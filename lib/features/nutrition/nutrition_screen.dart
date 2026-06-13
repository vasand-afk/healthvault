import 'package:flutter/material.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/core/widgets/stat_card.dart';
import 'package:vasan_health/core/database/database.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});
  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _waterLogs = [];

  double get _totalCalories => _logs.fold(0, (s, e) => s + ((e['calories'] as num?)?.toDouble() ?? 0));
  double get _totalProtein => _logs.fold(0, (s, e) => s + ((e['protein_g'] as num?)?.toDouble() ?? 0));
  double get _totalCarbs => _logs.fold(0, (s, e) => s + ((e['carbs_g'] as num?)?.toDouble() ?? 0));
  double get _totalFat => _logs.fold(0, (s, e) => s + ((e['fat_g'] as num?)?.toDouble() ?? 0));
  double get _totalWater => _waterLogs.fold(0, (s, e) => s + ((e['amount_ml'] as num?)?.toDouble() ?? 0));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final logs = await db.query('food_logs', where: 'date = ?', whereArgs: [dateStr], orderBy: 'created_at ASC');
    final water = await db.query('water_logs', where: 'date = ?', whereArgs: [dateStr]);
    setState(() { _logs = logs; _waterLogs = water; });
  }

  @override
  Widget build(BuildContext context) {
    final meals = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition'),
        actions: [
          IconButton(icon: const Icon(Icons.water_drop), onPressed: _logWater),
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddFoodDialog()),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateSelector(date: _selectedDate, onChanged: (d) { setState(() => _selectedDate = d); _load(); }),
            const SizedBox(height: 20),
            _MacroSummary(calories: _totalCalories, protein: _totalProtein, carbs: _totalCarbs, fat: _totalFat),
            const SizedBox(height: 20),
            _WaterTracker(totalMl: _totalWater, onAdd: _logWater),
            const SizedBox(height: 24),
            ...meals.map((meal) {
              final mealLogs = _logs.where((l) => l['meal_type'] == meal).toList();
              return _MealSection(
                meal: meal,
                logs: mealLogs,
                onAddFood: () => _showAddFoodDialog(meal: meal),
                onDelete: (id) async {
                  final db = await AppDatabase.instance;
                  await db.delete('food_logs', where: 'id = ?', whereArgs: [id]);
                  _load();
                },
              );
            }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _logWater() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Log Water', style: TextStyle(color: AppTheme.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How much did you drink?', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: [150, 250, 350, 500, 750].map((ml) => ElevatedButton(
              onPressed: () async {
                final db = await AppDatabase.instance;
                final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
                await db.insert('water_logs', {
                  'id': const Uuid().v4(),
                  'date': dateStr,
                  'amount_ml': ml.toDouble(),
                  'created_at': DateTime.now().toIso8601String(),
                });
                Navigator.pop(context);
                _load();
              },
              child: Text('${ml}ml'),
            )).toList(),
          ),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
    ));
  }

  void _showAddFoodDialog({String? meal}) {
    showDialog(context: context, builder: (_) => _AddFoodDialog(
      defaultMeal: meal ?? 'Snacks',
      onSave: (data) async {
        final db = await AppDatabase.instance;
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
        await db.insert('food_logs', {
          'id': const Uuid().v4(),
          'date': dateStr,
          ...data,
          'created_at': DateTime.now().toIso8601String(),
        });
        _load();
      },
    ));
  }
}

class _DateSelector extends StatelessWidget {
  final DateTime date;
  final Function(DateTime) onChanged;
  const _DateSelector({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
          onPressed: () => onChanged(date.subtract(const Duration(days: 1))),
        ),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
            if (picked != null) onChanged(picked);
          },
          child: Text(
            DateFormat.yMMMMd().format(date),
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          onPressed: date.isBefore(DateTime.now()) ? () => onChanged(date.add(const Duration(days: 1))) : null,
        ),
      ],
    );
  }
}

class _MacroSummary extends StatelessWidget {
  final double calories, protein, carbs, fat;
  const _MacroSummary({required this.calories, required this.protein, required this.carbs, required this.fat});

  @override
  Widget build(BuildContext context) {
    const calGoal = 2000.0;
    const proteinGoal = 150.0;
    const carbsGoal = 200.0;
    const fatGoal = 65.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${calories.toInt()}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 40, fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('/ 2,000 kcal', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (calories / calGoal).clamp(0, 1),
              backgroundColor: AppTheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                calories > calGoal ? AppTheme.danger : AppTheme.primary,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MacroBar('Protein', protein, proteinGoal, AppTheme.primary),
              const SizedBox(width: 12),
              _MacroBar('Carbs', carbs, carbsGoal, AppTheme.warning),
              const SizedBox(width: 12),
              _MacroBar('Fat', fat, fatGoal, AppTheme.secondary),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final double goal;
  final Color color;
  const _MacroBar(this.label, this.value, this.goal, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('${value.toInt()}g', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value / goal).clamp(0, 1),
              backgroundColor: AppTheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _WaterTracker extends StatelessWidget {
  final double totalMl;
  final VoidCallback onAdd;
  const _WaterTracker({required this.totalMl, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    const goalMl = 2500.0;
    final liters = totalMl / 1000;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
      child: Row(
        children: [
          const Icon(Icons.water_drop, color: AppTheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${liters.toStringAsFixed(1)}L / 2.5L', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    Text('${(totalMl / goalMl * 100).toInt()}%', style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (totalMl / goalMl).clamp(0, 1),
                    backgroundColor: AppTheme.surface,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(icon: const Icon(Icons.add_circle, color: AppTheme.primary, size: 28), onPressed: onAdd),
        ],
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  final String meal;
  final List<Map<String, dynamic>> logs;
  final VoidCallback onAddFood;
  final Function(String) onDelete;
  const _MealSection({required this.meal, required this.logs, required this.onAddFood, required this.onDelete});

  double get _mealCalories => logs.fold(0, (s, e) => s + ((e['calories'] as num?)?.toDouble() ?? 0));

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(meal, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                if (logs.isNotEmpty) Text('${_mealCalories.toInt()} kcal', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onAddFood,
                  child: const Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 22),
                ),
              ],
            ),
          ),
          if (logs.isNotEmpty)
            const Divider(height: 1),
          ...logs.map((log) => _FoodRow(log: log, onDelete: () => onDelete(log['id']))),
          if (logs.isEmpty)
            GestureDetector(
              onTap: onAddFood,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text('+ Add food', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  final Map<String, dynamic> log;
  final VoidCallback onDelete;
  const _FoodRow({required this.log, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log['food_name'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                Text('${log['serving_size'] ?? ''} ${log['serving_unit'] ?? ''} • P:${(log['protein_g'] as num?)?.toInt()}g C:${(log['carbs_g'] as num?)?.toInt()}g F:${(log['fat_g'] as num?)?.toInt()}g', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Text('${(log['calories'] as num?)?.toInt() ?? 0} kcal', style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 8),
          GestureDetector(onTap: onDelete, child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 16)),
        ],
      ),
    );
  }
}

class _AddFoodDialog extends StatefulWidget {
  final String defaultMeal;
  final Function(Map<String, dynamic>) onSave;
  const _AddFoodDialog({required this.defaultMeal, required this.onSave});
  @override
  State<_AddFoodDialog> createState() => _AddFoodDialogState();
}

class _AddFoodDialogState extends State<_AddFoodDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _meal;
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _servingSize = TextEditingController(text: '1');
  final _servingUnit = TextEditingController(text: 'serving');
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();
  final _sodium = TextEditingController();

  @override
  void initState() {
    super.initState();
    _meal = widget.defaultMeal;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add Food', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Food Name *'), style: const TextStyle(color: AppTheme.textPrimary), validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextFormField(controller: _brand, decoration: const InputDecoration(labelText: 'Brand'), style: const TextStyle(color: AppTheme.textPrimary))),
                  const SizedBox(width: 10),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _meal,
                    dropdownColor: AppTheme.surface,
                    decoration: const InputDecoration(labelText: 'Meal'),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    items: ['Breakfast', 'Lunch', 'Dinner', 'Snacks'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setState(() => _meal = v!),
                  )),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextFormField(controller: _servingSize, decoration: const InputDecoration(labelText: 'Serving Size'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _servingUnit, decoration: const InputDecoration(labelText: 'Unit'), style: const TextStyle(color: AppTheme.textPrimary))),
                ]),
                const SizedBox(height: 10),
                TextFormField(controller: _calories, decoration: const InputDecoration(labelText: 'Calories (kcal) *'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextFormField(controller: _protein, decoration: const InputDecoration(labelText: 'Protein (g)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _carbs, decoration: const InputDecoration(labelText: 'Carbs (g)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _fat, decoration: const InputDecoration(labelText: 'Fat (g)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextFormField(controller: _fiber, decoration: const InputDecoration(labelText: 'Fiber (g)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _sodium, decoration: const InputDecoration(labelText: 'Sodium (mg)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                ]),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave({
                'meal_type': _meal,
                'food_name': _name.text,
                'brand': _brand.text,
                'serving_size': double.tryParse(_servingSize.text),
                'serving_unit': _servingUnit.text,
                'calories': double.tryParse(_calories.text),
                'protein_g': double.tryParse(_protein.text),
                'carbs_g': double.tryParse(_carbs.text),
                'fat_g': double.tryParse(_fat.text),
                'fiber_g': double.tryParse(_fiber.text),
                'sodium_mg': double.tryParse(_sodium.text),
              });
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

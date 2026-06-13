import 'package:flutter/material.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/core/widgets/stat_card.dart';
import 'package:vasan_health/core/database/database.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class FitnessScreen extends StatefulWidget {
  const FitnessScreen({super.key});
  @override
  State<FitnessScreen> createState() => _FitnessScreenState();
}

class _FitnessScreenState extends State<FitnessScreen> {
  List<Map<String, dynamic>> _activities = [];
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('activities', orderBy: 'date DESC', limit: 30);
    setState(() => _activities = rows);
  }

  @override
  Widget build(BuildContext context) {
    final types = ['All', 'Run', 'Ride', 'Swim', 'Walk', 'Hike', 'Other'];
    final filtered = _filter == 'All' ? _activities : _activities.where((a) => a['type'] == _filter).toList();
    final thisWeek = _activities.where((a) {
      if (a['date'] == null) return false;
      final d = DateTime.tryParse(a['date']);
      if (d == null) return false;
      return d.isAfter(DateTime.now().subtract(const Duration(days: 7)));
    }).toList();
    final weekDist = thisWeek.fold<double>(0, (s, e) => s + ((e['distance_km'] as num?)?.toDouble() ?? 0));
    final weekCal = thisWeek.fold<double>(0, (s, e) => s + ((e['calories'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness & Cardio'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(child: StatCard(label: 'This Week Dist', value: weekDist.toStringAsFixed(1), unit: 'km', icon: Icons.route, color: AppTheme.accent)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Activities', value: '${thisWeek.length}', icon: Icons.directions_run, color: AppTheme.primary)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Calories', value: weekCal.toInt().toString(), unit: 'kcal', icon: Icons.local_fire_department, color: AppTheme.warning)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              itemCount: types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => FilterChip(
                label: Text(types[i]),
                selected: _filter == types[i],
                onSelected: (v) => setState(() => _filter = types[i]),
                selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                checkmarkColor: AppTheme.primary,
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.directions_run_outlined, size: 64, color: AppTheme.textSecondary),
                        const SizedBox(height: 16),
                        const Text('No activities', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(onPressed: _showAddDialog, icon: const Icon(Icons.add), label: const Text('Log Activity')),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _ActivityCard(activity: filtered[i], onDelete: () async {
                      final db = await AppDatabase.instance;
                      await db.delete('activities', where: 'id = ?', whereArgs: [filtered[i]['id']]);
                      _load();
                    }),
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    showDialog(context: context, builder: (_) => _AddActivityDialog(onSave: (data) async {
      final db = await AppDatabase.instance;
      await db.insert('activities', {
        'id': const Uuid().v4(),
        ...data,
        'created_at': DateTime.now().toIso8601String(),
      });
      _load();
    }));
  }
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final VoidCallback onDelete;
  const _ActivityCard({required this.activity, required this.onDelete});

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'Run': return Icons.directions_run;
      case 'Ride': return Icons.directions_bike;
      case 'Swim': return Icons.pool;
      case 'Walk': return Icons.directions_walk;
      case 'Hike': return Icons.terrain;
      default: return Icons.fitness_center;
    }
  }

  @override
  Widget build(BuildContext context) {
    return HvCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: Icon(_typeIcon(activity['type']), color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity['name'] ?? activity['type'] ?? 'Activity', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(activity['date'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                if (activity['avg_pace'] != null)
                  Text('Pace: ${activity['avg_pace']}/km', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (activity['distance_km'] != null) Text('${(activity['distance_km'] as num).toStringAsFixed(2)} km', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 15)),
              if (activity['duration_minutes'] != null) Text('${activity['duration_minutes']} min', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              if (activity['calories'] != null) Text('${(activity['calories'] as num).toInt()} kcal', style: const TextStyle(color: AppTheme.warning, fontSize: 11)),
              const SizedBox(height: 4),
              GestureDetector(onTap: onDelete, child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 15)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddActivityDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const _AddActivityDialog({required this.onSave});
  @override
  State<_AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<_AddActivityDialog> {
  String _type = 'Run';
  final _name = TextEditingController();
  final _date = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _duration = TextEditingController();
  final _distance = TextEditingController();
  final _calories = TextEditingController();
  final _avgHr = TextEditingController();
  final _pace = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Log Activity', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _type,
                  dropdownColor: AppTheme.surface,
                  decoration: const InputDecoration(labelText: 'Type'),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  items: ['Run', 'Ride', 'Swim', 'Walk', 'Hike', 'Rowing', 'HIIT', 'Other'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _type = v!),
                )),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name'), style: const TextStyle(color: AppTheme.textPrimary))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(controller: _date, decoration: const InputDecoration(labelText: 'Date'), style: const TextStyle(color: AppTheme.textPrimary))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _duration, decoration: const InputDecoration(labelText: 'Duration (min)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(controller: _distance, decoration: const InputDecoration(labelText: 'Distance (km)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _calories, decoration: const InputDecoration(labelText: 'Calories'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(controller: _avgHr, decoration: const InputDecoration(labelText: 'Avg HR (bpm)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _pace, decoration: const InputDecoration(labelText: 'Avg Pace (mm:ss)'), style: const TextStyle(color: AppTheme.textPrimary))),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onSave({
              'type': _type,
              'name': _name.text,
              'date': _date.text,
              'duration_minutes': double.tryParse(_duration.text),
              'distance_km': double.tryParse(_distance.text),
              'calories': double.tryParse(_calories.text),
              'avg_hr': double.tryParse(_avgHr.text),
              'avg_pace': _pace.text,
            });
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

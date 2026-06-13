import 'package:flutter/material.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/core/widgets/stat_card.dart';
import 'package:vasan_health/core/database/database.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class StrengthScreen extends StatefulWidget {
  const StrengthScreen({super.key});
  @override
  State<StrengthScreen> createState() => _StrengthScreenState();
}

class _StrengthScreenState extends State<StrengthScreen> {
  List<Map<String, dynamic>> _workouts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final workouts = await db.query('workouts', orderBy: 'date DESC', limit: 20);
    final result = <Map<String, dynamic>>[];
    for (final w in workouts) {
      final sets = await db.query('workout_sets', where: 'workout_id = ?', whereArgs: [w['id']]);
      result.add({...w, 'sets': sets});
    }
    setState(() => _workouts = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Strength Training'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showLogWorkout)],
      ),
      body: _workouts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fitness_center_outlined, size: 64, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  const Text('No workouts logged', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(onPressed: _showLogWorkout, icon: const Icon(Icons.add), label: const Text('Log Workout')),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _workouts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _WorkoutCard(workout: _workouts[i], onDelete: () async {
                final db = await AppDatabase.instance;
                await db.delete('workout_sets', where: 'workout_id = ?', whereArgs: [_workouts[i]['id']]);
                await db.delete('workouts', where: 'id = ?', whereArgs: [_workouts[i]['id']]);
                _load();
              }),
            ),
    );
  }

  void _showLogWorkout() {
    showDialog(context: context, builder: (_) => _LogWorkoutDialog(onSave: (name, sets) async {
      final db = await AppDatabase.instance;
      final workoutId = const Uuid().v4();
      await db.insert('workouts', {
        'id': workoutId,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (final set in sets) {
        await db.insert('workout_sets', {
          'id': const Uuid().v4(),
          'workout_id': workoutId,
          ...set,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      _load();
    }));
  }
}

class _WorkoutCard extends StatelessWidget {
  final Map<String, dynamic> workout;
  final VoidCallback onDelete;
  const _WorkoutCard({required this.workout, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final sets = workout['sets'] as List? ?? [];
    final exercises = sets.map((s) => s['exercise_name'] as String? ?? '').toSet().toList();
    final totalSets = sets.length;
    final totalVolume = sets.fold<double>(0, (s, e) => s + (((e['reps'] as num?)?.toDouble() ?? 0) * ((e['weight_kg'] as num?)?.toDouble() ?? 0)));

    return HvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.fitness_center, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workout['name'] ?? 'Workout', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(workout['date'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$totalSets sets', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('${totalVolume.toInt()} kg vol', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  const SizedBox(height: 4),
                  GestureDetector(onTap: onDelete, child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 15)),
                ],
              ),
            ],
          ),
          if (exercises.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: exercises.map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
                child: Text(e, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              )).toList(),
            ),
          ],
          if (sets.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            ...exercises.map((exercise) {
              final exSets = sets.where((s) => s['exercise_name'] == exercise).toList();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(
                      children: exSets.map((s) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text('${s['reps']}×${s['weight_kg']}kg', style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                      )).toList(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _LogWorkoutDialog extends StatefulWidget {
  final Function(String name, List<Map<String, dynamic>> sets) onSave;
  const _LogWorkoutDialog({required this.onSave});
  @override
  State<_LogWorkoutDialog> createState() => _LogWorkoutDialogState();
}

class _LogWorkoutDialogState extends State<_LogWorkoutDialog> {
  final _nameCtrl = TextEditingController(text: 'Workout');
  final _sets = <_SetEntry>[];

  void _addSet() {
    setState(() => _sets.add(_SetEntry()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Log Workout', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 520,
        height: 480,
        child: Column(
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Workout Name'),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sets', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                TextButton.icon(onPressed: _addSet, icon: const Icon(Icons.add, size: 16), label: const Text('Add Set')),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _sets.length,
                itemBuilder: (context, i) => _SetRow(entry: _sets[i], onRemove: () => setState(() => _sets.removeAt(i))),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onSave(
              _nameCtrl.text,
              _sets.map((s) => {
                'exercise_name': s.exercise.text,
                'set_number': _sets.indexOf(s) + 1,
                'reps': int.tryParse(s.reps.text),
                'weight_kg': double.tryParse(s.weight.text),
                'rpe': double.tryParse(s.rpe.text),
              }).toList(),
            );
            Navigator.pop(context);
          },
          child: const Text('Save Workout'),
        ),
      ],
    );
  }
}

class _SetEntry {
  final exercise = TextEditingController();
  final reps = TextEditingController();
  final weight = TextEditingController();
  final rpe = TextEditingController();
}

class _SetRow extends StatelessWidget {
  final _SetEntry entry;
  final VoidCallback onRemove;
  const _SetRow({required this.entry, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: TextFormField(
            controller: entry.exercise,
            decoration: const InputDecoration(labelText: 'Exercise', isDense: true, contentPadding: EdgeInsets.all(10)),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          )),
          const SizedBox(width: 6),
          SizedBox(width: 50, child: TextFormField(
            controller: entry.reps,
            decoration: const InputDecoration(labelText: 'Reps', isDense: true, contentPadding: EdgeInsets.all(10)),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            keyboardType: TextInputType.number,
          )),
          const SizedBox(width: 6),
          SizedBox(width: 60, child: TextFormField(
            controller: entry.weight,
            decoration: const InputDecoration(labelText: 'Kg', isDense: true, contentPadding: EdgeInsets.all(10)),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            keyboardType: TextInputType.number,
          )),
          const SizedBox(width: 6),
          SizedBox(width: 44, child: TextFormField(
            controller: entry.rpe,
            decoration: const InputDecoration(labelText: 'RPE', isDense: true, contentPadding: EdgeInsets.all(10)),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            keyboardType: TextInputType.number,
          )),
          IconButton(icon: const Icon(Icons.close, size: 16, color: AppTheme.textSecondary), onPressed: onRemove),
        ],
      ),
    );
  }
}

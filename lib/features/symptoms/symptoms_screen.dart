import 'package:flutter/material.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/core/widgets/stat_card.dart';
import 'package:healthvault/core/database/database.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class SymptomsScreen extends StatefulWidget {
  const SymptomsScreen({super.key});
  @override
  State<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends State<SymptomsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _symptoms = [];
  List<Map<String, dynamic>> _moods = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final symptoms = await db.query('symptoms', orderBy: 'date DESC, time DESC', limit: 30);
    final moods = await db.query('mood_logs', orderBy: 'date DESC, time DESC', limit: 30);
    setState(() { _symptoms = symptoms; _moods = moods; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symptoms & Wellbeing'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [Tab(text: 'Symptoms'), Tab(text: 'Mood & Energy')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              if (_tabs.index == 0) _showAddSymptomDialog();
              else _showAddMoodDialog();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _SymptomsTab(symptoms: _symptoms, onAdd: _showAddSymptomDialog, onDelete: (id) async {
            final db = await AppDatabase.instance; await db.delete('symptoms', where: 'id = ?', whereArgs: [id]); _load();
          }),
          _MoodTab(moods: _moods, onAdd: _showAddMoodDialog, onDelete: (id) async {
            final db = await AppDatabase.instance; await db.delete('mood_logs', where: 'id = ?', whereArgs: [id]); _load();
          }),
        ],
      ),
    );
  }

  void _showAddSymptomDialog() {
    showDialog(context: context, builder: (_) => _AddSymptomDialog(onSave: (data) async {
      final db = await AppDatabase.instance;
      await db.insert('symptoms', {'id': const Uuid().v4(), ...data, 'created_at': DateTime.now().toIso8601String()});
      _load();
    }));
  }

  void _showAddMoodDialog() {
    showDialog(context: context, builder: (_) => _AddMoodDialog(onSave: (data) async {
      final db = await AppDatabase.instance;
      await db.insert('mood_logs', {'id': const Uuid().v4(), ...data, 'created_at': DateTime.now().toIso8601String()});
      _load();
    }));
  }
}

class _SymptomsTab extends StatelessWidget {
  final List<Map<String, dynamic>> symptoms;
  final VoidCallback onAdd;
  final void Function(String) onDelete;
  const _SymptomsTab({required this.symptoms, required this.onAdd, required this.onDelete});

  Color _severityColor(int? s) {
    if (s == null) return AppTheme.textSecondary;
    if (s >= 8) return AppTheme.danger;
    if (s >= 5) return AppTheme.warning;
    return AppTheme.accent;
  }

  @override
  Widget build(BuildContext context) {
    if (symptoms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text('No symptoms logged', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Track symptoms, triggers, and patterns', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Log Symptom')),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: symptoms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = symptoms[i];
        final severity = s['severity'] as int?;
        return HvCard(
          borderColor: _severityColor(severity).withValues(alpha: 0.3),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: _severityColor(severity).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text('${severity ?? '-'}', style: TextStyle(color: _severityColor(severity), fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['symptom'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    Text('${s['date']} ${s['time'] ?? ''}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    if (s['triggers'] != null && (s['triggers'] as String).isNotEmpty)
                      Text('Triggers: ${s['triggers']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              if (s['duration_minutes'] != null)
                StatusBadge(label: '${s['duration_minutes']}min', color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              GestureDetector(onTap: () => onDelete(s['id'] as String), child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 15)),
            ],
          ),
        );
      },
    );
  }
}

class _MoodTab extends StatelessWidget {
  final List<Map<String, dynamic>> moods;
  final VoidCallback onAdd;
  final void Function(String) onDelete;
  const _MoodTab({required this.moods, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (moods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sentiment_satisfied_outlined, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text('No mood entries', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Log Mood')),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: moods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final m = moods[i];
        final mood = m['mood'] as int? ?? 5;
        const emojis = ['', '😢', '😞', '😕', '😐', '🙂', '😊', '😄', '😁', '🤩', '🥳'];
        return HvCard(
          child: Row(
            children: [
              Text(mood < emojis.length ? emojis[mood] : '😊', style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m['date']} ${m['time'] ?? ''}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(children: [
                      _MoodMetric('Mood', m['mood'], AppTheme.secondary),
                      const SizedBox(width: 12),
                      _MoodMetric('Energy', m['energy'], AppTheme.warning),
                      const SizedBox(width: 12),
                      _MoodMetric('Anxiety', m['anxiety'], AppTheme.danger),
                    ]),
                  ],
                ),
              ),
              GestureDetector(onTap: () => onDelete(m['id'] as String), child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 15)),
            ],
          ),
        );
      },
    );
  }
}

class _MoodMetric extends StatelessWidget {
  final String label;
  final dynamic value;
  final Color color;
  const _MoodMetric(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${value ?? '-'}/10', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ],
    );
  }
}

class _AddSymptomDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const _AddSymptomDialog({required this.onSave});
  @override
  State<_AddSymptomDialog> createState() => _AddSymptomDialogState();
}

class _AddSymptomDialogState extends State<_AddSymptomDialog> {
  final _symptom = TextEditingController();
  final _triggers = TextEditingController();
  final _notes = TextEditingController();
  final _duration = TextEditingController();
  int _severity = 5;
  final _date = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _time = TextEditingController(text: DateFormat('HH:mm').format(DateTime.now()));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Log Symptom', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _symptom, decoration: const InputDecoration(labelText: 'Symptom *'), style: const TextStyle(color: AppTheme.textPrimary)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(controller: _date, decoration: const InputDecoration(labelText: 'Date'), style: const TextStyle(color: AppTheme.textPrimary))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _time, decoration: const InputDecoration(labelText: 'Time'), style: const TextStyle(color: AppTheme.textPrimary))),
              ]),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Severity:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(width: 10),
                  Text('$_severity / 10', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                ],
              ),
              Slider(
                value: _severity.toDouble(),
                min: 1, max: 10, divisions: 9,
                activeColor: AppTheme.danger,
                onChanged: (v) => setState(() => _severity = v.toInt()),
              ),
              TextFormField(controller: _duration, decoration: const InputDecoration(labelText: 'Duration (minutes)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              TextFormField(controller: _triggers, decoration: const InputDecoration(labelText: 'Triggers'), style: const TextStyle(color: AppTheme.textPrimary)),
              const SizedBox(height: 10),
              TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes'), style: const TextStyle(color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_symptom.text.isNotEmpty) {
              widget.onSave({
                'date': _date.text,
                'time': _time.text,
                'symptom': _symptom.text,
                'severity': _severity,
                'duration_minutes': int.tryParse(_duration.text),
                'triggers': _triggers.text,
                'notes': _notes.text,
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

class _AddMoodDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const _AddMoodDialog({required this.onSave});
  @override
  State<_AddMoodDialog> createState() => _AddMoodDialogState();
}

class _AddMoodDialogState extends State<_AddMoodDialog> {
  int _mood = 7;
  int _energy = 7;
  int _anxiety = 3;
  final _notes = TextEditingController();

  @override
  Widget build(BuildContext context) {
    const emojis = ['', '😢', '😞', '😕', '😐', '🙂', '😊', '😄', '😁', '🤩', '🥳'];

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Log Mood & Energy', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emojis[_mood], style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              _SliderRow('Mood', _mood, AppTheme.secondary, (v) => setState(() => _mood = v)),
              const SizedBox(height: 8),
              _SliderRow('Energy', _energy, AppTheme.warning, (v) => setState(() => _energy = v)),
              const SizedBox(height: 8),
              _SliderRow('Anxiety', _anxiety, AppTheme.danger, (v) => setState(() => _anxiety = v)),
              const SizedBox(height: 12),
              TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes'), style: const TextStyle(color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onSave({
              'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
              'time': DateFormat('HH:mm').format(DateTime.now()),
              'mood': _mood,
              'energy': _energy,
              'anxiety': _anxiety,
              'notes': _notes.text,
            });
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final Function(int) onChanged;
  const _SliderRow(this.label, this.value, this.color, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        Expanded(child: Slider(value: value.toDouble(), min: 1, max: 10, divisions: 9, activeColor: color, onChanged: (v) => onChanged(v.toInt()))),
        SizedBox(width: 24, child: Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.w700))),
      ],
    );
  }
}

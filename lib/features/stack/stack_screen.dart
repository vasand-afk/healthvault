import 'package:flutter/material.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/core/widgets/stat_card.dart';
import 'package:healthvault/core/database/database.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class StackScreen extends StatefulWidget {
  const StackScreen({super.key});
  @override
  State<StackScreen> createState() => _StackScreenState();
}

class _StackScreenState extends State<StackScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _supplements = [];
  List<Map<String, dynamic>> _todayLogs = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final supp = await db.query('supplements', orderBy: 'name ASC');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final logs = await db.query('supplement_logs', where: 'date = ?', whereArgs: [today]);
    setState(() { _supplements = supp; _todayLogs = logs; });
  }

  @override
  Widget build(BuildContext context) {
    final active = _supplements.where((s) => (s['active'] as int? ?? 1) == 1).toList();
    final loggedIds = _todayLogs.map((l) => l['supplement_id']).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplement Stack'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [Tab(text: 'Today'), Tab(text: 'My Stack'), Tab(text: 'Log History')],
        ),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog)],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _TodayTab(supplements: active, loggedIds: loggedIds, onLog: (id) async {
            final db = await AppDatabase.instance;
            await db.insert('supplement_logs', {
              'id': const Uuid().v4(),
              'supplement_id': id,
              'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
              'time': DateFormat('HH:mm').format(DateTime.now()),
              'created_at': DateTime.now().toIso8601String(),
            });
            _load();
          }),
          _StackTab(supplements: _supplements, onAdd: _showAddDialog, onToggle: (id, active) async {
            final db = await AppDatabase.instance;
            await db.update('supplements', {'active': active ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
            _load();
          }),
          _HistoryTab(logs: _todayLogs, supplements: _supplements),
        ],
      ),
    );
  }

  void _showAddDialog() {
    showDialog(context: context, builder: (_) => _AddSupplementDialog(onSave: (data) async {
      final db = await AppDatabase.instance;
      await db.insert('supplements', {
        'id': const Uuid().v4(),
        ...data,
        'active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      _load();
    }));
  }
}

class _TodayTab extends StatelessWidget {
  final List<Map<String, dynamic>> supplements;
  final Set loggedIds;
  final Function(String) onLog;
  const _TodayTab({required this.supplements, required this.loggedIds, required this.onLog});

  @override
  Widget build(BuildContext context) {
    if (supplements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.science_outlined, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text('No supplements in your stack', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final timings = ['Morning', 'Pre-Workout', 'With Meals', 'Evening', 'Before Bed', ''];
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: timings.length,
      itemBuilder: (context, ti) {
        final timingSupps = supplements.where((s) {
          if (timings[ti].isEmpty) return (s['timing'] == null || !timings.take(timings.length - 1).contains(s['timing']));
          return s['timing'] == timings[ti];
        }).toList();
        if (timingSupps.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(timings[ti].isEmpty ? 'Other' : timings[ti], style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            ...timingSupps.map((s) {
              final logged = loggedIds.contains(s['id']);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: logged ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: logged ? AppTheme.accent.withValues(alpha: 0.4) : AppTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: logged ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(logged ? Icons.check_circle : Icons.science, color: logged ? AppTheme.accent : AppTheme.textSecondary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s['name'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                          Text('${s['dose'] ?? ''} ${s['unit'] ?? ''}  •  ${s['type'] ?? ''}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (!logged)
                      TextButton(
                        onPressed: () => onLog(s['id']),
                        style: TextButton.styleFrom(
                          backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
                          foregroundColor: AppTheme.accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        child: const Text('Log', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _StackTab extends StatelessWidget {
  final List<Map<String, dynamic>> supplements;
  final VoidCallback onAdd;
  final Function(String, bool) onToggle;
  const _StackTab({required this.supplements, required this.onAdd, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    if (supplements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.science_outlined, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text('No supplements added', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add Supplement')),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: supplements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = supplements[i];
        final active = (s['active'] as int? ?? 1) == 1;
        return HvCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: active ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.science, color: active ? AppTheme.accent : AppTheme.textSecondary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(s['name'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      if (s['type'] != null) StatusBadge(label: s['type'], color: AppTheme.secondary),
                    ]),
                    Text('${s['dose'] ?? ''} ${s['unit'] ?? ''} · ${s['timing'] ?? ''} · ${s['frequency'] ?? ''}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    if (s['purpose'] != null) Text(s['purpose'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Switch(
                value: active,
                onChanged: (v) => onToggle(s['id'], v),
                activeColor: AppTheme.accent,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final List<Map<String, dynamic>> supplements;
  const _HistoryTab({required this.logs, required this.supplements});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(child: Text('No logs today', style: TextStyle(color: AppTheme.textSecondary)));
    }
    final suppMap = {for (var s in supplements) s['id']: s};
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: logs.length,
      itemBuilder: (context, i) {
        final log = logs[i];
        final supp = suppMap[log['supplement_id']];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.accent, size: 18),
              const SizedBox(width: 10),
              Text(supp?['name'] ?? 'Unknown', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(log['time'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}

class _AddSupplementDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const _AddSupplementDialog({required this.onSave});
  @override
  State<_AddSupplementDialog> createState() => _AddSupplementDialogState();
}

class _AddSupplementDialogState extends State<_AddSupplementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _dose = TextEditingController();
  final _unit = TextEditingController(text: 'mg');
  final _purpose = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'Supplement';
  String _timing = 'Morning';
  String _frequency = 'Daily';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add Supplement / Peptide', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name *'), style: const TextStyle(color: AppTheme.textPrimary), validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _type,
                    dropdownColor: AppTheme.surface,
                    decoration: const InputDecoration(labelText: 'Type'),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    items: ['Supplement', 'Vitamin', 'Mineral', 'Peptide', 'Nootropic', 'Herb', 'Probiotic', 'Amino Acid', 'Hormone', 'Other'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _brand, decoration: const InputDecoration(labelText: 'Brand'), style: const TextStyle(color: AppTheme.textPrimary))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextFormField(controller: _dose, decoration: const InputDecoration(labelText: 'Dose'), style: const TextStyle(color: AppTheme.textPrimary))),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit'), style: const TextStyle(color: AppTheme.textPrimary))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _timing,
                    dropdownColor: AppTheme.surface,
                    decoration: const InputDecoration(labelText: 'Timing'),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    items: ['Morning', 'Pre-Workout', 'Post-Workout', 'With Meals', 'Evening', 'Before Bed', 'Fasted'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _timing = v!),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _frequency,
                    dropdownColor: AppTheme.surface,
                    decoration: const InputDecoration(labelText: 'Frequency'),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    items: ['Daily', '2x Daily', '3x Daily', 'Weekly', 'Cycling', 'As Needed'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                    onChanged: (v) => setState(() => _frequency = v!),
                  )),
                ]),
                const SizedBox(height: 10),
                TextFormField(controller: _purpose, decoration: const InputDecoration(labelText: 'Purpose / Goal'), style: const TextStyle(color: AppTheme.textPrimary)),
                const SizedBox(height: 10),
                TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes'), style: const TextStyle(color: AppTheme.textPrimary)),
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
                'name': _name.text,
                'type': _type,
                'brand': _brand.text,
                'dose': _dose.text,
                'unit': _unit.text,
                'timing': _timing,
                'frequency': _frequency,
                'purpose': _purpose.text,
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

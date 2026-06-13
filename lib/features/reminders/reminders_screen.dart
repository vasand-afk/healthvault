import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:vasan_health/core/database/database.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/core/widgets/stat_card.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const _reminderTypes = ['Supplement', 'Medication', 'Lab Re-test', 'Appointment', 'Workout', 'Fasting', 'Custom'];
const _frequencies   = ['Daily', 'Weekly', 'Monthly', 'Once'];
const _weekdays      = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _dueToday = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final all = await db.query('reminders', orderBy: 'enabled DESC, next_due ASC');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final due = all.where((r) {
      if ((r['enabled'] as int? ?? 1) == 0) return false;
      final nd = r['next_due'] as String?;
      return nd != null && nd.compareTo(today) <= 0;
    }).toList();
    if (mounted) setState(() { _all = all; _dueToday = due; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _add, tooltip: 'Add reminder'),
        ],
      ),
      body: _all.isEmpty ? _EmptyState(onAdd: _add) : _ReminderList(
        all: _all,
        dueToday: _dueToday,
        onToggle: _toggle,
        onDelete: _delete,
        onMarkDone: _markDone,
        onAdd: _add,
      ),
    );
  }

  Future<void> _add() async {
    await showDialog(context: context, builder: (_) => _AddReminderDialog(onSave: (row) async {
      final db = await AppDatabase.instance;
      await db.insert('reminders', {'id': const Uuid().v4(), ...row, 'created_at': DateTime.now().toIso8601String()});
      _load();
    }));
  }

  Future<void> _toggle(String id, bool enabled) async {
    final db = await AppDatabase.instance;
    await db.update('reminders', {'enabled': enabled ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
    _load();
  }

  Future<void> _delete(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
    _load();
  }

  Future<void> _markDone(String id) async {
    final db = await AppDatabase.instance;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final rows = await db.query('reminders', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final r = rows.first;
    final nextDue = _computeNextDue(r['frequency'] as String? ?? 'Daily', today);
    await db.update('reminders', {'last_triggered': today, 'next_due': nextDue}, where: 'id = ?', whereArgs: [id]);
    _load();
  }

  String _computeNextDue(String frequency, String fromDate) {
    final dt = DateTime.parse(fromDate);
    switch (frequency) {
      case 'Daily': return DateFormat('yyyy-MM-dd').format(dt.add(const Duration(days: 1)));
      case 'Weekly': return DateFormat('yyyy-MM-dd').format(dt.add(const Duration(days: 7)));
      case 'Monthly': return DateFormat('yyyy-MM-dd').format(DateTime(dt.year, dt.month + 1, dt.day));
      default: return DateFormat('yyyy-MM-dd').format(dt.add(const Duration(days: 365)));
    }
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _ReminderList extends StatelessWidget {
  final List<Map<String, dynamic>> all, dueToday;
  final void Function(String, bool) onToggle;
  final void Function(String) onDelete, onMarkDone;
  final VoidCallback onAdd;
  const _ReminderList({required this.all, required this.dueToday, required this.onToggle, required this.onDelete, required this.onMarkDone, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (dueToday.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.notifications_active, color: AppTheme.warning, size: 18),
              const SizedBox(width: 8),
              Text('${dueToday.length} due today', style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
            const SizedBox(height: 10),
            ...dueToday.map((r) => _DueCard(r, onDone: () => onMarkDone(r['id'] as String))),
          ]),
        ),
        const SizedBox(height: 20),
      ],
      const SectionHeader(title: 'All Reminders'),
      const SizedBox(height: 10),
      ...all.map((r) => _ReminderCard(r, onToggle: onToggle, onDelete: onDelete, onDone: (id) => onMarkDone(id))),
      const SizedBox(height: 80),
    ]);
  }
}

class _DueCard extends StatelessWidget {
  final Map<String, dynamic> r;
  final VoidCallback onDone;
  const _DueCard(this.r, {required this.onDone});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Icon(_typeIcon(r['type'] as String? ?? ''), color: AppTheme.warning, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r['title'] as String? ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        if (r['time_of_day'] != null) Text(r['time_of_day'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ])),
      TextButton(
        onPressed: onDone,
        style: TextButton.styleFrom(foregroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
        child: const Text('Done ✓', style: TextStyle(fontSize: 12)),
      ),
    ]),
  );
}

class _ReminderCard extends StatelessWidget {
  final Map<String, dynamic> r;
  final void Function(String, bool) onToggle;
  final void Function(String) onDelete, onDone;
  const _ReminderCard(this.r, {required this.onToggle, required this.onDelete, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final enabled = (r['enabled'] as int? ?? 1) == 1;
    final color = _typeColor(r['type'] as String? ?? '');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isDue = enabled && (r['next_due'] as String? ?? '').compareTo(today) <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDue ? AppTheme.warning.withValues(alpha: 0.5) : enabled ? color.withValues(alpha: 0.3) : AppTheme.border.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: enabled ? 0.15 : 0.05), borderRadius: BorderRadius.circular(10)),
          child: Icon(_typeIcon(r['type'] as String? ?? ''), color: enabled ? color : AppTheme.textSecondary, size: 18),
        ),
        title: Text(r['title'] as String? ?? '', style: TextStyle(color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (r['time_of_day'] != null) Text('${r['time_of_day']}  ·  ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            Text(r['frequency'] as String? ?? '', style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
          if (r['next_due'] != null) Text('Next: ${r['next_due']}', style: TextStyle(color: isDue ? AppTheme.warning : AppTheme.textSecondary, fontSize: 10)),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (isDue) IconButton(icon: const Icon(Icons.check_circle_outline, color: AppTheme.accent, size: 22), onPressed: () => onDone(r['id'] as String), tooltip: 'Mark done'),
          Switch(value: enabled, onChanged: (v) => onToggle(r['id'] as String, v), activeColor: color),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 18),
            color: AppTheme.surface,
            itemBuilder: (_) => [const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.danger)))],
            onSelected: (v) { if (v == 'delete') onDelete(r['id'] as String); },
          ),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.notifications_none, color: AppTheme.textSecondary, size: 64),
      const SizedBox(height: 16),
      const Text('No reminders yet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('Set reminders for supplements, labs, medications, workouts, and more.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
      const SizedBox(height: 28),
      ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add Reminder')),
    ]),
  ));
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

IconData _typeIcon(String type) {
  switch (type) {
    case 'Supplement': return Icons.science;
    case 'Medication': return Icons.medication;
    case 'Lab Re-test': return Icons.biotech;
    case 'Appointment': return Icons.calendar_today;
    case 'Workout': return Icons.fitness_center;
    case 'Fasting': return Icons.no_food;
    default: return Icons.notifications;
  }
}

Color _typeColor(String type) {
  switch (type) {
    case 'Supplement': return AppTheme.accent;
    case 'Medication': return AppTheme.danger;
    case 'Lab Re-test': return AppTheme.warning;
    case 'Appointment': return AppTheme.primary;
    case 'Workout': return const Color(0xFF10B981);
    case 'Fasting': return const Color(0xFFF59E0B);
    default: return AppTheme.secondary;
  }
}

// ─── Add dialog ──────────────────────────────────────────────────────────────

class _AddReminderDialog extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _AddReminderDialog({required this.onSave});
  @override
  State<_AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<_AddReminderDialog> {
  String _type = 'Supplement';
  String _frequency = 'Daily';
  final _title = TextEditingController();
  final _body  = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  String _nextDue = DateFormat('yyyy-MM-dd').format(DateTime.now());
  List<int> _days = [1, 2, 3, 4, 5]; // Mon-Fri default
  bool _saving = false;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _nextDue = DateFormat('yyyy-MM-dd').format(picked));
  }

  String get _timeStr => _time.hour.toString().padLeft(2, '0') + ':' + _time.minute.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add Reminder', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          value: _type, dropdownColor: AppTheme.surface,
          decoration: const InputDecoration(labelText: 'Type *'),
          style: const TextStyle(color: AppTheme.textPrimary),
          items: _reminderTypes.map((t) => DropdownMenuItem(value: t, child: Row(children: [
            Icon(_typeIcon(t), color: _typeColor(t), size: 16),
            const SizedBox(width: 8),
            Text(t),
          ]))).toList(),
          onChanged: (v) => setState(() { _type = v!; _title.text = v; }),
        ),
        const SizedBox(height: 10),
        TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title *', hintText: 'e.g. Morning supplements'), style: const TextStyle(color: AppTheme.textPrimary)),
        const SizedBox(height: 10),
        TextFormField(controller: _body, decoration: const InputDecoration(labelText: 'Notes', hintText: 'Optional details'), style: const TextStyle(color: AppTheme.textPrimary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            value: _frequency, dropdownColor: AppTheme.surface,
            decoration: const InputDecoration(labelText: 'Frequency'),
            style: const TextStyle(color: AppTheme.textPrimary),
            items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) => setState(() => _frequency = v!),
          )),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(
            onTap: _pickTime,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Time', suffixIcon: Icon(Icons.access_time, size: 18)),
              child: Text(_timeStr, style: const TextStyle(color: AppTheme.textPrimary)),
            ),
          )),
        ]),
        const SizedBox(height: 10),
        if (_frequency == 'Weekly') ...[
          const Text('Days of week', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: List.generate(7, (i) {
            final selected = _days.contains(i + 1);
            return FilterChip(
              label: Text(_weekdays[i]),
              selected: selected,
              onSelected: (v) => setState(() { if (v) _days.add(i + 1); else _days.remove(i + 1); }),
              selectedColor: AppTheme.primary.withValues(alpha: 0.3),
              labelStyle: TextStyle(color: selected ? AppTheme.primary : AppTheme.textSecondary, fontSize: 11),
            );
          })),
          const SizedBox(height: 10),
        ],
        GestureDetector(
          onTap: _pickDate,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Starting / Next Due Date', suffixIcon: Icon(Icons.calendar_today, size: 18)),
            child: Text(_nextDue, style: const TextStyle(color: AppTheme.textPrimary)),
          ),
        ),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving || _title.text.isEmpty ? null : () async {
            setState(() => _saving = true);
            await widget.onSave({
              'title': _title.text,
              'body': _body.text,
              'type': _type,
              'frequency': _frequency,
              'time_of_day': _timeStr,
              'days_of_week': jsonEncode(_days),
              'next_due': _nextDue,
              'enabled': 1,
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
        ),
      ],
    );
  }
}

// ─── Public helper: fetch due count ──────────────────────────────────────────

Future<int> getDueReminderCount() async {
  final db = await AppDatabase.instance;
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final rows = await db.query('reminders', where: 'enabled = 1 AND next_due <= ?', whereArgs: [today]);
  return rows.length;
}

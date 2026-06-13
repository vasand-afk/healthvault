import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/core/widgets/stat_card.dart';
import 'package:vasan_health/core/database/database.dart';
import 'package:uuid/uuid.dart';

class LabsScreen extends StatefulWidget {
  const LabsScreen({super.key});
  @override
  State<LabsScreen> createState() => _LabsScreenState();
}

class _LabsScreenState extends State<LabsScreen> {
  List<Map<String, dynamic>> _labs = [];
  String _filter = 'All';
  final _categories = ['All', 'Metabolic', 'Lipids', 'Hormones', 'CBC', 'Thyroid', 'Vitamins', 'Inflammation'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('lab_results', orderBy: 'date DESC');
    setState(() => _labs = rows);
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'High': return AppTheme.danger;
      case 'Low': return AppTheme.warning;
      case 'Normal': return AppTheme.accent;
      case 'Optimal': return AppTheme.primary;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Results'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog),
          IconButton(icon: const Icon(Icons.upload_file), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => FilterChip(
                label: Text(_categories[i]),
                selected: _filter == _categories[i],
                onSelected: (v) => setState(() => _filter = _categories[i]),
                selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                checkmarkColor: AppTheme.primary,
              ),
            ),
          ),
          Expanded(
            child: _labs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.biotech_outlined, size: 64, color: AppTheme.textSecondary),
                        const SizedBox(height: 16),
                        const Text('No lab results', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(onPressed: _showAddDialog, icon: const Icon(Icons.add), label: const Text('Add Lab Result')),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _labs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final lab = _labs[i];
                      return HvCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(lab['test_name'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text('${lab['date'] ?? ''} • ${lab['lab_name'] ?? ''}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                  if (lab['reference_range'] != null)
                                    Text('Ref: ${lab['reference_range']} ${lab['unit'] ?? ''}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${lab['value'] ?? ''} ${lab['unit'] ?? ''}',
                                  style: TextStyle(
                                    color: _statusColor(lab['status']),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                if (lab['status'] != null)
                                  StatusBadge(label: lab['status'], color: _statusColor(lab['status'])),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    showDialog(context: context, builder: (_) => _AddLabDialog(onSave: (data) async {
      final db = await AppDatabase.instance;
      await db.insert('lab_results', {
        'id': const Uuid().v4(),
        ...data,
        'created_at': DateTime.now().toIso8601String(),
      });
      _load();
    }));
  }
}

class _AddLabDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const _AddLabDialog({required this.onSave});
  @override
  State<_AddLabDialog> createState() => _AddLabDialogState();
}

class _AddLabDialogState extends State<_AddLabDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _value = TextEditingController();
  final _unit = TextEditingController();
  final _range = TextEditingController();
  final _date = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _lab = TextEditingController();
  final _notes = TextEditingController();
  String _status = 'Normal';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add Lab Result', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Test Name *'), style: const TextStyle(color: AppTheme.textPrimary), validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: _value, decoration: const InputDecoration(labelText: 'Value'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit'), style: const TextStyle(color: AppTheme.textPrimary))),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: _range, decoration: const InputDecoration(labelText: 'Reference Range'), style: const TextStyle(color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: _date, decoration: const InputDecoration(labelText: 'Date'), style: const TextStyle(color: AppTheme.textPrimary))),
                  const SizedBox(width: 12),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _status,
                    dropdownColor: AppTheme.surface,
                    decoration: const InputDecoration(labelText: 'Status'),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    items: ['Normal', 'Optimal', 'High', 'Low', 'Critical'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  )),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: _lab, decoration: const InputDecoration(labelText: 'Lab Name'), style: const TextStyle(color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
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
                'test_name': _name.text,
                'value': double.tryParse(_value.text),
                'unit': _unit.text,
                'reference_range': _range.text,
                'date': _date.text,
                'status': _status,
                'lab_name': _lab.text,
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

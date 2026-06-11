import 'package:flutter/material.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/core/widgets/stat_card.dart';
import 'package:healthvault/core/database/database.dart';
import 'package:uuid/uuid.dart';

class DiagnosesScreen extends StatefulWidget {
  const DiagnosesScreen({super.key});
  @override
  State<DiagnosesScreen> createState() => _DiagnosesScreenState();
}

class _DiagnosesScreenState extends State<DiagnosesScreen> {
  List<Map<String, dynamic>> _diagnoses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('diagnoses', orderBy: 'created_at DESC');
    setState(() => _diagnoses = rows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Diagnoses'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog),
        ],
      ),
      body: _diagnoses.isEmpty
          ? _EmptyState(onAdd: _showAddDialog)
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _diagnoses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _DiagnosisCard(
                diagnosis: _diagnoses[i],
                onDelete: () async {
                  final db = await AppDatabase.instance;
                  await db.delete('diagnoses', where: 'id = ?', whereArgs: [_diagnoses[i]['id']]);
                  _load();
                },
              ),
            ),
    );
  }

  void _showAddDialog() {
    showDialog(context: context, builder: (_) => _AddDiagnosisDialog(onSave: (data) async {
      final db = await AppDatabase.instance;
      await db.insert('diagnoses', {
        'id': const Uuid().v4(),
        'title': data['title'],
        'icd_code': data['icd_code'],
        'diagnosed_date': data['diagnosed_date'],
        'status': data['status'],
        'notes': data['notes'],
        'follow_up_plan': data['follow_up_plan'],
        'created_at': DateTime.now().toIso8601String(),
      });
      _load();
    }));
  }
}

class _DiagnosisCard extends StatelessWidget {
  final Map<String, dynamic> diagnosis;
  final VoidCallback onDelete;
  const _DiagnosisCard({required this.diagnosis, required this.onDelete});

  Color _statusColor(String? s) {
    switch (s) {
      case 'Active': return AppTheme.danger;
      case 'Managed': return AppTheme.warning;
      case 'Resolved': return AppTheme.accent;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return HvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medical_information, color: AppTheme.danger, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(diagnosis['title'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              if (diagnosis['status'] != null)
                StatusBadge(label: diagnosis['status'], color: _statusColor(diagnosis['status'])),
              const SizedBox(width: 8),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 18),
                color: AppTheme.surface,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.danger))),
                ],
                onSelected: (v) { if (v == 'delete') onDelete(); },
              ),
            ],
          ),
          if (diagnosis['icd_code'] != null && diagnosis['icd_code'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('ICD: ${diagnosis['icd_code']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
          if (diagnosis['diagnosed_date'] != null) ...[
            const SizedBox(height: 4),
            Text('Diagnosed: ${diagnosis['diagnosed_date']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
          if (diagnosis['notes'] != null && diagnosis['notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(diagnosis['notes'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
          ],
          if (diagnosis['follow_up_plan'] != null && diagnosis['follow_up_plan'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.assignment, color: AppTheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(diagnosis['follow_up_plan'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddDiagnosisDialog extends StatefulWidget {
  final Function(Map<String, String>) onSave;
  const _AddDiagnosisDialog({required this.onSave});
  @override
  State<_AddDiagnosisDialog> createState() => _AddDiagnosisDialogState();
}

class _AddDiagnosisDialogState extends State<_AddDiagnosisDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _icd = TextEditingController();
  final _date = TextEditingController();
  final _notes = TextEditingController();
  final _plan = TextEditingController();
  String _status = 'Active';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add Diagnosis', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Diagnosis Name *'),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _icd,
                  decoration: const InputDecoration(labelText: 'ICD-10 Code'),
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _date,
                  decoration: const InputDecoration(labelText: 'Diagnosed Date', hintText: 'YYYY-MM-DD'),
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _status,
                  dropdownColor: AppTheme.surface,
                  decoration: const InputDecoration(labelText: 'Status'),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  items: ['Active', 'Managed', 'Resolved', 'Monitoring']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _plan,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Follow-up Plan'),
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
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
                'title': _title.text,
                'icd_code': _icd.text,
                'diagnosed_date': _date.text,
                'status': _status,
                'notes': _notes.text,
                'follow_up_plan': _plan.text,
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.medical_information_outlined, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          const Text('No diagnoses recorded', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Add your medical conditions and follow-up plans', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Diagnosis'),
          ),
        ],
      ),
    );
  }
}

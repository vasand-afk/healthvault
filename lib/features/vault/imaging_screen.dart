import 'package:flutter/material.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/core/widgets/stat_card.dart';
import 'package:healthvault/core/database/database.dart';
import 'package:uuid/uuid.dart';

class ImagingScreen extends StatefulWidget {
  const ImagingScreen({super.key});
  @override
  State<ImagingScreen> createState() => _ImagingScreenState();
}

class _ImagingScreenState extends State<ImagingScreen> {
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('imaging_results', orderBy: 'date DESC');
    setState(() => _results = rows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart & Imaging'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog)],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CACScoreWidget(),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Imaging History'),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: _results.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            const Icon(Icons.favorite_border, size: 64, color: AppTheme.textSecondary),
                            const SizedBox(height: 16),
                            const Text('No imaging results', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(onPressed: _showAddDialog, icon: const Icon(Icons.add), label: const Text('Add Result')),
                          ],
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final r = _results[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: HvCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.favorite, color: AppTheme.danger, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(r['type'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                                          Text('${r['date']} • ${r['facility'] ?? ''}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    if (r['cac_score'] != null)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('${r['cac_score']}', style: const TextStyle(color: AppTheme.warning, fontSize: 20, fontWeight: FontWeight.w700)),
                                          const Text('CAC', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                        ],
                                      ),
                                  ],
                                ),
                                if (r['impression'] != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10)),
                                    child: Text(r['impression'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: _results.length,
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _showAddDialog() {
    showDialog(context: context, builder: (_) => _AddImagingDialog(onSave: (data) async {
      final db = await AppDatabase.instance;
      await db.insert('imaging_results', {
        'id': const Uuid().v4(),
        ...data,
        'created_at': DateTime.now().toIso8601String(),
      });
      _load();
    }));
  }
}

class _CACScoreWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: AppTheme.danger, size: 24),
              const SizedBox(width: 10),
              const Text('Coronary Artery Calcium', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _CACTier('0', 'None', AppTheme.accent),
              _CACTier('1–100', 'Mild', AppTheme.warning),
              _CACTier('101–400', 'Moderate', Color(0xFFFF8C00)),
              _CACTier('>400', 'Severe', AppTheme.danger),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Record your CAC score from a CT scan. Zero is optimal; score guides statin therapy decisions.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}

class _CACTier extends StatelessWidget {
  final String range;
  final String label;
  final Color color;
  const _CACTier(this.range, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(range, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _AddImagingDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const _AddImagingDialog({required this.onSave});
  @override
  State<_AddImagingDialog> createState() => _AddImagingDialogState();
}

class _AddImagingDialogState extends State<_AddImagingDialog> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'CAC Score (CT)';
  final _date = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _facility = TextEditingController();
  final _findings = TextEditingController();
  final _impression = TextEditingController();
  final _cac = TextEditingController();

  final _types = ['CAC Score (CT)', 'CCTA', 'Echocardiogram', 'Mammography', 'MRI', 'CT Scan', 'X-Ray', 'Ultrasound', 'PET Scan', 'Other'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add Imaging Result', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _type,
                  dropdownColor: AppTheme.surface,
                  decoration: const InputDecoration(labelText: 'Imaging Type *'),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _type = v!),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: _date, decoration: const InputDecoration(labelText: 'Date'), style: const TextStyle(color: AppTheme.textPrimary))),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _cac, decoration: const InputDecoration(labelText: 'CAC Score (if applicable)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: _facility, decoration: const InputDecoration(labelText: 'Facility'), style: const TextStyle(color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                TextFormField(controller: _findings, maxLines: 3, decoration: const InputDecoration(labelText: 'Findings'), style: const TextStyle(color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                TextFormField(controller: _impression, maxLines: 3, decoration: const InputDecoration(labelText: 'Impression / Summary'), style: const TextStyle(color: AppTheme.textPrimary)),
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
                'type': _type,
                'date': _date.text,
                'facility': _facility.text,
                'findings': _findings.text,
                'impression': _impression.text,
                'cac_score': double.tryParse(_cac.text),
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

import 'package:flutter/material.dart';
import 'package:vasan_health/core/database/database.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/core/widgets/stat_card.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const _indigo = Color(0xFF6366F1);

const _categories = [
  _OmicsCat('Single-Cell Omics', Icons.grid_on, Color(0xFF818CF8), 'scRNA-seq, scATAC-seq, spatial transcriptomics — cellular resolution of gene expression and chromatin state.'),
  _OmicsCat('Exposomics', Icons.public, Color(0xFF34D399), 'Total exposure measurement — environmental toxins, pollutants, microplastics, heavy metals, endocrine disruptors.'),
  _OmicsCat('Spatial Transcriptomics', Icons.map, Color(0xFFF472B6), 'Gene expression mapped to tissue location — identifies aging niches and disease microenvironments.'),
  _OmicsCat('Cell-Free DNA / Liquid Biopsy', Icons.water_drop, Color(0xFF60A5FA), 'cfDNA fragmentation patterns, methylation, and copy number changes — multi-cancer early detection.'),
  _OmicsCat('Glycomics / Glycome Age', Icons.grain, Color(0xFFFBBF24), 'N-glycan profiles from GlycanAge — inflammation-adjusted biological age from immunoglobulin glycosylation.'),
  _OmicsCat('Exosome / Extracellular Vesicles', Icons.bubble_chart, Color(0xFFF43F5E), 'Cargo in extracellular vesicles — tissue-specific aging signals, biomarkers of organ stress.'),
  _OmicsCat('Lipidomics', Icons.opacity, Color(0xFF10B981), 'Detailed lipid species profiling beyond standard lipids — ceramides, sphingomyelins, ether lipids.'),
  _OmicsCat('Proteogenomics', Icons.merge, Color(0xFFA855F7), 'Integration of proteomics + genomics — personalized protein expression quantitative trait loci (pQTL).'),
];

class OmicsOtherScreen extends StatefulWidget {
  const OmicsOtherScreen({super.key});
  @override
  State<OmicsOtherScreen> createState() => _OmicsOtherScreenState();
}

class _OmicsOtherScreenState extends State<OmicsOtherScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final e = await db.query('omics_other', where: "category != 'Transcriptomics'", orderBy: 'date DESC');
    if (mounted) setState(() => _entries = e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Other Advanced Omics'),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'My Data'), Tab(text: 'Modalities')]),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _add)],
      ),
      body: TabBarView(controller: _tabs, children: [
        _DataTab(entries: _entries, onAdd: _add, onDelete: _delete),
        _ModalitiesTab(),
      ]),
    );
  }

  Future<void> _add() async {
    await showDialog(context: context, builder: (_) => _AddEntryDialog(onSave: (row) async {
      final db = await AppDatabase.instance;
      await db.insert('omics_other', {'id': const Uuid().v4(), ...row, 'created_at': DateTime.now().toIso8601String()});
      _load();
    }));
  }

  Future<void> _delete(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('omics_other', where: 'id = ?', whereArgs: [id]);
    _load();
  }
}

class _DataTab extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final VoidCallback onAdd;
  final void Function(String) onDelete;
  const _DataTab({required this.entries, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.science, color: _indigo, size: 64),
        const SizedBox(height: 16),
        const Text('No advanced omics data', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Log single-cell results, exposomics panels, glycome age, liquid biopsy, and other cutting-edge tests.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add Entry'), style: ElevatedButton.styleFrom(backgroundColor: _indigo)),
      ]),
    ));

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in entries) {
      final cat = e['category'] as String? ?? 'Other';
      grouped.putIfAbsent(cat, () => []).add(e);
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final entry in grouped.entries) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: _indigo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(entry.key, style: const TextStyle(color: _indigo, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
        const SizedBox(height: 6),
        ...entry.value.map((e) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e['test_name'] as String? ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              Text(e['date'] as String? ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              if (e['notes'] != null && (e['notes'] as String).isNotEmpty) Text(e['notes'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontStyle: FontStyle.italic), maxLines: 2),
            ])),
            if (e['value'] != null) ...[
              Text('${e['value']} ${e['unit'] ?? ''}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 6),
            ],
            if (e['flag'] != null) StatusBadge(label: e['flag'] as String, color: e['flag'] == 'High' || e['flag'] == 'Elevated' ? AppTheme.warning : AppTheme.accent),
            const SizedBox(width: 6),
            GestureDetector(onTap: () => onDelete(e['id'] as String), child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 16)),
          ]),
        )),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 80),
    ]);
  }
}

class _ModalitiesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(0xFF0C0C2D), AppTheme.cardBg]),
          borderRadius: BorderRadius.circular(16), border: Border.all(color: _indigo.withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('FRONTIER OMICS TECHNOLOGIES', style: TextStyle(color: _indigo, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          SizedBox(height: 8),
          Text('These modalities represent the cutting edge of longevity medicine. Most are research-grade today but will be clinically available within 3–7 years. Track results now to build your longitudinal dataset.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 16),
      ..._categories.map((cat) => _ModalityCard(cat)),
      const SizedBox(height: 80),
    ]);
  }
}

class _ModalityCard extends StatelessWidget {
  final _OmicsCat cat;
  const _ModalityCard(this.cat);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: cat.color.withValues(alpha: 0.25)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: Icon(cat.icon, color: cat.color, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(cat.name, style: TextStyle(color: cat.color, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 4),
        Text(cat.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
      ])),
    ]),
  );
}

class _OmicsCat {
  final String name, description;
  final IconData icon;
  final Color color;
  const _OmicsCat(this.name, this.icon, this.color, this.description);
}

class _AddEntryDialog extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _AddEntryDialog({required this.onSave});
  @override
  State<_AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<_AddEntryDialog> {
  String _category = _categories.first.name;
  String _flag = 'Normal';
  final _test     = TextEditingController();
  final _value    = TextEditingController();
  final _unit     = TextEditingController();
  final _pct      = TextEditingController();
  final _provider = TextEditingController();
  final _notes    = TextEditingController();
  final _date     = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add Omics Result', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          value: _category, dropdownColor: AppTheme.surface,
          decoration: const InputDecoration(labelText: 'Modality *'),
          style: const TextStyle(color: AppTheme.textPrimary),
          items: _categories.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
          onChanged: (v) => setState(() => _category = v!),
        ),
        const SizedBox(height: 10),
        TextFormField(controller: _test, decoration: const InputDecoration(labelText: 'Test / Biomarker Name *'), style: const TextStyle(color: AppTheme.textPrimary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _value, decoration: const InputDecoration(labelText: 'Value / Result'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _pct, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Percentile'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(value: _flag, dropdownColor: AppTheme.surface, decoration: const InputDecoration(labelText: 'Flag'), style: const TextStyle(color: AppTheme.textPrimary), items: ['Normal', 'High', 'Low', 'Elevated', 'Detected', 'Not Detected'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(), onChanged: (v) => setState(() => _flag = v!))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _provider, decoration: const InputDecoration(labelText: 'Provider / Lab'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _date, decoration: const InputDecoration(labelText: 'Date'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes / Interpretation'), style: const TextStyle(color: AppTheme.textPrimary)),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _indigo),
          onPressed: _saving || _test.text.isEmpty ? null : () async {
            setState(() => _saving = true);
            await widget.onSave({
              'date': _date.text, 'category': _category, 'test_name': _test.text,
              'value': _value.text, 'unit': _unit.text,
              'percentile': double.tryParse(_pct.text), 'flag': _flag,
              'provider': _provider.text, 'notes': _notes.text,
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

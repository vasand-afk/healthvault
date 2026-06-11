import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:healthvault/core/database/database.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/core/widgets/stat_card.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const _violet = Color(0xFFA855F7);

const _panels = ['SomaScan 11K', 'SomaScan 7K', 'Olink Explore 3072', 'Olink Target 96', 'Proximity Extension Array', 'Mass Spectrometry Panel', 'Senescence Panel', 'SASP Panel', 'Custom'];

// Senescence / SASP biomarkers with normal ranges
const _senescenceMarkers = [
  _MarkerInfo('p16-INK4a (CDKN2A)', 'Senescent cell burden marker', 'pg/mL', 'Low'),
  _MarkerInfo('p21 (CDKN1A)', 'Cell cycle arrest, senescence', 'pg/mL', 'Low'),
  _MarkerInfo('GDF-15', 'Mitochondrial stress, aging', 'pg/mL', '<1200'),
  _MarkerInfo('IL-6', 'Pro-inflammatory SASP cytokine', 'pg/mL', '<3.0'),
  _MarkerInfo('IL-1β', 'SASP inflammasome cytokine', 'pg/mL', '<5.0'),
  _MarkerInfo('TNF-α', 'Inflammatory SASP cytokine', 'pg/mL', '<8.1'),
  _MarkerInfo('MMP-3', 'Matrix degradation, SASP', 'ng/mL', '<4.0'),
  _MarkerInfo('PAI-1 (SERPINE1)', 'Fibrinolysis, senescence', 'ng/mL', '<47'),
  _MarkerInfo('IGFBP-3', 'IGF axis, senescence suppressor', 'ng/mL', '3000–5000'),
  _MarkerInfo('TGF-β1', 'Fibrosis, SASP mediator', 'ng/mL', '<7.0'),
];

class ProteomicsScreen extends StatefulWidget {
  const ProteomicsScreen({super.key});
  @override
  State<ProteomicsScreen> createState() => _ProteomicsScreenState();
}

class _ProteomicsScreenState extends State<ProteomicsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _sen = [];
  String? _selectedPanel;
  List<String> _panels = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final all = await db.query('proteomics_results', orderBy: 'date DESC, panel_name, protein_name');
    final sen = await db.query('proteomics_results', where: "category = 'Senescence' OR category = 'SASP'", orderBy: 'date DESC, protein_name');
    final panelRows = await db.rawQuery('SELECT DISTINCT panel_name FROM proteomics_results');
    if (mounted) setState(() {
      _all = all;
      _sen = sen;
      _panels = panelRows.map((r) => r['panel_name'] as String).toList();
      _selectedPanel ??= _panels.isNotEmpty ? _panels.first : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proteomics & Senescence'),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'All Proteins'), Tab(text: 'Senescence'), Tab(text: 'Heatmap')]),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _addEntry)],
      ),
      body: TabBarView(controller: _tabs, children: [
        _AllProteinsTab(proteins: _all, panels: _panels, onDelete: _delete),
        _SenescenceTab(markers: _sen, onAdd: _addEntry),
        _HeatmapTab(proteins: _all, panels: _panels),
      ]),
    );
  }

  Future<void> _addEntry() async {
    await showDialog(context: context, builder: (_) => _AddProteinDialog(onSave: (row) async {
      final db = await AppDatabase.instance;
      await db.insert('proteomics_results', {'id': const Uuid().v4(), ...row, 'created_at': DateTime.now().toIso8601String()});
      _load();
    }));
  }

  Future<void> _delete(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('proteomics_results', where: 'id = ?', whereArgs: [id]);
    _load();
  }
}

class _AllProteinsTab extends StatelessWidget {
  final List<Map<String, dynamic>> proteins;
  final List<String> panels;
  final void Function(String) onDelete;
  const _AllProteinsTab({required this.proteins, required this.panels, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (proteins.isEmpty) return const _EmptyProteomics();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('${proteins.length} protein measurements across ${panels.length} panel(s)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      const SizedBox(height: 12),
      ...proteins.map((p) => _ProteinRow(p, onDelete: onDelete)),
      const SizedBox(height: 80),
    ]);
  }
}

class _ProteinRow extends StatelessWidget {
  final Map<String, dynamic> p;
  final void Function(String) onDelete;
  const _ProteinRow(this.p, {required this.onDelete});

  Color _flagColor(String? flag) {
    switch (flag) {
      case 'High': return AppTheme.danger;
      case 'Low': return AppTheme.primary;
      case 'Elevated': return AppTheme.warning;
      default: return AppTheme.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = (p['percentile'] as num?)?.toDouble();
    final flag = p['flag'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: flag != null && flag != 'Normal' ? _flagColor(flag).withValues(alpha: 0.35) : AppTheme.border),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p['protein_name'] as String? ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          Row(children: [
            if (p['panel_name'] != null) Text(p['panel_name'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            const SizedBox(width: 6),
            Text(p['date'] as String? ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ]),
          if (p['pathway'] != null) Text(p['pathway'] as String, style: const TextStyle(color: _violet, fontSize: 10)),
        ])),
        if (pct != null) SizedBox(width: 60, child: Column(children: [
          Text('${pct.toStringAsFixed(0)}th', style: TextStyle(color: pct > 80 ? AppTheme.danger : pct > 60 ? AppTheme.warning : AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 13)),
          const Text('pctile', style: TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: pct / 100, color: pct > 80 ? AppTheme.danger : pct > 60 ? AppTheme.warning : AppTheme.accent, backgroundColor: AppTheme.border, minHeight: 3, borderRadius: BorderRadius.circular(2)),
        ])),
        const SizedBox(width: 8),
        if (p['value'] != null) Text('${(p['value'] as num).toStringAsFixed(1)} ${p['unit'] ?? ''}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
        const SizedBox(width: 8),
        if (flag != null) StatusBadge(label: flag, color: _flagColor(flag)),
        const SizedBox(width: 6),
        GestureDetector(onTap: () => onDelete(p['id'] as String), child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 14)),
      ]),
    );
  }
}

class _SenescenceTab extends StatelessWidget {
  final List<Map<String, dynamic>> markers;
  final VoidCallback onAdd;
  const _SenescenceTab({required this.markers, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _violet.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: _violet.withValues(alpha: 0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('SASP — SENESCENCE-ASSOCIATED SECRETORY PHENOTYPE', style: TextStyle(color: _violet, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          SizedBox(height: 8),
          Text('Senescent cells secrete a cocktail of pro-inflammatory cytokines, growth factors, and proteases (SASP) that drive tissue dysfunction and aging. Elevated SASP markers indicate higher senescent cell burden.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 16),
      const Text('Reference Markers', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
      const SizedBox(height: 10),
      ..._senescenceMarkers.map((m) {
        final logged = markers.where((r) => (r['protein_name'] as String? ?? '').contains(m.name.split(' ').first)).toList();
        final latest = logged.isNotEmpty ? logged.first : null;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: latest != null && (latest['flag'] == 'High' || latest['flag'] == 'Elevated') ? AppTheme.warning.withValues(alpha: 0.4) : AppTheme.border),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
              Text(m.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              Text('Ref: ${m.reference}  ·  ${m.unit}', style: const TextStyle(color: _violet, fontSize: 10)),
            ])),
            if (latest != null) ...[
              Text('${(latest['value'] as num?)?.toStringAsFixed(1) ?? '—'} ${m.unit}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              StatusBadge(label: latest['flag'] as String? ?? 'OK', color: latest['flag'] == 'High' || latest['flag'] == 'Elevated' ? AppTheme.warning : AppTheme.accent),
            ] else
              StatusBadge(label: 'Not tested', color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          ]),
        );
      }),
      const SizedBox(height: 80),
    ]);
  }
}

class _HeatmapTab extends StatelessWidget {
  final List<Map<String, dynamic>> proteins;
  final List<String> panels;
  const _HeatmapTab({required this.proteins, required this.panels});

  @override
  Widget build(BuildContext context) {
    if (proteins.isEmpty) return const _EmptyProteomics();
    // Show BarChart of percentiles for proteins that have a percentile value
    final withPct = proteins.where((p) => p['percentile'] != null).take(20).toList();
    if (withPct.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('Add percentile values to proteins to see the heatmap visualization.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14), textAlign: TextAlign.center),
      ));
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Protein Percentile Heatmap', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
      const SizedBox(height: 4),
      const Text('Age-adjusted percentile rankings (>80th = flagged)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      const SizedBox(height: 16),
      SizedBox(
        height: withPct.length * 32.0 + 40,
        child: BarChart(BarChartData(
          barGroups: List.generate(withPct.length, (i) {
            final pct = (withPct[i]['percentile'] as num).toDouble();
            final Color barColor = pct > 80 ? AppTheme.danger : pct > 60 ? AppTheme.warning : AppTheme.accent;
            return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: pct, color: barColor, width: 14, borderRadius: BorderRadius.circular(4))]);
          }),
          groupsSpace: 6,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border, strokeWidth: 0.5)),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i >= withPct.length) return const SizedBox.shrink();
                final name = (withPct[i]['protein_name'] as String? ?? '').split(' ').first;
                return Transform.rotate(angle: -0.7, child: Text(name, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)));
              })),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, interval: 25,
              getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)))),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          maxY: 100,
        )),
      ),
      const SizedBox(height: 24),
      Row(children: [
        _Legend2(AppTheme.accent, '≤60th', 'Optimal'),
        const SizedBox(width: 16),
        _Legend2(AppTheme.warning, '61–80th', 'Borderline'),
        const SizedBox(width: 16),
        _Legend2(AppTheme.danger, '>80th', 'Elevated'),
      ]),
      const SizedBox(height: 80),
    ]);
  }
}

class _Legend2 extends StatelessWidget {
  final Color color;
  final String range, label;
  const _Legend2(this.color, this.range, this.label);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      Text(range, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
    ]),
  ]);
}

class _EmptyProteomics extends StatelessWidget {
  const _EmptyProteomics();
  @override
  Widget build(BuildContext context) => const Center(child: Padding(
    padding: EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.bubble_chart, color: _violet, size: 64),
      SizedBox(height: 16),
      Text('No proteomics data', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
      SizedBox(height: 8),
      Text('Add results from SomaScan, Olink, or senescence panels using the + button.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
    ]),
  ));
}

class _MarkerInfo {
  final String name, description, unit, reference;
  const _MarkerInfo(this.name, this.description, this.unit, this.reference);
}

class _AddProteinDialog extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _AddProteinDialog({required this.onSave});
  @override
  State<_AddProteinDialog> createState() => _AddProteinDialogState();
}

class _AddProteinDialogState extends State<_AddProteinDialog> {
  String _panel = _panels.first;
  String _category = 'General';
  final _protein   = TextEditingController();
  final _value     = TextEditingController();
  final _unit      = TextEditingController(text: 'pg/mL');
  final _pct       = TextEditingController();
  final _pathway   = TextEditingController();
  final _date      = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _provider  = TextEditingController();
  String _flag = 'Normal';
  bool _saving = false;

  static const _cats = ['General', 'Senescence', 'SASP', 'Inflammation', 'Cardiovascular', 'Metabolic', 'Neurological', 'Oncology'];
  static const _flags = ['Normal', 'High', 'Low', 'Elevated', 'Critical'];

  void _fillSenescence(String name, String unit, String pathway) {
    _protein.text = name;
    _unit.text = unit;
    _pathway.text = pathway;
    setState(() => _category = 'Senescence');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add Protein Result', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('QUICK FILL — SENESCENCE MARKERS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: _senescenceMarkers.take(6).map((m) => GestureDetector(
            onTap: () => _fillSenescence(m.name, m.unit, 'Senescence/SASP'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _violet.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _violet.withValues(alpha: 0.3))),
              child: Text(m.name.split(' ').first, style: const TextStyle(color: _violet, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          )).toList()),
        ])),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _panel, dropdownColor: AppTheme.surface, decoration: const InputDecoration(labelText: 'Panel *'), style: const TextStyle(color: AppTheme.textPrimary), items: _panels.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => setState(() => _panel = v!)),
        const SizedBox(height: 10),
        TextFormField(controller: _protein, decoration: const InputDecoration(labelText: 'Protein Name *'), style: const TextStyle(color: AppTheme.textPrimary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _value, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Value'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _pct, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Percentile (0–100)'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(value: _flag, dropdownColor: AppTheme.surface, decoration: const InputDecoration(labelText: 'Flag'), style: const TextStyle(color: AppTheme.textPrimary), items: _flags.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(), onChanged: (v) => setState(() => _flag = v!))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: _category, dropdownColor: AppTheme.surface, decoration: const InputDecoration(labelText: 'Category'), style: const TextStyle(color: AppTheme.textPrimary), items: _cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _category = v!))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _pathway, decoration: const InputDecoration(labelText: 'Pathway'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _date, decoration: const InputDecoration(labelText: 'Date'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _provider, decoration: const InputDecoration(labelText: 'Provider'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _violet),
          onPressed: _saving || _protein.text.isEmpty ? null : () async {
            setState(() => _saving = true);
            await widget.onSave({
              'date': _date.text, 'panel_name': _panel, 'provider': _provider.text,
              'protein_name': _protein.text, 'value': double.tryParse(_value.text),
              'unit': _unit.text, 'percentile': double.tryParse(_pct.text),
              'flag': _flag, 'pathway': _pathway.text, 'category': _category,
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

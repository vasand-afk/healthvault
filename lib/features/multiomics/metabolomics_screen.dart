import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:vasan_health/core/database/database.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/core/widgets/stat_card.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const _emerald = Color(0xFF10B981);
const _amber   = Color(0xFFF59E0B);

// Pathway groups for metabolomics
const _pathways = ['Energy Metabolism', 'Amino Acids', 'Lipids / Lipidomics', 'TCA Cycle', 'One-Carbon / Methylation', 'Gut Microbiome Metabolites', 'Oxylipins / Inflammation', 'Antioxidants', 'Hormones / Steroids', 'Other'];

// Gut microbiome keystone species with health associations
const _keystoneSpecies = [
  _Species('Akkermansia muciniphila', 'Gut barrier integrity, metabolic health, longevity', true),
  _Species('Faecalibacterium prausnitzii', 'Anti-inflammatory, butyrate producer, colon health', true),
  _Species('Lactobacillus spp.', 'Immune modulation, gut pH, lactic acid', true),
  _Species('Bifidobacterium spp.', 'Short-chain fatty acids, immune education', true),
  _Species('Roseburia intestinalis', 'Butyrate producer, anti-inflammatory', true),
  _Species('Prevotella copri', 'Linked to rheumatoid arthritis risk (context dependent)', false),
  _Species('Clostridium difficile', 'Opportunistic pathogen — low abundance expected', false),
  _Species('Ruminococcus gnavus', 'Mucosal inflammation when overgrown', false),
];

const _panels = ['Metabolon Global Metabolomics', 'Biocrates MxP Quant 500', 'Nightingale NMR', 'ION Biome (uBiome)', 'Viome Gut Intelligence', 'Genova GI Effects', 'Doctor\'s Data GI360', 'Mass Spec Panel', 'Custom'];

class MetabolomicsScreen extends StatefulWidget {
  const MetabolomicsScreen({super.key});
  @override
  State<MetabolomicsScreen> createState() => _MetabolomicsScreenState();
}

class _MetabolomicsScreenState extends State<MetabolomicsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _metabolites = [];
  List<Map<String, dynamic>> _microbiome = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final m = await db.query('metabolomics_results', orderBy: 'date DESC, pathway, metabolite');
    final g = await db.query('microbiome_snapshots', orderBy: 'date DESC');
    if (mounted) setState(() { _metabolites = m; _microbiome = g; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metabolomics & Microbiome'),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Metabolomics'), Tab(text: 'Microbiome')]),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _tabs.index == 0 ? _addMetabolite() : _addMicrobiome())],
      ),
      body: TabBarView(controller: _tabs, children: [
        _MetabolomicsTab(metabolites: _metabolites, onAdd: _addMetabolite, onDelete: _deleteMetabolite),
        _MicrobiomeTab(snapshots: _microbiome, onAdd: _addMicrobiome, onDelete: _deleteMicrobiome),
      ]),
    );
  }

  Future<void> _addMetabolite() async {
    await showDialog(context: context, builder: (_) => _AddMetaboliteDialog(onSave: (row) async {
      final db = await AppDatabase.instance;
      await db.insert('metabolomics_results', {'id': const Uuid().v4(), ...row, 'created_at': DateTime.now().toIso8601String()});
      _load();
    }));
  }

  Future<void> _deleteMetabolite(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('metabolomics_results', where: 'id = ?', whereArgs: [id]);
    _load();
  }

  Future<void> _addMicrobiome() async {
    await showDialog(context: context, builder: (_) => _AddMicrobiomeDialog(onSave: (row) async {
      final db = await AppDatabase.instance;
      await db.insert('microbiome_snapshots', {'id': const Uuid().v4(), ...row, 'created_at': DateTime.now().toIso8601String()});
      _load();
    }));
  }

  Future<void> _deleteMicrobiome(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('microbiome_snapshots', where: 'id = ?', whereArgs: [id]);
    _load();
  }
}

// ─── Metabolomics tab ────────────────────────────────────────────────────────

class _MetabolomicsTab extends StatelessWidget {
  final List<Map<String, dynamic>> metabolites;
  final VoidCallback onAdd;
  final void Function(String) onDelete;
  const _MetabolomicsTab({required this.metabolites, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (metabolites.isEmpty) return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.hub, color: _emerald, size: 56),
        const SizedBox(height: 16),
        const Text('No metabolomics data', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Add results from Metabolon, Biocrates, Nightingale NMR, or any metabolomics panel.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add Metabolite'), style: ElevatedButton.styleFrom(backgroundColor: _emerald)),
      ]),
    ));

    // Group by pathway
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final m in metabolites) {
      final pw = m['pathway'] as String? ?? 'Other';
      grouped.putIfAbsent(pw, () => []).add(m);
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('${metabolites.length} metabolites across ${grouped.length} pathway(s)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      const SizedBox(height: 12),
      for (final entry in grouped.entries) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: _emerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(entry.key, style: const TextStyle(color: _emerald, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.3)),
        ),
        const SizedBox(height: 6),
        ...entry.value.map((m) => _MetaboliteRow(m, onDelete: onDelete)),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 80),
    ]);
  }
}

class _MetaboliteRow extends StatelessWidget {
  final Map<String, dynamic> m;
  final void Function(String) onDelete;
  const _MetaboliteRow(this.m, {required this.onDelete});

  Color _flagColor(String? f) => f == 'High' ? AppTheme.danger : f == 'Low' ? AppTheme.primary : AppTheme.accent;

  @override
  Widget build(BuildContext context) {
    final pct = (m['percentile'] as num?)?.toDouble();
    final flag = m['flag'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: flag != null && flag != 'Normal' ? _flagColor(flag).withValues(alpha: 0.35) : AppTheme.border),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m['metabolite'] as String? ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
          Row(children: [
            if (m['panel_type'] != null) Text(m['panel_type'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            const SizedBox(width: 6),
            Text(m['date'] as String? ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ]),
        ])),
        if (pct != null) SizedBox(width: 55, child: Column(children: [
          Text('${pct.toStringAsFixed(0)}th', style: TextStyle(color: pct > 80 || pct < 20 ? AppTheme.warning : AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w700)),
          LinearProgressIndicator(value: pct / 100, color: pct > 80 ? AppTheme.danger : pct > 60 ? AppTheme.warning : _emerald, backgroundColor: AppTheme.border, minHeight: 3, borderRadius: BorderRadius.circular(2)),
        ])),
        const SizedBox(width: 8),
        if (m['value'] != null) Text('${(m['value'] as num).toStringAsFixed(2)} ${m['unit'] ?? ''}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
        const SizedBox(width: 6),
        if (flag != null && flag != 'Normal') StatusBadge(label: flag, color: _flagColor(flag)),
        const SizedBox(width: 4),
        GestureDetector(onTap: () => onDelete(m['id'] as String), child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 14)),
      ]),
    );
  }
}

// ─── Microbiome tab ──────────────────────────────────────────────────────────

class _MicrobiomeTab extends StatelessWidget {
  final List<Map<String, dynamic>> snapshots;
  final VoidCallback onAdd;
  final void Function(String) onDelete;
  const _MicrobiomeTab({required this.snapshots, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (snapshots.isEmpty) return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.bug_report, color: _amber, size: 56),
        const SizedBox(height: 16),
        const Text('No microbiome data', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Add gut microbiome results from Viome, Genova GI Effects, Doctor\'s Data, or uBiome.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add Snapshot'), style: ElevatedButton.styleFrom(backgroundColor: _amber)),
      ]),
    ));

    final latest = snapshots.first;
    final shannon = (latest['shannon_diversity'] as num?)?.toDouble();
    final fb = (latest['fb_ratio'] as num?)?.toDouble();
    final firmicutes = (latest['firmicutes_pct'] as num?)?.toDouble();
    final bacteroidetes = (latest['bacteroidetes_pct'] as num?)?.toDouble();
    final proteo = (latest['proteobacteria_pct'] as num?)?.toDouble();
    final actino = (latest['actinobacteria_pct'] as num?)?.toDouble();
    final gutAge = (latest['gut_age'] as num?)?.toDouble();
    final dysbiosis = (latest['dysbiosis_score'] as num?)?.toDouble();

    Color shannonColor = shannon == null ? AppTheme.textSecondary : shannon >= 3.5 ? _emerald : shannon >= 2.5 ? AppTheme.warning : AppTheme.danger;

    // Pie chart data for phylum composition
    final pieData = <PieChartSectionData>[];
    double other = 100;
    if (firmicutes != null) { pieData.add(PieChartSectionData(value: firmicutes, color: const Color(0xFF60A5FA), title: '${firmicutes.toStringAsFixed(0)}%', radius: 60, titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))); other -= firmicutes; }
    if (bacteroidetes != null) { pieData.add(PieChartSectionData(value: bacteroidetes, color: const Color(0xFF34D399), title: '${bacteroidetes.toStringAsFixed(0)}%', radius: 60, titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))); other -= bacteroidetes; }
    if (proteo != null && proteo > 1) { pieData.add(PieChartSectionData(value: proteo, color: AppTheme.danger, title: '${proteo.toStringAsFixed(0)}%', radius: 55, titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))); other -= proteo; }
    if (actino != null && actino > 1) { pieData.add(PieChartSectionData(value: actino, color: AppTheme.warning, title: '${actino.toStringAsFixed(0)}%', radius: 55, titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))); other -= actino; }
    if (other > 2) pieData.add(PieChartSectionData(value: other.clamp(0, 100), color: AppTheme.textSecondary.withValues(alpha: 0.4), title: '${other.clamp(0, 100).toStringAsFixed(0)}%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 9)));

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Latest snapshot hero card
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF0C2D1A), AppTheme.cardBg]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _emerald.withValues(alpha: 0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _emerald.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: _emerald.withValues(alpha: 0.4))), child: const Text('LATEST SNAPSHOT', style: TextStyle(color: _emerald, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1))),
            const Spacer(),
            Text(latest['date'] as String? ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Column(children: [
              Text(shannon != null ? shannon.toStringAsFixed(2) : '—', style: TextStyle(color: shannonColor, fontSize: 32, fontWeight: FontWeight.w800)),
              const Text('Shannon α-diversity', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              Text(shannon == null ? '' : shannon >= 3.5 ? 'Excellent diversity' : shannon >= 2.5 ? 'Moderate' : 'Low — intervention needed', style: TextStyle(color: shannonColor, fontSize: 10, fontWeight: FontWeight.w600)),
            ])),
            if (pieData.isNotEmpty) SizedBox(width: 120, height: 120, child: PieChart(PieChartData(sections: pieData, centerSpaceRadius: 28, sectionsSpace: 2))),
          ]),
          const SizedBox(height: 16),
          // Key metrics row
          Row(children: [
            if (fb != null) _MicroStat('F/B Ratio', fb.toStringAsFixed(1), fb > 3 ? AppTheme.warning : _emerald, 'Firmicutes/\nBacteroidetes'),
            if (gutAge != null) _MicroStat('Gut Age', '${gutAge.toStringAsFixed(0)} yrs', gutAge > 45 ? AppTheme.warning : _emerald, 'Microbiome\nbiological age'),
            if (dysbiosis != null) _MicroStat('Dysbiosis', dysbiosis.toStringAsFixed(1), dysbiosis > 2 ? AppTheme.danger : _emerald, 'Dysbiosis\nscore'),
            if (latest['species_richness'] != null) _MicroStat('Species', '${latest['species_richness']}', AppTheme.textPrimary, 'Total\nrichness'),
          ]),
          if (latest['provider'] != null) ...[const SizedBox(height: 8), Text('Provider: ${latest['provider']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))],
        ]),
      ),
      const SizedBox(height: 16),
      if (pieData.isNotEmpty) ...[
        const SectionHeader(title: 'Phylum Composition'),
        const SizedBox(height: 8),
        Row(children: [
          if (firmicutes != null) _PhylumTag('Firmicutes', firmicutes, const Color(0xFF60A5FA), 'Includes Lactobacillus, Clostridium. Elevated in obesity.'),
          const SizedBox(width: 8),
          if (bacteroidetes != null) _PhylumTag('Bacteroidetes', bacteroidetes, const Color(0xFF34D399), 'Includes Bacteroides, Prevotella. Key fiber digesters.'),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          if (proteo != null) _PhylumTag('Proteobacteria', proteo, AppTheme.danger, '>3% associated with gut inflammation.'),
          const SizedBox(width: 8),
          if (actino != null) _PhylumTag('Actinobacteria', actino, AppTheme.warning, 'Includes Bifidobacterium. Important for infant & adult immunity.'),
        ]),
        const SizedBox(height: 16),
      ],
      const SectionHeader(title: 'Keystone Species Reference'),
      const SizedBox(height: 8),
      ..._keystoneSpecies.map((s) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: s.beneficial ? _emerald.withValues(alpha: 0.25) : AppTheme.danger.withValues(alpha: 0.2))),
        child: Row(children: [
          Icon(s.beneficial ? Icons.check_circle_outline : Icons.warning_amber, color: s.beneficial ? _emerald : AppTheme.warning, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: TextStyle(color: s.beneficial ? _emerald : AppTheme.warning, fontWeight: FontWeight.w600, fontSize: 11, fontStyle: FontStyle.italic)),
            Text(s.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, height: 1.3)),
          ])),
        ]),
      )),
      const SizedBox(height: 16),
      if (snapshots.length > 1) ...[
        const SectionHeader(title: 'Previous Snapshots'),
        const SizedBox(height: 8),
        ...snapshots.skip(1).map((s) => _SnapshotRow(s, onDelete: onDelete)),
      ],
      const SizedBox(height: 80),
    ]);
  }
}

class _MicroStat extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  const _MicroStat(this.label, this.value, this.color, this.sub);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
    Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.w600)),
    Text(sub, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 8, height: 1.2), textAlign: TextAlign.center),
  ]));
}

class _PhylumTag extends StatelessWidget {
  final String name;
  final double pct;
  final Color color;
  final String tooltip;
  const _PhylumTag(this.name, this.pct, this.color, this.tooltip);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${pct.toStringAsFixed(1)}%', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
      Text(name, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
      const SizedBox(height: 3),
      Text(tooltip, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9, height: 1.3)),
    ]),
  ));
}

class _SnapshotRow extends StatelessWidget {
  final Map<String, dynamic> s;
  final void Function(String) onDelete;
  const _SnapshotRow(this.s, {required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final shannon = (s['shannon_diversity'] as num?)?.toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        const Icon(Icons.bug_report, color: _amber, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s['date'] as String? ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 12)),
          if (s['provider'] != null) Text(s['provider'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        ])),
        if (shannon != null) Text('Shannon: ${shannon.toStringAsFixed(2)}', style: TextStyle(color: shannon >= 3.0 ? _emerald : AppTheme.warning, fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(width: 8),
        GestureDetector(onTap: () => onDelete(s['id'] as String), child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 16)),
      ]),
    );
  }
}

class _Species {
  final String name, description;
  final bool beneficial;
  const _Species(this.name, this.description, this.beneficial);
}

// ─── Dialogs ─────────────────────────────────────────────────────────────────

class _AddMetaboliteDialog extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _AddMetaboliteDialog({required this.onSave});
  @override
  State<_AddMetaboliteDialog> createState() => _AddMetaboliteDialogState();
}

class _AddMetaboliteDialogState extends State<_AddMetaboliteDialog> {
  String _panel = _panels.first;
  String _pathway = _pathways.first;
  String _flag = 'Normal';
  final _metabolite = TextEditingController();
  final _value      = TextEditingController();
  final _unit       = TextEditingController();
  final _pct        = TextEditingController();
  final _date       = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _provider   = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add Metabolite', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: _panel, dropdownColor: AppTheme.surface, decoration: const InputDecoration(labelText: 'Panel *'), style: const TextStyle(color: AppTheme.textPrimary), items: _panels.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => setState(() => _panel = v!)),
        const SizedBox(height: 10),
        TextFormField(controller: _metabolite, decoration: const InputDecoration(labelText: 'Metabolite Name *'), style: const TextStyle(color: AppTheme.textPrimary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _value, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Value'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit', hintText: 'µM, nmol/L'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _pct, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Percentile'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(value: _flag, dropdownColor: AppTheme.surface, decoration: const InputDecoration(labelText: 'Flag'), style: const TextStyle(color: AppTheme.textPrimary), items: ['Normal', 'High', 'Low', 'Elevated', 'Deficient'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(), onChanged: (v) => setState(() => _flag = v!))),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: _pathway, dropdownColor: AppTheme.surface, decoration: const InputDecoration(labelText: 'Pathway'), style: const TextStyle(color: AppTheme.textPrimary), items: _pathways.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => setState(() => _pathway = v!)),
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
          style: ElevatedButton.styleFrom(backgroundColor: _emerald),
          onPressed: _saving || _metabolite.text.isEmpty ? null : () async {
            setState(() => _saving = true);
            await widget.onSave({
              'date': _date.text, 'panel_type': _panel, 'metabolite': _metabolite.text,
              'value': double.tryParse(_value.text), 'unit': _unit.text,
              'percentile': double.tryParse(_pct.text), 'flag': _flag,
              'pathway': _pathway, 'provider': _provider.text,
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AddMicrobiomeDialog extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _AddMicrobiomeDialog({required this.onSave});
  @override
  State<_AddMicrobiomeDialog> createState() => _AddMicrobiomeDialogState();
}

class _AddMicrobiomeDialogState extends State<_AddMicrobiomeDialog> {
  final _shannon    = TextEditingController();
  final _richness   = TextEditingController();
  final _firm       = TextEditingController();
  final _bact       = TextEditingController();
  final _proteo     = TextEditingController();
  final _actino     = TextEditingController();
  final _fbRatio    = TextEditingController();
  final _dysbiosis  = TextEditingController();
  final _gutAge     = TextEditingController();
  final _provider   = TextEditingController();
  final _notes      = TextEditingController();
  final _date       = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add Microbiome Snapshot', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: TextFormField(controller: _shannon, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Shannon Diversity *', hintText: '>3.5 = excellent'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _richness, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Species Richness', hintText: 'total OTUs/ASVs'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        const Text('Phylum Composition (%)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextFormField(controller: _firm, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Firmicutes %'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _bact, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bacteroidetes %'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _proteo, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Proteobacteria %'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _actino, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Actinobacteria %'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _fbRatio, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'F/B Ratio', hintText: 'Firmicutes/Bacteroidetes'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _dysbiosis, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Dysbiosis Score', hintText: '<2.0 = normal'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _gutAge, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Gut Microbiome Age', hintText: 'years (Viome)'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _provider, decoration: const InputDecoration(labelText: 'Provider'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _date, decoration: const InputDecoration(labelText: 'Date'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes'), style: const TextStyle(color: AppTheme.textPrimary)),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _emerald),
          onPressed: _saving || _shannon.text.isEmpty ? null : () async {
            setState(() => _saving = true);
            await widget.onSave({
              'date': _date.text, 'provider': _provider.text,
              'shannon_diversity': double.tryParse(_shannon.text),
              'species_richness': int.tryParse(_richness.text),
              'firmicutes_pct': double.tryParse(_firm.text),
              'bacteroidetes_pct': double.tryParse(_bact.text),
              'proteobacteria_pct': double.tryParse(_proteo.text),
              'actinobacteria_pct': double.tryParse(_actino.text),
              'fb_ratio': double.tryParse(_fbRatio.text),
              'dysbiosis_score': double.tryParse(_dysbiosis.text),
              'gut_age': double.tryParse(_gutAge.text),
              'notes': _notes.text,
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:healthvault/core/database/database.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/core/widgets/stat_card.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const _rose = Color(0xFFF43F5E);

const _scoreTypes = [
  _ScoreType('SenMayo Score', 'Expression of 125 senescence genes. Higher = more senescent cell burden. Published in Aging Cell 2021.', '0–100+', 'Lower is better'),
  _ScoreType('Sen-CAR Score', 'Senescence Core Aging Response — immune + senescence gene co-expression signature.', 'Z-score', 'Negative = less burden'),
  _ScoreType('p16-INK4a mRNA', 'Direct senescent cell load via CDKN2A expression. Used in clinical senolytic trials.', 'Relative expression', 'Lower is better'),
  _ScoreType('p21 mRNA', 'Cell cycle arrest gene CDKN1A expression — early senescence marker.', 'Relative expression', 'Lower is better'),
  _ScoreType('SenSignature-1', 'Broad 108-gene senescence transcriptomic score.', 'Normalized score', 'Lower is better'),
  _ScoreType('Inflammaging Score', 'Transcriptomic inflammation composite from NF-κB pathway genes.', 'Log-scale', 'Lower is better'),
  _ScoreType('SASP Expression Index', 'mRNA expression composite of 18 canonical SASP factors.', 'Fold change', 'Lower is better'),
  _ScoreType('Hallmarks of Aging Score', 'Multi-pathway composite across 9 aging hallmark gene sets.', '0–100', 'Lower is better'),
  _ScoreType('Other / Custom', '', '—', '—'),
];

// Classic senescence genes to track individually
const _senGenes = [
  'CDKN2A (p16)', 'CDKN1A (p21)', 'TP53', 'IL6', 'CXCL8 (IL-8)', 'VEGFA',
  'MMP3', 'MMP9', 'SERPINE1 (PAI-1)', 'IGFBP3', 'IGFBP7', 'CCL2 (MCP-1)',
  'CCL20', 'CXCL1', 'IL1B', 'TNFA', 'HMGB1', 'LMNB1 (decreased)', 'H2AX (γH2AX)',
];

class TranscriptomicsScreen extends StatefulWidget {
  const TranscriptomicsScreen({super.key});
  @override
  State<TranscriptomicsScreen> createState() => _TranscriptomicsScreenState();
}

class _TranscriptomicsScreenState extends State<TranscriptomicsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _scores = [];
  List<Map<String, dynamic>> _genes = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final scores = await db.query('senescence_scores', orderBy: 'date DESC');
    final genes = await db.query('omics_other', where: "category = 'Transcriptomics'", orderBy: 'date DESC');
    if (mounted) setState(() { _scores = scores; _genes = genes; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcriptomics & Senescence'),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Composite Scores'), Tab(text: 'Gene Expression')]),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _tabs.index == 0 ? _addScore() : _addGene())],
      ),
      body: TabBarView(controller: _tabs, children: [
        _ScoresTab(scores: _scores, onAdd: _addScore, onDelete: _deleteScore),
        _GenesTab(genes: _genes, onAdd: _addGene, onDelete: _deleteGene),
      ]),
    );
  }

  Future<void> _addScore() async {
    await showDialog(context: context, builder: (_) => _AddScoreDialog(onSave: (row) async {
      final db = await AppDatabase.instance;
      await db.insert('senescence_scores', {'id': const Uuid().v4(), ...row, 'created_at': DateTime.now().toIso8601String()});
      _load();
    }));
  }

  Future<void> _deleteScore(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('senescence_scores', where: 'id = ?', whereArgs: [id]);
    _load();
  }

  Future<void> _addGene() async {
    await showDialog(context: context, builder: (_) => _AddGeneDialog(onSave: (row) async {
      final db = await AppDatabase.instance;
      await db.insert('omics_other', {'id': const Uuid().v4(), ...row, 'created_at': DateTime.now().toIso8601String()});
      _load();
    }));
  }

  Future<void> _deleteGene(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('omics_other', where: 'id = ?', whereArgs: [id]);
    _load();
  }
}

class _ScoresTab extends StatelessWidget {
  final List<Map<String, dynamic>> scores;
  final VoidCallback onAdd;
  final void Function(String) onDelete;
  const _ScoresTab({required this.scores, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _rose.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: _rose.withValues(alpha: 0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('SENESCENT CELL BURDEN', style: TextStyle(color: _rose, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          SizedBox(height: 8),
          Text('Senescent cells are "zombie" cells that stop dividing but refuse to die. They secrete SASP factors that damage neighboring tissue and drive age-related disease. Transcriptomic scores quantify burden non-invasively from blood RNA.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5)),
          SizedBox(height: 8),
          Text('Senolytics (dasatinib + quercetin, fisetin) can clear these cells. Tracking scores over time validates treatment response.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4, fontStyle: FontStyle.italic)),
        ]),
      ),
      const SizedBox(height: 16),
      if (scores.isEmpty) ...[
        const SizedBox(height: 20),
        Center(child: Column(children: [
          const Icon(Icons.schema, color: _rose, size: 48),
          const SizedBox(height: 12),
          const Text('No scores recorded', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Add SenMayo, Sen-CAR, or any transcriptomic\nsenescence composite score.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add Score'), style: ElevatedButton.styleFrom(backgroundColor: _rose)),
        ])),
      ] else ...[
        const SectionHeader(title: 'Score History'),
        const SizedBox(height: 10),
        ...scores.map((s) => _ScoreCard(s, onDelete: onDelete)),
      ],
      const SizedBox(height: 24),
      const SectionHeader(title: 'Available Assays'),
      const SizedBox(height: 10),
      ..._scoreTypes.where((t) => t.description.isNotEmpty).map((t) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 3),
            Text(t.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4)),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(t.unit, style: const TextStyle(color: _rose, fontSize: 10, fontWeight: FontWeight.w600)),
            Text(t.interpret, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
          ]),
        ]),
      )),
      const SizedBox(height: 80),
    ]);
  }
}

class _ScoreCard extends StatelessWidget {
  final Map<String, dynamic> s;
  final void Function(String) onDelete;
  const _ScoreCard(this.s, {required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final val = (s['score_value'] as num?)?.toDouble();
    final pct = (s['percentile'] as num?)?.toDouble();
    final flagColor = pct != null ? (pct > 80 ? AppTheme.danger : pct > 60 ? AppTheme.warning : AppTheme.accent) : AppTheme.textSecondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_rose.withValues(alpha: 0.07), AppTheme.cardBg]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pct != null && pct > 80 ? _rose.withValues(alpha: 0.5) : AppTheme.border),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s['score_type'] as String? ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
          Text(s['date'] as String? ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          if (s['provider'] != null && (s['provider'] as String).isNotEmpty) Text(s['provider'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          if (s['interpretation'] != null && (s['interpretation'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(s['interpretation'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(val != null ? val.toStringAsFixed(1) : '—', style: TextStyle(color: flagColor, fontSize: 22, fontWeight: FontWeight.w800)),
          if (s['unit'] != null) Text(s['unit'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          if (pct != null) Text('${pct.toStringAsFixed(0)}th pct', style: TextStyle(color: flagColor, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(width: 10),
        GestureDetector(onTap: () => onDelete(s['id'] as String), child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 16)),
      ]),
    );
  }
}

class _GenesTab extends StatelessWidget {
  final List<Map<String, dynamic>> genes;
  final VoidCallback onAdd;
  final void Function(String) onDelete;
  const _GenesTab({required this.genes, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (genes.isEmpty) return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.schema, color: _rose, size: 48),
        const SizedBox(height: 16),
        const Text('No gene expression data', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Log individual gene expression levels from RNA-seq or qPCR results.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add Gene'), style: ElevatedButton.styleFrom(backgroundColor: _rose)),
      ]),
    ));

    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Key senescence genes to track: CDKN2A, CDKN1A, IL6, CXCL8, MMP3, SERPINE1', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.5)),
      const SizedBox(height: 12),
      ...genes.map((g) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g['test_name'] as String? ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            Text(g['date'] as String? ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ])),
          Text('${g['value'] ?? '—'} ${g['unit'] ?? ''}', style: const TextStyle(color: _rose, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          if (g['flag'] != null) StatusBadge(label: g['flag'] as String, color: g['flag'] == 'High' ? AppTheme.warning : AppTheme.accent),
          const SizedBox(width: 6),
          GestureDetector(onTap: () => onDelete(g['id'] as String), child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 14)),
        ]),
      )),
      const SizedBox(height: 80),
    ]);
  }
}

class _ScoreType {
  final String name, description, unit, interpret;
  const _ScoreType(this.name, this.description, this.unit, this.interpret);
}

// ─── Dialogs ─────────────────────────────────────────────────────────────────

class _AddScoreDialog extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _AddScoreDialog({required this.onSave});
  @override
  State<_AddScoreDialog> createState() => _AddScoreDialogState();
}

class _AddScoreDialogState extends State<_AddScoreDialog> {
  String _type = _scoreTypes.first.name;
  final _value       = TextEditingController();
  final _unit        = TextEditingController();
  final _pct         = TextEditingController();
  final _provider    = TextEditingController();
  final _interpret   = TextEditingController();
  final _date        = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final info = _scoreTypes.firstWhere((t) => t.name == _type, orElse: () => _scoreTypes.last);
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add Senescence Score', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: _type, dropdownColor: AppTheme.surface, decoration: const InputDecoration(labelText: 'Score Type *'), style: const TextStyle(color: AppTheme.textPrimary),
          items: _scoreTypes.map((t) => DropdownMenuItem(value: t.name, child: Text(t.name))).toList(),
          onChanged: (v) => setState(() { _type = v!; _unit.text = info.unit == '—' ? '' : info.unit; })),
        if (info.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _rose.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)), child: Text(info.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4))),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _value, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Score Value *'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _unit, decoration: InputDecoration(labelText: 'Unit', hintText: info.unit), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _pct, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age-adjusted Percentile'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _provider, decoration: const InputDecoration(labelText: 'Provider / Lab'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        TextFormField(controller: _interpret, maxLines: 2, decoration: const InputDecoration(labelText: 'Interpretation / Context'), style: const TextStyle(color: AppTheme.textPrimary)),
        const SizedBox(height: 10),
        TextFormField(controller: _date, decoration: const InputDecoration(labelText: 'Date'), style: const TextStyle(color: AppTheme.textPrimary)),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _rose),
          onPressed: _saving || _value.text.isEmpty ? null : () async {
            setState(() => _saving = true);
            await widget.onSave({
              'date': _date.text, 'score_type': _type,
              'score_value': double.tryParse(_value.text), 'unit': _unit.text,
              'percentile': double.tryParse(_pct.text), 'provider': _provider.text,
              'interpretation': _interpret.text,
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AddGeneDialog extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _AddGeneDialog({required this.onSave});
  @override
  State<_AddGeneDialog> createState() => _AddGeneDialogState();
}

class _AddGeneDialogState extends State<_AddGeneDialog> {
  String? _selectedGene;
  final _gene    = TextEditingController();
  final _value   = TextEditingController();
  final _unit    = TextEditingController(text: 'fold change');
  final _date    = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _notes   = TextEditingController();
  String _flag = 'Normal';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add Gene Expression', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('QUICK SELECT', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 5, children: _senGenes.take(10).map((g) => GestureDetector(
            onTap: () { setState(() { _selectedGene = g; _gene.text = g; }); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _selectedGene == g ? _rose.withValues(alpha: 0.2) : AppTheme.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: _selectedGene == g ? _rose : AppTheme.border)),
              child: Text(g, style: TextStyle(color: _selectedGene == g ? _rose : AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          )).toList()),
        ])),
        const SizedBox(height: 12),
        TextFormField(controller: _gene, decoration: const InputDecoration(labelText: 'Gene Name *'), style: const TextStyle(color: AppTheme.textPrimary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _value, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Expression Value'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _date, decoration: const InputDecoration(labelText: 'Date'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(value: _flag, dropdownColor: AppTheme.surface, decoration: const InputDecoration(labelText: 'Flag'), style: const TextStyle(color: AppTheme.textPrimary), items: ['Normal', 'High', 'Low', 'Elevated'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(), onChanged: (v) => setState(() => _flag = v!))),
        ]),
        const SizedBox(height: 10),
        TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes / Context'), style: const TextStyle(color: AppTheme.textPrimary)),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _rose),
          onPressed: _saving || _gene.text.isEmpty ? null : () async {
            setState(() => _saving = true);
            await widget.onSave({
              'date': _date.text, 'category': 'Transcriptomics',
              'test_name': _gene.text, 'value': _value.text,
              'unit': _unit.text, 'flag': _flag, 'notes': _notes.text,
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

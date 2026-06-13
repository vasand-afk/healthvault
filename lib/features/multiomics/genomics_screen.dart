import 'package:flutter/material.dart';
import 'package:vasan_health/core/database/database.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/core/widgets/stat_card.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const _cyan = Color(0xFF06B6D4);

// Epigenetic clocks catalog
const _clocks = [
  'GrimAge v2',
  'PhenoAge',
  'DunedinPACE',
  'Horvath (2013)',
  'Hannum',
  'PC-PhenoAge',
  'PC-GrimAge',
  'SkinBlood Clock',
  'DNAmTL (Telomere)',
  'GlycanAge',
  'InflammAge',
  'Other',
];

// Known longevity SNPs
const _snpPresets = [
  _SnpPreset('APOE', 'rs429358 / rs7412', 'Cardiovascular / Alzheimer\'s risk', 'Lipid metabolism'),
  _SnpPreset('MTHFR', 'rs1801133 (C677T)', 'Folate metabolism, methylation', 'Methyl cycle'),
  _SnpPreset('MTHFR', 'rs1801131 (A1298C)', 'Folate metabolism, methylation', 'Methyl cycle'),
  _SnpPreset('FOXO3', 'rs2802292', 'Longevity association', 'Insulin/IGF-1'),
  _SnpPreset('SIRT1', 'rs12778366', 'NAD+ metabolism, aging', 'Sirtuin pathway'),
  _SnpPreset('COMT', 'rs4680 (Val158Met)', 'Dopamine/stress response', 'Neurotransmitter'),
  _SnpPreset('ACE', 'rs4340 (I/D)', 'Blood pressure, athletic performance', 'RAAS'),
  _SnpPreset('ACTN3', 'rs1815739 (R577X)', 'Power vs endurance muscle fiber', 'Muscle'),
  _SnpPreset('VDR', 'rs2228570 (FokI)', 'Vitamin D receptor, immune function', 'Vitamin D'),
  _SnpPreset('BDNF', 'rs6265 (Val66Met)', 'Neuroplasticity, memory', 'Brain-derived NF'),
];

class GenomicsScreen extends StatefulWidget {
  const GenomicsScreen({super.key});
  @override
  State<GenomicsScreen> createState() => _GenomicsScreenState();
}

class _GenomicsScreenState extends State<GenomicsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _clocks = [];
  List<Map<String, dynamic>> _snps = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final c = await db.query('epigenetic_clocks', orderBy: 'date DESC');
    final s = await db.query('snp_variants', orderBy: 'category, gene');
    if (mounted) setState(() { _clocks = c; _snps = s; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Genomics & Epigenomics'),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Epigenetic Clocks'), Tab(text: 'SNP Variants')]),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _tabs.index == 0 ? _addClock() : _addSnp(),
          ),
        ],
      ),
      body: TabBarView(controller: _tabs, children: [
        _ClocksTab(clocks: _clocks, onAdd: _addClock, onDelete: _deleteClock),
        _SnpsTab(snps: _snps, onAdd: _addSnp, onDelete: _deleteSnp),
      ]),
    );
  }

  Future<void> _addClock() async {
    await showDialog(context: context, builder: (_) => _AddClockDialog(onSave: (row) async {
      final db = await AppDatabase.instance;
      await db.insert('epigenetic_clocks', {'id': const Uuid().v4(), ...row, 'created_at': DateTime.now().toIso8601String()});
      _load();
    }));
  }

  Future<void> _deleteClock(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('epigenetic_clocks', where: 'id = ?', whereArgs: [id]);
    _load();
  }

  Future<void> _addSnp() async {
    await showDialog(context: context, builder: (_) => _AddSnpDialog(onSave: (row) async {
      final db = await AppDatabase.instance;
      await db.insert('snp_variants', {'id': const Uuid().v4(), ...row, 'created_at': DateTime.now().toIso8601String()});
      _load();
    }));
  }

  Future<void> _deleteSnp(String id) async {
    final db = await AppDatabase.instance;
    await db.delete('snp_variants', where: 'id = ?', whereArgs: [id]);
    _load();
  }
}

// ─── Clocks tab ──────────────────────────────────────────────────────────────

class _ClocksTab extends StatelessWidget {
  final List<Map<String, dynamic>> clocks;
  final VoidCallback onAdd;
  final void Function(String) onDelete;
  const _ClocksTab({required this.clocks, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (clocks.isEmpty) return _Empty(
      icon: Icons.biotech, color: _cyan,
      title: 'No epigenetic clock results',
      body: 'Add results from GrimAge, DunedinPACE, PhenoAge, or any methylation clock.',
      onAdd: onAdd,
    );

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Explanation card
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _cyan.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: _cyan.withValues(alpha: 0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('ABOUT EPIGENETIC CLOCKS', style: TextStyle(color: _cyan, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          SizedBox(height: 8),
          Text('DNA methylation patterns change predictably with age. Second-generation clocks (GrimAge, PhenoAge) predict mortality risk. DunedinPACE measures your current pace of aging — 1.0 = average, >1.0 = faster than peers.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 16),
      ...clocks.map((c) => _ClockCard(c, onDelete: onDelete)),
      const SizedBox(height: 80),
    ]);
  }
}

class _ClockCard extends StatelessWidget {
  final Map<String, dynamic> c;
  final void Function(String) onDelete;
  const _ClockCard(this.c, {required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final bio = (c['biological_age'] as num?)?.toDouble();
    final chrono = (c['chronological_age'] as num?)?.toDouble();
    final pace = (c['pace_of_aging'] as num?)?.toDouble();
    final delta = (bio != null && chrono != null) ? bio - chrono : null;
    final deltaColor = delta == null ? AppTheme.textSecondary
        : delta <= -3 ? const Color(0xFF34D399)
        : delta <= 0  ? const Color(0xFF86EFAC)
        : delta <= 3  ? AppTheme.warning
        : AppTheme.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: delta != null && delta > 3 ? AppTheme.danger.withValues(alpha: 0.4) : AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _cyan.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Text(c['clock_name'] as String? ?? '', style: const TextStyle(color: _cyan, fontWeight: FontWeight.w700, fontSize: 12))),
          const Spacer(),
          Text(c['date'] as String? ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(width: 8),
          GestureDetector(onTap: () => onDelete(c['id'] as String), child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 16)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _ClockStat('Bio Age', bio != null ? '${bio.toStringAsFixed(1)} yrs' : '—', _cyan)),
          Expanded(child: _ClockStat('Chrono', chrono != null ? '${chrono.toStringAsFixed(0)} yrs' : '—', AppTheme.textSecondary)),
          if (delta != null) Expanded(child: _ClockStat('Delta', '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}', deltaColor)),
          if (pace != null) Expanded(child: _ClockStat('Pace', '${pace.toStringAsFixed(2)}×', pace > 1.05 ? AppTheme.warning : AppTheme.accent)),
        ]),
        if (c['provider'] != null && (c['provider'] as String).isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Provider: ${c['provider']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
        if (c['notes'] != null && (c['notes'] as String).isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(c['notes'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }
}

class _ClockStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ClockStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
    Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
  ]);
}

// ─── SNPs tab ────────────────────────────────────────────────────────────────

class _SnpsTab extends StatelessWidget {
  final List<Map<String, dynamic>> snps;
  final VoidCallback onAdd;
  final void Function(String) onDelete;
  const _SnpsTab({required this.snps, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (snps.isEmpty) return _Empty(
      icon: Icons.biotech, color: _cyan,
      title: 'No SNP variants recorded',
      body: 'Add key genetic variants from 23andMe, AncestryDNA, or whole genome sequencing.',
      onAdd: onAdd,
    );

    // Group by category
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final s in snps) {
      final cat = s['category'] as String? ?? 'Other';
      grouped.putIfAbsent(cat, () => []).add(s);
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _cyan.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: _cyan.withValues(alpha: 0.2))),
        child: const Text('Genetic variants are fixed at birth. Focus on environment & lifestyle to mitigate risk variants. High-risk variants inform screening frequency, not destiny.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
      ),
      const SizedBox(height: 16),
      for (final entry in grouped.entries) ...[
        SectionHeader(title: entry.key),
        const SizedBox(height: 8),
        ...entry.value.map((s) => _SnpCard(s, onDelete: onDelete)),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 80),
    ]);
  }
}

class _SnpCard extends StatelessWidget {
  final Map<String, dynamic> s;
  final void Function(String) onDelete;
  const _SnpCard(this.s, {required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final effect = s['effect'] as String? ?? '';
    final orVal = (s['odds_ratio'] as num?)?.toDouble();
    Color riskColor = orVal == null ? AppTheme.textSecondary : orVal >= 1.5 ? AppTheme.danger : orVal >= 1.2 ? AppTheme.warning : AppTheme.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Container(
          width: 40, height: 40, decoration: BoxDecoration(color: _cyan.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Text(s['gene'] as String? ?? '?', style: const TextStyle(color: _cyan, fontSize: 9, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(s['gene'] as String? ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(width: 6),
            if (s['rsid'] != null) Text(s['rsid'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ]),
          if (s['genotype'] != null) Text('Genotype: ${s['genotype']}  ·  Risk: ${s['risk_allele'] ?? '—'}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          if (effect.isNotEmpty) Text(effect, style: TextStyle(color: riskColor.withValues(alpha: 0.85), fontSize: 11), maxLines: 2),
        ])),
        if (orVal != null) Column(children: [
          Text('OR', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
          Text(orVal.toStringAsFixed(2), style: TextStyle(color: riskColor, fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
        const SizedBox(width: 8),
        GestureDetector(onTap: () => onDelete(s['id'] as String), child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 14)),
      ]),
    );
  }
}

// ─── Dialogs ─────────────────────────────────────────────────────────────────

class _AddClockDialog extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _AddClockDialog({required this.onSave});
  @override
  State<_AddClockDialog> createState() => _AddClockDialogState();
}

class _AddClockDialogState extends State<_AddClockDialog> {
  String _clockName = _clocks.first;
  final _bioAge   = TextEditingController();
  final _chrono   = TextEditingController();
  final _pace     = TextEditingController();
  final _date     = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _provider = TextEditingController();
  final _notes    = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add Epigenetic Clock Result', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          value: _clockName, dropdownColor: AppTheme.surface,
          decoration: const InputDecoration(labelText: 'Clock / Algorithm *'),
          style: const TextStyle(color: AppTheme.textPrimary),
          items: _clocks.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _clockName = v!),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _bioAge, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Biological Age *'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _chrono, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Chronological Age'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        if (_clockName.contains('DunedinPACE') || _clockName.contains('Pace'))
          TextFormField(controller: _pace, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'DunedinPACE value (e.g. 0.92)', hintText: '1.0 = average'), style: const TextStyle(color: AppTheme.textPrimary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _date, decoration: const InputDecoration(labelText: 'Date'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _provider, decoration: const InputDecoration(labelText: 'Provider / Lab'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes'), style: const TextStyle(color: AppTheme.textPrimary)),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _cyan),
          onPressed: _saving || _bioAge.text.isEmpty ? null : () async {
            setState(() => _saving = true);
            final bio = double.tryParse(_bioAge.text);
            final chrono = double.tryParse(_chrono.text);
            await widget.onSave({
              'date': _date.text,
              'clock_name': _clockName,
              'biological_age': bio,
              'chronological_age': chrono,
              'age_delta': (bio != null && chrono != null) ? bio - chrono : null,
              'pace_of_aging': double.tryParse(_pace.text),
              'provider': _provider.text,
              'notes': _notes.text,
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
        ),
      ],
    );
  }
}

class _AddSnpDialog extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _AddSnpDialog({required this.onSave});
  @override
  State<_AddSnpDialog> createState() => _AddSnpDialogState();
}

class _AddSnpDialogState extends State<_AddSnpDialog> {
  _SnpPreset? _preset;
  final _gene     = TextEditingController();
  final _rsid     = TextEditingController();
  final _genotype = TextEditingController();
  final _risk     = TextEditingController();
  final _effect   = TextEditingController();
  final _or       = TextEditingController();
  final _date     = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  String _category = 'Cardiovascular';
  bool _saving = false;

  static const _cats = ['Cardiovascular', 'Neurological', 'Metabolic', 'Cancer Risk', 'Longevity', 'Fitness', 'Nutrition', 'Other'];

  void _fillPreset(_SnpPreset p) {
    setState(() {
      _preset = p;
      _gene.text = p.gene;
      _rsid.text = p.rsid;
      _effect.text = p.effect;
      _category = p.category.contains('Cardio') ? 'Cardiovascular' : p.category.contains('Methyl') ? 'Metabolic' : p.category.contains('Insulin') ? 'Longevity' : 'Other';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add SNP Variant', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('QUICK FILL — COMMON VARIANTS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: _snpPresets.map((p) => GestureDetector(
              onTap: () => _fillPreset(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _preset == p ? _cyan.withValues(alpha: 0.2) : AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _preset == p ? _cyan : AppTheme.border),
                ),
                child: Text('${p.gene} (${p.rsid.split('/').first.trim()})', style: TextStyle(color: _preset == p ? _cyan : AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            )).toList()),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextFormField(controller: _gene, decoration: const InputDecoration(labelText: 'Gene *'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _rsid, decoration: const InputDecoration(labelText: 'rsID'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _genotype, decoration: const InputDecoration(labelText: 'Your Genotype', hintText: 'e.g. GG, AG, AA'), style: const TextStyle(color: AppTheme.textPrimary))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _risk, decoration: const InputDecoration(labelText: 'Risk Allele', hintText: 'e.g. G'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        TextFormField(controller: _effect, maxLines: 2, decoration: const InputDecoration(labelText: 'Effect / Association'), style: const TextStyle(color: AppTheme.textPrimary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            value: _category, dropdownColor: AppTheme.surface,
            decoration: const InputDecoration(labelText: 'Category'),
            style: const TextStyle(color: AppTheme.textPrimary),
            items: _cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _category = v!),
          )),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _or, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Odds Ratio', hintText: 'e.g. 1.43'), style: const TextStyle(color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        TextFormField(controller: _date, decoration: const InputDecoration(labelText: 'Date Tested'), style: const TextStyle(color: AppTheme.textPrimary)),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _cyan),
          onPressed: _saving || _gene.text.isEmpty ? null : () async {
            setState(() => _saving = true);
            await widget.onSave({
              'date': _date.text,
              'gene': _gene.text,
              'rsid': _rsid.text,
              'genotype': _genotype.text,
              'risk_allele': _risk.text,
              'effect': _effect.text,
              'odds_ratio': double.tryParse(_or.text),
              'category': _category,
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, body;
  final VoidCallback onAdd;
  const _Empty({required this.icon, required this.color, required this.title, required this.body, required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color.withValues(alpha: 0.4), size: 64),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(body, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add Entry'), style: ElevatedButton.styleFrom(backgroundColor: _cyan)),
    ]),
  ));
}

class _SnpPreset {
  final String gene, rsid, effect, category;
  const _SnpPreset(this.gene, this.rsid, this.effect, this.category);
}

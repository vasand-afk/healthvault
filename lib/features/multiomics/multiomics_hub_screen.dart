import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:healthvault/core/database/database.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/core/widgets/stat_card.dart';
import 'package:healthvault/features/multiomics/genomics_screen.dart';
import 'package:healthvault/features/multiomics/proteomics_screen.dart';
import 'package:healthvault/features/multiomics/transcriptomics_screen.dart';
import 'package:healthvault/features/multiomics/metabolomics_screen.dart';
import 'package:healthvault/features/multiomics/omics_other_screen.dart';

// ─── Color palette for omics domain ─────────────────────────────────────────
const _genomicsColor    = Color(0xFF06B6D4);   // cyan
const _proteomicsColor  = Color(0xFFA855F7);   // violet
const _transcriptColor  = Color(0xFFF43F5E);   // rose
const _metabolomicsColor= Color(0xFF10B981);   // emerald
const _microbiomeColor  = Color(0xFFF59E0B);   // amber
const _otherColor       = Color(0xFF6366F1);   // indigo

class MultiOmicsHubScreen extends StatefulWidget {
  const MultiOmicsHubScreen({super.key});
  @override
  State<MultiOmicsHubScreen> createState() => _MultiOmicsHubScreenState();
}

class _MultiOmicsHubScreenState extends State<MultiOmicsHubScreen> {
  // Latest summary values pulled from DB
  double? _latestBioAge;
  double? _latestChronoAge;
  double? _latestDunedinPace;
  double? _latestSenScore;
  double? _latestShannon;
  int _clockCount = 0;
  int _proteinCount = 0;
  int _metaboliteCount = 0;
  List<FlSpot> _bioAgeSpots = [];
  List<FlSpot> _chronoSpots = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;

    // Epigenetic clocks
    final clocks = await db.query('epigenetic_clocks', orderBy: 'date DESC');
    _clockCount = clocks.length;
    if (clocks.isNotEmpty) {
      final latest = clocks.first;
      _latestBioAge = (latest['biological_age'] as num?)?.toDouble();
      _latestChronoAge = (latest['chronological_age'] as num?)?.toDouble();
      _latestDunedinPace = (latest['pace_of_aging'] as num?)?.toDouble();

      // Build chart spots (up to 8 most recent)
      final chartRows = clocks.reversed.take(8).toList();
      _bioAgeSpots = List.generate(chartRows.length, (i) {
        final v = (chartRows[i]['biological_age'] as num?)?.toDouble() ?? 0;
        return FlSpot(i.toDouble(), v);
      });
      _chronoSpots = List.generate(chartRows.length, (i) {
        final v = (chartRows[i]['chronological_age'] as num?)?.toDouble() ?? 0;
        return FlSpot(i.toDouble(), v);
      });
    }

    // Senescence
    final sen = await db.query('senescence_scores', orderBy: 'date DESC', limit: 1);
    if (sen.isNotEmpty) _latestSenScore = (sen.first['score_value'] as num?)?.toDouble();

    // Microbiome
    final micro = await db.query('microbiome_snapshots', orderBy: 'date DESC', limit: 1);
    if (micro.isNotEmpty) _latestShannon = (micro.first['shannon_diversity'] as num?)?.toDouble();

    // Counts
    final proteins = await db.query('proteomics_results', distinct: true, columns: ['protein_name']);
    _proteinCount = proteins.length;
    final mets = await db.query('metabolomics_results', distinct: true, columns: ['metabolite']);
    _metaboliteCount = mets.length;

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final delta = (_latestBioAge != null && _latestChronoAge != null)
        ? _latestBioAge! - _latestChronoAge!
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Omics'),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), tooltip: 'About multi-omics', onPressed: _showAbout),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHero(delta)),
            SliverToBoxAdapter(child: _buildAgeChart()),
            SliverToBoxAdapter(child: _buildRadarCard()),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: const SectionHeader(title: 'Omics Domains'),
            )),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3,
                ),
                delegate: SliverChildListDelegate(_buildDomainCards(context)),
              ),
            ),
            SliverToBoxAdapter(child: _buildAlertsCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(double? delta) {
    final Color deltaColor = delta == null ? AppTheme.textSecondary
        : delta <= -3 ? const Color(0xFF34D399)
        : delta <= 0  ? const Color(0xFF6EE7B7)
        : delta <= 3  ? AppTheme.warning
        : AppTheme.danger;

    final String deltaLabel = delta == null ? 'No data yet'
        : delta > 0 ? '+${delta.toStringAsFixed(1)} yrs older' : '${delta.abs().toStringAsFixed(1)} yrs younger';

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [const Color(0xFF0C1445), const Color(0xFF1A0533)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _genomicsColor.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: _genomicsColor.withValues(alpha: 0.12), blurRadius: 30, spreadRadius: 2)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _genomicsColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: _genomicsColor.withValues(alpha: 0.4))),
            child: Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: _genomicsColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('ADVANCED BIOMARKERS', style: TextStyle(color: _genomicsColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            ]),
          ),
          const Spacer(),
          if (_clockCount > 0) Text('$_clockCount clock readings', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Biological Age', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(
                _latestBioAge != null ? _latestBioAge!.toStringAsFixed(1) : '—',
                style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800, height: 1),
              ),
              if (_latestBioAge != null) const Text(' yrs', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            ]),
            if (_latestChronoAge != null)
              Text('Chronological: ${_latestChronoAge!.toStringAsFixed(0)} yrs', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ])),
          if (delta != null) Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: deltaColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: deltaColor.withValues(alpha: 0.5)),
            ),
            child: Column(children: [
              Text(delta > 0 ? '▲' : '▼', style: TextStyle(color: deltaColor, fontSize: 18, height: 1)),
              Text(deltaLabel, style: TextStyle(color: deltaColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _MiniStat('Pace', _latestDunedinPace != null ? '${_latestDunedinPace!.toStringAsFixed(2)}×' : '—',
              _latestDunedinPace != null && _latestDunedinPace! > 1.0 ? AppTheme.warning : AppTheme.accent, 'DunedinPACE'),
          const SizedBox(width: 12),
          _MiniStat('Senescence', _latestSenScore != null ? '${_latestSenScore!.toStringAsFixed(0)}' : '—',
              _proteomicsColor, 'SenMayo score'),
          const SizedBox(width: 12),
          _MiniStat('Diversity', _latestShannon != null ? _latestShannon!.toStringAsFixed(2) : '—',
              _metabolomicsColor, 'Shannon α'),
        ]),
      ]),
    );
  }

  Widget _buildAgeChart() {
    if (_bioAgeSpots.isEmpty) return const SizedBox.shrink();
    final allY = [..._bioAgeSpots.map((s) => s.y), ..._chronoSpots.map((s) => s.y)];
    final minY = (allY.reduce(math.min) - 3).clamp(0, 200).toDouble();
    final maxY = allY.reduce(math.max) + 3;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Biological Age Timeline', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          _Legend(_genomicsColor, 'Bio Age'),
          const SizedBox(width: 12),
          _Legend(AppTheme.textSecondary.withValues(alpha: 0.5), 'Chrono'),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: LineChart(LineChartData(
            minY: minY, maxY: maxY,
            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 5,
              getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border, strokeWidth: 0.5)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(spots: _bioAgeSpots, isCurved: true, color: _genomicsColor, barWidth: 3,
                belowBarData: BarAreaData(show: true, color: _genomicsColor.withValues(alpha: 0.1)),
                dotData: FlDotData(show: true, getDotPainter: (s, _, __, ___) => FlDotCirclePainter(radius: 4, color: _genomicsColor, strokeWidth: 0))),
              LineChartBarData(spots: _chronoSpots, isCurved: false, color: AppTheme.textSecondary.withValues(alpha: 0.4),
                barWidth: 1.5, dashArray: [4, 4], dotData: FlDotData(show: false)),
            ],
          )),
        ),
      ]),
    );
  }

  Widget _buildRadarCard() {
    // Radar chart: 5 axes = epigenomics, proteomics, transcriptomics, metabolomics, microbiome
    // Score 0-10 for each (10=optimal). Derived from available data, default 5 if no data.
    final hasClocks = _clockCount > 0;
    final hasProteins = _proteinCount > 0;
    final hasMets = _metaboliteCount > 0;
    final hasMicro = _latestShannon != null;
    final hasSen = _latestSenScore != null;

    if (!hasClocks && !hasProteins && !hasMets && !hasMicro && !hasSen) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
        child: Column(children: [
          const Icon(Icons.radar, color: AppTheme.textSecondary, size: 40),
          const SizedBox(height: 12),
          const Text('Omics Constellation', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Add data across all 5 omics domains to see your multi-omics radar profile', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4), textAlign: TextAlign.center),
        ]),
      );
    }

    final delta = (_latestBioAge != null && _latestChronoAge != null) ? _latestBioAge! - _latestChronoAge! : 0.0;
    double epiScore = hasClocks ? (10 - (delta.abs() * 0.8)).clamp(0, 10) : 5;
    double protScore = hasProteins ? 7.0 : 5;
    double senScore = hasSen ? (10 - (_latestSenScore! / 10).clamp(0, 10)) : 5;
    double metScore = hasMets ? 6.5 : 5;
    double microScore = hasMicro ? ((_latestShannon! / 4.5) * 10).clamp(0, 10) : 5;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppTheme.cardBg, const Color(0xFF0C1445).withValues(alpha: 0.5)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Omics Constellation', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 4),
        const Text('Multi-domain biological health profile', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: RadarChart(RadarChartData(
            radarShape: RadarShape.polygon,
            tickCount: 4,
            ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 0),
            radarBorderData: const BorderSide(color: Colors.transparent),
            gridBorderData: BorderSide(color: AppTheme.border.withValues(alpha: 0.5), width: 0.5),
            tickBorderData: BorderSide(color: AppTheme.border.withValues(alpha: 0.3), width: 0.5),
            getTitle: (index, angle) {
              final labels = ['Epigenomics', 'Proteomics', 'Senescence', 'Metabolomics', 'Microbiome'];
              final colors = [_genomicsColor, _proteomicsColor, _transcriptColor, _metabolomicsColor, _microbiomeColor];
              return RadarChartTitle(text: labels[index], angle: angle,
                positionPercentageOffset: 0.1);
            },
            dataSets: [
              RadarDataSet(
                fillColor: _genomicsColor.withValues(alpha: 0.15),
                borderColor: _genomicsColor,
                borderWidth: 2,
                entryRadius: 4,
                dataEntries: [epiScore, protScore, senScore, metScore, microScore]
                    .map((v) => RadarEntry(value: v))
                    .toList(),
              ),
            ],
          )),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _RadarLegend('Epi', epiScore, _genomicsColor),
          _RadarLegend('Prot', protScore, _proteomicsColor),
          _RadarLegend('Sen', senScore, _transcriptColor),
          _RadarLegend('Met', metScore, _metabolomicsColor),
          _RadarLegend('Micro', microScore, _microbiomeColor),
        ]),
      ]),
    );
  }

  List<Widget> _buildDomainCards(BuildContext context) => [
    _DomainCard(
      icon: Icons.biotech,
      color: _genomicsColor,
      title: 'Genomics &\nEpigenomics',
      subtitle: 'Epigenetic clocks, SNPs, telomeres',
      tags: const ['GrimAge', 'DunedinPACE', 'APOE', 'MTHFR'],
      count: _clockCount > 0 ? '$_clockCount readings' : 'No data',
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GenomicsScreen())).then((_) => _load()),
    ),
    _DomainCard(
      icon: Icons.bubble_chart,
      color: _proteomicsColor,
      title: 'Proteomics &\nSenescence',
      subtitle: 'SomaScan, Olink, SASP panels',
      tags: const ['p16', 'GDF-15', 'IL-6', 'SomaScan'],
      count: _proteinCount > 0 ? '$_proteinCount proteins' : 'No data',
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProteomicsScreen())).then((_) => _load()),
    ),
    _DomainCard(
      icon: Icons.schema,
      color: _transcriptColor,
      title: 'Transcriptomics &\nSenescence Scores',
      subtitle: 'SenMayo, Sen-CAR, gene expression',
      tags: const ['SenMayo', 'Sen-CAR', 'p21', 'CDKN1A'],
      count: _latestSenScore != null ? 'Score: ${_latestSenScore!.toStringAsFixed(0)}' : 'No data',
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TranscriptomicsScreen())).then((_) => _load()),
    ),
    _DomainCard(
      icon: Icons.hub,
      color: _metabolomicsColor,
      title: 'Metabolomics &\nMicrobiome',
      subtitle: 'Metabolite panels, gut diversity',
      tags: const ['Shannon', 'F/B ratio', 'TMA/TMAO', 'Butyrate'],
      count: _latestShannon != null ? 'α-div: ${_latestShannon!.toStringAsFixed(2)}' : 'No data',
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MetabolomicsScreen())).then((_) => _load()),
    ),
    _DomainCard(
      icon: Icons.science,
      color: _otherColor,
      title: 'Other Advanced\nOmics',
      subtitle: 'Single-cell, exposomics, spatial',
      tags: const ['scRNA-seq', 'Exposomics', 'Spatial TX', 'cfDNA'],
      count: 'Cutting edge',
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OmicsOtherScreen())).then((_) => _load()),
    ),
  ];

  Widget _buildAlertsCard() {
    final alerts = <_Alert>[];
    final delta = (_latestBioAge != null && _latestChronoAge != null) ? _latestBioAge! - _latestChronoAge! : null;
    if (delta != null && delta > 5) alerts.add(_Alert(AppTheme.danger, Icons.warning_amber, 'Biological age ${delta.toStringAsFixed(1)} years ahead of chronological — consider high-priority intervention review with AI Coach.'));
    if (delta != null && delta < -3) alerts.add(_Alert(_genomicsColor, Icons.star, 'Excellent — biological age ${(-delta).toStringAsFixed(1)} years younger than chronological. Keep up current protocols.'));
    if (_latestDunedinPace != null && _latestDunedinPace! > 1.1) alerts.add(_Alert(AppTheme.warning, Icons.speed, 'DunedinPACE ${_latestDunedinPace!.toStringAsFixed(2)} — aging at faster than normal pace. Focus: sleep, stress, caloric restriction.'));
    if (_latestShannon != null && _latestShannon! < 2.5) alerts.add(_Alert(AppTheme.warning, Icons.bug_report, 'Gut diversity (Shannon ${_latestShannon!.toStringAsFixed(2)}) below healthy range (>3.0). Consider prebiotic/probiotic intervention.'));
    if (alerts.isEmpty && _clockCount == 0) alerts.add(_Alert(_genomicsColor, Icons.add_circle_outline, 'Start by adding an epigenetic clock result to see your biological age profile.'));

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(title: 'Insights & Alerts'),
        const SizedBox(height: 12),
        ...alerts.map((a) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: a.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: a.color.withValues(alpha: 0.3)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(a.icon, color: a.color, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(a.text, style: TextStyle(color: a.color.withValues(alpha: 0.9), fontSize: 13, height: 1.4))),
          ]),
        )),
      ]),
    );
  }

  void _showAbout() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('About Multi-Omics', style: TextStyle(color: AppTheme.textPrimary)),
      content: const SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Multi-omics integrates data across multiple biological layers to give a complete picture of biological aging and health.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
        SizedBox(height: 16),
        _AboutRow('Genomics/Epigenomics', 'DNA methylation clocks measure how your cells have aged. DunedinPACE measures speed of aging in real time.'),
        _AboutRow('Proteomics', 'Thousands of proteins measured simultaneously reveal disease risk, organ function, and biological age.'),
        _AboutRow('Transcriptomics', 'Gene expression panels like SenMayo quantify senescent cell burden — zombie cells that drive aging.'),
        _AboutRow('Metabolomics', 'Small molecules reveal metabolic health, micronutrient status, and gut-derived compounds.'),
        _AboutRow('Microbiome', 'Gut bacterial diversity is strongly linked to immune function, metabolism, and longevity.'),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ));
  }
}

class _Alert {
  final Color color;
  final IconData icon;
  final String text;
  const _Alert(this.color, this.icon, this.text);
}

class _MiniStat extends StatelessWidget {
  final String label, value, subLabel;
  final Color color;
  const _MiniStat(this.label, this.value, this.color, this.subLabel);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.25))),
    child: Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 10, fontWeight: FontWeight.w600)),
      Text(subLabel, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
    ]),
  ));
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
  ]);
}

class _RadarLegend extends StatelessWidget {
  final String label;
  final double score;
  final Color color;
  const _RadarLegend(this.label, this.score, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(score.toStringAsFixed(1), style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
    Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
  ]);
}

class _DomainCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle, count;
  final List<String> tags;
  final VoidCallback onTap;
  const _DomainCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.count, required this.tags, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.12), AppTheme.cardBg]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
          const Spacer(),
          Icon(Icons.arrow_forward_ios, color: color.withValues(alpha: 0.5), size: 12),
        ]),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 12, height: 1.2)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, height: 1.3), maxLines: 2),
        const Spacer(),
        Wrap(spacing: 4, runSpacing: 3, children: tags.map((t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Text(t, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
        )).toList()),
        const SizedBox(height: 6),
        Text(count, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _AboutRow extends StatelessWidget {
  final String title, body;
  const _AboutRow(this.title, this.body);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 2),
      Text(body, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
    ]),
  );
}

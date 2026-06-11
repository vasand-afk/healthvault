import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/core/widgets/stat_card.dart';
import 'package:healthvault/features/multiomics/multiomics_hub_screen.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = [
      _VaultSection(
        icon: Icons.medical_information,
        color: AppTheme.danger,
        title: 'Medical Diagnoses',
        subtitle: 'Conditions, follow-up plans & appointments',
        count: '3 active',
        path: '/vault/diagnoses',
      ),
      _VaultSection(
        icon: Icons.biotech,
        color: AppTheme.warning,
        title: 'Lab Results',
        subtitle: 'Blood work, urine, stool & specialty panels',
        count: '12 results',
        path: '/vault/labs',
      ),
      _VaultSection(
        icon: Icons.favorite,
        color: AppTheme.danger,
        title: 'Heart Imaging',
        subtitle: 'CAC score, CCTA, echocardiogram',
        count: '2 scans',
        path: '/vault/imaging',
      ),
      _VaultSection(
        icon: Icons.accessibility_new,
        color: AppTheme.secondary,
        title: 'Body Composition',
        subtitle: 'DEXA, InBody, hydrostatic weighing',
        count: '4 scans',
        path: '/vault/body-comp',
      ),
      _VaultSection(
        icon: Icons.watch,
        color: AppTheme.primary,
        title: 'Wearable Data',
        subtitle: 'Apple Watch, Oura, Garmin, Whoop',
        count: 'Syncing',
        path: '/vault/wearable',
      ),
      _VaultSection(
        icon: Icons.biotech,
        color: AppTheme.accent,
        title: 'Genetic Data',
        subtitle: '23andMe, AncestryDNA, Whole Genome',
        count: '1 report',
        path: '/vault/genetics',
      ),
      _VaultSection(
        icon: Icons.image,
        color: AppTheme.warning,
        title: 'Mammography',
        subtitle: 'Screening and diagnostic mammograms',
        count: '1 result',
        path: '/vault/mammography',
      ),
    ];


    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => context.go('/import'),
            tooltip: 'Import data',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _VaultSummaryBar(),
                  const SizedBox(height: 24),
                  const _MultiOmicsEntry(),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Medical Records'),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _VaultCard(section: sections[i]),
                childCount: sections.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _VaultSummaryBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.danger.withValues(alpha: 0.15), AppTheme.secondary.withValues(alpha: 0.15)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, color: AppTheme.accent, size: 32),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Encrypted & Private', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                SizedBox(height: 2),
                Text('All data stored locally on your device. Never shared without your consent.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultSection {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String count;
  final String path;
  const _VaultSection({
    required this.icon, required this.color, required this.title,
    required this.subtitle, required this.count, required this.path,
  });
}

// Multi-Omics hero entry — sits above the standard medical records
class _MultiOmicsEntry extends StatelessWidget {
  const _MultiOmicsEntry();

  static const _cyan   = Color(0xFF06B6D4);
  static const _violet = Color(0xFFA855F7);
  static const _rose   = Color(0xFFF43F5E);
  static const _emerald= Color(0xFF10B981);
  static const _amber  = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MultiOmicsHubScreen())),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0C1445), Color(0xFF1A0533)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cyan.withValues(alpha: 0.4)),
          boxShadow: [BoxShadow(color: _cyan.withValues(alpha: 0.12), blurRadius: 24, spreadRadius: 0, offset: const Offset(0, 6))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _cyan.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: _cyan.withValues(alpha: 0.4))),
              child: Row(children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: _cyan, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('ADVANCED BIOMARKERS', style: TextStyle(color: _cyan, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              ]),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFF475569), size: 14),
          ]),
          const SizedBox(height: 14),
          const Text('Multi-Omics Data Vault', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          const Text('Biological aging beyond standard labs', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          const SizedBox(height: 14),
          Row(children: [
            _OmicsChip('DNA Methylation\nClocks', _cyan),
            const SizedBox(width: 8),
            _OmicsChip('Proteomics\np16 · GDF-15', _violet),
            const SizedBox(width: 8),
            _OmicsChip('Senescence\nSenMayo', _rose),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _OmicsChip('Metabolomics\nMicrobiome', _emerald),
            const SizedBox(width: 8),
            _OmicsChip('Single-Cell\nExposomics', _amber),
          ]),
        ]),
      ),
    );
  }
}

class _OmicsChip extends StatelessWidget {
  final String label;
  final Color color;
  const _OmicsChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600, height: 1.3)),
  );
}

class _VaultCard extends StatelessWidget {
  final _VaultSection section;
  const _VaultCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(section.path),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: section.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(section.icon, color: section.color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(section.subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(label: section.count, color: section.color),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

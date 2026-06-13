import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/core/widgets/stat_card.dart';

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

class _MultiOmicsEntry extends StatelessWidget {
  const _MultiOmicsEntry();

  static const _cyan = Color(0xFF06B6D4);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cyan.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cyan.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.science_outlined, color: _cyan, size: 20),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Advanced Biomarkers', style: TextStyle(color: _cyan, fontWeight: FontWeight.w600, fontSize: 13)),
            SizedBox(height: 2),
            Text('Multi-omics, proteomics & biological aging clocks', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: _cyan.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: const Text('Coming Soon', style: TextStyle(color: _cyan, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
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

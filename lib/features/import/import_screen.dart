import 'package:flutter/material.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/core/widgets/stat_card.dart';
import 'package:healthvault/features/import/apple_health_import_screen.dart';
import 'package:healthvault/features/import/lab_csv_import_screen.dart';
import 'package:healthvault/features/import/oura_csv_import_screen.dart';
import 'package:healthvault/features/import/pdf_upload_screen.dart';
import 'package:healthvault/features/import/garmin_csv_import_screen.dart';
import 'package:healthvault/features/import/strava_import_screen.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Data')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primary, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All imported data is stored locally and encrypted on your device.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const SectionHeader(title: 'Wearables & Apps'),
            const SizedBox(height: 14),
            _ImportTile(
              icon: Icons.watch,
              color: AppTheme.primary,
              title: 'Apple Health',
              subtitle: 'Import steps, heart rate, sleep, workouts, HRV, SpO₂, weight, and body fat',
              status: 'ZIP or XML export from iPhone Health app',
              badge: 'Ready',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppleHealthImportScreen())),
            ),
            _ImportTile(
              icon: Icons.circle_outlined,
              color: Color(0xFF6366F1),
              title: 'Oura Ring',
              subtitle: 'Import sleep scores, HRV, temperature, and readiness data',
              status: 'CSV export from Oura app',
              badge: 'Ready',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OuraCsvImportScreen())),
            ),
            _ImportTile(
              icon: Icons.gps_fixed,
              color: AppTheme.accent,
              title: 'Garmin Connect',
              subtitle: 'Activities, VO2 max, sleep, stress scores',
              status: 'CSV export from Garmin Connect website',
              badge: 'Ready',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GarminCsvImportScreen())),
            ),
            _ImportTile(
              icon: Icons.monitor_heart,
              color: AppTheme.danger,
              title: 'Whoop',
              subtitle: 'Strain, recovery, sleep performance data',
              status: 'CSV export from Whoop app',
              onTap: () {},
            ),
            const SizedBox(height: 28),
            const SectionHeader(title: 'Lab & Medical Records'),
            const SizedBox(height: 14),
            _ImportTile(
              icon: Icons.biotech,
              color: AppTheme.warning,
              title: 'Lab Results (CSV)',
              subtitle: 'Import from Quest, LabCorp, Function Health, InsideTracker, Everlywell, or any spreadsheet',
              status: 'CSV, TSV, or TXT — any column order',
              badge: 'Ready',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LabCsvImportScreen())),
            ),
            _ImportTile(
              icon: Icons.description,
              color: AppTheme.secondary,
              title: 'PDF Medical Reports',
              subtitle: 'Upload imaging reports, DEXA scans, pathology results',
              status: 'PDF, JPG, PNG supported',
              badge: 'Ready',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfUploadScreen())),
            ),
            _ImportTile(
              icon: Icons.local_hospital,
              color: AppTheme.danger,
              title: 'FHIR / Epic MyChart',
              subtitle: 'Import medical records from hospital systems via FHIR API',
              status: 'Coming soon',
              onTap: null,
            ),
            const SizedBox(height: 28),
            const SectionHeader(title: 'Fitness & Nutrition'),
            const SizedBox(height: 14),
            _ImportTile(
              icon: Icons.directions_run,
              color: AppTheme.warning,
              title: 'Strava',
              subtitle: 'Import running, cycling, and activity history',
              status: 'Full data archive export (ZIP or activities.csv)',
              badge: 'Ready',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StravaImportScreen())),
            ),
            _ImportTile(
              icon: Icons.restaurant,
              color: AppTheme.accent,
              title: 'MyFitnessPal',
              subtitle: 'Import food diary and nutrition history',
              status: 'CSV export from MFP account',
              onTap: () {},
            ),
            _ImportTile(
              icon: Icons.biotech,
              color: Color(0xFF14B8A6),
              title: 'Genetic Data (23andMe / AncestryDNA)',
              subtitle: 'Import raw genetic data for variant analysis',
              status: 'Raw DNA file (txt/zip)',
              onTap: () {},
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _ImportTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String status;
  final String? badge;
  final VoidCallback? onTap;
  const _ImportTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.status, this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isComingSoon = status == 'Coming soon';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isComingSoon ? AppTheme.cardBg.withValues(alpha: 0.6) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isComingSoon ? AppTheme.border.withValues(alpha: 0.5) : AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isComingSoon ? 0.08 : 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: isComingSoon ? color.withValues(alpha: 0.5) : color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isComingSoon ? AppTheme.textSecondary : AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 2),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.info_outline, size: 11, color: color.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(status, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
                  ]),
                ],
              ),
            ),
            if (badge != null)
              StatusBadge(label: badge!, color: AppTheme.accent)
            else if (onTap != null)
              Icon(Icons.upload, color: color, size: 20)
            else
              const StatusBadge(label: 'Soon', color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

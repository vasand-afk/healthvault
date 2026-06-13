import 'dart:async';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vasan_health/core/database/database.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/features/import/apple_health_parser.dart';
import 'package:uuid/uuid.dart';

class AppleHealthImportScreen extends StatefulWidget {
  const AppleHealthImportScreen({super.key});

  @override
  State<AppleHealthImportScreen> createState() => _AppleHealthImportScreenState();
}

class _AppleHealthImportScreenState extends State<AppleHealthImportScreen> {
  _ImportState _state = _ImportState.idle;
  String _statusMessage = '';
  double _progress = 0;
  ParseResult? _result;
  String? _error;

  // counts after DB insert
  int _insertedWearable = 0;
  int _insertedSleep = 0;
  int _insertedActivities = 0;
  int _insertedBodyComp = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Apple Health'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InstructionsCard(),
            const SizedBox(height: 28),
            if (_state == _ImportState.idle) _PickFileButton(onPick: _pickAndImport),
            if (_state == _ImportState.picking || _state == _ImportState.parsing || _state == _ImportState.inserting)
              _ProgressCard(message: _statusMessage, progress: _progress),
            if (_state == _ImportState.done && _result != null) _ResultCard(
              result: _result!,
              wearable: _insertedWearable,
              sleep: _insertedSleep,
              activities: _insertedActivities,
              bodyComp: _insertedBodyComp,
              onImportMore: () => setState(() => _state = _ImportState.idle),
            ),
            if (_state == _ImportState.error) _ErrorCard(message: _error ?? 'Unknown error', onRetry: () => setState(() => _state = _ImportState.idle)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndImport() async {
    setState(() { _state = _ImportState.picking; _statusMessage = 'Selecting file…'; _progress = 0; });

    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'xml'],
        withData: true,
      );

      if (picked == null || picked.files.isEmpty) {
        setState(() => _state = _ImportState.idle);
        return;
      }

      final file = picked.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() { _state = _ImportState.error; _error = 'Could not read file bytes. Try again.'; });
        return;
      }

      setState(() { _state = _ImportState.parsing; _statusMessage = 'Reading file…'; _progress = 0.05; });

      String xmlContent;

      if (file.extension?.toLowerCase() == 'zip') {
        setState(() { _statusMessage = 'Extracting ZIP…'; _progress = 0.1; });
        xmlContent = await compute<Uint8List, String>(_extractXmlFromZip, bytes);
      } else {
        xmlContent = String.fromCharCodes(bytes);
      }

      setState(() { _statusMessage = 'Parsing health records (this may take a minute)…'; _progress = 0.15; });

      // Parse on a background isolate via compute
      final result = await compute<String, ParseResult>(_parseXml, xmlContent);

      setState(() {
        _result = result;
        _statusMessage = 'Saving ${result.totalRecords} records to database…';
        _progress = 0.7;
        _state = _ImportState.inserting;
      });

      await _insertToDatabase(result);

      setState(() {
        _state = _ImportState.done;
        _statusMessage = 'Import complete';
        _progress = 1.0;
      });
    } catch (e) {
      setState(() {
        _state = _ImportState.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _insertToDatabase(ParseResult result) async {
    final db = await AppDatabase.instance;
    const uuid = Uuid();
    int wearable = 0, sleep = 0, activities = 0, bodyComp = 0;

    // Wearable data — skip existing dates
    for (final row in result.wearableData) {
      final existing = await db.query('wearable_data', where: 'date = ? AND source = ?', whereArgs: [row['date'], 'Apple Health'], limit: 1);
      if (existing.isEmpty) {
        await db.insert('wearable_data', {
          'id': uuid.v4(),
          ...row,
          'created_at': DateTime.now().toIso8601String(),
        });
        wearable++;
      }
    }
    setState(() { _insertedWearable = wearable; _progress = 0.8; _statusMessage = 'Saving sleep data…'; });

    // Sleep logs
    for (final row in result.sleepLogs) {
      final existing = await db.query('sleep_logs', where: 'date = ?', whereArgs: [row['date']], limit: 1);
      if (existing.isEmpty) {
        await db.insert('sleep_logs', {
          'id': uuid.v4(),
          ...row,
          'created_at': DateTime.now().toIso8601String(),
        });
        sleep++;
      }
    }
    setState(() { _insertedSleep = sleep; _progress = 0.87; _statusMessage = 'Saving activities…'; });

    // Activities
    for (final row in result.activities) {
      await db.insert('activities', {
        'id': uuid.v4(),
        ...row,
        'created_at': DateTime.now().toIso8601String(),
      });
      activities++;
    }
    setState(() { _insertedActivities = activities; _progress = 0.94; _statusMessage = 'Saving body composition…'; });

    // Body compositions
    for (final row in result.bodyComps) {
      final existing = await db.query('body_compositions', where: 'date = ? AND scan_type = ?', whereArgs: [row['date'], 'Apple Health'], limit: 1);
      if (existing.isEmpty && row['weight_kg'] != null) {
        await db.insert('body_compositions', {
          'id': uuid.v4(),
          ...row,
          'created_at': DateTime.now().toIso8601String(),
        });
        bodyComp++;
      }
    }
    setState(() { _insertedBodyComp = bodyComp; _progress = 1.0; });
  }
}

// These run in isolates via compute()
String _extractXmlFromZip(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  for (final file in archive) {
    if (file.name == 'apple_health_export/export.xml' || file.name.endsWith('export.xml')) {
      return String.fromCharCodes(file.content as List<int>);
    }
  }
  throw Exception('export.xml not found in ZIP. Make sure you selected the Apple Health export ZIP.');
}

ParseResult _parseXml(String xmlContent) {
  return AppleHealthParser.parse(xmlContent);
}

// ---- UI Widgets ----

enum _ImportState { idle, picking, parsing, inserting, done, error }

class _InstructionsCard extends StatelessWidget {
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
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.watch, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            const Text('How to export from iPhone', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
          ]),
          const SizedBox(height: 16),
          ...[
            ('1', 'Open the Health app on your iPhone'),
            ('2', 'Tap your profile photo (top right)'),
            ('3', 'Scroll down → tap "Export All Health Data"'),
            ('4', 'Confirm export — this may take a few minutes'),
            ('5', 'Share the resulting ZIP to your Mac (AirDrop, iCloud Drive, email, etc.)'),
            ('6', 'Come back here and tap "Select File" — choose the ZIP or the XML inside it'),
          ].map((step) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(step.$1, style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(step.$2, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4))),
              ],
            ),
          )).toList(),
          const Divider(height: 24),
          const Text('What gets imported', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(Icons.directions_walk, 'Steps', AppTheme.accent),
              _Tag(Icons.favorite, 'Heart Rate', AppTheme.danger),
              _Tag(Icons.monitor_heart, 'HRV', AppTheme.secondary),
              _Tag(Icons.air, 'SpO₂', AppTheme.primary),
              _Tag(Icons.bedtime, 'Sleep stages', AppTheme.secondary),
              _Tag(Icons.directions_run, 'Workouts', AppTheme.accent),
              _Tag(Icons.local_fire_department, 'Active calories', AppTheme.warning),
              _Tag(Icons.monitor_weight, 'Weight', AppTheme.textSecondary),
              _Tag(Icons.accessibility_new, 'Body fat %', AppTheme.warning),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Tag(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _PickFileButton extends StatelessWidget {
  final VoidCallback onPick;
  const _PickFileButton({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: onPick,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upload_file, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text('Select Export File', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Accepts .zip (Apple Health export) or export.xml', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String message;
  final double progress;
  const _ProgressCard({required this.message, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
            const SizedBox(width: 14),
            Expanded(child: Text(message, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500))),
          ]),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.surface,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text('${(progress * 100).toInt()}%', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          const Text('Large exports (5+ years) can take 1–3 minutes. Please wait.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ParseResult result;
  final int wearable, sleep, activities, bodyComp;
  final VoidCallback onImportMore;
  const _ResultCard({required this.result, required this.wearable, required this.sleep, required this.activities, required this.bodyComp, required this.onImportMore});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.check_circle, color: AppTheme.accent, size: 22)),
            const SizedBox(width: 14),
            const Expanded(child: Text('Import complete!', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18))),
          ]),
          const SizedBox(height: 20),
          const Text('Records imported:', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 12),
          _ResultRow(Icons.watch, 'Wearable days (steps, HR, HRV, SpO₂)', wearable, AppTheme.primary),
          _ResultRow(Icons.bedtime, 'Sleep nights', sleep, AppTheme.secondary),
          _ResultRow(Icons.directions_run, 'Workouts & activities', activities, AppTheme.accent),
          _ResultRow(Icons.monitor_weight, 'Body composition entries', bodyComp, AppTheme.warning),
          const SizedBox(height: 20),
          const Text('Your data is now available across all HealthVault modules — Dashboard, Sleep, Fitness, and Wearable sections.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onImportMore,
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary, side: const BorderSide(color: AppTheme.primary)),
                child: const Text('Import Another File'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go to Dashboard'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  const _ResultRow(this.icon, this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ]),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.error_outline, color: AppTheme.danger, size: 22),
            const SizedBox(width: 10),
            const Text('Import failed', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger), child: const Text('Try Again')),
        ],
      ),
    );
  }
}

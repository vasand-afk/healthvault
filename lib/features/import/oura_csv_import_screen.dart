import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:healthvault/core/database/database.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/core/widgets/stat_card.dart';
import 'package:uuid/uuid.dart';

class OuraCsvImportScreen extends StatefulWidget {
  const OuraCsvImportScreen({super.key});
  @override
  State<OuraCsvImportScreen> createState() => _OuraCsvImportScreenState();
}

enum _Step { instructions, preview, done, error }

class _OuraCsvImportScreenState extends State<OuraCsvImportScreen> {
  _Step _step = _Step.instructions;
  List<Map<String, dynamic>> _parsed = [];
  String? _error;
  bool _importing = false;
  int _inserted = 0;
  String _detectedType = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Oura Data'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: switch (_step) {
          _Step.instructions => _InstructionsView(onPick: _pickAndParse),
          _Step.preview      => _PreviewView(rows: _parsed, type: _detectedType, importing: _importing, onImport: _doImport, onBack: () => setState(() => _step = _Step.instructions)),
          _Step.done         => _DoneView(inserted: _inserted, type: _detectedType, onMore: () => setState(() { _step = _Step.instructions; _parsed = []; _inserted = 0; })),
          _Step.error        => _ErrorView(message: _error!, onRetry: () => setState(() => _step = _Step.instructions)),
        },
      ),
    );
  }

  Future<void> _pickAndParse() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;

      final bytes = picked.files.first.bytes;
      if (bytes == null) throw Exception('Could not read file.');
      final content = utf8.decode(bytes, allowMalformed: true);

      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length < 2) throw Exception('File too short — needs a header row and data.');

      final headers = _parseLine(lines.first).map((h) => h.trim().replaceAll('"', '')).toList();
      final rows = lines.skip(1).map((l) {
        final cells = _parseLine(l);
        return Map.fromIterables(headers, List.generate(headers.length, (i) => i < cells.length ? cells[i].trim().replaceAll('"', '') : ''));
      }).where((r) => r.values.any((v) => v.isNotEmpty)).toList();

      // Detect which Oura export this is
      final type = _detectType(headers);
      if (type == 'unknown') throw Exception('Could not identify this as an Oura export.\n\nExpected sleep, activity, or readiness data.\nHeaders found: ${headers.take(6).join(', ')}…');

      final parsed = rows.map((r) => _parseRow(r, type)).where((r) => r != null).cast<Map<String, dynamic>>().toList();
      if (parsed.isEmpty) throw Exception('No valid rows found in this file.');

      setState(() { _parsed = parsed; _detectedType = type; _step = _Step.preview; });
    } catch (e) {
      setState(() { _error = e.toString(); _step = _Step.error; });
    }
  }

  List<String> _parseLine(String line) {
    final result = <String>[];
    bool inQuote = false;
    final buf = StringBuffer();
    for (final ch in line.split('')) {
      if (ch == '"') { inQuote = !inQuote; continue; }
      if (ch == ',' && !inQuote) { result.add(buf.toString()); buf.clear(); continue; }
      buf.write(ch);
    }
    result.add(buf.toString());
    return result;
  }

  String _detectType(List<String> headers) {
    final h = headers.map((e) => e.toLowerCase()).toList();
    if (h.any((e) => e.contains('sleep') && (e.contains('score') || e.contains('duration')))) return 'sleep';
    if (h.any((e) => e.contains('readiness'))) return 'readiness';
    if (h.any((e) => e.contains('activity') && e.contains('score'))) return 'activity';
    if (h.any((e) => e.contains('steps') || e.contains('cal') && e.contains('active'))) return 'activity';
    if (h.any((e) => e.contains('hrv') && e.contains('average'))) return 'sleep';
    return 'unknown';
  }

  Map<String, dynamic>? _parseRow(Map<String, String> r, String type) {
    String? _f(List<String> keys) {
      for (final k in keys) {
        for (final entry in r.entries) {
          if (entry.key.toLowerCase().contains(k.toLowerCase()) && entry.value.isNotEmpty) return entry.value;
        }
      }
      return null;
    }

    double? _d(List<String> keys) => double.tryParse(_f(keys) ?? '');
    int? _i(List<String> keys) => int.tryParse(_f(keys) ?? '');

    final date = _f(['date']) ?? '';
    if (date.isEmpty) return null;

    if (type == 'sleep') {
      final totalMin = _d(['total sleep duration', 'total sleep', 'sleep duration']);
      final deepMin  = _d(['deep sleep duration', 'deep sleep']);
      final remMin   = _d(['rem sleep duration', 'rem sleep', 'rem duration']);
      final lightMin = _d(['light sleep duration', 'light sleep']);
      final awakeMin = _d(['awake time', 'awake duration', 'awake']);

      // Oura sometimes reports in seconds
      double? toHours(double? v) {
        if (v == null) return null;
        return v > 600 ? v / 3600 : v / 60;  // if > 600 assume seconds else minutes
      }

      return {
        'date': date,
        'total_hours': toHours(totalMin),
        'deep_hours': toHours(deepMin),
        'rem_hours': toHours(remMin),
        'light_hours': toHours(lightMin),
        'awake_hours': toHours(awakeMin),
        'sleep_score': _i(['sleep score', 'score']),
        'hrv_avg': _d(['hrv average', 'hrv avg', 'average hrv', 'hrv']),
        'resting_hr': _d(['resting heart rate', 'resting hr', 'lowest hr', 'hr lowest']),
        'bedtime': _f(['bedtime start', 'bedtime']),
        'wake_time': _f(['bedtime end', 'wake', 'wakeup']),
        'temperature_deviation': _d(['temperature deviation', 'temp deviation', 'temperature delta']),
      };
    }

    if (type == 'activity') {
      return {
        'date': date,
        'source': 'Oura',
        'steps': _i(['steps']),
        'active_calories': _d(['active calories', 'active cal', 'calories burned']),
        'resting_hr': _d(['resting heart rate', 'resting hr']),
      };
    }

    // readiness → wearable data
    return {
      'date': date,
      'source': 'Oura',
      'hrv': _d(['hrv balance', 'hrv average', 'hrv']),
      'resting_hr': _d(['resting heart rate', 'resting hr']),
    };
  }

  Future<void> _doImport() async {
    setState(() => _importing = true);
    final db = await AppDatabase.instance;
    const uuid = Uuid();
    int count = 0;

    if (_detectedType == 'sleep') {
      for (final row in _parsed) {
        final existing = await db.query('sleep_logs', where: 'date = ?', whereArgs: [row['date']], limit: 1);
        if (existing.isEmpty) {
          await db.insert('sleep_logs', {'id': uuid.v4(), ...row, 'created_at': DateTime.now().toIso8601String()});
          count++;
        }
      }
    } else {
      for (final row in _parsed) {
        final existing = await db.query('wearable_data', where: 'date = ? AND source = ?', whereArgs: [row['date'], 'Oura'], limit: 1);
        if (existing.isEmpty) {
          await db.insert('wearable_data', {'id': uuid.v4(), ...row, 'created_at': DateTime.now().toIso8601String()});
          count++;
        }
      }
    }

    setState(() { _inserted = count; _importing = false; _step = _Step.done; });
  }
}

// ─── Steps ──────────────────────────────────────────────────────────────────

class _InstructionsView extends StatelessWidget {
  final VoidCallback onPick;
  const _InstructionsView({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Color(0xFF6366F1).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.circle_outlined, color: Color(0xFF6366F1), size: 22)),
                  const SizedBox(width: 14),
                  const Text('Import Oura Ring Data', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                ]),
                const SizedBox(height: 16),
                const Text('No API key needed — Oura lets you download your full history as CSV directly from the app.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text('How to export from Oura', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 14),

          _StepItem('1', 'Open the Oura app on your phone'),
          _StepItem('2', 'Go to Profile (bottom right) → Account'),
          _StepItem('3', 'Tap "Export Data"'),
          _StepItem('4', 'Choose the date range you want — you can export your full history'),
          _StepItem('5', 'Oura sends a download link to your email within a few minutes'),
          _StepItem('6', 'Download the ZIP — inside you\'ll find separate CSVs for sleep, activity, and readiness'),
          _StepItem('7', 'Import each one separately here — the app auto-detects which type it is'),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('What gets imported', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.5)),
                SizedBox(height: 10),
                _ImportTag(Icons.bedtime, 'Sleep score, stages (deep/REM/light)', Color(0xFF6366F1)),
                SizedBox(height: 6),
                _ImportTag(Icons.favorite, 'HRV, resting heart rate', AppTheme.danger),
                SizedBox(height: 6),
                _ImportTag(Icons.thermostat, 'Temperature deviation', AppTheme.warning),
                SizedBox(height: 6),
                _ImportTag(Icons.directions_walk, 'Steps, active calories (activity CSV)', AppTheme.accent),
                SizedBox(height: 6),
                _ImportTag(Icons.timeline, 'Readiness score, recovery indicators', AppTheme.primary),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: onPick,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Color(0xFF6366F1).withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_file, color: Colors.white, size: 22),
                    SizedBox(width: 12),
                    Text('Select Oura CSV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String num;
  final String text;
  const _StepItem(this.num, this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 24, height: 24, decoration: const BoxDecoration(color: Color(0x266366F1), shape: BoxShape.circle), alignment: Alignment.center, child: Text(num, style: const TextStyle(color: Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.w700))),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4))),
      ],
    ),
  );
}

class _ImportTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ImportTag(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: color, size: 14),
    const SizedBox(width: 8),
    Text(label, style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 12)),
  ]);
}

class _PreviewView extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String type;
  final bool importing;
  final VoidCallback onImport, onBack;
  const _PreviewView({required this.rows, required this.type, required this.importing, required this.onImport, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: AppTheme.surface,
          child: Row(children: [
            const Icon(Icons.circle_outlined, color: Color(0xFF6366F1), size: 18),
            const SizedBox(width: 10),
            Text('${rows.length} Oura $type records', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = rows[i];
              if (type == 'sleep') {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                  child: Row(children: [
                    const Icon(Icons.bedtime, color: Color(0xFF6366F1), size: 16),
                    const SizedBox(width: 8),
                    Text(r['date'] as String? ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    if (r['total_hours'] != null) Text('${(r['total_hours'] as double).toStringAsFixed(1)}h', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(width: 12),
                    if (r['sleep_score'] != null) StatusBadge(label: '${r['sleep_score']}', color: (r['sleep_score'] as int) >= 85 ? AppTheme.accent : AppTheme.warning),
                    const SizedBox(width: 8),
                    if (r['hrv_avg'] != null) Text('HRV ${(r['hrv_avg'] as double).toStringAsFixed(0)}ms', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ]),
                );
              }
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                child: Row(children: [
                  const Icon(Icons.directions_walk, color: AppTheme.accent, size: 16),
                  const SizedBox(width: 8),
                  Text(r['date'] as String? ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  if (r['steps'] != null) Text('${r['steps']} steps', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(color: AppTheme.surface, border: Border(top: BorderSide(color: AppTheme.border))),
          child: Row(
            children: [
              TextButton(onPressed: importing ? null : onBack, child: const Text('← Back')),
              const Spacer(),
              if (importing)
                const Row(children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1))), SizedBox(width: 12), Text('Saving…', style: TextStyle(color: AppTheme.textSecondary))])
              else
                ElevatedButton(
                  onPressed: onImport,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                  child: Text('Import ${rows.length} records'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoneView extends StatelessWidget {
  final int inserted;
  final String type;
  final VoidCallback onMore;
  const _DoneView({required this.inserted, required this.type, required this.onMore});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: AppTheme.accent, size: 72),
        const SizedBox(height: 20),
        const Text('Import complete!', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('$inserted Oura $type records added.', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
        const SizedBox(height: 32),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: onMore, style: OutlinedButton.styleFrom(foregroundColor: Color(0xFF6366F1), side: const BorderSide(color: Color(0xFF6366F1))), child: const Text('Import Another CSV'))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))),
        ]),
      ],
    ),
  ));
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: AppTheme.danger, size: 64),
        const SizedBox(height: 16),
        const Text('Import failed', style: TextStyle(color: AppTheme.danger, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text(message, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4), textAlign: TextAlign.center),
        const SizedBox(height: 28),
        ElevatedButton(onPressed: onRetry, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger), child: const Text('Try Again')),
      ],
    ),
  ));
}

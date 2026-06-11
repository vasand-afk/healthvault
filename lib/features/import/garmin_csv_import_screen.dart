import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:healthvault/core/database/database.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/core/widgets/stat_card.dart';
import 'package:uuid/uuid.dart';

class GarminCsvImportScreen extends StatefulWidget {
  const GarminCsvImportScreen({super.key});
  @override
  State<GarminCsvImportScreen> createState() => _GarminCsvImportScreenState();
}

enum _GarminStep { instructions, preview, done, error }

class _GarminCsvImportScreenState extends State<GarminCsvImportScreen> {
  _GarminStep _step = _GarminStep.instructions;
  List<Map<String, dynamic>> _parsed = [];
  String? _error;
  bool _importing = false;
  int _inserted = 0;
  String _detectedType = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Garmin Data'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: switch (_step) {
          _GarminStep.instructions => _Instructions(onPick: _pickAndParse),
          _GarminStep.preview      => _Preview(rows: _parsed, type: _detectedType, importing: _importing, onImport: _doImport, onBack: () => setState(() => _step = _GarminStep.instructions)),
          _GarminStep.done         => _Done(inserted: _inserted, type: _detectedType, onMore: () => setState(() { _step = _GarminStep.instructions; _parsed = []; _inserted = 0; })),
          _GarminStep.error        => _Err(message: _error!, onRetry: () => setState(() => _step = _GarminStep.instructions)),
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
      if (lines.length < 2) throw Exception('File too short.');

      final headers = _parseLine(lines.first).map((h) => h.trim().replaceAll('"', '')).toList();
      final rows = lines.skip(1).map((l) {
        final cells = _parseLine(l);
        return Map.fromIterables(headers, List.generate(headers.length, (i) => i < cells.length ? cells[i].trim().replaceAll('"', '') : ''));
      }).where((r) => r.values.any((v) => v.isNotEmpty)).toList();

      final type = _detectType(headers);
      if (type == 'unknown') throw Exception('Could not identify this CSV as Garmin data.\n\nExpected Activities, Sleep, or Heart Rate export.\nHeaders found: ${headers.take(6).join(', ')}…');

      final parsed = rows.map((r) => _parseRow(r, type)).where((r) => r != null).cast<Map<String, dynamic>>().toList();
      if (parsed.isEmpty) throw Exception('No valid rows found in this file.');

      setState(() { _parsed = parsed; _detectedType = type; _step = _GarminStep.preview; });
    } catch (e) {
      setState(() { _error = e.toString(); _step = _GarminStep.error; });
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
    if (h.any((e) => e.contains('activity type') || (e.contains('activity') && e.contains('name')))) return 'activities';
    if (h.any((e) => e.contains('sleep') && (e.contains('score') || e.contains('feedback')))) return 'sleep';
    if (h.any((e) => e == 'heart rate' || e.contains('resting heart rate'))) return 'heartrate';
    if (h.any((e) => e.contains('steps') && (e.contains('goal') || e.contains('distance')))) return 'daily';
    if (h.any((e) => e.contains('stress') || e.contains('body battery'))) return 'wellness';
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

    double? _d(List<String> keys) {
      final v = _f(keys);
      if (v == null) return null;
      return double.tryParse(v.replaceAll(',', ''));
    }

    int? _i(List<String> keys) => int.tryParse(_f(keys)?.replaceAll(',', '') ?? '');

    // Normalize Garmin date: "2024-01-15 08:30:00" → "2024-01-15"
    String? _date(List<String> keys) {
      final v = _f(keys);
      if (v == null || v.isEmpty) return null;
      return v.length >= 10 ? v.substring(0, 10) : v;
    }

    // Convert Garmin time "1:23:45" or "45:00" to minutes
    double? _durMin(List<String> keys) {
      final v = _f(keys);
      if (v == null || v.isEmpty) return null;
      final parts = v.split(':').map(int.tryParse).toList();
      if (parts.any((p) => p == null)) return null;
      if (parts.length == 3) return parts[0]! * 60 + parts[1]! + parts[2]! / 60;
      if (parts.length == 2) return parts[0]! + parts[1]! / 60;
      return null;
    }

    final date = _date(['date', 'start time', 'calendar date']) ?? '';
    if (date.isEmpty) return null;

    if (type == 'activities') {
      final distM = _d(['distance']);   // Garmin exports in meters sometimes, km others
      final distKm = distM != null && distM > 500 ? distM / 1000 : distM;
      return {
        'date': date,
        'type': _garminActivityType(_f(['activity type']) ?? ''),
        'name': _f(['activity name', 'name', 'title']),
        'duration_minutes': _durMin(['elapsed time', 'moving time', 'time']),
        'distance_km': distKm,
        'calories': _d(['calories']),
        'avg_hr': _d(['avg hr', 'average heart rate', 'avg heart rate']),
        'max_hr': _d(['max hr', 'max heart rate', 'maximum heart rate']),
        'elevation_m': _d(['total ascent', 'elevation gain']),
        'notes': 'Imported from Garmin Connect',
      };
    }

    if (type == 'sleep') {
      return {
        'date': date,
        'sleep_score': _i(['sleep score', 'score']),
        'total_hours': _d(['total sleep time', 'total sleep']),
        'deep_hours': _d(['deep sleep', 'deep']),
        'rem_hours': _d(['rem sleep', 'rem']),
        'light_hours': _d(['light sleep', 'light']),
        'resting_hr': _d(['resting heart rate', 'resting hr']),
        'hrv_avg': _d(['hrv', 'average hrv', 'hrv status']),
      };
    }

    if (type == 'daily' || type == 'wellness') {
      return {
        'date': date,
        'source': 'Garmin',
        'steps': _i(['steps']),
        'active_calories': _d(['active calories', 'calories burned', 'calories']),
        'resting_hr': _d(['resting heart rate', 'resting hr']),
        'hrv': _d(['hrv', 'hrv rmssd']),
      };
    }

    // heartrate
    return {
      'date': date,
      'source': 'Garmin',
      'resting_hr': _d(['resting heart rate', 'heart rate', 'avg hr']),
    };
  }

  String _garminActivityType(String raw) {
    final t = raw.toLowerCase();
    if (t.contains('running') || t == 'run') return 'Run';
    if (t.contains('cycling') || t.contains('bike') || t == 'ride') return 'Ride';
    if (t.contains('swim')) return 'Swim';
    if (t.contains('walk')) return 'Walk';
    if (t.contains('hike')) return 'Hike';
    if (t.contains('strength') || t.contains('weight') || t.contains('gym')) return 'Strength';
    if (t.contains('yoga')) return 'Yoga';
    if (t.contains('cardio')) return 'Cardio';
    return raw.isNotEmpty ? raw : 'Workout';
  }

  Future<void> _doImport() async {
    setState(() => _importing = true);
    final db = await AppDatabase.instance;
    const uuid = Uuid();
    int count = 0;

    if (_detectedType == 'activities') {
      for (final row in _parsed) {
        await db.insert('activities', {'id': uuid.v4(), ...row, 'created_at': DateTime.now().toIso8601String()});
        count++;
      }
    } else if (_detectedType == 'sleep') {
      for (final row in _parsed) {
        final exists = await db.query('sleep_logs', where: 'date = ?', whereArgs: [row['date']], limit: 1);
        if (exists.isEmpty) {
          await db.insert('sleep_logs', {'id': uuid.v4(), ...row, 'created_at': DateTime.now().toIso8601String()});
          count++;
        }
      }
    } else {
      for (final row in _parsed) {
        final exists = await db.query('wearable_data', where: 'date = ? AND source = ?', whereArgs: [row['date'], 'Garmin'], limit: 1);
        if (exists.isEmpty) {
          await db.insert('wearable_data', {'id': uuid.v4(), ...row, 'created_at': DateTime.now().toIso8601String()});
          count++;
        }
      }
    }

    setState(() { _inserted = count; _importing = false; _step = _GarminStep.done; });
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _Instructions extends StatelessWidget {
  final VoidCallback onPick;
  const _Instructions({required this.onPick});

  @override
  Widget build(BuildContext context) {
    const indigo = Color(0xFF6366F1);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HvCard(child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.gps_fixed, color: AppTheme.accent, size: 22)),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Import Garmin Connect Data', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
              SizedBox(height: 4),
              Text('No API key needed — export directly from Garmin Connect website.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
            ])),
          ])),
          const SizedBox(height: 24),
          const Text('How to export from Garmin Connect', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 14),
          ..._steps.map((s) => _StepRow(s.$1, s.$2)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SUPPORTED EXPORTS', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.8)),
              const SizedBox(height: 12),
              _Tag(Icons.directions_run, 'Activities CSV — all workouts with pace, HR, distance', AppTheme.accent),
              const SizedBox(height: 8),
              _Tag(Icons.bedtime, 'Sleep CSV — sleep score, stages, HRV', indigo),
              const SizedBox(height: 8),
              _Tag(Icons.directions_walk, 'Daily Summary CSV — steps, active calories, stress', AppTheme.warning),
              const SizedBox(height: 8),
              _Tag(Icons.favorite, 'Heart Rate CSV — resting HR over time', AppTheme.danger),
            ]),
          ),
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: onPick,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.accent, Color(0xFF059669)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.upload_file, color: Colors.white, size: 22),
                  SizedBox(width: 12),
                  Text('Select Garmin CSV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  static const _steps = [
    ('1', 'Go to connect.garmin.com and sign in'),
    ('2', 'Click your name → Account Settings → Data Management'),
    ('3', 'Under "Export Your Data" click "Export Data"'),
    ('4', 'You\'ll receive a download link by email'),
    ('5', 'Inside the ZIP, find the CSV files (Activities, Sleep, Wellness, etc.)'),
    ('6', 'Import each CSV file here — the app auto-detects the type'),
  ];
}

class _StepRow extends StatelessWidget {
  final String num, text;
  const _StepRow(this.num, this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 24, height: 24, decoration: const BoxDecoration(color: Color(0x2610B981), shape: BoxShape.circle), alignment: Alignment.center, child: Text(num, style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w700))),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4))),
    ]),
  );
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Tag(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: color, size: 14),
    const SizedBox(width: 8),
    Expanded(child: Text(label, style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 12))),
  ]);
}

class _Preview extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String type;
  final bool importing;
  final VoidCallback onImport, onBack;
  const _Preview({required this.rows, required this.type, required this.importing, required this.onImport, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: AppTheme.surface,
        child: Row(children: [
          const Icon(Icons.gps_fixed, color: AppTheme.accent, size: 18),
          const SizedBox(width: 10),
          Text('${rows.length} Garmin $type records ready', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = rows[i];
            if (type == 'activities') {
              return HvCard(child: Row(children: [
                const Icon(Icons.directions_run, color: AppTheme.accent, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['name'] as String? ?? r['type'] as String? ?? 'Activity', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(r['date'] as String? ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ])),
                if (r['distance_km'] != null) Text('${(r['distance_km'] as double).toStringAsFixed(1)} km', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 8),
                if (r['duration_minutes'] != null) Text('${(r['duration_minutes'] as double).toStringAsFixed(0)} min', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ]));
            }
            return HvCard(child: Row(children: [
              const Icon(Icons.bedtime, color: Color(0xFF6366F1), size: 16),
              const SizedBox(width: 8),
              Text(r['date'] as String? ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const Spacer(),
              if (r['sleep_score'] != null) StatusBadge(label: '${r['sleep_score']}', color: (r['sleep_score'] as int) >= 80 ? AppTheme.accent : AppTheme.warning),
              const SizedBox(width: 8),
              if (r['total_hours'] != null) Text('${(r['total_hours'] as double).toStringAsFixed(1)}h', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w700)),
            ]));
          },
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(color: AppTheme.surface, border: Border(top: BorderSide(color: AppTheme.border))),
        child: Row(children: [
          TextButton(onPressed: importing ? null : onBack, child: const Text('← Back')),
          const Spacer(),
          if (importing)
            const Row(children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)), SizedBox(width: 12), Text('Saving…', style: TextStyle(color: AppTheme.textSecondary))])
          else
            ElevatedButton(
              onPressed: onImport,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              child: Text('Import ${rows.length} records'),
            ),
        ]),
      ),
    ]);
  }
}

class _Done extends StatelessWidget {
  final int inserted;
  final String type;
  final VoidCallback onMore;
  const _Done({required this.inserted, required this.type, required this.onMore});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.check_circle, color: AppTheme.accent, size: 72),
      const SizedBox(height: 20),
      const Text('Import complete!', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('$inserted Garmin $type records added.', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
      const SizedBox(height: 32),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: onMore, style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accent, side: const BorderSide(color: AppTheme.accent)), child: const Text('Import Another CSV'))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))),
      ]),
    ]),
  ));
}

class _Err extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Err({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, color: AppTheme.danger, size: 64),
      const SizedBox(height: 16),
      const Text('Import failed', style: TextStyle(color: AppTheme.danger, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Text(message, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4), textAlign: TextAlign.center),
      const SizedBox(height: 28),
      ElevatedButton(onPressed: onRetry, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger), child: const Text('Try Again')),
    ]),
  ));
}

import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vasan_health/core/database/database.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/core/widgets/stat_card.dart';
import 'package:uuid/uuid.dart';

class StravaImportScreen extends StatefulWidget {
  const StravaImportScreen({super.key});
  @override
  State<StravaImportScreen> createState() => _StravaImportScreenState();
}

enum _StravaStep { instructions, parsing, preview, done, error }

class _StravaImportScreenState extends State<StravaImportScreen> {
  _StravaStep _step = _StravaStep.instructions;
  List<Map<String, dynamic>> _parsed = [];
  String? _error;
  bool _importing = false;
  int _inserted = 0;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Strava Data'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: switch (_step) {
          _StravaStep.instructions => _Instructions(onPick: _pick),
          _StravaStep.parsing      => _Parsing(progress: _progress),
          _StravaStep.preview      => _Preview(rows: _parsed, importing: _importing, onImport: _doImport, onBack: () => setState(() => _step = _StravaStep.instructions)),
          _StravaStep.done         => _Done(inserted: _inserted, onMore: () => setState(() { _step = _StravaStep.instructions; _parsed = []; _inserted = 0; })),
          _StravaStep.error        => _ErrView(message: _error!, onRetry: () => setState(() => _step = _StravaStep.instructions)),
        },
      ),
    );
  }

  Future<void> _pick() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'csv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      setState(() { _step = _StravaStep.parsing; _progress = 0.1; });

      final bytes = picked.files.first.bytes;
      if (bytes == null) throw Exception('Could not read file.');
      final ext = picked.files.first.extension?.toLowerCase() ?? '';

      String csvContent;
      if (ext == 'zip') {
        csvContent = await compute<Uint8List, String>(_extractActivitiesCsv, bytes);
      } else {
        csvContent = utf8.decode(bytes, allowMalformed: true);
      }

      setState(() => _progress = 0.5);
      final rows = await compute<String, List<Map<String, dynamic>>>(_parseActivitiesCsv, csvContent);
      setState(() { _parsed = rows; _progress = 1.0; _step = _StravaStep.preview; });
    } catch (e) {
      setState(() { _error = e.toString(); _step = _StravaStep.error; });
    }
  }

  Future<void> _doImport() async {
    setState(() => _importing = true);
    final db = await AppDatabase.instance;
    const uuid = Uuid();
    int count = 0;
    for (final row in _parsed) {
      await db.insert('activities', {'id': uuid.v4(), ...row, 'created_at': DateTime.now().toIso8601String()});
      count++;
    }
    setState(() { _inserted = count; _importing = false; _step = _StravaStep.done; });
  }
}

// Top-level functions for compute isolates

String _extractActivitiesCsv(Uint8List zipBytes) {
  final archive = ZipDecoder().decodeBytes(zipBytes);
  // Strava archive: activities.csv at root or activities/activities.csv
  for (final file in archive) {
    if (!file.isFile) continue;
    final name = file.name.toLowerCase();
    if (name.endsWith('activities.csv')) {
      return utf8.decode(file.content as List<int>, allowMalformed: true);
    }
  }
  throw Exception('Could not find activities.csv inside the ZIP.\n\nMake sure you uploaded the Strava data export archive (export_XXXXX.zip).');
}

List<Map<String, dynamic>> _parseActivitiesCsv(String csv) {
  final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
  if (lines.length < 2) throw Exception('activities.csv is empty.');

  List<String> parseLine(String line) {
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

  final headers = parseLine(lines.first).map((h) => h.trim().replaceAll('"', '')).toList();
  final rows = <Map<String, dynamic>>[];

  for (final line in lines.skip(1)) {
    final cells = parseLine(line);
    final r = Map.fromIterables(headers, List.generate(headers.length, (i) => i < cells.length ? cells[i].trim().replaceAll('"', '') : ''));

    String? f(List<String> keys) {
      for (final k in keys) {
        for (final e in r.entries) {
          if (e.key.toLowerCase().contains(k.toLowerCase()) && e.value.isNotEmpty) return e.value;
        }
      }
      return null;
    }

    double? d(List<String> keys) {
      final v = f(keys);
      if (v == null) return null;
      return double.tryParse(v.replaceAll(',', ''));
    }

    // Date: "Jan 15, 2024, 8:30:00 AM" or "2024-01-15T08:30:00Z"
    String? rawDate = f(['activity date', 'date']);
    String date = '';
    if (rawDate != null && rawDate.isNotEmpty) {
      // ISO format
      if (rawDate.length >= 10 && rawDate[4] == '-') {
        date = rawDate.substring(0, 10);
      } else {
        // Try parsing "Jan 15, 2024, ..." → extract first 3 tokens
        try {
          final parsed = DateTime.parse(rawDate);
          date = parsed.toIso8601String().substring(0, 10);
        } catch (_) {
          // "Jan 15, 2024, 8:30:00 AM"
          final months = {'jan':'01','feb':'02','mar':'03','apr':'04','may':'05','jun':'06','jul':'07','aug':'08','sep':'09','oct':'10','nov':'11','dec':'12'};
          final parts = rawDate.replaceAll(',', '').split(RegExp(r'\s+'));
          if (parts.length >= 3) {
            final mon = months[parts[0].toLowerCase()] ?? '01';
            final day = parts[1].padLeft(2, '0');
            final year = parts[2];
            date = '$year-$mon-$day';
          }
        }
      }
    }
    if (date.isEmpty) continue;

    // Duration: "1:23:45" → minutes
    double? durMin;
    final durStr = f(['elapsed time', 'moving time']);
    if (durStr != null) {
      final parts = durStr.split(':').map(int.tryParse).toList();
      if (parts.every((p) => p != null)) {
        if (parts.length == 3) durMin = parts[0]! * 60.0 + parts[1]! + parts[2]! / 60;
        if (parts.length == 2) durMin = parts[0]! + parts[1]! / 60.0;
        // seconds-only (Strava sometimes exports in seconds)
        if (parts.length == 1 && parts[0]! > 600) durMin = parts[0]! / 60.0;
      }
    }

    // Distance: Strava exports in meters
    final distRaw = d(['distance']);
    final distKm = distRaw != null && distRaw > 500 ? distRaw / 1000 : distRaw;

    rows.add({
      'date': date,
      'type': _mapStravaType(f(['activity type', 'sport type']) ?? ''),
      'name': f(['activity name', 'name']),
      'duration_minutes': durMin,
      'distance_km': distKm,
      'calories': d(['calories']),
      'avg_hr': d(['average heart rate', 'avg hr']),
      'max_hr': d(['max heart rate', 'max hr']),
      'elevation_m': d(['elevation gain', 'total elevation gain']),
      'avg_pace': f(['average pace', 'avg pace']),
      'notes': 'Imported from Strava',
    });
  }

  if (rows.isEmpty) throw Exception('No valid activities found in this file.');
  return rows;
}

String _mapStravaType(String raw) {
  final t = raw.toLowerCase();
  if (t.contains('run')) return 'Run';
  if (t.contains('ride') || t.contains('cycling')) return 'Ride';
  if (t.contains('swim')) return 'Swim';
  if (t.contains('walk')) return 'Walk';
  if (t.contains('hike')) return 'Hike';
  if (t.contains('workout') || t.contains('weight')) return 'Strength';
  if (t.contains('yoga')) return 'Yoga';
  if (t.contains('ski')) return 'Ski';
  if (t.contains('row')) return 'Row';
  return raw.isNotEmpty ? raw : 'Workout';
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _Instructions extends StatelessWidget {
  final VoidCallback onPick;
  const _Instructions({required this.onPick});

  static const _orange = Color(0xFFFC4C02); // Strava orange

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_orange.withValues(alpha: 0.15), _orange.withValues(alpha: 0.05)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _orange.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.directions_run, color: _orange, size: 22)),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Import Strava Activities', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
              SizedBox(height: 4),
              Text('No app registration needed — use Strava\'s built-in data export.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
            ])),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('How to export from Strava', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 14),
        ..._steps.map((s) => _Row(s.$1, s.$2)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('WHAT GETS IMPORTED', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.8)),
            SizedBox(height: 12),
            _Tag(Icons.calendar_today, 'Activity date and name', _orange),
            SizedBox(height: 8),
            _Tag(Icons.straighten, 'Distance (km), Duration (minutes)', _orange),
            SizedBox(height: 8),
            _Tag(Icons.favorite, 'Average & max heart rate', AppTheme.danger),
            SizedBox(height: 8),
            _Tag(Icons.terrain, 'Elevation gain', AppTheme.accent),
            SizedBox(height: 8),
            _Tag(Icons.local_fire_department, 'Calories burned', AppTheme.warning),
            SizedBox(height: 8),
            _Tag(Icons.directions_run, 'Activity type (Run, Ride, Swim, Walk…)', AppTheme.textSecondary),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3))),
          child: const Row(children: [
            Icon(Icons.schedule, color: AppTheme.warning, size: 16),
            SizedBox(width: 10),
            Expanded(child: Text('Strava can take up to 3 days to prepare your export — request it early.', style: TextStyle(color: AppTheme.warning, fontSize: 12, height: 1.4))),
          ]),
        ),
        const SizedBox(height: 32),
        Center(
          child: Column(children: [
            GestureDetector(
              onTap: onPick,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_orange, _orange.withValues(alpha: 0.75)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _orange.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.upload_file, color: Colors.white, size: 22),
                  SizedBox(width: 12),
                  Text('Upload Strava Export ZIP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            const Text('or select just the activities.csv file', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 80),
      ]),
    );
  }

  static const _steps = [
    ('1', 'Go to strava.com → Settings → My Account → Download or Delete Your Account'),
    ('2', 'Click "Request Your Archive" under Download'),
    ('3', 'Wait for the email from Strava with your download link (up to 3 days)'),
    ('4', 'Download the ZIP file and upload it here, OR extract it and upload just activities.csv'),
  ];
}

class _Row extends StatelessWidget {
  final String num, text;
  const _Row(this.num, this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 24, height: 24, decoration: const BoxDecoration(color: Color(0x26FC4C02), shape: BoxShape.circle), alignment: Alignment.center, child: Text(num, style: const TextStyle(color: Color(0xFFFC4C02), fontSize: 12, fontWeight: FontWeight.w700))),
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

class _Parsing extends StatelessWidget {
  final double progress;
  const _Parsing({required this.progress});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.directions_run, color: Color(0xFFFC4C02), size: 56),
      const SizedBox(height: 24),
      const Text('Reading your Strava data…', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 24),
      LinearProgressIndicator(value: progress, backgroundColor: AppTheme.border, color: const Color(0xFFFC4C02), minHeight: 6, borderRadius: BorderRadius.circular(3)),
      const SizedBox(height: 12),
      Text('${(progress * 100).toInt()}%', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
    ]),
  ));
}

class _Preview extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final bool importing;
  final VoidCallback onImport, onBack;
  const _Preview({required this.rows, required this.importing, required this.onImport, required this.onBack});

  static const _orange = Color(0xFFFC4C02);

  String _typeIcon(String? type) {
    switch (type) {
      case 'Run': return '🏃';
      case 'Ride': return '🚴';
      case 'Swim': return '🏊';
      case 'Walk': return '🚶';
      case 'Hike': return '🥾';
      case 'Strength': return '🏋️';
      default: return '⚡';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Quick summary stats
    int runs = rows.where((r) => r['type'] == 'Run').length;
    int rides = rows.where((r) => r['type'] == 'Ride').length;
    double totalKm = rows.fold(0.0, (s, r) => s + ((r['distance_km'] as double?) ?? 0.0));

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        color: AppTheme.surface,
        child: Row(children: [
          const Icon(Icons.directions_run, color: _orange, size: 18),
          const SizedBox(width: 10),
          Text('${rows.length} activities', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (runs > 0) Text('🏃 $runs', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(width: 10),
          if (rides > 0) Text('🚴 $rides', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(width: 10),
          Text('${totalKm.toStringAsFixed(0)} km total', style: const TextStyle(color: _orange, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = rows[i];
            final type = r['type'] as String? ?? 'Workout';
            final dist = r['distance_km'] as double?;
            final dur = r['duration_minutes'] as double?;
            final hr = r['avg_hr'] as double?;
            return HvCard(child: Row(children: [
              Text(_typeIcon(type), style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['name'] as String? ?? type, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                Text(r['date'] as String? ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ])),
              if (dist != null) Text('${dist.toStringAsFixed(1)} km', style: const TextStyle(color: _orange, fontWeight: FontWeight.w700, fontSize: 13)),
              if (dur != null) ...[const SizedBox(width: 8), Text('${dur.toStringAsFixed(0)}m', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))],
              if (hr != null) ...[const SizedBox(width: 8), Text('♥ ${hr.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.danger, fontSize: 11))],
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
            const Row(children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _orange)), SizedBox(width: 12), Text('Saving…', style: TextStyle(color: AppTheme.textSecondary))])
          else
            ElevatedButton(
              onPressed: onImport,
              style: ElevatedButton.styleFrom(backgroundColor: _orange),
              child: Text('Import ${rows.length} activities'),
            ),
        ]),
      ),
    ]);
  }
}

class _Done extends StatelessWidget {
  final int inserted;
  final VoidCallback onMore;
  const _Done({required this.inserted, required this.onMore});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🏃', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 20),
      const Text('Activities imported!', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('$inserted activities added to your Fitness log.', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
      const SizedBox(height: 32),
      ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFC4C02)),
        child: const Text('Done'),
      ),
    ]),
  ));
}

class _ErrView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrView({required this.message, required this.onRetry});
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

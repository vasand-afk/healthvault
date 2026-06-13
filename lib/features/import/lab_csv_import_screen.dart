import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:vasan_health/core/database/database.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/core/widgets/stat_card.dart';
import 'package:uuid/uuid.dart';

// ─── Data model ────────────────────────────────────────────────────────────

class _CsvRow {
  final Map<String, String> cells;
  _CsvRow(this.cells);
  String? operator [](String key) => cells[key];
}

// ─── Screen ────────────────────────────────────────────────────────────────

class LabCsvImportScreen extends StatefulWidget {
  const LabCsvImportScreen({super.key});
  @override
  State<LabCsvImportScreen> createState() => _LabCsvImportScreenState();
}

enum _Step { instructions, mapping, preview, done, error }

class _LabCsvImportScreenState extends State<LabCsvImportScreen> {
  _Step _step = _Step.instructions;
  List<String> _headers = [];
  List<_CsvRow> _rows = [];
  String? _error;

  // column mapping: our field → user-selected CSV column
  final Map<String, String?> _mapping = {
    'test_name': null,
    'value': null,
    'unit': null,
    'reference_range': null,
    'date': null,
    'status': null,
    'lab_name': null,
    'ordered_by': null,
    'notes': null,
  };

  // preview of mapped rows
  List<Map<String, dynamic>> _preview = [];
  int _inserted = 0;
  bool _importing = false;

  // ── field metadata ───────────────────────────────────────────────────────
  static const _fieldMeta = {
    'test_name':       ('Test Name',        true,  'e.g. "Total Cholesterol"'),
    'value':           ('Value',            true,  'e.g. "185"'),
    'unit':            ('Unit',             false, 'e.g. "mg/dL"'),
    'reference_range': ('Reference Range',  false, 'e.g. "< 200"'),
    'date':            ('Date',             true,  'e.g. "2025-06-10" or "06/10/2025"'),
    'status':          ('Status',           false, 'Normal / High / Low / Optimal'),
    'lab_name':        ('Lab Name',         false, 'e.g. "Quest Diagnostics"'),
    'ordered_by':      ('Ordered By',       false, 'Physician name'),
    'notes':           ('Notes',            false, 'Free text'),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Lab Results (CSV)'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (_step) {
          _Step.instructions => _InstructionsStep(onPickFile: _pickFile),
          _Step.mapping      => _MappingStep(
              headers: _headers,
              rows: _rows,
              mapping: _mapping,
              fieldMeta: _fieldMeta,
              onMappingChanged: (field, col) => setState(() => _mapping[field] = col),
              onNext: _buildPreview,
            ),
          _Step.preview      => _PreviewStep(
              rows: _preview,
              importing: _importing,
              onImport: _doImport,
              onBack: () => setState(() => _step = _Step.mapping),
            ),
          _Step.done         => _DoneStep(inserted: _inserted, onImportMore: () => setState(() {
                _step = _Step.instructions;
                _headers = []; _rows = []; _preview = []; _inserted = 0;
                _mapping.updateAll((_, __) => null);
              })),
          _Step.error        => _ErrorStep(message: _error ?? 'Unknown error', onRetry: () => setState(() => _step = _Step.instructions)),
        },
      ),
    );
  }

  // ── pick & parse CSV ─────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt', 'tsv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;

      final bytes = picked.files.first.bytes;
      if (bytes == null) throw Exception('Could not read file.');

      final content = utf8.decode(bytes, allowMalformed: true);
      _parseCSV(content, picked.files.first.extension ?? 'csv');
    } catch (e) {
      setState(() { _error = e.toString(); _step = _Step.error; });
    }
  }

  void _parseCSV(String content, String ext) {
    // Detect delimiter
    final firstLine = content.split('\n').first;
    final delimiter = ext == 'tsv' ? '\t'
        : firstLine.contains('\t') ? '\t'
        : firstLine.contains(';') ? ';'
        : ',';

    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) throw Exception('File has fewer than 2 rows — needs a header + at least one data row.');

    final headers = _splitLine(lines.first, delimiter).map((h) => h.trim().replaceAll('"', '')).toList();

    final rows = lines.skip(1).map((line) {
      final cells = _splitLine(line, delimiter);
      final map = <String, String>{};
      for (int i = 0; i < headers.length; i++) {
        map[headers[i]] = i < cells.length ? cells[i].trim().replaceAll('"', '') : '';
      }
      return _CsvRow(map);
    }).where((r) => r.cells.values.any((v) => v.isNotEmpty)).toList();

    // Auto-detect column mapping
    final autoMapping = _autoDetectMapping(headers);

    setState(() {
      _headers = headers;
      _rows = rows;
      _mapping.updateAll((_, __) => null);
      autoMapping.forEach((field, col) => _mapping[field] = col);
      _step = _Step.mapping;
    });
  }

  List<String> _splitLine(String line, String delimiter) {
    // Handles quoted fields containing the delimiter
    final result = <String>[];
    bool inQuote = false;
    final buf = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') { inQuote = !inQuote; continue; }
      if (ch == delimiter && !inQuote) { result.add(buf.toString()); buf.clear(); continue; }
      buf.write(ch);
    }
    result.add(buf.toString());
    return result;
  }

  Map<String, String> _autoDetectMapping(List<String> headers) {
    final patterns = <String, List<String>>{
      'test_name':       ['test', 'name', 'analyte', 'biomarker', 'marker', 'component', 'description'],
      'value':           ['result', 'value', 'val', 'level', 'amount'],
      'unit':            ['unit', 'units', 'uom'],
      'reference_range': ['reference', 'range', 'ref', 'normal range', 'refrange', 'interval'],
      'date':            ['date', 'collected', 'reported', 'drawn', 'specimen date', 'result date'],
      'status':          ['status', 'flag', 'abnormal', 'interpretation', 'remark'],
      'lab_name':        ['lab', 'laboratory', 'facility', 'vendor', 'source'],
      'ordered_by':      ['doctor', 'physician', 'provider', 'ordered by', 'ordering'],
      'notes':           ['note', 'comment', 'remark', 'additional'],
    };

    final mapping = <String, String>{};
    for (final entry in patterns.entries) {
      for (final header in headers) {
        final h = header.toLowerCase();
        if (entry.value.any((p) => h.contains(p))) {
          mapping[entry.key] = header;
          break;
        }
      }
    }
    return mapping;
  }

  // ── build preview ────────────────────────────────────────────────────────

  void _buildPreview() {
    // Validate required fields
    final missing = _fieldMeta.entries
        .where((e) => e.value.$2 && _mapping[e.key] == null)
        .map((e) => e.value.$1)
        .toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Required columns not mapped: ${missing.join(', ')}'),
        backgroundColor: AppTheme.danger,
      ));
      return;
    }

    final preview = _rows.take(200).map((row) {
      return <String, dynamic>{
        'test_name':       row[_mapping['test_name']!] ?? '',
        'value':           double.tryParse(row[_mapping['value']!] ?? ''),
        'unit':            _mapping['unit'] != null ? row[_mapping['unit']!] : null,
        'reference_range': _mapping['reference_range'] != null ? row[_mapping['reference_range']!] : null,
        'date':            _normalizeDate(row[_mapping['date']!] ?? ''),
        'status':          _mapping['status'] != null ? _normalizeStatus(row[_mapping['status']!] ?? '') : null,
        'lab_name':        _mapping['lab_name'] != null ? row[_mapping['lab_name']!] : null,
        'ordered_by':      _mapping['ordered_by'] != null ? row[_mapping['ordered_by']!] : null,
        'notes':           _mapping['notes'] != null ? row[_mapping['notes']!] : null,
      };
    }).where((r) => (r['test_name'] as String).isNotEmpty).toList();

    setState(() { _preview = preview; _step = _Step.preview; });
  }

  String _normalizeDate(String raw) {
    if (raw.isEmpty) return '';
    // Already ISO
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(raw)) return raw.substring(0, 10);
    // MM/DD/YYYY
    final mdy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})');
    final m1 = mdy.firstMatch(raw);
    if (m1 != null) return '${m1[3]}-${m1[1]!.padLeft(2,'0')}-${m1[2]!.padLeft(2,'0')}';
    // DD-MM-YYYY
    final dmy = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})');
    final m2 = dmy.firstMatch(raw);
    if (m2 != null) return '${m2[3]}-${m2[2]!.padLeft(2,'0')}-${m2[1]!.padLeft(2,'0')}';
    return raw;
  }

  String? _normalizeStatus(String raw) {
    final r = raw.trim().toLowerCase();
    if (r.isEmpty) return null;
    if (r == 'h' || r == 'high' || r == 'above' || r == 'a' || r == '*h') return 'High';
    if (r == 'l' || r == 'low' || r == 'below' || r == '*l') return 'Low';
    if (r == 'n' || r == 'normal' || r == 'in range' || r == 'wnl') return 'Normal';
    if (r == 'c' || r == 'critical' || r == '*c') return 'Critical';
    if (r == 'optimal') return 'Optimal';
    return raw.isNotEmpty ? raw : null;
  }

  // ── insert to DB ─────────────────────────────────────────────────────────

  Future<void> _doImport() async {
    setState(() => _importing = true);
    final db = await AppDatabase.instance;
    const uuid = Uuid();
    int count = 0;

    for (final row in _preview) {
      if ((row['test_name'] as String).isEmpty) continue;
      await db.insert('lab_results', {
        'id': uuid.v4(),
        ...row,
        'created_at': DateTime.now().toIso8601String(),
      });
      count++;
    }

    setState(() { _inserted = count; _importing = false; _step = _Step.done; });
  }
}

// ─── Step widgets ───────────────────────────────────────────────────────────

class _InstructionsStep extends StatelessWidget {
  final VoidCallback onPickFile;
  const _InstructionsStep({required this.onPickFile});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.biotech, color: AppTheme.warning, size: 22)),
                  const SizedBox(width: 14),
                  const Text('Lab Results CSV Import', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                ]),
                const SizedBox(height: 16),
                const Text('Accepts CSV exports from Quest, LabCorp, Everlywell, InsideTracker, Function Health, or any custom spreadsheet.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Per-lab export instructions
          const Text('How to export from each lab', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 14),
          _LabInstructions(
            name: 'Quest Diagnostics / MyQuest',
            color: Color(0xFF0066CC),
            icon: Icons.local_hospital,
            steps: [
              'Log in at myquest.questdiagnostics.com',
              'Go to Test Results → select the result',
              'Click "Download" or "Print" → save as PDF → copy values to CSV',
              'Or use Quest\'s "Share Results" feature if available',
            ],
          ),
          _LabInstructions(
            name: 'LabCorp Patient',
            color: Color(0xFF003DA6),
            icon: Icons.science,
            steps: [
              'Log in at patient.labcorp.com',
              'Go to Results → click a result',
              'Use the Download button (CSV or PDF)',
              'If PDF only: copy the table into a spreadsheet and save as CSV',
            ],
          ),
          _LabInstructions(
            name: 'Function Health',
            color: AppTheme.accent,
            icon: Icons.biotech,
            steps: [
              'Log in to your Function Health dashboard',
              'Go to Results → click Export or Download',
              'Choose CSV format — it includes all biomarkers with values and ranges',
            ],
          ),
          _LabInstructions(
            name: 'InsideTracker',
            color: Color(0xFF00B140),
            icon: Icons.analytics,
            steps: [
              'Log in to insidetracker.com',
              'Go to My Plan → Biomarkers',
              'Click the download icon → Export CSV',
            ],
          ),
          _LabInstructions(
            name: 'Any spreadsheet / manual entry',
            color: AppTheme.secondary,
            icon: Icons.table_chart,
            steps: [
              'Create a CSV with columns: Test Name, Value, Unit, Reference Range, Date',
              'One row per biomarker per draw',
              'Save as .csv and upload — you\'ll map columns in the next step',
            ],
          ),
          const SizedBox(height: 28),

          // Supported formats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Supported formats', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _FormatChip('.csv  comma-separated'),
                  _FormatChip('.tsv  tab-separated'),
                  _FormatChip('.txt  any delimiter'),
                  _FormatChip('Quoted fields'),
                  _FormatChip('Any column order'),
                  _FormatChip('Extra columns ignored'),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Center(
            child: GestureDetector(
              onTap: onPickFile,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.warning, Color(0xFFF97316)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppTheme.warning.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_file, color: Colors.white, size: 22),
                    SizedBox(width: 12),
                    Text('Select CSV File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
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

class _LabInstructions extends StatelessWidget {
  final String name;
  final Color color;
  final IconData icon;
  final List<String> steps;
  const _LabInstructions({required this.name, required this.color, required this.icon, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
        title: Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
        iconColor: AppTheme.textSecondary,
        collapsedIconColor: AppTheme.textSecondary,
        children: steps.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 20, height: 20, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle), alignment: Alignment.center, child: Text('${e.key + 1}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              Expanded(child: Text(e.value, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4))),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  const _FormatChip(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: AppTheme.border.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
  );
}

// ─── Column mapping step ────────────────────────────────────────────────────

class _MappingStep extends StatelessWidget {
  final List<String> headers;
  final List<_CsvRow> rows;
  final Map<String, String?> mapping;
  final Map<String, (String, bool, String)> fieldMeta;
  final Function(String, String?) onMappingChanged;
  final VoidCallback onNext;

  const _MappingStep({
    required this.headers, required this.rows, required this.mapping,
    required this.fieldMeta, required this.onMappingChanged, required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final requiredMapped = fieldMeta.entries.where((e) => e.value.$2).every((e) => mapping[e.key] != null);

    return Column(
      children: [
        // CSV preview strip
        if (rows.isNotEmpty) _CsvPreviewStrip(headers: headers, rows: rows.take(3).toList()),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25))),
                  child: const Row(children: [
                    Icon(Icons.auto_fix_high, color: AppTheme.primary, size: 18),
                    SizedBox(width: 10),
                    Expanded(child: Text('Column headers were auto-detected. Review and adjust any that look wrong.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
                  ]),
                ),
                const SizedBox(height: 20),
                ...fieldMeta.entries.map((entry) {
                  final field = entry.key;
                  final (label, required, hint) = entry.value;
                  final selectedCol = mapping[field];
                  final preview = selectedCol != null && rows.isNotEmpty ? rows.first[selectedCol] : null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: required && selectedCol == null ? AppTheme.danger.withValues(alpha: 0.4) : AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
                                if (required) ...[const SizedBox(width: 4), const Text('*', style: TextStyle(color: AppTheme.danger, fontSize: 13, fontWeight: FontWeight.w700))],
                              ]),
                              Text(hint, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: selectedCol,
                                dropdownColor: AppTheme.surface,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border)),
                                  hintText: required ? 'Select column *' : 'Select column',
                                ),
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('— not mapped —', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                                  ...headers.map((h) => DropdownMenuItem(value: h, child: Text(h, overflow: TextOverflow.ellipsis))),
                                ],
                                onChanged: (v) => onMappingChanged(field, v),
                              ),
                              if (preview != null && preview.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4, left: 4),
                                  child: Text('e.g. "$preview"', style: const TextStyle(color: AppTheme.accent, fontSize: 10), overflow: TextOverflow.ellipsis),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Text('* Required fields', style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 11)),
              ],
            ),
          ),
        ),

        // Bottom bar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(color: AppTheme.surface, border: Border(top: BorderSide(color: AppTheme.border))),
          child: Row(
            children: [
              Text('${rows.length} rows detected  •  ${headers.length} columns', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const Spacer(),
              ElevatedButton(
                onPressed: requiredMapped ? onNext : null,
                child: const Text('Preview Import →'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CsvPreviewStrip extends StatelessWidget {
  final List<String> headers;
  final List<_CsvRow> rows;
  const _CsvPreviewStrip({required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    final visibleHeaders = headers.take(6).toList();
    return Container(
      color: AppTheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(140),
          border: TableBorder.all(color: AppTheme.border, width: 0.5, borderRadius: BorderRadius.circular(4)),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFF1A2A3A)),
              children: visibleHeaders.map((h) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Text(h, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 11), overflow: TextOverflow.ellipsis),
              )).toList(),
            ),
            ...rows.map((row) => TableRow(
              children: visibleHeaders.map((h) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(row[h] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis),
              )).toList(),
            )),
          ],
        ),
      ),
    );
  }
}

// ─── Preview step ───────────────────────────────────────────────────────────

class _PreviewStep extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final bool importing;
  final VoidCallback onImport;
  final VoidCallback onBack;
  const _PreviewStep({required this.rows, required this.importing, required this.onImport, required this.onBack});

  Color _statusColor(String? s) {
    switch (s) {
      case 'High': return AppTheme.danger;
      case 'Low': return AppTheme.warning;
      case 'Normal': return AppTheme.accent;
      case 'Critical': return AppTheme.danger;
      case 'Optimal': return AppTheme.primary;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: AppTheme.surface,
          child: Row(children: [
            const Icon(Icons.preview, color: AppTheme.primary, size: 18),
            const SizedBox(width: 10),
            Text('${rows.length} lab results ready to import', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('Scroll to review', style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 12)),
          ]),
        ),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final row = rows[i];
              final status = row['status'] as String?;
              final value = row['value'];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: status != null ? _statusColor(status).withValues(alpha: 0.25) : AppTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row['test_name'] as String? ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 2),
                          Row(children: [
                            if (row['date'] != null && (row['date'] as String).isNotEmpty)
                              Text(row['date'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            if (row['lab_name'] != null && (row['lab_name'] as String).isNotEmpty) ...[
                              const Text('  ·  ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                              Text(row['lab_name'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            ],
                          ]),
                          if (row['reference_range'] != null && (row['reference_range'] as String).isNotEmpty)
                            Text('Ref: ${row['reference_range']}${row['unit'] != null ? ' ${row['unit']}' : ''}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          value != null ? '$value${row['unit'] != null ? ' ${row['unit']}' : ''}' : '—',
                          style: TextStyle(color: status != null ? _statusColor(status) : AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        if (status != null)
                          StatusBadge(label: status, color: _statusColor(status)),
                      ],
                    ),
                  ],
                ),
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
                const Row(children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                  SizedBox(width: 12),
                  Text('Saving…', style: TextStyle(color: AppTheme.textSecondary)),
                ])
              else
                ElevatedButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Icons.save),
                  label: Text('Import ${rows.length} Results'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Done step ──────────────────────────────────────────────────────────────

class _DoneStep extends StatelessWidget {
  final int inserted;
  final VoidCallback onImportMore;
  const _DoneStep({required this.inserted, required this.onImportMore});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: AppTheme.accent, size: 64),
            ),
            const SizedBox(height: 24),
            const Text('Import complete!', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('$inserted lab results added to your vault.', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            const SizedBox(height: 32),
            const Text('Your results are now in the Lab Results section of your Data Vault, with status badges and reference ranges. The AI Coach can also reference them.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: onImportMore, style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary, side: const BorderSide(color: AppTheme.primary)), child: const Text('Import More'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Go to Labs'))),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ErrorStep extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorStep({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
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
      ),
    );
  }
}

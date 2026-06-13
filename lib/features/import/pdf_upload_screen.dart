import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:vasan_health/core/database/database.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/core/widgets/stat_card.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class PdfUploadScreen extends StatefulWidget {
  const PdfUploadScreen({super.key});
  @override
  State<PdfUploadScreen> createState() => _PdfUploadScreenState();
}

class _PdfUploadScreenState extends State<PdfUploadScreen> {
  List<Map<String, dynamic>> _docs = [];
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('documents', orderBy: 'created_at DESC');
    setState(() => _docs = rows);
  }

  Future<void> _pickAndUpload() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'tiff'],
      withData: true,
      allowMultiple: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    setState(() => _uploading = true);

    for (final file in picked.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      await _showSaveDialog(file.name, bytes, file.size, _mimeFromExt(file.extension ?? ''));
    }

    setState(() => _uploading = false);
    _load();
  }

  Future<void> _showSaveDialog(String fileName, Uint8List bytes, int size, String mime) async {
    String title = fileName.replaceAll(RegExp(r'\.(pdf|jpg|jpeg|png|heic|tiff)$', caseSensitive: false), '');
    String category = 'Medical Report';
    String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String notes = '';

    await showDialog(context: context, builder: (_) => _SaveDocDialog(
      initialTitle: title,
      initialCategory: category,
      initialDate: date,
      fileName: fileName,
      fileSize: size,
      onSave: (t, c, d, n) async {
        title = t; category = c; date = d; notes = n;
        final db = await AppDatabase.instance;
        await db.insert('documents', {
          'id': const Uuid().v4(),
          'title': title,
          'category': category,
          'file_name': fileName,
          'file_size': size,
          'mime_type': mime,
          'bytes': bytes,
          'date': date,
          'notes': notes,
          'created_at': DateTime.now().toIso8601String(),
        });
      },
    ));
  }

  String _mimeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      default: return 'application/octet-stream';
    }
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Color _categoryColor(String? cat) {
    switch (cat) {
      case 'Lab Report': return AppTheme.warning;
      case 'Imaging / Scan': return AppTheme.danger;
      case 'Cardiology': return AppTheme.danger;
      case 'Surgical / Procedure': return AppTheme.secondary;
      case 'Pathology': return Color(0xFF14B8A6);
      case 'Prescription': return AppTheme.primary;
      case 'Insurance / EOB': return AppTheme.textSecondary;
      default: return AppTheme.accent;
    }
  }

  IconData _categoryIcon(String? cat) {
    switch (cat) {
      case 'Lab Report': return Icons.biotech;
      case 'Imaging / Scan': return Icons.medical_services;
      case 'Cardiology': return Icons.favorite;
      case 'DEXA / Body Comp': return Icons.accessibility_new;
      case 'Pathology': return Icons.science;
      case 'Prescription': return Icons.medication;
      default: return Icons.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Documents'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_uploading)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)))
          else
            IconButton(icon: const Icon(Icons.upload_file), onPressed: _pickAndUpload, tooltip: 'Upload document'),
        ],
      ),
      body: Column(
        children: [
          // Upload zone
          GestureDetector(
            onTap: _uploading ? null : _pickAndUpload,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5, style: BorderStyle.none),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, color: AppTheme.primary.withValues(alpha: 0.7), size: 40),
                  const SizedBox(height: 10),
                  const Text('Drop files here or tap to browse', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('PDF, JPG, PNG, HEIC, TIFF', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ),

          if (_docs.isEmpty)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_open_outlined, size: 64, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  const Text('No documents yet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Upload lab reports, imaging results, prescriptions,\nor any medical PDF', style: TextStyle(color: AppTheme.textSecondary, height: 1.5), textAlign: TextAlign.center),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                itemCount: _docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final doc = _docs[i];
                  final color = _categoryColor(doc['category'] as String?);
                  return HvCard(
                    onTap: () => _showDocDetail(doc),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                          child: Icon(_categoryIcon(doc['category'] as String?), color: color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(doc['title'] as String? ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Row(children: [
                                if (doc['category'] != null) StatusBadge(label: doc['category'] as String, color: color),
                                const SizedBox(width: 6),
                                Text(doc['date'] as String? ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                              ]),
                              const SizedBox(height: 2),
                              Text('${doc['file_name']}  ·  ${_formatSize(doc['file_size'] as int?)}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        PopupMenuButton(
                          icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 18),
                          color: AppTheme.surface,
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.danger))),
                          ],
                          onSelected: (v) async {
                            if (v == 'delete') {
                              final db = await AppDatabase.instance;
                              await db.delete('documents', where: 'id = ?', whereArgs: [doc['id']]);
                              _load();
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showDocDetail(Map<String, dynamic> doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doc['title'] as String? ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 16),
            _DetailRow('Category', doc['category'] as String? ?? '—'),
            _DetailRow('Date', doc['date'] as String? ?? '—'),
            _DetailRow('File', '${doc['file_name']}  (${_formatSize(doc['file_size'] as int?)})'),
            if (doc['notes'] != null && (doc['notes'] as String).isNotEmpty)
              _DetailRow('Notes', doc['notes'] as String),
            const SizedBox(height: 16),
            const Text('File stored securely on this device.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
      ],
    ),
  );
}

class _SaveDocDialog extends StatefulWidget {
  final String initialTitle, initialCategory, initialDate, fileName;
  final int fileSize;
  final Future<void> Function(String title, String category, String date, String notes) onSave;
  const _SaveDocDialog({required this.initialTitle, required this.initialCategory, required this.initialDate, required this.fileName, required this.fileSize, required this.onSave});
  @override
  State<_SaveDocDialog> createState() => _SaveDocDialogState();
}

class _SaveDocDialogState extends State<_SaveDocDialog> {
  late TextEditingController _title;
  late TextEditingController _date;
  late TextEditingController _notes;
  late String _category;
  bool _saving = false;

  static const _categories = ['Medical Report', 'Lab Report', 'Imaging / Scan', 'Cardiology', 'DEXA / Body Comp', 'Pathology', 'Surgical / Procedure', 'Prescription', 'Insurance / EOB', 'Genetic Report', 'Other'];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle);
    _date = TextEditingController(text: widget.initialDate);
    _notes = TextEditingController();
    _category = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Save Document', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.insert_drive_file, color: AppTheme.textSecondary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(widget.fileName, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                ]),
              ),
              const SizedBox(height: 14),
              TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title *'), style: const TextStyle(color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: AppTheme.surface,
                decoration: const InputDecoration(labelText: 'Category'),
                style: const TextStyle(color: AppTheme.textPrimary),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _date, decoration: const InputDecoration(labelText: 'Document Date', hintText: 'YYYY-MM-DD'), style: const TextStyle(color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes'), style: const TextStyle(color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Skip')),
        ElevatedButton(
          onPressed: _saving ? null : () async {
            setState(() => _saving = true);
            await widget.onSave(_title.text, _category, _date.text, _notes.text);
            if (context.mounted) Navigator.pop(context);
          },
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
        ),
      ],
    );
  }
}

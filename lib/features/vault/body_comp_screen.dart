import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/core/widgets/stat_card.dart';
import 'package:vasan_health/core/database/database.dart';
import 'package:uuid/uuid.dart';

class BodyCompScreen extends StatefulWidget {
  const BodyCompScreen({super.key});
  @override
  State<BodyCompScreen> createState() => _BodyCompScreenState();
}

class _BodyCompScreenState extends State<BodyCompScreen> {
  List<Map<String, dynamic>> _scans = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('body_compositions', orderBy: 'date ASC');
    setState(() => _scans = rows);
  }

  @override
  Widget build(BuildContext context) {
    final latest = _scans.isNotEmpty ? _scans.last : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Body Composition'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (latest != null) ...[
              _BodyCompSummary(data: latest),
              const SizedBox(height: 24),
            ],
            if (_scans.length > 1) ...[
              const SectionHeader(title: 'Trend'),
              const SizedBox(height: 12),
              _TrendChart(scans: _scans),
              const SizedBox(height: 24),
            ],
            SectionHeader(title: 'All Scans', actionLabel: 'Add Scan', onAction: _showAddDialog),
            const SizedBox(height: 12),
            if (_scans.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const Icon(Icons.accessibility_new_outlined, size: 64, color: AppTheme.textSecondary),
                      const SizedBox(height: 16),
                      const Text('No body composition data', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      const Text('Log DEXA, InBody, or manual measurements', style: TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(onPressed: _showAddDialog, icon: const Icon(Icons.add), label: const Text('Add Scan')),
                    ],
                  ),
                ),
              )
            else
              ..._scans.reversed.map((s) => _ScanCard(scan: s)).toList(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _showAddDialog() {
    showDialog(context: context, builder: (_) => _AddBodyCompDialog(onSave: (data) async {
      final db = await AppDatabase.instance;
      await db.insert('body_compositions', {
        'id': const Uuid().v4(),
        ...data,
        'created_at': DateTime.now().toIso8601String(),
      });
      _load();
    }));
  }
}

class _BodyCompSummary extends StatelessWidget {
  final Map<String, dynamic> data;
  const _BodyCompSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Latest Results'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            StatCard(label: 'Body Fat', value: '${data['body_fat_percent'] ?? '--'}', unit: '%', icon: Icons.percent, color: AppTheme.warning),
            StatCard(label: 'Lean Mass', value: '${data['lean_mass_kg'] ?? '--'}', unit: 'kg', icon: Icons.fitness_center, color: AppTheme.accent),
            StatCard(label: 'Weight', value: '${data['weight_kg'] ?? '--'}', unit: 'kg', icon: Icons.monitor_weight, color: AppTheme.primary),
            StatCard(label: 'Bone Density', value: '${data['bone_density'] ?? '--'}', unit: 'g/cm²', icon: Icons.accessibility_new, color: AppTheme.secondary),
          ],
        ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> scans;
  const _TrendChart({required this.scans});

  @override
  Widget build(BuildContext context) {
    final fatSpots = scans.asMap().entries.where((e) => e.value['body_fat_percent'] != null).map((e) => FlSpot(e.key.toDouble(), (e.value['body_fat_percent'] as num).toDouble())).toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: fatSpots.length < 2
          ? const Center(child: Text('Need 2+ scans for trend', style: TextStyle(color: AppTheme.textSecondary)))
          : LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: fatSpots,
                    isCurved: true,
                    color: AppTheme.warning,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.warning.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  final Map<String, dynamic> scan;
  const _ScanCard({required this.scan});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: HvCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.accessibility_new, color: AppTheme.secondary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(scan['scan_type'] ?? 'Scan', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                  Text(scan['date'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (scan['body_fat_percent'] != null) Text('${scan['body_fat_percent']}% fat', style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w600)),
                if (scan['weight_kg'] != null) Text('${scan['weight_kg']} kg', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddBodyCompDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const _AddBodyCompDialog({required this.onSave});
  @override
  State<_AddBodyCompDialog> createState() => _AddBodyCompDialogState();
}

class _AddBodyCompDialogState extends State<_AddBodyCompDialog> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'DEXA';
  final _date = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _weight = TextEditingController();
  final _fat = TextEditingController();
  final _lean = TextEditingController();
  final _bone = TextEditingController();
  final _visceral = TextEditingController();
  final _notes = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add Body Composition', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _type,
                    dropdownColor: AppTheme.surface,
                    decoration: const InputDecoration(labelText: 'Scan Type'),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    items: ['DEXA', 'InBody', 'Bod Pod', 'Hydrostatic', 'Manual'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _date, decoration: const InputDecoration(labelText: 'Date'), style: const TextStyle(color: AppTheme.textPrimary))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: _weight, decoration: const InputDecoration(labelText: 'Weight (kg)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _fat, decoration: const InputDecoration(labelText: 'Body Fat (%)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: _lean, decoration: const InputDecoration(labelText: 'Lean Mass (kg)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _bone, decoration: const InputDecoration(labelText: 'Bone Density (g/cm²)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: _visceral, decoration: const InputDecoration(labelText: 'Visceral Fat (%)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes'), style: const TextStyle(color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave({
                'date': _date.text,
                'scan_type': _type,
                'weight_kg': double.tryParse(_weight.text),
                'body_fat_percent': double.tryParse(_fat.text),
                'lean_mass_kg': double.tryParse(_lean.text),
                'bone_density': double.tryParse(_bone.text),
                'visceral_fat': double.tryParse(_visceral.text),
                'notes': _notes.text,
              });
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

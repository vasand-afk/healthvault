import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/core/widgets/stat_card.dart';
import 'package:vasan_health/core/database/database.dart';
import 'package:uuid/uuid.dart';

class WearableScreen extends StatefulWidget {
  const WearableScreen({super.key});
  @override
  State<WearableScreen> createState() => _WearableScreenState();
}

class _WearableScreenState extends State<WearableScreen> {
  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('wearable_data', orderBy: 'date DESC', limit: 30);
    setState(() => _data = rows);
  }

  @override
  Widget build(BuildContext context) {
    final latest = _data.isNotEmpty ? _data.first : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wearable Data'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog),
          IconButton(icon: const Icon(Icons.sync), onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Apple Health import coming soon'), backgroundColor: AppTheme.surface),
            );
          }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConnectSources(),
            const SizedBox(height: 24),
            if (latest != null) ...[
              const SectionHeader(title: 'Latest Data'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  StatCard(label: 'Steps', value: '${latest['steps'] ?? '--'}', icon: Icons.directions_walk, color: AppTheme.accent),
                  StatCard(label: 'Resting HR', value: '${latest['resting_hr'] ?? '--'}', unit: 'bpm', icon: Icons.monitor_heart, color: AppTheme.danger),
                  StatCard(label: 'HRV', value: '${latest['hrv'] ?? '--'}', unit: 'ms', icon: Icons.favorite, color: AppTheme.secondary),
                  StatCard(label: 'SpO2', value: '${latest['spo2'] ?? '--'}', unit: '%', icon: Icons.air, color: AppTheme.primary),
                  StatCard(label: 'Sleep', value: '${latest['sleep_hours'] ?? '--'}', unit: 'hrs', icon: Icons.bedtime, color: AppTheme.secondary),
                  StatCard(label: 'Active Cal', value: '${latest['active_calories'] ?? '--'}', unit: 'kcal', icon: Icons.bolt, color: AppTheme.warning),
                ],
              ),
              const SizedBox(height: 24),
            ],
            if (_data.length > 1) ...[
              const SectionHeader(title: 'HRV Trend (30 days)'),
              const SizedBox(height: 12),
              _HRVChart(data: _data),
              const SizedBox(height: 24),
            ],
            SectionHeader(title: 'History', actionLabel: 'Add Entry', onAction: _showAddDialog),
            const SizedBox(height: 12),
            if (_data.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const Icon(Icons.watch_outlined, size: 64, color: AppTheme.textSecondary),
                      const SizedBox(height: 16),
                      const Text('No wearable data', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(onPressed: _showAddDialog, icon: const Icon(Icons.add), label: const Text('Add Entry')),
                    ],
                  ),
                ),
              )
            else
              ..._data.take(14).map((d) => _WearableRow(data: d)).toList(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _showAddDialog() {
    showDialog(context: context, builder: (_) => _AddWearableDialog(onSave: (data) async {
      final db = await AppDatabase.instance;
      await db.insert('wearable_data', {
        'id': const Uuid().v4(),
        ...data,
        'created_at': DateTime.now().toIso8601String(),
      });
      _load();
    }));
  }
}

class _ConnectSources extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sources = [
      _Source('Apple Watch', Icons.watch, AppTheme.primary, true),
      _Source('Oura Ring', Icons.circle_outlined, AppTheme.secondary, false),
      _Source('Garmin', Icons.gps_fixed, AppTheme.accent, false),
      _Source('Whoop', AppTheme.danger == AppTheme.danger ? Icons.monitor_heart : Icons.watch, AppTheme.danger, false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Connected Sources'),
        const SizedBox(height: 12),
        Row(
          children: sources.map((s) => Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: s.connected ? s.color.withValues(alpha: 0.15) : AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: s.connected ? s.color.withValues(alpha: 0.4) : AppTheme.border),
              ),
              child: Column(
                children: [
                  Icon(s.icon, color: s.connected ? s.color : AppTheme.textSecondary, size: 22),
                  const SizedBox(height: 6),
                  Text(s.name, style: TextStyle(color: s.connected ? s.color : AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                  const SizedBox(height: 2),
                  Text(s.connected ? 'Active' : 'Connect', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                ],
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }
}

class _Source {
  final String name;
  final IconData icon;
  final Color color;
  final bool connected;
  const _Source(this.name, this.icon, this.color, this.connected);
}

class _HRVChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _HRVChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = data.reversed.toList().asMap().entries.where((e) => e.value['hrv'] != null).map((e) => FlSpot(e.key.toDouble(), (e.value['hrv'] as num).toDouble())).toList();

    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: spots.length < 2
          ? const Center(child: Text('Need more data for trend', style: TextStyle(color: AppTheme.textSecondary)))
          : LineChart(LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppTheme.secondary,
                  barWidth: 2,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: AppTheme.secondary.withValues(alpha: 0.1)),
                ),
              ],
            )),
    );
  }
}

class _WearableRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _WearableRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Row(
        children: [
          const Icon(Icons.watch, color: AppTheme.primary, size: 18),
          const SizedBox(width: 10),
          Text(data['date'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          const Spacer(),
          if (data['steps'] != null) _Metric('${data['steps']}', 'steps', AppTheme.accent),
          const SizedBox(width: 16),
          if (data['hrv'] != null) _Metric('${data['hrv']}', 'HRV', AppTheme.secondary),
          const SizedBox(width: 16),
          if (data['resting_hr'] != null) _Metric('${data['resting_hr']}', 'HR', AppTheme.danger),
          const SizedBox(width: 16),
          if (data['sleep_hours'] != null) _Metric('${data['sleep_hours']}h', 'sleep', AppTheme.primary),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Metric(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ],
    );
  }
}

class _AddWearableDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const _AddWearableDialog({required this.onSave});
  @override
  State<_AddWearableDialog> createState() => _AddWearableDialogState();
}

class _AddWearableDialogState extends State<_AddWearableDialog> {
  final _date = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _steps = TextEditingController();
  final _calories = TextEditingController();
  final _hr = TextEditingController();
  final _hrv = TextEditingController();
  final _spo2 = TextEditingController();
  final _sleep = TextEditingController();
  String _source = 'Apple Watch';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Add Wearable Entry', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _source,
                  dropdownColor: AppTheme.surface,
                  decoration: const InputDecoration(labelText: 'Source'),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  items: ['Apple Watch', 'Oura', 'Garmin', 'Whoop', 'Manual'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _source = v!),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _date, decoration: const InputDecoration(labelText: 'Date'), style: const TextStyle(color: AppTheme.textPrimary))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _steps, decoration: const InputDecoration(labelText: 'Steps'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _calories, decoration: const InputDecoration(labelText: 'Active Cal'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _hr, decoration: const InputDecoration(labelText: 'Resting HR (bpm)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _hrv, decoration: const InputDecoration(labelText: 'HRV (ms)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _spo2, decoration: const InputDecoration(labelText: 'SpO2 (%)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _sleep, decoration: const InputDecoration(labelText: 'Sleep (hrs)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onSave({
              'date': _date.text,
              'source': _source,
              'steps': int.tryParse(_steps.text),
              'active_calories': double.tryParse(_calories.text),
              'resting_hr': double.tryParse(_hr.text),
              'hrv': double.tryParse(_hrv.text),
              'spo2': double.tryParse(_spo2.text),
              'sleep_hours': double.tryParse(_sleep.text),
            });
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

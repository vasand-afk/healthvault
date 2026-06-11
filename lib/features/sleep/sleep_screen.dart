import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/core/widgets/stat_card.dart';
import 'package:healthvault/core/database/database.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});
  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('sleep_logs', orderBy: 'date DESC', limit: 14);
    setState(() => _logs = rows);
  }

  @override
  Widget build(BuildContext context) {
    final latest = _logs.isNotEmpty ? _logs.first : null;
    final avg7 = _logs.take(7).fold(0.0, (s, e) => s + ((e['total_hours'] as num?)?.toDouble() ?? 0)) / (_logs.take(7).length > 0 ? _logs.take(7).length : 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep & Recovery'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (latest != null) ...[
              _SleepScoreCard(log: latest),
              const SizedBox(height: 20),
            ],
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                StatCard(label: '7-Day Avg', value: avg7.toStringAsFixed(1), unit: 'hrs', icon: Icons.bedtime, color: AppTheme.secondary),
                StatCard(label: 'Deep Sleep', value: latest != null ? '${(latest['deep_hours'] as num?)?.toStringAsFixed(1) ?? '--'}' : '--', unit: 'hrs', icon: Icons.nights_stay, color: AppTheme.primary),
                StatCard(label: 'REM', value: latest != null ? '${(latest['rem_hours'] as num?)?.toStringAsFixed(1) ?? '--'}' : '--', unit: 'hrs', icon: Icons.psychology, color: AppTheme.secondary),
                StatCard(label: 'HRV', value: latest?['hrv_avg']?.toString() ?? '--', unit: 'ms', icon: Icons.favorite, color: AppTheme.danger),
              ],
            ),
            const SizedBox(height: 24),
            if (_logs.length > 1) ...[
              const SectionHeader(title: 'Sleep Duration (14 days)'),
              const SizedBox(height: 12),
              _SleepChart(logs: _logs),
              const SizedBox(height: 24),
            ],
            SectionHeader(title: 'Sleep Log', actionLabel: 'Add', onAction: _showAddDialog),
            const SizedBox(height: 12),
            if (_logs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const Icon(Icons.bedtime_outlined, size: 64, color: AppTheme.textSecondary),
                      const SizedBox(height: 16),
                      const Text('No sleep data yet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(onPressed: _showAddDialog, icon: const Icon(Icons.add), label: const Text('Log Sleep')),
                    ],
                  ),
                ),
              )
            else
              ..._logs.map((log) => _SleepRow(log: log)).toList(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _showAddDialog() {
    showDialog(context: context, builder: (_) => _AddSleepDialog(onSave: (data) async {
      final db = await AppDatabase.instance;
      await db.insert('sleep_logs', {
        'id': const Uuid().v4(),
        ...data,
        'created_at': DateTime.now().toIso8601String(),
      });
      _load();
    }));
  }
}

class _SleepScoreCard extends StatelessWidget {
  final Map<String, dynamic> log;
  const _SleepScoreCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final score = log['sleep_score'] as int? ?? 0;
    final color = score >= 85 ? AppTheme.accent : score >= 70 ? AppTheme.warning : AppTheme.danger;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Column(
            children: [
              SizedBox(
                width: 80, height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100,
                      backgroundColor: AppTheme.surface,
                      valueColor: AlwaysStoppedAnimation(color),
                      strokeWidth: 8,
                    ),
                    Text('$score', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text('Sleep Score', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last night · ${log['date'] ?? ''}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _SleepStagePill('Total', '${(log['total_hours'] as num?)?.toStringAsFixed(1) ?? '--'}h', AppTheme.textPrimary),
                    const SizedBox(width: 8),
                    _SleepStagePill('Deep', '${(log['deep_hours'] as num?)?.toStringAsFixed(1) ?? '--'}h', AppTheme.primary),
                    const SizedBox(width: 8),
                    _SleepStagePill('REM', '${(log['rem_hours'] as num?)?.toStringAsFixed(1) ?? '--'}h', AppTheme.secondary),
                  ],
                ),
                if (log['hrv_avg'] != null) ...[
                  const SizedBox(height: 8),
                  Text('HRV: ${log['hrv_avg']}ms  •  RHR: ${log['resting_hr'] ?? '--'}bpm', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepStagePill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SleepStagePill(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
        ],
      ),
    );
  }
}

class _SleepChart extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  const _SleepChart({required this.logs});

  @override
  Widget build(BuildContext context) {
    final reversed = logs.reversed.toList();
    final bars = reversed.asMap().entries.map((e) => BarChartGroupData(
      x: e.key,
      barRods: [BarChartRodData(
        toY: (e.value['total_hours'] as num?)?.toDouble() ?? 0,
        color: AppTheme.secondary,
        width: 14,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        rodStackItems: [
          BarChartRodStackItem(0, (e.value['deep_hours'] as num?)?.toDouble() ?? 0, AppTheme.primary),
          BarChartRodStackItem((e.value['deep_hours'] as num?)?.toDouble() ?? 0, ((e.value['deep_hours'] as num?)?.toDouble() ?? 0) + ((e.value['rem_hours'] as num?)?.toDouble() ?? 0), AppTheme.secondary),
        ],
      )],
    )).toList();

    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: BarChart(BarChartData(
        barGroups: bars,
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        maxY: 10,
      )),
    );
  }
}

class _SleepRow extends StatelessWidget {
  final Map<String, dynamic> log;
  const _SleepRow({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Row(
        children: [
          const Icon(Icons.bedtime, color: AppTheme.secondary, size: 18),
          const SizedBox(width: 10),
          Text(log['date'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const Spacer(),
          Text('${(log['total_hours'] as num?)?.toStringAsFixed(1) ?? '--'}h', style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w700, fontSize: 15)),
          if (log['sleep_score'] != null) ...[
            const SizedBox(width: 12),
            StatusBadge(
              label: '${log['sleep_score']}',
              color: (log['sleep_score'] as int) >= 85 ? AppTheme.accent : AppTheme.warning,
            ),
          ],
        ],
      ),
    );
  }
}

class _AddSleepDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const _AddSleepDialog({required this.onSave});
  @override
  State<_AddSleepDialog> createState() => _AddSleepDialogState();
}

class _AddSleepDialogState extends State<_AddSleepDialog> {
  final _date = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _bedtime = TextEditingController(text: '22:30');
  final _wake = TextEditingController(text: '06:30');
  final _total = TextEditingController();
  final _deep = TextEditingController();
  final _rem = TextEditingController();
  final _hrv = TextEditingController();
  final _hr = TextEditingController();
  final _score = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Log Sleep', style: TextStyle(color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(child: TextFormField(controller: _date, decoration: const InputDecoration(labelText: 'Date'), style: const TextStyle(color: AppTheme.textPrimary))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _score, decoration: const InputDecoration(labelText: 'Sleep Score (0–100)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(controller: _bedtime, decoration: const InputDecoration(labelText: 'Bedtime'), style: const TextStyle(color: AppTheme.textPrimary))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _wake, decoration: const InputDecoration(labelText: 'Wake Time'), style: const TextStyle(color: AppTheme.textPrimary))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(controller: _total, decoration: const InputDecoration(labelText: 'Total Hours'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _deep, decoration: const InputDecoration(labelText: 'Deep (hrs)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _rem, decoration: const InputDecoration(labelText: 'REM (hrs)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(controller: _hrv, decoration: const InputDecoration(labelText: 'HRV (ms)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _hr, decoration: const InputDecoration(labelText: 'Resting HR (bpm)'), style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.number)),
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
              'bedtime': _bedtime.text,
              'wake_time': _wake.text,
              'total_hours': double.tryParse(_total.text),
              'deep_hours': double.tryParse(_deep.text),
              'rem_hours': double.tryParse(_rem.text),
              'hrv_avg': double.tryParse(_hrv.text),
              'resting_hr': double.tryParse(_hr.text),
              'sleep_score': int.tryParse(_score.text),
            });
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

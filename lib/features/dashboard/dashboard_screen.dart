import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vasan_health/core/database/database.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/core/widgets/stat_card.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;

  // Daily vitals
  int _sunlightMinutes = 0;
  int _vitdSupplementIU = 0;

  // Today's stats
  double _calories = 0;
  double _protein = 0;
  double _carbs = 0;
  double _fat = 0;
  int _steps = 0;
  double _waterL = 0;
  double? _sleepHrs;
  double? _hrv;
  double? _restingHr;
  double? _weightKg;
  double? _activeCal;
  int _dueReminders = 0;

  // Dynamic score inputs
  int _supplementsToday = 0;
  int _activitiesThisWeek = 0;

  // Upcoming
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _remindersToday = [];

  // Insights
  List<_Insight> _insights = [];

  final String _today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final db = await AppDatabase.instance;

    // Calories + macros (today)
    final foods = await db.query('food_logs', where: 'date = ?', whereArgs: [_today]);
    double cal = 0, prot = 0, carb = 0, fat = 0;
    for (final f in foods) {
      cal  += (f['calories'] as num? ?? 0).toDouble();
      prot += (f['protein_g'] as num? ?? 0).toDouble();
      carb += (f['carbs_g'] as num? ?? 0).toDouble();
      fat  += (f['fat_g'] as num? ?? 0).toDouble();
    }

    // Water (today)
    final waters = await db.query('water_logs', where: 'date = ?', whereArgs: [_today]);
    double water = 0;
    for (final w in waters) water += (w['amount_ml'] as num? ?? 0).toDouble();

    // Wearable today (prefer today, fall back to latest)
    var wear = await db.query('wearable_data', where: 'date = ?', whereArgs: [_today], limit: 1);
    if (wear.isEmpty) wear = await db.query('wearable_data', orderBy: 'date DESC', limit: 1);
    final w = wear.isNotEmpty ? wear.first : null;

    // Sleep (last night)
    var sleepRows = await db.query('sleep_logs', orderBy: 'date DESC', limit: 1);
    final sleep = sleepRows.isNotEmpty ? sleepRows.first : null;

    // Weight (latest)
    var bodyRows = await db.query('body_compositions', orderBy: 'date DESC', limit: 1);
    final body = bodyRows.isNotEmpty ? bodyRows.first : null;

    // Supplement check-ins today
    final suppLogs = await db.query('supplement_logs', where: 'date = ?', whereArgs: [_today]);

    // Activities this week
    final weekStart = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)));
    final acts = await db.query('activities', where: 'date >= ?', whereArgs: [weekStart]);

    // Upcoming appointments (next 30 days)
    final next30 = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30)));
    final appts = await db.query('appointments',
      where: 'date_time >= ? AND date_time <= ? AND completed = 0',
      whereArgs: [_today, '$next30 23:59'],
      orderBy: 'date_time ASC', limit: 5);

    // Sunlight today
    final sunRows = await db.query('sunlight_logs', where: 'date = ?', whereArgs: [_today]);
    int sunMins = 0, vitdIU = 0;
    for (final s in sunRows) {
      sunMins += (s['minutes'] as int? ?? 0);
      vitdIU += (s['vitd_supplement_iu'] as int? ?? 0);
    }

    // Due reminders
    final reminderRows = await db.query('reminders',
      where: 'enabled = 1 AND next_due <= ?', whereArgs: [_today]);

    if (mounted) {
      setState(() {
        _calories = cal; _protein = prot; _carbs = carb; _fat = fat;
        _waterL = water / 1000;
        _steps = (w?['steps'] as int?) ?? 0;
        _hrv = (w?['hrv'] as num?)?.toDouble();
        _restingHr = (w?['resting_hr'] as num?)?.toDouble();
        _activeCal = (w?['active_calories'] as num?)?.toDouble();
        _sleepHrs = (sleep?['total_hours'] as num?)?.toDouble();
        _weightKg = (body?['weight_kg'] as num?)?.toDouble();
        _sunlightMinutes = sunMins;
        _vitdSupplementIU = vitdIU;
        _supplementsToday = suppLogs.length;
        _activitiesThisWeek = acts.length;
        _appointments = appts;
        _remindersToday = reminderRows;
        _dueReminders = reminderRows.length;
        _loading = false;
        _insights = _buildInsights();
      });
    }
  }

  List<_Insight> _buildInsights() {
    final insights = <_Insight>[];
    if (_sleepHrs != null && _sleepHrs! < 7.0) insights.add(_Insight(Icons.bedtime, AppTheme.secondary, 'Sleep deficit', 'You got ${_sleepHrs!.toStringAsFixed(1)}h last night. Aim for 7–9h. Poor sleep raises cortisol and slows recovery.'));
    if (_hrv != null && _hrv! > 60) insights.add(_Insight(Icons.favorite, AppTheme.accent, 'HRV looking great', 'HRV of ${_hrv!.toStringAsFixed(0)}ms signals good recovery. Good day to train hard.'));
    if (_hrv != null && _hrv! < 30) insights.add(_Insight(Icons.warning_amber, AppTheme.warning, 'Low HRV — recover today', 'HRV of ${_hrv!.toStringAsFixed(0)}ms indicates stress or fatigue. Prioritise sleep and light movement.'));
    if (_calories > 0 && _protein < 100) insights.add(_Insight(Icons.restaurant, AppTheme.warning, 'Protein behind target', '${_protein.toStringAsFixed(0)}g protein logged so far. Add a protein-rich meal to hit your daily goal.'));
    if (_steps > 0 && _steps >= 10000) insights.add(_Insight(Icons.directions_walk, AppTheme.accent, '10k steps hit!', '${NumberFormat('#,###').format(_steps)} steps — great movement day. Consistency builds cardiovascular resilience.'));
    if (_steps > 0 && _steps < 5000 && DateTime.now().hour > 16) insights.add(_Insight(Icons.directions_walk, AppTheme.warning, 'Low step count', 'Only ${NumberFormat('#,###').format(_steps)} steps by afternoon. A 20-min walk adds ~2,000 steps.'));
    if (_waterL < 1.5 && DateTime.now().hour > 14) insights.add(_Insight(Icons.water_drop, AppTheme.primary, 'Hydration behind', '${_waterL.toStringAsFixed(1)}L so far. Aim for 2–3L daily. Dehydration impairs cognition within 1–2% deficit.'));
    if (_activitiesThisWeek == 0 && DateTime.now().weekday >= 3) insights.add(_Insight(Icons.fitness_center, AppTheme.danger, 'No workouts logged this week', 'Log your first workout of the week. Resistance training 3×/week is the top longevity intervention.'));
    if (insights.isEmpty) insights.add(_Insight(Icons.check_circle, AppTheme.accent, 'Looking good today', 'Keep logging your data — more entries unlock deeper insights and trends.'));
    return insights.take(3).toList();
  }

  // Simple health score: 0–100
  int get _healthScore {
    int score = 50;
    if (_sleepHrs != null) score += (_sleepHrs! >= 7 ? 15 : (_sleepHrs! >= 6 ? 7 : 0));
    if (_steps > 0) score += (_steps >= 10000 ? 15 : (_steps >= 7000 ? 10 : (_steps >= 4000 ? 5 : 0)));
    if (_hrv != null) score += (_hrv! >= 50 ? 10 : (_hrv! >= 30 ? 5 : 0));
    if (_protein >= 120) score += 5;
    if (_waterL >= 2.0) score += 5;
    return score.clamp(0, 100);
  }

  Future<void> _showSunlightDialog(BuildContext context) async {
    int minutes = 15;
    int vitdIU = 0;
    String timeOfDay = 'Morning';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Log Sunlight & Vit D', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          const Text('Sunlight exposure', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            for (final m in [10, 15, 20, 30, 45, 60])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setModal(() => minutes = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: minutes == m ? AppTheme.warning.withValues(alpha: 0.2) : AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: minutes == m ? AppTheme.warning : AppTheme.border),
                    ),
                    child: Text('${m}m', style: TextStyle(color: minutes == m ? AppTheme.warning : AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          const Text('Time of day', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            for (final t in ['Morning', 'Midday', 'Afternoon'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setModal(() => timeOfDay = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: timeOfDay == t ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: timeOfDay == t ? AppTheme.primary : AppTheme.border),
                    ),
                    child: Text(t, style: TextStyle(color: timeOfDay == t ? AppTheme.primary : AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          const Text('Vit D supplement (IU) — 0 if none', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            for (final iu in [0, 1000, 2000, 4000, 5000])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setModal(() => vitdIU = iu),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: vitdIU == iu ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: vitdIU == iu ? AppTheme.accent : AppTheme.border),
                    ),
                    child: Text(iu == 0 ? 'None' : '${iu ~/ 1000}k', style: TextStyle(color: vitdIU == iu ? AppTheme.accent : AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final db = await AppDatabase.instance;
              await db.insert('sunlight_logs', {
                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                'date': _today,
                'minutes': minutes,
                'time_of_day': timeOfDay,
                'vitd_supplement_iu': vitdIU,
                'created_at': DateTime.now().toIso8601String(),
              });
              if (mounted) { Navigator.pop(ctx); _load(); }
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          )),
        ]),
      )),
    );
  }

  String get _scoreLabel {
    final s = _healthScore;
    if (s >= 85) return 'Excellent';
    if (s >= 70) return 'Good';
    if (s >= 55) return 'Fair';
    return 'Needs attention';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good morning' : now.hour < 17 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(greeting, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 2),
                  const Text('Your Health Today', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                ]),
                Row(children: [
                  if (_dueReminders > 0) GestureDetector(
                    onTap: () => context.go('/reminders'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4))),
                      child: Row(children: [
                        const Icon(Icons.notifications_active, color: AppTheme.warning, size: 16),
                        const SizedBox(width: 5),
                        Text('$_dueReminders due', style: const TextStyle(color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(DateFormat('EEE, MMM d').format(now), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ]),
              ]),
              const SizedBox(height: 20),
              _HealthScoreCard(score: _healthScore, label: _scoreLabel, loading: _loading,
                sleepPct: _sleepHrs != null ? (_sleepHrs! / 8.0).clamp(0, 1) : 0,
                nutritionPct: _calories > 0 ? (_protein / 150.0).clamp(0, 1) : 0,
                activityPct: (_steps / 10000.0).clamp(0, 1),
                onCoach: () => context.go('/ai-coach'),
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Today\'s Snapshot'),
              const SizedBox(height: 12),
              _loading ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())) : _StatsGrid(
                calories: _calories, steps: _steps, sleepHrs: _sleepHrs,
                hrv: _hrv, waterL: _waterL, weightKg: _weightKg,
                restingHr: _restingHr, activeCal: _activeCal,
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Quick Log'),
              const SizedBox(height: 12),
              _QuickLogRow(),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Daily Vitals'),
              const SizedBox(height: 12),
              _DailyVitalsSection(
                sunlightMinutes: _sunlightMinutes,
                vitdIU: _vitdSupplementIU,
                onLog: () => _showSunlightDialog(context),
              ),
              if (_remindersToday.isNotEmpty) ...[
                const SizedBox(height: 24),
                SectionHeader(title: 'Due Today', actionLabel: 'All reminders', onAction: () => context.go('/reminders')),
                const SizedBox(height: 12),
                ..._remindersToday.take(3).map((r) => _ReminderDueTile(r, onDone: () async {
                  final db = await AppDatabase.instance;
                  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                  final nxt = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));
                  await db.update('reminders', {'last_triggered': today, 'next_due': nxt}, where: 'id = ?', whereArgs: [r['id']]);
                  _load();
                })),
              ],
              if (_appointments.isNotEmpty) ...[
                const SizedBox(height: 24),
                const SectionHeader(title: 'Upcoming'),
                const SizedBox(height: 12),
                ..._appointments.take(3).map((a) => _AppointmentTile(a)),
              ] else if (!_loading) ...[
                const SizedBox(height: 24),
                const SectionHeader(title: 'Upcoming'),
                const SizedBox(height: 12),
                _EmptyUpcoming(onAdd: () => context.go('/vault/diagnoses')),
              ],
              const SizedBox(height: 24),
              const SectionHeader(title: 'Insights'),
              const SizedBox(height: 12),
              ..._insights.map((i) => _InsightCard(i)),
              const SizedBox(height: 100),
            ]),
          )),
        ]),
      ),
    );
  }
}

// ─── Health Score Card ────────────────────────────────────────────────────────

class _HealthScoreCard extends StatelessWidget {
  final int score;
  final String label;
  final double sleepPct, nutritionPct, activityPct;
  final bool loading;
  final VoidCallback onCoach;
  const _HealthScoreCard({required this.score, required this.label, required this.loading, required this.sleepPct, required this.nutritionPct, required this.activityPct, required this.onCoach});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF8B5CF6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Health Score', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          loading
              ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)))
              : Text('$score', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 12),
          _Bar('Nutrition', nutritionPct),
          const SizedBox(height: 6),
          _Bar('Sleep', sleepPct),
          const SizedBox(height: 6),
          _Bar('Activity', activityPct),
        ])),
        const SizedBox(width: 16),
        Column(children: [
          const Icon(Icons.health_and_safety, color: Colors.white, size: 48),
          const SizedBox(height: 8),
          TextButton(onPressed: onCoach, style: TextButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.2), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('AI Coach', style: TextStyle(fontSize: 12))),
        ]),
      ]),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double value;
  const _Bar(this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 70, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))),
    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: value, backgroundColor: Colors.white.withValues(alpha: 0.2), valueColor: const AlwaysStoppedAnimation<Color>(Colors.white), minHeight: 6))),
    const SizedBox(width: 8),
    Text('${(value * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
  ]);
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final double calories, waterL;
  final int steps;
  final double? sleepHrs, hrv, weightKg, restingHr, activeCal;
  const _StatsGrid({required this.calories, required this.steps, required this.sleepHrs, required this.hrv, required this.waterL, required this.weightKg, required this.restingHr, required this.activeCal});

  String _fmt(double? v, {int decimals = 0, String ifNull = '—'}) =>
      v == null || v == 0 ? ifNull : v.toStringAsFixed(decimals);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.2,
      children: [
        StatCard(label: 'Calories', value: calories > 0 ? NumberFormat('#,###').format(calories.toInt()) : '—', unit: 'kcal', icon: Icons.local_fire_department, color: const Color(0xFFF59E0B)),
        StatCard(label: 'Steps', value: steps > 0 ? NumberFormat('#,###').format(steps) : '—', icon: Icons.directions_walk, color: const Color(0xFF10B981), trend: steps >= 10000 ? '✓ goal' : null),
        StatCard(label: 'Sleep', value: _fmt(sleepHrs, decimals: 1), unit: 'hrs', icon: Icons.bedtime, color: const Color(0xFF8B5CF6), trend: sleepHrs != null && sleepHrs! >= 7 ? 'good' : null),
        StatCard(label: 'HRV', value: _fmt(hrv, decimals: 0), unit: 'ms', icon: Icons.favorite, color: const Color(0xFFEF4444)),
        StatCard(label: 'Water', value: _fmt(waterL, decimals: 1), unit: 'L', icon: Icons.water_drop, color: const Color(0xFF0EA5E9)),
        StatCard(label: 'Weight', value: _fmt(weightKg, decimals: 1), unit: 'kg', icon: Icons.monitor_weight, color: const Color(0xFF94A3B8)),
        StatCard(label: 'Resting HR', value: _fmt(restingHr, decimals: 0), unit: 'bpm', icon: Icons.monitor_heart, color: const Color(0xFFEF4444)),
        StatCard(label: 'Active Cal', value: _fmt(activeCal, decimals: 0), unit: 'kcal', icon: Icons.bolt, color: const Color(0xFFF59E0B)),
      ],
    );
  }
}

// ─── Quick Log ────────────────────────────────────────────────────────────────

class _QuickLogRow extends StatelessWidget {
  static const _actions = [
    _QA(Icons.restaurant, 'Log Food', AppTheme.warning, '/nutrition'),
    _QA(Icons.bedtime, 'Log Sleep', AppTheme.secondary, '/sleep'),
    _QA(Icons.fitness_center, 'Workout', AppTheme.primary, '/strength'),
    _QA(Icons.favorite, 'Symptoms', AppTheme.danger, '/symptoms'),
    _QA(Icons.science, 'Stack', AppTheme.accent, '/stack'),
    _QA(Icons.directions_run, 'Activity', AppTheme.accent, '/fitness'),
    _QA(Icons.notifications, 'Reminders', AppTheme.warning, '/reminders'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 88, child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _actions.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, i) {
        final a = _actions[i];
        return GestureDetector(
          onTap: () => context.go(a.path),
          child: Column(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: a.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: a.color.withValues(alpha: 0.3))), child: Icon(a.icon, color: a.color, size: 24)),
            const SizedBox(height: 6),
            Text(a.label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ]),
        );
      },
    ));
  }
}

class _QA {
  final IconData icon;
  final String label, path;
  final Color color;
  const _QA(this.icon, this.label, this.color, this.path);
}

// ─── Reminder due tile ────────────────────────────────────────────────────────

class _ReminderDueTile extends StatelessWidget {
  final Map<String, dynamic> r;
  final VoidCallback onDone;
  const _ReminderDueTile(this.r, {required this.onDone});

  IconData _icon(String? t) {
    switch (t) {
      case 'Supplement': return Icons.science;
      case 'Medication': return Icons.medication;
      case 'Lab Re-test': return Icons.biotech;
      case 'Appointment': return Icons.calendar_today;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35))),
    child: Row(children: [
      Icon(_icon(r['type'] as String?), color: AppTheme.warning, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r['title'] as String? ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        if (r['time_of_day'] != null) Text(r['time_of_day'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ])),
      TextButton(onPressed: onDone, style: TextButton.styleFrom(foregroundColor: AppTheme.accent), child: const Text('Done ✓')),
    ]),
  );
}

// ─── Appointment tile ─────────────────────────────────────────────────────────

class _AppointmentTile extends StatelessWidget {
  final Map<String, dynamic> a;
  const _AppointmentTile(this.a);
  @override
  Widget build(BuildContext context) {
    final dt = a['date_time'] as String? ?? '';
    final dateStr = dt.length >= 10 ? dt.substring(0, 10) : dt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.calendar_today, color: AppTheme.primary, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a['title'] as String? ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          if (a['provider'] != null) Text(a['provider'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(8)), child: Text(dateStr, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class _EmptyUpcoming extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyUpcoming({required this.onAdd});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
    child: Row(children: [
      const Icon(Icons.calendar_today_outlined, color: AppTheme.textSecondary, size: 20),
      const SizedBox(width: 12),
      const Expanded(child: Text('No upcoming appointments', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
      TextButton(onPressed: onAdd, child: const Text('Add', style: TextStyle(fontSize: 12))),
    ]),
  );
}

// ─── Insight card ─────────────────────────────────────────────────────────────

class _Insight {
  final IconData icon;
  final Color color;
  final String title, body;
  const _Insight(this.icon, this.color, this.title, this.body);
}

// ─── Daily Vitals ─────────────────────────────────────────────────────────────

class _DailyVitalsSection extends StatelessWidget {
  final int sunlightMinutes;
  final int vitdIU;
  final VoidCallback onLog;
  const _DailyVitalsSection({required this.sunlightMinutes, required this.vitdIU, required this.onLog});

  static const _amber = Color(0xFFF59E0B);
  static const _goalMinutes = 20;

  @override
  Widget build(BuildContext context) {
    final pct = (sunlightMinutes / _goalMinutes).clamp(0.0, 1.0);
    final met = sunlightMinutes >= _goalMinutes;

    return GestureDetector(
      onTap: onLog,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: met ? _amber.withValues(alpha: 0.4) : AppTheme.border),
        ),
        child: Row(children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(width: 52, height: 52, child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 5,
              backgroundColor: _amber.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(met ? _amber : _amber.withValues(alpha: 0.6)),
            )),
            Icon(Icons.wb_sunny, color: _amber, size: 22),
          ]),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Sunlight & Vit D', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              sunlightMinutes == 0
                ? 'No sunlight logged today'
                : '$sunlightMinutes min outdoors${vitdIU > 0 ? ' · ${vitdIU ~/ 1000}k IU Vit D' : ''}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: _amber.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(_amber),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text('Goal: ${_goalMinutes} min daily', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ])),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: _amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(met ? '✓ Done' : '+ Log', style: TextStyle(color: _amber, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final _Insight data;
  const _InsightCard(this.data);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: data.color.withValues(alpha: 0.25))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: data.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(data.icon, color: data.color, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        Text(data.body, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
      ])),
    ]),
  );
}

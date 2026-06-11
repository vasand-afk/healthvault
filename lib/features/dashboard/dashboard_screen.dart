import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/core/widgets/stat_card.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good morning' : now.hour < 17 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(greeting, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                          const SizedBox(height: 2),
                          const Text(
                            'Your Health Today',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        DateFormat('EEE, MMM d').format(now),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _HealthScoreCard(),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Today\'s Snapshot'),
                  const SizedBox(height: 12),
                  _StatsGrid(),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Quick Log'),
                  const SizedBox(height: 12),
                  _QuickLogRow(),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Upcoming', actionLabel: 'View all'),
                  const SizedBox(height: 12),
                  _UpcomingList(),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Recent Insights'),
                  const SizedBox(height: 12),
                  _InsightCards(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthScoreCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Health Score',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  '82',
                  style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800),
                ),
                const Text(
                  'Good — 3 areas need attention',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                _ScoreBar(label: 'Nutrition', value: 0.75, color: Colors.white),
                const SizedBox(height: 6),
                _ScoreBar(label: 'Sleep', value: 0.88, color: Colors.white),
                const SizedBox(height: 6),
                _ScoreBar(label: 'Activity', value: 0.60, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              const Icon(Icons.health_and_safety, color: Colors.white, size: 48),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('AI Coach', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ScoreBar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(value * 100).toInt()}%',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: const [
        StatCard(label: 'Calories', value: '1,840', unit: 'kcal', icon: Icons.local_fire_department, color: Color(0xFFF59E0B), trend: '-260'),
        StatCard(label: 'Steps', value: '8,234', icon: Icons.directions_walk, color: Color(0xFF10B981), trend: '+1.2k'),
        StatCard(label: 'Sleep', value: '7.4', unit: 'hrs', icon: Icons.bedtime, color: Color(0xFF8B5CF6), trend: '+0.3'),
        StatCard(label: 'HRV', value: '52', unit: 'ms', icon: Icons.favorite, color: Color(0xFFEF4444), trend: '+4'),
        StatCard(label: 'Water', value: '1.8', unit: 'L', icon: Icons.water_drop, color: Color(0xFF0EA5E9)),
        StatCard(label: 'Weight', value: '74.2', unit: 'kg', icon: Icons.monitor_weight, color: Color(0xFF94A3B8)),
        StatCard(label: 'Resting HR', value: '58', unit: 'bpm', icon: Icons.monitor_heart, color: Color(0xFFEF4444)),
        StatCard(label: 'Active Cal', value: '420', unit: 'kcal', icon: Icons.bolt, color: Color(0xFFF59E0B)),
      ],
    );
  }
}

class _QuickLogRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(Icons.restaurant, 'Log Food', AppTheme.warning, '/nutrition'),
      _QuickAction(Icons.bedtime, 'Log Sleep', AppTheme.secondary, '/sleep'),
      _QuickAction(Icons.fitness_center, 'Workout', AppTheme.primary, '/strength'),
      _QuickAction(Icons.favorite, 'Symptoms', AppTheme.danger, '/symptoms'),
      _QuickAction(Icons.science, 'Stack', AppTheme.accent, '/stack'),
      _QuickAction(Icons.directions_run, 'Activity', AppTheme.accent, '/fitness'),
    ];

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final a = actions[i];
          return GestureDetector(
            onTap: () => context.go(a.path),
            child: Column(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: a.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: a.color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(a.icon, color: a.color, size: 24),
                ),
                const SizedBox(height: 6),
                Text(a.label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final String path;
  const _QuickAction(this.icon, this.label, this.color, this.path);
}

class _UpcomingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      _AppointmentItem('Cardiologist Follow-up', 'Dr. Sarah Chen', 'Jun 15', Icons.favorite, AppTheme.danger),
      _AppointmentItem('Blood Panel – Quest', 'Fasting required', 'Jun 18', Icons.biotech, AppTheme.warning),
      _AppointmentItem('DEXA Scan', 'UCLA Body Comp', 'Jun 22', Icons.accessibility_new, AppTheme.secondary),
    ];
    return Column(
      children: items.map((item) => _AppointmentCard(item: item)).toList(),
    );
  }
}

class _AppointmentItem {
  final String title;
  final String subtitle;
  final String date;
  final IconData icon;
  final Color color;
  const _AppointmentItem(this.title, this.subtitle, this.date, this.icon, this.color);
}

class _AppointmentCard extends StatelessWidget {
  final _AppointmentItem item;
  const _AppointmentCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(item.subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(item.date, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _InsightCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final insights = [
      _InsightData(
        icon: Icons.trending_up,
        color: AppTheme.accent,
        title: 'HRV trending up',
        body: 'Your HRV has improved 12% over 2 weeks. Sleep quality and lower stress are likely drivers.',
      ),
      _InsightData(
        icon: Icons.warning_amber,
        color: AppTheme.warning,
        title: 'Protein deficit',
        body: 'You\'ve hit your protein goal only 3/7 days. Aim for 150g daily for your muscle composition goals.',
      ),
      _InsightData(
        icon: Icons.bedtime,
        color: AppTheme.secondary,
        title: 'Sleep consistency',
        body: 'Bedtime varies by 90 min across the week. Consistent sleep timing boosts REM quality significantly.',
      ),
    ];

    return Column(
      children: insights.map((i) => _InsightCard(data: i)).toList(),
    );
  }
}

class _InsightData {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _InsightData({required this.icon, required this.color, required this.title, required this.body});
}

class _InsightCard extends StatelessWidget {
  final _InsightData data;
  const _InsightCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: data.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(data.body, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

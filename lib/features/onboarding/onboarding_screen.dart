import 'package:flutter/material.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  final _nameCtrl = TextEditingController();
  String _goal = 'Longevity';

  static const _goals = ['Longevity', 'Weight Loss', 'Muscle Gain', 'Athletic Performance', 'General Health'];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameCtrl.text.trim());
    await prefs.setString('primary_goal', _goal);
    await prefs.setBool('onboarding_done', true);
    widget.onComplete();
  }

  void _next() {
    if (_page < 2) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_page > 0)
                    TextButton(onPressed: _finish, child: const Text('Skip', style: TextStyle(color: AppTheme.textSecondary))),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (p) => setState(() => _page = p),
                physics: const NeverScrollableScrollPhysics(),
                children: [_WelcomePage(), _NamePage(ctrl: _nameCtrl), _GoalPage(goal: _goal, onGoalChanged: (g) => setState(() => _goal = g))],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _page == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _page == i ? AppTheme.primary : AppTheme.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: Text(_page == 2 ? 'Get Started' : 'Continue', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.health_and_safety, color: Colors.white, size: 52),
          ),
          const SizedBox(height: 40),
          const Text('Welcome to HealthVault', style: TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Text('Your private, local-first health operating system. Everything stays on your device — no cloud, no tracking.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16, height: 1.6), textAlign: TextAlign.center),
          const SizedBox(height: 40),
          ...[
            ('Labs & Biomarkers', Icons.biotech, AppTheme.primary),
            ('Sleep, Fitness & Nutrition', Icons.bar_chart, AppTheme.secondary),
            ('AI Health Coach', Icons.auto_awesome, AppTheme.accent),
          ].map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: item.$3.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(item.$2, color: item.$3, size: 18)),
              const SizedBox(width: 14),
              Text(item.$1, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
            ]),
          )),
        ],
      ),
    );
  }
}

class _NamePage extends StatelessWidget {
  final TextEditingController ctrl;
  const _NamePage({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What should we call you?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Your name stays local. It personalises your dashboard and AI coach.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.5)),
          const SizedBox(height: 40),
          TextFormField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
            decoration: InputDecoration(
              labelText: 'Your name',
              hintText: 'e.g. Alex',
              hintStyle: const TextStyle(color: AppTheme.textSecondary),
              prefixIcon: const Icon(Icons.person_outline, color: AppTheme.textSecondary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalPage extends StatelessWidget {
  final String goal;
  final void Function(String) onGoalChanged;
  const _GoalPage({required this.goal, required this.onGoalChanged});

  static const _descriptions = {
    'Longevity': 'Focus on healthspan, biomarkers, and evidence-based longevity protocols.',
    'Weight Loss': 'Track calories, macros, and body composition over time.',
    'Muscle Gain': 'Log strength workouts, protein intake, and lean mass changes.',
    'Athletic Performance': 'Monitor training load, HRV, and recovery metrics.',
    'General Health': 'Build habits around sleep, movement, nutrition, and wellbeing.',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What is your primary goal?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('This shapes your dashboard insights and AI recommendations.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.5)),
          const SizedBox(height: 32),
          ..._GoalPage._descriptions.keys.map((g) {
            final selected = g == goal;
            return GestureDetector(
              onTap: () => onGoalChanged(g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? AppTheme.primary : AppTheme.border, width: selected ? 1.5 : 1),
                ),
                child: Row(children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? AppTheme.primary : AppTheme.border, width: 2),
                      color: selected ? AppTheme.primary : Colors.transparent,
                    ),
                    child: selected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(g, style: TextStyle(color: selected ? AppTheme.primary : AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    Text(_GoalPage._descriptions[g]!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
                  ])),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

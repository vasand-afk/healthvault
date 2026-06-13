import 'package:flutter/material.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
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
  DateTime? _dob;
  String _sex = 'Male';
  double _heightCm = 170;
  double _weightKg = 70;

  static const _totalPages = 5;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameCtrl.text.trim());
    await prefs.setString('primary_goal', _goal);
    if (_dob != null) await prefs.setString('user_dob', _dob!.toIso8601String());
    await prefs.setString('user_sex', _sex);
    await prefs.setDouble('user_height_cm', _heightCm);
    await prefs.setDouble('user_weight_kg', _weightKg);
    await prefs.setBool('onboarding_done', true);
    widget.onComplete();
  }

  void _next() {
    if (_page < _totalPages - 1) {
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
                children: [
                  _WelcomePage(),
                  _NamePage(ctrl: _nameCtrl),
                  _GoalPage(goal: _goal, onGoalChanged: (g) => setState(() => _goal = g)),
                  _BiologicsPage(
                    dob: _dob, sex: _sex,
                    onDobChanged: (d) => setState(() => _dob = d),
                    onSexChanged: (s) => setState(() => _sex = s),
                  ),
                  _BodyPage(
                    heightCm: _heightCm, weightKg: _weightKg,
                    onHeightChanged: (h) => setState(() => _heightCm = h),
                    onWeightChanged: (w) => setState(() => _weightKg = w),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalPages, (i) => AnimatedContainer(
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
                      child: Text(_page == _totalPages - 1 ? 'Get Started' : 'Continue', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

class _BiologicsPage extends StatelessWidget {
  final DateTime? dob;
  final String sex;
  final void Function(DateTime) onDobChanged;
  final void Function(String) onSexChanged;
  const _BiologicsPage({required this.dob, required this.sex, required this.onDobChanged, required this.onSexChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About you', style: TextStyle(color: AppTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Used to personalise calorie targets, health insights, and lab reference ranges.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.5)),
          const SizedBox(height: 36),
          const Text('Date of birth', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: dob ?? DateTime(1990, 1, 1),
                firstDate: DateTime(1920),
                lastDate: DateTime.now(),
                builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primary)), child: child!),
              );
              if (picked != null) onDobChanged(picked);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: dob != null ? AppTheme.primary : AppTheme.border),
              ),
              child: Row(children: [
                const Icon(Icons.cake_outlined, color: AppTheme.textSecondary, size: 20),
                const SizedBox(width: 12),
                Text(
                  dob == null ? 'Select date of birth' : '${dob!.day}/${dob!.month}/${dob!.year}',
                  style: TextStyle(color: dob == null ? AppTheme.textSecondary : AppTheme.textPrimary, fontSize: 16),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 28),
          const Text('Biological sex', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Row(children: [
            for (final s in ['Male', 'Female', 'Other'])
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: s != 'Other' ? 10 : 0),
                  child: GestureDetector(
                    onTap: () => onSexChanged(s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: sex == s ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: sex == s ? AppTheme.primary : AppTheme.border, width: sex == s ? 1.5 : 1),
                      ),
                      child: Text(s, textAlign: TextAlign.center, style: TextStyle(color: sex == s ? AppTheme.primary : AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
          ]),
        ],
      ),
    );
  }
}

class _BodyPage extends StatelessWidget {
  final double heightCm;
  final double weightKg;
  final void Function(double) onHeightChanged;
  final void Function(double) onWeightChanged;
  const _BodyPage({required this.heightCm, required this.weightKg, required this.onHeightChanged, required this.onWeightChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Height & Weight', style: TextStyle(color: AppTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Used to calculate BMI, calorie needs, and protein targets. You can update this anytime in Settings.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.5)),
          const SizedBox(height: 36),
          _SliderField(
            label: 'Height',
            value: heightCm,
            min: 140, max: 220,
            displayText: '${heightCm.toStringAsFixed(0)} cm  (${(heightCm / 30.48).toStringAsFixed(1)} ft)',
            color: AppTheme.primary,
            onChanged: onHeightChanged,
          ),
          const SizedBox(height: 32),
          _SliderField(
            label: 'Weight',
            value: weightKg,
            min: 30, max: 200,
            displayText: '${weightKg.toStringAsFixed(1)} kg  (${(weightKg * 2.205).toStringAsFixed(1)} lbs)',
            color: AppTheme.secondary,
            onChanged: onWeightChanged,
          ),
        ],
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  final String label;
  final double value, min, max;
  final String displayText;
  final Color color;
  final void Function(double) onChanged;
  const _SliderField({required this.label, required this.value, required this.min, required this.max, required this.displayText, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
    const SizedBox(height: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(displayText, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
    ),
    SliderTheme(
      data: SliderTheme.of(context).copyWith(activeTrackColor: color, thumbColor: color, inactiveTrackColor: color.withValues(alpha: 0.2), overlayColor: color.withValues(alpha: 0.1)),
      child: Slider(value: value, min: min, max: max, divisions: ((max - min)).toInt(), onChanged: onChanged),
    ),
  ]);
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

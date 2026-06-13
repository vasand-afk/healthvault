import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:vasan_health/core/database/database.dart';
import 'package:vasan_health/core/services/auth_service.dart';
import 'package:vasan_health/core/theme/app_theme.dart';
import 'package:vasan_health/features/auth/lock_screen.dart';
import 'package:vasan_health/features/settings/privacy_policy_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _name = '';
  String _apiKey = '';
  String _gender = 'Not specified';
  String _dob = '';
  double _heightCm = 0;
  double _weightKg = 0;
  String _units = 'Metric';
  String _calorieGoal = '2000';
  String _proteinGoal = '150';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('user_name') ?? '';
      _apiKey = prefs.getString('anthropic_api_key') ?? '';
      _gender = prefs.getString('gender') ?? 'Not specified';
      _dob = prefs.getString('dob') ?? '';
      _heightCm = prefs.getDouble('height_cm') ?? 0;
      _weightKg = prefs.getDouble('weight_kg') ?? 0;
      _units = prefs.getString('units') ?? 'Metric';
      _calorieGoal = prefs.getString('calorie_goal') ?? '2000';
      _proteinGoal = prefs.getString('protein_goal') ?? '150';
    });
  }

  Future<void> _save(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) await prefs.setString(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is int) await prefs.setInt(key, value);
  }

  Future<void> _exportData() async {
    try {
      final db = await AppDatabase.instance;
      const tables = [
        'diagnoses', 'appointments', 'lab_results', 'body_compositions',
        'imaging_results', 'wearable_data', 'food_logs', 'water_logs',
        'activities', 'workouts', 'workout_sets', 'sleep_logs', 'symptoms',
        'mood_logs', 'supplements', 'supplement_logs', 'documents',
        'reminders', 'epigenetic_clocks', 'snp_variants', 'proteomics_results',
        'senescence_scores', 'metabolomics_results', 'microbiome_snapshots', 'omics_other',
      ];
      final export = <String, dynamic>{
        'exported_at': DateTime.now().toIso8601String(),
        'app': 'HealthVault',
        'version': '1.0.0',
      };
      for (final t in tables) {
        try { export[t] = await db.query(t); } catch (_) { export[t] = []; }
      }
      final json = const JsonEncoder.withIndent('  ').convert(export);
      final bytes = utf8.encode(json);
      final fileName = 'healthvault_export_${DateFormat('yyyyMMdd').format(DateTime.now())}.json';
      if (kIsWeb) {
        // Web export not supported in this build
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)]);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export ready'), backgroundColor: Color(0xFF10B981)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionTitle('Profile'),
          _SettingField(label: 'Name', value: _name, onChanged: (v) { setState(() => _name = v); _save('user_name', v); }),
          _SettingField(label: 'Date of Birth', value: _dob, hint: 'YYYY-MM-DD', onChanged: (v) { setState(() => _dob = v); _save('dob', v); }),
          _DropdownField(label: 'Biological Sex', value: _gender, options: ['Not specified', 'Male', 'Female'], onChanged: (v) { setState(() => _gender = v!); _save('gender', v!); }),
          _SettingField(label: 'Height (cm)', value: _heightCm > 0 ? _heightCm.toString() : '', onChanged: (v) { final d = double.tryParse(v) ?? 0; setState(() => _heightCm = d); _save('height_cm', d); }, isNumber: true),
          _SettingField(label: 'Weight (kg)', value: _weightKg > 0 ? _weightKg.toString() : '', onChanged: (v) { final d = double.tryParse(v) ?? 0; setState(() => _weightKg = d); _save('weight_kg', d); }, isNumber: true),
          const SizedBox(height: 24),
          _SectionTitle('Goals'),
          _SettingField(label: 'Daily Calorie Goal (kcal)', value: _calorieGoal, onChanged: (v) { setState(() => _calorieGoal = v); _save('calorie_goal', v); }, isNumber: true),
          _SettingField(label: 'Daily Protein Goal (g)', value: _proteinGoal, onChanged: (v) { setState(() => _proteinGoal = v); _save('protein_goal', v); }, isNumber: true),
          const SizedBox(height: 24),
          _SectionTitle('Preferences'),
          _DropdownField(label: 'Units', value: _units, options: ['Metric', 'Imperial'], onChanged: (v) { setState(() => _units = v!); _save('units', v!); }),
          const SizedBox(height: 24),
          _SectionTitle('AI Coach'),
          _SettingField(
            label: 'Anthropic API Key',
            value: _apiKey,
            hint: 'sk-ant-...',
            isPassword: true,
            onChanged: (v) { setState(() => _apiKey = v); _save('anthropic_api_key', v); },
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
            child: const Text(
              'Your Anthropic API key powers the AI Coach. It is stored locally on your device and never transmitted anywhere except the Anthropic API.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('Security'),
          _PinSettingsTile(),
          const SizedBox(height: 24),
          _SectionTitle('Data & Privacy'),
          _ActionTile(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', subtitle: 'How your data is handled', color: AppTheme.primary, onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
          }),
          _ActionTile(icon: Icons.download, label: 'Export All Data', subtitle: 'Download a complete JSON backup', color: AppTheme.primary, onTap: _exportData),
          _ActionTile(icon: Icons.delete_forever, label: 'Clear All Data', subtitle: 'Permanently delete all health records', color: AppTheme.danger, onTap: () {
            showDialog(context: context, builder: (_) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text('Clear All Data', style: TextStyle(color: AppTheme.danger)),
              content: const Text('This will permanently delete all your health data. This cannot be undone.', style: TextStyle(color: AppTheme.textSecondary)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final db = await AppDatabase.instance;
                    const tables = ['diagnoses','appointments','lab_results','body_compositions','imaging_results','wearable_data','food_logs','water_logs','activities','workouts','workout_sets','sleep_logs','symptoms','mood_logs','supplements','supplement_logs','documents','reminders','epigenetic_clocks','snp_variants','proteomics_results','senescence_scores','metabolomics_results','microbiome_snapshots','omics_other','ai_messages'];
                    for (final t in tables) { try { await db.delete(t); } catch (_) {} }
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All data cleared'), backgroundColor: AppTheme.danger));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                  child: const Text('Delete Everything'),
                ),
              ],
            ));
          }),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                const Text('HealthVault', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                const Text('Version 1.0.0', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                const Text('Local-first • Private • Open Source', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.0)),
    );
  }
}

class _SettingField extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final bool isPassword;
  final bool isNumber;
  final Function(String) onChanged;
  const _SettingField({required this.label, required this.value, this.hint, this.isPassword = false, this.isNumber = false, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        obscureText: isPassword,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(labelText: label, hintText: hint),
        onChanged: onChanged,
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final Function(String?) onChanged;
  const _DropdownField({required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: AppTheme.surface,
        decoration: InputDecoration(labelText: label),
        style: const TextStyle(color: AppTheme.textPrimary),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _PinSettingsTile extends StatefulWidget {
  @override
  State<_PinSettingsTile> createState() => _PinSettingsTileState();
}

class _PinSettingsTileState extends State<_PinSettingsTile> {
  bool _enabled = false;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final e = await AuthService.instance.isPinEnabled();
    if (mounted) setState(() => _enabled = e);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.lock, color: AppTheme.primary, size: 20)),
          const SizedBox(width: 14),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PIN Lock', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
            Text('Require PIN to open the app', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ])),
          Switch(
            value: _enabled,
            activeColor: AppTheme.primary,
            onChanged: (v) async {
              if (v) {
                // Show PIN setup
                await showDialog(context: context, barrierDismissible: false, builder: (_) => Dialog(
                  backgroundColor: AppTheme.background,
                  child: SizedBox(height: 520, child: LockScreen(setup: true, onUnlocked: () { Navigator.pop(context); })),
                ));
                _load();
              } else {
                await AuthService.instance.disablePin();
                _load();
              }
            },
          ),
        ]),
      ),
      if (_enabled) GestureDetector(
        onTap: () => showDialog(context: context, barrierDismissible: false, builder: (_) => Dialog(
          backgroundColor: AppTheme.background,
          child: SizedBox(height: 520, child: LockScreen(setup: true, onUnlocked: () { Navigator.pop(context); })),
        )).then((_) => _load()),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
          child: const Row(children: [
            SizedBox(width: 44),
            SizedBox(width: 14),
            Text('Change PIN', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w500)),
            Spacer(),
            Icon(Icons.chevron_right, color: AppTheme.primary, size: 18),
          ]),
        ),
      ),
    ]);
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

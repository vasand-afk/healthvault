import 'package:flutter/material.dart';
import 'package:healthvault/core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _Heading('HealthVault Privacy Policy'),
          _SubHeading('Effective Date: June 11, 2026'),
          SizedBox(height: 16),
          _Body(
            'HealthVault is a local-first personal health data app. '
            'Your privacy is not just a policy — it is the foundation of how this app is built.',
          ),
          SizedBox(height: 24),
          _Section('1. Data Storage'),
          _Body(
            'All data you enter — including health records, lab results, diagnoses, fitness logs, '
            'sleep data, nutrition, supplements, symptoms, mood, genomics, and any other personal '
            'health information — is stored exclusively on your device using a local SQLite database. '
            'No data is uploaded to any server operated by HealthVault.',
          ),
          SizedBox(height: 20),
          _Section('2. Data We Do Not Collect'),
          _Body('HealthVault does not collect, transmit, or store on external servers:'),
          _Bullet('Your name, date of birth, or any identifying information'),
          _Bullet('Health records, lab results, or medical history'),
          _Bullet('Fitness, nutrition, or sleep data'),
          _Bullet('Device identifiers, IP addresses, or location data'),
          _Bullet('Usage analytics or crash reports'),
          SizedBox(height: 20),
          _Section('3. AI Coach & Anthropic API'),
          _Body(
            'If you choose to use the AI Coach feature, you must provide your own Anthropic API key. '
            'That key is stored locally on your device. When you send a message to the AI Coach, '
            'the content of that message is transmitted directly to the Anthropic API on your behalf. '
            'HealthVault does not intercept, log, or store these transmissions. '
            'Anthropic\'s privacy policy governs their handling of that data: https://www.anthropic.com/privacy',
          ),
          SizedBox(height: 20),
          _Section('4. Third-Party Integrations'),
          _Body(
            'HealthVault supports optional imports from Apple Health, Strava, Oura, and CSV/PDF files. '
            'These imports pull data into your local device only. HealthVault does not maintain '
            'persistent connections to these services and does not share your data with them.',
          ),
          SizedBox(height: 20),
          _Section('5. PIN & Security'),
          _Body(
            'If you enable PIN lock, your PIN is hashed using SHA-256 and stored locally in device '
            'preferences. The raw PIN is never stored or transmitted.',
          ),
          SizedBox(height: 20),
          _Section('6. Data Export'),
          _Body(
            'You can export all your data at any time as a JSON file using the Export feature in Settings. '
            'This export is performed entirely on-device and is downloaded directly to your device.',
          ),
          SizedBox(height: 20),
          _Section('7. Data Deletion'),
          _Body(
            'You can permanently delete all your health data at any time using "Clear All Data" in Settings. '
            'Uninstalling the app also removes all locally stored data.',
          ),
          SizedBox(height: 20),
          _Section('8. Children\'s Privacy'),
          _Body(
            'HealthVault is not directed at children under 13 and does not knowingly collect '
            'any information from children.',
          ),
          SizedBox(height: 20),
          _Section('9. Changes to This Policy'),
          _Body(
            'If we make material changes to this policy, we will update the effective date above '
            'and notify users through an in-app notice.',
          ),
          SizedBox(height: 20),
          _Section('10. Contact'),
          _Body(
            'Questions about this privacy policy? Contact us at:\n'
            'vasand@gmail.com',
          ),
          SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
      );
}

class _SubHeading extends StatelessWidget {
  final String text;
  const _SubHeading(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      );
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(color: AppTheme.primary, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      );
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.6),
      );
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 12, top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            Expanded(
              child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5)),
            ),
          ],
        ),
      );
}

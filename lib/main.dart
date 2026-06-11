import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthvault/core/router/app_router.dart';
import 'package:healthvault/core/services/auth_service.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/features/auth/lock_screen.dart';
import 'package:healthvault/features/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  runApp(const ProviderScope(child: HealthVaultApp()));
}

class HealthVaultApp extends StatefulWidget {
  const HealthVaultApp({super.key});
  @override
  State<HealthVaultApp> createState() => _HealthVaultAppState();
}

class _HealthVaultAppState extends State<HealthVaultApp> with WidgetsBindingObserver {
  bool _ready = false;
  bool _pinEnabled = false;
  bool _needsSetup = false;
  bool _onboardingDone = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _backgroundedAt != null) {
      final away = DateTime.now().difference(_backgroundedAt!);
      // Lock after 5 minutes in background
      if (away.inMinutes >= 5 && _pinEnabled) {
        setState(() => AuthService.instance.lock());
      }
      _backgroundedAt = null;
    }
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = await AuthService.instance.isPinEnabled();
    final hasPin = await AuthService.instance.hasPinSet();
    if (!enabled) AuthService.instance.unlock();
    setState(() {
      _pinEnabled = enabled;
      _needsSetup = !hasPin;
      _onboardingDone = prefs.getBool('onboarding_done') ?? false;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthVault',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: !_ready
          ? const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator()))
          : !_onboardingDone
              ? OnboardingScreen(onComplete: () => setState(() => _onboardingDone = true))
              : _pinEnabled && !AuthService.instance.isUnlocked
                  ? LockScreen(setup: _needsSetup, onUnlocked: () => setState(() {}))
                  : _RouterHost(),
    );
  }
}

class _RouterHost extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HealthVault',
      theme: AppTheme.dark(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}

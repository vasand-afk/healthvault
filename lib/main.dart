import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthvault/core/router/app_router.dart';
import 'package:healthvault/core/services/auth_service.dart';
import 'package:healthvault/core/theme/app_theme.dart';
import 'package:healthvault/features/auth/lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    final enabled = await AuthService.instance.isPinEnabled();
    final hasPin = await AuthService.instance.hasPinSet();
    // If PIN is enabled and set, require it on launch
    if (!enabled) AuthService.instance.unlock();
    setState(() {
      _pinEnabled = enabled;
      _needsSetup = !hasPin;
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
          : _pinEnabled && !AuthService.instance.isUnlocked
              ? LockScreen(
                  setup: _needsSetup,
                  onUnlocked: () => setState(() {}),
                )
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

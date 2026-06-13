import 'package:flutter/material.dart';
import 'package:vasan_health/core/services/auth_service.dart';
import 'package:vasan_health/core/theme/app_theme.dart';

/// Shown on launch when PIN is enabled.
/// [setup] = true means first-time PIN creation flow.
class LockScreen extends StatefulWidget {
  final bool setup;
  final VoidCallback onUnlocked;
  const LockScreen({super.key, this.setup = false, required this.onUnlocked});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  final List<String> _digits = [];
  String? _error;
  bool _confirming = false;      // setup phase 2: confirm PIN
  List<String>? _firstPin;       // stores first entry during setup
  late AnimationController _shake;
  late Animation<double> _shakeAnim;

  static const _pinLength = 4;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _shake, curve: Curves.elasticIn));
  }

  @override
  void dispose() { _shake.dispose(); super.dispose(); }

  void _onDigit(String d) {
    if (_digits.length >= _pinLength) return;
    setState(() { _digits.add(d); _error = null; });
    if (_digits.length == _pinLength) _submit();
  }

  void _onDelete() {
    if (_digits.isEmpty) return;
    setState(() { _digits.removeLast(); _error = null; });
  }

  Future<void> _submit() async {
    final pin = _digits.join();

    if (widget.setup) {
      if (!_confirming) {
        // Save first entry, switch to confirm
        setState(() { _firstPin = List.from(_digits); _digits.clear(); _confirming = true; });
        return;
      }
      // Confirm phase
      if (pin == _firstPin!.join()) {
        await AuthService.instance.setPin(pin);
        AuthService.instance.unlock();
        widget.onUnlocked();
      } else {
        await _shakeAndClear('PINs don\'t match — try again');
        setState(() { _confirming = false; _firstPin = null; });
      }
      return;
    }

    // Verify existing PIN
    final ok = await AuthService.instance.verifyPin(pin);
    if (ok) {
      AuthService.instance.unlock();
      widget.onUnlocked();
    } else {
      await _shakeAndClear('Incorrect PIN');
    }
  }

  Future<void> _shakeAndClear(String msg) async {
    _shake.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() { _digits.clear(); _error = msg; });
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.setup
        ? (_confirming ? 'Confirm your PIN' : 'Create a 4-digit PIN')
        : 'Enter PIN';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.health_and_safety, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 20),
                const Text('HealthVault', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                const SizedBox(height: 40),

                // PIN dots
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(_shakeAnim.value * 8 * (_shake.value < 0.5 ? 1 : -1), 0),
                    child: child,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pinLength, (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _digits.length ? AppTheme.primary : Colors.transparent,
                        border: Border.all(
                          color: i < _digits.length ? AppTheme.primary : AppTheme.border,
                          width: 2,
                        ),
                      ),
                    )),
                  ),
                ),

                const SizedBox(height: 12),
                AnimatedOpacity(
                  opacity: _error != null ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(_error ?? '', style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
                ),
                const SizedBox(height: 32),

                // Numpad
                _Numpad(onDigit: _onDigit, onDelete: _onDelete),

                const SizedBox(height: 32),
                if (!widget.setup)
                  TextButton(
                    onPressed: () => _showForgotDialog(),
                    child: const Text('Forgot PIN?', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Forgot PIN', style: TextStyle(color: AppTheme.textPrimary)),
      content: const Text('To reset your PIN, you\'ll need to clear all app data from your device settings, or contact support.\n\nAll health data is stored locally and cannot be recovered remotely.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
      ],
    ));
  }
}

class _Numpad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;
  const _Numpad({required this.onDigit, required this.onDelete});

  static const _layout = [
    ['1','2','3'],
    ['4','5','6'],
    ['7','8','9'],
    ['','0','⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _layout.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) return const SizedBox(width: 80, height: 64);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _NumpadKey(
                label: key,
                onTap: () => key == '⌫' ? onDelete() : onDigit(key),
                isDelete: key == '⌫',
              ),
            );
          }).toList(),
        ),
      )).toList(),
    );
  }
}

class _NumpadKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDelete;
  const _NumpadKey({required this.label, required this.onTap, this.isDelete = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 72, height: 64,
      decoration: BoxDecoration(
        color: isDelete ? Colors.transparent : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isDelete ? null : Border.all(color: AppTheme.border),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: isDelete ? AppTheme.textSecondary : AppTheme.textPrimary,
          fontSize: isDelete ? 22 : 22,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}

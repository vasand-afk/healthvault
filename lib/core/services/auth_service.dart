import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _pinKey = 'hv_pin_hash';
  static const _pinEnabledKey = 'hv_pin_enabled';

  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  AuthService._();

  bool _unlocked = false;

  bool get isUnlocked => _unlocked;

  Future<bool> isPinEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinEnabledKey) ?? false;
  }

  Future<bool> hasPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) != null;
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = _hash(pin);
    await prefs.setString(_pinKey, hash);
    await prefs.setBool(_pinEnabledKey, true);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinKey);
    if (stored == null) return false;
    return stored == _hash(pin);
  }

  Future<void> disablePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.setBool(_pinEnabledKey, false);
    _unlocked = true;
  }

  Future<void> changePin(String newPin) async => setPin(newPin);

  void unlock() => _unlocked = true;
  void lock() => _unlocked = false;

  String _hash(String pin) {
    final bytes = utf8.encode(pin + 'hv_salt_2024');
    return sha256.convert(bytes).toString();
  }
}

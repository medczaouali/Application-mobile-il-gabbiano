import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/biometric_auth_service.dart';

class BiometricProvider extends ChangeNotifier {
  static const _keyEnabled = 'biometric_enabled';
  static const _keyUserId = 'biometric_user_id';
  static const _keyUserRole = 'biometric_user_role';

  final BiometricAuthService _service;
  bool _enabled = false;
  bool _available = false;
  bool _initialized = false;
  String? _lastErrorCode;
  int? _linkedUserId;
  String? _linkedUserRole;

  BiometricProvider({BiometricAuthService? service}) : _service = service ?? BiometricAuthService();

  bool get enabled => _enabled;
  bool get available => _available;
  bool get initialized => _initialized;
  String? get lastErrorCode => _lastErrorCode;
  int? get linkedUserId => _linkedUserId;
  String? get linkedUserRole => _linkedUserRole;

  Future<void> init() async {
    _available = await _service.isAvailable();
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_keyEnabled) ?? false;
    _linkedUserId = prefs.getInt(_keyUserId);
    _linkedUserRole = prefs.getString(_keyUserRole);
    _initialized = true;
    notifyListeners();
  }

  Future<bool> enable() async {
    if (!_available) return false;
    final ok = await _service.authenticate(reason: 'Confirmer pour activer le déverrouillage par empreinte');
    _lastErrorCode = _service.lastErrorCode;
    if (!ok) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, true);
    _enabled = true;
    notifyListeners();
    return true;
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, false);
    _enabled = false;
    _lastErrorCode = null;
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserRole);
    _linkedUserId = null;
    _linkedUserRole = null;
    notifyListeners();
  }

  /// Link the current logged-in user to biometric unlock (used after enabling).
  Future<void> linkCurrentUser({required int userId, required String role}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyUserRole, role);
    _linkedUserId = userId;
    _linkedUserRole = role;
    notifyListeners();
  }
}

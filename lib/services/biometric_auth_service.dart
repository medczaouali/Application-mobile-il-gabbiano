import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

/// Thin wrapper around LocalAuthentication to centralize checks
/// and make it easier to stub in tests.
class BiometricAuthService {
  final LocalAuthentication _auth;
  BiometricAuthService({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();
  String? lastErrorCode;

  /// Whether device supports biometrics (fingerprint/face) and at least one is enrolled.
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final methods = await _auth.getAvailableBiometrics();
      return methods.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Prompt the user to authenticate with biometrics.
  Future<bool> authenticate({String reason = 'Authenticate to continue'}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      lastErrorCode = null;
      return ok;
    } on PlatformException catch (e) {
      lastErrorCode = e.code; // notEnrolled, notAvailable, passcodeNotSet, lockedOut, permanentlyLockedOut, otherError, auth_in_progress
      return false;
    } catch (_) {
      lastErrorCode = 'otherError';
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}

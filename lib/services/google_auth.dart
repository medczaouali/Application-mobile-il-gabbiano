import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  GoogleAuthService._internal();

  Future<GoogleSignInAccount?> signIn() async {
    // Let exceptions bubble up so callers can distinguish between
    // user-cancel (null) and configuration/errors (PlatformException).
    final account = await _googleSignIn.signIn();
    return account;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}

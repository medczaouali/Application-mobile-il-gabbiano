import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import 'package:ilgabbiano/theme/brand_palette.dart';
import 'package:ilgabbiano/screens/auth/forgot_password_screen.dart';
import 'package:ilgabbiano/widgets/custom_button.dart';
import 'package:ilgabbiano/widgets/custom_text_field.dart';
import 'package:ilgabbiano/providers/unread_provider.dart';
import 'package:ilgabbiano/services/ai/ai_user_service.dart';
import 'package:ilgabbiano/providers/locale_provider.dart';
import 'package:ilgabbiano/providers/cart_provider.dart';
import 'package:ilgabbiano/providers/biometric_provider.dart';
import 'package:ilgabbiano/services/biometric_auth_service.dart';

import '../../db/database_helper.dart';
import '../../services/session_manager.dart';
import '../../localization/app_localizations.dart';
import '../../services/google_auth.dart';
import '../../models/user.dart';
import '../admin/admin_home_screen.dart';
import '../client/client_home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dbHelper = DatabaseHelper();
  final _sessionManager = SessionManager();
  final _googleAuth = GoogleAuthService();
  final _bioService = BiometricAuthService();

  void _login() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text;
      final password = _passwordController.text;
      final l10n = AppLocalizations.of(context);
      final user = await _dbHelper.loginUser(email, password);

      if (!context.mounted) return;

        if (user != null) {
        if (user.isBanned == 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('banned_account'))),
          );
          return;
        }
        await _sessionManager.saveUserSession(user.id!, user.role);
        if (!context.mounted) return;
        // Initialize cart provider for this user so adding to cart works immediately
        try {
          await Provider.of<CartProvider>(context, listen: false).init(user.id!);
        } catch (_) {}
        // initialize UnreadProvider for this user so badges and banners are accurate immediately
        try {
          final up = Provider.of<UnreadProvider>(context, listen: false);
          await up.init(user.id!);
        } catch (e) {
          // ignore initialization issues
        }
        // Suggest language if none set yet
        try {
          final savedLang = await _sessionManager.getLanguage();
          if (savedLang == null) {
            final device = WidgetsBinding.instance.platformDispatcher.locale;
            final suggested = AIUserService().suggestSupportedLocale(device: device);
            if (!context.mounted) return;
            await context.read<LocaleProvider>().setLocale(suggested);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.t('language_auto_set').replaceFirst('{lang}', suggested.languageCode))),
            );
          }
        } catch (_) {}

        if (!context.mounted) return;
        if (user.role == 'admin') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => AdminHomeScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => ClientHomeScreen()),
          );
        }
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('incorrect_credentials'))),
        );
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    GoogleSignInAccount? acct;
    try {
      acct = await _googleAuth.signIn();
    } on PlatformException catch (e) {
      final msg = (e.message ?? '').toLowerCase();
      final isDevError10 = msg.contains('10');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t(isDevError10 ? 'google_config_error' : 'google_signin_failed'))),
      );
      return;
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('google_signin_failed'))));
      return;
    }
    if (acct == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('google_cancelled'))));
      return;
    }

    final email = acct.email;
    final name = acct.displayName ?? '';

    // Try to find existing user by email
    final existing = await _dbHelper.getUserByEmail(email);
    if (existing != null) {
      if (existing.isBanned == 1) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('banned_account'))));
        return;
      }
      await _sessionManager.saveUserSession(existing.id!, existing.role);
      // Initialize cart provider
      try {
        await Provider.of<CartProvider>(context, listen: false).init(existing.id!);
      } catch (_) {}
      try {
        final up = Provider.of<UnreadProvider>(context, listen: false);
        await up.init(existing.id!);
      } catch (e) {}
      // Suggest language if none set yet
      try {
        final savedLang = await _sessionManager.getLanguage();
        if (savedLang == null) {
          final device = WidgetsBinding.instance.platformDispatcher.locale;
          final suggested = AIUserService().suggestSupportedLocale(device: device);
          if (!context.mounted) return;
          await context.read<LocaleProvider>().setLocale(suggested);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).t('language_auto_set').replaceFirst('{lang}', suggested.languageCode))),
          );
        }
      } catch (_) {}

      if (!context.mounted) return;
      if (existing.role == 'admin') {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AdminHomeScreen()));
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ClientHomeScreen()));
      }
      return;
    }

  // No user yet: create a new client user using Google info
    final newUser = User(name: name.isEmpty ? email.split('@').first : name, email: email, phone: '', password: DateTime.now().millisecondsSinceEpoch.toString());
    final id = await _dbHelper.registerUser(newUser);
    await _sessionManager.saveUserSession(id, 'client');
    // Initialize cart provider
    try {
      await Provider.of<CartProvider>(context, listen: false).init(id);
    } catch (_) {}
    try {
      final up = Provider.of<UnreadProvider>(context, listen: false);
      await up.init(id);
    } catch (e) {}
    // Suggest language if none set yet
    try {
      final savedLang = await _sessionManager.getLanguage();
      if (savedLang == null) {
        final device = WidgetsBinding.instance.platformDispatcher.locale;
        final suggested = AIUserService().suggestSupportedLocale(device: device);
        if (!context.mounted) return;
        await context.read<LocaleProvider>().setLocale(suggested);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('language_auto_set').replaceFirst('{lang}', suggested.languageCode))),
        );
      }
    } catch (_) {}

    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ClientHomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Full-bleed banner from top to mid with the app icon
                SizedBox(
                  height: constraints.maxHeight * 0.45,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset('assets/icon.png', fit: BoxFit.contain),
                      // Subtle gradient overlay for readability on various icons
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.25),
                              Colors.black.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                      ),
                      // Header title aligned at the top-left
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              l10n.t('login'),
                              style: GoogleFonts.lato(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Form card
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight * 0.5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Solid card to avoid overlap with the header image on tall devices
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                                boxShadow: BrandPalette.softShadow,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    CustomTextField(
                                      controller: _emailController,
                                      labelText: l10n.t('email_label'),
                                      icon: Icons.email_outlined,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return l10n.t('enter_email');
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    CustomTextField(
                                      controller: _passwordController,
                                      labelText: l10n.t('password_label'),
                                      icon: Icons.lock_outline,
                                      isPassword: true,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return l10n.t('enter_password');
                                        }
                                        return null;
                                      },
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                        ),
                                        child: Text(l10n.t('forgot_password')),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    CustomButton(
                                      onPressed: _login,
                                      text: l10n.t('login'),
                                      icon: Icons.login,
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.account_circle, size: 20),
                                        label: Text(l10n.t('login_with_google')),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: _loginWithGoogle,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Consumer<BiometricProvider>(
                                      builder: (context, bio, _) {
                                        if (!bio.available) return const SizedBox.shrink();
                                        return SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            icon: const Icon(Icons.fingerprint),
                                            label: Text(l10n.t('login_with_fingerprint')),
                                            onPressed: () async {
                                              if (!bio.enabled) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(l10n.t('enable_biometrics_first'))),
                                                );
                                                return;
                                              }
                                              final ok = await _bioService.authenticate(
                                                reason: l10n.t('unlock_with_fingerprint'),
                                              );
                                              if (!ok) {
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(l10n.t('biometric_failed'))),
                                                );
                                                return;
                                              }
                                              var session = await _sessionManager.getUserSession();
                                              if (session == null &&
                                                  bio.linkedUserId != null &&
                                                  bio.linkedUserRole != null) {
                                                await _sessionManager.saveUserSession(
                                                  bio.linkedUserId!,
                                                  bio.linkedUserRole!,
                                                );
                                                session = {
                                                  'id': bio.linkedUserId!,
                                                  'role': bio.linkedUserRole!,
                                                };
                                              }
                                              if (!mounted) return;
                                              if (session == null) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(l10n.t('no_saved_session'))),
                                                );
                                                return;
                                              }
                                              try {
                                                await Provider.of<CartProvider>(context, listen: false)
                                                    .init(session['id']);
                                              } catch (_) {}
                                              try {
                                                await Provider.of<UnreadProvider>(context, listen: false)
                                                    .init(session['id']);
                                              } catch (_) {}
                                              if (session['role'] == 'admin') {
                                                Navigator.of(context).pushReplacement(
                                                  MaterialPageRoute(builder: (_) => AdminHomeScreen()),
                                                );
                                              } else {
                                                Navigator.of(context).pushReplacement(
                                                  MaterialPageRoute(builder: (_) => ClientHomeScreen()),
                                                );
                                              }
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
                            },
                            child: Text(l10n.t('no_account_register')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

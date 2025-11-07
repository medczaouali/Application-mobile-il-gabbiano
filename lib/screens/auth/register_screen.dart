import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/models/user.dart';
import 'package:ilgabbiano/theme/brand_palette.dart';
import '../../services/google_auth.dart';
import '../../services/session_manager.dart';
import 'package:ilgabbiano/providers/unread_provider.dart';
import '../client/client_home_screen.dart';
import '../../localization/app_localizations.dart';
import 'package:ilgabbiano/services/ai/content_moderation_service.dart';
import 'package:ilgabbiano/services/ai/ai_user_service.dart';
import 'package:ilgabbiano/providers/locale_provider.dart';
import 'package:ilgabbiano/providers/cart_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final GoogleAuthService _googleAuth = GoogleAuthService();
  final SessionManager _sessionManager = SessionManager();

  void _register() async {
    if (_formKey.currentState!.validate()) {
      // AI moderation on name
      final mod = await ContentModerationService().moderateText(_nameController.text);
      if (mod.action == ModerationAction.block) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('name_inappropriate'))),
        );
        return;
      } else if (mod.action == ModerationAction.review) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(AppLocalizations.of(context).t('content_maybe_inappropriate')),
            content: Text(AppLocalizations.of(context).t('continue_anyway_q')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context).t('no'))),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(AppLocalizations.of(context).t('yes'))),
            ],
          ),
        );
        if (proceed != true) return;
      }
      final existingUser = await _dbHelper.getUserByEmail(_emailController.text);
      if (existingUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('email_already_used'))),
        );
        return;
      }

      final user = User(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        password: _passwordController.text,
      );
      await _dbHelper.registerUser(user);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('register_success'))),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _registerWithGoogle() async {
    GoogleSignInAccount? acct;
    try {
      acct = await _googleAuth.signIn();
    } on PlatformException catch (e) {
      final msg = (e.message ?? '').toLowerCase();
      final isDevError10 = msg.contains('10');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t(isDevError10 ? 'google_config_error' : 'google_signin_failed'))),
      );
      return;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('google_signin_failed'))));
      return;
    }
    if (acct == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('google_cancelled'))));
      return;
    }
    final email = acct.email;
    final name = acct.displayName ?? '';

    final existing = await _dbHelper.getUserByEmail(email);
    if (existing != null) {
      // Already exists: just log in
      if (existing.isBanned == 1) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('banned_account'))));
        return;
      }
      await _sessionManager.saveUserSession(existing.id!, existing.role);
      try {
        final up = Provider.of<UnreadProvider>(context, listen: false);
        await up.init(existing.id!);
      } catch (e) {}
      // Initialize cart provider
      try {
        await Provider.of<CartProvider>(context, listen: false).init(existing.id!);
      } catch (_) {}
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ClientHomeScreen()));
      return;
    }

    final user = User(name: name.isEmpty ? email.split('@').first : name, email: email, phone: '', password: DateTime.now().millisecondsSinceEpoch.toString());
    final id = await _dbHelper.registerUser(user);
      await _sessionManager.saveUserSession(id, 'client');
    // Language suggestion after first login if not set
    try {
      final savedLang = await SessionManager().getLanguage();
      if (savedLang == null) {
        final device = WidgetsBinding.instance.platformDispatcher.locale;
        final suggested = AIUserService().suggestSupportedLocale(device: device);
        // ignore: use_build_context_synchronously
        await context.read<LocaleProvider>().setLocale(suggested);
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('language_auto_set').replaceFirst('{lang}', suggested.languageCode))),
        );
      }
    } catch (_) {}
    try {
      final up = Provider.of<UnreadProvider>(context, listen: false);
      await up.init(id);
    } catch (e) {}
    // Initialize cart provider
    try {
      await Provider.of<CartProvider>(context, listen: false).init(id);
    } catch (_) {}
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
                // Gradient header
                Container(
                  height: constraints.maxHeight * 0.36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: BrandPalette.headerGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        ),
                        const SizedBox(width: 4),
                        Text(l10n.t('register'), style: GoogleFonts.lato(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        const Icon(Icons.person_add_alt_1, color: Colors.white70),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),

                Align(
                  alignment: Alignment.bottomCenter,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                            boxShadow: BrandPalette.softShadow,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(labelText: l10n.t('name_label'), prefixIcon: const Icon(Icons.person_outline)),
                                  validator: (value) => value!.isEmpty ? l10n.t('enter_name') : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _emailController,
                                  decoration: InputDecoration(labelText: l10n.t('email_label'), prefixIcon: const Icon(Icons.email_outlined)),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value!.isEmpty) return l10n.t('enter_email');
                                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                      return l10n.t('enter_valid_email');
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _phoneController,
                                  decoration: InputDecoration(labelText: l10n.t('phone_label'), prefixIcon: const Icon(Icons.phone_outlined)),
                                  keyboardType: TextInputType.phone,
                                  validator: (value) => value!.isEmpty ? l10n.t('enter_phone') : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: InputDecoration(
                                    labelText: l10n.t('password_label'),
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
                                      onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                                    ),
                                  ),
                                  obscureText: !_passwordVisible,
                                  validator: (value) {
                                    if (value!.isEmpty) return l10n.t('enter_password');
                                    if (value.length < 6) return l10n.t('password_too_short');
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  decoration: InputDecoration(
                                    labelText: l10n.t('confirm_password_label'),
                                    prefixIcon: const Icon(Icons.lock_person_outlined),
                                    suffixIcon: IconButton(
                                      icon: Icon(_confirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                                      onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                                    ),
                                  ),
                                  obscureText: !_confirmPasswordVisible,
                                  validator: (value) {
                                    if (value != _passwordController.text) {
                                      return l10n.t('passwords_do_not_match');
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _register,
                                  child: Text(l10n.t('register')),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.account_circle, size: 20),
                                    label: Text(l10n.t('register_with_google')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: _registerWithGoogle,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.center,
                                  child: TextButton.icon(
                                    onPressed: () => Navigator.of(context).pop(),
                                    icon: const Icon(Icons.login, size: 18),
                                    label: Text(l10n.t('login')),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ilgabbiano/widgets/custom_text_field.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';
import 'package:ilgabbiano/config/supabase_config.dart';
import 'package:ilgabbiano/theme/brand_palette.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;

  Future<void> _sendResetLink() async {
    if (_emailController.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: SupabaseConfig.resetRedirectUri,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lien de réinitialisation envoyé à votre email.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur envoi du lien: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // OTP and local fallback removed: Only email reset link is supported.

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Header gradient
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
                        Text(l10n.t('forgot_password'), style: GoogleFonts.lato(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        const Icon(Icons.lock_reset, color: Colors.white70),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),

                // Glass form card
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
                                CustomTextField(
                                  controller: _emailController,
                                  labelText: l10n.t('email_label'),
                                  icon: Icons.email_outlined,
                                  validator: (value) => value!.isEmpty ? l10n.t('enter_email') : null,
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _loading ? null : _sendResetLink,
                                    icon: const Icon(Icons.link),
                                    label: Text(l10n.t('reset_password')),
                                  ),
                                ),
                                const SizedBox(height: 4),
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

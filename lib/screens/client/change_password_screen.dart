import 'package:flutter/material.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/services/session_manager.dart';
import 'package:ilgabbiano/widgets/custom_app_bar.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dbHelper = DatabaseHelper();
  final _session = SessionManager();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      final l10n = AppLocalizations.of(context);
      final current = _currentPasswordController.text.trim();
      final next = _newPasswordController.text.trim();
      final confirm = _confirmPasswordController.text.trim();

      if (next.isEmpty) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        await _showErrorDialog(l10n.t('new_password_empty'));
        return;
      }
      if (next != confirm) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        await _showErrorDialog(l10n.t('passwords_do_not_match'));
        return;
      }

      final session = await _session.getUserSession();
      if (session == null) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        await _showErrorDialog(l10n.t('not_logged_in'));
        return;
      }

      final userId = session['id'] as int?;
      if (userId == null) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        await _showErrorDialog(l10n.t('not_logged_in'));
        return;
      }

      // Fetch user to obtain email (SessionManager doesn't store email)
      final user = await _dbHelper.getUserById(userId);
      if (user == null) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        await _showErrorDialog(l10n.t('user_not_found'));
        return;
      }

      // Verify current password by attempting a login with stored email
      final verified = await _dbHelper.loginUser(user.email, current);
      if (verified == null) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        await _showErrorDialog(l10n.t('current_password_incorrect'));
        return;
      }

      await _dbHelper.updatePasswordById(userId, next);
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      await _showSuccessAndPop();
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      await _showErrorDialog(AppLocalizations.of(context).t('unexpected_error'));
    }
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('⚠️'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK'),
          )
        ],
      ),
    );
  }

  Future<void> _showSuccessAndPop() async {
    if (!mounted) return;
    // Show a short success dialog then return to the previous screen automatically
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('✅'),
        content: Text(AppLocalizations.of(context).t('password_changed')),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      Navigator.of(context).pop(); // close dialog
      Navigator.of(context).pop(true); // go back to profile
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: AppLocalizations.of(context).t('change_password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).t('current_password_label'),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    icon: Icon(_obscureCurrent ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).t('new_password_label'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    icon: Icon(_obscureNew ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).t('confirm_password_label'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check),
                  label: Text(AppLocalizations.of(context).t('confirm')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

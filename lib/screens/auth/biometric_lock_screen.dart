import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../localization/app_localizations.dart';
import '../../providers/biometric_provider.dart';
import '../../services/biometric_auth_service.dart';
import '../auth/login_screen.dart';

class BiometricLockScreen extends StatefulWidget {
  final Widget next;
  const BiometricLockScreen({super.key, required this.next});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final _service = BiometricAuthService();
  bool _authing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_tryAuth);
  }

  Future<void> _tryAuth() async {
    if (!mounted) return;
    setState(() => _authing = true);
    final ok = await _service.authenticate(
      reason: AppLocalizations.of(context).t('unlock_with_fingerprint'),
    );
    if (!mounted) return;
    setState(() => _authing = false);
    if (ok) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => widget.next));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('biometric_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bio = context.watch<BiometricProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(t.t('biometric_unlock'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fingerprint, size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(t.t('unlock_with_fingerprint'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _authing ? null : _tryAuth,
                  icon: _authing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.fingerprint),
                  label: Text(t.t('unlock')),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Allow using password: disable biometric for now and go to login
                    if (bio.enabled) bio.disable();
                    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
                  },
                  icon: const Icon(Icons.lock_open),
                  label: Text(t.t('use_password_instead')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

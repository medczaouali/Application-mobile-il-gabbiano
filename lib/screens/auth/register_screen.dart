import 'package:flutter/material.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/models/user.dart';
import '../../services/google_auth.dart';
import '../../services/session_manager.dart';
import 'package:provider/provider.dart';
import 'package:ilgabbiano/providers/unread_provider.dart';
import '../client/client_home_screen.dart';
import '../../localization/app_localizations.dart';

class RegisterScreen extends StatefulWidget {
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
    final acct = await _googleAuth.signIn();
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
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ClientHomeScreen()));
      return;
    }

    final user = User(name: name.isEmpty ? email.split('@').first : name, email: email, phone: '', password: DateTime.now().millisecondsSinceEpoch.toString());
    final id = await _dbHelper.registerUser(user);
      await _sessionManager.saveUserSession(id, 'client');
    try {
      final up = Provider.of<UnreadProvider>(context, listen: false);
      await up.init(id);
    } catch (e) {}
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ClientHomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('register'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context).t('name_label')),
                validator: (value) => value!.isEmpty ? AppLocalizations.of(context).t('enter_name') : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context).t('email_label')),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value!.isEmpty) return AppLocalizations.of(context).t('enter_email');
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return AppLocalizations.of(context).t('enter_valid_email');
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context).t('phone_label')),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? AppLocalizations.of(context).t('enter_phone') : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).t('password_label'),
                  suffixIcon: IconButton(
                    icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                  ),
                ),
                obscureText: !_passwordVisible,
                validator: (value) {
                  if (value!.isEmpty) return AppLocalizations.of(context).t('enter_password');
                  if (value.length < 6) return AppLocalizations.of(context).t('password_too_short');
                  return null;
                },
              ),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).t('confirm_password_label'),
                  suffixIcon: IconButton(
                    icon: Icon(_confirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                  ),
                ),
                obscureText: !_confirmPasswordVisible,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return AppLocalizations.of(context).t('passwords_do_not_match');
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _register,
                child: Text(AppLocalizations.of(context).t('register')),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.login, size: 20),
                  label: Text(AppLocalizations.of(context).t('register_with_google')),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                  onPressed: _registerWithGoogle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

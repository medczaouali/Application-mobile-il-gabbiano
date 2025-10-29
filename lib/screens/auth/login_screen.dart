
import 'package:flutter/material.dart';
import 'package:ilgabbiano/screens/auth/forgot_password_screen.dart';
import 'package:ilgabbiano/widgets/custom_button.dart';
import 'package:ilgabbiano/widgets/custom_text_field.dart';
import 'package:provider/provider.dart';
import 'package:ilgabbiano/providers/unread_provider.dart';
import '../../db/database_helper.dart';
import '../../services/session_manager.dart';
import '../../localization/app_localizations.dart';
import '../../services/google_auth.dart';
import '../../models/user.dart';
import '../admin/admin_dashboard_screen.dart';
import '../client/client_home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
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

  void _login() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text;
      final password = _passwordController.text;
      final user = await _dbHelper.loginUser(email, password);

        if (user != null) {
        if (user.isBanned == 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).t('banned_account'))),
          );
          return;
        }
        await _sessionManager.saveUserSession(user.id!, user.role);
        // initialize UnreadProvider for this user so badges and banners are accurate immediately
        try {
          final up = Provider.of<UnreadProvider>(context, listen: false);
          await up.init(user.id!);
        } catch (e) {
          // ignore initialization issues
        }
        if (user.role == 'admin') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => AdminDashboardScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => ClientHomeScreen()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('incorrect_credentials'))),
        );
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    final acct = await _googleAuth.signIn();
    if (acct == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('google_cancelled'))));
      return;
    }

    final email = acct.email;
    final name = acct.displayName ?? '';

    // Try to find existing user by email
    final existing = await _dbHelper.getUserByEmail(email);
    if (existing != null) {
      if (existing.isBanned == 1) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('banned_account'))));
        return;
      }
      await _sessionManager.saveUserSession(existing.id!, existing.role);
      try {
        final up = Provider.of<UnreadProvider>(context, listen: false);
        await up.init(existing.id!);
      } catch (e) {}
      if (existing.role == 'admin') {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AdminDashboardScreen()));
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ClientHomeScreen()));
      }
      return;
    }

    // No user yet: create a new client user using Google info
    final newUser = User(name: name.isEmpty ? email.split('@').first : name, email: email, phone: '', password: DateTime.now().millisecondsSinceEpoch.toString());
    final id = await _dbHelper.registerUser(newUser);
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
      body: Column(
        children: [ 
          SizedBox(
            width: MediaQuery.sizeOf(context).width,
            child: Image.asset(
              'assets/icon.png',
              fit: BoxFit.fill,
            ),
          ),
          SizedBox(height: 20),
          Padding(
        padding: const EdgeInsets.all(16.0),

            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomTextField(
                    controller: _emailController,
                    labelText: AppLocalizations.of(context).t('email_label'),
                    icon: Icons.email,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context).t('enter_email');
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  CustomTextField(
                    controller: _passwordController,
                    labelText: AppLocalizations.of(context).t('password_label'),
                    icon: Icons.lock,
                    isPassword: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context).t('enter_password');
                      }
                      return null;
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => ForgotPasswordScreen()));
                      },
                      child: Text(AppLocalizations.of(context).t('forgot_password')),
                    ),
                  ),
                  SizedBox(height: 20),
                  CustomButton(
                    onPressed: _login,
                    text: AppLocalizations.of(context).t('login'),
                    icon: Icons.login,
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.login, size: 20),
                      label: Text(AppLocalizations.of(context).t('login_with_google')),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                      onPressed: _loginWithGoogle,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => RegisterScreen()),
                      );
                    },
                    child: Text(AppLocalizations.of(context).t('no_account_register')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

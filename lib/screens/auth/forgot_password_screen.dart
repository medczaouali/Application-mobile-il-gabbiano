import 'package:flutter/material.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/widgets/custom_app_bar.dart';
import 'package:ilgabbiano/widgets/custom_button.dart';
import 'package:ilgabbiano/widgets/custom_text_field.dart';
import '../../localization/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _dbHelper = DatabaseHelper();
  bool _emailExists = false;

  void _verifyEmail() async {
    if (_emailController.text.isEmpty) return;
    final user = await _dbHelper.getUserByEmail(_emailController.text);
    setState(() {
      _emailExists = user != null;
    });
    if (!_emailExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('no_account_found_for_email'))),
      );
    }
  }

  void _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      await _dbHelper.updatePassword(
          _emailController.text, _newPasswordController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('password_reset_success'))),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: CustomAppBar(title: AppLocalizations.of(context).t('forgot_password')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CustomTextField(
                controller: _emailController,
                labelText: AppLocalizations.of(context).t('email_label'),
                icon: Icons.email,
                validator: (value) =>
                    value!.isEmpty ? AppLocalizations.of(context).t('enter_email') : null,
              ),
              SizedBox(height: 20),
              if (!_emailExists)
                CustomButton(
                  text: AppLocalizations.of(context).t('verify_email'),
                  onPressed: _verifyEmail,
                ),
              if (_emailExists)
                AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  child: Column(
                    children: [
                      Text(AppLocalizations.of(context).t('email_found_enter_new_password')),
                      SizedBox(height: 20),
                      CustomTextField(
                        controller: _newPasswordController,
                        labelText: AppLocalizations.of(context).t('new_password_label'),
                        icon: Icons.lock,
                        isPassword: true,
            validator: (value) => value!.length < 6
              ? AppLocalizations.of(context).t('password_too_short')
              : null,
                      ),
                      SizedBox(height: 20),
                      CustomButton(
                        text: AppLocalizations.of(context).t('reset_password'),
                        onPressed: _resetPassword,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:ilgabbiano/services/session_manager.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('fr');

  Locale get locale => _locale;

  LocaleProvider() {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final code = await SessionManager().getLanguage();
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    await SessionManager().saveLanguage(locale.languageCode);
    notifyListeners();
  }
}

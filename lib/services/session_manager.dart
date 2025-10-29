
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _userIdKey = 'userId';
  static const String _userRoleKey = 'userRole';
  static const String _languageKey = 'language';

  Future<void> saveUserSession(int userId, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, userId);
    await prefs.setString(_userRoleKey, role);
  }

  Future<Map<String, dynamic>?> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_userIdKey);
    final role = prefs.getString(_userRoleKey);
    if (id != null && role != null) {
      return {'id': id, 'role': role};
    }
    return null;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_userRoleKey);
  }

  Future<void> saveLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, code);
  }

  Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey);
  }
}

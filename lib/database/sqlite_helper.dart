import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario.dart';

class LocalSessionManager {
  LocalSessionManager._();

  static const String _kIsLoggedInKey = 'is_logged_in';
  static const String _kCurrentUserKey = 'current_user';

  static Future<void> saveLoginState(bool isLoggedIn) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsLoggedInKey, isLoggedIn);
  }

  static Future<bool> getLoginState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsLoggedInKey) ?? false;
  }

  static Future<void> saveUser(Usuario usuario) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(usuario.toJson());
    await prefs.setString(_kCurrentUserKey, encoded);
  }

  static Future<Usuario?> getUser() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? encoded = prefs.getString(_kCurrentUserKey);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    final Map<String, dynamic> decoded =
        jsonDecode(encoded) as Map<String, dynamic>;
    return Usuario.fromJson(decoded);
  }

  static Future<void> clearSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIsLoggedInKey);
    await prefs.remove(_kCurrentUserKey);
  }
}

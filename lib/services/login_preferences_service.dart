import 'package:shared_preferences/shared_preferences.dart';

class LoginPreferencesService {
  static const String _rememberMeKey = 'login.rememberMe';
  static const String _biometricEnabledKey = 'login.biometricEnabled';
  static const String _savedEmailKey = 'login.savedEmail';

  Future<LoginPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LoginPreferences(
      rememberMe: prefs.getBool(_rememberMeKey) ?? false,
      biometricEnabled: prefs.getBool(_biometricEnabledKey) ?? false,
      savedEmail: prefs.getString(_savedEmailKey) ?? '',
    );
  }

  Future<void> save({
    required bool rememberMe,
    required bool biometricEnabled,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_rememberMeKey, rememberMe);
    await prefs.setBool(
      _biometricEnabledKey,
      rememberMe && biometricEnabled,
    );

    if (rememberMe && email.trim().isNotEmpty) {
      await prefs.setString(_savedEmailKey, email.trim());
    } else {
      await prefs.remove(_savedEmailKey);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_biometricEnabledKey);
    await prefs.remove(_savedEmailKey);
  }
}

class LoginPreferences {
  const LoginPreferences({
    required this.rememberMe,
    required this.biometricEnabled,
    required this.savedEmail,
  });

  final bool rememberMe;
  final bool biometricEnabled;
  final String savedEmail;
}

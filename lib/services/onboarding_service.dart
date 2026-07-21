import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _completedKey = 'onboarding.completed.v1';

  Future<bool> isCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_completedKey) ?? false;
  }

  Future<void> complete() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_completedKey, true);
  }
}

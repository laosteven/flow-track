import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyPaddlerName = 'paddler_name';
  static const String _keyBoatName = 'boat_name';
  static const String _keyAutoSave = 'auto_save_sessions';
  static const String _keyKeepAwake = 'keep_screen_awake';
  static const String _keyAdvancedMetrics = 'show_advanced_metrics';
  static const String _keyVibrate = 'vibrate_feedback';

  // Paddler Name
  Future<String> getPaddlerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPaddlerName) ?? '';
  }

  Future<void> setPaddlerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPaddlerName, name);
  }

  // Boat Name
  Future<String> getBoatName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBoatName) ?? '';
  }

  Future<void> setBoatName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBoatName, name);
  }

  // Auto-save Sessions
  Future<bool> getAutoSaveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoSave) ?? true;
  }

  Future<void> setAutoSaveSessions(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSave, value);
  }

  // Keep Screen Awake
  Future<bool> getKeepScreenAwake() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyKeepAwake) ?? false;
  }

  Future<void> setKeepScreenAwake(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyKeepAwake, value);
  }

  // Show Advanced Metrics
  Future<bool> getShowAdvancedMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAdvancedMetrics) ?? true;
  }

  Future<void> setShowAdvancedMetrics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAdvancedMetrics, value);
  }

  // Vibrate Feedback
  Future<bool> getVibrateFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyVibrate) ?? false;
  }

  Future<void> setVibrateFeedback(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVibrate, value);
  }
}

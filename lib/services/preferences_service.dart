import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyUserName = 'user_name';
  static const String _keyAppTheme = 'app_theme';
  static const String _keyBoardTheme = 'board_theme';

  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyUserName);
    return (name != null && name.trim().isNotEmpty) ? name : "Grandmaster";
  }

  static Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name.trim());
  }

  // 0 = Dark, 1 = Light
  static Future<int> getAppTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAppTheme) ?? 0; // Default Dark
  }

  static Future<void> setAppTheme(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAppTheme, index);
  }

  // Board themes (mapped to squares package BoardTheme later)
  static Future<String> getBoardTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBoardTheme) ?? "blueGrey";
  }

  static Future<void> setBoardTheme(String themeStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBoardTheme, themeStr);
  }
}

import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyUserName = 'user_name';
  static const String _keyAppTheme = 'app_theme';
  static const String _keyBoardTheme = 'board_theme';
  static const String _keyCustomQuotes = 'custom_quotes';

  /// The raw stored display name, or "" if the user has never set one.
  /// Deliberately does NOT fall back to a default — callers that pre-fill
  /// an editable text field need the true empty value, not literal text
  /// the user would have to manually clear. For anywhere the name is
  /// actually shown to the user, use [getDisplayName] instead.
  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyUserName);
    return (name != null && name.trim().isNotEmpty) ? name : "";
  }

  /// The name to actually display anywhere in the UI — falls back to
  /// "Friend" when unset. Every display context (Settings profile header,
  /// morning greeting, slide-to-stop screen, weather widget) used to call
  /// [getUserName] directly and show a blank/broken-looking name for any
  /// user who hadn't set one — which is most users, since setting a
  /// display name is an optional, easy-to-skip step.
  static Future<String> getDisplayName() async {
    final name = await getUserName();
    return name.isEmpty ? 'Friend' : name;
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

  static Future<List<String>> getCustomQuotes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyCustomQuotes) ?? [];
  }

  static Future<void> setCustomQuotes(List<String> quotes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyCustomQuotes, quotes);
  }
}

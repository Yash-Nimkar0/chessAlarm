import 'package:flutter/material.dart';
import 'preferences_service.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  String _boardTheme = "blueGrey";
  String get boardTheme => _boardTheme;

  Future<void> init() async {
    int themeIndex = await PreferencesService.getAppTheme();
    _themeMode = themeIndex == 2 ? ThemeMode.system : (themeIndex == 1 ? ThemeMode.light : ThemeMode.dark);
    _boardTheme = await PreferencesService.getBoardTheme();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    int index = mode == ThemeMode.system ? 2 : (mode == ThemeMode.light ? 1 : 0);
    await PreferencesService.setAppTheme(index);
    notifyListeners();
  }

  Future<void> setBoardTheme(String theme) async {
    _boardTheme = theme;
    await PreferencesService.setBoardTheme(theme);
    notifyListeners();
  }
}

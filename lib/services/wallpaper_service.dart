import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists an optional custom background image, shown behind every
/// screen via PlatformScaffold. A singleton ChangeNotifier (same pattern
/// as ThemeService) so PlatformScaffold can rebuild wherever it's used the
/// instant the wallpaper changes, without every screen needing to know
/// about it individually.
class WallpaperService extends ChangeNotifier {
  static final WallpaperService _instance = WallpaperService._internal();
  factory WallpaperService() => _instance;
  WallpaperService._internal();

  static const String _prefsKey = 'wakely_wallpaper_path';
  static const String _prefsOpacityKey = 'wakely_wallpaper_dim';

  String? _wallpaperPath;
  String? get wallpaperPath => _wallpaperPath;

  /// How much to darken the wallpaper so text stays legible over it —
  /// user-adjustable since a bright photo needs more dimming than a dark
  /// one. 0 = wallpaper at full brightness, 1 = fully black (wallpaper
  /// invisible).
  double _dimAmount = 0.55;
  double get dimAmount => _dimAmount;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _wallpaperPath = prefs.getString(_prefsKey);
    // A wallpaper set in a previous install/session may have been removed
    // from disk (e.g. this device's container was reset) — fall back to
    // the default gradient rather than trying to render a missing file.
    if (_wallpaperPath != null && !await File(_wallpaperPath!).exists()) {
      _wallpaperPath = null;
      await prefs.remove(_prefsKey);
    }
    _dimAmount = prefs.getDouble(_prefsOpacityKey) ?? 0.55;
    notifyListeners();
  }

  Future<void> setWallpaper(String? path) async {
    _wallpaperPath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, path);
    }
    notifyListeners();
  }

  Future<void> setDimAmount(double value) async {
    _dimAmount = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsOpacityKey, value);
    notifyListeners();
  }
}

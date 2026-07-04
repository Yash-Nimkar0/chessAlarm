import 'package:shared_preferences/shared_preferences.dart';

class EloService {
  static const String _eloKey = 'user_elo';
  static const int _defaultElo = 850; // Temporarily boosted for testing

  static Future<int> getElo() async {
    final prefs = await SharedPreferences.getInstance();
    // Temporarily force it to 850 even if they have 400 saved, so testing works immediately
    int elo = prefs.getInt(_eloKey) ?? _defaultElo;
    if (elo < 800) {
      elo = 850;
      await prefs.setInt(_eloKey, elo);
    }
    return elo;
  }

  static Future<void> updateElo(int change) async {
    final prefs = await SharedPreferences.getInstance();
    int currentElo = prefs.getInt(_eloKey) ?? _defaultElo;
    int newElo = currentElo + change;
    if (newElo < 100) newElo = 100; // Floor
    await prefs.setInt(_eloKey, newElo);
  }
}

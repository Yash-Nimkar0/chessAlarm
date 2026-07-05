import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EloService {
  static const String _eloKey = 'user_elo';
  static const String _eloHistoryKey = 'elo_history';
  static const String _streakKey = 'current_streak';
  static const String _longestStreakKey = 'longest_streak';
  static const String _lastWakeKey = 'last_wake_date';
  static const String _morningsWonKey = 'mornings_won';
  static const String _puzzlesSolvedKey = 'puzzles_solved';
  static const String _practiceStreakKey = 'practice_streak';
  static const String _lastPracticeKey = 'last_practice_date';
  static const String _puzzlesSolvedThisWeekKey = 'puzzles_solved_this_week';
  static const String _fastestSolveKey = 'fastest_solve_sec';
  static const String _currentWeekStartKey = 'current_week_start';
  static const String _themesStatsKey = 'themes_stats';
  static const int _defaultElo = 1000;

  static Future<int> getElo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_eloKey) ?? _defaultElo;
  }

  static Future<List<int>> getEloHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyString = prefs.getString(_eloHistoryKey);
    if (historyString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(historyString);
        return decoded.map((e) => e as int).toList();
      } catch (e) {
        return [_defaultElo];
      }
    }
    return [_defaultElo];
  }

  static Future<void> updateElo(int change) async {
    final prefs = await SharedPreferences.getInstance();
    int currentElo = prefs.getInt(_eloKey) ?? _defaultElo;
    int newElo = currentElo + change;
    if (newElo < 100) newElo = 100; // Floor
    await prefs.setInt(_eloKey, newElo);

    // Update history
    List<int> history = await getEloHistory();
    history.add(newElo);
    if (history.length > 7) {
      history = history.sublist(history.length - 7);
    }
    await prefs.setString(_eloHistoryKey, jsonEncode(history));
  }
  
  static Future<void> setElo(int elo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_eloKey, elo);
    await prefs.setString(_eloHistoryKey, jsonEncode([elo]));
  }
  
  static Future<void> checkAndResetWeeklyStats() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1)); // Monday
    final weekStartStr = DateTime(currentWeekStart.year, currentWeekStart.month, currentWeekStart.day).toIso8601String();
    
    final savedWeekStartStr = prefs.getString(_currentWeekStartKey);
    if (savedWeekStartStr != weekStartStr) {
      // New week started
      await prefs.setString(_currentWeekStartKey, weekStartStr);
      await prefs.setInt(_puzzlesSolvedThisWeekKey, 0);
      await prefs.remove(_fastestSolveKey);
    }
  }

  static Future<Map<String, dynamic>> getStats() async {
    await checkAndResetWeeklyStats();
    final prefs = await SharedPreferences.getInstance();
    
    // Calculate if streak is broken
    int currentStreak = prefs.getInt(_streakKey) ?? 0;
    final String? lastWakeStr = prefs.getString(_lastWakeKey);
    if (lastWakeStr != null) {
      final now = DateTime.now();
      final lastWake = DateTime.parse(lastWakeStr);
      final difference = DateTime(now.year, now.month, now.day)
          .difference(DateTime(lastWake.year, lastWake.month, lastWake.day))
          .inDays;
      if (difference > 1) {
        currentStreak = 0; // Streak was broken
        await prefs.setInt(_streakKey, 0);
      }
    }
    
    int practiceStreak = prefs.getInt(_practiceStreakKey) ?? 0;
    final String? lastPracticeStr = prefs.getString(_lastPracticeKey);
    if (lastPracticeStr != null) {
      final now = DateTime.now();
      final lastPractice = DateTime.parse(lastPracticeStr);
      final difference = DateTime(now.year, now.month, now.day)
          .difference(DateTime(lastPractice.year, lastPractice.month, lastPractice.day))
          .inDays;
      if (difference > 1) {
        practiceStreak = 0; // Practice streak was broken
        await prefs.setInt(_practiceStreakKey, 0);
      }
    }
    
    // Parse themes insight
    String? themesStr = prefs.getString(_themesStatsKey);
    Map<String, dynamic> themesStats = {};
    if (themesStr != null) {
      themesStats = jsonDecode(themesStr);
    }

    return {
      'currentStreak': currentStreak,
      'longestStreak': prefs.getInt(_longestStreakKey) ?? 0,
      'morningsWon': prefs.getInt(_morningsWonKey) ?? 0,
      'puzzlesSolved': prefs.getInt(_puzzlesSolvedKey) ?? 0,
      'practiceStreak': practiceStreak,
      'puzzlesSolvedThisWeek': prefs.getInt(_puzzlesSolvedThisWeekKey) ?? 0,
      'fastestSolve': prefs.getInt(_fastestSolveKey) ?? 0,
      'themesStats': themesStats,
    };
  }
  
  static Future<void> recordMorningSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    
    int mornings = prefs.getInt(_morningsWonKey) ?? 0;
    await prefs.setInt(_morningsWonKey, mornings + 1);
    
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day).toIso8601String();
    
    final String? lastWakeStr = prefs.getString(_lastWakeKey);
    int currentStreak = prefs.getInt(_streakKey) ?? 0;
    
    if (lastWakeStr != null) {
      final lastWake = DateTime.parse(lastWakeStr);
      final difference = DateTime(now.year, now.month, now.day)
          .difference(DateTime(lastWake.year, lastWake.month, lastWake.day))
          .inDays;
          
      if (difference == 1) {
        currentStreak++;
      } else if (difference > 1) {
        currentStreak = 1;
      }
    } else {
      currentStreak = 1;
    }
    
    await prefs.setInt(_streakKey, currentStreak);
    await prefs.setString(_lastWakeKey, todayDate);
    
    int longestStreak = prefs.getInt(_longestStreakKey) ?? 0;
    if (currentStreak > longestStreak) {
      await prefs.setInt(_longestStreakKey, currentStreak);
    }
  }
  
  static Future<void> recordPracticeSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day).toIso8601String();
    
    final String? lastPracticeStr = prefs.getString(_lastPracticeKey);
    int practiceStreak = prefs.getInt(_practiceStreakKey) ?? 0;
    
    if (lastPracticeStr != null) {
      final lastPractice = DateTime.parse(lastPracticeStr);
      final difference = DateTime(now.year, now.month, now.day)
          .difference(DateTime(lastPractice.year, lastPractice.month, lastPractice.day))
          .inDays;
          
      if (difference == 1) {
        practiceStreak++;
      } else if (difference > 1) {
        practiceStreak = 1;
      }
    } else {
      practiceStreak = 1;
    }
    
    await prefs.setInt(_practiceStreakKey, practiceStreak);
    await prefs.setString(_lastPracticeKey, todayDate);
  }
  
  static Future<void> recordPuzzleSolved({int? solveTimeSeconds, String? themes}) async {
    final prefs = await SharedPreferences.getInstance();
    int puzzles = prefs.getInt(_puzzlesSolvedKey) ?? 0;
    await prefs.setInt(_puzzlesSolvedKey, puzzles + 1);
    
    await checkAndResetWeeklyStats();
    int weeklyPuzzles = prefs.getInt(_puzzlesSolvedThisWeekKey) ?? 0;
    await prefs.setInt(_puzzlesSolvedThisWeekKey, weeklyPuzzles + 1);
    
    if (solveTimeSeconds != null && solveTimeSeconds > 0) {
      int currentFastest = prefs.getInt(_fastestSolveKey) ?? 9999;
      if (solveTimeSeconds < currentFastest) {
        await prefs.setInt(_fastestSolveKey, solveTimeSeconds);
      }
      
      if (themes != null && themes.isNotEmpty) {
        String? themesStr = prefs.getString(_themesStatsKey);
        Map<String, dynamic> themesStats = themesStr != null ? jsonDecode(themesStr) : {};
        
        List<String> puzzleThemes = themes.split(' ').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        for (String theme in puzzleThemes) {
           if (!themesStats.containsKey(theme)) {
             themesStats[theme] = {'count': 0, 'avgTime': 0.0};
           }
           int count = themesStats[theme]['count'];
           double avg = themesStats[theme]['avgTime'];
           
           double newAvg = ((avg * count) + solveTimeSeconds) / (count + 1);
           themesStats[theme] = {'count': count + 1, 'avgTime': newAvg};
        }
        
        await prefs.setString(_themesStatsKey, jsonEncode(themesStats));
      }
    }
  }
  
  static String getLevel(int morningsWon) {
    if (morningsWon < 5) return 'Pawn';
    if (morningsWon < 15) return 'Knight';
    if (morningsWon < 30) return 'Bishop';
    if (morningsWon < 50) return 'Rook';
    if (morningsWon < 100) return 'Queen';
    return 'Grandmaster';
  }
}

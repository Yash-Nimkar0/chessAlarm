import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class EloService {
  static const String _keyElo = 'wakely_points';
  static const String _keyCurrentStreak = 'wakely_stats_streak';
  static const String _keyLastSuccessDate = 'wakely_stats_last_date';
  static const String _keyMorningsWon = 'wakely_stats_mornings_won';
  static const String _keyMorningsWonThisWeek = 'wakely_stats_mornings_week';
  static const String _keyPuzzlesSolved = 'wakely_stats_puzzles';
  static const String _keyPuzzlesSolvedThisWeek = 'wakely_stats_puzzles_week';
  static const String _keyWeekStart = 'wakely_stats_week_start';
  static const String _keyFastestSolve = 'wakely_stats_fastest_solve';

  static Future<int> getElo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyElo) ?? 0;
  }

  static Future<List<int>> getEloHistory() async {
    final elo = await getElo();
    return [elo, elo];
  }

  static Future<Map<String, int>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    
    int currentStreak = prefs.getInt(_keyCurrentStreak) ?? 0;
    final lastDateStr = prefs.getString(_keyLastSuccessDate);
    if (lastDateStr != null) {
      final lastDate = DateTime.parse(lastDateStr);
      final today = DateTime(now.year, now.month, now.day);
      final lastSuccessDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      final difference = today.difference(lastSuccessDay).inDays;
      
      if (difference > 1) {
        currentStreak = 0;
      }
    }

    int puzzlesWeek = prefs.getInt(_keyPuzzlesSolvedThisWeek) ?? 0;
    int morningsWeek = prefs.getInt(_keyMorningsWonThisWeek) ?? 0;
    final weekStartStr = prefs.getString(_keyWeekStart);
    final currentWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    if (weekStartStr != null) {
      final weekStart = DateTime.parse(weekStartStr);
      if (weekStart.isBefore(currentWeekStart)) {
        puzzlesWeek = 0;
        morningsWeek = 0;
      }
    } else {
      puzzlesWeek = 0;
      morningsWeek = 0;
    }

    return {
      'currentStreak': currentStreak,
      'morningsWon': prefs.getInt(_keyMorningsWon) ?? 0,
      'morningsWonThisWeek': morningsWeek,
      'puzzlesSolved': prefs.getInt(_keyPuzzlesSolved) ?? 0,
      'puzzlesSolvedThisWeek': puzzlesWeek,
      'fastestSolve': prefs.getInt(_keyFastestSolve) ?? 0,
    };
  }

  static Future<void> updateElo(int change) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getElo();
    await prefs.setInt(_keyElo, current + change);
  }

  static Future<void> setElo(int elo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyElo, elo);
  }

  static Future<void> recordMorningSuccess({required int solveTimeSeconds}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    
    // Update streak
    int currentStreak = prefs.getInt(_keyCurrentStreak) ?? 0;
    final lastDateStr = prefs.getString(_keyLastSuccessDate);
    if (lastDateStr != null) {
      final lastDate = DateTime.parse(lastDateStr);
      final today = DateTime(now.year, now.month, now.day);
      final lastSuccessDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      final difference = today.difference(lastSuccessDay).inDays;
      
      if (difference == 1) {
        currentStreak++;
      } else if (difference > 1) {
        currentStreak = 1; // Restart streak
      }
      // If difference is 0 (same day), do not increment streak, but count as success
    } else {
      currentStreak = 1;
    }
    await prefs.setInt(_keyCurrentStreak, currentStreak);
    await prefs.setString(_keyLastSuccessDate, now.toIso8601String());
    
    // Update mornings won
    int morningsWon = prefs.getInt(_keyMorningsWon) ?? 0;
    await prefs.setInt(_keyMorningsWon, morningsWon + 1);

    // Update this-week mornings won — mirrors the weekly rollover logic in
    // recordPracticeSuccess below, on the same shared week-start boundary.
    // The Morning tab's weekly recap used to read puzzlesSolvedThisWeek
    // here instead, a counter this method never touches at all (only
    // recordPracticeSuccess does, and that path is unreachable — no UI
    // ever navigates to PracticeScreen), so "missions completed this week"
    // silently stayed 0 forever regardless of real usage.
    int morningsWeek = prefs.getInt(_keyMorningsWonThisWeek) ?? 0;
    final weekStartStr = prefs.getString(_keyWeekStart);
    final currentWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    if (weekStartStr != null) {
      final weekStart = DateTime.parse(weekStartStr);
      if (weekStart.isBefore(currentWeekStart)) {
        morningsWeek = 0;
      }
    } else {
      morningsWeek = 0;
    }
    await prefs.setInt(_keyMorningsWonThisWeek, morningsWeek + 1);
    await prefs.setString(_keyWeekStart, currentWeekStart.toIso8601String());

    // Update fastest solve
    int fastestSolve = prefs.getInt(_keyFastestSolve) ?? 0;
    if (fastestSolve == 0 || solveTimeSeconds < fastestSolve) {
      await prefs.setInt(_keyFastestSolve, solveTimeSeconds);
    }
    
    // Grant points
    await updateElo(10);
  }

  static Future<void> recordPracticeSuccess({required int solveTimeSeconds}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    
    // Update total puzzles solved
    int puzzlesSolved = prefs.getInt(_keyPuzzlesSolved) ?? 0;
    await prefs.setInt(_keyPuzzlesSolved, puzzlesSolved + 1);
    
    // Update weekly puzzles solved
    int puzzlesWeek = prefs.getInt(_keyPuzzlesSolvedThisWeek) ?? 0;
    final weekStartStr = prefs.getString(_keyWeekStart);
    final currentWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    
    if (weekStartStr != null) {
      final weekStart = DateTime.parse(weekStartStr);
      if (weekStart.isBefore(currentWeekStart)) {
        puzzlesWeek = 0;
      }
    } else {
      puzzlesWeek = 0;
    }
    await prefs.setInt(_keyPuzzlesSolvedThisWeek, puzzlesWeek + 1);
    await prefs.setString(_keyWeekStart, currentWeekStart.toIso8601String());
    
    // Grant points
    await updateElo(5);
  }

  static String getLevel(int morningsWon) {
    if (morningsWon >= 30) return "Grandmaster";
    if (morningsWon >= 14) return "Master";
    if (morningsWon >= 7) return "Adept";
    if (morningsWon >= 3) return "Initiate";
    return "Novice";
  }
}

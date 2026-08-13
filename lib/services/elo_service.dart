import 'dart:async';

class EloService {
  static Future<int> getElo() async => 400;
  static Future<List<int>> getEloHistory() async => [400, 400];
  static Future<Map<String, int>> getStats() async => {
    'currentStreak': 0, 
    'morningsWon': 0, 
    'puzzlesSolved': 0, 
    'puzzlesSolvedThisWeek': 0, 
    'fastestSolve': 0
  };
  static Future<void> updateElo(int change) async {}
  static Future<void> setElo(int elo) async {}
  static Future<void> recordMorningSuccess() async {}
  static Future<void> recordPracticeSuccess() async {}
  static Future<void> recordMissionCompleted({required int solveTimeSeconds, String? themes}) async {}
  static String getLevel(int morningsWon) => "Beginner";
}

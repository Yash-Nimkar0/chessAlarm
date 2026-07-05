import 'sleep_service.dart';

class PerformanceInsightService {
  static Future<Map<String, dynamic>> getInsights() async {
    final history = await SleepService.getHistory();
    if (history.isEmpty) {
       return {
          'hasInsight': false,
          'message': 'Keep sleeping with Chess Alarm to build your profile.'
       };
    }
    
    // Filter sessions that actually had a wake performance score
    final validSessions = history.where((s) => s.wakePerformanceScore != null).toList();
    if (validSessions.length < 3) {
       return {
          'hasInsight': false,
          'message': 'Keep solving morning puzzles to unlock insights.'
       };
    }
    
    // Calculate average sleep
    double totalHours = 0;
    for (var s in history) {
       totalHours += s.duration.inMinutes / 60.0;
    }
    double avgSleep = totalHours / history.length;
    
    // Find best performance duration
    SleepSession? bestSession;
    for (var s in validSessions) {
       if (bestSession == null || s.wakePerformanceScore! > bestSession.wakePerformanceScore!) {
          bestSession = s;
       }
    }
    
    double bestSleepDuration = bestSession!.duration.inMinutes / 60.0;
    
    String avgSleepStr = '${avgSleep.floor()}h ${(avgSleep * 60 % 60).toInt()}m';
    String bestSleepStr = '${bestSleepDuration.floor()}h ${(bestSleepDuration * 60 % 60).toInt()}m';
    
    return {
       'hasInsight': true,
       'avgSleep': avgSleepStr,
       'bestPerformanceSleep': 'Your best mornings usually happen after $bestSleepStr of sleep.',
    };
  }
}

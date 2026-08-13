import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakely/services/sleep_service.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SleepService Scoring Logic', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Midnight consistency bug is fixed (11:50 PM to 12:10 AM)', () async {
      final prefs = await SharedPreferences.getInstance();
      
      // Last night's session: Bedtime was 11:50 PM
      final lastSession = SleepSession(
        startTime: DateTime(2026, 8, 1, 23, 50, 0),
        endTime: DateTime(2026, 8, 2, 7, 0, 0),
        score: 80,
        confidence: 'High',
        totalMovementEvents: 0,
        soundActivityEvents: 0,
      );
      
      // Save it to history
      await prefs.setStringList('sleep_history', [jsonEncode(lastSession.toJson())]);

      // Tonight's active session checkpoint: Bedtime is 12:10 AM (the next day physically)
      final activeSession = SleepSession(
        startTime: DateTime(2026, 8, 2, 0, 10, 0),
        endTime: DateTime(2026, 8, 2, 7, 30, 0),
        score: 0, // Should be recalculated
        confidence: 'Active',
        totalMovementEvents: 0,
        soundActivityEvents: 0,
      );

      // Save as checkpoint to trigger recoverOrphanedSession
      await prefs.setString('sleep_checkpoint', jsonEncode(activeSession.toJson()));

      // Recover the session (which calculates score and moves it to history)
      await SleepService.recoverOrphanedSession();

      final historyJson = prefs.getStringList('sleep_history');
      expect(historyJson, isNotNull);
      expect(historyJson!.length, 2);

      final recoveredJson = jsonDecode(historyJson.last);
      final recoveredSession = SleepSession.fromJson(recoveredJson);

      // The duration is 7 hours 20 mins.
      // Duration score: 7.33 hours -> < 7.5 means penalty. (7.5 - 7.33) * 6 = ~1 penalty. 50 - 1 = 49.
      // Consistency score: 11:50 PM vs 12:10 AM is 20 minutes apart. 20 <= 60, so NO penalty. 25/25.
      // Disturbance: 0 events -> 5/5.
      // Total score: ~49 + 25 + 5 = ~79.
      // Previously, the 23h 40m diff would subtract 25 points, resulting in ~54.
      
      expect(recoveredSession.score, greaterThan(70), reason: 'Score should not be penalized heavily for midnight boundary');
    });
  });
}

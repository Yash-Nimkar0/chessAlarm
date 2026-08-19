import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakle/services/elo_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EloService stats', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('a real wake-mission success is reflected under the morningsWon key', () async {
      await EloService.recordMorningSuccess(solveTimeSeconds: 30);

      final stats = await EloService.getStats();

      // Regression: report_screen.dart's "Missions Beaten" stat reads
      // stats['morningsWon']. It used to read a key ('totalPuzzlesSolved')
      // that getStats() never returns, so the UI always showed 0 no matter
      // how many real alarms were completed.
      expect(stats['morningsWon'], equals(1));
    });

    test('morningsWon is distinct from puzzlesSolved (practice mode)', () async {
      await EloService.recordMorningSuccess(solveTimeSeconds: 30);

      final stats = await EloService.getStats();

      expect(stats['morningsWon'], equals(1));
      // Practice-mode completions are a separate counter and must not be
      // conflated with real wake-mission completions.
      expect(stats['puzzlesSolved'], equals(0));
    });

    test('multiple wake-mission successes accumulate morningsWon', () async {
      await EloService.recordMorningSuccess(solveTimeSeconds: 30);
      await EloService.recordMorningSuccess(solveTimeSeconds: 20);
      await EloService.recordMorningSuccess(solveTimeSeconds: 40);

      final stats = await EloService.getStats();
      expect(stats['morningsWon'], equals(3));
    });
  });
}

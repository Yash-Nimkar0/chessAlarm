import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wakely/models/mission_settings.dart';
import 'package:wakely/screens/missions/typing_mission.dart';

void main() {
  Future<void> pumpMission(
    WidgetTester tester, {
    required int rounds,
    required VoidCallback onSuccess,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TypingMission(
            onSuccess: onSuccess,
            onSkip: () {},
            settings: MissionSettings(
              mission: 'typing',
              missionRounds: rounds,
              missionData: const {
                'enabled_quotes': ['Discipline equals freedom'],
              },
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('single-round mission never shows "2 of 1" during the success transition', (tester) async {
    var successCalled = false;
    await pumpMission(tester, rounds: 1, onSuccess: () => successCalled = true);

    expect(find.text('Quote 1 of 1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Discipline equals freedom');
    await tester.pump();

    expect(successCalled, isTrue);
    // Regression: the round label used to increment unconditionally before
    // checking completion, so a rebuild during the success transition would
    // briefly display "Quote 2 of 1" even though the mission was already
    // done and there is no round 2.
    expect(find.text('Quote 2 of 1'), findsNothing);
    expect(find.text('Quote 1 of 1'), findsOneWidget);
  });

  testWidgets('multi-round mission advances the label correctly between rounds', (tester) async {
    var successCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TypingMission(
            onSuccess: () => successCalled = true,
            onSkip: () {},
            settings: MissionSettings(
              mission: 'typing',
              missionRounds: 2,
              missionData: const {
                'enabled_quotes': ['Same phrase every round'],
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Quote 1 of 2'), findsOneWidget);

    // Complete round 1 of 2 — should advance to round 2, not finish yet.
    await tester.enterText(find.byType(TextField), 'Same phrase every round');
    await tester.pump();

    expect(successCalled, isFalse);
    expect(find.text('Quote 2 of 2'), findsOneWidget);

    // Complete round 2 of 2 — should finish, and never show "3 of 2".
    await tester.enterText(find.byType(TextField), 'Same phrase every round');
    await tester.pump();

    expect(successCalled, isTrue);
    expect(find.text('Quote 3 of 2'), findsNothing);
    expect(find.text('Quote 2 of 2'), findsOneWidget);
  });
}

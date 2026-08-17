import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:wakely/screens/sound_picker_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  bool mockAlarmKitSupported = false;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('wakely.alarmkit'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'checkCapability') {
          return {
            'supported': mockAlarmKitSupported,
            'authorization': 'authorized',
          };
        }
        return null;
      },
    );
    
    // Mock audioplayers channel to avoid MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async {
        return 1;
      },
    );
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: SoundPickerScreen(
        initialSoundId: 'wakely_ringphone',
        initialFadeIn: true,
        initialFadeDuration: 30,
        onChanged: (result) {},
      ),
    );
  }

  testWidgets('shows Fade In controls on non-AlarmKit platforms (Android/Legacy iOS)', (WidgetTester tester) async {
    mockAlarmKitSupported = false;
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Fade In'), findsOneWidget);
    expect(find.text('15s'), findsOneWidget);
    expect(find.text('30s'), findsOneWidget);
    expect(find.text('60s'), findsOneWidget);
  });

  testWidgets('shows Fade In controls on AlarmKit platforms (iOS 26+) thanks to Dual-Layer Architecture', (WidgetTester tester) async {
    mockAlarmKitSupported = true;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Fade In'), findsOneWidget);
    expect(find.text('15s'), findsOneWidget);
    expect(find.text('30s'), findsOneWidget);
    expect(find.text('60s'), findsOneWidget);
    
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('shows intrinsic sound duration in the UI', (WidgetTester tester) async {
    mockAlarmKitSupported = false;
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // The repo has a bundled sound with 18 sec duration
    expect(find.text('18 sec'), findsWidgets);
    expect(find.text('72 sec'), findsWidgets);
  });
}

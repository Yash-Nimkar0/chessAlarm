import 'package:flutter_test/flutter_test.dart';
import 'package:wakely/features/alarms/data/alarm_kit_uuid.dart';

/// Mirrors WakelyAlarmKitManager.getUUID(for:) on the Swift side exactly,
/// so these tests catch drift between the two implementations.
String _swiftGetUUID(String id) {
  final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
  final last12 = digits.padLeft(12, '0');
  final truncated = last12.length > 12 ? last12.substring(last12.length - 12) : last12;
  return '00000000-0000-0000-0000-$truncated';
}

void main() {
  group('AlarmKit UUID codec', () {
    test('round-trips small and large IDs', () {
      for (final id in [1, 2, 3, 10, 12, 99999, 100002, 123456789]) {
        final uuid = _swiftGetUUID(id.toString());
        expect(parseAlarmKitUUID(uuid), equals(id), reason: 'id=$id via uuid=$uuid');
      }
    });

    test('id 1 and id 10 no longer collide (regression for right-padding bug)', () {
      final uuid1 = _swiftGetUUID('1');
      final uuid10 = _swiftGetUUID('10');
      expect(uuid1, isNot(equals(uuid10)));
      expect(parseAlarmKitUUID(uuid1), equals(1));
      expect(parseAlarmKitUUID(uuid10), equals(10));
    });

    test('handles null and malformed input safely', () {
      expect(parseAlarmKitUUID(null), isNull);
      expect(parseAlarmKitUUID('not-a-uuid-at-all'), isNull);
      expect(parseAlarmKitUUID(''), isNull);
    });

    test('a raw dashed UUID string never parses via bare int.tryParse (documents the old bug)', () {
      // This is the exact mistake AlarmKitIOSAlarmScheduler.getScheduledAlarms()
      // used to make: calling int.tryParse directly on the UUID string.
      final uuid = _swiftGetUUID('3');
      expect(int.tryParse(uuid), isNull);
      // The correct decoder recovers it.
      expect(parseAlarmKitUUID(uuid), equals(3));
    });
  });
}

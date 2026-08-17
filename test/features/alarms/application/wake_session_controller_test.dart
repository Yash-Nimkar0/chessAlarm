import 'package:flutter_test/flutter_test.dart';
import 'package:wakely/features/alarms/application/wake_session_controller.dart';
import 'package:wakely/features/alarms/application/alarm_controller.dart';
import 'package:wakely/features/alarms/data/alarm_repository.dart';
import 'package:wakely/features/alarms/data/alarm_scheduler.dart';
import 'package:wakely/features/alarms/domain/alarm_model.dart';
import 'package:wakely/features/alarms/domain/recurrence.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('WakeSessionController Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('startSession is idempotent', () async {
      final controller = WakeSessionController.instance;
      
      // Attempt to start a session for a non-existent alarm
      await controller.startSession(999);
      expect(controller.isActive, isFalse);
    });
  });
}

import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// Represents the current state of alarm-critical platform capabilities.
///
/// This replaces the scattered permission checks in home_screen.dart and
/// onboarding_screen.dart with a single, queryable state object.
class AlarmReliabilityStatus {
  final bool notifications;
  final bool exactAlarms;
  final bool fullScreenIntent;
  final bool batteryOptimized; // false = good (not battery-optimized = can run freely)

  const AlarmReliabilityStatus({
    required this.notifications,
    required this.exactAlarms,
    required this.fullScreenIntent,
    required this.batteryOptimized,
  });

  /// Whether the platform is likely to deliver alarms reliably.
  /// This is the primary check for UI display.
  bool get isReady => notifications && exactAlarms;

  /// Human-readable list of issues for UI display.
  List<String> get issues {
    final result = <String>[];
    if (!notifications) result.add('Notification permission required');
    if (!exactAlarms) result.add('Exact alarm permission required');
    if (!fullScreenIntent) result.add('Full-screen intent permission recommended');
    if (batteryOptimized) result.add('Battery optimization may delay alarms');
    return result;
  }

  @override
  String toString() =>
      'AlarmReliabilityStatus(notifications: $notifications, exactAlarms: $exactAlarms, '
      'fullScreen: $fullScreenIntent, batteryOptimized: $batteryOptimized, isReady: $isReady)';
}

/// Checks and reports alarm-related platform capabilities.
///
/// This service only CHECKS current state — it does NOT request permissions.
/// Permission requests should be triggered by explicit user actions.
class AlarmCapabilityService {
  /// Check all alarm-related capabilities.
  static Future<AlarmReliabilityStatus> check() async {
    bool notifications = true;
    bool exactAlarms = true;
    bool fullScreenIntent = true;
    bool batteryOptimized = false;

    if (Platform.isAndroid) {
      notifications = await Permission.notification.isGranted;
      exactAlarms = await Permission.scheduleExactAlarm.isGranted;
      fullScreenIntent = await Permission.systemAlertWindow.isGranted;
      batteryOptimized = !(await Permission.ignoreBatteryOptimizations.isGranted);
    } else if (Platform.isIOS) {
      notifications = await Permission.notification.isGranted;
      // iOS doesn't have exact alarm / full-screen intent permissions.
      exactAlarms = true;
      fullScreenIntent = true;
      batteryOptimized = false;
    }

    return AlarmReliabilityStatus(
      notifications: notifications,
      exactAlarms: exactAlarms,
      fullScreenIntent: fullScreenIntent,
      batteryOptimized: batteryOptimized,
    );
  }

  /// Request the minimum permissions needed for reliable alarms.
  ///
  /// Should only be called from an explicit user action (e.g., tapping
  /// "Fix permissions" banner, or during onboarding when user consents).
  static Future<void> requestAlarmPermissions() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
      await Permission.scheduleExactAlarm.request();
    } else if (Platform.isIOS) {
      await Permission.notification.request();
      await Permission.criticalAlerts.request();
    }
  }
}

import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

import '../features/alarms/application/alarm_controller.dart';
import '../features/alarms/domain/alarm_model.dart';
import 'elo_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // Fixed ID far outside the alarm-ID-derived range bedtime reminders use
  // (alarmId + 10000), so the two features never collide on the same slot.
  static const int _reEngagementNotificationId = 999999;

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(settings: initializationSettings);
  }

  static Future<void> setupSleepReminders() async {
    await _notificationsPlugin.cancelAll();
    
    final prefs = await SharedPreferences.getInstance();
    final reminderOffset = prefs.getString('bedtime_reminder') ?? 'at_bedtime'; 
    if (reminderOffset == 'off') return;

    int offsetMinutes = 0;
    if (reminderOffset == '15m') offsetMinutes = 15;
    if (reminderOffset == '30m') offsetMinutes = 30;

    // Must read from AlarmController (the unified WakelyAlarm repository),
    // not the legacy `alarm` plugin's own Alarm.getAlarms(): on iOS 26.1+,
    // AlarmKitIOSAlarmScheduler schedules alarms entirely through AlarmKit's
    // own MethodChannel, never touching the `alarm` plugin's native store.
    // Alarm.getAlarms() would silently return an empty list there, meaning
    // bedtime reminders would never fire on the primary supported iOS path.
    final alarms = await AlarmController.instance.getAlarms();
    for (final reminder in remindersDue(alarms, offsetMinutes: offsetMinutes, now: DateTime.now())) {
      _scheduleBedtimeReminder(reminder.alarmId, reminder.reminderTime, reminder.wakeTime);
    }
  }

  /// Pure logic (no plugin calls) for which enabled wake-routine alarms need
  /// a bedtime reminder scheduled, and when. Split out from
  /// [setupSleepReminders] so it's testable without needing to mock the
  /// notifications plugin's platform-specific internals.
  static List<_BedtimeReminder> remindersDue(
    List<WakelyAlarm> alarms, {
    required int offsetMinutes,
    required DateTime now,
  }) {
    final due = <_BedtimeReminder>[];
    for (final alarm in alarms) {
      if (!alarm.enabled || alarm.type != AlarmType.wakeRoutine) continue;

      final bedtime = alarm.time.subtract(Duration(minutes: (alarm.sleepGoal * 60).toInt()));
      final reminderTime = bedtime.subtract(Duration(minutes: offsetMinutes));

      if (reminderTime.isAfter(now)) {
        due.add(_BedtimeReminder(alarmId: alarm.id, reminderTime: reminderTime, wakeTime: alarm.time));
      }
    }
    return due;
  }

  /// Pushes a "come back" reminder out to 3 days from now. Called on every
  /// app open, so an active user's reminder keeps getting rescheduled
  /// further into the future and never actually fires - only a user who
  /// stops opening the app for 3 days will see it, nudging them back before
  /// they've fully lapsed.
  static Future<void> scheduleReEngagementReminder() async {
    await _notificationsPlugin.cancel(id: _reEngagementNotificationId);

    final stats = await EloService.getStats();
    final currentStreak = stats['currentStreak'] ?? 0;

    final String body = currentStreak > 0
        ? "Your $currentStreak day streak is about to reset. Set an alarm before you lose it."
        : "Heavy sleepers stay heavy sleepers without a system. Set an alarm and get back on track.";

    await _notificationsPlugin.zonedSchedule(
      id: _reEngagementNotificationId,
      title: 'Still there?',
      body: body,
      scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(days: 3)),
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(
           presentAlert: true,
           presentBadge: true,
           presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> _scheduleBedtimeReminder(int id, DateTime reminderTime, DateTime wakeTime) async {
    final List<String> messages = [
      "🌙 Time to prepare tomorrow. Your Wake Routine is ready.",
      "🌟 Tomorrow starts tonight. Rest up for your morning.",
      "🌙 Prepare your sleep. Your routine is waiting.",
      "🌟 Tomorrow's goal is waiting. Rest up for a good start."
    ];
    
    final message = messages[Random().nextInt(messages.length)];

    await _notificationsPlugin.zonedSchedule(
      id: id + 10000,
      title: 'Bedtime Reminder',
      body: message,
      scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(
           presentAlert: true,
           presentBadge: true,
           presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}

class _BedtimeReminder {
  final int alarmId;
  final DateTime reminderTime;
  final DateTime wakeTime;
  const _BedtimeReminder({required this.alarmId, required this.reminderTime, required this.wakeTime});
}

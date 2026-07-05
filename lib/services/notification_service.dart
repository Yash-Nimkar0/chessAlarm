import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mission_settings.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

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

    final alarms = await Alarm.getAlarms();
    for (var alarm in alarms) {
      if (alarm.payload != null) {
        final settings = MissionSettings.fromJsonString(alarm.payload!);
        if (settings.type == 'wakeRoutine') {
          DateTime bedtime = alarm.dateTime.subtract(Duration(minutes: (settings.sleepGoal * 60).toInt()));
          DateTime reminderTime = bedtime.subtract(Duration(minutes: offsetMinutes));
          
          if (reminderTime.isAfter(DateTime.now())) {
             _scheduleBedtimeReminder(alarm.id, reminderTime, alarm.dateTime);
          }
        }
      }
    }
  }

  static Future<void> _scheduleBedtimeReminder(int id, DateTime reminderTime, DateTime wakeTime) async {
    final List<String> messages = [
      "🌙 Time to prepare tomorrow. Your Wake Routine is ready.",
      "♟ Tomorrow starts tonight. Rest up for your challenge.",
      "🌙 Prepare your sleep. Your routine is waiting.",
      "♟ Tomorrow's challenge is waiting. Rest up for your next move."
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

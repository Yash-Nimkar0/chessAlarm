import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// A wrapper for tracking analytics events.
/// This currently logs to console and tracks retention locally via SharedPreferences.
/// It is structured so it can be easily swapped with Mixpanel/Amplitude/PostHog later.
class AnalyticsService {
  static const String _firstOpenDateKey = 'analytics_first_open_date';
  static const String _retentionDay1Key = 'retention_day_1_logged';
  static const String _retentionDay3Key = 'retention_day_3_logged';
  static const String _retentionDay7Key = 'retention_day_7_logged';
  static const String _retentionDay30Key = 'retention_day_30_logged';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_firstOpenDateKey)) {
      await prefs.setString(_firstOpenDateKey, DateTime.now().toIso8601String());
      logEvent('app_first_open');
    }
  }

  static void logEvent(String eventName, [Map<String, dynamic>? properties]) {
    // In the future, this is where you call Amplitude.getInstance().logEvent(eventName, eventProperties: properties);
    if (kDebugMode) {
      print('📊 [ANALYTICS] Event: $eventName | Properties: ${properties ?? {}}');
    }
  }

  static Future<void> checkRetention() async {
    final prefs = await SharedPreferences.getInstance();
    final firstOpenStr = prefs.getString(_firstOpenDateKey);
    if (firstOpenStr == null) return;

    final firstOpen = DateTime.parse(firstOpenStr);
    final now = DateTime.now();
    final daysSinceFirstOpen = DateTime(now.year, now.month, now.day)
        .difference(DateTime(firstOpen.year, firstOpen.month, firstOpen.day))
        .inDays;

    if (daysSinceFirstOpen >= 1 && daysSinceFirstOpen <= 2) {
      if (!(prefs.getBool(_retentionDay1Key) ?? false)) {
        logEvent('retention_day_1');
        await prefs.setBool(_retentionDay1Key, true);
      }
    }
    
    if (daysSinceFirstOpen >= 3 && daysSinceFirstOpen <= 4) {
      if (!(prefs.getBool(_retentionDay3Key) ?? false)) {
        logEvent('retention_day_3');
        await prefs.setBool(_retentionDay3Key, true);
      }
    }
    
    if (daysSinceFirstOpen >= 7 && daysSinceFirstOpen <= 9) {
      if (!(prefs.getBool(_retentionDay7Key) ?? false)) {
        logEvent('retention_day_7');
        await prefs.setBool(_retentionDay7Key, true);
      }
    }

    if (daysSinceFirstOpen >= 30 && daysSinceFirstOpen <= 35) {
      if (!(prefs.getBool(_retentionDay30Key) ?? false)) {
        logEvent('retention_day_30');
        await prefs.setBool(_retentionDay30Key, true);
      }
    }
  }
}

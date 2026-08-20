import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

/// Pushes the next-alarm time and current streak into the shared App Group
/// container so the iOS home screen widget (WakleWidget, in ios/WakleWidget)
/// can display them without launching the app.
class HomeWidgetService {
  static const String _appGroupId = 'group.com.yashnimkar.chessAlarm';
  static const String _iOSWidgetName = 'WakleWidget';

  static Future<void> update({
    required DateTime? nextAlarmTime,
    required int currentStreak,
  }) async {
    await HomeWidget.setAppGroupId(_appGroupId);

    final label = nextAlarmTime == null ? 'No alarm set' : DateFormat.jm().format(nextAlarmTime);

    await HomeWidget.saveWidgetData<String>('next_alarm_label', label);
    // Raw epoch seconds, not just the pre-formatted label - lets the native
    // widget render a genuinely live "in 1 hr 28 min" countdown via
    // SwiftUI's own relative-date text, which ticks on-device with zero
    // further app involvement, instead of a countdown that's already stale
    // the moment the widget was last refreshed.
    if (nextAlarmTime != null) {
      await HomeWidget.saveWidgetData<int>('next_alarm_epoch', nextAlarmTime.millisecondsSinceEpoch ~/ 1000);
    } else {
      await HomeWidget.saveWidgetData<int>('next_alarm_epoch', 0);
    }
    await HomeWidget.saveWidgetData<int>('current_streak', currentStreak);
    await HomeWidget.updateWidget(iOSName: _iOSWidgetName);
  }
}

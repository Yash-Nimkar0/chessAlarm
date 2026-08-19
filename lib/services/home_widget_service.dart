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
    await HomeWidget.saveWidgetData<int>('current_streak', currentStreak);
    await HomeWidget.updateWidget(iOSName: _iOSWidgetName);
  }
}

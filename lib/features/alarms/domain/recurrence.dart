/// Recurrence model for alarms.
///
/// Represents which days of the week an alarm repeats on.
/// Index convention: 0=Monday through 6=Sunday (matching DateTime.weekday - 1).
/// This matches the existing convention used in the edit_alarm_screen UI.

class Recurrence {
  /// Which days are active. Length must be exactly 7.
  /// Index 0 = Monday, 6 = Sunday.
  final List<bool> days;

  Recurrence(List<bool> days)
      : assert(days.length == 7, 'Recurrence days must have exactly 7 elements'),
        days = List.unmodifiable(days);

  /// A one-shot alarm has no recurring days.
  bool get isOneShot => !days.contains(true);

  /// Whether every day is selected.
  bool get isEveryday => days.every((d) => d);

  /// Whether only weekdays are selected (Mon-Fri).
  bool get isWeekdaysOnly =>
      days[0] && days[1] && days[2] && days[3] && days[4] && !days[5] && !days[6];

  /// Human-readable summary for display.
  String get displayText {
    if (isOneShot) return 'Once';
    if (isEveryday) return 'Every day';
    if (isWeekdaysOnly) return 'Weekdays';

    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final active = <String>[];
    for (int i = 0; i < 7; i++) {
      if (days[i]) active.add(labels[i]);
    }
    return active.join(', ');
  }

  /// No recurrence — one-shot alarm.
  factory Recurrence.none() => Recurrence(List.filled(7, false));

  /// Every day of the week.
  factory Recurrence.everyday() => Recurrence(List.filled(7, true));

  Recurrence copyWith({List<bool>? days}) {
    return Recurrence(days ?? List.from(this.days));
  }

  /// Create a mutable copy for UI editing (the [days] list is normally unmodifiable).
  List<bool> toMutableDays() => List.from(days);

  Map<String, dynamic> toJson() {
    return {'days': days};
  }

  factory Recurrence.fromJson(Map<String, dynamic> json) {
    final daysList = (json['days'] as List<dynamic>?)?.map((e) => e as bool).toList();
    if (daysList == null || daysList.length != 7) {
      return Recurrence.none();
    }
    return Recurrence(daysList);
  }

  /// Parse from legacy SharedPreferences JSON string (the old alarm_days_<id> format).
  factory Recurrence.fromLegacyJson(List<dynamic> decoded) {
    if (decoded.length != 7) return Recurrence.none();
    return Recurrence(decoded.map((e) => e as bool).toList());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Recurrence) return false;
    for (int i = 0; i < 7; i++) {
      if (days[i] != other.days[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(days);

  @override
  String toString() => 'Recurrence($displayText)';
}

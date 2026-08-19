class GreetingUtils {
  /// The single source of truth for the time-of-day greeting — every
  /// screen that shows one (morning_screen's heading, WeatherWidget) must
  /// call this rather than keeping its own copy. Two divergent copies used
  /// to exist; WeatherWidget's had no lower bound so 0-4am read as
  /// "morning" while this one's unbounded `else` read the same hours as
  /// "evening" — the two disagreed on-screen at the same moment.
  static String getGreeting({DateTime? now}) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else if (hour >= 17 && hour < 22) {
      return 'Good evening';
    } else {
      return 'Good night';
    }
  }
}

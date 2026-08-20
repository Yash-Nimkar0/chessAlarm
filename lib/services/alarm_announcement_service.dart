import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import '../utils/greeting_utils.dart';
import 'weather_service.dart';

/// Speaks a short readout at alarm ring time, for alarms with a
/// `RingAnnouncementMode` of voiceOnly or voiceAndTone (see
/// WakelyAlarm.announcementMode) — an Alarmy-style talking alarm. Day,
/// date, time, and weather are each independently selectable per alarm
/// (WakelyAlarm.announceDay/announceDate/announceTime/announceWeather).
///
/// Weather is read only from WeatherService's cache, never fetched fresh —
/// a hung or slow network call at ring time must never delay, block, or
/// silence the alarm itself. If the cache is missing or older than
/// [_maxWeatherAge] the weather portion is silently skipped; time/day/date
/// always speak regardless of weather state.
class AlarmAnnouncementService {
  AlarmAnnouncementService._();

  static final FlutterTts _tts = FlutterTts();
  static bool _configured = false;

  static const Duration _maxWeatherAge = Duration(hours: 6);

  // A ring cycle can trigger a speak attempt from more than one place (a
  // best-effort pre-interaction hook, then the guaranteed RingingScreen/
  // SlideToStopScreen hook) — de-duped per alarm id within a short window,
  // rather than forever, so a later genuine re-ring (a Wake Check re-alert,
  // or a snoozed alarm firing again) can still speak.
  static final Map<int, DateTime> _lastSpokenAt = {};
  static const Duration _dedupeWindow = Duration(minutes: 3);

  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    _configured = true;
    try {
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
    } catch (_) {
      // Device TTS unavailable or misconfigured — maybeSpeak() below fails
      // the same way and simply stays silent on the voice portion rather
      // than ever blocking or crashing the alarm over this.
    }
  }

  /// Speaks the readout for [alarmId] if [announcementMode] calls for it.
  /// Each of day/date/time/weather is independently selectable — any
  /// subset (including all four, or just one) produces a sensible
  /// sentence. Safe to call from multiple trigger points per ring cycle
  /// (only actually speaks once, per [_dedupeWindow], unless [forcePreview]
  /// bypasses that for an explicit "hear it now" preview) and safe to call
  /// even if TTS is unavailable on the device — never throws, never delays
  /// the caller waiting on the alarm to actually ring.
  static Future<void> maybeSpeak({
    required int alarmId,
    required String announcementMode,
    bool announceDay = true,
    bool announceDate = true,
    bool announceTime = true,
    bool announceWeather = true,
    bool forcePreview = false,
  }) async {
    if (announcementMode != 'voiceOnly' && announcementMode != 'voiceAndTone') return;

    if (!forcePreview) {
      final last = _lastSpokenAt[alarmId];
      if (last != null && DateTime.now().difference(last) < _dedupeWindow) return;
      _lastSpokenAt[alarmId] = DateTime.now();
    }

    try {
      await _ensureConfigured();
      await _tts.stop();
      await _tts.speak(_buildPhrase(
        announceDay: announceDay,
        announceDate: announceDate,
        announceTime: announceTime,
        announceWeather: announceWeather,
      ));
    } catch (_) {
      // Never let a TTS failure affect the alarm itself.
    }
  }

  static String _buildPhrase({
    required bool announceDay,
    required bool announceDate,
    required bool announceTime,
    required bool announceWeather,
  }) {
    final now = DateTime.now();
    final greeting = GreetingUtils.getGreeting(now: now);
    final buffer = StringBuffer(greeting);

    final dayDateParts = [
      if (announceDay) DateFormat('EEEE').format(now),
      if (announceDate) DateFormat('MMMM d').format(now),
    ];
    final sentenceParts = [
      if (dayDateParts.isNotEmpty) dayDateParts.join(', '),
      if (announceTime) DateFormat('h:mm a').format(now),
    ];

    if (sentenceParts.isNotEmpty) {
      buffer.write(". It's ${sentenceParts.join(', ')}.");
    } else {
      buffer.write('.');
    }

    if (announceWeather) {
      final weather = WeatherService.cachedWeather;
      final age = WeatherService.cacheAge;
      if (weather != null && age != null && age <= _maxWeatherAge) {
        buffer.write(' Currently ${weather.temperature.round()} degrees and ${weather.conditionTitle.toLowerCase()}.');
      }
    }

    return buffer.toString();
  }

  /// Stops any in-progress speech immediately — call when the ringing
  /// screen is dismissed/disposed so nothing keeps talking after the user
  /// has already moved on.
  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

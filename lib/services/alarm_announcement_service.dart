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
  // SlideToStopScreen hook) — de-duped per alarm id so it speaks once, not
  // once from each trigger point.
  //
  // This window must outlast the Wake Check relentless re-alert chain, not
  // just cover "two triggers landing close together": re-alerts fire every
  // kWakeCheckIntervalSeconds (3s) for up to kMaxWakeCheckReAlerts (200)
  // cycles - a ~10 minute worst case. A short window (this used to be 3
  // minutes) meant the phrase would arbitrarily speak AGAIN partway through
  // a single continuous, still-unanswered ring - not "repeats every re-alert"
  // and not "silent for the whole chain," just one jarring, unintended
  // repeat at whatever moment the window happened to expire. 20 minutes
  // safely covers the real 10-minute max with margin. The right trigger for
  // "speak again" is a NEW ring session, not a timer - see [clearDedupe],
  // called once a session actually ends (completed, escaped, or snoozed),
  // so the next genuine ring (tomorrow's occurrence, or a snoozed alarm
  // firing again in 5 minutes) always speaks fresh regardless of this
  // window.
  static final Map<int, DateTime> _lastSpokenAt = {};
  static const Duration _dedupeWindow = Duration(minutes: 20);

  /// Call once a ring session genuinely ends (completed, emergency-escaped,
  /// or snoozed) so the NEXT ring for this alarm - whether that's a snoozed
  /// re-fire minutes later or tomorrow's occurrence - speaks again
  /// immediately instead of waiting out [_dedupeWindow].
  static void clearDedupe(int alarmId) {
    _lastSpokenAt.remove(alarmId);
  }

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
      // flutter_tts defaults to deactivating the shared iOS audio session
      // the instant it finishes speaking - since the whole point of
      // voiceAndTone is the tone playing alongside/after the voice, that
      // default was silently killing the tone out from under it the moment
      // speech ended (mixWithOthers only governs OTHER apps' audio, not
      // whether finishing speech tears down the one shared session this
      // app's own tone is also using). Leave the session's lifecycle to
      // whatever actually owns the ring audio instead.
      await _tts.autoStopSharedSession(false);
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

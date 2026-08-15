import 'dart:convert';
import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/alarm_model.dart';
import '../domain/mission_config.dart';
import '../domain/recurrence.dart';
import 'alarm_id_allocator.dart';
import '../../sounds/data/sound_repository.dart';
import 'alarm_repository.dart';
import 'alarm_scheduler.dart';

/// Handles one-time migration from the legacy `alarm` package + SharedPreferences
/// setup to the unified WakelyAlarm domain model.
class AlarmMigration {
  static const String _migrationVersionKey = 'wakely_alarm_schema_version';
  static const int _targetVersion = 1;

  /// Run migration if needed.
  ///
  /// Safe to call on every app launch. It checks the version flag and only
  /// runs if migration is incomplete.
  static Future<void> migrateIfNeeded(AlarmRepository repository, AlarmScheduler scheduler) async {
    final prefs = await SharedPreferences.getInstance();
    final currentVersion = prefs.getInt(_migrationVersionKey) ?? 0;

    if (currentVersion >= _targetVersion) {
      return; // Already migrated
    }

    try {
      await _performMigration(prefs, repository, scheduler);
      // Only set success flag if everything completed without throwing
      await prefs.setInt(_migrationVersionKey, _targetVersion);
    } catch (e) {
      // Allow it to retry on next launch if it fails halfway
      print('Alarm migration failed: $e');
    }
  }

  static Future<void> _performMigration(
    SharedPreferences prefs,
    AlarmRepository repository,
    AlarmScheduler scheduler,
  ) async {
    // 1. Get legacy platform alarms
    final legacyAlarms = await Alarm.getAlarms();
    if (legacyAlarms.isEmpty) return;

    int maxExistingId = 0;

    for (final legacy in legacyAlarms) {
      if (legacy.id > maxExistingId) {
        maxExistingId = legacy.id;
      }

      // Check if we already migrated this specific alarm (idempotency check in case
      // of partial migration failure).
      final existing = await repository.getById(legacy.id);
      if (existing != null) {
        continue;
      }

      // 2. Parse legacy payload (with fallback so corruption doesn't destroy the alarm)
      Map<String, dynamic> payload = {};
      if (legacy.payload != null && legacy.payload!.isNotEmpty) {
        try {
          payload = jsonDecode(legacy.payload!);
        } catch (_) {}
      }

      final legacyTypeStr = payload['type'] as String? ?? 'alarm';
      final isWakeRoutine = legacyTypeStr == 'wakeRoutine' || legacyTypeStr == 'chess';
      final alarmType = AlarmType.fromString(legacyTypeStr);

      final missionTypeStr = payload['mission'] as String? ?? (isWakeRoutine ? 'memory' : 'none');
      final missionType = MissionType.fromString(missionTypeStr);

      final missionConfig = MissionConfig(
        type: missionType,
        difficultyMode: payload['difficultyMode'] as String? ?? 'adaptive',
        difficultyOverride: payload['difficultyOverride'] as int?,
        rounds: payload['missionRounds'] as int? ?? 1,
        data: payload['missionData'] as Map<String, dynamic>?,
      );

      // 3. Parse legacy recurrence
      Recurrence recurrence = Recurrence.none();
      final String? daysJson = prefs.getString('alarm_days_${legacy.id}');
      if (daysJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(daysJson);
          recurrence = Recurrence.fromLegacyJson(decoded);
        } catch (_) {}
      }

      // 4. Construct WakelyAlarm
      final wakelyAlarm = WakelyAlarm(
        id: legacy.id,
        time: legacy.dateTime,
        enabled: true, // Legacy platform alarms are by definition enabled
        type: alarmType,
        recurrence: recurrence,
        label: payload['label'] as String?,
        soundId: SoundRepository.instance.resolveLegacyPath(legacy.assetAudioPath ?? 'soft_morning'),
        fadeIn: legacy.volumeSettings.fadeDuration != null && legacy.volumeSettings.fadeDuration!.inSeconds > 0,
        fadeDuration: (legacy.volumeSettings.fadeDuration?.inSeconds ?? 30).toInt(),
        loopAudio: legacy.loopAudio,
        vibrate: legacy.vibrate,
        volume: legacy.volumeSettings.volume ?? 0.8,
        smartLock: payload['smartLock'] as bool? ?? isWakeRoutine, // default smart lock true for wake routines
        mission: missionConfig,
        sleepGoal: (payload['sleepGoal'] as num?)?.toDouble() ?? 8.0,
        sleepTracking: payload['sleepTracking'] as bool? ?? true,
        sleepSounds: payload['sleepSounds'] as bool? ?? true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 5. Persist and explicitly schedule using the new scheduler.
      // We schedule it again just to ensure the new AlarmSettings payload is updated 
      // in the platform storage.
      await scheduler.schedule(wakelyAlarm);
      await repository.save(wakelyAlarm);
    }

    // 6. Ensure the allocator won't collide with migrated IDs
    await AlarmIdAllocator.ensureAbove(maxExistingId);
  }
}

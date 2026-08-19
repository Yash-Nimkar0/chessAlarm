import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/alarm_model.dart';

/// Persistence layer for WakelyAlarm objects.
///
/// This is purely a CRUD storage layer. It does NOT interact with the
/// alarm platform plugin. All platform scheduling is handled by [AlarmScheduler].
///
/// Storage format: JSON list in SharedPreferences under a single key.
/// This is sufficient for the expected alarm count (<50) and consistent
/// with the existing app's persistence patterns.
class AlarmRepository {
  static const String _key = 'wakely_alarms';

  /// Retrieve all persisted alarms.
  Future<List<WakelyAlarm>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];

    List<dynamic> decoded;
    try {
      decoded = jsonDecode(jsonStr);
    } catch (e) {
      // Whole payload is corrupted (not even valid JSON) - nothing to salvage.
      if (kDebugMode) print('Failed to decode alarms JSON: $e');
      return [];
    }

    final alarms = <WakelyAlarm>[];
    for (final e in decoded) {
      try {
        alarms.add(WakelyAlarm.fromJson(e as Map<String, dynamic>));
      } catch (err) {
        // Skip just this one corrupt alarm rather than losing every alarm.
        if (kDebugMode) print('Skipping corrupt alarm entry: $err');
      }
    }
    return alarms;
  }

  /// Retrieve a single alarm by ID, or null if not found.
  Future<WakelyAlarm?> getById(int id) async {
    final alarms = await getAll();
    try {
      return alarms.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Save (create or update) an alarm.
  ///
  /// If an alarm with the same ID exists, it is replaced.
  /// Returns the saved alarm.
  Future<WakelyAlarm> save(WakelyAlarm alarm) async {
    final alarms = await getAll();

    // Remove existing alarm with same ID if present (update case).
    alarms.removeWhere((a) => a.id == alarm.id);
    alarms.add(alarm);

    await _persist(alarms);
    return alarm;
  }

  /// Delete an alarm by ID.
  ///
  /// Returns true if the alarm existed and was removed.
  Future<bool> delete(int id) async {
    final alarms = await getAll();
    final initialLength = alarms.length;
    alarms.removeWhere((a) => a.id == id);

    if (alarms.length != initialLength) {
      await _persist(alarms);
      return true;
    }
    return false;
  }

  /// Persist the full alarm list.
  Future<void> _persist(List<WakelyAlarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(alarms.map((a) => a.toJson()).toList());
    await prefs.setString(_key, jsonStr);
  }

  /// Check if any alarms exist.
  Future<bool> get isEmpty async => (await getAll()).isEmpty;
}

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Generates collision-safe, monotonically incrementing alarm IDs.
///
/// Uses a persisted counter so IDs are never reused, even across app restarts.
/// A static Completer-based lock serializes concurrent calls to prevent
/// two simultaneous allocations from reading the same counter value.
class AlarmIdAllocator {
  static const String _key = 'wakely_next_alarm_id';

  /// Lock to serialize concurrent allocate() calls.
  static Completer<void>? _lock;

  /// Allocate the next unique alarm ID.
  ///
  /// This is concurrency-safe: if two calls happen simultaneously,
  /// the second will wait for the first to complete before reading.
  static Future<int> allocate() async {
    // Wait for any in-flight allocation to finish.
    while (_lock != null && !_lock!.isCompleted) {
      await _lock!.future;
    }

    _lock = Completer<void>();
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = prefs.getInt(_key) ?? 1;
      await prefs.setInt(_key, next + 1);
      return next;
    } finally {
      _lock!.complete();
    }
  }

  /// Ensure the allocator counter is above all existing alarm IDs.
  ///
  /// Must be called during migration so that future allocations
  /// never collide with IDs that were already assigned by the old
  /// Random().nextInt(10000) system.
  static Future<void> ensureAbove(int maxExistingId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key) ?? 1;
    if (current <= maxExistingId) {
      await prefs.setInt(_key, maxExistingId + 1);
    }
  }

  /// Get the current counter value (for testing/diagnostics).
  static Future<int> peekNext() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 1;
  }
}

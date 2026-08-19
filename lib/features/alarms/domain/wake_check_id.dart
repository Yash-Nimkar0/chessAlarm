/// Shared offset used to derive a Wake Check fallback alarm's ID from its
/// parent alarm's ID (parentId + kWakeCheckIdOffset).
///
/// This lives in `domain` (rather than being private to
/// `WakeSessionController`) because both the application layer
/// (`WakeSessionController`, which schedules the Dart-side fallback) and the
/// data layer (`AlarmKitIOSAlarmScheduler`, which must avoid telling the
/// native side to cascade a Wake Check onto a Wake Check alarm) need to
/// agree on the exact same value.
const int kWakeCheckIdOffset = 99999;

/// Whether [alarmId] is itself a Wake Check fallback alarm's ID, as opposed
/// to a real user-created alarm.
bool isWakeCheckAlarmId(int alarmId) => alarmId >= kWakeCheckIdOffset;

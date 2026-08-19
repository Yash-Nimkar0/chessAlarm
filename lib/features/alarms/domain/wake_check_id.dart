/// Shared offset used to derive a Wake Check fallback alarm's ID from its
/// parent alarm's ID (parentId + kWakeCheckIdOffset).
///
/// This lives in `domain` (rather than being private to
/// `WakeSessionController`) because both the application layer
/// (`WakeSessionController`, which schedules the Dart-side fallback) and the
/// data layer (`AlarmKitIOSAlarmScheduler`, which must tell the native side
/// whether to cascade another Wake Check on top of one that already fired)
/// need to agree on the exact same value.
const int kWakeCheckIdOffset = 99999;

/// Whether [alarmId] is itself a Wake Check fallback alarm's ID, as opposed
/// to a real user-created alarm.
bool isWakeCheckAlarmId(int alarmId) => alarmId >= kWakeCheckIdOffset;

/// The original (real, user-created) alarm ID a Wake Check chain belongs to.
/// Wake Check alarms always reuse the SAME derived ID
/// (`kWakeCheckIdOffset + originalAlarmId`) on every re-alert cycle rather
/// than growing a new ID each time, so the chain has one fixed native
/// "slot" that gets rescheduled repeatedly instead of an ever-expanding set
/// of alarms. Given either a real alarm ID or a Wake Check ID, this always
/// resolves back to the original.
int originalAlarmIdFor(int alarmId) =>
    isWakeCheckAlarmId(alarmId) ? alarmId - kWakeCheckIdOffset : alarmId;

/// Deterministic ID for the Wake Check fallback alarm belonging to
/// [originalAlarmId] (which may itself already be a Wake Check ID — this
/// normalizes first, so re-scheduling a chain always targets the same slot).
int wakeCheckAlarmIdFor(int originalAlarmId) => kWakeCheckIdOffset + originalAlarmIdFor(originalAlarmId);

/// How many times a Wake Check is allowed to re-alert before Wakely stops
/// automatically rescheduling it and just leaves the mission unresolved
/// (still not counted as complete — the user can still open the app and
/// finish it, there's just no further automatic native re-alert). Chosen to
/// feel relentless (matching the explicit product goal: a heavy sleeper
/// must not be able to escape by repeatedly silencing it) while stopping
/// short of literal unbounded notification spam.
const int kMaxWakeCheckReAlerts = 20;

/// Spacing between Wake Check re-alerts. Deliberately short — a multi-minute
/// gap reads as a snooze, which is a different feature; this is meant to be
/// close to immediate.
const int kWakeCheckIntervalSeconds = 30;

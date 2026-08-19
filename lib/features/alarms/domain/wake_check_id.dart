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

/// Spacing between Wake Check re-alerts. Explicit product requirement: this
/// must read as "the alarm just keeps ringing," not a snooze — a 30s (let
/// alone multi-minute) gap is a completely different, much weaker
/// experience. Kept above 0 only because scheduling a new native alarm on
/// every single tick has real overhead and no verified floor from Apple;
/// a few seconds is as close to instant as is reasonable to ship without
/// physical-device confirmation that shorter is safe.
const int kWakeCheckIntervalSeconds = 3;

/// How many times a Wake Check is allowed to re-alert before Wakely stops
/// automatically rescheduling it and just leaves the mission unresolved
/// (still not counted as complete — the user can still open the app and
/// finish it, there's just no further automatic native re-alert). Sized
/// against kWakeCheckIntervalSeconds to keep the same ~10-minute total
/// relentless window as before, just far more frequent within it —
/// matching the explicit product goal that a heavy sleeper must not be
/// able to escape by repeatedly silencing it, while stopping short of
/// literal unbounded spam.
const int kMaxWakeCheckReAlerts = 200;

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
/// of alarms. Given any of a real alarm ID, a reactive Wake Check slot ID,
/// or a pre-scheduled chain ID, this always resolves back to the original.
///
/// MUST check the chain-ID band (kWakeCheckChainIdBase, ~1 billion+) before
/// falling back to the old small-offset (kWakeCheckIdOffset, 99999) check —
/// chain IDs are also >= kWakeCheckIdOffset, so without this ordering every
/// chain-derived event (the vast majority of interactions once the chain is
/// running — 30 chain slots vs. 1 reactive slot) decoded to a garbage
/// "original id" instead of the real one. Confirmed live as two compounding
/// failures: on the Dart side, any interaction whose native id was a chain
/// entry could never find a matching alarm record and silently did
/// nothing (tapping the alert's buttons opened the app but showed no
/// mission screen); on the Swift side (see the mirrored fix in
/// AlarmKitManager.swift's originalAlarmId(for:)), every chain-derived stop
/// spawned an entirely separate, orphaned reactive re-alert cycle under
/// that garbage id — invisible to completeSession()'s cleanup, which only
/// ever cancels the real original id's alarms — so completing the mission
/// stopped the alarms we knew about while a rogue chain kept ringing.
int originalAlarmIdFor(int alarmId) {
  if (isWakeCheckChainAlarmId(alarmId)) return chainOriginalAlarmId(alarmId);
  return isWakeCheckAlarmId(alarmId) ? alarmId - kWakeCheckIdOffset : alarmId;
}

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

/// Base of the ID band used by the native (Swift-only) pre-scheduled Wake
/// Check chain — see wakeCheckChainIdBase in AlarmKitManager.swift, which
/// this must mirror exactly. Chain alarms are scheduled directly by native
/// code and deliberately have NO corresponding [WakelyAlarm] record in the
/// Dart repository (there's nothing for the user to see or edit), so any
/// code that walks native alarms looking for orphans (alarms with no local
/// DB record) must recognize and skip this ID band — otherwise it reads as
/// "deleted locally" and gets cancelled, silently deleting the entire
/// hardware-button-dismiss backstop the first time the app is reconciled.
const int kWakeCheckChainIdBase = 1000000000;

/// Whether [alarmId] belongs to the native pre-scheduled Wake Check chain
/// (as opposed to a real user alarm or a reactive single-slot Wake Check
/// alarm, both of which are always well below this band).
bool isWakeCheckChainAlarmId(int alarmId) => alarmId >= kWakeCheckChainIdBase;

/// Mirrors wakeCheckChainIndexStride in AlarmKitManager.swift.
const int kWakeCheckChainIndexStride = 1000000;

/// Decodes the original (real, user-created) alarm ID embedded in a Wake
/// Check chain alarm's ID. Mirrors wakeCheckChainAlarmId(originalId:index:)
/// on the Swift side (chainId = chainIdBase + index*stride + originalId) —
/// safe as a plain remainder because real Wakely alarm IDs are always well
/// below kWakeCheckChainIndexStride.
int chainOriginalAlarmId(int chainAlarmId) => (chainAlarmId - kWakeCheckChainIdBase) % kWakeCheckChainIndexStride;

import Foundation
import AlarmKit
import AppIntents
import Flutter
import SwiftUI

@available(iOS 26.1, *)
public class WakelyAlarmKitManager: NSObject, FlutterStreamHandler {
    public static let shared = WakelyAlarmKitManager()
    
    var eventSink: FlutterEventSink?
    
    // Hold pending interaction for cold start
    var pendingAlarmInteraction: String?
    
    // Hold authorization status task
    private var authTask: Task<Void, Never>?
    private var alarmsTask: Task<Void, Never>?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Event Channel
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    public func startListeningToNativeStreams() {
        authTask?.cancel()
        authTask = Task {
            for await status in AlarmManager.shared.authorizationUpdates {
                var authString = "unsupported"
                switch status {
                case .notDetermined: authString = "notDetermined"
                case .denied: authString = "denied"
                case .authorized: authString = "authorized"
                @unknown default: authString = "unsupported"
                }
                
                DispatchQueue.main.async {
                    self.eventSink?(["type": "authUpdate", "status": authString])
                }
            }
        }
        
        alarmsTask?.cancel()
        alarmsTask = Task {
            for await alarms in AlarmManager.shared.alarmUpdates {
                let mappedAlarms = alarms.map { alarm -> [String: Any] in
                    var statusStr = "unknown"
                    switch alarm.state {
                    case .scheduled: statusStr = "scheduled"
                    case .alerting: statusStr = "firing"
                    default: statusStr = "unknown"
                    }
                    return [
                        "id": alarm.id.uuidString,
                        "state": statusStr
                    ]
                }
                
                DispatchQueue.main.async {
                    self.eventSink?(["type": "update", "alarms": mappedAlarms])
                }
            }
        }
    }
    
    // MARK: - Method Channel Implementations
    
    public func checkCapability(completion: @escaping ([String: Any]) -> Void) {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        
        // Exact production API requirement: 26.1 for AlarmPresentation.Alert
        let isSupported = (osVersion.majorVersion >= 26 && osVersion.minorVersion >= 1) || osVersion.majorVersion > 26
        
        if !isSupported {
            completion(["supported": false, "authorization": "unsupported"])
            return
        }
        
        Task {
            let status = AlarmManager.shared.authorizationState
            var authString = "unsupported"
            switch status {
            case .notDetermined: authString = "notDetermined"
            case .denied: authString = "denied"
            case .authorized: authString = "authorized"
            @unknown default: authString = "unsupported"
            }
            
            DispatchQueue.main.async {
                completion(["supported": true, "authorization": authString])
            }
        }
    }
    
    public func getScheduledAlarms(completion: @escaping ([[String: Any]]) -> Void) {
        Task {
            do {
                let alarms = try await AlarmManager.shared.alarms
                let result = alarms.map { alarm -> [String: Any] in
                    // Real per-alarm state (mirrors the mapping in
                    // startListeningToNativeStreams' alarmUpdates handler).
                    // This USED to be hardcoded to "scheduled" for every
                    // alarm regardless of what it was actually doing, which
                    // broke cold-start recovery: reconcile() had no way to
                    // learn "this alarm is currently ringing" from native
                    // truth, only from Dart's own prior bookkeeping — which
                    // never happened at all if the app was killed before
                    // the alarm ever fired (exactly the scenario the whole
                    // Wake Check chain exists for). Confirmed live: an
                    // alarm kept relentlessly ringing via the chain while
                    // the app, once reopened, showed a normal alarm list
                    // instead of recovering into the mission screen.
                    var statusStr = "unknown"
                    switch alarm.state {
                    case .scheduled: statusStr = "scheduled"
                    case .alerting: statusStr = "firing"
                    default: statusStr = "unknown"
                    }
                    return [
                        "id": alarm.id.uuidString,
                        "state": statusStr,
                        "scheduledAt": 0 // Flutter will match by ID and use local DB for time
                    ]
                }
                DispatchQueue.main.async {
                    completion(result)
                }
            } catch {
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    /// Deterministically derives a UUID from a Wakely alarm ID (a plain decimal
    /// integer string, e.g. "3"). The digits are left-zero-padded into the
    /// UUID's final 12-character segment so distinct IDs never collide.
    ///
    /// The previous scheme right-padded with zeros (e.g. id "1" ->
    /// "10000000-0000-0000-0000-000000000000"), which meant id "1" and id "10"
    /// produced the identical UUID — a real collision, not just a formatting
    /// quirk. Dart's `parseAlarmKitUUID` must mirror this exactly to decode it.
    private func getUUID(for id: String) -> UUID {
        let digits = id.filter { $0.isNumber }
        let last12 = String((String(repeating: "0", count: 12) + digits).suffix(12))
        let uuidString = "00000000-0000-0000-0000-\(last12)"
        return UUID(uuidString: uuidString) ?? UUID()
    }
    
    // MARK: - Wake Check bookkeeping
    //
    // A Wake Check is a follow-up alarm that re-alerts the user if a mission
    // alarm's native Stop button is tapped without the mission actually being
    // completed in Wakely. The Dart side already schedules this fallback
    // (WakeSessionController._scheduleWakeCheckFallback), but that requires
    // the Flutter engine + EventChannel listener to be fully alive by the
    // time the native "stop" interaction is delivered. Scheduling it here,
    // directly inside StopAlarmIntent.perform(), is strictly more reliable:
    // AlarmKit's `.foreground(.immediate)` intent mode guarantees this code
    // runs in-process (launching the app if needed), with no dependency on
    // Dart/Flutter having finished booting. Both paths target the identical
    // deterministic UUID (see wakeCheckAlarmId below), so whichever runs
    // first "wins" and the other is a harmless no-op reschedule.
    //
    // These keys are plain UserDefaults.standard entries — StopAlarmIntent
    // and OpenWakelyIntent are declared in this same app target (no separate
    // extension), so they share the exact same sandboxed container/process
    // as the running Flutter app; no App Group is needed.
    // Mirrors lib/features/alarms/domain/wake_check_id.dart exactly — both
    // sides must agree on these values.
    private static let wakeCheckIdOffset = 99999
    private static let wakeCheckIntervalSeconds: TimeInterval = 3
    private static let maxWakeCheckReAlerts = 200

    // MARK: - Wake Check chain (pre-scheduled, hardware-button-proof)
    //
    // Confirmed live on device: dismissing an AlarmKit alert via the
    // hardware volume/side button does NOT invoke `stopIntent` — the alarm
    // just silences and never reschedules, even though the exact same
    // scenario reached via the on-screen interaction does reschedule.
    // Apple's own developer forums (developer.apple.com/forums/thread/805937,
    // /810865) confirm the buttons "turn off" the alarm but do not document
    // any app code running as a result. Since a killed app plus a hardware
    // button leaves nothing of ours running to react, the only mechanism
    // that can survive that path is having already scheduled every re-alert
    // BEFORE the first one ever fires: each chain alarm has its own unique
    // native ID, so silencing one has zero effect on whether the next one
    // fires on its own independently pre-set schedule. This is scheduled
    // unconditionally alongside the primary alarm below; the reactive
    // scheduleWakeCheckIfNeeded() path (triggered from StopAlarmIntent)
    // remains as a belt-and-suspenders extension for any interaction that
    // *does* route through our code.
    private static let wakeCheckChainIdBase = 1_000_000_000
    private static let wakeCheckChainIndexStride = 1_000_000

    // The chain is scheduled BLIND — with no way to know at schedule time
    // whether the previous entry will still be legitimately, untouched
    // ringing when the next one's fire time arrives. Confirmed live: at a
    // short interval (previously reused wakeCheckIntervalSeconds = 3s),
    // AlarmKit forcibly supersedes a still-alerting alarm the instant the
    // next scheduled one fires, which chopped a completely untouched,
    // legitimate ring into a 2-3s-on/off cycle — a real regression, not
    // the "instant re-alert after a genuine dismiss" behavior this was
    // meant to provide. The reactive path (scheduleWakeCheckIfNeeded,
    // triggered only once we KNOW the alarm was actually stopped) keeps
    // using the short wakeCheckIntervalSeconds — it has no risk of cutting
    // off a legitimate ring, since it only ever fires after a confirmed
    // stop. This chain interval is intentionally longer and still
    // provisional pending a real-device measurement of how long an
    // AlarmKit alert naturally keeps ringing on its own when left
    // completely untouched — it should end up set to just past that
    // natural duration, not shorter.
    private static let wakeCheckChainIntervalSeconds: TimeInterval = 20
    private static let wakeCheckChainMaxEntries = 30

    private static func wakeCheckChainAlarmId(originalId: Int, index: Int) -> String {
        String(wakeCheckChainIdBase + index * wakeCheckChainIndexStride + originalId)
    }

    private static func wakeCheckRequiredKey(_ id: String) -> String { "wakely_requires_wake_check_\(id)" }
    private static func soundKey(_ id: String) -> String { "wakely_sound_\(id)" }
    private static func wakeCheckCountKey(_ originalId: Int) -> String { "wakely_wake_check_count_\(originalId)" }

    /// The original (real, user-created) alarm ID a Wake Check chain
    /// belongs to. Mirrors originalAlarmIdFor() in wake_check_id.dart —
    /// MUST check the chain-ID band first, exactly like the Dart side, for
    /// the same reason: chain IDs are also >= wakeCheckIdOffset, so without
    /// this ordering every chain-derived stop (StopAlarmIntent.perform()
    /// firing for ANY of the 30 chain entries, not just the original)
    /// decoded to a garbage "original id" here and spawned an entirely
    /// separate, orphaned reactive re-alert cycle under that wrong id —
    /// invisible to cancelWakeCheckChain/cancelAlarm, which only ever
    /// operate on the real original id. Confirmed live: completing the
    /// mission stopped the alarms Wakely knew about while a rogue chain,
    /// spawned by this exact bug, kept ringing regardless.
    private static func originalAlarmId(for id: String) -> Int {
        let numeric = Int(id.filter { $0.isNumber }) ?? 0
        if numeric >= wakeCheckChainIdBase {
            return (numeric - wakeCheckChainIdBase) % wakeCheckChainIndexStride
        }
        return numeric >= wakeCheckIdOffset ? numeric - wakeCheckIdOffset : numeric
    }

    /// Deterministic ID for the Wake Check alarm belonging to [originalId].
    /// Always the SAME slot regardless of re-alert cycle — mirrors
    /// wakeCheckAlarmIdFor() in wake_check_id.dart.
    private static func wakeCheckAlarmId(for id: String) -> String {
        String(wakeCheckIdOffset + originalAlarmId(for: id))
    }

    public func scheduleAlarm(id: String, date: Date, soundName: String, requiresWakeCheck: Bool, completion: @escaping (Error?) -> Void) {
        UserDefaults.standard.set(requiresWakeCheck, forKey: Self.wakeCheckRequiredKey(id))
        UserDefaults.standard.set(soundName, forKey: Self.soundKey(id))

        // Scheduling a real (non-Wake-Check) alarm is a genuinely fresh
        // start, not a re-alert continuation — reset the cycle counter so a
        // new morning's chain doesn't inherit yesterday's count. Mirrors
        // the equivalent reset in WakeSessionController.startSession().
        let numericId = Int(id.filter { $0.isNumber }) ?? 0
        if numericId < Self.wakeCheckIdOffset {
            UserDefaults.standard.removeObject(forKey: Self.wakeCheckCountKey(numericId))
        }

        Task {
            do {
                try await scheduleAlarmInternal(id: id, date: date, soundName: soundName)
                // Complete the Dart call as soon as the PRIMARY alarm is
                // scheduled — do not make the caller wait on the full
                // 30-entry chain. This same scheduleAlarm() path runs on
                // every app boot's reconcile pass for any recurring alarm
                // that needs advancing to its next occurrence, not just
                // fresh alarm creation, so awaiting all 30 sequential
                // native schedule() calls here was blocking app startup —
                // confirmed live as a grey/blank launch screen, and once as
                // an outright signal-9 kill (very likely iOS's launch
                // watchdog). The chain itself still fully schedules; it
                // just no longer blocks anything waiting on this callback.
                DispatchQueue.main.async { completion(nil) }
                // Chain prescheduling must ONLY ever happen for a genuinely
                // fresh, real user alarm id (numericId < wakeCheckIdOffset)
                // — never for a wake-check-derived id (the reactive slot,
                // >= wakeCheckIdOffset, or a chain entry, >=
                // wakeCheckChainIdBase). wakeCheckRequiredKey is still set
                // above for every id regardless — that part is correct and
                // needed so the reactive slot's OWN dismissal can still
                // reschedule itself via scheduleWakeCheckIfNeeded. But the
                // Dart-side reactive fallback re-schedules the reactive
                // slot on every single native stop of a mission alarm via
                // this exact scheduleAlarm() entry point with
                // requiresWakeCheck still true (since it copies the same
                // mission) — without this guard, EVERY one of those
                // re-schedules ALSO prescheduled an entire new 30-entry
                // chain keyed to the reactive slot's own id, not the real
                // original alarm's id. cancelWakeCheckChain(originalId)
                // only ever cancels the chain under the REAL original id,
                // so every one of these extra mis-keyed chains was
                // permanently orphaned and kept ringing on its own,
                // regardless of the mission ever being completed —
                // confirmed live, repeatedly, even on a completely fresh
                // install with no leftover state at all.
                if requiresWakeCheck && numericId < Self.wakeCheckIdOffset {
                    Task {
                        await self.scheduleWakeCheckChain(originalId: numericId, baseDate: date, soundName: soundName)
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
        }
    }

    /// Pre-schedules the full Wake Check chain (see comment above
    /// wakeCheckChainIdBase) up front, one independent native alarm per
    /// cycle, spaced wakeCheckIntervalSeconds apart starting after the
    /// primary alarm's fire time.
    fileprivate func scheduleWakeCheckChain(originalId: Int, baseDate: Date, soundName: String) async {
        for index in 1...Self.wakeCheckChainMaxEntries {
            let chainId = Self.wakeCheckChainAlarmId(originalId: originalId, index: index)
            let fireDate = baseDate.addingTimeInterval(Double(index) * Self.wakeCheckChainIntervalSeconds)
            do {
                try await scheduleAlarmInternal(id: chainId, date: fireDate, soundName: soundName)
            } catch {
                // Best-effort — a single failed slot doesn't invalidate the rest of the chain.
            }
        }
    }

    /// Cancels the "back half" of [originalId]'s chain (every index beyond
    /// [keepLiveTailCount]) while genuinely, actively solving the mission —
    /// so a fresh alert doesn't interrupt every ~20s while the user is
    /// actually engaged. Deliberately does NOT cancel the first
    /// [keepLiveTailCount] entries: those stay armed the whole time, so
    /// even a hard kill the instant this call returns still leaves
    /// something scheduled — the resume path (a Dart-side idle timer, or
    /// reacting to backgrounding) cannot be relied on to run before a kill,
    /// so the chain must never be left with literally nothing armed.
    /// Chain indices are already in chronological order by construction
    /// (index*intervalSeconds), so "keep the first N" is exactly "keep the
    /// N soonest-upcoming entries" without needing to query live state.
    public func pauseWakeCheckChain(originalId: Int, keepLiveTailCount: Int, completion: @escaping (Error?) -> Void) {
        guard keepLiveTailCount < Self.wakeCheckChainMaxEntries else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        Task {
            for index in (keepLiveTailCount + 1)...Self.wakeCheckChainMaxEntries {
                let chainId = Self.wakeCheckChainAlarmId(originalId: originalId, index: index)
                let uuid = getUUID(for: chainId)
                await stopAndCancel(uuid: uuid)
            }
            DispatchQueue.main.async { completion(nil) }
        }
    }

    /// Reschedules the "back half" of [originalId]'s chain (the part
    /// pauseWakeCheckChain cancelled) starting fresh from now — not from
    /// the original stale schedule, since real time has passed. Uses the
    /// same sound as the original alarm (looked up by [originalId]'s own
    /// soundKey, set once when the real alarm was first scheduled).
    public func resumeWakeCheckChain(originalId: Int, keepLiveTailCount: Int, completion: @escaping (Error?) -> Void) {
        guard keepLiveTailCount < Self.wakeCheckChainMaxEntries else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        guard let soundName = UserDefaults.standard.string(forKey: Self.soundKey(String(originalId))) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        Task {
            let now = Date()
            var relativeIndex = 1
            for index in (keepLiveTailCount + 1)...Self.wakeCheckChainMaxEntries {
                let chainId = Self.wakeCheckChainAlarmId(originalId: originalId, index: index)
                let fireDate = now.addingTimeInterval(Double(relativeIndex) * Self.wakeCheckChainIntervalSeconds)
                relativeIndex += 1
                do {
                    try await scheduleAlarmInternal(id: chainId, date: fireDate, soundName: soundName)
                } catch {
                    // Best-effort — a single failed slot doesn't invalidate the rest of the chain.
                }
            }
            DispatchQueue.main.async { completion(nil) }
        }
    }

    /// AlarmManager exposes `cancel(id:)` (removes a not-yet-fired scheduled
    /// alarm) and `stop(id:)` (dismisses one that's CURRENTLY alerting) as
    /// two entirely separate calls. Confirmed live: completing the mission
    /// only ever called cancel(), so whichever alarm in the family happened
    /// to be actively ringing at that exact moment (the original, the
    /// reactive Wake Check slot, or any chain entry) just kept ringing —
    /// cancel() has no effect on an alarm already in .alerting state. Since
    /// we don't know in advance which state a given id is in, every real
    /// cleanup call must try both, ignoring whichever one doesn't apply.
    private func stopAndCancel(uuid: UUID) async {
        try? await AlarmManager.shared.stop(id: uuid)
        try? await AlarmManager.shared.cancel(id: uuid)
    }

    /// Cancels every alarm in [originalId]'s pre-scheduled Wake Check
    /// chain — both not-yet-fired ones and, critically, whichever one is
    /// currently alerting. Called when the mission is actually completed
    /// (or emergency-escaped) so the chain doesn't keep ringing after the
    /// user has genuinely finished. Acting on an ID that already fired and
    /// cleared or doesn't exist is a harmless no-op.
    public func cancelWakeCheckChain(originalId: Int, completion: @escaping (Error?) -> Void) {
        Task {
            for index in 1...Self.wakeCheckChainMaxEntries {
                let chainId = Self.wakeCheckChainAlarmId(originalId: originalId, index: index)
                let uuid = getUUID(for: chainId)
                await stopAndCancel(uuid: uuid)
            }
            DispatchQueue.main.async { completion(nil) }
        }
    }

    /// Core AlarmKit scheduling call, shared by the public scheduleAlarm
    /// entry point and the native Wake Check re-alert scheduled from
    /// StopAlarmIntent.perform().
    @discardableResult
    fileprivate func scheduleAlarmInternal(id: String, date: Date, soundName: String) async throws -> Alarm {
        struct EmptyMetadata: AlarmMetadata {}

        let stopIntent = StopAlarmIntent(alarmId: id)
        let openIntent = OpenWakelyIntent(alarmId: id)
        let openWakelyButton = AlarmButton(
            text: "Open Wakely",
            textColor: .white,
            systemImageName: "arrow.up.forward.app"
        )
        let alert = AlarmPresentation.Alert(
            title: "Wakely Alarm",
            secondaryButton: openWakelyButton,
            secondaryButtonBehavior: .custom
        )
        let presentation = AlarmPresentation(alert: alert)

        let attributes = AlarmAttributes<EmptyMetadata>(
            presentation: presentation,
            metadata: EmptyMetadata(),
            tintColor: .blue
        )

        let config = AlarmManager.AlarmConfiguration<EmptyMetadata>.alarm(
            schedule: .fixed(date),
            attributes: attributes,
            stopIntent: stopIntent,
            secondaryIntent: openIntent,
            sound: .named(soundName)
        )

        let uuid = getUUID(for: id)

        if AlarmManager.shared.authorizationState == .notDetermined {
            let _ = try await AlarmManager.shared.requestAuthorization()
        }

        return try await AlarmManager.shared.schedule(id: uuid, configuration: config)
    }

    /// Called from StopAlarmIntent.perform() when a mission alarm's native
    /// Stop button is tapped. If the stopped alarm required a Wake Check,
    /// schedules the follow-up re-alert alarm natively — see the comment
    /// above wakeCheckRequiredKey for why this matters.
    ///
    /// Re-alerts on a short, fixed interval (not a multi-minute gap, which
    /// reads as a snooze) and reuses the same alarm slot every cycle, up to
    /// maxWakeCheckReAlerts — deliberately relentless, matching the product
    /// requirement that silencing the alarm without completing the mission
    /// must not actually make it stop, while still being bounded rather
    /// than literal unbounded spam.
    fileprivate func scheduleWakeCheckIfNeeded(forStoppedAlarmId alarmId: String) async {
        guard UserDefaults.standard.bool(forKey: Self.wakeCheckRequiredKey(alarmId)) else { return }

        let originalId = Self.originalAlarmId(for: alarmId)
        let countKey = Self.wakeCheckCountKey(originalId)
        let cycleCount = UserDefaults.standard.integer(forKey: countKey) + 1
        guard cycleCount <= Self.maxWakeCheckReAlerts else { return }
        UserDefaults.standard.set(cycleCount, forKey: countKey)

        let soundName = UserDefaults.standard.string(forKey: Self.soundKey(alarmId)) ?? "misogi77.wav"
        let wakeCheckId = Self.wakeCheckAlarmId(for: alarmId)
        // The re-alert alarm's own requiresWakeCheck flag: cascading is
        // controlled by the cycle counter above, not by whether this is
        // already a Wake Check id, so the next cycle can be scheduled too.
        UserDefaults.standard.set(true, forKey: Self.wakeCheckRequiredKey(wakeCheckId))
        UserDefaults.standard.set(soundName, forKey: Self.soundKey(wakeCheckId))
        let fireDate = Date().addingTimeInterval(Self.wakeCheckIntervalSeconds)
        do {
            try await scheduleAlarmInternal(id: wakeCheckId, date: fireDate, soundName: soundName)
        } catch {
            // Best-effort: the Dart-side fallback (if Flutter is alive) is
            // still in play even if this native attempt fails.
        }
    }
    
    public func cancelAlarm(id: String, completion: @escaping (Error?) -> Void) {
        let uuid = getUUID(for: id)
        Task {
            // See stopAndCancel's doc comment: cancel() alone does not
            // silence an alarm that's currently alerting, only one that's
            // still merely scheduled. This is the single general-purpose
            // cancel path used by every Dart-side deleteAlarm/completeAlarm
            // call, so fixing it here covers all of them, not just the
            // mission-completion flow specifically.
            await stopAndCancel(uuid: uuid)
            DispatchQueue.main.async { completion(nil) }
        }
    }
    
    public func notifyAlarmStopped(alarmId: String) {
        DispatchQueue.main.async {
            self.pendingAlarmInteraction = alarmId
            self.eventSink?(["type": "interaction", "alarmId": alarmId])
        }
    }

    public func notifyAlarmOpened(alarmId: String) {
        DispatchQueue.main.async {
            self.pendingAlarmInteraction = alarmId
            self.eventSink?(["type": "interactionOpenWakely", "alarmId": alarmId])
        }
    }
}

@available(iOS 26.1, *)
public struct StopAlarmIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Stop Wakely Alarm"
    
    @Parameter(title: "Alarm ID")
    public var alarmId: String
    
    public static var supportedModes: IntentModes = .foreground(.immediate)
    
    public init() {}
    
    public init(alarmId: String) {
        self.alarmId = alarmId
    }
    
    public func perform() async throws -> some IntentResult {
        WakelyAlarmKitManager.shared.notifyAlarmStopped(alarmId: alarmId)
        // Native stop does NOT complete the mission — it only silences this
        // alarm's presentation/audio. If this alarm required a Wake Check,
        // schedule the re-alert natively so it survives even if Flutter
        // never finishes booting before this intent returns.
        await WakelyAlarmKitManager.shared.scheduleWakeCheckIfNeeded(forStoppedAlarmId: alarmId)
        return .result()
    }
}

@available(iOS 26.1, *)
public struct OpenWakelyIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Open Wakely"
    
    @Parameter(title: "Alarm ID")
    public var alarmId: String
    
    public static var supportedModes: IntentModes = .foreground(.immediate)
    
    public init() {}
    
    public init(alarmId: String) {
        self.alarmId = alarmId
    }
    
    public func perform() async throws -> some IntentResult {
        WakelyAlarmKitManager.shared.notifyAlarmOpened(alarmId: alarmId)
        return .result()
    }
}

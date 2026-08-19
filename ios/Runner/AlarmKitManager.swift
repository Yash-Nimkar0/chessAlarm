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
                    // We map UUID back to the original string representation, assuming UUID was created from it
                    return [
                        "id": alarm.id.uuidString,
                        "state": "scheduled",
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
    
    public func scheduleAlarm(id: String, date: Date, soundName: String, completion: @escaping (Error?) -> Void) {
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
        
        Task {
            do {
                if AlarmManager.shared.authorizationState == .notDetermined {
                    let _ = try await AlarmManager.shared.requestAuthorization()
                }
                
                try await AlarmManager.shared.schedule(id: uuid, configuration: config)
                
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
        }
    }
    
    public func cancelAlarm(id: String, completion: @escaping (Error?) -> Void) {
        let uuid = getUUID(for: id)
        Task {
            do {
                try await AlarmManager.shared.cancel(id: uuid)
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
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

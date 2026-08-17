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
                    switch alarm.status {
                    case .scheduled: statusStr = "scheduled"
                    case .alerting: statusStr = "firing"
                    case .snoozed: statusStr = "snoozed"
                    case .completed: statusStr = "completed"
                    @unknown default: statusStr = "unknown"
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
    
    private func getUUID(for id: String) -> UUID {
        var str = id.replacingOccurrences(of: "[^a-fA-F0-9]", with: "", options: .regularExpression)
        if str.count < 32 {
            str = str.padding(toLength: 32, withPad: "0", startingAt: 0)
        }
        let formatted = "\(str.prefix(8))-\(str.dropFirst(8).prefix(4))-\(str.dropFirst(12).prefix(4))-\(str.dropFirst(16).prefix(4))-\(str.dropFirst(20).prefix(12))"
        return UUID(uuidString: formatted) ?? UUID()
    }
    
    public func scheduleAlarm(id: String, date: Date, soundName: String, completion: @escaping (Error?) -> Void) {
        struct EmptyMetadata: AlarmMetadata {}
        
        let stopIntent = StopAlarmIntent(alarmId: id)
        let alert = AlarmPresentation.Alert(title: "Wakely Alarm")
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
            secondaryIntent: nil,
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

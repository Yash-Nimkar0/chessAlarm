import Flutter
import UIKit
import alarm

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  
  private func registerAlarmKitChannels(messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(name: "wakely.alarmkit", binaryMessenger: messenger)
    let eventChannel = FlutterEventChannel(name: "wakely.alarmkit.events", binaryMessenger: messenger)
    
    if #available(iOS 26.1, *) {
        let manager = WakelyAlarmKitManager.shared
        eventChannel.setStreamHandler(manager)
        manager.startListeningToNativeStreams()
        
        methodChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "checkCapability":
                manager.checkCapability { res in result(res) }
            case "getPendingAlarmInteraction":
                result(manager.pendingAlarmInteraction)
                manager.pendingAlarmInteraction = nil // Clear after reading
            case "getScheduledAlarms":
                manager.getScheduledAlarms { res in result(res) }
            case "scheduleAlarm":
                if let args = call.arguments as? [String: Any],
                   let id = args["id"] as? String,
                   let fireTime = args["fireTime"] as? Double,
                   let soundName = args["soundName"] as? String {
                    let date = Date(timeIntervalSince1970: fireTime / 1000.0)
                    let requiresWakeCheck = args["requiresWakeCheck"] as? Bool ?? false
                    manager.scheduleAlarm(id: id, date: date, soundName: soundName, requiresWakeCheck: requiresWakeCheck) { error in
                        if let error = error {
                            result(FlutterError(code: "SCHEDULE_ERROR", message: error.localizedDescription, details: nil))
                        } else {
                            result(true)
                        }
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                }
            case "cancelAlarm":
                if let args = call.arguments as? [String: Any], let id = args["id"] as? String {
                    manager.cancelAlarm(id: id) { error in
                        if let error = error {
                            result(FlutterError(code: "CANCEL_ERROR", message: error.localizedDescription, details: nil))
                        } else {
                            result(true)
                        }
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    } else {
        methodChannel.setMethodCallHandler { (call, result) in
            if call.method == "checkCapability" {
                result(["supported": false, "authorization": "unsupported"])
            } else {
                result(FlutterError(code: "UNSUPPORTED_OS", message: "AlarmKit requires iOS 26.1+", details: nil))
            }
        }
    }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    SwiftAlarmPlugin.registerBackgroundTasks()
    
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    if let controller = window?.rootViewController as? FlutterViewController {
        registerAlarmKitChannels(messenger: controller.binaryMessenger)
    }
    
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    
    // Register channels for the implicit engine
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WakelyAlarmKit") {
        registerAlarmKitChannels(messenger: registrar.messenger())
    }
  }
}

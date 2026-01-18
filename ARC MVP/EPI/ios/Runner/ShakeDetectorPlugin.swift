import Flutter
import UIKit

/// Native iOS shake detection plugin
/// Includes cooldown to prevent false positives from minor movements
class ShakeDetectorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    
    /// Cooldown period in seconds between shake detections
    /// Prevents false triggers from placing phone on desk, etc.
    private let shakeCooldownSeconds: TimeInterval = 3.0
    
    /// Last time a shake was detected
    private var lastShakeTime: Date?
    
    /// Whether shake detection is currently in cooldown
    private var isInCooldown: Bool {
        guard let lastShake = lastShakeTime else { return false }
        return Date().timeIntervalSince(lastShake) < shakeCooldownSeconds
    }
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "com.epi.arcmvp/shake_detector",
            binaryMessenger: registrar.messenger()
        )
        
        let eventChannel = FlutterEventChannel(
            name: "com.epi.arcmvp/shake_events",
            binaryMessenger: registrar.messenger()
        )
        
        let instance = ShakeDetectorPlugin()
        methodChannel.setMethodCallHandler(instance.handle)
        eventChannel.setStreamHandler(instance)
        
        // Register for shake notifications
        NotificationCenter.default.addObserver(
            instance,
            selector: #selector(deviceDidShake),
            name: UIDevice.deviceDidShakeNotification,
            object: nil
        )
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(true)
        case "resetCooldown":
            lastShakeTime = nil
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    @objc private func deviceDidShake() {
        // Skip if in cooldown period
        guard !isInCooldown else {
            print("ShakeDetector: Shake ignored (cooldown active)")
            return
        }
        
        // Record this shake time
        lastShakeTime = Date()
        
        // Send event to Flutter
        eventSink?("shake")
        print("ShakeDetector: Shake detected and sent to Flutter")
    }
}

// Extension to detect shake motion
extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

// Custom window to detect shake gestures
// Uses motionBegan + motionEnded pattern for more deliberate shake detection
class ShakeDetectingWindow: UIWindow {
    /// Track if motion began (for requiring deliberate shake)
    private var motionDidBegin = false
    
    /// Minimum duration the shake motion should last (in seconds)
    /// This filters out brief bumps from placing phone on desk
    private let minimumShakeDuration: TimeInterval = 0.3
    
    /// Time when motion began
    private var motionBeganTime: Date?
    
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            motionDidBegin = true
            motionBeganTime = Date()
        }
        super.motionBegan(motion, with: event)
    }
    
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake && motionDidBegin {
            // Check if the shake was long enough to be intentional
            if let beganTime = motionBeganTime {
                let shakeDuration = Date().timeIntervalSince(beganTime)
                if shakeDuration >= minimumShakeDuration {
                    NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
                    print("ShakeDetector: Intentional shake detected (duration: \(String(format: "%.2f", shakeDuration))s)")
                } else {
                    print("ShakeDetector: Shake too brief (\(String(format: "%.2f", shakeDuration))s), ignoring")
                }
            }
            motionDidBegin = false
            motionBeganTime = nil
        }
        super.motionEnded(motion, with: event)
    }
    
    override func motionCancelled(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        motionDidBegin = false
        motionBeganTime = nil
        super.motionCancelled(motion, with: event)
    }
}


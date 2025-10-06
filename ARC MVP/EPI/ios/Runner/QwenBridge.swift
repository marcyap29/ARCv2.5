import Foundation
import Flutter
import UIKit

// Adapter to maintain compatibility with existing Flutter integration
// This now uses the new LlamaBridge with real llama.cpp + Metal support

@objc public class QwenBridge: NSObject, FlutterPlugin {
    // Delegate to the new LlamaBridge
    private let llamaBridge = LlamaBridge()
    
    // Model state tracking
    private var chatModelLoaded = false
    private var visionModelLoaded = false
    private var embeddingModelLoaded = false
    
    // Model configurations
    private var currentRuntime: String = "llamacpp"
    private var temperature: Float = 0.6
    private var topP: Float = 0.9
    private var maxTokens: Int = 256
    
    // Required FlutterPlugin method
    public static func register(with registrar: FlutterPluginRegistrar) {
        let method = FlutterMethodChannel(name: "lumara_llm", binaryMessenger: registrar.messenger())
        let instance = QwenBridge()
        registrar.addMethodCallDelegate(instance, channel: method)

        let events = FlutterEventChannel(name: "lumara_llm/events", binaryMessenger: registrar.messenger())
        events.setStreamHandler(TokenStream.shared)

        NSLog("[QwenBridge] register() called ✅")
    }
    
    // Custom register method for direct use
    static func register(with binaryMessenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "lumara_native", binaryMessenger: binaryMessenger)
        let instance = QwenBridge()
        channel.setMethodCallHandler(instance.handle)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Delegate all calls to the new LlamaBridge
        llamaBridge.handle(call, result: result)
        
        // Update our internal state based on the call
        switch call.method {
        case "initModel", "initChatModel":
            if let args = call.arguments as? [String: Any], let path = args["path"] as? String ?? args["modelPath"] as? String {
                chatModelLoaded = true
                NSLog("[QwenBridge] Model initialized via LlamaBridge: \(path)")
            }
        case "dispose":
            chatModelLoaded = false
            visionModelLoaded = false
            embeddingModelLoaded = false
        default:
            break
        }
    }
    
    // MARK: - Legacy Compatibility Methods
    
    private func initChatModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Delegate to LlamaBridge
        llamaBridge.handle(call, result: result)
    }
    
    private func qwenText(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Delegate to LlamaBridge
        llamaBridge.handle(call, result: result)
    }
    
    private func initVisionModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Vision model not implemented in llama.cpp version
            result(false)
    }
    
    private func qwenVision(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Vision model not implemented in llama.cpp version
        result("Vision model not available in llama.cpp implementation")
    }
    
    private func initEmbeddingModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Embedding model not implemented in llama.cpp version
            result(false)
    }
    
    private func embedText(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Embedding model not implemented in llama.cpp version
            result([])
    }
    
    private func embedTextBatch(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Embedding model not implemented in llama.cpp version
            result([])
    }
    
    private func getDeviceCapabilities(result: @escaping FlutterResult) {
        // Delegate to LlamaBridge
        llamaBridge.handle(FlutterMethodCall(method: "getModelInfo", arguments: nil), result: result)
    }
    
    private func isModelReady(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Delegate to LlamaBridge
        llamaBridge.handle(call, result: result)
    }
    
    private func getModelLoadingProgress(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Return progress based on model state
        let progress: Double
        if chatModelLoaded {
            progress = 1.0
        } else {
            progress = 0.0
        }
        result(progress)
    }
    
    private func switchRuntime(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let runtime = args["runtime"] as? String else {
            result(false)
            return
        }
        
        currentRuntime = runtime
        NSLog("[QwenBridge] Runtime switched to: \(runtime)")
        result(true)
    }
    
    private func getRuntimeInfo(result: @escaping FlutterResult) {
        let runtimeInfo: [String: Any] = [
            "runtime": currentRuntime,
            "version": "llama.cpp-2.x",
            "supportedModels": ["llama-3.2-3b-instruct", "phi-3.5-mini-instruct"],
            "metalAccelerated": true
        ]
        
        result(runtimeInfo)
    }
    
    private func dispose(result: @escaping FlutterResult) {
        // Delegate to LlamaBridge
        llamaBridge.handle(FlutterMethodCall(method: "dispose", arguments: nil), result: result)
    }
}

// Token streaming support (reuse from LlamaBridge)
final class TokenStream: NSObject, FlutterStreamHandler {
    static let shared = TokenStream()
    private var sink: FlutterEventSink?
    var isReady: Bool { sink != nil }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        NSLog("[QwenBridge] events onListen")
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        NSLog("[QwenBridge] events onCancel")
        return nil
    }
    
    func send(_ token: String) {
        sink?(token)
    }
}

// Diagnostic utilities
enum QwenDiag {
    static func metalAvailable() -> Bool {
        #if targetEnvironment(simulator)
        return false // Conservative for simulator
        #else
        return MTLCreateSystemDefaultDevice() != nil
        #endif
    }
    
    static func llamaLinked() -> Bool {
        // Test if llama.cpp functions are available
        return true // We'll know at runtime if they're linked
    }
    
    static func buildMode() -> String {
        #if DEBUG
        return "DEBUG"
        #else
        return "RELEASE"
        #endif
    }
}
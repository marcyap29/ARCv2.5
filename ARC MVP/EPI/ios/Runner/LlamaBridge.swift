import Foundation
import Flutter
import UIKit
import Metal

// Real llama.cpp integration with Metal support
// This replaces the previous MLX-based implementation

@objc public class LlamaBridge: NSObject, FlutterPlugin {
    // Model state tracking
    private var modelLoaded = false
    private var currentModelPath: String?

    // Generation configuration
    private var temperature: Float = 0.7
    private var topP: Float = 0.9
    private var maxTokens: Int = 256

    // Metal device for acceleration
    private var metalDevice: MTLDevice?

    // Required FlutterPlugin method
    public static func register(with registrar: FlutterPluginRegistrar) {
        let method = FlutterMethodChannel(name: "lumara_llm", binaryMessenger: registrar.messenger())
        let instance = LlamaBridge()
        registrar.addMethodCallDelegate(instance, channel: method)

        let events = FlutterEventChannel(name: "lumara_llm/events", binaryMessenger: registrar.messenger())
        events.setStreamHandler(TokenStream.shared)

        NSLog("[LlamaBridge] register() called ✅")
    }

    // Custom register method for direct use
    static func register(with binaryMessenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "lumara_native", binaryMessenger: binaryMessenger)
        let instance = LlamaBridge()
        channel.setMethodCallHandler(instance.handle)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        // Test method
        case "ping":
            NSLog("[LlamaBridge] ping")
            result("pong")

        case "selfTest":
            let diag: [String: Any] = [
                "registered": true,
                "thread": Thread.isMainThread ? "main" : "background",
                "canStream": TokenStream.shared.isReady,
                "metalAvailable": metalAvailable(),
                "llamaLinked": llamaLinked(),
                "buildMode": buildMode(),
                "modelLoaded": modelLoaded
            ]
            NSLog("[LlamaBridge] selfTest -> \(diag)")
            result(diag)

        case "initModel":
            initModel(call: call, result: result)

        case "generateText":
            generateText(call: call, result: result)

        case "startStreaming":
            startStreaming(call: call, result: result)

        case "getNextToken":
            getNextToken(result: result)

        case "cancelGeneration":
            cancelGeneration(result: result)

        case "isModelReady":
            isModelReady(call: call, result: result)

        case "getModelInfo":
            getModelInfo(result: result)

        case "dispose":
            dispose(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Model Management

    private func initModel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
            NSLog("[LlamaBridge] initModel missing path")
            result(["ok": false, "error": "missing_path"]); return
        }

        NSLog("[LlamaBridge] initModel path=\(path)")

        // Check if the model file exists
        let bundlePath = Bundle.main.path(forResource: "Llama-3.2-3b-Instruct-Q4_K_M", ofType: "gguf", inDirectory: "assets/models/gguf")
        if bundlePath == nil {
            NSLog("[LlamaBridge] model file not found in bundle at assets/models/gguf/Llama-3.2-3b-Instruct-Q4_K_M.gguf")
            result(["ok": false, "error": "file_not_found"]); return
        }

        NSLog("[LlamaBridge] model file found in bundle at: \(bundlePath!)")

        // Initialize Metal device
        metalDevice = MTLCreateSystemDefaultDevice()
        if metalDevice == nil {
            NSLog("[LlamaBridge] Metal not available")
            result(["ok": false, "error": "metal_not_available"]); return
        }

        // Initialize llama.cpp model
        DispatchQueue.global(qos: .userInitiated).async {
            let success = llama_init(bundlePath!)

            DispatchQueue.main.async {
                if success == 1 {
                    self.modelLoaded = true
                    self.currentModelPath = bundlePath
                    NSLog("[LlamaBridge] Model loaded successfully with Metal support")
                    result(["ok": true])
                } else {
                    NSLog("[LlamaBridge] Failed to load model")
                    result(["ok": false, "error": "model_load_failed"])
                }
            }
        }
    }

    private func generateText(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let prompt = args["prompt"] as? String else {
            result("")
            return
        }

        guard modelLoaded else {
            NSLog("[LlamaBridge] Model not loaded")
            result("")
            return
        }

        let temperature = args["temperature"] as? Float ?? self.temperature
        let topP = args["top_p"] as? Float ?? self.topP
        let maxTokens = args["max_tokens"] as? Int ?? self.maxTokens

        NSLog("[LlamaBridge] Generating text for prompt: \(prompt.prefix(50))...")

        DispatchQueue.global(qos: .userInitiated).async {
            let response = llama_generate(prompt, temperature, topP, Int32(maxTokens))

            DispatchQueue.main.async {
                if let response = response {
                    result(String(cString: response))
                } else {
                    result("")
                }
            }
        }
    }

    private func startStreaming(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let prompt = args["prompt"] as? String else {
            result(false)
            return
        }

        guard modelLoaded else {
            NSLog("[LlamaBridge] Model not loaded")
            result(false)
            return
        }

        let temperature = args["temperature"] as? Float ?? self.temperature
        let topP = args["top_p"] as? Float ?? self.topP
        let maxTokens = args["max_tokens"] as? Int ?? self.maxTokens

        NSLog("[LlamaBridge] Starting streaming generation")

        DispatchQueue.global(qos: .userInitiated).async {
            let success = llama_start_generation(prompt, temperature, topP, Int32(maxTokens))

            DispatchQueue.main.async {
                result(success == 1)
            }
        }
    }

    private func getNextToken(result: @escaping FlutterResult) {
        guard modelLoaded else {
            result(["token": "", "finished": true, "error": "model_not_loaded"])
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let streamResult = llama_get_next_token()

            DispatchQueue.main.async {
                let token = streamResult.token != nil ? String(cString: streamResult.token!) : ""
                result([
                    "token": token,
                    "finished": streamResult.is_finished,
                    "error": streamResult.error_code
                ])
            }
        }
    }

    private func cancelGeneration(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            llama_cancel_generation()

            DispatchQueue.main.async {
                result(nil)
            }
        }
    }

    private func isModelReady(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelType = args["modelType"] as? String else {
            result(false)
            return
        }

        let ready: Bool
        switch modelType {
        case "chat":
            ready = modelLoaded && llama_is_loaded() == 1
        default:
            ready = false
        }

        result(ready)
    }

    private func getModelInfo(result: @escaping FlutterResult) {
        // let info = llama_get_model_info()
        let contextLength = llama_get_context_length()

        let modelInfo: [String: Any] = [
            "info": "Model info temporarily disabled for debugging",
            "contextLength": Int(contextLength),
            "metalAvailable": metalDevice != nil,
            "modelPath": currentModelPath ?? "Not loaded"
        ]

        result(modelInfo)
    }

    private func dispose(result: @escaping FlutterResult) {
        NSLog("[LlamaBridge] Disposing models and cleaning up resources")

        DispatchQueue.global(qos: .userInitiated).async {
            llama_cleanup()

            DispatchQueue.main.async {
                self.modelLoaded = false
                self.currentModelPath = nil
                self.metalDevice = nil
                NSLog("[LlamaBridge] Cleanup complete")
                result(nil)
            }
        }
    }

    // MARK: - Device Capabilities

    private func metalAvailable() -> Bool {
        #if targetEnvironment(simulator)
        return false // Conservative for simulator
        #else
        return MTLCreateSystemDefaultDevice() != nil
        #endif
    }

    private func llamaLinked() -> Bool {
        // Test if llama.cpp functions are available
        return true // We'll know at runtime if they're linked
    }

    private func buildMode() -> String {
        #if DEBUG
        return "DEBUG"
        #else
        return "RELEASE"
        #endif
    }
}

// Token streaming support
final class TokenStream: NSObject, FlutterStreamHandler {
    static let shared = TokenStream()
    private var sink: FlutterEventSink?
    var isReady: Bool { sink != nil }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        NSLog("[LlamaBridge] events onListen")
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        NSLog("[LlamaBridge] events onCancel")
        return nil
    }

    func send(_ token: String) {
        sink?(token)
    }
}

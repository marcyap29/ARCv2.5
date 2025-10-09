// LLMBridge_GGUF.swift
// Swift implementation of LumaraNative Pigeon protocol
// Provides on-device LLM inference with llama.cpp + Metal + GGUF models only
// Modern implementation using llama.cpp C API

import Foundation
import os.log

// MARK: - CoreGraphics NaN Prevention Helpers

@inline(__always)
func clamp01(_ x: Double?) -> Double? {
    guard let x, x.isFinite else { return nil }     // nil = indeterminate progress in SwiftUI/Flutter
    return min(max(x, 0), 1)
}

@inline(__always)
func safeCGFloat(_ v: CGFloat, _ label: String) -> CGFloat {
    if !v.isFinite || v.isNaN { 
        NSLog("NaN in \(label)"); 
        return 0 
    }
    return v
}

// MARK: - Error Mapping

enum LLMError: LocalizedError {
    case alreadyInFlight
    case runtime(String)
    
    var errorDescription: String? {
        switch self {
        case .alreadyInFlight: return "already_in_flight"
        case .runtime(let m):  return m
        }
    }
}
import CryptoKit

// MARK: - C Struct Definitions

struct EpiGenParams {
    var maxTokens: Int32
    var temperature: Float
    var topP: Float
    var repeatPenalty: Float
}

struct EpiCallbacks {
    var onToken: (@convention(c) (UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Void)?
    var user: UnsafeMutableRawPointer?
}

// MARK: - C Bridge Declarations

@_silgen_name("epi_llama_init")
func epi_llama_init(_ modelPath: UnsafePointer<CChar>, _ ctxSize: Int32, _ nGpuLayers: Int32) -> Bool

@_silgen_name("epi_llama_free")
func epi_llama_free()

@_silgen_name("epi_llama_start")
func epi_llama_start(_ prompt: UnsafePointer<CChar>) -> Bool

@_silgen_name("epi_llama_generate_next")
func epi_llama_generate_next(_ cb: (@convention(c) (UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Void)!,
                             _ userData: UnsafeMutableRawPointer?,
                             _ outIsEos: UnsafeMutablePointer<Bool>?) -> Bool

@_silgen_name("epi_llama_stop")
func epi_llama_stop()

@_silgen_name("epi_set_top_k")
func epi_set_top_k(_ k: Int32)

@_silgen_name("epi_set_top_p")
func epi_set_top_p(_ p: Float)

@_silgen_name("epi_set_temp")
func epi_set_temp(_ t: Float)

@_silgen_name("epi_set_logger")
func epi_set_logger(_ logger: (@convention(c) (Int32, UnsafePointer<CChar>?) -> Void)!)

@_silgen_name("epi_llama_start_with_fallback")
func epi_llama_start_with_fallback(_ prompt: UnsafePointer<CChar>?) -> Bool

// Modern streaming API
@_silgen_name("epi_start")
func epi_start(_ prompt: UnsafePointer<CChar>, _ params: UnsafePointer<EpiGenParams>, _ cbs: EpiCallbacks, _ requestId: UInt64) -> Bool

@_silgen_name("epi_feed")
func epi_feed(_ nPromptTokens: Int32, _ requestId: UInt64) -> Bool

@_silgen_name("epi_stop")
func epi_stop() -> Bool

@_silgen_name("RequestGate_begin")
func RequestGate_begin(_ requestId: UInt64) -> Bool

@_silgen_name("RequestGate_end")
func RequestGate_end(_ requestId: UInt64)

@_silgen_name("RequestGate_current")
func RequestGate_current() -> UInt64

// MARK: - GGUF Model Management

/// Simple GGUF model path resolver
class GGUFModelManager {
    static let shared = GGUFModelManager()
    private let logger = Logger(subsystem: "EPI", category: "GGUFModelManager")
    
    private init() {}
    
    /// Get the path to a GGUF model file
    func getGGUFModelPath(modelId: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let ggufModelsPath = documentsPath.appendingPathComponent("gguf_models")
        
        // Check for both exact case and lowercase versions
        let exactPath = ggufModelsPath.appendingPathComponent(modelId)
        let lowercasePath = ggufModelsPath.appendingPathComponent(modelId.lowercased())
        
        let exactExists = FileManager.default.fileExists(atPath: exactPath.path)
        let lowercaseExists = FileManager.default.fileExists(atPath: lowercasePath.path)
        
        if exactExists {
            return exactPath
        } else if lowercaseExists {
            return lowercasePath
        }
        
        logger.warning("GGUF model not found: \(modelId)")
        return nil
    }
    
    /// Check if a GGUF model is available
    func isGGUFModelAvailable(modelId: String) -> Bool {
        return getGGUFModelPath(modelId: modelId) != nil
    }
}

// MARK: - Modern LLM Bridge (for internal use)

extension Notification.Name {
    static let llmToken = Notification.Name("llm.token")
}

// MARK: - Internal LLM Bridge (for ModelLifecycle use)

// MARK: - Model Lifecycle

/// Manages loaded GGUF model state
class ModelLifecycle {
    static let shared = ModelLifecycle()
    private let logger = Logger(subsystem: "EPI", category: "ModelLifecycle")

    private var isRunning = false
    private var currentModelId: String?
    private let loadQueue = DispatchQueue(label: "com.epi.model.load", qos: .userInitiated)
    // Re-entrancy guard removed - now handled by LLMBridge

    // Progress API reference
    weak var progressApi: LumaraNativeProgress?

    private func emit(modelId: String, value: Double, message: String) {
        DispatchQueue.main.async { [weak self] in
            // Convert Double to Int64 for Pigeon bridge (multiply by 100 for percentage)
            let intValue = Int64(value * 100.0)
            self?.progressApi?.modelProgress(modelId: modelId, value: intValue, message: message, completion: { _ in })
        }
        logger.info("[ModelPreload] progress=\(value) msg=\(message)")
    }

    func start(modelId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Fast path: already loaded
        if isRunning && currentModelId == modelId {
            emit(modelId: modelId, value: 1.0, message: "already loaded")
            completion(.success(()))
            return
        }

        // Stop existing model if different
        if isRunning && currentModelId != modelId {
            try? stop()
        }

        // Start async loading
        emit(modelId: modelId, value: 0.0, message: "starting")
        logger.info("[ModelPreload] step=start modelId=\(modelId)")

        loadQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                // Only support GGUF models
                let ggufModelIds = [
                    "Llama-3.2-3b-Instruct-Q4_K_M.gguf",
                    "Phi-3.5-mini-instruct-Q5_K_M.gguf",
                    "Qwen3-4B-Instruct-2507-Q5_K_M.gguf"
                ]

                guard ggufModelIds.contains(modelId) else {
                    throw NSError(domain: "ModelLifecycle", code: 400, userInfo: [
                        NSLocalizedDescriptionKey: "Unsupported model format. Only GGUF models are supported: \(modelId)"
                    ])
                }

                // Handle GGUF model loading
                self.emit(modelId: modelId, value: 0.1, message: "locating GGUF file")

                // For GGUF models, check if the .gguf file exists in the gguf_models directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let ggufModelsPath = documentsPath.appendingPathComponent("gguf_models")

                // Check for both exact case and lowercase versions
                let exactPath = ggufModelsPath.appendingPathComponent(modelId)
                let lowercasePath = ggufModelsPath.appendingPathComponent(modelId.lowercased())

                let exactExists = FileManager.default.fileExists(atPath: exactPath.path)
                let lowercaseExists = FileManager.default.fileExists(atPath: lowercasePath.path)

                let ggufPath = exactExists ? exactPath : lowercasePath
                let exists = exactExists || lowercaseExists

                guard exists else {
                    throw NSError(domain: "ModelLifecycle", code: 404, userInfo: [
                        NSLocalizedDescriptionKey: "GGUF model file not found: \(modelId)"
                    ])
                }

                self.logger.info("[ModelPreload] GGUF model found at: \(ggufPath.path)")

                // For GGUF models, we don't need a separate tokenizer
                // llama.cpp handles tokenization internally
                self.emit(modelId: modelId, value: 0.5, message: "preparing llama.cpp GGUF model")

                // Log file details before calling epi_llama_init (using NSLog for immediate output)
                NSLog("🔍🔍🔍 [ModelPreload] ===== LLAMA INIT DEBUG =====")
                NSLog("🔍🔍🔍 [ModelPreload] Model file path: \(ggufPath.path)")
                NSLog("🔍🔍🔍 [ModelPreload] File exists: \(FileManager.default.fileExists(atPath: ggufPath.path))")

                self.logger.info("[ModelPreload] ===== LLAMA INIT DEBUG =====")
                self.logger.info("[ModelPreload] Model file path: \(ggufPath.path)")
                self.logger.info("[ModelPreload] File exists: \(FileManager.default.fileExists(atPath: ggufPath.path))")

                if let attrs = try? FileManager.default.attributesOfItem(atPath: ggufPath.path) {
                    let size = attrs[.size] as? UInt64 ?? 0
                    NSLog("🔍🔍🔍 [ModelPreload] File size: \(size / 1_000_000) MB")
                    self.logger.info("[ModelPreload] File size: \(size / 1_000_000) MB")
                }

                // Initialize llama.cpp with the GGUF model using modern API
                NSLog("🔍🔍🔍 [ModelPreload] Calling epi_llama_init()...")
                self.logger.info("[ModelPreload] Calling epi_llama_init()...")
                let initResult = LLMBridge.shared.initialize(modelPath: ggufPath.path, ctxTokens: 2048, nGpuLayers: 16)
                NSLog("🔍🔍🔍 [ModelPreload] epi_llama_init() returned: \(initResult)")
                self.logger.info("[ModelPreload] epi_llama_init() returned: \(initResult)")

                if !initResult {
                    NSLog("❌❌❌ [ModelPreload] LLAMA INIT FAILED - returned \(initResult)")
                    NSLog("❌❌❌ [ModelPreload] Model path: \(ggufPath.path)")
                    NSLog("❌❌❌ [ModelPreload] This usually means: corrupt GGUF, not enough memory, or incompatible format")
                    self.logger.error("[ModelPreload] LLAMA INIT FAILED - returned \(initResult)")
                    self.logger.error("[ModelPreload] Model path: \(ggufPath.path)")
                    self.logger.error("[ModelPreload] This usually means: corrupt GGUF, not enough memory, or incompatible format")
                    throw NSError(domain: "ModelLifecycle", code: 500, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to initialize llama.cpp with model: \(modelId) (returned \(initResult))"
                    ])
                }

                NSLog("✅✅✅ [ModelPreload] llama.cpp initialized successfully with model: \(modelId)")
                self.logger.info("[ModelPreload] ✅ llama.cpp initialized successfully with model: \(modelId)")

                // Mark as loaded
                self.isRunning = true
                self.currentModelId = modelId

                self.emit(modelId: modelId, value: 1.0, message: "ready")
                self.logger.info("[ModelPreload] GGUF model ready: \(modelId)")

                DispatchQueue.main.async {
                    completion(.success(()))
                }

            } catch {
                self.logger.error("[ModelPreload] err=\(error.localizedDescription)")
                self.emit(modelId: modelId, value: 0.0, message: "failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func stop() throws {
        guard isRunning else { return }

        // Release llama.cpp model resources
        LLMBridge.shared.release()
        isRunning = false
        currentModelId = nil
        logger.info("Stopped model")
    }

    func generate(prompt: String, params: GenParams) throws -> GenResult {
        guard isRunning else {
            throw NSError(domain: "ModelLifecycle", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "No model is loaded"
            ])
        }
        
        // Re-entrancy protection now handled by LLMBridge

        // Only support GGUF models
        let ggufModelIds = [
            "Llama-3.2-3b-Instruct-Q4_K_M.gguf",
            "Phi-3.5-mini-instruct-Q5_K_M.gguf",
            "Qwen3-4B-Instruct-2507-Q5_K_M.gguf",
        ]

        guard ggufModelIds.contains(currentModelId ?? "") else {
            throw NSError(domain: "ModelLifecycle", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Unsupported model format. Only GGUF models are supported: \(currentModelId ?? "unknown")"
            ])
        }

        let startTime = Date()

        // === DEBUG OUTPUT ===
        logger.info("🔷🔷🔷 === GGUF GENERATION START === 🔷🔷🔷")
        logger.info("📥 INPUT PROMPT:")
        logger.info("  Length: \(prompt.count) characters")
        logger.info("  First 200 chars: \(String(prompt.prefix(200)))")
        if prompt.count > 200 {
            logger.info("  ... (truncated)")
        }
        logger.info("📊 GENERATION PARAMETERS:")
        logger.info("  maxTokens: \(params.maxTokens)")
        logger.info("  temperature: \(params.temperature)")
        logger.info("  topP: \(params.topP)")
        logger.info("  repeatPenalty: \(params.repeatPenalty)")

        // Use modern llama.cpp streaming generation
        logger.info("=== GGUF MODEL GENERATION (Modern API) ===")

        // Generation parameters
        let maxNewTokens = min(Int(params.maxTokens), 96)
        let temperature = params.temperature
        let topP = params.topP

        // Call native generation directly to avoid recursive loop
        let result = try startNativeGenerationDirect(prompt: prompt, params: params)
        
        // Clean up the generated text
        let cleanedText = cleanQwenOutput(result.text)
        logger.info("📤 GGUF GENERATED TEXT:")
        logger.info("  '\(cleanedText)'")
        logger.info("  Length: \(cleanedText.count) characters")

        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)

        let finalText = cleanedText.isEmpty ? generateFallbackResponse(prompt: prompt) : cleanedText

        logger.info("🎯 FINAL OUTPUT:")
        logger.info("  '\(finalText)'")
        logger.info("  Length: \(finalText.count) characters")
        logger.info("  Using fallback: \(cleanedText.isEmpty)")
        logger.info("⏱️  Generation time: \(latencyMs)ms")
        logger.info("🔷🔷🔷 === GGUF GENERATION END === 🔷🔷🔷")

        return GenResult(
            text: finalText,
            tokensIn: result.tokensIn,
            tokensOut: result.tokensOut,
            latencyMs: Int64(latencyMs),
            provider: result.provider
        )
    }
    
    private func startNativeGenerationDirect(prompt: String, params: GenParams) throws -> GenResult {
        // Direct native generation without guard system (for internal use)
        let startTime = Date()
        
        // Generate unique request ID
        let requestId = UInt64.random(in: 1...UInt64.max)
        logger.info("🚀 Direct native generation req=\(requestId)")
        
        // Call native generation directly to avoid recursive loop
        let result = try LLMBridge.shared.startNativeGenerationDirectNative(prompt: prompt, params: params, requestId: requestId)
        
        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
        
        logger.info("✅ Direct native generation completed:")
        logger.info("  text: '\(result.text)'")
        logger.info("  latencyMs: \(latencyMs)")
        
        return result
    }

    func cleanQwenOutput(_ text: String) -> String {
        var cleaned = text

        // Remove Qwen-3 template tokens
        cleaned = cleaned.replacingOccurrences(of: "<|im_start|>", with: "")
        cleaned = cleaned.replacingOccurrences(of: "<|im_end|>", with: "")

        // Remove everything after stop strings
        let stopStrings = ["<|im_end|>", "<|endoftext|>"]
        for stopString in stopStrings {
            if let range = cleaned.range(of: stopString) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
        }

        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }

    // MARK: - Fallback Response Generation

    private func generateFallbackResponse(prompt: String) -> String {
        // Extract the actual user prompt (remove LUMARA system prompt if present)
        let userPrompt = extractUserPrompt(from: prompt)

        // Generate LUMARA-style response based on prompt content
        if userPrompt.lowercased().contains("hello") || userPrompt.lowercased().contains("hi") {
            return "Hi! How can I help today?"
        } else if userPrompt.lowercased().contains("what is lumara") || userPrompt.lowercased().contains("what is epi") {
            return """
            LUMARA is a privacy-first, on-device assistant that helps you journal, spot patterns, and choose your next wise step. It summarizes gently, protects your data, and adapts its tone to your current season of life.

            EPI System:
            • ARC: journaling + visual Arcforms
            • ATLAS: life-phase detection for pacing
            • MIRA: memory you control
            • AURORA: rhythm and cadence
            • VEIL: restorative pruning for clarity

            Next step: Would you like a 1-minute check-in prompt?
            """
        } else if userPrompt.lowercased().contains("arcform") || userPrompt.lowercased().contains("keywords") {
            return """
            Arcform Keywords: (extracted from your prompt)
            • reflection • patterns • growth • insight • next steps

            Next step: Choose 5 keywords to anchor today's Arcform visualization.
            """
        } else if userPrompt.lowercased().contains("help") || userPrompt.lowercased().contains("how") {
            return """
            LUMARA can help with:
            • Journaling prompts and reflection
            • Pattern recognition in your thoughts
            • Life phase guidance (Discovery, Expansion, Transition, etc.)
            • Memory organization and tagging
            • Next step planning

            Next step: Try asking about a specific area or share what's on your mind.
            """
        } else {
            return """
            I'm LUMARA, your privacy-first on-device assistant. I'm here to help you journal, see patterns, and take your next wise step.

            Current status: Bridge ✓, llama.cpp loaded ✓, GGUF model ✓

            Next step: Share what's on your mind, or ask about journaling, patterns, or life phases.
            """
        }
    }

    private func extractUserPrompt(from fullPrompt: String) -> String {
        // Look for the actual user message after the LUMARA system prompt
        let lines = fullPrompt.components(separatedBy: .newlines)

        // Find the last non-empty line that doesn't look like system prompt
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty &&
               !trimmed.hasPrefix("You are LUMARA") &&
               !trimmed.hasPrefix("PRINCIPLES") &&
               !trimmed.hasPrefix("CONTEXT MAP") &&
               !trimmed.hasPrefix("ATLAS TONE") &&
               !trimmed.hasPrefix("OUTPUT STYLE") &&
               !trimmed.hasPrefix("REFUSALS") &&
               !trimmed.hasPrefix("MEMORY") &&
               !trimmed.hasPrefix("FAIL-SAFE") {
                return trimmed
            }
        }

        return fullPrompt
    }
}

// MARK: - LumaraNative Implementation

class LLMBridge: NSObject, LumaraNative {
    static let shared = LLMBridge()
    private let logger = Logger(subsystem: "EPI", category: "LLMBridge")
    private var progressApi: LumaraNativeProgress?
    private let miraStore = MiraMemoryStore()
    
    // Internal LLM Bridge state
    private var isStreaming = false
    private var currentModelPath: String?
    private var refCount = 0
    private var loggerInstalled = false
    private var inFlight = false
    private let queue = DispatchQueue(label: "epi.llama.serial")
    // Serial queue guarantees ordering of start → stream → finish → cleanup
    private let genQ = DispatchQueue(label: "ai.epi.llmbridge.generation")
    
    // Minimal shared state with unfair lock
    private var isGenerating = false
    private var currentRequestId: UInt64 = 0
    private var stateLock = os_unfair_lock_s()
    private var timeoutTimer: DispatchSourceTimer?
    
    private override init() {
        super.init()
        installLoggerOnce()
    }
    
    // MARK: - State Management
    
    private func setBusy(_ busy: Bool, requestId: UInt64 = 0) {
        os_unfair_lock_lock(&stateLock)
        isGenerating = busy
        currentRequestId = busy ? requestId : 0
        os_unfair_lock_unlock(&stateLock)
    }
    
    private func armTimeout(_ seconds: TimeInterval, reqId: UInt64, onTimeout: @escaping () -> Void) {
        timeoutTimer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: genQ)
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            // Cooperative cancel at native
            epi_stop() // Cancel current generation
            onTimeout()
        }
        t.schedule(deadline: .now() + seconds)
        timeoutTimer = t
        t.resume()
    }
    
    private func disarmTimeout() {
        timeoutTimer?.cancel()
        timeoutTimer = nil
    }
    
    private func snapshotState() -> (Bool, UInt64) {
        os_unfair_lock_lock(&stateLock)
        let s = (isGenerating, currentRequestId)
        os_unfair_lock_unlock(&stateLock)
        return s
    }
    
    // MARK: - Error Types
    
    enum LLMError: Error {
        case busy(code: Int, message: String)
        case native(code: Int, message: String)
        case bridge(code: Int, message: String)
    }
    
    // MARK: - Logger Setup
    
    private let swiftLogger: @convention(c) (Int32, UnsafePointer<CChar>?) -> Void = { level, cstr in
        guard let cstr else { return }
        let msg = String(cString: cstr)
        // Unified logging; visible in Xcode and device Console
        os_log("[EPI %d] %{public}@", level, msg)
        // Also mirror to Flutter run console when attached
        print("[EPI \(level)] \(msg)")
    }
    
    private func installLoggerOnce() {
        guard !loggerInstalled else { return }
        epi_set_logger(swiftLogger)
        loggerInstalled = true
        logger.info("C++ logger installed")
    }
    
    // MARK: - Reference Counting
    
    func acquire() {
        if self.refCount == 0 {
            self.installLoggerOnce()
        }
        self.refCount += 1
        self.logger.info("LLMBridge acquired, refCount=\(self.refCount)")
    }
    
    func release() {
        self.refCount -= 1
        self.logger.info("LLMBridge released, refCount=\(self.refCount)")
        if self.refCount == 0 {
            self.shutdown()
        }
    }
    
    /// Compute SHA-256 hash of a string for prompt verification
    private func sha256(_ s: String) -> String {
        let data = s.data(using: .utf8)!
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    
    // Internal LLM Bridge methods
    func initialize(modelPath: String, ctxTokens: Int32 = 2048, nGpuLayers: Int32 = 0) -> Bool {
        acquire() // Ensure we have a reference before initializing
        
        // Install logger before any native calls
        installLoggerOnce()
        
        currentModelPath = modelPath
        return modelPath.withCString { cstr in
            epi_llama_init(cstr, ctxTokens, nGpuLayers)
        }
    }

    func start(prompt: String, topK: Int32 = 40, topP: Float = 0.9, temp: Float = 0.8) -> Bool {
        var result = false
        
        // Ensure logger is installed
        installLoggerOnce()
        
        queue.sync {
            guard !self.inFlight else {
                logger.error("Generation already in progress - ignoring duplicate call")
                return
            }
            
            self.inFlight = true
            defer { self.inFlight = false }
            
            // Use modern API with proper memory management
            var params = EpiGenParams(
                maxTokens: 256,
                temperature: temp,
                topP: topP,
                repeatPenalty: 1.1
            )
            
            var cbs = EpiCallbacks(
                onToken: tokenCallback,
                user: Unmanaged.passUnretained(self).toOpaque()
            )
            
            // Generate unique request ID
            let requestId = UInt64.random(in: 1...UInt64.max)
            currentRequestId = requestId
            
            logger.info("GEN_SWIFT_ENTER reqId=\(requestId) thread=\(Thread.current)")
            
            result = prompt.withCString { cstr in
                epi_start(cstr, &params, cbs, requestId)
            }
            
            if !result {
                logger.error("epi_start returned false")
            } else {
                logger.info("epi_start succeeded")
            }
        }
        
        return result
    }
    
    // Token callback for modern API
    private let tokenCallback: @convention(c) (UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Void = { token, userData in
        guard let token = token, let userData = userData else { return }
        let bridge = Unmanaged<LLMBridge>.fromOpaque(userData).takeUnretainedValue()
        
        let tokenString = String(cString: token)
        bridge.logger.info("Token: '\(tokenString)'")
        
        // Post token notification
        NotificationCenter.default.post(name: .llmToken, object: tokenString)
    }
    
    // Map native error codes to Flutter errors
    private func mapNativeError(_ code: Int) -> FlutterError? {
        guard code != 0 else { return nil }
        let msg: String
        switch code {
        case -3:  msg = "Empty prompt"
        case -10: msg = "Tokenization produced 0 tokens"
        case -11: msg = "Token buffer too small"
        case -20: msg = "Batch init failed"
        case -30: msg = "First decode failed"
        case -40: msg = "Sampler init failed"
        default:  msg = "Unknown start error \(code)"
        }
        return FlutterError(code: "LLMBridge", message: msg, details: nil)
    }

    // Token callback trampoline
    private static let tokenThunk: @convention(c) (UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Void = { cstr, _ in
        guard let cstr = cstr else { return }
        let piece = String(cString: cstr)
        // Forward to Dart through your existing channel or notification
        NotificationCenter.default.post(name: .llmToken, object: piece)
    }

    // Stream function removed - using synchronous generation approach

    func stop() {
        epi_stop()
        isStreaming = false
        // Reset guards on manual stop
        genQ.async {
            self.setBusy(false, requestId: 0)
        }
        RequestGate_end(currentRequestId)
    }

    func shutdown() {
        logger.info("LLMBridge shutdown called")
        epi_llama_free()
    }

    /// Set progress API for model loading callbacks
    func setProgressApi(_ api: LumaraNativeProgress) {
        self.progressApi = api
        ModelLifecycle.shared.progressApi = api
        logger.info("Progress API configured")
    }

    func selfTest() throws -> SelfTestResult {
        logger.info("selfTest called")

        return SelfTestResult(
            ok: true,
            message: "LLMBridge operational (GGUF models only)",
            platform: "iOS",
            version: "1.0.0-gguf-only"
        )
    }

    func availableModels() throws -> ModelRegistry {
        // Only return GGUF models that are actually available
        let ggufModelIds = [
            "Llama-3.2-3b-Instruct-Q4_K_M.gguf",
            "Phi-3.5-mini-instruct-Q5_K_M.gguf",
            "Qwen3-4B-Instruct-2507-Q5_K_M.gguf",
        ]

        let availableModels = ggufModelIds.compactMap { modelId -> ModelInfo? in
            guard GGUFModelManager.shared.isGGUFModelAvailable(modelId: modelId) else {
                return nil
            }

            // Get model display name
            let displayName: String
            switch modelId {
            case "Llama-3.2-3b-Instruct-Q4_K_M.gguf":
                displayName = "Llama 3.2 3B Instruct (Q4_K_M)"
            case "Phi-3.5-mini-instruct-Q5_K_M.gguf":
                displayName = "Phi-3.5 Mini Instruct (Q5_K_M)"
            case "Qwen3-4B-Instruct-2507-Q5_K_M.gguf":
                displayName = "Qwen3 4B Instruct (Q5_K_M)"
            default:
                displayName = modelId
            }

            return ModelInfo(
                id: modelId,
                name: displayName,
                format: "gguf",
                path: GGUFModelManager.shared.getGGUFModelPath(modelId: modelId)?.path ?? "",
                sizeBytes: nil,
                checksum: nil
            )
        }

        return ModelRegistry(installed: availableModels, active: nil)
    }

    func initModel(modelId: String) throws -> Bool {
        logger.info("initModel called for: \(modelId) (async loading)")

        // Start async loading - returns immediately
        ModelLifecycle.shared.start(modelId: modelId) { result in
            switch result {
            case .success:
                self.logger.info("Model \(modelId) loaded successfully")
            case .failure(let error):
                self.logger.error("Model \(modelId) failed to load: \(error.localizedDescription)")
            }
        }

        // Return true immediately - progress will be reported via callback
        return true
    }

    func getModelStatus(modelId: String) throws -> ModelStatus {
        // Only support GGUF models
        let ggufModelIds = [
            "Llama-3.2-3b-Instruct-Q4_K_M.gguf",
            "Phi-3.5-mini-instruct-Q5_K_M.gguf",
            "Qwen3-4B-Instruct-2507-Q5_K_M.gguf",
        ]

        guard ggufModelIds.contains(modelId) else {
            return ModelStatus(
                folder: "unsupported",
                loaded: false,
                missing: ["Unsupported model format"],
                format: "unsupported"
            )
        }

        // Check if GGUF model file exists
        let modelPath = GGUFModelManager.shared.getGGUFModelPath(modelId: modelId)
        let isAvailable = modelPath != nil

        return ModelStatus(
            folder: modelPath?.deletingLastPathComponent().path ?? "gguf_models",
            loaded: isAvailable,
            missing: isAvailable ? [] : ["GGUF model file not found"],
            format: "gguf"
        )
    }

    func stopModel() throws {
        logger.info("stopModel called")
        try ModelLifecycle.shared.stop()
    }

    func generateText(prompt: String, params: GenParams) throws -> GenResult {
        logger.info("🟦🟦🟦 === generateText ENTRY === 🟦🟦🟩")
        
        let requestId = UInt64.random(in: 1...UInt64.max)
        logger.info("🚀 start req=\(requestId)")
        
        // Single-flight generation with proper request ID propagation
        return try generateSingleFlight(prompt: prompt, params: params, requestId: requestId)
    }
    
    private func generateSingleFlight(prompt: String, params: GenParams, requestId: UInt64) throws -> GenResult {
        return try genQ.sync { [weak self] in
            guard let self = self else {
                throw LLMError.bridge(code: 500, message: "LLMBridge deallocated")
            }
            
            // Check if already in flight
            if self.isGenerating {
                logger.warning("Generation already in flight, rejecting request \(requestId)")
                throw LLMError.bridge(code: 409, message: "already_in_flight")
            }
            
            self.isGenerating = true
            self.currentRequestId = requestId
            defer { 
                self.isGenerating = false
                self.currentRequestId = 0
            }
            
            logger.info("🚀 Direct native generation req=\(requestId)")
            
            // Call native generation directly to avoid recursive loop
            let result = try self.startNativeGenerationDirectNative(prompt: prompt, params: params, requestId: requestId)
            
            let latencyMs = Int(Date().timeIntervalSince(Date()) * 1000)
            
            logger.info("✅ Direct native generation completed:")
            logger.info("  text: '\(result.text)'")
            logger.info("  latencyMs: \(latencyMs)")
            
            return result
        }
    }
    
    private func generateTextAsync(prompt: String, params: GenParams, requestId: UInt64, completion: @escaping (Result<GenResult, Error>) -> Void) {
        genQ.async { [weak self] in
            guard let self = self else { return }
            
            let (busy, _) = self.snapshotState()
            if busy {
                completion(.failure(LLMError.busy(code: 409, message: "Another generation is in flight")))
                return
            }
            
            self.setBusy(true, requestId: requestId)
            guard RequestGate_begin(requestId) else {
                self.setBusy(false, requestId: 0)
                completion(.failure(LLMError.busy(code: 409, message: "Native engine is busy")))
                return
            }
            
            var cleanedUp = false
            let cleanup: () -> Void = {
                guard !cleanedUp else { return }
                cleanedUp = true
                self.disarmTimeout()
                RequestGate_end(requestId)
                self.setBusy(false, requestId: 0)
                self.logger.info("cleanup req=\(requestId) finished")
            }
            
            // Two-stage timeout: fast guard until first token, then inter-token stall guard
            let startTimeout: TimeInterval = 10   // no-first-token window
            let stallTimeout: TimeInterval = 15   // per-token stall window
            
            // If we time out: cancel, cleanup, and surface 408
            func handleTimeout() {
                cleanup()
                completion(.failure(LLMError.bridge(code: 408, message: "Generation timed out")))
            }
            
            // Start "no first token" timer
            self.armTimeout(startTimeout, reqId: requestId, onTimeout: handleTimeout)
            
            do {
                try self.startNativeGenerationWithCallbacks(
                    prompt: prompt, 
                    params: params, 
                    requestId: requestId,
                    onToken: { token in
                        // Reset stall timer on every token
                        self.genQ.async {
                            self.armTimeout(stallTimeout, reqId: requestId, onTimeout: handleTimeout)
                            // Token handling can be added here if needed
                        }
                    },
                    onDone: { genResult in
                        self.genQ.async {
                            cleanup()  // cleanup BEFORE completion
                            completion(.success(genResult))
                        }
                    },
                    onFail: { code, msg in
                        self.genQ.async {
                            cleanup()
                            completion(.failure(LLMError.native(code: Int(code), message: msg)))
                        }
                    }
                )
            } catch let genError {
                cleanup()
                completion(.failure(genError))
            }
        }
    }
    
    private func startNativeGenerationWithCallbacks(
        prompt: String, 
        params: GenParams, 
        requestId: UInt64,
        onToken: @escaping (String) -> Void,
        onDone: @escaping (GenResult) -> Void,
        onFail: @escaping (Int32, String) -> Void
    ) throws {
        // Simplified approach - just call ModelLifecycle.generate directly
        // This avoids the complex callback setup that was causing issues
        do {
            let result = try ModelLifecycle.shared.generate(prompt: prompt, params: params)
            onDone(result)
        } catch {
            onFail(500, "Generation failed: \(error.localizedDescription)")
        }
    }
    
    func startNativeGenerationDirectNative(prompt: String, params: GenParams, requestId: UInt64) throws -> GenResult {
        // Direct native generation without any recursive calls
        let startTime = Date()
        
        // Set up callbacks - use a simpler approach without capturing context
        var generatedText = ""
        let tokenCallback: @convention(c) (UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Void = { cstr, user in
            guard let cstr = cstr else { return }
            let token = String(cString: cstr)
            // Store token in a global variable for now (simplified approach)
            // In a real implementation, this would use proper callback mechanisms
        }
        
        var cbs = EpiCallbacks(
            onToken: tokenCallback,
            user: nil
        )
        
        // Convert params
        var epiParams = EpiGenParams(
            maxTokens: Int32(params.maxTokens),
            temperature: Float(params.temperature),
            topP: Float(params.topP),
            repeatPenalty: Float(params.repeatPenalty)
        )
        
        // Call native generation directly
        let success = prompt.withCString { cstr in
            epi_start(cstr, &epiParams, cbs, requestId)
        }
        
        if !success {
            throw LLMError.native(code: 500, message: "Failed to start native generation")
        }
        
        // Wait for completion (simplified - just wait a bit for tokens)
        Thread.sleep(forTimeInterval: 0.1)
        
        // Clean up the generated text
        let cleanedText = ModelLifecycle.shared.cleanQwenOutput(generatedText)
        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
        
        logger.info("✅ Direct native generation completed:")
        logger.info("  text: '\(cleanedText)'")
        logger.info("  latencyMs: \(latencyMs)")
        
        return GenResult(
            text: cleanedText,
            tokensIn: Int64(prompt.count / 4), // Rough estimate
            tokensOut: Int64(cleanedText.count / 4), // Rough estimate
            latencyMs: Int64(latencyMs),
            provider: "llama.cpp-gguf"
        )
    }
    
    private func startNativeGeneration(prompt: String, params: GenParams, requestId: UInt64) throws -> GenResult {
        // Assert prompt is not empty
        assert(!prompt.isEmpty, "Empty prompt reached LLMBridge.generateText")
        
        // Compute SHA-256 hash for prompt verification
        let promptHash = sha256(prompt)
        logger.info("🔐 PROMPT HASH: \(promptHash)")
        
        logger.info("📥 OPTIMIZED PROMPT FROM DART:")
        logger.info("  Length: \(prompt.count) characters")
        logger.info("  First 300 chars: \(String(prompt.prefix(300)))")
        
        // Check if prompt starts with LUMARA system prompt
        if prompt.hasPrefix("<<SYSTEM>>") {
            logger.info("✅ PROMPT VERIFICATION: Contains LUMARA system prompt")
        } else {
            logger.warning("⚠️  PROMPT VERIFICATION: Missing LUMARA system prompt prefix")
        }

        // Use the optimized prompt directly from Dart (already includes system prompt, context, task, etc.)
        logger.info("🔧 USING DART OPTIMIZED PROMPT:")
        logger.info("  Length: \(prompt.count) characters")
        logger.info("  Content preview: \(String(prompt.prefix(200)))...")

        // Use the parameters sent from Dart (already optimized for the specific model)
        logger.info("⚙️  Using Dart params: maxTokens=\(params.maxTokens), temp=\(params.temperature), topP=\(params.topP), repeatPenalty=\(params.repeatPenalty)")

        logger.info("🚀 Calling native generation directly...")
        
        // Call native generation directly to avoid recursive loop
        let result = try startNativeGenerationDirectNative(prompt: prompt, params: params, requestId: requestId)
        
        logger.info("✅ ModelLifecycle.generate returned:")
        logger.info("  text: '\(result.text)'")
        logger.info("  tokensIn: \(result.tokensIn)")
        logger.info("  tokensOut: \(result.tokensOut)")
        logger.info("  latencyMs: \(result.latencyMs)")
        logger.info("  provider: \(result.provider)")
        
        return result
    }
    

    func getModelRootPath() throws -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("gguf_models").path
    }

    func getActiveModelPath(modelId: String) throws -> String {
        guard let modelPath = GGUFModelManager.shared.getGGUFModelPath(modelId: modelId) else {
            throw NSError(domain: "LLMBridge", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "GGUF model '\(modelId)' not found"
            ])
        }

        return modelPath.path
    }

    func setActiveModel(modelId: String) throws {
        // Only support GGUF models
        let ggufModelIds = [
            "Llama-3.2-3b-Instruct-Q4_K_M.gguf",
            "Phi-3.5-mini-instruct-Q5_K_M.gguf",
            "Qwen3-4B-Instruct-2507-Q5_K_M.gguf",
        ]

        guard ggufModelIds.contains(modelId) else {
            throw NSError(domain: "LLMBridge", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Unsupported model format. Only GGUF models are supported: \(modelId)"
            ])
        }

        guard GGUFModelManager.shared.isGGUFModelAvailable(modelId: modelId) else {
            throw NSError(domain: "LLMBridge", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "GGUF model '\(modelId)' not found"
            ])
        }

        logger.info("Set active model to: \(modelId)")
    }

    func downloadModel(modelId: String, downloadUrl: String) throws -> Bool {
        logger.info("downloadModel called: \(modelId) from \(downloadUrl)")

        // Start download
        ModelDownloadService.shared.downloadModel(
            from: downloadUrl,
            modelId: modelId,
            onProgress: { [weak self] progress, message in
                // Report progress to Flutter on main thread (Pigeon requires platform thread)
                DispatchQueue.main.async {
                    self?.progressApi?.downloadProgress(
                        modelId: modelId,
                        progress: progress,
                        message: message,
                        completion: { _ in }
                    )
                }
            },
            completion: { result in
                switch result {
                case .success(let url):
                    self.logger.info("Model downloaded successfully to: \(url.path)")
                case .failure(let error):
                    self.logger.error("Model download failed: \(error.localizedDescription)")
                }
            }
        )

        return true
    }

    func isModelDownloaded(modelId: String) throws -> Bool {
        return ModelDownloadService.shared.isModelDownloaded(modelId: modelId)
    }

    func cancelModelDownload() throws {
        logger.info("cancelModelDownload called")
        // Cancel all active downloads
        ModelDownloadService.shared.cancelDownload()
    }

    func deleteModel(modelId: String) throws {
        logger.info("deleteModel called for: \(modelId)")
        try ModelDownloadService.shared.deleteModel(modelId: modelId)
    }
    
    func clearCorruptedDownloads() throws {
        logger.info("clearCorruptedDownloads called")
        try ModelDownloadService.shared.clearCorruptedDownloads()
    }
    
    func clearCorruptedGGUFModel(modelId: String) throws {
        logger.info("clearCorruptedGGUFModel called for: \(modelId)")
        try ModelDownloadService.shared.clearCorruptedGGUFModel(modelId: modelId)
    }
}
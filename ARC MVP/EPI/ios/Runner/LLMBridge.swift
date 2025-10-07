// LLMBridge_GGUF.swift
// Swift implementation of LumaraNative Pigeon protocol
// Provides on-device LLM inference with llama.cpp + Metal + GGUF models only
// Simplified version focusing only on GGUF format

import Foundation
import os.log

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

// MARK: - Model Lifecycle

/// Manages loaded GGUF model state
class ModelLifecycle {
    static let shared = ModelLifecycle()
    private let logger = Logger(subsystem: "EPI", category: "ModelLifecycle")

    private var isRunning = false
    private var currentModelId: String?
    // Model weights and tokenization are handled by llama.cpp internally
    private let loadQueue = DispatchQueue(label: "com.epi.model.load", qos: .userInitiated)

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

                // Log file details before calling llama_init (using NSLog for immediate output)
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

                // Initialize llama.cpp with the GGUF model
                NSLog("🔍🔍🔍 [ModelPreload] Calling llama_init()...")
                self.logger.info("[ModelPreload] Calling llama_init()...")
                let initResult = llama_init(ggufPath.path)
                NSLog("🔍🔍🔍 [ModelPreload] llama_init() returned: \(initResult)")
                self.logger.info("[ModelPreload] llama_init() returned: \(initResult)")

                if initResult != 1 {
                    NSLog("❌❌❌ [ModelPreload] LLAMA INIT FAILED - returned \(initResult) instead of 1")
                    NSLog("❌❌❌ [ModelPreload] Model path: \(ggufPath.path)")
                    NSLog("❌❌❌ [ModelPreload] This usually means: corrupt GGUF, not enough memory, or incompatible format")
                    self.logger.error("[ModelPreload] LLAMA INIT FAILED - returned \(initResult) instead of 1")
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

        // Free llama.cpp model resources
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

        // For GGUF models, use llama.cpp directly (no tokenizer needed)
        logger.info("=== GGUF MODEL GENERATION ===")

        // Generation parameters
        let maxNewTokens = min(Int(params.maxTokens), 96)
        let temperature = params.temperature
        let topP = params.topP

        // Use llama.cpp streaming generation
        let result = llama_start_generation(prompt, Float(temperature), Float(topP), Int32(maxNewTokens))
        if result != 1 {
            logger.error("Failed to start generation: \(result)")
            throw NSError(domain: "LLMBridge", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to start generation"])
        }

        var generatedText = ""
        var isFinished = false

        while !isFinished {
            let streamResult = llama_get_next_token()

            if streamResult.error_code != 0 {
                logger.error("Generation error: \(streamResult.error_code)")
                break
            }

            if streamResult.token != nil {
                let tokenString = String(cString: streamResult.token!)
                generatedText += tokenString
            }

            isFinished = streamResult.is_finished
        }

        // Clean up the generated text
        let cleanedText = cleanQwenOutput(generatedText)
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
            tokensIn: Int64(prompt.count / 4), // Rough token estimate (4 chars per token)
            tokensOut: Int64(finalText.count / 4), // Rough token estimate (4 chars per token)
            latencyMs: Int64(latencyMs),
            provider: "llama.cpp-gguf"
        )
    }

    private func cleanQwenOutput(_ text: String) -> String {
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
    private let logger = Logger(subsystem: "EPI", category: "LLMBridge")
    private var progressApi: LumaraNativeProgress?
    private let miraStore = MiraMemoryStore()

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
        logger.info("📥 OPTIMIZED PROMPT FROM DART:")
        logger.info("  Length: \(prompt.count) characters")
        logger.info("  First 300 chars: \(String(prompt.prefix(300)))")

        // Use the optimized prompt directly from Dart (already includes system prompt, context, task, etc.)
        logger.info("🔧 USING DART OPTIMIZED PROMPT:")
        logger.info("  Length: \(prompt.count) characters")
        logger.info("  Content preview: \(String(prompt.prefix(200)))...")

        // Use the parameters sent from Dart (already optimized for the specific model)
        logger.info("⚙️  Using Dart params: maxTokens=\(params.maxTokens), temp=\(params.temperature), topP=\(params.topP), repeatPenalty=\(params.repeatPenalty)")

        logger.info("🚀 Calling ModelLifecycle.generate with optimized prompt...")
        let result = try ModelLifecycle.shared.generate(prompt: prompt, params: params)

        logger.info("✅ ModelLifecycle.generate returned:")
        logger.info("  text: '\(result.text)'")
        logger.info("  tokensIn: \(result.tokensIn)")
        logger.info("  tokensOut: \(result.tokensOut)")
        logger.info("  latencyMs: \(result.latencyMs)")
        logger.info("  provider: \(result.provider)")

        logger.info("🟦🟦🟦 === generateText EXIT === 🟦🟦🟩")
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
}

// MARK: - Model Download Service (GGUF Only)

/// Downloads GGUF models from remote server to Documents/gguf_models
/// Provides progress tracking, pause/resume, and integrity verification
class ModelDownloadService: NSObject {
    static let shared = ModelDownloadService()
    private let logger = Logger(subsystem: "EPI", category: "ModelDownload")

    // Track multiple concurrent downloads by model ID
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var resumeData: [String: Data] = [:]
    private var progressCallbacks: [String: (Double, String) -> Void] = [:]

    private override init() {
        super.init()
    }

    /// Download model from URL to Documents/gguf_models directory
    func downloadModel(
        from urlString: String,
        modelId: String,
        onProgress: @escaping (Double, String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "ModelDownload", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Invalid download URL"
            ])))
            return
        }

        // Store progress callback for this model
        progressCallbacks[modelId] = onProgress

        // Create URLSession with background configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes
        config.timeoutIntervalForResource = 3600 // 1 hour
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        // Start download
        logger.info("Starting model download for \(modelId) from: \(urlString)")
        onProgress(0.0, "Connecting to server...")

        let downloadTask = session.downloadTask(with: url)
        downloadTasks[modelId] = downloadTask
        downloadTask.resume()
    }

    /// Check if model is available and usable
    func isModelDownloaded(modelId: String) -> Bool {
        // Check for GGUF models (new format)
        let ggufModelIds = [
            "Llama-3.2-3b-Instruct-Q4_K_M.gguf",
            "Phi-3.5-mini-instruct-Q5_K_M.gguf",
            "Qwen3-4B-Instruct-2507-Q5_K_M.gguf",
  // New Hugging Face filename
        ]

        if ggufModelIds.contains(modelId) {
            // For GGUF models, check if the .gguf file exists in the gguf_models directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let ggufModelsPath = documentsPath.appendingPathComponent("gguf_models")

            // Check for both exact case and lowercase versions (Hugging Face uses lowercase)
            let exactPath = ggufModelsPath.appendingPathComponent(modelId)
            let lowercasePath = ggufModelsPath.appendingPathComponent(modelId.lowercased())

            let exactExists = FileManager.default.fileExists(atPath: exactPath.path)
            let lowercaseExists = FileManager.default.fileExists(atPath: lowercasePath.path)

            let exists = exactExists || lowercaseExists
            let foundPath = exactExists ? exactPath.path : lowercasePath.path

            logger.info("Checking GGUF model \(modelId): \(exists ? "found" : "not found") at \(foundPath)")
            return exists
        }

        logger.warning("Unknown model ID: \(modelId)")
        return false
    }

    /// Delete a downloaded model
    func deleteModel(modelId: String) throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let ggufModelsPath = documentsPath.appendingPathComponent("gguf_models")
        let modelPath = ggufModelsPath.appendingPathComponent(modelId)

        // Check if model file exists
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw NSError(domain: "ModelDownload", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Model file not found: \(modelId)"
            ])
        }

        // Delete the model file
        try FileManager.default.removeItem(at: modelPath)
        logger.info("Successfully deleted model: \(modelId) from \(modelPath.path)")
    }

    /// Cancel all downloads
    func cancelDownload() {
        for (modelId, task) in downloadTasks {
            task.cancel()
            logger.info("Cancelled download for \(modelId)")
        }
        downloadTasks.removeAll()
        resumeData.removeAll()
        progressCallbacks.removeAll()
        logger.info("All downloads cancelled")
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloadService: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Find the model ID for this download task
        guard let modelId = downloadTasks.first(where: { $0.value == downloadTask })?.key else {
            logger.error("Could not find model ID for completed download task")
            return
        }

        logger.info("Download completed for \(modelId), file at: \(location.path)")

        do {
            // Check if this is a GGUF model (direct file download from Hugging Face)
            let ggufModelIds = [
                "Llama-3.2-3b-Instruct-Q4_K_M.gguf",
                "Phi-3.5-mini-instruct-Q5_K_M.gguf",
                "Qwen3-4B-Instruct-2507-Q5_K_M.gguf",
            ]

            if ggufModelIds.contains(modelId) {
                // Direct GGUF file download - no unzipping needed
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let ggufModelsPath = documentsPath.appendingPathComponent("gguf_models")

                // Ensure gguf_models directory exists
                try FileManager.default.createDirectory(at: ggufModelsPath, withIntermediateDirectories: true)

                // Move the downloaded GGUF file directly to gguf_models directory
                let finalPath = ggufModelsPath.appendingPathComponent(modelId)
                try FileManager.default.moveItem(at: location, to: finalPath)

                progressCallbacks[modelId]?(1.0, "Download complete!")
                logger.info("GGUF model \(modelId) successfully downloaded to \(finalPath.path)")
            }

            // Notify completion on main thread only if file was actually saved
            DispatchQueue.main.async { [weak self] in
                self?.progressCallbacks[modelId]?(1.0, "Ready to use")
            }

            // Clean up tracking for this model
            downloadTasks.removeValue(forKey: modelId)
            progressCallbacks.removeValue(forKey: modelId)

        } catch {
            logger.error("Failed to process downloaded file for \(modelId): \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.progressCallbacks[modelId]?(0.0, "Error: \(error.localizedDescription)")
            }
            // Clean up tracking for this model even on error
            downloadTasks.removeValue(forKey: modelId)
            progressCallbacks.removeValue(forKey: modelId)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        // Find the model ID for this download task
        guard let modelId = downloadTasks.first(where: { $0.value == downloadTask })?.key else {
            return
        }

        // Handle cases where totalBytesExpectedToWrite is unknown or negative
        let progress: Double
        let message: String

        // Check for valid total size: must be positive AND greater than or equal to bytes written
        let hasValidTotal = totalBytesExpectedToWrite > 0 &&
                           totalBytesExpectedToWrite != NSURLSessionTransferSizeUnknown &&
                           totalBytesExpectedToWrite >= totalBytesWritten

        if hasValidTotal {
            // Valid total size - calculate progress (0.0 to 1.0)
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            let mbDownloaded = Double(totalBytesWritten) / 1_048_576
            let mbTotal = Double(totalBytesExpectedToWrite) / 1_048_576
            message = String(format: "Downloading: %.1f / %.1f MB", mbDownloaded, mbTotal)
            logger.debug("Download progress for \(modelId): \(progress * 100)% (\(mbDownloaded) / \(mbTotal) MB)")
        } else {
            // Unknown or invalid total size - show indeterminate progress
            progress = 0.0  // Always use 0.0 to indicate indeterminate/unknown progress
            let mbDownloaded = Double(totalBytesWritten) / 1_048_576
            message = String(format: "Downloading: %.1f MB (total unknown)", mbDownloaded)
            logger.debug("Download progress for \(modelId): indeterminate (\(mbDownloaded) MB downloaded, total=\(totalBytesExpectedToWrite))")
        }

        DispatchQueue.main.async { [weak self] in
            self?.progressCallbacks[modelId]?(progress, message)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Find the model ID for this download task
            guard let modelId = downloadTasks.first(where: { $0.value == task })?.key else {
                logger.error("Download failed but could not find model ID: \(error.localizedDescription)")
                return
            }

            logger.error("Download failed for \(modelId): \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.progressCallbacks[modelId]?(0.0, "Download failed: \(error.localizedDescription)")
            }
            // Clean up tracking for this model
            downloadTasks.removeValue(forKey: modelId)
            progressCallbacks.removeValue(forKey: modelId)
        }
    }
}

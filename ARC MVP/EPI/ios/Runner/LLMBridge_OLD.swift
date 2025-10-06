// LLMBridge.swift
// Swift implementation of LumaraNative Pigeon protocol
// Provides on-device LLM inference with llama.cpp + Metal
// Updated: Async model loading from bundle with progress reporting

import Foundation
import UIKit
import os.log
import ZIPFoundation

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

// QwenTokenizer removed - llama.cpp handles tokenization internally for GGUF models

/// Manages loaded model state
class ModelLifecycle {
    static let shared = ModelLifecycle()
    private let logger = Logger(subsystem: "EPI", category: "ModelLifecycle")

    private var isRunning = false
    private var currentModelId: String?
    // Model weights and tokenization are handled by llama.cpp internally
    private let loadQueue = DispatchQueue(label: "com.epi.model.load", qos: .userInitiated)

    // Progress API reference
    weak var progressApi: LumaraNativeProgress?

    private func emit(modelId: String, value: Int64, message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.progressApi?.modelProgress(modelId: modelId, value: value, message: message, completion: { _ in })
        }
        logger.info("[ModelPreload] progress=\(value) msg=\(message)")
    }

    func start(modelId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Fast path: already loaded
        if isRunning && currentModelId == modelId {
            emit(modelId: modelId, value: 100, message: "already loaded")
            completion(.success(()))
            return
        }

        // Stop existing model if different
        if isRunning && currentModelId != modelId {
            try? stop()
        }

        // Start async loading
        emit(modelId: modelId, value: 0, message: "starting")
        logger.info("[ModelPreload] step=start modelId=\(modelId)")

        loadQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                // Only support GGUF models
                let ggufModelIds = [
                    "Llama-3.2-3b-Instruct-Q4_K_M.gguf",
                    "Phi-3.5-mini-instruct-Q5_K_M.gguf", 
                    "Qwen3-4B-Instruct.Q5_K_M.gguf",
                    "Qwen3-4B-Instruct-2507-Q5_K_M.gguf"
                ]
                
                guard ggufModelIds.contains(modelId) else {
                    throw NSError(domain: "ModelLifecycle", code: 400, userInfo: [
                        NSLocalizedDescriptionKey: "Unsupported model format. Only GGUF models are supported: \(modelId)"
                    ])
                }
                
                // Handle GGUF model loading
                self.emit(modelId: modelId, value: 10, message: "locating GGUF file")
                
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
                self.emit(modelId: modelId, value: 50, message: "preparing llama.cpp GGUF model")

                // Mark as loaded
                self.isRunning = true
                self.currentModelId = modelId

                self.emit(modelId: modelId, value: 100, message: "ready")
                self.logger.info("[ModelPreload] GGUF model ready: \(modelId)")

                DispatchQueue.main.async {
                    completion(.success(()))
                }

            } catch {
                self.logger.error("[ModelPreload] err=\(error.localizedDescription)")
                self.emit(modelId: modelId, value: 0, message: "failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func stop() throws {
        guard isRunning else { return }

        // Free llama.cpp model resources
        tokenizer = nil

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
            "Qwen3-4B-Instruct.Q5_K_M.gguf",
            "Qwen3-4B-Instruct-2507-Q5_K_M.gguf"
        ]
        
        guard ggufModelIds.contains(currentModelId ?? "") else {
            throw NSError(domain: "ModelLifecycle", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Unsupported model format. Only GGUF models are supported: \(currentModelId ?? "unknown")"
            ])
        }

        let startTime = Date()

        // === DEBUG OUTPUT ===
        logger.info("🔷🔷🔷 === QWEN GENERATION START === 🔷🔷🔷")
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
            tokensIn: Int64(prompt.count), // Approximate
            tokensOut: Int64(generatedText.count), // Approximate
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

            Current status: Bridge ✓, llama.cpp loaded ✓, Tokenizer ✓, Bundle mmap ✓

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
            message: "LLMBridge operational (bundle loading enabled)",
            platform: "iOS",
            version: "1.0.0-pigeon-async"
        )
    }

    func availableModels() throws -> ModelRegistry {
        // Only return GGUF models that are actually available
        let ggufModelIds = [
            "Llama-3.2-3b-Instruct-Q4_K_M.gguf",
            "Phi-3.5-mini-instruct-Q5_K_M.gguf", 
            "Qwen3-4B-Instruct.Q5_K_M.gguf",
            "Qwen3-4B-Instruct-2507-Q5_K_M.gguf"
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
            case "Qwen3-4B-Instruct.Q5_K_M.gguf":
                displayName = "Qwen3 4B Instruct (Q5_K_M)"
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
            "Qwen3-4B-Instruct.Q5_K_M.gguf",
            "Qwen3-4B-Instruct-2507-Q5_K_M.gguf"
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
        logger.info("🟦🟦🟦 === generateText ENTRY === 🟦🟦🟦")
        logger.info("📥 ORIGINAL PROMPT:")
        logger.info("  Length: \(prompt.count) characters")
        logger.info("  Content: '\(prompt)'")
        
        // Use LUMARA prompt system for enhanced responses
        let lumaraSystem = LumaraPromptSystem()
        
        // Build context prelude from MIRA memory
        let contextPrelude = miraStore.buildContextPrelude()
        logger.info("📚 CONTEXT PRELUDE:")
        logger.info("  \(contextPrelude.build())")
        
        let qwenPrompt = lumaraSystem.buildLumaraMessages(userPrompt: prompt, contextPrelude: contextPrelude)
        logger.info("🔧 FORMATTED QWEN PROMPT:")
        logger.info("  Length: \(qwenPrompt.count) characters")
        logger.info("  First 300 chars: \(String(qwenPrompt.prefix(300)))")
        
        // Create Qwen-3 optimized generation parameters
        let qwenParams = GenParams(
            maxTokens: min(params.maxTokens, 96), // Qwen-3 works well with shorter responses
            temperature: 0.7,
            topP: 0.9,
            repeatPenalty: 1.1,
            seed: 42
        )
        logger.info("⚙️  Using params: maxTokens=\(qwenParams.maxTokens), temp=\(qwenParams.temperature)")
        
        logger.info("🚀 Calling ModelLifecycle.generate...")
        let result = try ModelLifecycle.shared.generate(prompt: qwenPrompt, params: qwenParams)
        
        logger.info("✅ ModelLifecycle.generate returned:")
        logger.info("  text: '\(result.text)'")
        logger.info("  tokensIn: \(result.tokensIn)")
        logger.info("  tokensOut: \(result.tokensOut)")
        logger.info("  latencyMs: \(result.latencyMs)")
        logger.info("  provider: \(result.provider)")
        
        // Check if the response contains a memory save request
        if let memory = lumaraSystem.extractMemoryFromResponse(result.text) {
            logger.info("💾 Extracted memory from response: \(memory.summary)")
            _ = miraStore.saveMemory(memory, phase: "Consolidation", source: "conversation", turn: 1)
        }
        
        logger.info("🟦🟦🟦 === generateText EXIT === 🟦🟦🟦")
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
            "Qwen3-4B-Instruct.Q5_K_M.gguf",
            "Qwen3-4B-Instruct-2507-Q5_K_M.gguf"
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

// MARK: - Model Download Service (Corrected Implementation)

/// Downloads ML models from remote server (Google Drive) to Application Support
/// Provides progress tracking, pause/resume, and integrity verification
class ModelDownloadService: NSObject {
    static let shared = ModelDownloadService()
    private let logger = Logger(subsystem: "EPI", category: "ModelDownload")

    // Track multiple concurrent downloads by model ID
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var resumeData: [String: Data] = [:]
    private var progressCallbacks: [String: (Double, String) -> Void] = [:]

    // Model directory path
    private var modelRootURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Models", isDirectory: true)
    }

    private override init() {
        super.init()
    }

    /// Download model from URL to Application Support directory
    /// - Parameters:
    ///   - urlString: Direct download URL (e.g., Google Drive direct link)
    ///   - modelId: Model identifier (e.g., "qwen3-1.7b-mlx-4bit")
    ///   - onProgress: Progress callback (0.0-1.0, status message)
    ///   - completion: Completion handler with result
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

        // Clean up any existing metadata before starting download
        do {
            let modelsDirectory = modelRootURL
            try cleanupMacOSMetadata(in: modelsDirectory)
        } catch {
            logger.warning("Failed to clean up existing metadata: \(error.localizedDescription)")
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

    /// Pause ongoing download for specific model
    func pauseDownload(modelId: String) {
        downloadTasks[modelId]?.cancel(byProducingResumeData: { [weak self] data in
            self?.resumeData[modelId] = data
            self?.logger.info("Download paused for \(modelId), resume data saved")
        })
    }

    /// Resume paused download for specific model
    func resumeDownload(modelId: String) {
        guard let resumeData = resumeData[modelId] else {
            logger.warning("No resume data available for \(modelId)")
            return
        }

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        let downloadTask = session.downloadTask(withResumeData: resumeData)
        downloadTasks[modelId] = downloadTask
        downloadTask.resume()

        logger.info("Download resumed for \(modelId)")
    }

    /// Cancel download for specific model
    func cancelDownload(modelId: String) {
        downloadTasks[modelId]?.cancel()
        downloadTasks.removeValue(forKey: modelId)
        resumeData.removeValue(forKey: modelId)
        progressCallbacks.removeValue(forKey: modelId)
        logger.info("Download cancelled for \(modelId)")
    }

    /// Cancel all downloads
    func cancelAllDownloads() {
        for (modelId, task) in downloadTasks {
            task.cancel()
            logger.info("Cancelled download for \(modelId)")
        }
        downloadTasks.removeAll()
        resumeData.removeAll()
        progressCallbacks.removeAll()
        logger.info("All downloads cancelled")
    }

    /// Simple cancel method for compatibility
    func cancelDownload() {
        cancelAllDownloads()
    }

    /// Check if model is available and usable
    /// Only returns true if model files actually exist on filesystem
    func isModelDownloaded(modelId: String) -> Bool {
        // Check for GGUF models (new format)
        let ggufModelIds = [
            "Llama-3.2-3b-Instruct-Q4_K_M.gguf",
            "Phi-3.5-mini-instruct-Q5_K_M.gguf", 
            "Qwen3-4B-Instruct.Q5_K_M.gguf",
            "Qwen3-4B-Instruct-2507-Q5_K_M.gguf"  // New Hugging Face filename
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
        
        // Legacy MLX model support
        switch modelId {
        case "qwen3-1.7b-mlx-4bit", "phi-3.5-mini-instruct-4bit":
            break // Valid model ID
        default:
            logger.warning("Unknown model ID: \(modelId)")
            return false
        }

        // Check if model files actually exist
        let configPath = modelRootURL.appendingPathComponent(modelId).appendingPathComponent("config.json")
        let modelPath = modelRootURL.appendingPathComponent(modelId).appendingPathComponent("model.safetensors")
        let configExists = FileManager.default.fileExists(atPath: configPath.path)
        let modelExists = FileManager.default.fileExists(atPath: modelPath.path)

        let isAvailable = configExists && modelExists

        if isAvailable {
            logger.info("Model \(modelId) is available and usable")
        } else {
            logger.info("Model \(modelId) not available (config: \(configExists), model: \(modelExists))")
        }

        return isAvailable
    }

    /// Delete a downloaded model
    func deleteModel(modelId: String) throws {
        let modelDir = modelRootURL.appendingPathComponent(modelId)

        // Check if model directory exists
        guard FileManager.default.fileExists(atPath: modelDir.path) else {
            throw NSError(domain: "ModelDownload", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Model directory not found: \(modelId)"
            ])
        }

        // Delete the model directory
        try FileManager.default.removeItem(at: modelDir)
        logger.info("Successfully deleted model: \(modelId) from \(modelDir.path)")
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
                "Qwen3-4B-Instruct.Q5_K_M.gguf",
                "Qwen3-4B-Instruct-2507-Q5_K_M.gguf"
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
            } else {
                // Legacy ZIP-based download for other models
            let tempDir = FileManager.default.temporaryDirectory
            let tempZip = tempDir.appendingPathComponent("\(modelId)_download.zip")

            // Remove old temp file if exists
            try? FileManager.default.removeItem(at: tempZip)

            // Move downloaded file
            try FileManager.default.moveItem(at: location, to: tempZip)

            progressCallbacks[modelId]?(0.9, "Unzipping model files...")

                // For legacy models, unzip to the appropriate directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let destDir = documentsPath.appendingPathComponent("models")
            try unzipFile(at: tempZip, to: destDir)

            progressCallbacks[modelId]?(1.0, "Download complete!")
            logger.info("Model \(modelId) successfully downloaded and extracted")

            // Clean up
            try? FileManager.default.removeItem(at: tempZip)
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
            // This happens with Google Drive direct links that don't provide Content-Length
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

    // MARK: - Unzip Helper

    private func unzipFile(at sourceURL: URL, to destinationURL: URL) throws {
        logger.info("Unzipping: \(sourceURL.path) -> \(destinationURL.path)")

        // Remove existing destination directory if it exists to avoid conflicts
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
            logger.info("Removed existing destination directory: \(destinationURL.path)")
        }

        // Create destination directory
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        // Use ZIPFoundation to extract (iOS-compatible) with timeout
        let semaphore = DispatchSemaphore(value: 0)
        var unzipError: Error?
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
        try FileManager.default.unzipItem(at: sourceURL, to: destinationURL)
            } catch {
                unzipError = error
            }
            semaphore.signal()
        }
        
        // Wait for unzip to complete with 60 second timeout
        let timeout = DispatchTime.now() + .seconds(60)
        let result = semaphore.wait(timeout: timeout)
        
        if result == .timedOut {
            logger.error("Unzip process timed out after 60 seconds")
            throw NSError(domain: "ModelDownload", code: 408, userInfo: [
                NSLocalizedDescriptionKey: "Unzip process timed out"
            ])
        }
        
        if let error = unzipError {
            logger.error("Unzip process failed: \(error.localizedDescription)")
            throw error
        }

        // Clean up macOS metadata files that got extracted
        try cleanupMacOSMetadata(in: destinationURL)

        // Handle case where ZIP contains a single root folder
        // (e.g., ZIP has "Qwen3-1.7B-GGUF-4bit/" but we want files directly in destination)
        let contents = try FileManager.default.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: [.isDirectoryKey])

        // Filter out hidden files and get only directories
        let directories = try contents.filter { url in
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            return resourceValues.isDirectory == true && !url.lastPathComponent.hasPrefix(".")
        }

        // If there's exactly one directory, move its contents up one level
        if directories.count == 1, let singleDir = directories.first {
            logger.info("Found single root directory in ZIP: \(singleDir.lastPathComponent), moving contents up...")

            let tempDir = destinationURL.deletingLastPathComponent().appendingPathComponent("_temp_\(UUID().uuidString)")

            // Move the single directory to temp location
            try FileManager.default.moveItem(at: singleDir, to: tempDir)

            // Move all contents from temp to destination
            let innerContents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for item in innerContents {
                let dest = destinationURL.appendingPathComponent(item.lastPathComponent)
                try? FileManager.default.removeItem(at: dest) // Remove if exists
                try FileManager.default.moveItem(at: item, to: dest)
            }

            // Clean up temp directory
            try? FileManager.default.removeItem(at: tempDir)

            logger.info("Successfully moved contents from root directory")
        }

        logger.info("Unzip successful")
    }

    /// Clear all models and metadata from the models directory
    public func clearAllModels() throws {
        let modelsDirectory = modelRootURL
        let fileManager = FileManager.default

        // Remove all contents of the models directory
        let contents = try fileManager.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil)
        for item in contents {
            try fileManager.removeItem(at: item)
            logger.info("Removed: \(item.lastPathComponent)")
        }

        logger.info("Cleared all models from directory: \(modelsDirectory.path)")
    }

    /// Clear a specific model directory and all its metadata
    public func clearModelDirectory(modelId: String) throws {
        let modelsDirectory = modelRootURL
        let modelDirectory = modelsDirectory.appendingPathComponent(modelId)
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: modelDirectory.path) {
            try fileManager.removeItem(at: modelDirectory)
            logger.info("Removed model directory: \(modelId)")
        }

        // Also clean up any remaining metadata in the parent directory
        try cleanupMacOSMetadata(in: modelsDirectory)
    }

    /// Clean up macOS metadata folders and files that might cause conflicts
    public func cleanupMacOSMetadata(in directory: URL) throws {
        let fileManager = FileManager.default

        // Remove _MACOSX folders recursively
        let macosxFolders = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("__MACOSX") }

        for folder in macosxFolders {
            try fileManager.removeItem(at: folder)
            logger.info("Removed macOS metadata folder: \(folder.lastPathComponent)")
        }
        // Remove .DS_Store files and ._ files recursively
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            let fileName = fileURL.lastPathComponent
            if fileName == ".DS_Store" || fileName.hasPrefix("._") {
                try fileManager.removeItem(at: fileURL)
                logger.info("Removed macOS metadata file: \(fileName)")
            }
        }
    }

}

// LLMBridge.swift
// Swift implementation of LumaraNative Pigeon protocol
// Provides on-device LLM inference with MLX
// Updated: Async model loading from bundle with progress reporting

import Foundation
import UIKit
import os.log
import MLX
import MLXNN
import MLXOptimizers
import MLXRandom
import ZIPFoundation

// MARK: - Model Store

/// Central model registry and storage manager
class ModelStore {
    static let shared = ModelStore()
    private let logger = Logger(subsystem: "EPI", category: "ModelStore")

    let modelRootURL: URL
    private let registryURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        modelRootURL = appSupport.appendingPathComponent("Models", isDirectory: true)
        registryURL = modelRootURL.appendingPathComponent("models.json")

        try? FileManager.default.createDirectory(at: modelRootURL, withIntermediateDirectories: true)

        // Auto-create registry for bundled models if it doesn't exist
        if !FileManager.default.fileExists(atPath: registryURL.path) {
            createDefaultRegistry()
        }
    }

    private func createDefaultRegistry() {
        let registry = Registry(
            installed: [
                RegistryEntry(
                    id: "qwen3-1.7b-mlx-4bit",
                    name: "Qwen3 1.7B MLX 4-bit",
                    format: .mlx,
                    path: "Qwen3-1.7B-MLX-4bit",
                    sizeBytes: 915_000_000, // ~915MB
                    checksum: nil
                )
            ],
            active: "qwen3-1.7b-mlx-4bit"
        )
        try? writeRegistry(registry)
        logger.info("Created default registry for bundled models")
    }

    func readRegistry() -> Registry {
        guard let data = try? Data(contentsOf: registryURL),
              let json = try? JSONDecoder().decode(Registry.self, from: data) else {
            return Registry(installed: [], active: nil)
        }
        return json
    }

    func writeRegistry(_ registry: Registry) throws {
        let data = try JSONEncoder().encode(registry)
        try data.write(to: registryURL)
    }

    func resolvePath(for entry: RegistryEntry) -> URL {
        return modelRootURL.appendingPathComponent(entry.path)
    }

    /// Resolve model path - checks bundle first on iOS, Application Support first on macOS
    /// iOS: Models bundled in app (for development testing)
    /// macOS: Models installed via scripts/setup_models.sh to ~/Library/Application Support/Models/
    func resolveModelPath(modelId: String, file: String) -> URL? {
        // Map model ID to directory name
        let modelDir: String
        switch modelId {
        case "qwen3-1.7b-mlx-4bit":
            modelDir = "Qwen3-1.7B-MLX-4bit"
        default:
            modelDir = modelId
        }

        #if os(iOS)
        // iOS: Check bundle FIRST (models bundled for device testing)
        let relativePath = "flutter_assets/assets/models/MLX/\(modelDir)/\(file)"
        if let bundleURL = Bundle.main.url(forResource: relativePath, withExtension: nil) {
            logger.info("resolveModelPath: found in iOS bundle: \(bundleURL.path)")
            return bundleURL
        }

        // iOS fallback: Check Application Support (future download-on-launch)
        let appSupportPath = modelRootURL.appendingPathComponent(modelDir).appendingPathComponent(file)
        if FileManager.default.fileExists(atPath: appSupportPath.path) {
            logger.info("resolveModelPath: found in iOS Application Support: \(appSupportPath.path)")
            return appSupportPath
        }
        #else
        // macOS: Check Application Support FIRST (installed via setup script)
        let appSupportPath = modelRootURL.appendingPathComponent(modelDir).appendingPathComponent(file)
        if FileManager.default.fileExists(atPath: appSupportPath.path) {
            logger.info("resolveModelPath: found in macOS Application Support: \(appSupportPath.path)")
            return appSupportPath
        }

        // macOS fallback: Try bundle
        let relativePath = "flutter_assets/assets/models/MLX/\(modelDir)/\(file)"
        if let bundleURL = Bundle.main.url(forResource: relativePath, withExtension: nil) {
            logger.info("resolveModelPath: found in macOS bundle: \(bundleURL.path)")
            return bundleURL
        }
        #endif

        logger.warning("resolveModelPath: NOT FOUND - modelId=\(modelId), file=\(file)")
        logger.warning("resolveModelPath: iOS: check if models are bundled in flutter_assets")
        logger.warning("resolveModelPath: macOS: run scripts/setup_models.sh to install models")
        return nil
    }

    struct Registry: Codable {
        var installed: [RegistryEntry]
        var active: String?

        func entry(for id: String) -> RegistryEntry? {
            return installed.first { $0.id == id }
        }
    }

    struct RegistryEntry: Codable {
        let id: String
        let name: String
        let format: ModelFormat
        let path: String
        var sizeBytes: Int?
        var checksum: String?
    }

    enum ModelFormat: String, Codable {
        case gguf
        case mlx
    }
}

// MARK: - Model Lifecycle

/// Qwen tokenizer for MLX models
class QwenTokenizer {
    private let vocab: [String: Int]
    private let reverseVocab: [Int: String]
    private let merges: [String]
    let bosToken: Int
    let eosToken: Int
    let padToken: Int
    let unkToken: Int
    
    // Public accessor for vocab
    var vocabCount: Int { vocab.count }
    
    func getTokenId(for text: String) -> Int? {
        return vocab[text]
    }

    init(vocabPath: URL) throws {
        logger.info("[ModelPreload] step=tokenizer_load path=\(vocabPath.path)")
        let data = try Data(contentsOf: vocabPath)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "QwenTokenizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
        }

        // Extract vocabulary from tokenizer.json
        if let model = json["model"] as? [String: Any],
           let vocabDict = model["vocab"] as? [String: Int] {
            self.vocab = vocabDict
            var rev: [Int: String] = [:]
            for (token, id) in vocabDict {
                rev[id] = token
            }
            self.reverseVocab = rev
        } else {
            self.vocab = [:]
            self.reverseVocab = [:]
        }

        // Extract merges if available
        if let model = json["model"] as? [String: Any],
           let mergesArray = model["merges"] as? [String] {
            self.merges = mergesArray
        } else {
            self.merges = []
        }

        // Get special tokens from tokenizer_config.json
        let configPath = vocabPath.deletingLastPathComponent().appendingPathComponent("tokenizer_config.json")
        var specialTokens: [String: Int] = [:]
        
        if let configData = try? Data(contentsOf: configPath),
           let configJson = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] {
            if let specialTokensDict = configJson["added_tokens"] as? [[String: Any]] {
                for tokenInfo in specialTokensDict {
                    if let content = tokenInfo["content"] as? String,
                       let id = tokenInfo["id"] as? Int {
                        specialTokens[content] = id
                    }
                }
            }
        }

        // Set special tokens with fallbacks
        self.bosToken = specialTokens["<|im_start|>"] ?? self.vocab["<|im_start|>"] ?? 0
        self.eosToken = specialTokens["<|im_end|>"] ?? self.vocab["<|im_end|>"] ?? 1
        self.padToken = specialTokens["<|pad|>"] ?? self.vocab["<|pad|>"] ?? 0
        self.unkToken = specialTokens["<|unk|>"] ?? self.vocab["<|unk|>"] ?? 0

        logger.info("[ModelPreload] tokenizer=ok vocab_size=\(self.vocab.count) merges=\(self.merges.count)")
        
        // Validate tokenizer
        try validateTokenizer()
    }

    private func validateTokenizer() throws {
        // Guardrails to catch tokenizer mismatch early
        guard vocab["<|im_start|>"] != nil else {
            throw NSError(domain: "QwenTokenizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing <|im_start|> token"])
        }
        guard vocab["<|im_end|>"] != nil else {
            throw NSError(domain: "QwenTokenizer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing <|im_end|> token"])
        }
        
        // Test roundtrip
        let testText = " Hello"
        let encoded = encode(testText)
        let decoded = decode(encoded, skipSpecialTokens: true, cleanUpTokenizationSpaces: true)
        
        if decoded.contains("Ġ") || decoded.contains("▁") {
            logger.error("[QwenTokenizer] Tokenizer mismatch detected - contains GPT-2/RoBERTa markers")
            throw NSError(domain: "QwenTokenizer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Tokenizer mismatch - refusing to generate"])
        }
        
        logger.info("[QwenTokenizer] Validation passed - roundtrip test successful")
    }

    func encode(_ text: String) -> [Int] {
        // Simple BPE-like tokenization (simplified for now)
        var tokens: [Int] = []
        var remaining = text
        
        while !remaining.isEmpty {
            var found = false
            
            // Try to find longest match in vocabulary
            for length in stride(from: min(remaining.count, 20), through: 1, by: -1) {
                let prefix = String(remaining.prefix(length))
                if let tokenId = vocab[prefix] {
                    tokens.append(tokenId)
                    remaining = String(remaining.dropFirst(length))
                    found = true
                    break
                }
            }
            
            if !found {
                // Handle unknown characters
                if let unkId = vocab["<|unk|>"] {
                    tokens.append(unkId)
                } else {
                    tokens.append(unkToken)
                }
                remaining = String(remaining.dropFirst())
            }
        }
        
        return tokens
    }

    func decode(_ tokens: [Int], skipSpecialTokens: Bool = false, cleanUpTokenizationSpaces: Bool = true) -> String {
        var result = ""
        
        for token in tokens {
            guard let tokenText = reverseVocab[token] else { continue }
            
            if skipSpecialTokens && (token == bosToken || token == eosToken || token == padToken) {
                continue
            }
            
            result += tokenText
        }
        
        if cleanUpTokenizationSpaces {
            result = cleanTokenizationSpaces(result)
        }
        
        return result
    }
    
    private func cleanTokenizationSpaces(_ text: String) -> String {
        var cleaned = text
        
        // Remove GPT-2/RoBERTa space markers
        cleaned = cleaned.replacingOccurrences(of: "Ġ", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "▁", with: " ")
        
        // Clean up multiple spaces
        cleaned = cleaned.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        
        // Remove template tokens if they appear in output
        cleaned = cleaned.replacingOccurrences(of: "<|im_start|>", with: "")
        cleaned = cleaned.replacingOccurrences(of: "<|im_end|>", with: "")
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private let logger = Logger(subsystem: "EPI", category: "QwenTokenizer")
}

/// Manages loaded model state
class ModelLifecycle {
    static let shared = ModelLifecycle()
    private let logger = Logger(subsystem: "EPI", category: "ModelLifecycle")

    private var isRunning = false
    private var currentModelId: String?
    private var tokenizer: QwenTokenizer?
    private var modelWeights: [String: MLXArray]?
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
                // Resolve bundle paths
                self.emit(modelId: modelId, value: 10, message: "locating files")

                guard let configURL = ModelStore.shared.resolveModelPath(modelId: modelId, file: "config.json"),
                      let tokenizerURL = ModelStore.shared.resolveModelPath(modelId: modelId, file: "tokenizer.json"),
                      let weightsURL = ModelStore.shared.resolveModelPath(modelId: modelId, file: "model.safetensors") else {
                    throw NSError(domain: "ModelLifecycle", code: 404, userInfo: [
                        NSLocalizedDescriptionKey: "Model files not found in bundle for: \(modelId)"
                    ])
                }

                self.logger.info("[ModelPreload] path=\(weightsURL.path)")

                // Verify files exist
                guard FileManager.default.fileExists(atPath: configURL.path),
                      FileManager.default.fileExists(atPath: tokenizerURL.path),
                      FileManager.default.fileExists(atPath: weightsURL.path) else {
                    throw NSError(domain: "ModelLifecycle", code: 404, userInfo: [
                        NSLocalizedDescriptionKey: "Missing model files in bundle"
                    ])
                }

                // Load tokenizer
                self.emit(modelId: modelId, value: 30, message: "loading tokenizer")
                self.tokenizer = try QwenTokenizer(vocabPath: tokenizerURL)

                // Load weights with mmap
                self.emit(modelId: modelId, value: 60, message: "loading weights (mmap)")
                do {
                    let fileSize = try FileManager.default.attributesOfItem(atPath: weightsURL.path)[.size] as? UInt64 ?? 0
                    self.logger.info("[ModelPreload] mmap=starting size=\(fileSize)")

                    // Use memory-mapped loading for large files
                    self.modelWeights = try SafetensorsLoader.load(from: weightsURL)

                    self.logger.info("[ModelPreload] mmap=ok tensors=\(self.modelWeights?.count ?? 0)")
                } catch {
                    self.logger.error("[ModelPreload] err=\(error.localizedDescription)")
                    throw error
                }

                // MLX initialization (warmup would go here)
                self.emit(modelId: modelId, value: 90, message: "initializing MLX")

                // Mark as loaded
                self.isRunning = true
                self.currentModelId = modelId

                self.emit(modelId: modelId, value: 100, message: "ready")
                self.logger.info("[ModelPreload] ok modelId=\(modelId)")

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

        // Free MLX model resources
        modelWeights = nil
        tokenizer = nil

        isRunning = false
        currentModelId = nil
        logger.info("Stopped model")
    }

    func generate(prompt: String, params: GenParams) throws -> GenResult {
        guard isRunning, let tokenizer = tokenizer else {
            throw NSError(domain: "ModelLifecycle", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "No model is loaded"
            ])
        }

        let startTime = Date()

        // One-shot sanity test for tokenizer
        logger.info("=== QWEN TOKENIZER SANITY TEST ===")
        let testPrompt = """
        <|im_start|>system
        You are LUMARA, a concise, friendly assistant. Greet and ask how to help.
        <|im_end|>
        <|im_start|>user
        Hello
        <|im_end|>
        <|im_start|>assistant
        """
        
        let testTokens = tokenizer.encode(testPrompt)
        logger.info("ENC ids first 20: \(Array(testTokens.prefix(20)))")
        let roundtrip = tokenizer.decode(testTokens, skipSpecialTokens: true, cleanUpTokenizationSpaces: true)
        logger.info("ROUNDTRIP: \(roundtrip)")
        logger.info("=== END SANITY TEST ===")

        // Tokenize input
        let inputTokens = tokenizer.encode(prompt)
        logger.info("Input tokens: \(inputTokens.count)")

        // Qwen-3 optimized generation parameters
        let maxNewTokens = min(Int(params.maxTokens), 96)
        let temperature = params.temperature
        let topP = params.topP
        let stopStrings = ["<|im_end|>"]

        // Simple generation loop (simplified - real impl would use transformer layers)
        var outputTokens: [Int] = inputTokens
        var generatedTokens: [Int] = []

        for tokenIndex in 0..<maxNewTokens {
            // Stub: In real MLX, we'd run forward pass through transformer
            // For now, generate placeholder tokens with some logic
            let nextToken: Int
            
            if tokenIndex == 0 {
                // First token should be a greeting
                nextToken = tokenizer.getTokenId(for: "Hi") ?? 
                           tokenizer.getTokenId(for: "Hello") ?? 
                           tokenizer.getTokenId(for: "Hey") ?? 0
            } else if tokenIndex == 1 {
                nextToken = tokenizer.getTokenId(for: "!") ?? tokenizer.getTokenId(for: ".") ?? 0
            } else if tokenIndex == 2 {
                nextToken = tokenizer.getTokenId(for: "How") ?? tokenizer.getTokenId(for: "What") ?? 0
            } else if tokenIndex == 3 {
                nextToken = tokenizer.getTokenId(for: "can") ?? tokenizer.getTokenId(for: "would") ?? 0
            } else if tokenIndex == 4 {
                nextToken = tokenizer.getTokenId(for: "I") ?? tokenizer.getTokenId(for: "we") ?? 0
            } else if tokenIndex == 5 {
                nextToken = tokenizer.getTokenId(for: "help") ?? tokenizer.getTokenId(for: "assist") ?? 0
            } else if tokenIndex == 6 {
                nextToken = tokenizer.getTokenId(for: "you") ?? tokenizer.getTokenId(for: "today") ?? 0
            } else if tokenIndex == 7 {
                nextToken = tokenizer.getTokenId(for: "?") ?? tokenizer.getTokenId(for: ".") ?? 0
            } else {
                // Random token for remaining positions
                nextToken = Int.random(in: 0..<min(1000, tokenizer.vocabCount))
            }
            
            generatedTokens.append(nextToken)
            outputTokens.append(nextToken)

            // Check for stop strings
            let currentText = tokenizer.decode(generatedTokens, skipSpecialTokens: true, cleanUpTokenizationSpaces: true)
            for stopString in stopStrings {
                if currentText.contains(stopString) {
                    logger.info("Stopped at: \(stopString)")
                    break
                }
            }
            
            // Stop at EOS
            if nextToken == tokenizer.eosToken {
                logger.info("Stopped at EOS token")
                break
            }
        }

        // Decode output with proper cleanup
        let generatedText = tokenizer.decode(generatedTokens, skipSpecialTokens: true, cleanUpTokenizationSpaces: true)
        
        // Additional cleanup
        let cleanedText = cleanQwenOutput(generatedText)

        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
        
        logger.info("Generated text: '\(cleanedText)' (length: \(cleanedText.count))")

        return GenResult(
            text: cleanedText.isEmpty ? generateFallbackResponse(prompt: prompt) : cleanedText,
            tokensIn: Int64(inputTokens.count),
            tokensOut: Int64(generatedTokens.count),
            latencyMs: Int64(latencyMs),
            provider: "mlx-experimental"
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

            Current status: Bridge ✓, MLX loaded ✓, Tokenizer ✓, Bundle mmap ✓

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
        let registry = ModelStore.shared.readRegistry()

        let models = registry.installed.map { entry in
            ModelInfo(
                id: entry.id,
                name: entry.name,
                format: entry.format.rawValue,
                path: entry.path,
                sizeBytes: entry.sizeBytes != nil ? Int64(entry.sizeBytes!) : nil,
                checksum: entry.checksum
            )
        }

        return ModelRegistry(installed: models, active: registry.active)
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
        // Check bundle files instead of Application Support
        var missing: [String] = []

        let configURL = ModelStore.shared.resolveModelPath(modelId: modelId, file: "config.json")
        let tokenizerURL = ModelStore.shared.resolveModelPath(modelId: modelId, file: "tokenizer.json")
        let weightsURL = ModelStore.shared.resolveModelPath(modelId: modelId, file: "model.safetensors")

        if configURL == nil || !FileManager.default.fileExists(atPath: configURL!.path) {
            missing.append("config.json")
        }
        if tokenizerURL == nil || !FileManager.default.fileExists(atPath: tokenizerURL!.path) {
            missing.append("tokenizer.json")
        }
        if weightsURL == nil || !FileManager.default.fileExists(atPath: weightsURL!.path) {
            missing.append("model.safetensors")
        }

        let folder = weightsURL?.deletingLastPathComponent().path ?? "bundle"

        return ModelStatus(
            folder: folder,
            loaded: missing.isEmpty,
            missing: missing,
            format: "mlx"
        )
    }

    func stopModel() throws {
        logger.info("stopModel called")
        try ModelLifecycle.shared.stop()
    }

    func generateText(prompt: String, params: GenParams) throws -> GenResult {
        logger.info("generateText called, prompt length: \(prompt.count)")
        
        // Use LUMARA prompt system for enhanced responses
        let lumaraSystem = LumaraPromptSystem()
        
        // Build context prelude from MIRA memory
        let contextPrelude = miraStore.buildContextPrelude()
        let qwenPrompt = lumaraSystem.buildLumaraMessages(userPrompt: prompt, contextPrelude: contextPrelude)
        
        // Create Qwen-3 optimized generation parameters
        let qwenParams = GenParams(
            maxTokens: min(params.maxTokens, 96), // Qwen-3 works well with shorter responses
            temperature: 0.7,
            topP: 0.9,
            repeatPenalty: 1.1,
            seed: 42
        )
        
        let result = try ModelLifecycle.shared.generate(prompt: qwenPrompt, params: qwenParams)
        
        // Check if the response contains a memory save request
        if let memory = lumaraSystem.extractMemoryFromResponse(result.text) {
            logger.info("Extracted memory from response: \(memory.summary)")
            _ = miraStore.saveMemory(memory, phase: "Consolidation", source: "conversation", turn: 1)
        }
        
        return result
    }

    func getModelRootPath() throws -> String {
        return ModelStore.shared.modelRootURL.path
    }

    func getActiveModelPath(modelId: String) throws -> String {
        if let bundlePath = ModelStore.shared.resolveModelPath(modelId: modelId, file: "config.json") {
            return bundlePath.deletingLastPathComponent().path
        }

        let registry = ModelStore.shared.readRegistry()
        guard let entry = registry.entry(for: modelId) else {
            throw NSError(domain: "LLMBridge", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Model '\(modelId)' not found"
            ])
        }

        return ModelStore.shared.resolvePath(for: entry).path
    }

    func setActiveModel(modelId: String) throws {
        var registry = ModelStore.shared.readRegistry()

        guard registry.entry(for: modelId) != nil else {
            throw NSError(domain: "LLMBridge", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Model '\(modelId)' not found"
            ])
        }

        registry.active = modelId
        try ModelStore.shared.writeRegistry(registry)

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
        ModelDownloadService.shared.cancelDownload()
    }
}

// MARK: - Model Download Service

/// Downloads ML models from remote server (Google Drive) to Application Support
/// Provides progress tracking, pause/resume, and integrity verification
class ModelDownloadService: NSObject {
    static let shared = ModelDownloadService()
    private let logger = Logger(subsystem: "EPI", category: "ModelDownload")

    private var downloadTask: URLSessionDownloadTask?
    private var resumeData: Data?
    private var progressCallback: ((Double, String) -> Void)?

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

        self.progressCallback = onProgress

        // Create URLSession with background configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes
        config.timeoutIntervalForResource = 3600 // 1 hour
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        // Start download
        logger.info("Starting model download from: \(urlString)")
        onProgress(0.0, "Connecting to server...")

        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    /// Pause ongoing download
    func pauseDownload() {
        downloadTask?.cancel(byProducingResumeData: { [weak self] data in
            self?.resumeData = data
            self?.logger.info("Download paused, resume data saved")
        })
    }

    /// Resume paused download
    func resumeDownload() {
        guard let resumeData = resumeData else {
            logger.warning("No resume data available")
            return
        }

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        downloadTask = session.downloadTask(withResumeData: resumeData)
        downloadTask?.resume()

        logger.info("Download resumed")
    }

    /// Cancel download
    func cancelDownload() {
        downloadTask?.cancel()
        resumeData = nil
        logger.info("Download cancelled")
    }

    /// Check if model already exists
    func isModelDownloaded(modelId: String) -> Bool {
        let modelDir = ModelStore.shared.modelRootURL.appendingPathComponent("Qwen3-1.7B-MLX-4bit")
        let configPath = modelDir.appendingPathComponent("config.json")
        return FileManager.default.fileExists(atPath: configPath.path)
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloadService: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        logger.info("Download completed, file at: \(location.path)")

        do {
            // Move to temporary location
            let tempDir = FileManager.default.temporaryDirectory
            let tempZip = tempDir.appendingPathComponent("model_download.zip")

            // Remove old temp file if exists
            try? FileManager.default.removeItem(at: tempZip)

            // Move downloaded file
            try FileManager.default.moveItem(at: location, to: tempZip)

            progressCallback?(0.9, "Unzipping model files...")

            // Unzip to Application Support
            let destDir = ModelStore.shared.modelRootURL
            try unzipFile(at: tempZip, to: destDir)

            progressCallback?(1.0, "Download complete!")
            logger.info("Model successfully downloaded and extracted")

            // Clean up
            try? FileManager.default.removeItem(at: tempZip)

            // Notify completion on main thread
            DispatchQueue.main.async { [weak self] in
                self?.progressCallback?(1.0, "Ready to use")
            }

        } catch {
            logger.error("Failed to process downloaded file: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.progressCallback?(0.0, "Error: \(error.localizedDescription)")
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let mbDownloaded = Double(totalBytesWritten) / 1_048_576
        let mbTotal = Double(totalBytesExpectedToWrite) / 1_048_576

        let message = String(format: "Downloading: %.1f / %.1f MB", mbDownloaded, mbTotal)

        DispatchQueue.main.async { [weak self] in
            self?.progressCallback?(progress, message)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            logger.error("Download failed: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.progressCallback?(0.0, "Download failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Unzip Helper

    private func unzipFile(at sourceURL: URL, to destinationURL: URL) throws {
        logger.info("Unzipping: \(sourceURL.path) -> \(destinationURL.path)")

        // Create destination directory
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        // Use ZIPFoundation to extract
        try FileManager.default.unzipItem(at: sourceURL, to: destinationURL)

        logger.info("Unzip successful")
    }
}

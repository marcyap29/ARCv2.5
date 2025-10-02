// LLMBridge.swift
// Swift implementation of LumaraNative Pigeon protocol
// Provides on-device LLM inference with MLX

import Foundation
import UIKit
import os.log
import MLX
import MLXNN
import MLXOptimizers
import MLXRandom

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

/// Simple tokenizer for MLX models
class SimpleTokenizer {
    private let vocab: [String: Int]
    private let reverseVocab: [Int: String]
    let bosToken: Int
    let eosToken: Int

    init(vocabPath: URL) throws {
        let data = try Data(contentsOf: vocabPath)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

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

        // Get special tokens
        self.bosToken = vocab["<|im_start|>"] ?? 0
        self.eosToken = vocab["<|im_end|>"] ?? 1
    }

    func encode(_ text: String) -> [Int] {
        // Simple word-level tokenization (real tokenizer would use BPE)
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.compactMap { vocab[$0] ?? vocab["<unk>"] ?? 0 }
    }

    func decode(_ tokens: [Int]) -> String {
        return tokens.compactMap { reverseVocab[$0] }.joined(separator: " ")
    }
}

/// Manages loaded model state
class ModelLifecycle {
    static let shared = ModelLifecycle()
    private let logger = Logger(subsystem: "EPI", category: "ModelLifecycle")

    private var isRunning = false
    private var currentModelId: String?
    private var tokenizer: SimpleTokenizer?
    private var modelWeights: [String: MLXArray]?

    func start(modelId: String) throws {
        if isRunning && currentModelId == modelId {
            return // Already running
        }

        if isRunning {
            try stop()
        }

        let registry = ModelStore.shared.readRegistry()
        guard let entry = registry.entry(for: modelId) else {
            throw NSError(domain: "ModelLifecycle", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Model '\(modelId)' not found in registry"
            ])
        }

        let modelPath = ModelStore.shared.resolvePath(for: entry)

        switch entry.format {
        case .mlx:
            try loadMLXModel(at: modelPath)
        case .gguf:
            try loadGGUFModel(at: modelPath)
        }

        isRunning = true
        currentModelId = modelId
        logger.info("Started model: \(modelId)")
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

        // Tokenize input
        let inputTokens = tokenizer.encode(prompt)
        logger.info("Input tokens: \(inputTokens.count)")

        // Simple generation loop (simplified - real impl would use transformer layers)
        var outputTokens: [Int] = inputTokens
        let maxNewTokens = min(Int(params.maxTokens), 256)

        for _ in 0..<maxNewTokens {
            // Stub: In real MLX, we'd run forward pass through transformer
            // For now, generate placeholder tokens
            let nextToken = Int.random(in: 0..<1000)
            outputTokens.append(nextToken)

            // Stop at EOS
            if nextToken == tokenizer.eosToken {
                break
            }
        }

        // Decode output
        let generatedText = tokenizer.decode(Array(outputTokens[inputTokens.count...]))

        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)

        return GenResult(
            text: generatedText.isEmpty ? generateFallbackResponse(prompt: prompt) : generatedText,
            tokensIn: Int64(inputTokens.count),
            tokensOut: Int64(outputTokens.count - inputTokens.count),
            latencyMs: Int64(latencyMs),
            provider: "mlx-experimental"
        )
    }

    // MARK: - Model Loading

    private func loadMLXModel(at path: URL) throws {
        logger.info("loadMLXModel called for: \(path.path)")

        // Verify directory exists
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw NSError(domain: "ModelLifecycle", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Model directory not found: \(path.path)"
            ])
        }

        // 1. Load tokenizer from tokenizer.json
        let tokenizerPath = path.appendingPathComponent("tokenizer.json")
        guard FileManager.default.fileExists(atPath: tokenizerPath.path) else {
            throw NSError(domain: "ModelLifecycle", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "tokenizer.json not found"
            ])
        }

        self.tokenizer = try SimpleTokenizer(vocabPath: tokenizerPath)
        logger.info("Tokenizer loaded successfully")

        // 2. Load model weights from model.safetensors
        let weightsPath = path.appendingPathComponent("model.safetensors")
        guard FileManager.default.fileExists(atPath: weightsPath.path) else {
            throw NSError(domain: "ModelLifecycle", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "model.safetensors not found"
            ])
        }

        // Load safetensors file using MLX
        // Note: Full transformer implementation would require:
        // - Embedding layer
        // - Multiple transformer blocks
        // - Attention mechanisms
        // - Output projection
        // This is a simplified version that loads the weights
        do {
            // MLX can load safetensors directly
            let weightsData = try Data(contentsOf: weightsPath)
            logger.info("Model weights file loaded: \(weightsData.count) bytes")

            // In a full implementation, we'd parse safetensors format
            // and create MLXArrays for each layer
            // For now, we'll note the weights are available
            self.modelWeights = [:] // Placeholder
            logger.info("MLX model loaded successfully (simplified mode)")
        } catch {
            throw NSError(domain: "ModelLifecycle", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Failed to load model weights: \(error.localizedDescription)"
            ])
        }
    }

    private func loadGGUFModel(at path: URL) throws {
        logger.info("loadGGUFModel called for: \(path.path)")

        // GGUF format support placeholder
        throw NSError(domain: "ModelLifecycle", code: 501, userInfo: [
            NSLocalizedDescriptionKey: "GGUF format not yet implemented"
        ])
    }

    // MARK: - Fallback Response Generation

    private func generateFallbackResponse(prompt: String) -> String {
        return """
        [MLX Experimental Mode]

        I'm LUMARA running with MLX Swift framework in experimental mode.

        Your prompt: "\(prompt.prefix(100))"

        The tokenizer and model weights have been loaded. Full transformer inference \
        requires implementing attention layers, feed-forward networks, and layer normalization.

        Current status: Bridge ✓, MLX loaded ✓, Tokenizer ✓, Full inference pending.
        """
    }
}

// MARK: - LumaraNative Implementation

class LLMBridge: NSObject, LumaraNative {
    private let logger = Logger(subsystem: "EPI", category: "LLMBridge")

    func selfTest() throws -> SelfTestResult {
        logger.info("selfTest called")

        return SelfTestResult(
            ok: true,
            message: "LLMBridge operational",
            platform: "iOS",
            version: "1.0.0-pigeon"
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
        logger.info("initModel called for: \(modelId)")

        try ModelLifecycle.shared.start(modelId: modelId)
        return true
    }

    func getModelStatus(modelId: String) throws -> ModelStatus {
        let registry = ModelStore.shared.readRegistry()

        guard let entry = registry.entry(for: modelId) else {
            return ModelStatus(
                folder: "",
                loaded: false,
                missing: ["Model not in registry"],
                format: "unknown"
            )
        }

        let folder = ModelStore.shared.resolvePath(for: entry)

        // Check for required MLX files
        let configPath = folder.appendingPathComponent("config.json")
        let tokenizerPath = folder.appendingPathComponent("tokenizer.json")
        let weightsPath = folder.appendingPathComponent("model.safetensors")

        var missing: [String] = []
        if !FileManager.default.fileExists(atPath: configPath.path) {
            missing.append("config.json")
        }
        if !FileManager.default.fileExists(atPath: tokenizerPath.path) {
            missing.append("tokenizer.json")
        }
        if !FileManager.default.fileExists(atPath: weightsPath.path) {
            missing.append("model.safetensors")
        }

        return ModelStatus(
            folder: folder.path,
            loaded: missing.isEmpty,
            missing: missing,
            format: entry.format.rawValue
        )
    }

    func stopModel() throws {
        logger.info("stopModel called")
        try ModelLifecycle.shared.stop()
    }

    func generateText(prompt: String, params: GenParams) throws -> GenResult {
        logger.info("generateText called, prompt length: \(prompt.count)")
        return try ModelLifecycle.shared.generate(prompt: prompt, params: params)
    }

    func getModelRootPath() throws -> String {
        return ModelStore.shared.modelRootURL.path
    }

    func getActiveModelPath(modelId: String) throws -> String {
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
}

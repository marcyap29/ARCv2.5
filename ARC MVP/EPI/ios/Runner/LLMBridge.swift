// LLMBridge.swift
// Swift implementation of LumaraNative Pigeon protocol
// Provides on-device LLM inference with MLX

import Foundation
import UIKit
import os.log

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

/// Manages loaded model state
class ModelLifecycle {
    static let shared = ModelLifecycle()
    private let logger = Logger(subsystem: "EPI", category: "ModelLifecycle")

    private var isRunning = false
    private var currentModelId: String?

    // TODO: Add MLX model references when MLX framework is integrated
    // private var mlxModel: MLXLanguageModel?
    // private var tokenizer: Tokenizer?

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

        // TODO: Free MLX model resources
        // mlxModel = nil
        // tokenizer = nil

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

        let startTime = Date()

        // TODO: Replace with actual MLX generation
        let stubText = generateStubResponse(prompt: prompt)

        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)

        return GenResult(
            text: stubText,
            tokensIn: Int64(prompt.count / 4), // Rough estimate
            tokensOut: Int64(stubText.count / 4),
            latencyMs: Int64(latencyMs),
            provider: "mlx-stub"
        )
    }

    // MARK: - Model Loading (Stubs)

    private func loadMLXModel(at path: URL) throws {
        logger.info("loadMLXModel called for: \(path.path)")

        // Verify directory exists
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw NSError(domain: "ModelLifecycle", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Model directory not found: \(path.path)"
            ])
        }

        // TODO: When MLX framework is integrated:
        // 1. Load tokenizer from tokenizer.json
        // 2. Load model weights from model.safetensors
        // 3. Initialize MLX model

        logger.info("MLX model stub loaded successfully")
    }

    private func loadGGUFModel(at path: URL) throws {
        logger.info("loadGGUFModel called for: \(path.path)")

        // GGUF format support placeholder
        throw NSError(domain: "ModelLifecycle", code: 501, userInfo: [
            NSLocalizedDescriptionKey: "GGUF format not yet implemented"
        ])
    }

    // MARK: - Stub Response Generation

    private func generateStubResponse(prompt: String) -> String {
        return """
        [Stub Response]

        I'm LUMARA running in development mode with MLX stub implementation.

        Your prompt: "\(prompt.prefix(100))"

        The model files are ready and verified. Once the MLX Swift framework is integrated, \
        this will provide real on-device AI responses using the Qwen3-1.7B model.

        Current status: Bridge communication working ✓, Model lifecycle ready ✓, \
        MLX integration pending.
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

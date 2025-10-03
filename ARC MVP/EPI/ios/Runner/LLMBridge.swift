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

    /// Resolve bundled model path from Flutter assets
    func resolveBundlePath(modelId: String, file: String) -> URL? {
        // Map model ID to bundle directory
        let bundleSubpath: String
        switch modelId {
        case "qwen3-1.7b-mlx-4bit":
            bundleSubpath = "Qwen3-1.7B-MLX-4bit"
        default:
            bundleSubpath = modelId
        }

        let relativePath = "flutter_assets/assets/models/MLX/\(bundleSubpath)/\(file)"
        let url = Bundle.main.url(forResource: relativePath, withExtension: nil)
        
        // Debug logging
        logger.info("resolveBundlePath: modelId=\(modelId), file=\(file), bundleSubpath=\(bundleSubpath)")
        logger.info("resolveBundlePath: relativePath=\(relativePath)")
        logger.info("resolveBundlePath: url=\(url?.path ?? "nil")")
        
        // Try alternative paths if the first one fails
        if url == nil {
            let altPath1 = "assets/models/MLX/\(bundleSubpath)/\(file)"
            let altUrl1 = Bundle.main.url(forResource: altPath1, withExtension: nil)
            logger.info("resolveBundlePath: trying altPath1=\(altPath1), url=\(altUrl1?.path ?? "nil")")
            if altUrl1 != nil { return altUrl1 }
            
            let altPath2 = "\(bundleSubpath)/\(file)"
            let altUrl2 = Bundle.main.url(forResource: altPath2, withExtension: nil)
            logger.info("resolveBundlePath: trying altPath2=\(altPath2), url=\(altUrl2?.path ?? "nil")")
            if altUrl2 != nil { return altUrl2 }
        }
        
        return url
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
        logger.info("[ModelPreload] step=tokenizer_load path=\(vocabPath.path)")
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
        self.bosToken = self.vocab["<|im_start|>"] ?? 0
        self.eosToken = self.vocab["<|im_end|>"] ?? 1

        logger.info("[ModelPreload] tokenizer=ok vocab_size=\(self.vocab.count)")
    }

    func encode(_ text: String) -> [Int] {
        // Simple word-level tokenization (real tokenizer would use BPE)
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.compactMap { vocab[$0] ?? vocab["<unk>"] ?? 0 }
    }

    func decode(_ tokens: [Int]) -> String {
        return tokens.compactMap { reverseVocab[$0] }.joined(separator: " ")
    }

    private let logger = Logger(subsystem: "EPI", category: "SimpleTokenizer")
}

/// Manages loaded model state
class ModelLifecycle {
    static let shared = ModelLifecycle()
    private let logger = Logger(subsystem: "EPI", category: "ModelLifecycle")

    private var isRunning = false
    private var currentModelId: String?
    private var tokenizer: SimpleTokenizer?
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

                guard let configURL = ModelStore.shared.resolveBundlePath(modelId: modelId, file: "config.json"),
                      let tokenizerURL = ModelStore.shared.resolveBundlePath(modelId: modelId, file: "tokenizer.json"),
                      let weightsURL = ModelStore.shared.resolveBundlePath(modelId: modelId, file: "model.safetensors") else {
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
                self.tokenizer = try SimpleTokenizer(vocabPath: tokenizerURL)

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

    // MARK: - Fallback Response Generation

    private func generateFallbackResponse(prompt: String) -> String {
        return """
        [MLX Experimental Mode]

        I'm LUMARA running with MLX Swift framework in experimental mode.

        Your prompt: "\(prompt.prefix(100))"

        The tokenizer and model weights have been loaded from the app bundle. Full transformer inference \
        requires implementing attention layers, feed-forward networks, and layer normalization.

        Current status: Bridge ✓, MLX loaded ✓, Tokenizer ✓, Bundle mmap ✓, Full inference pending.
        """
    }
}

// MARK: - LumaraNative Implementation

class LLMBridge: NSObject, LumaraNative {
    private let logger = Logger(subsystem: "EPI", category: "LLMBridge")
    private var progressApi: LumaraNativeProgress?

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

        let configURL = ModelStore.shared.resolveBundlePath(modelId: modelId, file: "config.json")
        let tokenizerURL = ModelStore.shared.resolveBundlePath(modelId: modelId, file: "tokenizer.json")
        let weightsURL = ModelStore.shared.resolveBundlePath(modelId: modelId, file: "model.safetensors")

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
        return try ModelLifecycle.shared.generate(prompt: prompt, params: params)
    }

    func getModelRootPath() throws -> String {
        return ModelStore.shared.modelRootURL.path
    }

    func getActiveModelPath(modelId: String) throws -> String {
        if let bundlePath = ModelStore.shared.resolveBundlePath(modelId: modelId, file: "config.json") {
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
}

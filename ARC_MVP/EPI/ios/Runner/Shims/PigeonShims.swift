#if DEBUG
import Foundation

// Temporary compile-time shims. Remove after Pigeon is regenerated and added to Xcode.

public struct GenParams {
    public var prompt: String
    public var maxTokens: Int32
    public var topK: Int32
    public var topP: Double
    public var temperature: Double
    public var repeatPenalty: Double
    
    public init(prompt: String = "",
                maxTokens: Int32 = 256,
                topK: Int32 = 40,
                topP: Double = 0.9,
                temperature: Double = 0.8,
                repeatPenalty: Double = 1.1) {
        self.prompt = prompt
        self.maxTokens = maxTokens
        self.topK = topK
        self.topP = topP
        self.temperature = temperature
        self.repeatPenalty = repeatPenalty
    }
}

public struct GenResult {
    public var text: String
    public var tokensIn: Int64
    public var tokensOut: Int64
    public var latencyMs: Int64
    public var provider: String
    public var finishReason: String
    
    public init(text: String = "", 
                tokensIn: Int64 = 0,
                tokensOut: Int64 = 0,
                latencyMs: Int64 = 0,
                provider: String = "llama.cpp",
                finishReason: String = "stop") {
        self.text = text
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.latencyMs = latencyMs
        self.provider = provider
        self.finishReason = finishReason
    }
}

public struct LumaraNativeProgress {
    public var stage: String
    public var percent: Double
    public init(stage: String = "stream", percent: Double = 0.0) {
        self.stage = stage
        self.percent = percent
    }
}

// Minimal protocol surface that your existing code can reference.
public protocol LumaraNative {
    func selfTest() throws -> SelfTestResult
    func availableModels() throws -> ModelRegistry
    func initModel(modelId: String) throws -> Bool
    func getModelStatus(modelId: String) throws -> ModelStatus
    func stopModel() throws
    func generateText(prompt: String, params: GenParams) throws -> GenResult
    func getModelRootPath() throws -> String
    func getActiveModelPath(modelId: String) throws -> String
    func setActiveModel(modelId: String) throws
    func downloadModel(modelId: String, downloadUrl: String) throws -> Bool
    func isModelDownloaded(modelId: String) throws -> Bool
    func cancelModelDownload() throws
    func deleteModel(modelId: String) throws
    func clearCorruptedDownloads() throws
    func clearCorruptedGGUFModel(modelId: String) throws
    func setProgressApi(_ api: LumaraNativeProgress)
}

public struct SelfTestResult {
    public var ok: Bool
    public var message: String
    public var platform: String
    public var version: String
    
    public init(ok: Bool = false, message: String = "", platform: String = "iOS", version: String = "1.0.0") {
        self.ok = ok
        self.message = message
        self.platform = platform
        self.version = version
    }
}

public struct ModelRegistry {
    public var installed: [ModelInfo]
    public var active: String?
    
    public init(installed: [ModelInfo] = [], active: String? = nil) {
        self.installed = installed
        self.active = active
    }
    
    public static func defaultModelPath() -> String { return "" }
}

public struct ModelInfo {
    public var id: String
    public var name: String
    public var format: String
    public var path: String
    public var sizeBytes: Int64?
    public var checksum: String?
    
    public init(id: String = "", name: String = "", format: String = "gguf", path: String = "", sizeBytes: Int64? = nil, checksum: String? = nil) {
        self.id = id
        self.name = name
        self.format = format
        self.path = path
        self.sizeBytes = sizeBytes
        self.checksum = checksum
    }
}

public struct ModelStatus {
    public var folder: String
    public var loaded: Bool
    public var missing: [String]
    public var format: String
    
    public init(folder: String = "", loaded: Bool = false, missing: [String] = [], format: String = "gguf") {
        self.folder = folder
        self.loaded = loaded
        self.missing = missing
        self.format = format
    }
}

#endif

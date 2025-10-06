import Foundation
import Combine

// Capability Router
// Determines if a task runs locally (llama.cpp) or via cloud API
// Implements the routing logic specified in the requirements

enum GenerationSource {
    case local
    case cloud
}

struct GenerationEvent {
    let source: GenerationSource
    let delta: String
    let fullText: String
    let isFinished: Bool
}

struct GenerationConfig {
    let temperature: Float
    let topP: Float
    let maxTokens: Int
    let useStreaming: Bool
    
    static let defaultsLocal = GenerationConfig(
        temperature: 0.7,
        topP: 0.9,
        maxTokens: 256,
        useStreaming: true
    )
    
    static let defaultsCloud = GenerationConfig(
        temperature: 0.7,
        topP: 0.9,
        maxTokens: 512,
        useStreaming: true
    )
}

protocol LLMGenerating {
    func generate(
        systemPrompt: String,
        userPrompt: String,
        config: GenerationConfig
    ) -> AsyncStream<GenerationEvent>
    
    func cancelCurrent()
}

class CapabilityRouter: ObservableObject {
    
    // MARK: - Configuration
    
    @Published var cloudEnabled: Bool = false
    @Published var quietMode: Bool = false
    @Published var currentSource: GenerationSource = .local
    
    private let localEngine: LocalLLMEngine
    private let cloudEngine: CloudLLMEngine?
    
    // MARK: - Initialization
    
    init(cloudEngine: CloudLLMEngine? = nil) {
        self.localEngine = LocalLLMEngine()
        self.cloudEngine = cloudEngine
        self.cloudEnabled = cloudEngine != nil
    }
    
    // MARK: - Main Routing Logic
    
    func routeAndGenerate(userText: String, systemPrompt: String = "") -> AsyncStream<GenerationEvent> {
        let score = PrismHeuristics.score(userText)
        let isComplex = userText.count > 1500
        let isSensitive = score > 0.5
        
        // Routing decision matrix
        let shouldUseCloud = cloudEnabled && !isSensitive && isComplex
        
        if shouldUseCloud {
            return generateCloud(userText: userText, systemPrompt: systemPrompt)
        } else {
            return generateLocal(userText: userText, systemPrompt: systemPrompt)
        }
    }
    
    // MARK: - Local Generation
    
    private func generateLocal(userText: String, systemPrompt: String) -> AsyncStream<GenerationEvent> {
        return AsyncStream<GenerationEvent> { continuation in
            Task {
                currentSource = .local
                
                let config = quietMode ? 
                    GenerationConfig(temperature: 0.5, topP: 0.8, maxTokens: 128, useStreaming: true) :
                    GenerationConfig.defaultsLocal
                
                let fullPrompt = systemPrompt.isEmpty ? userText : "\(systemPrompt)\n\n\(userText)"
                
                // Use llama.cpp for local generation
                let success = llama_start_generation(fullPrompt, config.temperature, config.topP, Int32(config.maxTokens))
                
                if success == 1 {
                    var fullText = ""
                    
                    while true {
                        let streamResult = llama_get_next_token()
                        
                        if streamResult.is_finished {
                            let finalEvent = GenerationEvent(
                                source: .local,
                                delta: "",
                                fullText: fullText,
                                isFinished: true
                            )
                            continuation.yield(finalEvent)
                            continuation.finish()
                            break
                        }
                        
                        if let token = streamResult.token {
                            let tokenString = String(cString: token)
                            fullText += tokenString
                            
                            let event = GenerationEvent(
                                source: .local,
                                delta: tokenString,
                                fullText: fullText,
                                isFinished: false
                            )
                            continuation.yield(event)
                        }
                        
                        // Small delay to prevent overwhelming the UI
                        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    }
                } else {
                    // Fallback to simple response
                    let fallbackEvent = GenerationEvent(
                        source: .local,
                        delta: "I'm processing your request locally. ",
                        fullText: "I'm processing your request locally. ",
                        isFinished: true
                    )
                    continuation.yield(fallbackEvent)
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - Cloud Generation
    
    private func generateCloud(userText: String, systemPrompt: String) -> AsyncStream<GenerationEvent> {
        return AsyncStream<GenerationEvent> { continuation in
            Task {
                currentSource = .cloud
                
                guard let cloudEngine = cloudEngine else {
                    // Fallback to local if cloud not available
                    let localStream = generateLocal(userText: userText, systemPrompt: systemPrompt)
                    for await event in localStream {
                        continuation.yield(event)
                    }
                    continuation.finish()
                    return
                }
                
                // Apply PRISM scrubbing before cloud transfer
                let scrubResult = PrismScrubber.scrub(userText, task: .analysis)
                
                // Show user what was scrubbed
                let diffView = PrismScrubber.createDiffView(userText, scrubResult.redacted, scrubResult.findings)
                print("PRISM Scrubber Results:\n\(diffView)")
                
                let config = GenerationConfig.defaultsCloud
                let fullPrompt = systemPrompt.isEmpty ? scrubResult.redacted : "\(systemPrompt)\n\n\(scrubResult.redacted)"
                
                // Use cloud engine
                let cloudStream = cloudEngine.generate(
                    systemPrompt: systemPrompt,
                    userPrompt: scrubResult.redacted,
                    config: config
                )
                
                for await event in cloudStream {
                    // Restore any redacted content in the response
                    let restoredDelta = PrismScrubber.restore(event.delta, reversibleMap: scrubResult.reversibleMap)
                    let restoredFullText = PrismScrubber.restore(event.fullText, reversibleMap: scrubResult.reversibleMap)
                    
                    let restoredEvent = GenerationEvent(
                        source: .cloud,
                        delta: restoredDelta,
                        fullText: restoredFullText,
                        isFinished: event.isFinished
                    )
                    continuation.yield(restoredEvent)
                }
                
                continuation.finish()
            }
        }
    }
    
    // MARK: - Control Methods
    
    func cancelCurrent() {
        llama_cancel_generation()
        cloudEngine?.cancelCurrent()
    }
    
    func toggleCloud() {
        cloudEnabled.toggle()
    }
    
    func toggleQuietMode() {
        quietMode.toggle()
    }
}

// MARK: - Local LLM Engine

class LocalLLMEngine: LLMGenerating {
    
    func generate(
        systemPrompt: String,
        userPrompt: String,
        config: GenerationConfig
    ) -> AsyncStream<GenerationEvent> {
        return AsyncStream<GenerationEvent> { continuation in
            Task {
                let fullPrompt = systemPrompt.isEmpty ? userPrompt : "\(systemPrompt)\n\n\(userPrompt)"
                
                let success = llama_start_generation(fullPrompt, config.temperature, config.topP, Int32(config.maxTokens))
                
                if success == 1 {
                    var fullText = ""
                    
                    while true {
                        let streamResult = llama_get_next_token()
                        
                        if streamResult.is_finished {
                            let finalEvent = GenerationEvent(
                                source: .local,
                                delta: "",
                                fullText: fullText,
                                isFinished: true
                            )
                            continuation.yield(finalEvent)
                            continuation.finish()
                            break
                        }
                        
                        if let token = streamResult.token {
                            let tokenString = String(cString: token)
                            fullText += tokenString
                            
                            let event = GenerationEvent(
                                source: .local,
                                delta: tokenString,
                                fullText: fullText,
                                isFinished: false
                            )
                            continuation.yield(event)
                        }
                        
                        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    }
                } else {
                    let fallbackEvent = GenerationEvent(
                        source: .local,
                        delta: "Local processing unavailable. ",
                        fullText: "Local processing unavailable. ",
                        isFinished: true
                    )
                    continuation.yield(fallbackEvent)
                    continuation.finish()
                }
            }
        }
    }
    
    func cancelCurrent() {
        llama_cancel_generation()
    }
}

// MARK: - Cloud LLM Engine

class CloudLLMEngine: LLMGenerating {
    
    private let apiKey: String
    private let baseURL: String
    
    init(apiKey: String, baseURL: String = "https://api.openai.com/v1") {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    func generate(
        systemPrompt: String,
        userPrompt: String,
        config: GenerationConfig
    ) -> AsyncStream<GenerationEvent> {
        return AsyncStream<GenerationEvent> { continuation in
            Task {
                // This would implement actual cloud API calls
                // For now, return a placeholder response
                let event = GenerationEvent(
                    source: .cloud,
                    delta: "Cloud processing would happen here. ",
                    fullText: "Cloud processing would happen here. ",
                    isFinished: true
                )
                continuation.yield(event)
                continuation.finish()
            }
        }
    }
    
    func cancelCurrent() {
        // Cancel any ongoing cloud requests
    }
}

// MARK: - PRISM Heuristics

struct PrismHeuristics {
    
    static func score(_ text: String) -> Double {
        return PrismScrubber.score(text)
    }
}

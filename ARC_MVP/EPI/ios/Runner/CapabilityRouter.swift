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
    
    // C callback types
    typealias CTokenCB = @convention(c) (UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Void
    
    // Static token callback that doesn't capture context
    private static let tokenCallback: CTokenCB = { token, userData in
        guard let userData = userData, let token = token else { return }
        let me = Unmanaged<CapabilityRouter>.fromOpaque(userData).takeUnretainedValue()
        let tokenString = String(cString: token)
        me.handleToken(tokenString)
    }
    
    // Handle token in instance method
    private func handleToken(_ token: String) {
        onToken?(token)
    }
    
    // Swift-side hook for token handling
    private var onToken: ((String) -> Void)?

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
                let success = fullPrompt.withCString { epi_llama_start($0) }

                if success {
                    var fullText = ""

                    // TODO: Fix broken closures - temporarily commented out
                    /*
                    while true {
                        var isEos: Bool = false
                        var tokenString = ""
                        
                        let success = epi_llama_generate_next(Self.tokenCallback, Unmanaged.passUnretained(self).toOpaque(), &isEos)

                        if isEos {
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

                        if !tokenString.isEmpty {
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
                    */
                    
                    // Temporary fallback
                    let fallbackEvent = GenerationEvent(
                        source: .local,
                        delta: "Local generation temporarily disabled",
                        fullText: "Local generation temporarily disabled",
                        isFinished: true
                    )
                    continuation.yield(fallbackEvent)
                    continuation.finish()
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

                let success = fullPrompt.withCString { epi_llama_start($0) }

                if success {
                    var fullText = ""

                    // TODO: Fix broken closures - temporarily commented out
                    /*
                    while true {
                        var isEos: Bool = false
                        var tokenString = ""
                        
                        let success = epi_llama_generate_next(Self.tokenCallback, Unmanaged.passUnretained(self).toOpaque(), &isEos)

                        if isEos {
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

                        if !tokenString.isEmpty {
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
                    */
                    
                    // Temporary fallback
                    let fallbackEvent = GenerationEvent(
                        source: .local,
                        delta: "Local generation temporarily disabled",
                        fullText: "Local generation temporarily disabled",
                        isFinished: true
                    )
                    continuation.yield(fallbackEvent)
                    continuation.finish()
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
    private let geminiClient: GeminiClient

    init(apiKey: String, baseURL: String = "https://generativelanguage.googleapis.com/v1beta") {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.geminiClient = GeminiClient(apiKey: apiKey, baseURL: baseURL)
    }

    func generate(
        systemPrompt: String,
        userPrompt: String,
        config: GenerationConfig
    ) -> AsyncStream<GenerationEvent> {
        return AsyncStream<GenerationEvent> { continuation in
            Task {
                do {
                    // Use Gemini API for cloud generation
                    let response = try await geminiClient.generateCompletion(
                        systemPrompt: systemPrompt,
                        userPrompt: userPrompt,
                        config: config
                    )
                    
                    // Stream the response
                    for await chunk in response {
                        continuation.yield(chunk)
                    }
                    
                    continuation.finish()
                } catch {
                    // Fallback to local generation if cloud fails
                    print("Cloud generation failed, falling back to local: \(error)")
                    let fallbackEvent = GenerationEvent(
                        source: .local,
                        delta: "Cloud service unavailable, using local processing. ",
                        fullText: "Cloud service unavailable, using local processing. ",
                        isFinished: true
                    )
                    continuation.yield(fallbackEvent)
                    continuation.finish()
                }
            }
        }
    }

    func cancelCurrent() {
        // Cancel any ongoing cloud requests
    }
}

// MARK: - Gemini Client

class GeminiClient {
    private let apiKey: String
    private let baseURL: String
    
    init(apiKey: String, baseURL: String = "https://generativelanguage.googleapis.com/v1beta") {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    func generateCompletion(
        systemPrompt: String,
        userPrompt: String,
        config: GenerationConfig
    ) async throws -> AsyncStream<GenerationEvent> {
        return AsyncStream<GenerationEvent> { continuation in
            Task {
                do {
                    let url = URL(string: "\(baseURL)/models/gemini-2.5-flash:streamGenerateContent?key=\(apiKey)")!
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    // Gemini API request body
                    let requestBody: [String: Any] = [
                        "contents": [
                            [
                                "parts": [
                                    ["text": "\(systemPrompt)\n\n\(userPrompt)"]
                                ]
                            ]
                        ],
                        "generationConfig": [
                            "temperature": config.temperature,
                            "topP": config.topP,
                            "maxOutputTokens": config.maxTokens
                        ]
                    ]
                    
                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                    
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        throw NSError(domain: "GeminiAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    }
                    
                    // Parse streaming response
                    let responseString = String(data: data, encoding: .utf8) ?? ""
                    let lines = responseString.components(separatedBy: .newlines)
                    
                    var fullText = ""
                    
                    for line in lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            if jsonString == "[DONE]" {
                                let finalEvent = GenerationEvent(
                                    source: .cloud,
                                    delta: "",
                                    fullText: fullText,
                                    isFinished: true
                                )
                                continuation.yield(finalEvent)
                                break
                            }
                            
                            if let jsonData = jsonString.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                               let candidates = json["candidates"] as? [[String: Any]],
                               let firstCandidate = candidates.first,
                               let content = firstCandidate["content"] as? [String: Any],
                               let parts = content["parts"] as? [[String: Any]],
                               let firstPart = parts.first,
                               let text = firstPart["text"] as? String {
                                
                                fullText += text
                                
                                let event = GenerationEvent(
                                    source: .cloud,
                                    delta: text,
                                    fullText: fullText,
                                    isFinished: false
                                )
                                continuation.yield(event)
                            }
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.yield(GenerationEvent(
                        source: .cloud,
                        delta: "Error: \(error.localizedDescription)",
                        fullText: "Error: \(error.localizedDescription)",
                        isFinished: true
                    ))
                    continuation.finish()
                }
            }
        }
    }
}

// MARK: - PRISM Heuristics

struct PrismHeuristics {

    static func score(_ text: String) -> Double {
        return PrismScrubber.score(text)
    }
}

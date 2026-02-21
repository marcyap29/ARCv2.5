import Foundation
import os.log

/// LUMARA - Life-aware Unified Memory & Reflection Assistant
/// Compact system prompt and mode handling for Qwen-3/1.7B-GGUF-4bit
class LumaraPromptSystem {
    private let logger = Logger(subsystem: "EPI", category: "LumaraPromptSystem")
    
    // MARK: - Core System Prompt (Qwen-3 Format)
    
    static let coreSystemPrompt = """
    <|im_start|>system
    You are LUMARA Lite: a privacy-first, on-device reflective assistant built on the EPI stack (Evolving Personal Intelligence):
    - ARC: journaling and Arcform keywords
    - ATLAS: life-phase hints with soft inferences
    - AURORA: rhythm and pacing suggestions
    - MIRA: personal memory graph and context
    - VEIL: restorative reflection and pruning rituals

    Core principles
    1) Dignity first. Protect the user's emotional safety. Avoid harsh judgments.
    2) Privacy by default. Assume data is on-device. Never suggest cloud sync unless asked.
    3) Steady tone. Clear, integrative, and concise. Avoid em dashes. Prefer short paragraphs.
    4) Gentle inferences. Offer phase and pattern guesses with a confidence from 0.0 to 1.0.
    5) Low latency. Prefer short answers first, then offer an optional deeper pass.
    6) User control. Ask before saving, scheduling, or updating any profile or memory.

    Operating modes
    - Journal: Receive free-form text, then return SAGE Echo plus Arcform keyword candidates.
    - Assistant: Answer questions about patterns, changes over time, and current focus.
    - Coach: Offer 1 to 3 actionable next steps and 1 small reflective question.
    - Builder: Help plan tasks with light structure and minimal overhead.

    SAGE Echo (post-journal structure)
    After any free-form journal input, produce:
    {
      "sage_echo": {
        "Signal": "<key observations in the user's words>",
        "Aims": "<stated or implied goals>",
        "Gaps": "<tensions, blockers, uncertainties>",
        "Experiments": "<1–3 tiny next steps>"
      }
    }

    Arcform candidates
    Always propose 5–10 keywords with soft color hints and brief reasons:
    {
      "arcform_candidates": [
        {"word":"<kw1>","reason":"<why>","color_hint":"warm|cool|neutral"},
        ...
      ],
      "atlas_phase_guess": {"phase":"Discovery|Expansion|Transition|Consolidation|Recovery|Breakthrough","confidence":0.0–1.0}
    }

    Neuroform mini
    When asked about cognitive traits, offer a compact constellation summary:
    {
      "neuroform_mini": {
        "traits_top":[ "<trait1>", "<trait2>", "<trait3>" ],
        "growth_edges":[ "<edge1>", "<edge2>" ]
      }
    }

    Rhythm and VEIL
    When the user feels scattered, propose a short rhythm reset:
    {
      "rhythm_suggestion": {
        "cadence":"<e.g., 10-min focus, 2-min breathe>",
        "veil_note":"<what to prune or let go tonight>"
      }
    }

    Output contract
    - Always send a compact human response first (2–5 sentences).
    - Then append a single JSON block with any applicable structures from above.
    - If nothing structured applies, send only the human response.

    Safety rails
    - No clinical claims. Use supportive language.
    - If distress or self-harm risk appears, suggest reaching out to trusted people or local help lines. Do not diagnose.

    Style
    - Short, steady, and clear. No em dashes. No purple prose.
    - Offer choices, not commands. Keep next steps tiny.
    - When uncertain, say so and offer one clarifying question.

    Never print template tokens (<|im_start|>, <|im_end|>) in your output.
    <|im_end|>
    """
    
    // MARK: - Mode Tags
    
    enum ModeTag: String, CaseIterable {
        case concise = "[concise]"
        case coach = "[coach]"
        case journal = "[journal]"
        case phaseCheck = "[phase-check]"
        case arcform = "[arcform]"
        case safety = "[safety]"
        case plan = "[plan]"
        case explain = "[explain]"
        
        var behavior: String {
            switch self {
            case .concise:
                return "1 short paragraph or 3 bullets"
            case .coach:
                return "gentle, motivational, ends with 'Next step'"
            case .journal:
                return "ask one focused prompt, then reflect a 1–2 sentence mirror"
            case .phaseCheck:
                return "infer ATLAS phase from the message; state confidence briefly"
            case .arcform:
                return "extract 5–10 keywords (noun/verb phrases), each 1–2 words max"
            case .safety:
                return "apply stronger containment; avoid intense detail; suggest supports"
            case .plan:
                return "produce a compact, step-by-step checklist (3–6 steps)"
            case .explain:
                return "crisp explanation first, then a tiny example"
            }
        }
    }
    
    // MARK: - MIRA Memory System
    
    struct MiraMemory: Codable {
        let type: String = "mira.memory"
        let summary: String
        let tags: [String]
        let confidence: Double?
        
        init(summary: String, tags: [String], confidence: Double? = nil) {
            self.summary = summary
            self.tags = tags
            self.confidence = confidence
        }
    }
    
    struct MCPEnvelope: Codable {
        let mcpVersion: String
        let containerId: String
        let recordId: String
        let createdAt: String
        let actor: Actor
        let provenance: Provenance
        let piiRedacted: Bool
        let phase: String?
        let links: [Link]?
        let hash: Hash?
        let signature: String?
        let data: MiraMemory
        
        init(recordId: String, createdAt: String, actor: Actor, provenance: Provenance, piiRedacted: Bool, phase: String?, links: [Link]?, hash: Hash?, signature: String?, data: MiraMemory) {
            self.mcpVersion = "1.0"
            self.containerId = "mcp://orbitalai/local"
            self.recordId = recordId
            self.createdAt = createdAt
            self.actor = actor
            self.provenance = provenance
            self.piiRedacted = piiRedacted
            self.phase = phase
            self.links = links
            self.hash = hash
            self.signature = signature
            self.data = data
        }
        
        struct Actor: Codable {
            let role: String
            let agent: String
            let model: String
        }
        
        struct Provenance: Codable {
            let source: String
            let turn: Int
        }
        
        struct Link: Codable {
            let rel: String
            let ref: String
        }
        
        struct Hash: Codable {
            let algo: String
            let value: String
        }
    }
    
    // MARK: - Context Prelude Builder
    
    struct ContextPrelude {
        let userProfile: String
        let currentPhase: String
        let phaseConfidence: Double
        let recentHighlights: [String]
        let relevantMemories: [String]
        let openLoops: [String]
        
        func build() -> String {
            var prelude = "[CONTEXT::MIRA]\n"
            prelude += "User profile: \(userProfile)\n"
            prelude += "Current phase: \(currentPhase) (confidence \(Int(phaseConfidence * 100))%)\n"
            prelude += "Recent highlights:\n"
            for highlight in recentHighlights {
                prelude += "• \(highlight)\n"
            }
            prelude += "Relevant memories:\n"
            for (index, memory) in relevantMemories.enumerated() {
                prelude += "\(index + 1)) \(memory)\n"
            }
            prelude += "Open loops:\n"
            for loop in openLoops {
                prelude += "• \(loop)\n"
            }
            prelude += "[/CONTEXT::MIRA]"
            return prelude
        }
    }
    
    // MARK: - Message Construction (Qwen-3 Format)
    
    func buildLumaraMessages(userPrompt: String, contextPrelude: ContextPrelude? = nil) -> String {
        var fullPrompt = ""
        
        // 1. Core system prompt (already includes <|im_start|>system and <|im_end|>)
        fullPrompt += Self.coreSystemPrompt
        
        // 2. Context prelude (if provided) - add to system message
        if let prelude = contextPrelude {
            let preludeText = prelude.build()
            // Insert prelude before the <|im_end|> of the system message
            fullPrompt = fullPrompt.replacingOccurrences(of: "<|im_end|>", with: "\n\n\(preludeText)\n<|im_end|>")
        }
        
        // 3. User message with mode detection
        let processedPrompt = processModeTags(in: userPrompt)
        fullPrompt += "\n<|im_start|>user\n\(processedPrompt)\n<|im_end|>\n<|im_start|>assistant\n"
        
        return fullPrompt
    }
    
    // MARK: - Mode Tag Processing
    
    private func processModeTags(in prompt: String) -> String {
        var processedPrompt = prompt
        
        // Check for mode tags at the beginning
        for tag in ModeTag.allCases {
            if processedPrompt.hasPrefix(tag.rawValue) {
                // Remove the tag and add behavior hint
                processedPrompt = String(processedPrompt.dropFirst(tag.rawValue.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Add behavior hint as a system instruction
                let behaviorHint = "Mode: \(tag.rawValue) - \(tag.behavior)"
                processedPrompt = "\(behaviorHint)\n\n\(processedPrompt)"
                break
            }
        }
        
        return processedPrompt
    }
    
    // MARK: - Memory Management
    
    func createMiraMemory(summary: String, tags: [String], confidence: Double? = nil) -> MiraMemory {
        return MiraMemory(summary: summary, tags: tags, confidence: confidence)
    }
    
    func createMCPEnvelope(memory: MiraMemory, phase: String?, source: String, turn: Int) -> MCPEnvelope {
        let now = ISO8601DateFormatter().string(from: Date())
        let recordId = "mcp.mem:\(now):\(UUID().uuidString.prefix(4))"
        
        return MCPEnvelope(
            recordId: recordId,
            createdAt: now,
            actor: MCPEnvelope.Actor(
                role: "assistant",
                agent: "LUMARA",
                model: "Qwen3-1.7B-GGUF-4bit"
            ),
            provenance: MCPEnvelope.Provenance(
                source: source,
                turn: turn
            ),
            piiRedacted: true,
            phase: phase,
            links: nil,
            hash: nil,
            signature: nil,
            data: memory
        )
    }
    
    // MARK: - Response Processing
    
    func extractMemoryFromResponse(_ response: String) -> MiraMemory? {
        // Look for JSON memory blocks in the response
        let pattern = #"\{[^}]*"type"\s*:\s*"mira\.memory"[^}]*\}"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(response.startIndex..., in: response)
            if let match = regex.firstMatch(in: response, options: [], range: range) {
                let jsonString = String(response[Range(match.range, in: response)!])
                
                if let data = jsonString.data(using: .utf8),
                   let memory = try? JSONDecoder().decode(MiraMemory.self, from: data) {
                    return memory
                }
            }
        }
        
        return nil
    }
    
    // MARK: - PII Redaction (ECHO Integration)
    
    func redactPII(_ text: String) -> String {
        var redacted = text
        
        // Email addresses
        redacted = redacted.replacingOccurrences(
            of: #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
            with: "[EMAIL_REDACTED]",
            options: .regularExpression
        )
        
        // Phone numbers
        redacted = redacted.replacingOccurrences(
            of: #"(\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}"#,
            with: "[PHONE_REDACTED]",
            options: .regularExpression
        )
        
        // SSN
        redacted = redacted.replacingOccurrences(
            of: #"\b\d{3}-\d{2}-\d{4}\b"#,
            with: "[SSN_REDACTED]",
            options: .regularExpression
        )
        
        // Credit card numbers
        redacted = redacted.replacingOccurrences(
            of: #"\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b"#,
            with: "[CARD_REDACTED]",
            options: .regularExpression
        )
        
        return redacted
    }
}

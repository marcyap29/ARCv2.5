import Foundation

// PRISM Privacy Scrubber
// Deterministic local text-sanitization module that redacts or replaces identifiable content
// before any off-device transfer

struct PrismResult {
    let redacted: String
    let reversibleMap: [String: String]
    let findings: [String]
}

enum TaskType {
    case journaling
    case analysis
    case chat
    case export
}

class PrismScrubber {
    
    // MARK: - Main Scrub Function
    
    static func scrub(_ text: String, task: TaskType) -> PrismResult {
        var redactedText = text
        var reversibleMap: [String: String] = [:]
        var findings: [String] = []
        
        // Email redaction
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        redactedText = redactPattern(redactedText, pattern: emailPattern, replacement: "[EMAIL_#]", map: &reversibleMap, findings: &findings, type: "email")
        
        // Phone number redaction
        let phonePattern = #"(\+?1[-.\s]?)?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})"#
        redactedText = redactPattern(redactedText, pattern: phonePattern, replacement: "[PHONE_#]", map: &reversibleMap, findings: &findings, type: "phone")
        
        // Physical address redaction (basic patterns)
        let addressPattern = #"\d+\s+[A-Za-z0-9\s,.-]+(?:Street|St|Avenue|Ave|Road|Rd|Drive|Dr|Lane|Ln|Boulevard|Blvd|Way|Place|Pl|Court|Ct)"#
        redactedText = redactPattern(redactedText, pattern: addressPattern, replacement: "[ADDRESS_#]", map: &reversibleMap, findings: &findings, type: "address")
        
        // Name redaction (common first/last name patterns)
        let namePattern = #"\b[A-Z][a-z]+\s+[A-Z][a-z]+\b"#
        redactedText = redactPattern(redactedText, pattern: namePattern, replacement: "[NAME_#]", map: &reversibleMap, findings: &findings, type: "name")
        
        // Date redaction (mask day, keep month/year)
        let datePattern = #"\b(0?[1-9]|1[0-2])/(0?[1-9]|[12][0-9]|3[01])/(\d{4})\b"#
        redactedText = redactPattern(redactedText, pattern: datePattern, replacement: "[DATE_MMYYYY]", map: &reversibleMap, findings: &findings, type: "date")
        
        // GPS coordinates redaction
        let gpsPattern = #"-?\d+\.\d+,\s*-?\d+\.\d+"#
        redactedText = redactPattern(redactedText, pattern: gpsPattern, replacement: "[COORD_#]", map: &reversibleMap, findings: &findings, type: "coordinates")
        
        // SSN redaction
        let ssnPattern = #"\b\d{3}-?\d{2}-?\d{4}\b"#
        redactedText = redactPattern(redactedText, pattern: ssnPattern, replacement: "[ID_#]", map: &reversibleMap, findings: &findings, type: "ssn")
        
        // Credit card redaction
        let cardPattern = #"\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b"#
        redactedText = redactPattern(redactedText, pattern: cardPattern, replacement: "[CARD_#]", map: &reversibleMap, findings: &findings, type: "credit_card")
        
        // API key redaction
        let apiKeyPattern = #"\b[A-Za-z0-9]{20,}\b"#
        redactedText = redactPattern(redactedText, pattern: apiKeyPattern, replacement: "[API_KEY_#]", map: &reversibleMap, findings: &findings, type: "api_key")
        
        return PrismResult(
            redacted: redactedText,
            reversibleMap: reversibleMap,
            findings: findings
        )
    }
    
    // MARK: - Pattern Redaction Helper
    
    private static func redactPattern(_ text: String, pattern: String, replacement: String, map: inout [String: String], findings: inout [String], type: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(location: 0, length: text.utf16.count)
            
            let matches = regex.matches(in: text, options: [], range: range)
            
            var redactedText = text
            var offset = 0
            
            for match in matches.reversed() {
                let adjustedRange = NSRange(location: match.range.location + offset, length: match.range.length)
                let originalText = (text as NSString).substring(with: match.range)
                
                // Create unique replacement
                let uniqueReplacement = replacement.replacingOccurrences(of: "#", with: "\(map.count + 1)")
                
                // Store mapping
                map[uniqueReplacement] = originalText
                findings.append("\(type): \(originalText)")
                
                // Replace in text
                redactedText = (redactedText as NSString).replacingCharacters(in: adjustedRange, with: uniqueReplacement)
                
                // Adjust offset for next replacement
                offset += uniqueReplacement.count - match.range.length
            }
            
            return redactedText
            
        } catch {
            print("PrismScrubber: Error with pattern \(pattern): \(error)")
            return text
        }
    }
    
    // MARK: - Heuristics for Routing Decisions
    
    static func score(_ text: String) -> Double {
        var score = 0.0
        
        // Length-based scoring
        if text.count > 1500 {
            score += 0.3
        } else if text.count > 1000 {
            score += 0.2
        } else if text.count > 500 {
            score += 0.1
        }
        
        // Content-based scoring
        let sensitiveKeywords = [
            "confidential", "private", "personal", "secret", "sensitive",
            "financial", "medical", "legal", "password", "token"
        ]
        
        let lowercasedText = text.lowercased()
        for keyword in sensitiveKeywords {
            if lowercasedText.contains(keyword) {
                score += 0.1
            }
        }
        
        // PII detection scoring
        let piiPatterns = [
            #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#, // Email
            #"(\+?1[-.\s]?)?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})"#, // Phone
            #"\b\d{3}-?\d{2}-?\d{4}\b"# // SSN
        ]
        
        for pattern in piiPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let range = NSRange(location: 0, length: text.utf16.count)
                let matches = regex.matches(in: text, options: [], range: range)
                if !matches.isEmpty {
                    score += 0.2
                }
            } catch {
                continue
            }
        }
        
        return min(score, 1.0) // Cap at 1.0
    }
    
    // MARK: - Reversible Map Utilities
    
    static func restore(_ redactedText: String, reversibleMap: [String: String]) -> String {
        var restoredText = redactedText
        
        for (replacement, original) in reversibleMap {
            restoredText = restoredText.replacingOccurrences(of: replacement, with: original)
        }
        
        return restoredText
    }
    
    static func createDiffView(_ original: String, _ redacted: String, _ findings: [String]) -> String {
        var diff = "PRISM Privacy Scrubber Results:\n\n"
        diff += "Original length: \(original.count) characters\n"
        diff += "Redacted length: \(redacted.count) characters\n"
        diff += "Items redacted: \(findings.count)\n\n"
        
        if !findings.isEmpty {
            diff += "Redacted items:\n"
            for finding in findings {
                diff += "• \(finding)\n"
            }
        }
        
        return diff
    }
}

import Foundation
import os.log

/// MIRA Memory Store - Manages persistent memory for LUMARA
/// Stores memories in MCP envelope format for portability
class MiraMemoryStore {
    private let logger = Logger(subsystem: "EPI", category: "MiraMemoryStore")
    private let fileManager = FileManager.default
    
    // MARK: - Storage Paths
    
    private var memoryDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let miraDir = appSupport.appendingPathComponent("MIRA", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: miraDir, withIntermediateDirectories: true)
        
        return miraDir
    }
    
    private var memoriesDirectory: URL {
        let dir = memoryDirectory.appendingPathComponent("memories", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    // MARK: - Memory Storage
    
    func saveMemory(_ memory: LumaraPromptSystem.MiraMemory, phase: String?, source: String, turn: Int) -> Bool {
        let envelope = LumaraPromptSystem().createMCPEnvelope(
            memory: memory,
            phase: phase,
            source: source,
            turn: turn
        )
        
        do {
            let data = try JSONEncoder().encode(envelope)
            let filename = "\(envelope.recordId).json"
            var fileURL = memoriesDirectory.appendingPathComponent(filename)
            
            try data.write(to: fileURL)
            
            // Set no-backup flag
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try fileURL.setResourceValues(resourceValues)
            
            logger.info("Saved memory: \(envelope.recordId)")
            return true
        } catch {
            logger.error("Failed to save memory: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Memory Retrieval
    
    func getRecentMemories(limit: Int = 10, phase: String? = nil) -> [LumaraPromptSystem.MCPEnvelope] {
        do {
            let files = try fileManager.contentsOfDirectory(at: memoriesDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            // Sort by creation date (newest first)
            let sortedFiles = files.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
            
            var memories: [LumaraPromptSystem.MCPEnvelope] = []
            
            for file in sortedFiles.prefix(limit) {
                if let data = try? Data(contentsOf: file),
                   let envelope = try? JSONDecoder().decode(LumaraPromptSystem.MCPEnvelope.self, from: data) {
                    
                    // Filter by phase if specified
                    if let phase = phase, envelope.phase != phase {
                        continue
                    }
                    
                    memories.append(envelope)
                }
            }
            
            return memories
        } catch {
            logger.error("Failed to retrieve memories: \(error.localizedDescription)")
            return []
        }
    }
    
    func searchMemories(query: String, limit: Int = 5) -> [LumaraPromptSystem.MCPEnvelope] {
        let allMemories = getRecentMemories(limit: 50) // Get more to search through
        
        // Simple text search in summary and tags
        let queryLower = query.lowercased()
        
        let filtered = allMemories.filter { envelope in
            let summary = envelope.data.summary.lowercased()
            let tags = envelope.data.tags.joined(separator: " ").lowercased()
            
            return summary.contains(queryLower) || tags.contains(queryLower)
        }
        
        return Array(filtered.prefix(limit))
    }
    
    // MARK: - Context Prelude Building
    
    func buildContextPrelude(userProfile: String = "User building EPI (ARC, ATLAS, MIRA, AURORA, VEIL)", 
                           currentPhase: String = "Consolidation", 
                           phaseConfidence: Double = 0.8) -> LumaraPromptSystem.ContextPrelude {
        
        let recentMemories = getRecentMemories(limit: 5)
        let relevantMemories = searchMemories(query: "qwen mlx on-device", limit: 3)
        
        // Build recent highlights
        let recentHighlights = recentMemories.prefix(3).map { envelope in
            let date = ISO8601DateFormatter().date(from: envelope.createdAt) ?? Date()
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: date)) — \(envelope.data.summary)"
        }
        
        // Build relevant memories
        let memoryStrings = relevantMemories.map { envelope in
            let date = ISO8601DateFormatter().date(from: envelope.createdAt) ?? Date()
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: date)) — \(envelope.data.summary)"
        }
        
        // Build open loops
        let openLoops = [
            "Add 'Model Library' screen for downloads",
            "Draft compact LUMARA prompt; add [arcform] and [phase-check] modes",
            "Test complete on-device inference with real model"
        ]
        
        return LumaraPromptSystem.ContextPrelude(
            userProfile: userProfile,
            currentPhase: currentPhase,
            phaseConfidence: phaseConfidence,
            recentHighlights: Array(recentHighlights),
            relevantMemories: memoryStrings,
            openLoops: openLoops
        )
    }
    
    // MARK: - Memory Management
    
    func clearOldMemories(olderThanDays: Int = 30) {
        do {
            let files = try fileManager.contentsOfDirectory(at: memoriesDirectory, includingPropertiesForKeys: [.creationDateKey])
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date.distantPast
            
            for file in files {
                if let creationDate = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < cutoffDate {
                    try fileManager.removeItem(at: file)
                    logger.info("Removed old memory: \(file.lastPathComponent)")
                }
            }
        } catch {
            logger.error("Failed to clear old memories: \(error.localizedDescription)")
        }
    }
    
    func getMemoryCount() -> Int {
        do {
            let files = try fileManager.contentsOfDirectory(at: memoriesDirectory, includingPropertiesForKeys: nil)
            return files.count
        } catch {
            logger.error("Failed to count memories: \(error.localizedDescription)")
            return 0
        }
    }
}

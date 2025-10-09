// ModelDownloadService.swift
// Downloads ML models from remote server (Google Drive) to Application Support
// Provides progress tracking, pause/resume, and integrity verification

import Foundation
import os.log

class ModelDownloadService: NSObject {
    static let shared = ModelDownloadService()
    private let logger = Logger(subsystem: "EPI", category: "ModelDownload")
    
    /// Resolve model path case-insensitively
    func resolveModelPath(fileName: String, under dir: URL) -> URL? {
        let want = fileName.lowercased()
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return nil }
        return files.first { $0.lastPathComponent.lowercased() == want }
    }

    // Track multiple concurrent downloads by model ID
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var resumeData: [String: Data] = [:]
    private var progressCallbacks: [String: (Double, String) -> Void] = [:]

    // Model directory path
    private var modelRootURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Models", isDirectory: true)
    }

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

        // Clean up any existing metadata before starting download
        do {
            let modelsDirectory = modelRootURL
            try cleanupMacOSMetadata(in: modelsDirectory)
        } catch {
            logger.warning("Failed to clean up existing metadata: \(error.localizedDescription)")
        }

        // Store progress callback for this model
        progressCallbacks[modelId] = onProgress

        // Create URLSession with background configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes
        config.timeoutIntervalForResource = 3600 // 1 hour
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        // Start download
        logger.info("Starting model download for \(modelId) from: \(urlString)")
        onProgress(0.0, "Connecting to server...")

        let downloadTask = session.downloadTask(with: url)
        downloadTasks[modelId] = downloadTask
        downloadTask.resume()
    }

    /// Pause ongoing download for specific model
    func pauseDownload(modelId: String) {
        downloadTasks[modelId]?.cancel(byProducingResumeData: { [weak self] data in
            self?.resumeData[modelId] = data
            self?.logger.info("Download paused for \(modelId), resume data saved")
        })
    }

    /// Resume paused download for specific model
    func resumeDownload(modelId: String) {
        guard let resumeData = resumeData[modelId] else {
            logger.warning("No resume data available for \(modelId)")
            return
        }

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        let downloadTask = session.downloadTask(withResumeData: resumeData)
        downloadTasks[modelId] = downloadTask
        downloadTask.resume()

        logger.info("Download resumed for \(modelId)")
    }

    /// Cancel download for specific model
    func cancelDownload(modelId: String) {
        downloadTasks[modelId]?.cancel()
        downloadTasks.removeValue(forKey: modelId)
        resumeData.removeValue(forKey: modelId)
        progressCallbacks.removeValue(forKey: modelId)
        logger.info("Download cancelled for \(modelId)")
    }

    /// Cancel all downloads
    func cancelAllDownloads() {
        for (modelId, task) in downloadTasks {
            task.cancel()
            logger.info("Cancelled download for \(modelId)")
        }
        downloadTasks.removeAll()
        resumeData.removeAll()
        progressCallbacks.removeAll()
        logger.info("All downloads cancelled")
    }

    /// Simple cancel method for compatibility
    func cancelDownload() {
        cancelAllDownloads()
    }

    /// Check if model is available and usable
    /// Only returns true if model files actually exist on filesystem
    func isModelDownloaded(modelId: String) -> Bool {
        // Check for GGUF models (new format)
        let ggufModelIds = [
            "Llama-3.2-3b-Instruct-Q4_K_M.gguf",
            "Phi-3.5-mini-instruct-Q5_K_M.gguf", 
            "Qwen3-4B-Instruct.Q5_K_M.gguf",
            "Qwen3-4B-Instruct-2507-Q5_K_M.gguf"  // New Hugging Face filename
        ]
        
        if ggufModelIds.contains(modelId) {
            // For GGUF models, check if the .gguf file exists in the gguf_models directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let ggufModelsPath = documentsPath.appendingPathComponent("gguf_models")
            
            // Case-insensitive model resolution
            let resolvedPath = resolveModelPath(fileName: modelId, under: ggufModelsPath)
            let exists = resolvedPath != nil
            
            if let path = resolvedPath {
                logger.info("Checking GGUF model \(modelId): found at \(path.path)")
            } else {
                logger.info("Checking GGUF model \(modelId): not found")
            }
            return exists
        }
        
        // Legacy MLX model support
        switch modelId {
        case "qwen3-1.7b-mlx-4bit", "phi-3.5-mini-instruct-4bit":
            break // Valid model ID
        default:
            logger.warning("Unknown model ID: \(modelId)")
            return false
        }

        // Check if model files actually exist (for legacy MLX models)
        let configPath = modelRootURL.appendingPathComponent(modelId).appendingPathComponent("config.json")
        let modelPath = modelRootURL.appendingPathComponent(modelId).appendingPathComponent("model.safetensors")
        let configExists = FileManager.default.fileExists(atPath: configPath.path)
        let modelExists = FileManager.default.fileExists(atPath: modelPath.path)

        let isAvailable = configExists && modelExists

        if isAvailable {
            logger.info("Model \(modelId) is available and usable")
        } else {
            logger.info("Model \(modelId) not available (config: \(configExists), model: \(modelExists))")
        }

        return isAvailable
    }

    /// Delete a downloaded model
    func deleteModel(modelId: String) throws {
        // Map model IDs to their directory names
        let modelDirName: String
        switch modelId {
        case "qwen3-1.7b-mlx-4bit":
            modelDirName = "Qwen3-1.7B-GGUF-4bit"
        case "phi-3.5-mini-instruct-4bit":
            modelDirName = "Phi-3.5-mini-instruct-4bit"
        case "Llama-3.2-3b-Instruct-Q4_K_M.gguf":
            modelDirName = "Llama-3.2-3b-Instruct-Q4_K_M.gguf"
        case "Phi-3.5-mini-instruct-Q5_K_M.gguf":
            modelDirName = "Phi-3.5-mini-instruct-Q5_K_M.gguf"
        case "Qwen3-4B-Instruct-2507-Q5_K_M.gguf":
            modelDirName = "Qwen3-4B-Instruct-2507-Q5_K_M.gguf"
        default:
            throw NSError(domain: "ModelDownload", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Unknown model ID: \(modelId)"
            ])
        }
        // For GGUF models, check Documents/gguf_models directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let ggufModelsPath = documentsPath.appendingPathComponent("gguf_models")
        let modelFile = ggufModelsPath.appendingPathComponent(modelId)
        
        // Check if model file exists
        guard FileManager.default.fileExists(atPath: modelFile.path) else {
            throw NSError(domain: "ModelDownload", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Model file not found: \(modelId)"
            ])
        }

        // Delete the model file
        try FileManager.default.removeItem(at: modelFile)
        logger.info("Successfully deleted model: \(modelId) from \(modelFile.path)")
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloadService: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Find the model ID for this download task
        guard let modelId = downloadTasks.first(where: { $0.value == downloadTask })?.key else {
            logger.error("Could not find model ID for completed download task")
            return
        }

        logger.info("Download completed for \(modelId), file at: \(location.path)")

        do {
            // Check if this is a GGUF model (single file, no unzipping needed)
            let ggufModelIds = [
                "Llama-3.2-3b-Instruct-Q4_K_M.gguf",
                "Phi-3.5-mini-instruct-Q5_K_M.gguf", 
                "Qwen3-4B-Instruct.Q5_K_M.gguf",
                "Qwen3-4B-Instruct-2507-Q5_K_M.gguf"
            ]
            
            if ggufModelIds.contains(modelId) {
                // Handle GGUF models - move directly to Documents/gguf_models
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let ggufModelsPath = documentsPath.appendingPathComponent("gguf_models")
                
                // Create gguf_models directory if it doesn't exist
                try FileManager.default.createDirectory(at: ggufModelsPath, withIntermediateDirectories: true, attributes: nil)
                
                let finalPath = ggufModelsPath.appendingPathComponent(modelId)
                
                // Remove existing file if it exists
                try? FileManager.default.removeItem(at: finalPath)
                
                // Move the downloaded file to the final location
                try FileManager.default.moveItem(at: location, to: finalPath)
                
                progressCallbacks[modelId]?(1.0, "Download complete!")
                logger.info("GGUF model \(modelId) successfully downloaded to: \(finalPath.path)")
                
            } else {
                // Only GGUF models are supported
                logger.error("Unsupported model format: \(modelId). Only GGUF models are supported.")
                progressCallbacks[modelId]?(0.0, "Unsupported model format. Only GGUF models are supported.")
                throw NSError(domain: "ModelDownloadService", code: 400, userInfo: [
                    NSLocalizedDescriptionKey: "Unsupported model format: \(modelId). Only GGUF models are supported."
                ])
            }

            // Notify completion on main thread
            DispatchQueue.main.async { [weak self] in
                self?.progressCallbacks[modelId]?(1.0, "Ready to use")
            }

            // Clean up tracking for this model
            downloadTasks.removeValue(forKey: modelId)
            progressCallbacks.removeValue(forKey: modelId)

        } catch {
            logger.error("Failed to process downloaded file for \(modelId): \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.progressCallbacks[modelId]?(0.0, "Error: \(error.localizedDescription)")
            }
            // Clean up tracking for this model even on error
            downloadTasks.removeValue(forKey: modelId)
            progressCallbacks.removeValue(forKey: modelId)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        // Find the model ID for this download task
        guard let modelId = downloadTasks.first(where: { $0.value == downloadTask })?.key else {
            return
        }

        // Handle cases where totalBytesExpectedToWrite is unknown or negative
        // Google Drive often returns -1 when Content-Length header is missing
        let progress: Double
        let message: String

        // Check for valid total size: must be positive AND greater than or equal to bytes written
        let hasValidTotal = totalBytesExpectedToWrite > 0 &&
                           totalBytesExpectedToWrite != NSURLSessionTransferSizeUnknown &&
                           totalBytesExpectedToWrite >= totalBytesWritten

        if hasValidTotal {
            // Valid total size - calculate progress (0.0 to 1.0)
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            let mbDownloaded = Double(totalBytesWritten) / 1_048_576
            let mbTotal = Double(totalBytesExpectedToWrite) / 1_048_576
            message = String(format: "Downloading: %.1f / %.1f MB", mbDownloaded, mbTotal)
            logger.debug("Download progress for \(modelId): \(progress * 100)% (\(mbDownloaded) / \(mbTotal) MB)")
        } else {
            // Unknown or invalid total size - show indeterminate progress
            // This happens with Google Drive direct links that don't provide Content-Length
            progress = 0.0  // Always use 0.0 to indicate indeterminate/unknown progress
            let mbDownloaded = Double(totalBytesWritten) / 1_048_576
            message = String(format: "Downloading: %.1f MB (total unknown)", mbDownloaded)
            logger.debug("Download progress for \(modelId): indeterminate (\(mbDownloaded) MB downloaded, total=\(totalBytesExpectedToWrite))")
        }

        DispatchQueue.main.async { [weak self] in
            self?.progressCallbacks[modelId]?(progress, message)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Find the model ID for this download task
            guard let modelId = downloadTasks.first(where: { $0.value == task })?.key else {
                logger.error("Download failed but could not find model ID: \(error.localizedDescription)")
                return
            }

            logger.error("Download failed for \(modelId): \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.progressCallbacks[modelId]?(0.0, "Download failed: \(error.localizedDescription)")
            }
            // Clean up tracking for this model
            downloadTasks.removeValue(forKey: modelId)
            progressCallbacks.removeValue(forKey: modelId)
        }
    }

    // MARK: - Unzip Helper

    // MARK: - Legacy Unzip Helper (Not used for GGUF models)
    
    // Note: GGUF models are single files and don't need unzipping.
    // This function is kept for potential future use with other model formats.
    // For GGUF models, the download logic directly moves the file to Documents/gguf_models.

    /// Copy bundled GGUF models from app bundle to Documents directory
    public func copyBundledGGUFModels() throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let ggufModelsPath = documentsPath.appendingPathComponent("gguf_models")
        
        // Create gguf_models directory if it doesn't exist
        try FileManager.default.createDirectory(at: ggufModelsPath, withIntermediateDirectories: true, attributes: nil)
        
        // List of bundled GGUF models to copy
        let bundledModels = [
            "Llama-3.2-3b-Instruct-Q4_K_M.gguf",
            "Phi-3.5-mini-instruct-Q5_K_M.gguf",
            "Qwen3-4B-Instruct.Q5_K_M.gguf",
            "Qwen3-4B-Instruct-2507-Q5_K_M.gguf"
        ]
        
        for modelName in bundledModels {
            // Check if model exists in bundle
            guard let bundlePath = Bundle.main.path(forResource: modelName, ofType: nil, inDirectory: "models/gguf") else {
                logger.info("Bundled model not found: \(modelName)")
                continue
            }
            
            let sourceURL = URL(fileURLWithPath: bundlePath)
            let destURL = ggufModelsPath.appendingPathComponent(modelName)
            
            // Only copy if destination doesn't exist or is different size
            if !FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
                logger.info("Copied bundled model: \(modelName)")
            } else {
                // Check if file sizes match (simple integrity check)
                let sourceSize = try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64 ?? 0
                let destSize = try FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int64 ?? 0
                
                if sourceSize != destSize {
                    try FileManager.default.removeItem(at: destURL)
                    try FileManager.default.copyItem(at: sourceURL, to: destURL)
                    logger.info("Updated bundled model: \(modelName)")
                } else {
                    logger.info("Bundled model already exists: \(modelName)")
                }
            }
        }
        
        logger.info("Bundled GGUF models copy completed")
    }

    /// Clear all models and metadata from the models directory
    public func clearAllModels() throws {
        let modelsDirectory = modelRootURL
        let fileManager = FileManager.default

        // Remove all contents of the models directory
        let contents = try fileManager.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil)
        for item in contents {
            try fileManager.removeItem(at: item)
            logger.info("Removed: \(item.lastPathComponent)")
        }

        logger.info("Cleared all models from directory: \(modelsDirectory.path)")
    }

    /// Clear a specific model directory and all its metadata
    public func clearModelDirectory(modelId: String) throws {
        let modelsDirectory = modelRootURL
        let modelDirectory = modelsDirectory.appendingPathComponent(modelId)
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: modelDirectory.path) {
            try fileManager.removeItem(at: modelDirectory)
            logger.info("Removed model directory: \(modelId)")
        }

        // Also clean up any remaining metadata in the parent directory
        try cleanupMacOSMetadata(in: modelsDirectory)
    }
    
    /// Clear corrupted downloads and GGUF models
    public func clearCorruptedDownloads() throws {
        let fileManager = FileManager.default
        
        // Clear GGUF models from Documents directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let ggufModelsPath = documentsPath.appendingPathComponent("gguf_models")
        
        if fileManager.fileExists(atPath: ggufModelsPath.path) {
            let contents = try fileManager.contentsOfDirectory(at: ggufModelsPath, includingPropertiesForKeys: nil)
            for item in contents {
                try fileManager.removeItem(at: item)
                logger.info("Removed corrupted GGUF model: \(item.lastPathComponent)")
            }
            logger.info("Cleared GGUF models directory: \(ggufModelsPath.path)")
        }
        
        // Clear Application Support models directory
        let modelsDirectory = modelRootURL
        if fileManager.fileExists(atPath: modelsDirectory.path) {
            let contents = try fileManager.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil)
            for item in contents {
                try fileManager.removeItem(at: item)
                logger.info("Removed corrupted model: \(item.lastPathComponent)")
            }
            logger.info("Cleared models directory: \(modelsDirectory.path)")
        }
        
        // Clear any temporary download files
        let tempDir = fileManager.temporaryDirectory
        let tempContents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        for item in tempContents {
            if item.lastPathComponent.contains("CFNetworkDownload_") || 
               item.lastPathComponent.contains(".part") ||
               item.lastPathComponent.contains("gguf") {
                try? fileManager.removeItem(at: item)
                logger.info("Removed temp file: \(item.lastPathComponent)")
            }
        }
        
        logger.info("Cleared all corrupted downloads and models")
    }
    
    /// Clear specific corrupted GGUF model
    public func clearCorruptedGGUFModel(modelId: String) throws {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let ggufModelsPath = documentsPath.appendingPathComponent("gguf_models")
        let modelPath = ggufModelsPath.appendingPathComponent(modelId)
        
        if fileManager.fileExists(atPath: modelPath.path) {
            try fileManager.removeItem(at: modelPath)
            logger.info("Removed corrupted GGUF model: \(modelId)")
        }
        
        // Also check for lowercase version (Hugging Face naming)
        let lowercasePath = ggufModelsPath.appendingPathComponent(modelId.lowercased())
        if fileManager.fileExists(atPath: lowercasePath.path) {
            try fileManager.removeItem(at: lowercasePath)
            logger.info("Removed corrupted GGUF model (lowercase): \(modelId.lowercased())")
        }
    }

    /// Clean up macOS metadata folders and files that might cause conflicts
    public func cleanupMacOSMetadata(in directory: URL) throws {
        let fileManager = FileManager.default

        // Remove _MACOSX folders recursively
        let macosxFolders = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("__MACOSX") }

        for folder in macosxFolders {
            try fileManager.removeItem(at: folder)
            logger.info("Removed macOS metadata folder: \(folder.lastPathComponent)")
        }
        // Remove .DS_Store files and ._ files recursively
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil)
        while let fileURL = enumerator?.nextObject() as? URL {
            let fileName = fileURL.lastPathComponent
            if fileName == ".DS_Store" || fileName.hasPrefix("._") {
                try fileManager.removeItem(at: fileURL)
                logger.info("Removed macOS metadata file: \(fileName)")
            }
        }
    }

}

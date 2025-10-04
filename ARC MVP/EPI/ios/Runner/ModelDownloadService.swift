// ModelDownloadService.swift
// Downloads ML models from remote server (Google Drive) to Application Support
// Provides progress tracking, pause/resume, and integrity verification

import Foundation
import os.log

class ModelDownloadService: NSObject {
    static let shared = ModelDownloadService()
    private let logger = Logger(subsystem: "EPI", category: "ModelDownload")

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
        // Validate model ID
        switch modelId {
        case "qwen3-1.7b-mlx-4bit", "phi-3.5-mini-instruct-4bit":
            break // Valid model ID
        default:
            logger.warning("Unknown model ID: \(modelId)")
            return false
        }

        // Check if model files actually exist
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
            modelDirName = "Qwen3-1.7B-MLX-4bit"
        case "phi-3.5-mini-instruct-4bit":
            modelDirName = "Phi-3.5-mini-instruct-4bit"
        default:
            throw NSError(domain: "ModelDownload", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Unknown model ID: \(modelId)"
            ])
        }
        let modelDir = modelRootURL.appendingPathComponent(modelDirName)
        // Check if model directory exists
        guard FileManager.default.fileExists(atPath: modelDir.path) else {
            throw NSError(domain: "ModelDownload", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Model directory not found: \(modelDirName)"
            ])
        }

        // Delete the model directory
        try FileManager.default.removeItem(at: modelDir)
        logger.info("Successfully deleted model: \(modelId) from \(modelDir.path)")
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
            // Move to temporary location
            let tempDir = FileManager.default.temporaryDirectory
            let tempZip = tempDir.appendingPathComponent("\(modelId)_download.zip")

            // Remove old temp file if exists
            try? FileManager.default.removeItem(at: tempZip)

            // Move downloaded file
            try FileManager.default.moveItem(at: location, to: tempZip)

            progressCallbacks[modelId]?(0.9, "Unzipping model files...")

            // Unzip to Application Support in model-specific directory
            let destDir = modelRootURL.appendingPathComponent(modelId, isDirectory: true)
            try unzipFile(at: tempZip, to: destDir)

            progressCallbacks[modelId]?(1.0, "Download complete!")
            logger.info("Model \(modelId) successfully downloaded and extracted")

            // Clean up
            try? FileManager.default.removeItem(at: tempZip)

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

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let mbDownloaded = Double(totalBytesWritten) / 1_048_576
        let mbTotal = Double(totalBytesExpectedToWrite) / 1_048_576

        let message = String(format: "Downloading: %.1f / %.1f MB", mbDownloaded, mbTotal)

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

    private func unzipFile(at sourceURL: URL, to destinationURL: URL) throws {
        logger.info("Unzipping: \(sourceURL.path) -> \(destinationURL.path)")

        // Create destination directory
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        // Use Process to call unzip command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = [
            "-o", // Overwrite files
            "-q", // Quiet mode
            "-x", "*__MACOSX*", // Exclude macOS metadata folders
            "-x", "*.DS_Store", // Exclude macOS .DS_Store files
            "-x", "._*", // Exclude macOS resource fork files
            sourceURL.path,
            "-d", destinationURL.path
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ModelDownload", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Failed to unzip model files"
            ])
        }

        // Clean up any remaining macOS metadata folders that might have been extracted
        try cleanupMacOSMetadata(in: destinationURL)

        // Handle case where ZIP contains a single root folder
        // (e.g., ZIP has "Qwen3-1.7B-MLX-4bit/" but we want files directly in destination)
        let contents = try FileManager.default.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: [.isDirectoryKey])

        // Filter out hidden files and get only directories
        let directories = try contents.filter { url in
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            return resourceValues.isDirectory == true && !url.lastPathComponent.hasPrefix(".")
        }

        // If there's exactly one directory, move its contents up one level
        if directories.count == 1, let singleDir = directories.first {
            logger.info("Found single root directory in ZIP: \(singleDir.lastPathComponent), moving contents up...")

            let tempDir = destinationURL.deletingLastPathComponent().appendingPathComponent("_temp_\(UUID().uuidString)")

            // Move the single directory to temp location
            try FileManager.default.moveItem(at: singleDir, to: tempDir)

            // Move all contents from temp to destination
            let innerContents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for item in innerContents {
                let dest = destinationURL.appendingPathComponent(item.lastPathComponent)
                try? FileManager.default.removeItem(at: dest) // Remove if exists
                try FileManager.default.moveItem(at: item, to: dest)
            }

            // Clean up temp directory
            try? FileManager.default.removeItem(at: tempDir)

            logger.info("Successfully moved contents from root directory")
        }

        logger.info("Unzip successful")
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

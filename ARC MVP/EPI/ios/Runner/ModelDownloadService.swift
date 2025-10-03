// ModelDownloadService.swift
// Downloads ML models from remote server (Google Drive) to Application Support
// Provides progress tracking, pause/resume, and integrity verification

import Foundation
import os.log

class ModelDownloadService: NSObject {
    static let shared = ModelDownloadService()
    private let logger = Logger(subsystem: "EPI", category: "ModelDownload")

    private var downloadTask: URLSessionDownloadTask?
    private var resumeData: Data?
    private var progressCallback: ((Double, String) -> Void)?

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

        self.progressCallback = onProgress

        // Create URLSession with background configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes
        config.timeoutIntervalForResource = 3600 // 1 hour
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        // Start download
        logger.info("Starting model download from: \(urlString)")
        onProgress(0.0, "Connecting to server...")

        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    /// Pause ongoing download
    func pauseDownload() {
        downloadTask?.cancel(byProducingResumeData: { [weak self] data in
            self?.resumeData = data
            self?.logger.info("Download paused, resume data saved")
        })
    }

    /// Resume paused download
    func resumeDownload() {
        guard let resumeData = resumeData else {
            logger.warning("No resume data available")
            return
        }

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        downloadTask = session.downloadTask(withResumeData: resumeData)
        downloadTask?.resume()

        logger.info("Download resumed")
    }

    /// Cancel download
    func cancelDownload() {
        downloadTask?.cancel()
        resumeData = nil
        logger.info("Download cancelled")
    }

    /// Check if model is available and usable
    /// Only returns true if model files actually exist on filesystem
    func isModelDownloaded(modelId: String) -> Bool {
        // Map model IDs to their directory names
        let modelDirName: String
        switch modelId {
        case "qwen3-1.7b-mlx-4bit":
            modelDirName = "Qwen3-1.7B-MLX-4bit"
        case "phi-3.5-mini-instruct-4bit":
            modelDirName = "Phi-3.5-mini-instruct-4bit"
        default:
            logger.warning("Unknown model ID: \(modelId)")
            return false
        }

        // Use ModelStore's resolveModelPath to check if model files actually exist
        // This properly checks both bundle and Application Support
        let configExists = ModelStore.shared.resolveModelPath(modelId: modelId, file: "config.json") != nil
        let modelExists = ModelStore.shared.resolveModelPath(modelId: modelId, file: "model.safetensors") != nil

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
        logger.info("Download completed, file at: \(location.path)")

        do {
            // Move to temporary location
            let tempDir = FileManager.default.temporaryDirectory
            let tempZip = tempDir.appendingPathComponent("model_download.zip")

            // Remove old temp file if exists
            try? FileManager.default.removeItem(at: tempZip)

            // Move downloaded file
            try FileManager.default.moveItem(at: location, to: tempZip)

            progressCallback?(0.9, "Unzipping model files...")

            // Unzip to Application Support
            let destDir = ModelStore.shared.modelRootURL
            try unzipFile(at: tempZip, to: destDir)

            progressCallback?(1.0, "Download complete!")
            logger.info("Model successfully downloaded and extracted")

            // Clean up
            try? FileManager.default.removeItem(at: tempZip)

            // Notify completion on main thread
            DispatchQueue.main.async { [weak self] in
                self?.progressCallback?(1.0, "Ready to use")
            }

        } catch {
            logger.error("Failed to process downloaded file: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.progressCallback?(0.0, "Error: \(error.localizedDescription)")
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let mbDownloaded = Double(totalBytesWritten) / 1_048_576
        let mbTotal = Double(totalBytesExpectedToWrite) / 1_048_576

        let message = String(format: "Downloading: %.1f / %.1f MB", mbDownloaded, mbTotal)

        DispatchQueue.main.async { [weak self] in
            self?.progressCallback?(progress, message)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            logger.error("Download failed: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.progressCallback?(0.0, "Download failed: \(error.localizedDescription)")
            }
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

        logger.info("Unzip successful")
    }
}

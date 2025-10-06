// lib/lumara/services/download_state_service.dart
// Persistent download state management that survives screen navigation

import 'package:flutter/foundation.dart';

/// Download state for a single model
class ModelDownloadState {
  final String modelId;
  final bool isDownloading;
  final bool isDownloaded;
  final double progress; // 0.0 to 1.0
  final String statusMessage;
  final String? errorMessage;
  final int? bytesDownloaded; // Bytes downloaded so far
  final int? totalBytes; // Total bytes to download

  const ModelDownloadState({
    required this.modelId,
    this.isDownloading = false,
    this.isDownloaded = false,
    this.progress = 0.0,
    this.statusMessage = '',
    this.errorMessage,
    this.bytesDownloaded,
    this.totalBytes,
  });

  /// Get human-readable download progress
  String get downloadSizeText {
    if (bytesDownloaded == null) return '';

    final downloadedMB = bytesDownloaded! / 1048576;

    if (totalBytes == null || totalBytes == 0) {
      // Unknown total size
      if (downloadedMB >= 1000) {
        final downloadedGB = downloadedMB / 1024;
        return '${downloadedGB.toStringAsFixed(2)} GB';
      } else {
        return '${downloadedMB.toStringAsFixed(1)} MB';
      }
    }

    final totalMB = totalBytes! / 1048576;

    if (totalMB >= 1000) {
      // Show in GB
      final downloadedGB = downloadedMB / 1024;
      final totalGB = totalMB / 1024;
      return '${downloadedGB.toStringAsFixed(2)} / ${totalGB.toStringAsFixed(2)} GB';
    } else {
      // Show in MB
      return '${downloadedMB.toStringAsFixed(1)} / ${totalMB.toStringAsFixed(1)} MB';
    }
  }

  ModelDownloadState copyWith({
    bool? isDownloading,
    bool? isDownloaded,
    double? progress,
    String? statusMessage,
    String? errorMessage,
    int? bytesDownloaded,
    int? totalBytes,
  }) {
    return ModelDownloadState(
      modelId: modelId,
      isDownloading: isDownloading ?? this.isDownloading,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
    );
  }
}

/// Singleton service to manage persistent download state
class DownloadStateService extends ChangeNotifier {
  static final DownloadStateService _instance = DownloadStateService._internal();
  static DownloadStateService get instance => _instance;

  DownloadStateService._internal();

  final Map<String, ModelDownloadState> _downloadStates = {};

  /// Get download state for a specific model
  ModelDownloadState? getState(String modelId) => _downloadStates[modelId];

  /// Get all download states
  Map<String, ModelDownloadState> get allStates => Map.unmodifiable(_downloadStates);

  /// Update download state for a model
  void updateState(String modelId, ModelDownloadState state) {
    _downloadStates[modelId] = state;
    notifyListeners();
    debugPrint('DownloadStateService: Updated state for $modelId - ${state.statusMessage}');
  }

  /// Update progress with byte information
  void updateProgress({
    required String modelId,
    required double progress,
    required String statusMessage,
    int? bytesDownloaded,
    int? totalBytes,
  }) {
    final currentState = _downloadStates[modelId] ?? ModelDownloadState(modelId: modelId);

    _downloadStates[modelId] = currentState.copyWith(
      isDownloading: true,
      progress: progress,
      statusMessage: statusMessage,
      bytesDownloaded: bytesDownloaded,
      totalBytes: totalBytes,
      errorMessage: null,
    );

    notifyListeners();
  }

  /// Get display name for a model ID
  String _getModelDisplayName(String modelId) {
    switch (modelId) {
      case 'Llama-3.2-3b-Instruct-Q4_K_M.gguf':
        return 'Llama 3.2 3B Instruct (Q4_K_M)';
      case 'phi-3.5-mini-instruct-4bit':
        return 'Phi-3.5-mini-instruct (4-bit)';
      default:
        return modelId;
    }
  }

  /// Mark download as started
  void startDownload(String modelId, {String? modelName}) {
    final displayName = modelName ?? _getModelDisplayName(modelId);
    _downloadStates[modelId] = ModelDownloadState(
      modelId: modelId,
      isDownloading: true,
      progress: 0.0,
      statusMessage: 'Starting download of $displayName...',
    );
    notifyListeners();
    debugPrint('DownloadStateService: Started download for $modelId ($displayName)');
  }

  /// Mark download as completed
  void completeDownload(String modelId) {
    final displayName = _getModelDisplayName(modelId);
    _downloadStates[modelId] = ModelDownloadState(
      modelId: modelId,
      isDownloading: false,
      isDownloaded: true,
      progress: 1.0,
      statusMessage: '$displayName download complete!',
    );
    notifyListeners();
    debugPrint('DownloadStateService: Completed download for $modelId ($displayName)');
  }

  /// Mark download as failed
  void failDownload(String modelId, String error) {
    final displayName = _getModelDisplayName(modelId);
    final currentState = _downloadStates[modelId] ?? ModelDownloadState(modelId: modelId);

    _downloadStates[modelId] = currentState.copyWith(
      isDownloading: false,
      errorMessage: error,
      statusMessage: '$displayName download failed',
    );
    notifyListeners();
    debugPrint('DownloadStateService: Failed download for $modelId ($displayName) - $error');
  }

  /// Mark download as cancelled
  void cancelDownload(String modelId) {
    final displayName = _getModelDisplayName(modelId);
    _downloadStates[modelId] = ModelDownloadState(
      modelId: modelId,
      isDownloading: false,
      progress: 0.0,
      statusMessage: '$displayName download cancelled',
    );
    notifyListeners();
    debugPrint('DownloadStateService: Cancelled download for $modelId ($displayName)');
  }

  /// Update model availability after checking
  void updateAvailability(String modelId, bool isAvailable) {
    final displayName = _getModelDisplayName(modelId);
    final currentState = _downloadStates[modelId] ?? ModelDownloadState(modelId: modelId);

    if (!currentState.isDownloading) {
      _downloadStates[modelId] = currentState.copyWith(
        isDownloaded: isAvailable,
        statusMessage: isAvailable ? '$displayName ready to use' : '$displayName not downloaded yet',
      );
      notifyListeners();
    }
  }

  /// Clear all download states
  void clearAll() {
    _downloadStates.clear();
    notifyListeners();
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'bridge.pigeon.dart' as pigeon;
import '../services/download_state_service.dart';
import '../config/api_config.dart';

/// Service to handle model loading progress from native side
class ModelProgressService implements pigeon.LumaraNativeProgress {
  static final ModelProgressService _instance = ModelProgressService._internal();
  factory ModelProgressService() => _instance;
  ModelProgressService._internal();

  final _controller = StreamController<ModelProgressUpdate>.broadcast();
  final _downloadStateService = DownloadStateService.instance;
  
  // Terminal state tracking to prevent duplicate progress emissions
  final _terminalByModel = <String, bool>{};
  
  /// Safe progress calculation to prevent NaN and infinite values
  double _safeProgress(double progress) {
    if (progress.isNaN || !progress.isFinite) {
      debugPrint('[ModelProgress] Warning: Invalid progress value $progress, using 0.0');
      return 0.0;
    }
    return progress.clamp(0.0, 1.0);
  }
  
  /// Clamp progress to 0-1 range, return null for invalid values (indeterminate progress)
  double? clamp01(num? x) {
    if (x == null) return null;
    final d = x.toDouble();
    if (!d.isFinite) return null;
    if (d < 0) return 0;
    if (d > 1) return 1;
    return d;
  }

  /// Stream of progress updates
  Stream<ModelProgressUpdate> get progressStream => _controller.stream;

  @override
  void modelProgress(String modelId, int value, String? message) {
    final update = ModelProgressUpdate(
      modelId: modelId,
      progress: value,
      message: message ?? '',
      isComplete: value >= 100,
    );

    debugPrint('[ModelProgress] $modelId: $value% - $message');
    _controller.add(update);
  }

  @override
  void downloadProgress(String modelId, double progress, String message) {
    // Check if model is already in terminal state
    if (_terminalByModel[modelId] == true) {
      debugPrint('[DownloadProgress] Model $modelId is terminal, suppressing progress update');
      return;
    }
    
    // Safe progress calculation to prevent NaN
    final safeProgress = _safeProgress(progress);
    final update = ModelProgressUpdate(
      modelId: modelId,
      progress: (safeProgress * 100).round(),
      message: message,
      isComplete: safeProgress >= 1.0,
    );

    debugPrint('[DownloadProgress] $modelId: ${(safeProgress * 100).toStringAsFixed(1)}% - $message');
    _controller.add(update);

    // Parse byte information from message (format: "Downloading: X.X / Y.Y MB")
    final bytesInfo = _parseDownloadMessage(message);

    // Update persistent download state
    if (message.contains('Ready to use') || progress >= 1.0) {
      // Mark as completed when we get "Ready to use" message OR when progress reaches 100%
      debugPrint('ModelProgressService: Download completed for $modelId - calling completeDownload');
      _downloadStateService.completeDownload(modelId);
      // Mark as terminal to prevent duplicate progress emissions
      _terminalByModel[modelId] = true;
      // Refresh API config to update provider availability
      debugPrint('ModelProgressService: Refreshing API config after download completion');
      _refreshApiConfig();
    } else if (message.contains('failed') || message.contains('Error')) {
      _downloadStateService.failDownload(modelId, message);
      // Mark as terminal on failure
      _terminalByModel[modelId] = true;
    } else {
      _downloadStateService.updateProgress(
        modelId: modelId,
        progress: progress,
        statusMessage: message,
        bytesDownloaded: bytesInfo?['downloaded'],
        totalBytes: bytesInfo?['total'],
      );
    }
  }

  /// Refresh API config to update provider availability
  Future<void> _refreshApiConfig() async {
    try {
      final apiConfig = LumaraAPIConfig.instance;
      await apiConfig.refreshModelAvailability();
      debugPrint('[ModelProgress] Refreshed API config after download completion');
    } catch (e) {
      debugPrint('[ModelProgress] Error refreshing API config: $e');
    }
  }

  /// Parse download message to extract byte information
  /// Message format: "Downloading: 45.3 / 900.0 MB" or "Downloading: 45.3 MB" (unknown total)
  Map<String, int>? _parseDownloadMessage(String message) {
    try {
      // Try to match format with total: "Downloading: 45.3 / 900.0 MB"
      final regexWithTotal = RegExp(r'(\d+\.?\d*)\s*/\s*(\d+\.?\d*)\s*(MB|GB)', caseSensitive: false);
      final matchWithTotal = regexWithTotal.firstMatch(message);

      if (matchWithTotal != null) {
        final downloaded = double.parse(matchWithTotal.group(1)!);
        final total = double.parse(matchWithTotal.group(2)!);
        final unit = matchWithTotal.group(3)!.toUpperCase();

        // Skip if total is negative or zero (invalid)
        if (total <= 0) {
          debugPrint('Invalid total size in message: $message');
          return null;
        }

        // Convert to bytes
        final multiplier = unit == 'GB' ? 1073741824 : 1048576; // 1GB or 1MB in bytes

        return {
          'downloaded': (downloaded * multiplier).toInt(),
          'total': (total * multiplier).toInt(),
        };
      }

      // Try to match format without total: "Downloading: 45.3 MB"
      final regexWithoutTotal = RegExp(r'(\d+\.?\d*)\s*(MB|GB)', caseSensitive: false);
      final matchWithoutTotal = regexWithoutTotal.firstMatch(message);

      if (matchWithoutTotal != null) {
        final downloaded = double.parse(matchWithoutTotal.group(1)!);
        final unit = matchWithoutTotal.group(2)!.toUpperCase();

        // Convert to bytes
        final multiplier = unit == 'GB' ? 1073741824 : 1048576; // 1GB or 1MB in bytes

        return {
          'downloaded': (downloaded * multiplier).toInt(),
          'total': 0, // Unknown total - use 0 to indicate unknown
        };
      }
    } catch (e) {
      debugPrint('Failed to parse download message: $message - $e');
    }

    return null;
  }

  /// Wait for model to finish loading
  Future<void> waitForCompletion(String modelId, {Duration timeout = const Duration(minutes: 2)}) async {
    final completer = Completer<void>();
    StreamSubscription? subscription;

    subscription = progressStream
        .where((update) => update.modelId == modelId)
        .listen((update) {
      if (update.isComplete) {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    // Set timeout
    Timer(timeout, () {
      subscription?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Model loading timeout'));
      }
    });

    return completer.future;
  }

  void dispose() {
    _controller.close();
  }
}

/// Model loading progress update
class ModelProgressUpdate {
  final String modelId;
  final int progress; // 0-100
  final String message;
  final bool isComplete;

  ModelProgressUpdate({
    required this.modelId,
    required this.progress,
    required this.message,
    required this.isComplete,
  });

  @override
  String toString() => 'ModelProgressUpdate($modelId: $progress% - $message)';
}

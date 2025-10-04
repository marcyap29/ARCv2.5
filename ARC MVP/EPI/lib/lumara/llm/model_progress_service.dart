import 'dart:async';
import 'package:flutter/foundation.dart';
import 'bridge.pigeon.dart' as pigeon;
import '../services/download_state_service.dart';

/// Service to handle model loading progress from native side
class ModelProgressService implements pigeon.LumaraNativeProgress {
  static final ModelProgressService _instance = ModelProgressService._internal();
  factory ModelProgressService() => _instance;
  ModelProgressService._internal();

  final _controller = StreamController<ModelProgressUpdate>.broadcast();
  final _downloadStateService = DownloadStateService.instance;

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
    final update = ModelProgressUpdate(
      modelId: modelId,
      progress: (progress * 100).round(),
      message: message,
      isComplete: progress >= 1.0,
    );

    debugPrint('[DownloadProgress] $modelId: ${(progress * 100).toStringAsFixed(1)}% - $message');
    _controller.add(update);

    // Parse byte information from message (format: "Downloading: X.X / Y.Y MB")
    final bytesInfo = _parseDownloadMessage(message);

    // Update persistent download state
    if (message.contains('Ready to use')) {
      _downloadStateService.completeDownload(modelId);
    } else if (message.contains('failed') || message.contains('Error')) {
      _downloadStateService.failDownload(modelId, message);
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

  /// Parse download message to extract byte information
  /// Message format: "Downloading: 45.3 / 900.0 MB"
  Map<String, int>? _parseDownloadMessage(String message) {
    try {
      final regex = RegExp(r'(\d+\.?\d*)\s*/\s*(\d+\.?\d*)\s*(MB|GB)', caseSensitive: false);
      final match = regex.firstMatch(message);

      if (match != null) {
        final downloaded = double.parse(match.group(1)!);
        final total = double.parse(match.group(2)!);
        final unit = match.group(3)!.toUpperCase();

        // Convert to bytes
        final multiplier = unit == 'GB' ? 1073741824 : 1048576; // 1GB or 1MB in bytes

        return {
          'downloaded': (downloaded * multiplier).toInt(),
          'total': (total * multiplier).toInt(),
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

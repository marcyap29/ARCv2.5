import 'dart:async';
import 'package:flutter/foundation.dart';
import 'bridge.pigeon.dart' as pigeon;

/// Service to handle model loading progress from native side
class ModelProgressService implements pigeon.LumaraNativeProgress {
  static final ModelProgressService _instance = ModelProgressService._internal();
  factory ModelProgressService() => _instance;
  ModelProgressService._internal();

  final _controller = StreamController<ModelProgressUpdate>.broadcast();

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

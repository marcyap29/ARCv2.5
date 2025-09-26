import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:typed_data';

/// Progress event for media import operations
class ImportProgress {
  final String entryId;
  final String taskId;
  final ImportStage stage;
  final double percentage;
  final String? message;
  final String? error;

  const ImportProgress({
    required this.entryId,
    required this.taskId,
    required this.stage,
    required this.percentage,
    this.message,
    this.error,
  });

  @override
  String toString() => 'ImportProgress($entryId, $stage, ${(percentage * 100).toStringAsFixed(1)}%)';
}

enum ImportStage {
  queued,
  hashing,
  transcoding,
  analyzing,
  thumbnailing,
  encrypting,
  emitting,
  completed,
  failed,
}

/// Background job for media processing
class MediaProcessingJob {
  final String id;
  final String entryId;
  final Uint8List data;
  final String mediaType;
  final Map<String, dynamic> options;
  final DateTime createdAt;
  int retryCount;

  MediaProcessingJob({
    required this.id,
    required this.entryId,
    required this.data,
    required this.mediaType,
    required this.options,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'entryId': entryId,
    'data': data,
    'mediaType': mediaType,
    'options': options,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'retryCount': retryCount,
  };

  factory MediaProcessingJob.fromMap(Map<String, dynamic> map) {
    return MediaProcessingJob(
      id: map['id'],
      entryId: map['entryId'],
      data: map['data'],
      mediaType: map['mediaType'],
      options: Map<String, dynamic>.from(map['options']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      retryCount: map['retryCount'] ?? 0,
    );
  }
}

/// Result of background media processing
class MediaProcessingResult {
  final String jobId;
  final String entryId;
  final bool success;
  final String? pointerId;
  final String? error;
  final Map<String, dynamic> metadata;

  const MediaProcessingResult({
    required this.jobId,
    required this.entryId,
    required this.success,
    this.pointerId,
    this.error,
    this.metadata = const {},
  });
}

/// Background processor with isolate-based workers and job queue
class BackgroundProcessor {
  static const int _maxWorkers = 2;
  static const int _maxRetries = 3;
  static const Duration _workerTimeout = Duration(minutes: 5);

  final Queue<MediaProcessingJob> _jobQueue = Queue<MediaProcessingJob>();
  final Map<String, Isolate> _activeWorkers = {};
  final Map<String, SendPort> _workerPorts = {};
  final StreamController<ImportProgress> _progressController = StreamController<ImportProgress>.broadcast();
  final StreamController<MediaProcessingResult> _resultController = StreamController<MediaProcessingResult>.broadcast();

  bool _isRunning = false;
  Timer? _queueProcessor;

  /// Stream of import progress events
  Stream<ImportProgress> get progressStream => _progressController.stream;

  /// Stream of processing results
  Stream<MediaProcessingResult> get resultStream => _resultController.stream;

  /// Start the background processor
  Future<void> start() async {
    if (_isRunning) return;
    
    _isRunning = true;
    _queueProcessor = Timer.periodic(const Duration(milliseconds: 500), (_) => _processQueue());
    
    print('BackgroundProcessor: Started with $_maxWorkers workers');
  }

  /// Stop the background processor
  Future<void> stop() async {
    _isRunning = false;
    _queueProcessor?.cancel();
    
    // Kill all active workers
    for (final isolate in _activeWorkers.values) {
      isolate.kill(priority: Isolate.immediate);
    }
    
    _activeWorkers.clear();
    _workerPorts.clear();
    
    print('BackgroundProcessor: Stopped');
  }

  /// Add a job to the processing queue
  Future<void> enqueueJob(MediaProcessingJob job) async {
    _jobQueue.add(job);
    
    _progressController.add(ImportProgress(
      entryId: job.entryId,
      taskId: job.id,
      stage: ImportStage.queued,
      percentage: 0.0,
      message: 'Job queued for processing',
    ));
    
    print('BackgroundProcessor: Enqueued job ${job.id} for entry ${job.entryId}');
  }

  /// Process the job queue
  void _processQueue() {
    if (!_isRunning || _jobQueue.isEmpty) return;
    
    // Don't exceed max workers
    if (_activeWorkers.length >= _maxWorkers) return;
    
    final job = _jobQueue.removeFirst();
    _startWorkerForJob(job);
  }

  /// Start an isolate worker for a job
  Future<void> _startWorkerForJob(MediaProcessingJob job) async {
    try {
      final receivePort = ReceivePort();
      final isolate = await Isolate.spawn(_workerEntryPoint, receivePort.sendPort);
      
      _activeWorkers[job.id] = isolate;
      
      // Listen for worker messages
      final subscription = receivePort.listen((message) {
        _handleWorkerMessage(job.id, message);
      });

      // Set up timeout
      Timer(_workerTimeout, () {
        if (_activeWorkers.containsKey(job.id)) {
          _killWorker(job.id, 'Worker timeout');
        }
      });

      // Wait for worker to be ready, then send job
      final completer = Completer<SendPort>();
      late StreamSubscription readySubscription;
      
      readySubscription = receivePort.listen((message) {
        if (message is SendPort) {
          _workerPorts[job.id] = message;
          completer.complete(message);
          readySubscription.cancel();
        }
      });

      final sendPort = await completer.future;
      sendPort.send(job.toMap());
      
    } catch (e) {
      print('BackgroundProcessor: Failed to start worker for job ${job.id}: $e');
      _handleJobFailure(job, 'Failed to start worker: $e');
    }
  }

  /// Handle messages from worker isolates
  void _handleWorkerMessage(String jobId, dynamic message) {
    if (message is Map<String, dynamic>) {
      final type = message['type'];
      
      switch (type) {
        case 'progress':
          final progress = ImportProgress(
            entryId: message['entryId'],
            taskId: jobId,
            stage: ImportStage.values.byName(message['stage']),
            percentage: message['percentage'].toDouble(),
            message: message['message'],
          );
          _progressController.add(progress);
          break;
          
        case 'result':
          final result = MediaProcessingResult(
            jobId: jobId,
            entryId: message['entryId'],
            success: message['success'],
            pointerId: message['pointerId'],
            error: message['error'],
            metadata: Map<String, dynamic>.from(message['metadata'] ?? {}),
          );
          _resultController.add(result);
          _cleanupWorker(jobId);
          break;
          
        case 'error':
          final job = _findJobById(jobId);
          if (job != null) {
            _handleJobFailure(job, message['error']);
          }
          _cleanupWorker(jobId);
          break;
      }
    }
  }

  /// Find job by ID (would normally be stored in a proper job store)
  MediaProcessingJob? _findJobById(String jobId) {
    // In a real implementation, this would query a persistent job store
    return null;
  }

  /// Handle job failure with retry logic
  void _handleJobFailure(MediaProcessingJob job, String error) {
    job.retryCount++;
    
    if (job.retryCount <= _maxRetries) {
      print('BackgroundProcessor: Retrying job ${job.id} (attempt ${job.retryCount}/$_maxRetries)');
      
      _progressController.add(ImportProgress(
        entryId: job.entryId,
        taskId: job.id,
        stage: ImportStage.queued,
        percentage: 0.0,
        message: 'Retrying job (attempt ${job.retryCount}/$_maxRetries)',
      ));
      
      // Re-queue with delay
      Timer(Duration(seconds: job.retryCount * 2), () {
        _jobQueue.add(job);
      });
    } else {
      print('BackgroundProcessor: Job ${job.id} failed after $_maxRetries attempts: $error');
      
      _progressController.add(ImportProgress(
        entryId: job.entryId,
        taskId: job.id,
        stage: ImportStage.failed,
        percentage: 1.0,
        error: error,
      ));
      
      _resultController.add(MediaProcessingResult(
        jobId: job.id,
        entryId: job.entryId,
        success: false,
        error: error,
      ));
    }
  }

  /// Kill a worker isolate
  void _killWorker(String jobId, String reason) {
    final isolate = _activeWorkers[jobId];
    if (isolate != null) {
      isolate.kill(priority: Isolate.immediate);
      print('BackgroundProcessor: Killed worker for job $jobId: $reason');
    }
    _cleanupWorker(jobId);
  }

  /// Clean up worker resources
  void _cleanupWorker(String jobId) {
    _activeWorkers.remove(jobId);
    _workerPorts.remove(jobId);
  }

  /// Get queue status
  Map<String, dynamic> getStatus() {
    return {
      'isRunning': _isRunning,
      'queuedJobs': _jobQueue.length,
      'activeWorkers': _activeWorkers.length,
      'maxWorkers': _maxWorkers,
    };
  }
}

/// Entry point for worker isolates
void _workerEntryPoint(SendPort mainSendPort) async {
  final receivePort = ReceivePort();
  
  // Send our send port back to main isolate
  mainSendPort.send(receivePort.sendPort);
  
  // Listen for jobs
  receivePort.listen((message) async {
    if (message is Map<String, dynamic>) {
      try {
        final job = MediaProcessingJob.fromMap(message);
        await _processJobInIsolate(job, mainSendPort);
      } catch (e) {
        mainSendPort.send({
          'type': 'error',
          'error': 'Worker processing failed: $e',
        });
      }
    }
  });
}

/// Process a job in the worker isolate
Future<void> _processJobInIsolate(MediaProcessingJob job, SendPort mainSendPort) async {
  try {
    // Send progress updates
    void sendProgress(ImportStage stage, double percentage, {String? message}) {
      mainSendPort.send({
        'type': 'progress',
        'entryId': job.entryId,
        'stage': stage.name,
        'percentage': percentage,
        'message': message,
      });
    }

    sendProgress(ImportStage.hashing, 0.1, message: 'Computing content hash');
    
    // Compute hash (streaming to avoid loading full file into memory)
    final hash = await _computeHashStreaming(job.data);
    
    sendProgress(ImportStage.analyzing, 0.3, message: 'Analyzing content');
    
    // Process based on media type
    String? pointerId;
    Map<String, dynamic> metadata = {};
    
    switch (job.mediaType) {
      case 'image':
        final result = await _processImageInIsolate(job.data, job.options);
        pointerId = result['pointerId'];
        metadata = result['metadata'];
        break;
      case 'audio':
        final result = await _processAudioInIsolate(job.data, job.options);
        pointerId = result['pointerId'];
        metadata = result['metadata'];
        break;
      case 'video':
        final result = await _processVideoInIsolate(job.data, job.options);
        pointerId = result['pointerId'];
        metadata = result['metadata'];
        break;
    }
    
    sendProgress(ImportStage.emitting, 0.9, message: 'Emitting pointer');
    
    // Emit pointer and embeddings would happen here
    
    sendProgress(ImportStage.completed, 1.0, message: 'Processing complete');
    
    // Send final result
    mainSendPort.send({
      'type': 'result',
      'entryId': job.entryId,
      'success': true,
      'pointerId': pointerId,
      'metadata': metadata,
    });
    
  } catch (e) {
    mainSendPort.send({
      'type': 'error',
      'error': 'Processing failed: $e',
    });
  }
}

/// Compute hash using streaming approach
Future<String> _computeHashStreaming(Uint8List data) async {
  // In a real implementation, this would process the data in chunks
  // to avoid loading everything into memory at once
  return data.hashCode.toString(); // Placeholder
}

/// Process image in isolate
Future<Map<String, dynamic>> _processImageInIsolate(
  Uint8List imageData,
  Map<String, dynamic> options,
) async {
  // Placeholder for image processing
  // Would include: thumbnail generation, OCR, face detection, etc.
  await Future.delayed(const Duration(seconds: 1)); // Simulate work
  
  return {
    'pointerId': 'ptr_image_${DateTime.now().millisecondsSinceEpoch}',
    'metadata': {
      'width': 1920,
      'height': 1080,
      'size': imageData.length,
    },
  };
}

/// Process audio in isolate
Future<Map<String, dynamic>> _processAudioInIsolate(
  Uint8List audioData,
  Map<String, dynamic> options,
) async {
  // Placeholder for audio processing
  // Would include: transcription, VAD, waveform generation, etc.
  await Future.delayed(const Duration(seconds: 2)); // Simulate work
  
  return {
    'pointerId': 'ptr_audio_${DateTime.now().millisecondsSinceEpoch}',
    'metadata': {
      'duration': 120.5,
      'sampleRate': 16000,
      'size': audioData.length,
    },
  };
}

/// Process video in isolate
Future<Map<String, dynamic>> _processVideoInIsolate(
  Uint8List videoData,
  Map<String, dynamic> options,
) async {
  // Placeholder for video processing
  // Would include: keyframe extraction, transcoding, scene detection, etc.
  await Future.delayed(const Duration(seconds: 3)); // Simulate work
  
  return {
    'pointerId': 'ptr_video_${DateTime.now().millisecondsSinceEpoch}',
    'metadata': {
      'duration': 62.4,
      'width': 1920,
      'height': 1080,
      'fps': 30,
      'size': videoData.length,
    },
  };
}
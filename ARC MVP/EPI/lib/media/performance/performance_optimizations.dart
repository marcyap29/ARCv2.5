import 'dart:typed_data';
import 'dart:isolate';
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

/// Performance optimization defaults for mobile devices
class PerformanceDefaults {
  // Thumbnail sizes
  static const int standardThumbnailSize = 256;
  static const int analysisVariantSize = 1024;
  
  // Video processing
  static const String videoProxyResolution = '360p';
  static const String videoCodec = 'h264';
  static const int videoCRF = 28; // Constant Rate Factor for compression
  
  // Audio processing
  static const int vadWindowMinSec = 20;
  static const int vadWindowMaxSec = 45;
  static const int waveformPreviewWidth = 1200;
  
  // Processing limits
  static const int maxConcurrentJobs = 2;
  static const int maxMemoryUsageMB = 100;
  static const Duration processingTimeout = Duration(minutes: 5);
}

/// Optimized thumbnail generator with memory management
class OptimizedThumbnailGenerator {
  /// Generate thumbnail with memory-efficient streaming
  static Future<Uint8List> generateThumbnail(
    Uint8List imageData, {
    int targetSize = PerformanceDefaults.standardThumbnailSize,
    bool maintainAspectRatio = true,
    int quality = 85,
  }) async {
    try {
      // Use Isolate for CPU-intensive work
      final result = await Isolate.run(() {
        return _generateThumbnailInIsolate(
          imageData,
          targetSize,
          maintainAspectRatio,
          quality,
        );
      });
      
      return result;
    } catch (e) {
      throw ThumbnailGenerationException('Thumbnail generation failed: $e');
    }
  }

  /// Generate thumbnail in isolate to avoid blocking main thread
  static Uint8List _generateThumbnailInIsolate(
    Uint8List imageData,
    int targetSize,
    bool maintainAspectRatio,
    int quality,
  ) {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Calculate target dimensions
      int targetWidth, targetHeight;
      if (maintainAspectRatio) {
        if (image.width > image.height) {
          targetWidth = targetSize;
          targetHeight = (targetSize * image.height / image.width).round();
        } else {
          targetHeight = targetSize;
          targetWidth = (targetSize * image.width / image.height).round();
        }
      } else {
        targetWidth = targetSize;
        targetHeight = targetSize;
      }

      // Resize with high-quality algorithm
      final resized = img.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.cubic,
      );

      // Encode as JPEG with specified quality
      return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    } catch (e) {
      throw ThumbnailGenerationException('Isolate thumbnail generation failed: $e');
    }
  }

  /// Generate multiple thumbnail sizes efficiently
  static Future<Map<int, Uint8List>> generateMultipleThumbnails(
    Uint8List imageData,
    List<int> sizes,
  ) async {
    return await Isolate.run(() {
      final thumbnails = <int, Uint8List>{};
      
      final image = img.decodeImage(imageData);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      for (final size in sizes) {
        try {
          final resized = img.copyResize(
            image,
            width: size,
            height: (size * image.height / image.width).round(),
            interpolation: img.Interpolation.cubic,
          );
          
          thumbnails[size] = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
        } catch (e) {
          print('Failed to generate ${size}px thumbnail: $e');
        }
      }
      
      return thumbnails;
    });
  }
}

/// Optimized waveform generator for audio visualization
class OptimizedWaveformGenerator {
  /// Generate waveform preview PNG
  static Future<Uint8List> generateWaveform(
    Uint8List audioData, {
    int width = PerformanceDefaults.waveformPreviewWidth,
    int height = 200,
    int sampleRate = 16000,
  }) async {
    return await Isolate.run(() {
      return _generateWaveformInIsolate(audioData, width, height, sampleRate);
    });
  }

  static Uint8List _generateWaveformInIsolate(
    Uint8List audioData,
    int width,
    int height,
    int sampleRate,
  ) {
    try {
      // Simplified waveform generation
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(30, 30, 30)); // Dark background

      final samplesPerPixel = audioData.length ~/ width;
      if (samplesPerPixel <= 0) return Uint8List.fromList(img.encodePng(image));

      final centerY = height ~/ 2;
      
      for (int x = 0; x < width; x++) {
        final startSample = x * samplesPerPixel;
        final endSample = ((x + 1) * samplesPerPixel).clamp(0, audioData.length);
        
        // Calculate RMS amplitude for this pixel column
        double rms = 0.0;
        int sampleCount = 0;
        
        for (int i = startSample; i < endSample; i += 2) {
          if (i + 1 < audioData.length) {
            // Assume 16-bit little-endian samples
            final sample = (audioData[i + 1] << 8) | audioData[i];
            final normalized = sample / 32768.0;
            rms += normalized * normalized;
            sampleCount++;
          }
        }
        
        if (sampleCount > 0) {
          rms = sqrt(rms / sampleCount);
          final amplitude = (rms * centerY).round().clamp(0, centerY);
          
          // Draw waveform line
          for (int y = centerY - amplitude; y <= centerY + amplitude; y++) {
            if (y >= 0 && y < height) {
              image.setPixel(x, y, img.ColorRgb8(100, 150, 255));
            }
          }
        }
      }

      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      throw WaveformGenerationException('Waveform generation failed: $e');
    }
  }
}

/// Memory-efficient video proxy generator
class OptimizedVideoProxyGenerator {
  /// Generate compressed video proxy
  static Future<Uint8List> generateProxy(
    Uint8List videoData, {
    String resolution = PerformanceDefaults.videoProxyResolution,
    int crf = PerformanceDefaults.videoCRF,
    String codec = PerformanceDefaults.videoCodec,
  }) async {
    // This would require FFmpeg integration in a real implementation
    // For now, return a placeholder
    
    print('OptimizedVideoProxyGenerator: Would generate $resolution proxy with CRF $crf');
    
    // Simulate compression by returning a smaller version of the data
    final compressionRatio = _getCompressionRatio(resolution);
    final compressedSize = (videoData.length * compressionRatio).round();
    
    return Uint8List.fromList(
      videoData.take(compressedSize).toList(),
    );
  }

  static double _getCompressionRatio(String resolution) {
    switch (resolution) {
      case '360p':
        return 0.15; // 85% compression
      case '720p':
        return 0.35; // 65% compression
      case '1080p':
        return 0.65; // 35% compression
      default:
        return 0.25; // Default compression
    }
  }

  /// Extract keyframes at optimal intervals
  static Future<List<VideoKeyframeData>> extractOptimizedKeyframes(
    Uint8List videoData, {
    Duration interval = const Duration(seconds: 10),
    int maxKeyframes = 20,
  }) async {
    // In a real implementation, this would use FFmpeg to extract frames
    // For now, return mock keyframe data
    
    final keyframes = <VideoKeyframeData>[];
    final intervalSeconds = interval.inSeconds;
    
    for (int i = 0; i < maxKeyframes; i++) {
      final timestamp = i * intervalSeconds.toDouble();
      
      // Mock thumbnail data
      final thumbnailData = await OptimizedThumbnailGenerator.generateThumbnail(
        Uint8List.fromList(List.generate(100, (i) => i % 256)), // Mock image data
        targetSize: PerformanceDefaults.standardThumbnailSize,
      );
      
      keyframes.add(VideoKeyframeData(
        timestamp: timestamp,
        thumbnailData: thumbnailData,
      ));
    }
    
    return keyframes;
  }
}

/// Performance monitor for media processing
class MediaProcessingPerformanceMonitor {
  static final Map<String, ProcessingMetrics> _metrics = {};
  
  /// Start monitoring a processing task
  static ProcessingTimer startTimer(String taskId, String taskType) {
    final timer = ProcessingTimer(taskId, taskType);
    _metrics[taskId] = ProcessingMetrics(
      taskId: taskId,
      taskType: taskType,
      startTime: DateTime.now(),
    );
    return timer;
  }

  /// End monitoring and record results
  static void endTimer(
    ProcessingTimer timer, {
    bool success = true,
    int? bytesProcessed,
    String? error,
  }) {
    final metrics = _metrics[timer.taskId];
    if (metrics != null) {
      metrics.endTime = DateTime.now();
      metrics.duration = metrics.endTime!.difference(metrics.startTime);
      metrics.success = success;
      metrics.bytesProcessed = bytesProcessed;
      metrics.error = error;
      
      _logPerformanceMetrics(metrics);
    }
  }

  /// Get performance statistics
  static PerformanceStats getStats() {
    final allMetrics = _metrics.values.toList();
    final successfulTasks = allMetrics.where((m) => m.success).toList();
    final failedTasks = allMetrics.where((m) => !m.success).toList();
    
    if (allMetrics.isEmpty) {
      return const PerformanceStats(
        totalTasks: 0,
        successfulTasks: 0,
        failedTasks: 0,
        averageDuration: Duration.zero,
        totalBytesProcessed: 0,
      );
    }
    
    final totalDuration = allMetrics
        .where((m) => m.duration != null)
        .map((m) => m.duration!.inMilliseconds)
        .reduce((a, b) => a + b);
    
    final averageDuration = Duration(
      milliseconds: totalDuration ~/ allMetrics.length,
    );
    
    final totalBytes = allMetrics
        .where((m) => m.bytesProcessed != null)
        .map((m) => m.bytesProcessed!)
        .fold<int>(0, (sum, bytes) => sum + bytes);
    
    return PerformanceStats(
      totalTasks: allMetrics.length,
      successfulTasks: successfulTasks.length,
      failedTasks: failedTasks.length,
      averageDuration: averageDuration,
      totalBytesProcessed: totalBytes,
      tasksByType: _groupTasksByType(allMetrics),
    );
  }

  static void _logPerformanceMetrics(ProcessingMetrics metrics) {
    final durationMs = metrics.duration?.inMilliseconds ?? 0;
    final throughputMBps = metrics.bytesProcessed != null && durationMs > 0
        ? (metrics.bytesProcessed! / (1024 * 1024)) / (durationMs / 1000.0)
        : 0.0;
    
    print('MediaProcessing: ${metrics.taskType} ${metrics.taskId} '
        'completed in ${durationMs}ms, '
        'throughput: ${throughputMBps.toStringAsFixed(2)} MB/s, '
        'success: ${metrics.success}');
  }

  static Map<String, int> _groupTasksByType(List<ProcessingMetrics> metrics) {
    final grouped = <String, int>{};
    for (final metric in metrics) {
      grouped[metric.taskType] = (grouped[metric.taskType] ?? 0) + 1;
    }
    return grouped;
  }

  /// Clear old metrics to prevent memory leaks
  static void cleanup({Duration maxAge = const Duration(hours: 1)}) {
    final cutoff = DateTime.now().subtract(maxAge);
    _metrics.removeWhere((key, metrics) => 
        metrics.startTime.isBefore(cutoff));
  }
}

/// Timer for tracking processing performance
class ProcessingTimer {
  final String taskId;
  final String taskType;
  final DateTime startTime;

  ProcessingTimer(this.taskId, this.taskType) : startTime = DateTime.now();
}

/// Metrics for a processing task
class ProcessingMetrics {
  final String taskId;
  final String taskType;
  final DateTime startTime;
  DateTime? endTime;
  Duration? duration;
  bool success = true;
  int? bytesProcessed;
  String? error;

  ProcessingMetrics({
    required this.taskId,
    required this.taskType,
    required this.startTime,
  });
}

/// Performance statistics
class PerformanceStats {
  final int totalTasks;
  final int successfulTasks;
  final int failedTasks;
  final Duration averageDuration;
  final int totalBytesProcessed;
  final Map<String, int> tasksByType;

  const PerformanceStats({
    required this.totalTasks,
    required this.successfulTasks,
    required this.failedTasks,
    required this.averageDuration,
    required this.totalBytesProcessed,
    this.tasksByType = const {},
  });

  double get successRate => totalTasks > 0 ? successfulTasks / totalTasks : 0.0;
  double get totalMBProcessed => totalBytesProcessed / (1024 * 1024);
  
  @override
  String toString() {
    return 'PerformanceStats(tasks: $totalTasks, success: ${(successRate * 100).toStringAsFixed(1)}%, '
           'avgDuration: ${averageDuration.inMilliseconds}ms, throughput: ${totalMBProcessed.toStringAsFixed(1)}MB)';
  }
}

/// Video keyframe data
class VideoKeyframeData {
  final double timestamp;
  final Uint8List thumbnailData;

  const VideoKeyframeData({
    required this.timestamp,
    required this.thumbnailData,
  });
}

/// Custom exceptions for performance operations
class ThumbnailGenerationException implements Exception {
  final String message;
  const ThumbnailGenerationException(this.message);
  
  @override
  String toString() => 'ThumbnailGenerationException: $message';
}

class WaveformGenerationException implements Exception {
  final String message;
  const WaveformGenerationException(this.message);
  
  @override
  String toString() => 'WaveformGenerationException: $message';
}

/// Memory usage monitor for preventing OOM
class MemoryUsageMonitor {
  static int _currentUsageMB = 0;
  static final List<MemoryAllocation> _allocations = [];

  /// Track memory allocation
  static void allocate(String taskId, int sizeMB) {
    _allocations.add(MemoryAllocation(taskId, sizeMB, DateTime.now()));
    _currentUsageMB += sizeMB;
    
    if (_currentUsageMB > PerformanceDefaults.maxMemoryUsageMB) {
      print('MemoryUsageMonitor: WARNING - Memory usage ${_currentUsageMB}MB exceeds limit');
    }
  }

  /// Track memory deallocation
  static void deallocate(String taskId) {
    final allocation = _allocations.where((a) => a.taskId == taskId).firstOrNull;
    if (allocation != null) {
      _currentUsageMB -= allocation.sizeMB;
      _allocations.remove(allocation);
    }
  }

  /// Get current memory usage
  static int getCurrentUsageMB() => _currentUsageMB;

  /// Check if allocation would exceed limits
  static bool canAllocate(int sizeMB) {
    return (_currentUsageMB + sizeMB) <= PerformanceDefaults.maxMemoryUsageMB;
  }

  /// Force cleanup of old allocations
  static void cleanup() {
    _allocations.clear();
    _currentUsageMB = 0;
  }
}

class MemoryAllocation {
  final String taskId;
  final int sizeMB;
  final DateTime allocatedAt;

  const MemoryAllocation(this.taskId, this.sizeMB, this.allocatedAt);
}
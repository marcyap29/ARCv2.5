import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../pointer/pointer_models.dart';
import '../crypto/hash_utils.dart';

/// Result of video analysis and keyframe extraction
class VideoDerivative {
  final List<VideoKeyframe> keyframes;
  final List<TranscriptSegment> captions;
  final VideoMetadata metadata;
  final String? proxyUri; // Optional compressed proxy video

  const VideoDerivative({
    required this.keyframes,
    required this.captions,
    required this.metadata,
    this.proxyUri,
  });
}

/// Keyframe with extracted thumbnail
class VideoKeyframe {
  final double timestamp;
  final Uint8List thumbnailData;
  final String casUri;
  final int width;
  final int height;

  const VideoKeyframe({
    required this.timestamp,
    required this.thumbnailData,
    required this.casUri,
    required this.width,
    required this.height,
  });
}

/// Video metadata extracted during analysis
class VideoMetadata {
  final double duration;
  final int width;
  final int height;
  final double fps;
  final int? audioChannels;
  final int? audioBitrate;
  final int? videoBitrate;
  final String codec;
  final String container;

  const VideoMetadata({
    required this.duration,
    required this.width,
    required this.height,
    required this.fps,
    this.audioChannels,
    this.audioBitrate,
    this.videoBitrate,
    required this.codec,
    required this.container,
  });
}

/// Scene cut detection result
class SceneCut {
  final double timestamp;
  final double confidence;
  final String type; // 'hard_cut', 'fade', 'dissolve'

  const SceneCut({
    required this.timestamp,
    required this.confidence,
    required this.type,
  });
}

/// Abstract interface for video keyframe extraction
abstract class VideoKeyframeService {
  Future<VideoDerivative> derive(
    Uint8List videoBytes, {
    Duration keyframeEvery = const Duration(seconds: 10),
    bool enableSceneCuts = true,
    bool enableProxy = false,
    ProxyQuality proxyQuality = ProxyQuality.low,
  });
  
  Future<List<SceneCut>> detectSceneCuts(Uint8List videoBytes);
  Future<VideoMetadata> extractMetadata(Uint8List videoBytes);
  Future<void> dispose();
}

/// Proxy video quality settings
enum ProxyQuality {
  low,    // 360p
  medium, // 720p
  high,   // 1080p
}

/// FFmpeg-based implementation (stub)
/// In production, this would use ffmpeg_kit_flutter
class FFmpegVideoKeyframeService implements VideoKeyframeService {
  static const String _tempDirectoryName = 'video_processing';
  
  @override
  Future<VideoDerivative> derive(
    Uint8List videoBytes, {
    Duration keyframeEvery = const Duration(seconds: 10),
    bool enableSceneCuts = true,
    bool enableProxy = false,
    ProxyQuality proxyQuality = ProxyQuality.low,
  }) async {
    try {
      // Create temporary file for processing
      final tempFile = await _createTempFile(videoBytes);
      
      try {
        // Extract metadata
        final metadata = await extractMetadata(videoBytes);
        
        // Detect scene cuts if enabled
        List<SceneCut> sceneCuts = [];
        if (enableSceneCuts) {
          sceneCuts = await detectSceneCuts(videoBytes);
        }
        
        // Determine keyframe timestamps
        final keyframeTimes = _calculateKeyframeTimes(
          metadata.duration,
          keyframeEvery,
          sceneCuts,
        );
        
        // Extract keyframes
        final keyframes = await _extractKeyframes(tempFile, keyframeTimes, metadata);
        
        // Extract audio captions
        final captions = await _extractCaptions(tempFile, metadata);
        
        // Create proxy video if requested
        String? proxyUri;
        if (enableProxy) {
          proxyUri = await _createProxyVideo(tempFile, proxyQuality, metadata);
        }
        
        return VideoDerivative(
          keyframes: keyframes,
          captions: captions,
          metadata: metadata,
          proxyUri: proxyUri,
        );
      } finally {
        // Clean up temporary file
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e) {
      throw VideoProcessingException('Video processing failed: $e');
    }
  }

  @override
  Future<List<SceneCut>> detectSceneCuts(Uint8List videoBytes) async {
    // Stub implementation - in reality would use FFmpeg scene detection
    final metadata = await extractMetadata(videoBytes);
    final cuts = <SceneCut>[];
    
    // Simulate scene cuts every 15-30 seconds
    for (double t = 15.0; t < metadata.duration; t += 20.0) {
      cuts.add(SceneCut(
        timestamp: t,
        confidence: 0.8,
        type: 'hard_cut',
      ));
    }
    
    return cuts;
  }

  @override
  Future<VideoMetadata> extractMetadata(Uint8List videoBytes) async {
    // Stub implementation - in reality would use FFprobe
    // This provides mock metadata based on common video characteristics
    
    return const VideoMetadata(
      duration: 120.5, // 2 minutes example
      width: 1920,
      height: 1080,
      fps: 30.0,
      audioChannels: 2,
      audioBitrate: 128000,
      videoBitrate: 2000000,
      codec: 'h264',
      container: 'mp4',
    );
  }

  /// Create temporary file for video processing
  Future<File> _createTempFile(Uint8List videoBytes) async {
    final tempDir = await getTemporaryDirectory();
    final processingDir = Directory(path.join(tempDir.path, _tempDirectoryName));
    
    if (!await processingDir.exists()) {
      await processingDir.create(recursive: true);
    }
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempFile = File(path.join(processingDir.path, 'video_$timestamp.mp4'));
    
    await tempFile.writeAsBytes(videoBytes);
    return tempFile;
  }

  /// Calculate keyframe extraction timestamps
  List<double> _calculateKeyframeTimes(
    double duration,
    Duration keyframeEvery,
    List<SceneCut> sceneCuts,
  ) {
    final times = <double>{};
    
    // Regular interval keyframes
    for (double t = 0; t < duration; t += keyframeEvery.inMilliseconds / 1000.0) {
      times.add(t);
    }
    
    // Add scene cut keyframes
    for (final cut in sceneCuts) {
      times.add(cut.timestamp);
      // Also add frame just before cut
      if (cut.timestamp > 1.0) {
        times.add(cut.timestamp - 0.5);
      }
    }
    
    final sortedTimes = times.toList()..sort();
    return sortedTimes;
  }

  /// Extract keyframe thumbnails (stub implementation)
  Future<List<VideoKeyframe>> _extractKeyframes(
    File videoFile,
    List<double> timestamps,
    VideoMetadata metadata,
  ) async {
    final keyframes = <VideoKeyframe>[];
    
    for (final timestamp in timestamps) {
      // Stub: Generate mock thumbnail data
      final thumbnailData = await _generateMockThumbnail(
        timestamp,
        metadata.width,
        metadata.height,
      );
      
      // Store thumbnail in CAS
      final casUri = await CASStore.store('kf', '256', thumbnailData);
      
      keyframes.add(VideoKeyframe(
        timestamp: timestamp,
        thumbnailData: thumbnailData,
        casUri: casUri,
        width: 256, // Thumbnail size
        height: (256 * metadata.height / metadata.width).round(),
      ));
    }
    
    return keyframes;
  }

  /// Generate mock thumbnail data
  Future<Uint8List> _generateMockThumbnail(double timestamp, int width, int height) async {
    // Generate a simple colored rectangle as placeholder thumbnail
    // In reality, this would extract actual video frames using FFmpeg
    
    const thumbnailWidth = 256;
    final thumbnailHeight = (thumbnailWidth * height / width).round();
    
    // Create RGB data (simplified)
    final pixelCount = thumbnailWidth * thumbnailHeight;
    final imageData = Uint8List(pixelCount * 3); // RGB
    
    // Fill with gradient based on timestamp
    final hue = (timestamp * 10) % 360;
    for (int i = 0; i < pixelCount; i++) {
      final y = i ~/ thumbnailWidth;
      final intensity = (y / thumbnailHeight * 255).round();
      
      imageData[i * 3] = intensity; // R
      imageData[i * 3 + 1] = (intensity * 0.7).round(); // G
      imageData[i * 3 + 2] = (intensity * 0.5).round(); // B
    }
    
    return imageData;
  }

  /// Extract captions from video audio track (stub)
  Future<List<TranscriptSegment>> _extractCaptions(
    File videoFile,
    VideoMetadata metadata,
  ) async {
    // Stub implementation
    // In reality, would extract audio track and run speech recognition
    
    final captions = <TranscriptSegment>[];
    const segmentDuration = 10.0;
    
    for (double t = 0; t < metadata.duration; t += segmentDuration) {
      final endTime = (t + segmentDuration).clamp(0, metadata.duration);
      
      captions.add(TranscriptSegment(
        ts: [t, endTime],
        text: _generateMockCaption(t),
      ));
    }
    
    return captions;
  }

  /// Generate mock caption text
  String _generateMockCaption(double timestamp) {
    final mockCaptions = [
      'This is the beginning of the video',
      'Here we see the main content',
      'The demonstration continues',
      'Key points are being explained',
      'This concludes the segment',
    ];
    
    final index = (timestamp / 10).floor() % mockCaptions.length;
    return mockCaptions[index];
  }

  /// Create compressed proxy video (stub)
  Future<String> _createProxyVideo(
    File videoFile,
    ProxyQuality quality,
    VideoMetadata metadata,
  ) async {
    // Stub implementation
    // In reality, would use FFmpeg to create compressed proxy
    
    final proxyData = await _generateMockProxyData(quality, metadata);
    final casUri = await CASStore.store('proxy', _getQualityString(quality), proxyData);
    
    return casUri;
  }

  /// Generate mock proxy video data
  Future<Uint8List> _generateMockProxyData(ProxyQuality quality, VideoMetadata metadata) async {
    // Generate mock compressed video data
    final originalSize = 1000000; // 1MB mock original
    final compressionRatio = _getCompressionRatio(quality);
    final proxySize = (originalSize * compressionRatio).round();
    
    return Uint8List(proxySize);
  }

  String _getQualityString(ProxyQuality quality) {
    switch (quality) {
      case ProxyQuality.low:
        return '360p';
      case ProxyQuality.medium:
        return '720p';
      case ProxyQuality.high:
        return '1080p';
    }
  }

  double _getCompressionRatio(ProxyQuality quality) {
    switch (quality) {
      case ProxyQuality.low:
        return 0.1; // 90% compression
      case ProxyQuality.medium:
        return 0.3; // 70% compression
      case ProxyQuality.high:
        return 0.6; // 40% compression
    }
  }

  @override
  Future<void> dispose() async {
    // Clean up temporary files
    try {
      final tempDir = await getTemporaryDirectory();
      final processingDir = Directory(path.join(tempDir.path, _tempDirectoryName));
      
      if (await processingDir.exists()) {
        await processingDir.delete(recursive: true);
      }
    } catch (e) {
      print('FFmpegVideoKeyframeService: Error cleaning up temp files: $e');
    }
  }
}

/// Exception thrown during video processing
class VideoProcessingException implements Exception {
  final String message;
  const VideoProcessingException(this.message);
  
  @override
  String toString() => 'VideoProcessingException: $message';
}
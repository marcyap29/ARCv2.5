import 'package:my_app/arc/chat/chat/content_parts.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'ocp_services.dart';

/// Multimodal processor for chat messages
/// Handles OCP analysis and PRISM reduction for chat content
class ChatMultimodalProcessor {

  /// Process a chat message with media content
  Future<ProcessedChatMessage> processMessage(ChatMessage message) async {
    final processedParts = <ContentPart>[];
    
    final contentParts = message.contentParts;
    if (contentParts != null) {
      for (final part in contentParts) {
        if (part is MediaContentPart) {
          // Process media content through OCP + PRISM pipeline
          final processedPart = await _processMediaPart(part);
          processedParts.add(processedPart);
        } else {
          // Keep non-media parts as-is
          processedParts.add(part);
        }
      }
    }
    
    return ProcessedChatMessage(
      originalMessage: message,
      processedParts: processedParts,
      processingTimestamp: DateTime.now(),
    );
  }

  /// Process a media content part through OCP + PRISM pipeline
  Future<ContentPart> _processMediaPart(MediaContentPart mediaPart) async {
    final uri = mediaPart.pointer.uri;
    final mime = mediaPart.mime;
    
    try {
      // Step 1: OCP Analysis
      final ocpResult = await _runOcpAnalysis(uri, mime);
      
      // Step 2: PRISM Reduction
      final prismSummary = await _createPrismSummary(ocpResult, mime);
      
      // Step 3: Create PRISM content part
      final prismPart = PrismContentPart(summary: prismSummary);
      
      // Step 4: Return both original media and PRISM analysis
      return _createCombinedContentPart(mediaPart, prismPart);
    } catch (e) {
      // If processing fails, return original media part with error metadata
      return _createErrorContentPart(mediaPart, e.toString());
    }
  }

  /// Run OCP analysis based on media type
  Future<OcpAnalysisResult> _runOcpAnalysis(String uri, String mime) async {
    if (mime.startsWith('image/')) {
      final result = await OcpImageService.analyzeImage(uri);
      return OcpAnalysisResult(
        mediaType: 'image',
        ocrText: result.ocrText,
        objects: result.objects.map((obj) => obj.label).toList(),
        emotions: _extractEmotionsFromImage(result),
        metadata: {
          'exif': result.exif,
          'gps': result.gps,
          'perceptualHash': result.perceptualHash,
          'analysisTimestamp': result.analysisTimestamp.toIso8601String(),
        },
      );
    } else if (mime.startsWith('video/')) {
      final result = await OcpVideoService.analyzeVideo(uri, _getDefaultKeyframePolicy());
      return OcpAnalysisResult(
        mediaType: 'video',
        ocrText: result.ocrAggregate,
        objects: result.objects.map((obj) => obj.label).toList(),
        emotions: _extractEmotionsFromVideo(result),
        metadata: {
          'duration': result.duration.inMilliseconds,
          'keyframeCount': result.keyframes.length,
          'sceneCount': result.scenes.length,
          'analysisTimestamp': result.analysisTimestamp.toIso8601String(),
        },
      );
    } else if (mime.startsWith('audio/')) {
      final result = await SttService.transcribeAudio(uri, 'whisper');
      return OcpAnalysisResult(
        mediaType: 'audio',
        ocrText: result.transcript,
        objects: [],
        emotions: _extractEmotionsFromAudio(result),
        metadata: {
          'duration': result.duration.inMilliseconds,
          'confidence': result.confidence,
          'prosody': result.prosody.toJson(),
          'sentiment': result.sentiment.toJson(),
          'analysisTimestamp': result.analysisTimestamp.toIso8601String(),
        },
      );
    } else {
      throw UnsupportedError('Unsupported media type: $mime');
    }
  }

  /// Create PRISM summary from OCP analysis
  Future<PrismSummary> _createPrismSummary(OcpAnalysisResult ocpResult, String mime) async {
    // Extract captions from OCR text
    final captions = ocpResult.ocrText.isNotEmpty ? [ocpResult.ocrText] : null;
    
    // Extract transcript for audio/video
    String? transcript;
    if (mime.startsWith('audio/') || mime.startsWith('video/')) {
      transcript = ocpResult.ocrText;
    }
    
    // Extract objects
    final objects = ocpResult.objects.isNotEmpty ? ocpResult.objects : null;
    
    // Extract emotions
    final emotion = ocpResult.emotions.isNotEmpty 
        ? EmotionData(
            valence: ocpResult.emotions['valence'] ?? 0.0,
            arousal: ocpResult.emotions['arousal'] ?? 0.5,
            dominantEmotion: _getDominantEmotion(ocpResult.emotions),
            metadata: ocpResult.emotions,
          )
        : null;
    
    // Extract symbols from text
    final symbols = _extractSymbols(ocpResult.ocrText);
    
    return PrismSummary(
      captions: captions,
      transcript: transcript,
      objects: objects,
      emotion: emotion,
      symbols: symbols.isNotEmpty ? symbols : null,
      metadata: {
        'mediaType': ocpResult.mediaType,
        'processingTimestamp': DateTime.now().toIso8601String(),
        'ocpMetadata': ocpResult.metadata,
      },
    );
  }

  /// Create combined content part with original media and PRISM analysis
  ContentPart _createCombinedContentPart(MediaContentPart mediaPart, PrismContentPart prismPart) {
    // For now, return the original media part
    // In a full implementation, we might want to create a composite part
    // or modify the media part to include PRISM data
    return mediaPart;
  }

  /// Create error content part when processing fails
  ContentPart _createErrorContentPart(MediaContentPart mediaPart, String error) {
    // Return original media part with error metadata
    final updatedMetadata = Map<String, dynamic>.from(mediaPart.pointer.metadata);
    updatedMetadata['processingError'] = error;
    updatedMetadata['processingTimestamp'] = DateTime.now().toIso8601String();
    
    final updatedPointer = MediaPointer(
      uri: mediaPart.pointer.uri,
      role: mediaPart.pointer.role,
      metadata: updatedMetadata,
    );
    
    return MediaContentPart(
      mime: mediaPart.mime,
      pointer: updatedPointer,
      alt: mediaPart.alt,
      durationMs: mediaPart.durationMs,
    );
  }

  /// Extract emotions from image analysis
  Map<String, double> _extractEmotionsFromImage(OcpImageResult result) {
    // Simple emotion extraction based on detected objects and text
    final emotions = <String, double>{
      'valence': 0.0,
      'arousal': 0.5,
    };
    
    // Analyze objects for emotional content
    for (final obj in result.objects) {
      final label = obj.label.toLowerCase();
      if (label.contains('smile') || label.contains('happy')) {
        emotions['valence'] = 0.7;
        emotions['arousal'] = 0.6;
      } else if (label.contains('sad') || label.contains('cry')) {
        emotions['valence'] = -0.5;
        emotions['arousal'] = 0.3;
      }
    }
    
    // Analyze text for emotional content
    final text = result.ocrText.toLowerCase();
    if (text.contains('happy') || text.contains('joy')) {
      emotions['valence'] = 0.8;
    } else if (text.contains('sad') || text.contains('depressed')) {
      emotions['valence'] = -0.6;
    }
    
    return emotions;
  }

  /// Extract emotions from video analysis
  Map<String, double> _extractEmotionsFromVideo(OcpVideoResult result) {
    // Aggregate emotions from all scenes
    final emotions = <String, double>{
      'valence': 0.0,
      'arousal': 0.5,
    };
    
    // Simple aggregation - in real implementation, use more sophisticated analysis
    for (final scene in result.scenes) {
      // Analyze scene content for emotional indicators
      if (scene.summary.toLowerCase().contains('action') || 
          scene.summary.toLowerCase().contains('movement')) {
        emotions['arousal'] = 0.8;
      }
    }
    
    return emotions;
  }

  /// Extract emotions from audio analysis
  Map<String, double> _extractEmotionsFromAudio(SttResult result) {
    return {
      'valence': result.sentiment.valence,
      'arousal': result.sentiment.arousal,
    };
  }

  /// Get dominant emotion from emotion data
  String? _getDominantEmotion(Map<String, double> emotions) {
    final valence = emotions['valence'] ?? 0.0;
    final arousal = emotions['arousal'] ?? 0.5;
    
    if (valence > 0.5) {
      return arousal > 0.6 ? 'excited' : 'happy';
    } else if (valence < -0.5) {
      return arousal > 0.6 ? 'angry' : 'sad';
    } else {
      return arousal > 0.6 ? 'alert' : 'calm';
    }
  }

  /// Extract symbols from text
  List<String> _extractSymbols(String text) {
    final symbolRegex = RegExp(r'[^\w\s]');
    return symbolRegex.allMatches(text)
        .map((match) => match.group(0)!)
        .toSet()
        .toList();
  }

  /// Get default keyframe policy for video analysis
  KeyframePolicy _getDefaultKeyframePolicy() {
    return KeyframePolicy(
      shortS: 5,
      mediumS: 10,
      longS: 20,
      thresholds: {
        'short': 30,
        'medium': 60,
        'long': 120,
      },
    );
  }
}

/// OCP analysis result
class OcpAnalysisResult {
  final String mediaType;
  final String ocrText;
  final List<String> objects;
  final Map<String, double> emotions;
  final Map<String, dynamic> metadata;

  OcpAnalysisResult({
    required this.mediaType,
    required this.ocrText,
    required this.objects,
    required this.emotions,
    required this.metadata,
  });
}

/// Processed chat message
class ProcessedChatMessage {
  final ChatMessage originalMessage;
  final List<ContentPart> processedParts;
  final DateTime processingTimestamp;

  ProcessedChatMessage({
    required this.originalMessage,
    required this.processedParts,
    required this.processingTimestamp,
  });
}

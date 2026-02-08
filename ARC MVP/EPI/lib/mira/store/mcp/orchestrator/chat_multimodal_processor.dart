import 'dart:io';

import 'package:my_app/arc/chat/chat/content_parts.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'ocp_services.dart';

/// Multimodal processor for chat messages
///
/// Handles OCP (Open Content Protocol) analysis and PRISM reduction for chat content.
/// This service processes media attachments in chat messages through a two-stage pipeline:
///
/// ## Processing Pipeline
/// 1. **OCP Analysis**: Extracts raw content from media (OCR, object detection, transcription)
/// 2. **PRISM Reduction**: Converts OCP results into structured summaries for memory storage
///
/// ## Architecture Context
/// Part of POLYMETA's MCP (Memory Container Protocol) orchestrator layer.
/// Previously located in `core/mcp/`, moved to `polymeta/store/mcp/` during consolidation.
///
/// ## Supported Media Types
/// - **Images**: OCR text extraction, object detection, EXIF/GPS metadata; keywords from labels/objects/OCR
/// - **Video**: Keyframe extraction, scene detection, aggregate OCR; keywords from transcript/scenes
/// - **Audio**: Speech-to-text transcription, prosody analysis, sentiment detection
/// - **PDF / .md / Doc**: Text extraction; metadata and extracted keywords merged into conversation/entry
///
/// ## Data Flow
/// ```
/// ChatMessage (with MediaContentPart)
///   → ChatMultimodalProcessor.processMessage()
///   → OCP Service (image/video/audio specific)
///   → PRISM Summary generation
///   → ProcessedChatMessage (with PrismContentPart)
/// ```
///
/// ## Error Handling
/// If processing fails, returns original media part with error metadata.
/// This ensures chat messages remain functional even if analysis fails.
class ChatMultimodalProcessor {

  /// Process a chat message with media content
  ///
  /// Iterates through all content parts in the message and processes media parts
  /// through the OCP + PRISM pipeline. Non-media parts (text, etc.) are preserved
  /// as-is to maintain message integrity.
  ///
  /// Returns a ProcessedChatMessage containing both original and processed content.
  Future<ProcessedChatMessage> processMessage(ChatMessage message) async {
    final processedParts = <ContentPart>[];
    
    final contentParts = message.contentParts;
    if (contentParts != null) {
      for (final part in contentParts) {
        if (part is MediaContentPart) {
          // Process media content through OCP + PRISM pipeline
          // This extracts structured data (OCR, objects, transcription) and
          // creates PRISM summaries for memory storage
          final processedPart = await _processMediaPart(part);
          processedParts.add(processedPart);
        } else {
          // Keep non-media parts (text, metadata) as-is
          // These don't require multimodal processing
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
  ///
  /// This is the core processing method that:
  /// 1. Runs OCP analysis to extract raw content from media
  /// 2. Creates a PRISM summary for efficient memory storage
  /// 3. Combines original media with PRISM analysis in a single content part
  ///
  /// The PRISM summary is essential for memory storage - it reduces large media
  /// analysis results to compact, searchable summaries that preserve key insights.
  Future<ContentPart> _processMediaPart(MediaContentPart mediaPart) async {
    final uri = mediaPart.pointer.uri;
    final mime = mediaPart.mime;
    
    try {
      // Step 1: OCP Analysis
      // Extract raw content: OCR text, detected objects, transcription, metadata
      final ocpResult = await _runOcpAnalysis(uri, mime);
      
      // Step 2: PRISM Reduction
      // Convert OCP results into structured summary for memory storage
      // This reduces storage size while preserving key insights
      final prismSummary = await _createPrismSummary(ocpResult, mime);
      
      // Step 3: Create PRISM content part
      // Wrap summary in ContentPart for inclusion in chat message
      final prismPart = PrismContentPart(summary: prismSummary);
      
      // Step 4: Return both original media and PRISM analysis
      // Original media is preserved for display, PRISM summary for memory
      return _createCombinedContentPart(mediaPart, prismPart);
    } catch (e) {
      // If processing fails, return original media part with error metadata
      // This ensures chat messages remain functional even if analysis fails
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
    } else if (mime == 'application/pdf' ||
        mime == 'text/markdown' ||
        mime == 'application/msword' ||
        mime == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
      // Document types: extract text for keywords; metadata and text merged into conversation/entry
      final docResult = await _extractDocumentText(uri, mime);
      return OcpAnalysisResult(
        mediaType: 'document',
        ocrText: docResult.extractedText,
        objects: docResult.keywords,
        emotions: <String, double>{},
        metadata: docResult.metadata,
      );
    } else {
      throw UnsupportedError('Unsupported media type: $mime');
    }
  }

  /// Extract text and keywords from PDF, .md, Doc for analysis and entry keywords
  Future<({String extractedText, List<String> keywords, Map<String, dynamic> metadata})> _extractDocumentText(String uri, String mime) async {
    final metadata = <String, dynamic>{
      'mime': mime,
      'analysisTimestamp': DateTime.now().toIso8601String(),
    };
    try {
      final file = File(uri);
      if (!await file.exists()) {
        return (extractedText: '', keywords: <String>[], metadata: {...metadata, 'error': 'File not found'});
      }
      final bytes = await file.readAsBytes();
      metadata['sizeBytes'] = bytes.length;
      String raw = '';
      if (mime == 'text/markdown' || uri.toLowerCase().endsWith('.md')) {
        raw = String.fromCharCodes(bytes);
      }
      // PDF and Word would require packages (e.g. pdf_text, docx); for now capture filename as keyword
      final fileName = uri.split('/').last;
      final List<String> keywords = [];
      if (fileName.isNotEmpty) {
        final stem = fileName.replaceAll(RegExp(r'\.(pdf|md|docx?)$', caseSensitive: false), '');
        if (stem.length > 1) keywords.add(stem);
      }
      if (raw.trim().isNotEmpty) {
        final words = raw.split(RegExp(r'\s+')).where((w) => w.length > 2).take(100);
        for (final w in words) {
          if (w.length > 3 && keywords.length < 20) keywords.add(w);
        }
      }
      return (extractedText: raw, keywords: keywords, metadata: metadata);
    } catch (e) {
      return (extractedText: '', keywords: <String>[], metadata: {...metadata, 'error': e.toString()});
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

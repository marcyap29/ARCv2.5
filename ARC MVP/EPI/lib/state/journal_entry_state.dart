import 'dart:convert';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';
import 'package:hive/hive.dart';

part 'journal_entry_state.g.dart';

/// Inline reflection block that appears within journal entries
@HiveType(typeId: 103)
class InlineBlock {
  @HiveField(0)
  final String type; // 'inline_reflection'
  @HiveField(1)
  final String intent; // ideas | think | perspective | next | analyze
  @HiveField(2)
  final String content;
  @HiveField(3)
  final int timestamp;
  @HiveField(4)
  final String? phase; // Discovery, Recovery, Breakthrough, Consolidation
  @HiveField(5)
  final String? userComment; // User's comment/continuation text after the reflection
  // AttributionTrace stored as JSON string since it's complex
  @HiveField(6)
  final String? attributionTracesJson;

  InlineBlock({
    required this.type,
    required this.intent,
    required this.content,
    required this.timestamp,
    this.phase,
    this.userComment,
    List<AttributionTrace>? attributionTraces,
    this.attributionTracesJson,
  }) : _attributionTraces = attributionTraces;

  // Store attributionTraces separately (not in Hive)
  final List<AttributionTrace>? _attributionTraces;
  
  // Getter for attributionTraces
  List<AttributionTrace>? get attributionTraces {
    if (_attributionTraces != null) return _attributionTraces;
    if (attributionTracesJson == null) return null;
    try {
      final decoded = jsonDecode(attributionTracesJson!);
      if (decoded is List) {
        return decoded
            .map((t) => AttributionTrace.fromJson(t as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'intent': intent,
    'content': content,
    'timestamp': timestamp,
    'phase': phase,
    'userComment': userComment,
    'attributionTraces': attributionTraces?.map((t) => t.toJson()).toList(),
  };
  
  // Helper to create InlineBlock with attributionTraces for JSON serialization
  InlineBlock withAttributionTraces(List<AttributionTrace>? traces) {
    return InlineBlock(
      type: type,
      intent: intent,
      content: content,
      timestamp: timestamp,
      phase: phase,
      userComment: userComment,
      attributionTraces: traces,
      attributionTracesJson: traces != null ? jsonEncode(traces.map((t) => t.toJson()).toList()) : null,
    );
  }

  factory InlineBlock.fromJson(Map<String, dynamic> json) {
    List<AttributionTrace>? traces;
    if (json['attributionTraces'] != null && json['attributionTraces'] is List) {
      try {
        traces = (json['attributionTraces'] as List)
            .map((t) => t is Map<String, dynamic> ? AttributionTrace.fromJson(t) : null)
            .whereType<AttributionTrace>()
            .toList();
        if (traces.isEmpty) traces = null;
      } catch (_) {
        traces = null;
      }
    }
    // Legacy entries may have missing or wrong-typed fields; use safe defaults so entries are not skipped.
    final type = json['type'] is String ? json['type'] as String : 'inline_reflection';
    final intent = json['intent'] is String ? json['intent'] as String : 'ideas';
    final content = json['content'] is String ? json['content'] as String : '';
    final rawTimestamp = json['timestamp'];
    final timestamp = rawTimestamp is int
        ? rawTimestamp
        : (rawTimestamp is num ? rawTimestamp.toInt() : 0);
    return InlineBlock(
      type: type,
      intent: intent,
      content: content,
      timestamp: timestamp,
      phase: json['phase'] as String?,
      userComment: json['userComment'] as String?,
      attributionTraces: traces,
      attributionTracesJson: traces != null ? jsonEncode(traces.map((t) => t.toJson()).toList()) : null,
    );
  }

  /// Create a copy with updated fields
  InlineBlock copyWith({
    String? type,
    String? intent,
    String? content,
    int? timestamp,
    String? phase,
    String? userComment,
    List<AttributionTrace>? attributionTraces,
    String? attributionTracesJson,
  }) {
    final traces = attributionTraces ?? this.attributionTraces;
    return InlineBlock(
      type: type ?? this.type,
      intent: intent ?? this.intent,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      phase: phase ?? this.phase,
      userComment: userComment ?? this.userComment,
      attributionTraces: traces,
      attributionTracesJson: attributionTracesJson ?? 
          (traces != null ? jsonEncode(traces.map((t) => t.toJson()).toList()) : this.attributionTracesJson),
    );
  }
}

/// State management for journal entries with inline LUMARA integration
class JournalEntryState {
  String text = '';
  String? phase; // Discovery, Recovery, Breakthrough, Consolidation
  final List<InlineBlock> blocks = [];
  final List<dynamic> attachments = []; // Can contain ScanAttachment, PhotoAttachment, VideoAttachment, or FileAttachment

  /// Whether to show LUMARA nudge animation
  bool get showLumaraNudge => text.trim().length >= 30;

  /// Add a new inline reflection block
  void addReflection(InlineBlock block) {
    blocks.add(block);
  }

  /// Remove a reflection block
  void removeReflection(int index) {
    if (index >= 0 && index < blocks.length) {
      blocks.removeAt(index);
    }
  }

  /// Add a scan attachment
  void addAttachment(ScanAttachment attachment) {
    attachments.add(attachment);
  }

  /// Add a video attachment
  void addVideoAttachment(VideoAttachment attachment) {
    attachments.add(attachment);
  }

  /// Add a file attachment (PDF, .md, Doc, etc.)
  void addFileAttachment(FileAttachment attachment) {
    attachments.add(attachment);
  }

  /// Get all content including text and blocks for analysis
  String get fullContent {
    final buffer = StringBuffer(text);
    for (final block in blocks) {
      buffer.write('\n\n[LUMARA: ${block.content}]');
    }
    return buffer.toString();
  }

  /// Clear all content
  void clear() {
    text = '';
    blocks.clear();
    attachments.clear();
  }
}

/// Scan attachment for OCR text
class ScanAttachment {
  final String type; // 'ocr_text'
  final String text;
  final String sourceImageId;
  final String? thumbnailPath;

  ScanAttachment({
    required this.type,
    required this.text,
    required this.sourceImageId,
    this.thumbnailPath,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'text': text,
    'sourceImageId': sourceImageId,
    'thumbnailPath': thumbnailPath,
  };

  factory ScanAttachment.fromJson(Map<String, dynamic> json) => ScanAttachment(
    type: json['type'] as String,
    text: json['text'] as String,
    sourceImageId: json['sourceImageId'] as String,
    thumbnailPath: json['thumbnailPath'] as String?,
  );
}

/// Photo attachment with analysis results
class PhotoAttachment {
  final String type; // 'photo_analysis'
  final String imagePath;
  final Map<String, dynamic> analysisResult;
  final int timestamp;
  final String? altText; // Descriptive text for accessibility and fallback (like HTML alt attribute)
  final int? insertionPosition; // Character position in text where photo was added (for inline display)
  final String? photoId; // Unique ID for text placeholder reference
  final String? sha256; // SHA-256 hash for content-addressed linking

  PhotoAttachment({
    required this.type,
    required this.imagePath,
    required this.analysisResult,
    required this.timestamp,
    this.altText,
    this.insertionPosition,
    this.photoId,
    this.sha256,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'imagePath': imagePath,
    'analysisResult': analysisResult,
    'timestamp': timestamp,
    'altText': altText,
    'insertionPosition': insertionPosition,
    'photoId': photoId,
    'sha256': sha256,
  };

  factory PhotoAttachment.fromJson(Map<String, dynamic> json) => PhotoAttachment(
    type: json['type'] as String,
    imagePath: json['imagePath'] as String,
    analysisResult: json['analysisResult'] as Map<String, dynamic>,
    timestamp: json['timestamp'] as int,
    altText: json['altText'] as String?,
    insertionPosition: json['insertionPosition'] as int?,
    photoId: json['photoId'] as String?,
    sha256: json['sha256'] as String?,
  );

  /// Create a copy with updated fields
  PhotoAttachment copyWith({
    String? type,
    String? imagePath,
    Map<String, dynamic>? analysisResult,
    int? timestamp,
    String? altText,
    int? insertionPosition,
    String? photoId,
    String? sha256,
  }) {
    return PhotoAttachment(
      type: type ?? this.type,
      imagePath: imagePath ?? this.imagePath,
      analysisResult: analysisResult ?? this.analysisResult,
      timestamp: timestamp ?? this.timestamp,
      altText: altText ?? this.altText,
      insertionPosition: insertionPosition ?? this.insertionPosition,
      photoId: photoId ?? this.photoId,
      sha256: sha256 ?? this.sha256,
    );
  }
}

/// Video attachment for video files
class VideoAttachment {
  final String type; // 'video'
  final String videoPath;
  final int timestamp;
  final String? altText; // Descriptive text for accessibility
  final int? insertionPosition; // Character position in text where video was added
  final String? videoId; // Unique ID for text placeholder reference
  final String? sha256; // SHA-256 hash for content-addressed linking
  final Duration? duration; // Video duration if available
  final int? sizeBytes; // File size in bytes if available
  final String? thumbnailPath; // Path to thumbnail image if available

  VideoAttachment({
    required this.type,
    required this.videoPath,
    required this.timestamp,
    this.altText,
    this.insertionPosition,
    this.videoId,
    this.sha256,
    this.duration,
    this.sizeBytes,
    this.thumbnailPath,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'videoPath': videoPath,
    'timestamp': timestamp,
    'altText': altText,
    'insertionPosition': insertionPosition,
    'videoId': videoId,
    'sha256': sha256,
    'duration': duration?.inSeconds,
    'sizeBytes': sizeBytes,
    'thumbnailPath': thumbnailPath,
  };

  factory VideoAttachment.fromJson(Map<String, dynamic> json) => VideoAttachment(
    type: json['type'] as String,
    videoPath: json['videoPath'] as String,
    timestamp: json['timestamp'] as int,
    altText: json['altText'] as String?,
    insertionPosition: json['insertionPosition'] as int?,
    videoId: json['videoId'] as String?,
    sha256: json['sha256'] as String?,
    duration: json['duration'] != null ? Duration(seconds: json['duration'] as int) : null,
    sizeBytes: json['sizeBytes'] as int?,
    thumbnailPath: json['thumbnailPath'] as String?,
  );

  /// Create a copy with updated fields
  VideoAttachment copyWith({
    String? type,
    String? videoPath,
    int? timestamp,
    String? altText,
    int? insertionPosition,
    String? videoId,
    String? sha256,
    Duration? duration,
    int? sizeBytes,
    String? thumbnailPath,
  }) {
    return VideoAttachment(
      type: type ?? this.type,
      videoPath: videoPath ?? this.videoPath,
      timestamp: timestamp ?? this.timestamp,
      altText: altText ?? this.altText,
      insertionPosition: insertionPosition ?? this.insertionPosition,
      videoId: videoId ?? this.videoId,
      sha256: sha256 ?? this.sha256,
      duration: duration ?? this.duration,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}

/// File attachment for PDF, Markdown, Word documents
class FileAttachment {
  final String type; // 'file'
  final String filePath;
  final String fileName;
  final String mimeType; // e.g. application/pdf, text/markdown
  final int timestamp;
  final String? fileId;
  final String? extractedText; // For keyword extraction (OCR/text extraction)

  FileAttachment({
    required this.type,
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    required this.timestamp,
    this.fileId,
    this.extractedText,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'filePath': filePath,
    'fileName': fileName,
    'mimeType': mimeType,
    'timestamp': timestamp,
    'fileId': fileId,
    'extractedText': extractedText,
  };

  factory FileAttachment.fromJson(Map<String, dynamic> json) => FileAttachment(
    type: json['type'] as String,
    filePath: json['filePath'] as String,
    fileName: json['fileName'] as String,
    mimeType: json['mimeType'] as String,
    timestamp: json['timestamp'] as int,
    fileId: json['fileId'] as String?,
    extractedText: json['extractedText'] as String?,
  );

  FileAttachment copyWith({
    String? type,
    String? filePath,
    String? fileName,
    String? mimeType,
    int? timestamp,
    String? fileId,
    String? extractedText,
  }) {
    return FileAttachment(
      type: type ?? this.type,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      timestamp: timestamp ?? this.timestamp,
      fileId: fileId ?? this.fileId,
      extractedText: extractedText ?? this.extractedText,
    );
  }
}

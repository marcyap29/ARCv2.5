/// Inline reflection block that appears within journal entries
class InlineBlock {
  final String type; // 'inline_reflection'
  final String intent; // ideas | think | perspective | next | analyze
  final String content;
  final int timestamp;
  final String? phase; // Discovery, Recovery, Breakthrough, Consolidation

  InlineBlock({
    required this.type,
    required this.intent,
    required this.content,
    required this.timestamp,
    this.phase,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'intent': intent,
    'content': content,
    'timestamp': timestamp,
    'phase': phase,
  };

  factory InlineBlock.fromJson(Map<String, dynamic> json) => InlineBlock(
    type: json['type'] as String,
    intent: json['intent'] as String,
    content: json['content'] as String,
    timestamp: json['timestamp'] as int,
    phase: json['phase'] as String?,
  );
}

/// State management for journal entries with inline LUMARA integration
class JournalEntryState {
  String text = '';
  String? phase; // Discovery, Recovery, Breakthrough, Consolidation
  final List<InlineBlock> blocks = [];
  final List<dynamic> attachments = []; // Can contain ScanAttachment or PhotoAttachment

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

  PhotoAttachment({
    required this.type,
    required this.imagePath,
    required this.analysisResult,
    required this.timestamp,
    this.altText,
    this.insertionPosition,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'imagePath': imagePath,
    'analysisResult': analysisResult,
    'timestamp': timestamp,
    'altText': altText,
    'insertionPosition': insertionPosition,
  };

  factory PhotoAttachment.fromJson(Map<String, dynamic> json) => PhotoAttachment(
    type: json['type'] as String,
    imagePath: json['imagePath'] as String,
    analysisResult: json['analysisResult'] as Map<String, dynamic>,
    timestamp: json['timestamp'] as int,
    altText: json['altText'] as String?,
    insertionPosition: json['insertionPosition'] as int?,
  );

  /// Create a copy with updated fields
  PhotoAttachment copyWith({
    String? type,
    String? imagePath,
    Map<String, dynamic>? analysisResult,
    int? timestamp,
    String? altText,
    int? insertionPosition,
  }) {
    return PhotoAttachment(
      type: type ?? this.type,
      imagePath: imagePath ?? this.imagePath,
      analysisResult: analysisResult ?? this.analysisResult,
      timestamp: timestamp ?? this.timestamp,
      altText: altText ?? this.altText,
      insertionPosition: insertionPosition ?? this.insertionPosition,
    );
  }
}

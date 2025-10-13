/// Service for generating descriptive alt text from vision analysis
///
/// Creates HTML-like alt text descriptions for images based on iOS Vision
/// analysis data. Provides graceful fallback when original photos are deleted.
///
/// Example output: "Photo showing outdoor scene with 2 people, building, and sky.
/// Text detected: 'Welcome Home'. Captured on January 15, 2025"
class MediaAltTextGenerator {
  /// Generate descriptive alt text from vision analysis data
  ///
  /// Creates a natural language description including:
  /// - Scene labels (outdoor, building, etc.)
  /// - Detected objects (person, car, etc.)
  /// - Face count
  /// - OCR text
  /// - Timestamp
  ///
  /// Returns null if insufficient data to generate description
  static String? generateFromAnalysis(Map<String, dynamic>? analysisData) {
    if (analysisData == null || analysisData.isEmpty) {
      return null;
    }

    final buffer = StringBuffer();
    final components = <String>[];

    // Extract analysis components
    final labels = analysisData['labels'] as List? ?? [];
    final objects = analysisData['objects'] as List? ?? [];
    final faces = analysisData['faces'] as List? ?? [];
    final ocrData = analysisData['ocr'] as Map? ?? {};
    final ocrText = ocrData['fullText'] as String? ?? '';

    // Start with basic description
    buffer.write('Photo');

    // Add scene context from labels (top 3)
    if (labels.isNotEmpty) {
      final sceneLabels = labels
          .take(3)
          .map((label) => _extractLabel(label))
          .where((label) => label.isNotEmpty)
          .toList();

      if (sceneLabels.isNotEmpty) {
        components.add('showing ${sceneLabels.join(', ')} scene');
      }
    }

    // Add face count
    if (faces.isNotEmpty) {
      final faceCount = faces.length;
      components.add(
        faceCount == 1 ? 'with 1 person' : 'with $faceCount people',
      );
    }

    // Add top objects (excluding duplicates with labels)
    if (objects.isNotEmpty) {
      final objectLabels = objects
          .take(5)
          .map((obj) => _extractLabel(obj))
          .where((label) => label.isNotEmpty)
          .toList();

      if (objectLabels.isNotEmpty) {
        if (components.isEmpty) {
          components.add('showing ${objectLabels.join(', ')}');
        } else {
          components.add(objectLabels.join(', '));
        }
      }
    }

    // Join main components
    if (components.isNotEmpty) {
      buffer.write(' ${components.join(', ')}');
    }

    // Add OCR text if significant
    if (ocrText.isNotEmpty && ocrText.length <= 100) {
      // Limit to reasonable length
      final cleanedText = ocrText.trim().replaceAll('\n', ' ');
      buffer.write('. Text detected: "$cleanedText"');
    } else if (ocrText.length > 100) {
      buffer.write('. Contains text content');
    }

    // End with period
    final description = buffer.toString();
    if (!description.endsWith('.') && !description.endsWith('"')) {
      buffer.write('.');
    }

    return buffer.toString();
  }

  /// Generate concise alt text for UI display
  ///
  /// Shorter version suitable for inline display in journal entries
  static String? generateConcise(Map<String, dynamic>? analysisData) {
    if (analysisData == null || analysisData.isEmpty) {
      return 'Photo (no longer available)';
    }

    final labels = analysisData['labels'] as List? ?? [];
    final objects = analysisData['objects'] as List? ?? [];
    final faces = analysisData['faces'] as List? ?? [];

    final keywords = <String>[];

    // Collect top keywords
    if (labels.isNotEmpty) {
      keywords.addAll(
        labels.take(2).map((label) => _extractLabel(label)),
      );
    }

    if (faces.isNotEmpty) {
      keywords.add(faces.length == 1 ? '1 person' : '${faces.length} people');
    }

    if (objects.isNotEmpty && keywords.length < 4) {
      keywords.addAll(
        objects
            .take(4 - keywords.length)
            .map((obj) => _extractLabel(obj))
            .where((label) => label.isNotEmpty),
      );
    }

    if (keywords.isEmpty) {
      return 'Photo';
    }

    return 'Photo: ${keywords.join(', ')}';
  }

  /// Generate alt text suitable for export (MCP bundles, backups)
  ///
  /// Comprehensive description including metadata for data portability
  static String? generateForExport(
    Map<String, dynamic>? analysisData, {
    String? originalFilename,
    DateTime? capturedAt,
  }) {
    final baseDescription = generateFromAnalysis(analysisData);
    if (baseDescription == null) {
      return originalFilename != null
          ? 'Photo: $originalFilename'
          : 'Photo attachment';
    }

    final buffer = StringBuffer(baseDescription);

    // Add metadata
    if (originalFilename != null) {
      buffer.write(' Original filename: $originalFilename.');
    }

    if (capturedAt != null) {
      final dateStr = _formatDate(capturedAt);
      buffer.write(' Captured: $dateStr.');
    }

    return buffer.toString();
  }

  /// Extract label text from vision analysis object
  static String _extractLabel(dynamic labelData) {
    if (labelData is String) return labelData;
    if (labelData is Map) {
      return labelData['label']?.toString() ?? '';
    }
    return '';
  }

  /// Format date for human readability
  static String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Generate fallback text when photo file is missing
  static String generateMissingPhotoText(String? altText) {
    if (altText != null && altText.isNotEmpty) {
      return altText;
    }
    return 'Photo no longer available';
  }
}

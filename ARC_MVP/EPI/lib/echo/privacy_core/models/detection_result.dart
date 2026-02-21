// Detection Result Models
// Defines the result structures for PII detection

import 'pii_types.dart';

/// Result of PII detection operation
class PIIDetectionResult {
  final List<PIIItem> detectedItems;
  final double overallConfidence;
  final Duration processingTime;
  final Map<PIIType, int> typeCounts;
  final bool hasHighConfidenceItems;

  const PIIDetectionResult({
    required this.detectedItems,
    required this.overallConfidence,
    required this.processingTime,
    required this.typeCounts,
    required this.hasHighConfidenceItems,
  });

  /// Returns true if any PII was detected
  bool get hasPII => detectedItems.isNotEmpty;

  /// Returns the count of detected PII items
  int get itemCount => detectedItems.length;

  /// Returns PII items of a specific type
  List<PIIItem> getItemsByType(PIIType type) {
    return detectedItems.where((item) => item.type == type).toList();
  }

  /// Returns high confidence PII items (confidence > 0.8)
  List<PIIItem> get highConfidenceItems {
    return detectedItems.where((item) => item.confidence > 0.8).toList();
  }

  @override
  String toString() => 'PIIDetectionResult(items: $itemCount, confidence: $overallConfidence)';
}

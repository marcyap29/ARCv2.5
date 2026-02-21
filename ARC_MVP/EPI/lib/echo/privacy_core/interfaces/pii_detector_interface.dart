// PII Detector Interface
// Defines the contract for PII detection services across all EPI modules

import '../models/pii_types.dart';
import '../models/detection_result.dart';

/// Interface for PII detection services
abstract class PIIDetector {
  /// Detects PII in the given text
  /// 
  /// [text] - The text to analyze for PII
  /// Returns a [PIIDetectionResult] containing detected PII items
  PIIDetectionResult detectPII(String text);
  
  /// Detects PII with custom sensitivity level
  /// 
  /// [text] - The text to analyze for PII
  /// [sensitivity] - The sensitivity level for detection
  /// Returns a [PIIDetectionResult] containing detected PII items
  PIIDetectionResult detectPIIWithSensitivity(String text, PIISensitivity sensitivity);
  
  /// Checks if the detector supports a specific PII type
  /// 
  /// [type] - The PII type to check
  /// Returns true if the detector supports this PII type
  bool supportsPIIType(PIIType type);
}

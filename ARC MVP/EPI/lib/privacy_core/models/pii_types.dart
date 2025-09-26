// PII Types and Models
// Defines the core PII types and data structures for the privacy system

/// Enumeration of PII types that can be detected and masked
enum PIIType {
  name,
  email,
  phone,
  address,
  ssn,
  creditCard,
  dateOfBirth,
  ipAddress,
  macAddress,
  licensePlate,
  passport,
  driverLicense,
  bankAccount,
  routingNumber,
  medicalRecord,
  healthInsurance,
  biometric,
  other
}

/// Sensitivity levels for PII detection
enum PIISensitivity {
  strict,
  normal,
  relaxed
}

/// Represents a detected PII item
class PIIItem {
  final PIIType type;
  final String value;
  final int startIndex;
  final int endIndex;
  final double confidence;
  final String? context;

  const PIIItem({
    required this.type,
    required this.value,
    required this.startIndex,
    required this.endIndex,
    required this.confidence,
    this.context,
  });

  @override
  String toString() => 'PIIItem(type: $type, value: $value, confidence: $confidence)';
}

/// Masking options for PII processing
class MaskingOptions {
  final bool preserveStructure;
  final bool useConsistentMapping;
  final bool enableHashing;
  final String? customPrefix;
  final String? customSuffix;

  const MaskingOptions({
    this.preserveStructure = true,
    this.useConsistentMapping = true,
    this.enableHashing = false,
    this.customPrefix,
    this.customSuffix,
  });
}

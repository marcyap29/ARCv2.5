// Shared privacy presets and user settings (no LUMARA / PII scrub imports — avoids cycles).

import 'package:my_app/echo/privacy_core/models/pii_types.dart' hide MaskingOptions;
import 'package:my_app/echo/privacy_core/pii_detection_service.dart';
import 'package:my_app/echo/privacy_core/pii_masking_service.dart';

enum PrivacyLevel {
  /// Maximum privacy: Strict detection, full masking, no data retention
  maximum('Maximum Privacy', 'Strict detection, full masking, blocks all PII'),

  /// Balanced privacy: Normal detection, smart masking, utility preserved
  balanced('Balanced Privacy', 'Smart detection, preserves readability and utility'),

  /// Minimal privacy: Relaxed detection, structure preservation, performance focused
  minimal('Minimal Privacy', 'Basic protection, optimized for speed and utility'),

  /// Custom: User-defined settings
  custom('Custom Settings', 'Configure individual privacy preferences');

  const PrivacyLevel(this.displayName, this.description);

  final String displayName;
  final String description;
}

class PrivacySettings {
  // Detection settings
  final SensitivityLevel detectionSensitivity;
  final Set<PIIType> enabledPIITypes;

  // Masking settings
  final bool preserveStructure;
  final bool consistentMapping;
  final bool hashEmails;
  final bool reversibleMasking;

  // Guardrail settings
  final bool enableInterceptor;
  final bool blockOnViolation;
  final bool auditLogging;

  // Performance settings
  final bool enableRealTimeScanning;
  final int maxProcessingTime; // milliseconds

  const PrivacySettings({
    this.detectionSensitivity = SensitivityLevel.normal,
    this.enabledPIITypes = const {
      PIIType.name,
      PIIType.email,
      PIIType.phone,
      PIIType.address,
      PIIType.ssn,
      PIIType.creditCard,
    },
    this.preserveStructure = true,
    this.consistentMapping = true,
    this.hashEmails = true,
    this.reversibleMasking = false,
    this.enableInterceptor = true,
    this.blockOnViolation = true,
    this.auditLogging = true,
    this.enableRealTimeScanning = true,
    this.maxProcessingTime = 1000,
  });

  /// Factory for preset privacy levels
  factory PrivacySettings.fromLevel(PrivacyLevel level) {
    switch (level) {
      case PrivacyLevel.maximum:
        return const PrivacySettings(
          detectionSensitivity: SensitivityLevel.strict,
          enabledPIITypes: {
            PIIType.name,
            PIIType.email,
            PIIType.phone,
            PIIType.address,
            PIIType.ssn,
            PIIType.creditCard,
            PIIType.ipAddress,
            PIIType.url,
            PIIType.dateOfBirth,
            PIIType.other,
          },
          preserveStructure: false,
          consistentMapping: true,
          hashEmails: true,
          reversibleMasking: false,
          enableInterceptor: true,
          blockOnViolation: true,
          auditLogging: true,
          enableRealTimeScanning: true,
          maxProcessingTime: 2000,
        );

      case PrivacyLevel.balanced:
        return const PrivacySettings(
          detectionSensitivity: SensitivityLevel.normal,
          enabledPIITypes: {
            PIIType.name,
            PIIType.email,
            PIIType.phone,
            PIIType.address,
            PIIType.ssn,
            PIIType.creditCard,
          },
          preserveStructure: true,
          consistentMapping: true,
          hashEmails: true,
          reversibleMasking: false,
          enableInterceptor: true,
          blockOnViolation: true,
          auditLogging: true,
          enableRealTimeScanning: true,
          maxProcessingTime: 1000,
        );

      case PrivacyLevel.minimal:
        return const PrivacySettings(
          detectionSensitivity: SensitivityLevel.relaxed,
          enabledPIITypes: {
            PIIType.ssn,
            PIIType.creditCard,
            PIIType.email,
          },
          preserveStructure: true,
          consistentMapping: false,
          hashEmails: false,
          reversibleMasking: true,
          enableInterceptor: false,
          blockOnViolation: false,
          auditLogging: false,
          enableRealTimeScanning: false,
          maxProcessingTime: 500,
        );

      case PrivacyLevel.custom:
        return const PrivacySettings(); // Default settings for customization
    }
  }

  PrivacySettings copyWith({
    SensitivityLevel? detectionSensitivity,
    Set<PIIType>? enabledPIITypes,
    bool? preserveStructure,
    bool? consistentMapping,
    bool? hashEmails,
    bool? reversibleMasking,
    bool? enableInterceptor,
    bool? blockOnViolation,
    bool? auditLogging,
    bool? enableRealTimeScanning,
    int? maxProcessingTime,
  }) {
    return PrivacySettings(
      detectionSensitivity: detectionSensitivity ?? this.detectionSensitivity,
      enabledPIITypes: enabledPIITypes ?? this.enabledPIITypes,
      preserveStructure: preserveStructure ?? this.preserveStructure,
      consistentMapping: consistentMapping ?? this.consistentMapping,
      hashEmails: hashEmails ?? this.hashEmails,
      reversibleMasking: reversibleMasking ?? this.reversibleMasking,
      enableInterceptor: enableInterceptor ?? this.enableInterceptor,
      blockOnViolation: blockOnViolation ?? this.blockOnViolation,
      auditLogging: auditLogging ?? this.auditLogging,
      enableRealTimeScanning: enableRealTimeScanning ?? this.enableRealTimeScanning,
      maxProcessingTime: maxProcessingTime ?? this.maxProcessingTime,
    );
  }

  /// Base masking options from settings (LUMARA rivet path may override fields).
  MaskingOptions toMaskingOptions() {
    return MaskingOptions(
      preserveStructure: preserveStructure,
      consistentMapping: consistentMapping,
      reversibleMasking: reversibleMasking,
      hashEmails: hashEmails,
    );
  }

  Map<String, dynamic> toJson() => {
        'detectionSensitivity': detectionSensitivity.index,
        'enabledPIITypes': enabledPIITypes.map((e) => e.index).toList(),
        'preserveStructure': preserveStructure,
        'consistentMapping': consistentMapping,
        'hashEmails': hashEmails,
        'reversibleMasking': reversibleMasking,
        'enableInterceptor': enableInterceptor,
        'blockOnViolation': blockOnViolation,
        'auditLogging': auditLogging,
        'enableRealTimeScanning': enableRealTimeScanning,
        'maxProcessingTime': maxProcessingTime,
      };

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    final sensIdx = json['detectionSensitivity'] as int? ?? 1;
    final sensitivity = sensIdx >= 0 && sensIdx < SensitivityLevel.values.length
        ? SensitivityLevel.values[sensIdx]
        : SensitivityLevel.normal;

    Set<PIIType> types = {
      PIIType.name,
      PIIType.email,
      PIIType.phone,
    };
    final rawList = json['enabledPIITypes'] as List?;
    if (rawList != null && rawList.isNotEmpty) {
      types = rawList
          .map((i) {
            final idx = i is int ? i : int.tryParse('$i') ?? -1;
            if (idx >= 0 && idx < PIIType.values.length) {
              return PIIType.values[idx];
            }
            return null;
          })
          .whereType<PIIType>()
          .toSet();
      if (types.isEmpty) {
        types = {
          PIIType.name,
          PIIType.email,
          PIIType.phone,
        };
      }
    }

    return PrivacySettings(
      detectionSensitivity: sensitivity,
      enabledPIITypes: types,
      preserveStructure: json['preserveStructure'] as bool? ?? true,
      consistentMapping: json['consistentMapping'] as bool? ?? true,
      hashEmails: json['hashEmails'] as bool? ?? true,
      reversibleMasking: json['reversibleMasking'] as bool? ?? false,
      enableInterceptor: json['enableInterceptor'] as bool? ?? true,
      blockOnViolation: json['blockOnViolation'] as bool? ?? true,
      auditLogging: json['auditLogging'] as bool? ?? true,
      enableRealTimeScanning: json['enableRealTimeScanning'] as bool? ?? true,
      maxProcessingTime: json['maxProcessingTime'] as int? ?? 1000,
    );
  }
}

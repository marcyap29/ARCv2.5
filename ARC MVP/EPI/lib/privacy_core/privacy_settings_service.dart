// lib/services/privacy/privacy_settings_service.dart
// Privacy Settings Service for user-configurable PII protection

import 'package:shared_preferences/shared_preferences.dart';
import 'pii_detection_service.dart';
import 'pii_masking_service.dart';

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

  /// Convert to masking options
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
    return PrivacySettings(
      detectionSensitivity: SensitivityLevel.values[json['detectionSensitivity'] ?? 1],
      enabledPIITypes: (json['enabledPIITypes'] as List?)
          ?.map((i) => PIIType.values[i])
          .toSet() ?? const {PIIType.name, PIIType.email, PIIType.phone},
      preserveStructure: json['preserveStructure'] ?? true,
      consistentMapping: json['consistentMapping'] ?? true,
      hashEmails: json['hashEmails'] ?? true,
      reversibleMasking: json['reversibleMasking'] ?? false,
      enableInterceptor: json['enableInterceptor'] ?? true,
      blockOnViolation: json['blockOnViolation'] ?? true,
      auditLogging: json['auditLogging'] ?? true,
      enableRealTimeScanning: json['enableRealTimeScanning'] ?? true,
      maxProcessingTime: json['maxProcessingTime'] ?? 1000,
    );
  }
}

/// Service for managing privacy settings
class PrivacySettingsService {
  static const String _keyPrivacyLevel = 'privacy_level';
  static const String _keyPrivacySettings = 'privacy_settings';
  static const String _keyFirstTimeSetup = 'privacy_first_time_setup';

  PrivacyLevel _currentLevel = PrivacyLevel.balanced;
  PrivacySettings _currentSettings = PrivacySettings.fromLevel(PrivacyLevel.balanced);
  bool _isFirstTimeSetup = true;

  PrivacyLevel get currentLevel => _currentLevel;
  PrivacySettings get currentSettings => _currentSettings;
  bool get isFirstTimeSetup => _isFirstTimeSetup;

  /// Initialize privacy settings from storage
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // Load privacy level
    final levelIndex = prefs.getInt(_keyPrivacyLevel);
    if (levelIndex != null && levelIndex < PrivacyLevel.values.length) {
      _currentLevel = PrivacyLevel.values[levelIndex];
    }

    // Load custom settings
    final settingsJson = prefs.getString(_keyPrivacySettings);
    if (settingsJson != null) {
      try {
        final Map<String, dynamic> json = Map<String, dynamic>.from(
          // In a real app, you'd use proper JSON parsing
          {}
        );
        _currentSettings = PrivacySettings.fromJson(json);
      } catch (e) {
        print('Error loading privacy settings: $e');
        // Fall back to level-based settings
        _currentSettings = PrivacySettings.fromLevel(_currentLevel);
      }
    } else {
      _currentSettings = PrivacySettings.fromLevel(_currentLevel);
    }

    // Check if first time setup
    _isFirstTimeSetup = !(prefs.getBool(_keyFirstTimeSetup) ?? false);
  }

  /// Set privacy level and update settings
  Future<void> setPrivacyLevel(PrivacyLevel level) async {
    _currentLevel = level;

    if (level != PrivacyLevel.custom) {
      _currentSettings = PrivacySettings.fromLevel(level);
    }

    await _saveSettings();
  }

  /// Update custom privacy settings
  Future<void> updateSettings(PrivacySettings settings) async {
    _currentSettings = settings;
    _currentLevel = PrivacyLevel.custom;
    await _saveSettings();
  }

  /// Complete first-time setup
  Future<void> completeFirstTimeSetup() async {
    _isFirstTimeSetup = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstTimeSetup, true);
  }

  /// Save settings to storage
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPrivacyLevel, _currentLevel.index);

    // In a real implementation, you'd properly serialize the settings
    // For now, we'll just save the level
    await prefs.setString(_keyPrivacySettings, '{}');
  }

  /// Get privacy impact description
  String getPrivacyImpactDescription() {
    switch (_currentLevel) {
      case PrivacyLevel.maximum:
        return 'All personal information is thoroughly protected. Some text readability may be reduced.';
      case PrivacyLevel.balanced:
        return 'Good privacy protection while maintaining text readability and utility.';
      case PrivacyLevel.minimal:
        return 'Basic privacy protection focused on sensitive data like SSNs and credit cards.';
      case PrivacyLevel.custom:
        return 'Custom privacy settings based on your specific preferences.';
    }
  }

  /// Get expected performance impact
  String getPerformanceImpact() {
    final processingTime = _currentSettings.maxProcessingTime;
    final realTimeEnabled = _currentSettings.enableRealTimeScanning;

    if (!realTimeEnabled) return 'Minimal impact - protection on-demand only';
    if (processingTime < 500) return 'Low impact - optimized for speed';
    if (processingTime < 1000) return 'Moderate impact - balanced processing';
    return 'Higher impact - thorough protection';
  }

  /// Reset to default settings
  Future<void> resetToDefaults() async {
    await setPrivacyLevel(PrivacyLevel.balanced);
  }
}
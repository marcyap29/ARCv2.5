import 'dart:typed_data';
import 'package:json_annotation/json_annotation.dart';
import '../pointer/pointer_models.dart';

part 'privacy_controls.g.dart';

/// Privacy settings for media analysis and storage
@JsonSerializable()
class PrivacySettings {
  @JsonKey(name: 'detect_faces')
  final bool detectFaces;
  
  @JsonKey(name: 'store_face_boxes')
  final bool storeFaceBoxes;
  
  @JsonKey(name: 'location_precision')
  final LocationPrecision locationPrecision;
  
  @JsonKey(name: 'redact_exif')
  final bool redactExif;
  
  @JsonKey(name: 'enable_pii_detection')
  final bool enablePiiDetection;
  
  @JsonKey(name: 'auto_blur_faces')
  final bool autoBlurFaces;

  const PrivacySettings({
    this.detectFaces = true,
    this.storeFaceBoxes = false,
    this.locationPrecision = LocationPrecision.city,
    this.redactExif = true,
    this.enablePiiDetection = true,
    this.autoBlurFaces = false,
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) => _$PrivacySettingsFromJson(json);
  Map<String, dynamic> toJson() => _$PrivacySettingsToJson(this);

  PrivacySettings copyWith({
    bool? detectFaces,
    bool? storeFaceBoxes,
    LocationPrecision? locationPrecision,
    bool? redactExif,
    bool? enablePiiDetection,
    bool? autoBlurFaces,
  }) {
    return PrivacySettings(
      detectFaces: detectFaces ?? this.detectFaces,
      storeFaceBoxes: storeFaceBoxes ?? this.storeFaceBoxes,
      locationPrecision: locationPrecision ?? this.locationPrecision,
      redactExif: redactExif ?? this.redactExif,
      enablePiiDetection: enablePiiDetection ?? this.enablePiiDetection,
      autoBlurFaces: autoBlurFaces ?? this.autoBlurFaces,
    );
  }

  static const PrivacySettings privacyFocused = PrivacySettings(
    detectFaces: false,
    storeFaceBoxes: false,
    locationPrecision: LocationPrecision.none,
    redactExif: true,
    enablePiiDetection: true,
    autoBlurFaces: true,
  );

  static const PrivacySettings balanced = PrivacySettings(
    detectFaces: true,
    storeFaceBoxes: false,
    locationPrecision: LocationPrecision.city,
    redactExif: true,
    enablePiiDetection: true,
    autoBlurFaces: false,
  );

  static const PrivacySettings analysisEnabled = PrivacySettings(
    detectFaces: true,
    storeFaceBoxes: true,
    locationPrecision: LocationPrecision.exact,
    redactExif: false,
    enablePiiDetection: true,
    autoBlurFaces: false,
  );
}

enum LocationPrecision {
  @JsonValue('none')
  none,
  @JsonValue('city')
  city,
  @JsonValue('exact')
  exact,
}

/// Enhanced face analysis with privacy controls
@JsonSerializable()
class EnhancedFaceAnalysis {
  final int count;
  @JsonKey(name: 'bounding_boxes')
  final List<FaceBoundingBox>? boundingBoxes;
  @JsonKey(name: 'faces_blurred')
  final bool facesBlurred;

  const EnhancedFaceAnalysis({
    required this.count,
    this.boundingBoxes,
    this.facesBlurred = false,
  });

  factory EnhancedFaceAnalysis.fromJson(Map<String, dynamic> json) => _$EnhancedFaceAnalysisFromJson(json);
  Map<String, dynamic> toJson() => _$EnhancedFaceAnalysisToJson(this);
}

@JsonSerializable()
class FaceBoundingBox {
  final double left;
  final double top;
  final double width;
  final double height;
  final double confidence;

  const FaceBoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.confidence,
  });

  factory FaceBoundingBox.fromJson(Map<String, dynamic> json) => _$FaceBoundingBoxFromJson(json);
  Map<String, dynamic> toJson() => _$FaceBoundingBoxToJson(this);
}

/// Sanitized EXIF data with privacy controls
@JsonSerializable()
class SanitizedExifData {
  @JsonKey(name: 'taken_at')
  final DateTime? takenAt;
  final GPSLocation? gps;
  @JsonKey(name: 'camera_make')
  final String? cameraMake;
  @JsonKey(name: 'camera_model')
  final String? cameraModel;
  @JsonKey(name: 'redacted_fields')
  final List<String> redactedFields;

  const SanitizedExifData({
    this.takenAt,
    this.gps,
    this.cameraMake,
    this.cameraModel,
    this.redactedFields = const [],
  });

  factory SanitizedExifData.fromJson(Map<String, dynamic> json) => _$SanitizedExifDataFromJson(json);
  Map<String, dynamic> toJson() => _$SanitizedExifDataToJson(this);
}

/// PII detection result
@JsonSerializable()
class PIIAnalysis {
  @JsonKey(name: 'has_pii')
  final bool hasPii;
  @JsonKey(name: 'pii_types')
  final List<PIIType> piiTypes;
  @JsonKey(name: 'redacted_text')
  final String? redactedText;
  final double confidence;

  const PIIAnalysis({
    required this.hasPii,
    required this.piiTypes,
    this.redactedText,
    required this.confidence,
  });

  factory PIIAnalysis.fromJson(Map<String, dynamic> json) => _$PIIAnalysisFromJson(json);
  Map<String, dynamic> toJson() => _$PIIAnalysisToJson(this);
}

enum PIIType {
  @JsonValue('name')
  name,
  @JsonValue('email')
  email,
  @JsonValue('phone')
  phone,
  @JsonValue('address')
  address,
  @JsonValue('ssn')
  ssn,
  @JsonValue('credit_card')
  creditCard,
  @JsonValue('date_of_birth')
  dateOfBirth,
  @JsonValue('id_number')
  idNumber,
}

/// Privacy-aware media processor
class PrivacyAwareProcessor {
  final PrivacySettings _settings;

  const PrivacyAwareProcessor(this._settings);

  /// Process image with privacy controls
  Future<ProcessedImageResult> processImage(
    Uint8List imageData,
    Map<String, dynamic> rawExif,
    List<FaceBoundingBox> detectedFaces,
  ) async {
    // Process faces based on privacy settings
    EnhancedFaceAnalysis? faceAnalysis;
    Uint8List? processedImage;

    if (_settings.detectFaces) {
      final boundingBoxes = _settings.storeFaceBoxes ? detectedFaces : null;
      final facesBlurred = _settings.autoBlurFaces && detectedFaces.isNotEmpty;

      faceAnalysis = EnhancedFaceAnalysis(
        count: detectedFaces.length,
        boundingBoxes: boundingBoxes,
        facesBlurred: facesBlurred,
      );

      if (facesBlurred) {
        processedImage = await _blurFaces(imageData, detectedFaces);
      }
    }

    // Process EXIF data based on privacy settings
    final sanitizedExif = _sanitizeExif(rawExif);

    return ProcessedImageResult(
      faceAnalysis: faceAnalysis,
      sanitizedExif: sanitizedExif,
      processedImage: processedImage,
    );
  }

  /// Process text for PII detection
  Future<PIIAnalysis> processText(String text) async {
    if (!_settings.enablePiiDetection) {
      return const PIIAnalysis(
        hasPii: false,
        piiTypes: [],
        confidence: 0.0,
      );
    }

    final detectedPII = await _detectPII(text);
    final redactedText = _settings.redactExif ? _redactPII(text, detectedPII) : null;

    return PIIAnalysis(
      hasPii: detectedPII.isNotEmpty,
      piiTypes: detectedPII,
      redactedText: redactedText,
      confidence: detectedPII.isNotEmpty ? 0.8 : 0.0, // Simplified confidence
    );
  }

  /// Sanitize EXIF data based on privacy settings
  SanitizedExifData _sanitizeExif(Map<String, dynamic> rawExif) {
    final redactedFields = <String>[];
    DateTime? takenAt;
    GPSLocation? gps;
    String? cameraMake;
    String? cameraModel;

    // Always preserve basic metadata
    if (rawExif.containsKey('DateTime')) {
      takenAt = DateTime.tryParse(rawExif['DateTime']);
    }

    // Handle location precision
    if (rawExif.containsKey('GPS') && _settings.locationPrecision != LocationPrecision.none) {
      final gpsData = rawExif['GPS'] as Map<String, dynamic>?;
      if (gpsData != null) {
        final lat = gpsData['Latitude'] as double?;
        final lon = gpsData['Longitude'] as double?;

        if (lat != null && lon != null) {
          switch (_settings.locationPrecision) {
            case LocationPrecision.exact:
              gps = GPSLocation(lat: lat, lon: lon);
              break;
            case LocationPrecision.city:
              // Round to ~1km precision
              gps = GPSLocation(
                lat: (lat * 100).round() / 100,
                lon: (lon * 100).round() / 100,
              );
              break;
            case LocationPrecision.none:
              redactedFields.add('GPS');
              break;
          }
        }
      }
    }

    // Handle camera information
    if (!_settings.redactExif) {
      cameraMake = rawExif['Make'] as String?;
      cameraModel = rawExif['Model'] as String?;
    } else {
      if (rawExif.containsKey('Make')) redactedFields.add('Make');
      if (rawExif.containsKey('Model')) redactedFields.add('Model');
      if (rawExif.containsKey('Software')) redactedFields.add('Software');
      if (rawExif.containsKey('Artist')) redactedFields.add('Artist');
      if (rawExif.containsKey('Copyright')) redactedFields.add('Copyright');
    }

    return SanitizedExifData(
      takenAt: takenAt,
      gps: gps,
      cameraMake: cameraMake,
      cameraModel: cameraModel,
      redactedFields: redactedFields,
    );
  }

  /// Detect PII in text using simple pattern matching
  Future<List<PIIType>> _detectPII(String text) async {
    final piiTypes = <PIIType>[];
    final lowerText = text.toLowerCase();

    // Email detection
    if (RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b').hasMatch(text)) {
      piiTypes.add(PIIType.email);
    }

    // Phone number detection
    if (RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b').hasMatch(text)) {
      piiTypes.add(PIIType.phone);
    }

    // Name detection (simple heuristics)
    if (RegExp(r'\bmy name is\b|\bi am\b|\bcalled\b').hasMatch(lowerText)) {
      piiTypes.add(PIIType.name);
    }

    // SSN detection
    if (RegExp(r'\b\d{3}-\d{2}-\d{4}\b').hasMatch(text)) {
      piiTypes.add(PIIType.ssn);
    }

    // Credit card detection
    if (RegExp(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b').hasMatch(text)) {
      piiTypes.add(PIIType.creditCard);
    }

    // Address detection
    if (RegExp(r'\b\d+\s+[A-Za-z\s]+(?:street|st|avenue|ave|road|rd|lane|ln|drive|dr)\b', caseSensitive: false).hasMatch(text)) {
      piiTypes.add(PIIType.address);
    }

    return piiTypes;
  }

  /// Redact PII from text
  String _redactPII(String text, List<PIIType> piiTypes) {
    String redacted = text;

    for (final type in piiTypes) {
      switch (type) {
        case PIIType.email:
          redacted = redacted.replaceAll(
            RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
            '[EMAIL_REDACTED]',
          );
          break;
        case PIIType.phone:
          redacted = redacted.replaceAll(
            RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b'),
            '[PHONE_REDACTED]',
          );
          break;
        case PIIType.ssn:
          redacted = redacted.replaceAll(
            RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
            '[SSN_REDACTED]',
          );
          break;
        case PIIType.creditCard:
          redacted = redacted.replaceAll(
            RegExp(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b'),
            '[CARD_REDACTED]',
          );
          break;
        case PIIType.address:
          redacted = redacted.replaceAll(
            RegExp(r'\b\d+\s+[A-Za-z\s]+(?:street|st|avenue|ave|road|rd|lane|ln|drive|dr)\b', caseSensitive: false),
            '[ADDRESS_REDACTED]',
          );
          break;
        case PIIType.name:
        case PIIType.dateOfBirth:
        case PIIType.idNumber:
          // These require more sophisticated NER - placeholder for now
          break;
      }
    }

    return redacted;
  }

  /// Blur faces in image (simplified implementation)
  Future<Uint8List> _blurFaces(Uint8List imageData, List<FaceBoundingBox> faces) async {
    // In a real implementation, this would use image processing libraries
    // to apply gaussian blur to the face regions
    
    // For now, return original image data
    // In production, you would:
    // 1. Decode the image
    // 2. Apply gaussian blur to each face bounding box
    // 3. Re-encode the image
    
    print('PrivacyAwareProcessor: Would blur ${faces.length} faces');
    return imageData;
  }
}

/// Result of privacy-aware image processing
class ProcessedImageResult {
  final EnhancedFaceAnalysis? faceAnalysis;
  final SanitizedExifData sanitizedExif;
  final Uint8List? processedImage;

  const ProcessedImageResult({
    this.faceAnalysis,
    required this.sanitizedExif,
    this.processedImage,
  });
}

/// Privacy settings persistence
class PrivacySettingsStore {
  static const String _storageKey = 'privacy_settings';

  /// Save privacy settings
  static Future<void> save(PrivacySettings settings) async {
    // In a real implementation, this would use SharedPreferences or Hive
    print('PrivacySettingsStore: Saved settings');
  }

  /// Load privacy settings
  static Future<PrivacySettings> load() async {
    // In a real implementation, this would load from persistent storage
    // For now, return balanced defaults
    return PrivacySettings.balanced;
  }

  /// Get privacy settings for specific app mode
  static Future<PrivacySettings> getForMode(String mode) async {
    final base = await load();
    
    // Apply mode-specific overrides
    switch (mode) {
      case 'first_responder':
        // First responder mode may need more analysis
        return base.copyWith(
          detectFaces: true,
          storeFaceBoxes: true,
          enablePiiDetection: true,
        );
      case 'coach':
        // Coach mode is privacy-focused
        return base.copyWith(
          locationPrecision: LocationPrecision.city,
          redactExif: true,
        );
      default:
        return base;
    }
  }
}

/// Privacy compliance checker
class PrivacyComplianceChecker {
  /// Check if media processing is compliant with privacy settings
  static bool isCompliant(
    PrivacySettings settings,
    Map<String, dynamic> processingOptions,
  ) {
    // Check face detection compliance
    if (!settings.detectFaces && processingOptions['detectFaces'] == true) {
      return false;
    }

    // Check location precision compliance
    if (settings.locationPrecision == LocationPrecision.none && 
        processingOptions['includeLocation'] == true) {
      return false;
    }

    // Check PII detection compliance
    if (!settings.enablePiiDetection && processingOptions['analyzePII'] == true) {
      return false;
    }

    return true;
  }

  /// Generate privacy report for media processing
  static Map<String, dynamic> generatePrivacyReport(
    PrivacySettings settings,
    ProcessedImageResult? imageResult,
    PIIAnalysis? textAnalysis,
  ) {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'settings': settings.toJson(),
      'processing_applied': {
        'face_detection': imageResult?.faceAnalysis != null,
        'face_blurring': imageResult?.faceAnalysis?.facesBlurred ?? false,
        'exif_sanitization': true,
        'pii_analysis': textAnalysis != null,
        'pii_redaction': textAnalysis?.redactedText != null,
      },
      'privacy_level': _calculatePrivacyLevel(settings),
    };
  }

  static String _calculatePrivacyLevel(PrivacySettings settings) {
    if (!settings.detectFaces && 
        settings.locationPrecision == LocationPrecision.none &&
        settings.redactExif &&
        settings.autoBlurFaces) {
      return 'high';
    } else if (settings.locationPrecision == LocationPrecision.city &&
               settings.redactExif) {
      return 'medium';
    } else {
      return 'low';
    }
  }
}
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'privacy_controls.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrivacySettings _$PrivacySettingsFromJson(Map<String, dynamic> json) =>
    PrivacySettings(
      detectFaces: json['detect_faces'] as bool? ?? true,
      storeFaceBoxes: json['store_face_boxes'] as bool? ?? false,
      locationPrecision: $enumDecodeNullable(
              _$LocationPrecisionEnumMap, json['location_precision']) ??
          LocationPrecision.city,
      redactExif: json['redact_exif'] as bool? ?? true,
      enablePiiDetection: json['enable_pii_detection'] as bool? ?? true,
      autoBlurFaces: json['auto_blur_faces'] as bool? ?? false,
    );

Map<String, dynamic> _$PrivacySettingsToJson(PrivacySettings instance) =>
    <String, dynamic>{
      'detect_faces': instance.detectFaces,
      'store_face_boxes': instance.storeFaceBoxes,
      'location_precision':
          _$LocationPrecisionEnumMap[instance.locationPrecision]!,
      'redact_exif': instance.redactExif,
      'enable_pii_detection': instance.enablePiiDetection,
      'auto_blur_faces': instance.autoBlurFaces,
    };

const _$LocationPrecisionEnumMap = {
  LocationPrecision.none: 'none',
  LocationPrecision.city: 'city',
  LocationPrecision.exact: 'exact',
};

EnhancedFaceAnalysis _$EnhancedFaceAnalysisFromJson(
        Map<String, dynamic> json) =>
    EnhancedFaceAnalysis(
      count: (json['count'] as num).toInt(),
      boundingBoxes: (json['bounding_boxes'] as List<dynamic>?)
          ?.map((e) => FaceBoundingBox.fromJson(e as Map<String, dynamic>))
          .toList(),
      facesBlurred: json['faces_blurred'] as bool? ?? false,
    );

Map<String, dynamic> _$EnhancedFaceAnalysisToJson(
        EnhancedFaceAnalysis instance) =>
    <String, dynamic>{
      'count': instance.count,
      'bounding_boxes': instance.boundingBoxes,
      'faces_blurred': instance.facesBlurred,
    };

FaceBoundingBox _$FaceBoundingBoxFromJson(Map<String, dynamic> json) =>
    FaceBoundingBox(
      left: (json['left'] as num).toDouble(),
      top: (json['top'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
    );

Map<String, dynamic> _$FaceBoundingBoxToJson(FaceBoundingBox instance) =>
    <String, dynamic>{
      'left': instance.left,
      'top': instance.top,
      'width': instance.width,
      'height': instance.height,
      'confidence': instance.confidence,
    };

SanitizedExifData _$SanitizedExifDataFromJson(Map<String, dynamic> json) =>
    SanitizedExifData(
      takenAt: json['taken_at'] == null
          ? null
          : DateTime.parse(json['taken_at'] as String),
      gps: json['gps'] == null
          ? null
          : GPSLocation.fromJson(json['gps'] as Map<String, dynamic>),
      cameraMake: json['camera_make'] as String?,
      cameraModel: json['camera_model'] as String?,
      redactedFields: (json['redacted_fields'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$SanitizedExifDataToJson(SanitizedExifData instance) =>
    <String, dynamic>{
      'taken_at': instance.takenAt?.toIso8601String(),
      'gps': instance.gps,
      'camera_make': instance.cameraMake,
      'camera_model': instance.cameraModel,
      'redacted_fields': instance.redactedFields,
    };

PIIAnalysis _$PIIAnalysisFromJson(Map<String, dynamic> json) => PIIAnalysis(
      hasPii: json['has_pii'] as bool,
      piiTypes: (json['pii_types'] as List<dynamic>)
          .map((e) => $enumDecode(_$PIITypeEnumMap, e))
          .toList(),
      redactedText: json['redacted_text'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
    );

Map<String, dynamic> _$PIIAnalysisToJson(PIIAnalysis instance) =>
    <String, dynamic>{
      'has_pii': instance.hasPii,
      'pii_types': instance.piiTypes.map((e) => _$PIITypeEnumMap[e]!).toList(),
      'redacted_text': instance.redactedText,
      'confidence': instance.confidence,
    };

const _$PIITypeEnumMap = {
  PIIType.name: 'name',
  PIIType.email: 'email',
  PIIType.phone: 'phone',
  PIIType.address: 'address',
  PIIType.ssn: 'ssn',
  PIIType.creditCard: 'credit_card',
  PIIType.dateOfBirth: 'date_of_birth',
  PIIType.idNumber: 'id_number',
};

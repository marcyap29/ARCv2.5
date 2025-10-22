// lib/rivet/validation/rivet_models.dart
// RIVET validation models for evidence tracking

enum EvidenceSource {
  journal,
  chat,
  media,
  arcform,
  phase,
  system,
}

class RivetEvent {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final EvidenceSource source;
  final DateTime timestamp;
  final double confidence;
  final List<String> tags;

  const RivetEvent({
    required this.id,
    required this.type,
    required this.data,
    required this.source,
    required this.timestamp,
    required this.confidence,
    this.tags = const [],
  });

  factory RivetEvent.fromJson(Map<String, dynamic> json) {
    return RivetEvent(
      id: json['id'] as String,
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>,
      source: EvidenceSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => EvidenceSource.system,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      confidence: (json['confidence'] as num).toDouble(),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'data': data,
      'source': source.name,
      'timestamp': timestamp.toIso8601String(),
      'confidence': confidence,
      'tags': tags,
    };
  }
}

class RivetValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, dynamic> metadata;

  const RivetValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.metadata = const {},
  });

  factory RivetValidationResult.fromJson(Map<String, dynamic> json) {
    return RivetValidationResult(
      isValid: json['isValid'] as bool,
      errors: (json['errors'] as List<dynamic>?)?.cast<String>() ?? [],
      warnings: (json['warnings'] as List<dynamic>?)?.cast<String>() ?? [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isValid': isValid,
      'errors': errors,
      'warnings': warnings,
      'metadata': metadata,
    };
  }
}

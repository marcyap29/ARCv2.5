import 'dart:io';
import 'dart:convert';
import 'package:my_app/mcp/import/ndjson_stream_reader.dart';

/// Validation error details
class ValidationError {
  final String message;
  final int? lineNumber;
  final String? fieldPath;
  final dynamic value;
  final String severity; // 'error', 'warning'

  const ValidationError({
    required this.message,
    this.lineNumber,
    this.fieldPath,
    this.value,
    this.severity = 'error',
  });

  @override
  String toString() {
    final lineInfo = lineNumber != null ? ' (line $lineNumber)' : '';
    final pathInfo = fieldPath != null ? ' at $fieldPath' : '';
    return '$severity: $message$pathInfo$lineInfo';
  }
}

/// Result of MCP validation
class McpValidationResult {
  final bool isValid;
  final List<ValidationError> errors;
  final List<ValidationError> warnings;
  final int totalRecords;
  final int validRecords;
  final Duration processingTime;

  const McpValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.totalRecords,
    required this.validRecords,
    required this.processingTime,
  });

  int get invalidRecords => totalRecords - validRecords;
  double get validPercent => totalRecords > 0 ? (validRecords / totalRecords) * 100 : 0.0;

  @override
  String toString() {
    return 'McpValidationResult(valid: $isValid, records: $validRecords/$totalRecords '
           '(${validPercent.toStringAsFixed(1)}%), errors: ${errors.length}, '
           'warnings: ${warnings.length}, time: ${processingTime.inMilliseconds}ms)';
  }
}

/// Comprehensive validator for MCP import data
/// 
/// Validates MCP schemas, enforces guardrails, and provides detailed error reporting
/// for nodes, edges, pointers, and embeddings according to MCP Draft 2020-12.
class McpImportValidator {
  final NdjsonStreamReader _streamReader;
  final bool strictMode;
  final bool ignoreUnknownFields;

  McpImportValidator({
    NdjsonStreamReader? streamReader,
    this.strictMode = false,
    this.ignoreUnknownFields = true,
  }) : _streamReader = streamReader ?? NdjsonStreamReader();

  /// Validate an entire NDJSON file for a specific record type
  Future<McpValidationResult> validateNdjsonFile(File file, String recordType) async {
    final stopwatch = Stopwatch()..start();
    final errors = <ValidationError>[];
    final warnings = <ValidationError>[];
    int totalRecords = 0;
    int validRecords = 0;

    try {
      await for (final line in _streamReader.readStream(file)) {
        totalRecords++;
        
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final recordErrors = <ValidationError>[];
          
          // Validate based on record type
          switch (recordType.toLowerCase()) {
            case 'node':
              _validateNodeRecord(json, totalRecords, recordErrors);
              break;
            case 'edge':
              _validateEdgeRecord(json, totalRecords, recordErrors);
              break;
            case 'pointer':
              _validatePointerRecord(json, totalRecords, recordErrors);
              break;
            case 'embedding':
              _validateEmbeddingRecord(json, totalRecords, recordErrors);
              break;
            default:
              recordErrors.add(ValidationError(
                message: 'Unknown record type: $recordType',
                lineNumber: totalRecords,
                severity: 'error',
              ));
          }
          
          if (recordErrors.isEmpty) {
            validRecords++;
          } else {
            errors.addAll(recordErrors);
          }
          
        } catch (e) {
          errors.add(ValidationError(
            message: 'Invalid JSON: $e',
            lineNumber: totalRecords,
            severity: 'error',
          ));
        }
        
        // Limit error collection to prevent memory issues
        if (errors.length > 10000) {
          warnings.add(const ValidationError(
            message: 'Too many errors, stopping validation early',
            severity: 'warning',
          ));
          break;
        }
      }
    } catch (e) {
      errors.add(ValidationError(
        message: 'File reading error: $e',
        severity: 'error',
      ));
    }

    stopwatch.stop();
    
    return McpValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      totalRecords: totalRecords,
      validRecords: validRecords,
      processingTime: stopwatch.elapsed,
    );
  }

  /// Validate a single Node record
  void _validateNodeRecord(Map<String, dynamic> json, int lineNumber, List<ValidationError> errors) {
    try {
      // Required fields
      _validateRequiredField(json, 'id', String, lineNumber, errors);
      _validateRequiredField(json, 'type', String, lineNumber, errors);
      _validateRequiredField(json, 'created_at', String, lineNumber, errors);
      
      // Validate timestamps are UTC ISO-8601
      if (json.containsKey('created_at')) {
        _validateUtcTimestamp(json['created_at'], 'created_at', lineNumber, errors);
      }
      if (json.containsKey('updated_at')) {
        _validateUtcTimestamp(json['updated_at'], 'updated_at', lineNumber, errors);
      }
      
      // Validate SAGE fields if present
      if (json.containsKey('narrative')) {
        _validateSageNarrative(json['narrative'], lineNumber, errors);
      }
      
      // Validate phase hint
      if (json.containsKey('phase_hint')) {
        _validatePhaseHint(json['phase_hint'], lineNumber, errors);
      }
      
      // Validate keywords array
      if (json.containsKey('keywords')) {
        _validateKeywordsArray(json['keywords'], lineNumber, errors);
      }
      
      // Validate emotions object
      if (json.containsKey('emotions')) {
        _validateEmotionsObject(json['emotions'], lineNumber, errors);
      }
      
      // Validate provenance
      if (json.containsKey('provenance')) {
        _validateProvenance(json['provenance'], lineNumber, errors);
      }
      
      // Check for unknown fields if not ignoring them
      if (!ignoreUnknownFields) {
        _checkUnknownFields(json, _getKnownNodeFields(), 'node', lineNumber, errors);
      }
      
    } catch (e) {
      errors.add(ValidationError(
        message: 'Node validation error: $e',
        lineNumber: lineNumber,
        severity: 'error',
      ));
    }
  }

  /// Validate a single Edge record
  void _validateEdgeRecord(Map<String, dynamic> json, int lineNumber, List<ValidationError> errors) {
    try {
      // Required fields
      _validateRequiredField(json, 'id', String, lineNumber, errors);
      _validateRequiredField(json, 'source', String, lineNumber, errors);
      _validateRequiredField(json, 'target', String, lineNumber, errors);
      _validateRequiredField(json, 'relation_type', String, lineNumber, errors);
      _validateRequiredField(json, 'created_at', String, lineNumber, errors);
      
      // Validate timestamps
      if (json.containsKey('created_at')) {
        _validateUtcTimestamp(json['created_at'], 'created_at', lineNumber, errors);
      }
      
      // Validate weight (if present)
      if (json.containsKey('weight')) {
        _validateNumericRange(json['weight'], 'weight', 0.0, 1.0, lineNumber, errors);
      }
      
      // Validate confidence (if present)
      if (json.containsKey('confidence')) {
        _validateNumericRange(json['confidence'], 'confidence', 0.0, 1.0, lineNumber, errors);
      }
      
      // Validate relation type
      if (json.containsKey('relation_type')) {
        _validateRelationType(json['relation_type'], lineNumber, errors);
      }
      
      // Check for unknown fields
      if (!ignoreUnknownFields) {
        _checkUnknownFields(json, _getKnownEdgeFields(), 'edge', lineNumber, errors);
      }
      
    } catch (e) {
      errors.add(ValidationError(
        message: 'Edge validation error: $e',
        lineNumber: lineNumber,
        severity: 'error',
      ));
    }
  }

  /// Validate a single Pointer record
  void _validatePointerRecord(Map<String, dynamic> json, int lineNumber, List<ValidationError> errors) {
    try {
      // Required fields (note: source_uri is optional per spec)
      _validateRequiredField(json, 'id', String, lineNumber, errors);
      _validateRequiredField(json, 'created_at', String, lineNumber, errors);
      
      // Validate timestamps
      if (json.containsKey('created_at')) {
        _validateUtcTimestamp(json['created_at'], 'created_at', lineNumber, errors);
      }
      
      // Validate integrity object if present
      if (json.containsKey('integrity')) {
        _validateIntegrityObject(json['integrity'], lineNumber, errors);
      }
      
      // Validate privacy object if present
      if (json.containsKey('privacy')) {
        _validatePrivacyObject(json['privacy'], lineNumber, errors);
      }
      
      // Validate provenance
      if (json.containsKey('provenance')) {
        _validateProvenance(json['provenance'], lineNumber, errors);
      }
      
      // Check for unknown fields
      if (!ignoreUnknownFields) {
        _checkUnknownFields(json, _getKnownPointerFields(), 'pointer', lineNumber, errors);
      }
      
    } catch (e) {
      errors.add(ValidationError(
        message: 'Pointer validation error: $e',
        lineNumber: lineNumber,
        severity: 'error',
      ));
    }
  }

  /// Validate a single Embedding record
  void _validateEmbeddingRecord(Map<String, dynamic> json, int lineNumber, List<ValidationError> errors) {
    try {
      // Required fields
      _validateRequiredField(json, 'id', String, lineNumber, errors);
      _validateRequiredField(json, 'model_id', String, lineNumber, errors);
      _validateRequiredField(json, 'created_at', String, lineNumber, errors);
      
      // Validate timestamps
      if (json.containsKey('created_at')) {
        _validateUtcTimestamp(json['created_at'], 'created_at', lineNumber, errors);
      }
      
      // Validate vector dimensions
      if (json.containsKey('vector')) {
        _validateVectorArray(json['vector'], lineNumber, errors);
      }
      
      // Validate embedding version
      if (json.containsKey('embedding_version')) {
        _validateEmbeddingVersion(json['embedding_version'], lineNumber, errors);
      }
      
      // Check for unknown fields
      if (!ignoreUnknownFields) {
        _checkUnknownFields(json, _getKnownEmbeddingFields(), 'embedding', lineNumber, errors);
      }
      
    } catch (e) {
      errors.add(ValidationError(
        message: 'Embedding validation error: $e',
        lineNumber: lineNumber,
        severity: 'error',
      ));
    }
  }

  /// Validate required field presence and type
  void _validateRequiredField(
    Map<String, dynamic> json,
    String fieldName,
    Type expectedType,
    int lineNumber,
    List<ValidationError> errors,
  ) {
    if (!json.containsKey(fieldName)) {
      errors.add(ValidationError(
        message: 'Missing required field: $fieldName',
        lineNumber: lineNumber,
        fieldPath: fieldName,
        severity: 'error',
      ));
      return;
    }
    
    final value = json[fieldName];
    if (value == null) {
      errors.add(ValidationError(
        message: 'Required field cannot be null: $fieldName',
        lineNumber: lineNumber,
        fieldPath: fieldName,
        severity: 'error',
      ));
      return;
    }
    
    // Type checking
    bool typeMatches = false;
    switch (expectedType) {
      case String:
        typeMatches = value is String;
        break;
      case int:
        typeMatches = value is int;
        break;
      case double:
        typeMatches = value is num;
        break;
      case bool:
        typeMatches = value is bool;
        break;
      case List:
        typeMatches = value is List;
        break;
      case Map:
        typeMatches = value is Map;
        break;
    }
    
    if (!typeMatches) {
      errors.add(ValidationError(
        message: 'Field $fieldName must be of type $expectedType, got ${value.runtimeType}',
        lineNumber: lineNumber,
        fieldPath: fieldName,
        value: value,
        severity: 'error',
      ));
    }
  }

  /// Validate UTC timestamp format
  void _validateUtcTimestamp(dynamic value, String fieldName, int lineNumber, List<ValidationError> errors) {
    if (value is! String) {
      errors.add(ValidationError(
        message: 'Timestamp must be a string: $fieldName',
        lineNumber: lineNumber,
        fieldPath: fieldName,
        severity: 'error',
      ));
      return;
    }
    
    try {
      final dt = DateTime.parse(value);
      if (!dt.isUtc) {
        errors.add(ValidationError(
          message: 'Timestamp must be in UTC timezone: $fieldName',
          lineNumber: lineNumber,
          fieldPath: fieldName,
          value: value,
          severity: 'error',
        ));
      }
    } catch (e) {
      errors.add(ValidationError(
        message: 'Invalid timestamp format: $fieldName ($e)',
        lineNumber: lineNumber,
        fieldPath: fieldName,
        value: value,
        severity: 'error',
      ));
    }
  }

  /// Validate SAGE narrative structure
  void _validateSageNarrative(dynamic value, int lineNumber, List<ValidationError> errors) {
    if (value is! Map<String, dynamic>) {
      errors.add(ValidationError(
        message: 'Narrative must be an object',
        lineNumber: lineNumber,
        fieldPath: 'narrative',
        severity: 'error',
      ));
      return;
    }
    
    final narrative = value;
    final sageFields = ['situation', 'action', 'growth', 'essence'];
    
    for (final field in sageFields) {
      if (narrative.containsKey(field) && narrative[field] is! String) {
        errors.add(ValidationError(
          message: 'SAGE field $field must be a string',
          lineNumber: lineNumber,
          fieldPath: 'narrative.$field',
          severity: 'error',
        ));
      }
    }
  }

  /// Validate phase hint values
  void _validatePhaseHint(dynamic value, int lineNumber, List<ValidationError> errors) {
    if (value is! String) {
      errors.add(ValidationError(
        message: 'Phase hint must be a string',
        lineNumber: lineNumber,
        fieldPath: 'phase_hint',
        severity: 'error',
      ));
      return;
    }
    
    const validPhases = [
      'Discovery', 'Expansion', 'Transition', 'Consolidation', 'Recovery', 'Breakthrough'
    ];
    
    if (!validPhases.contains(value)) {
      errors.add(ValidationError(
        message: 'Invalid phase hint: $value',
        lineNumber: lineNumber,
        fieldPath: 'phase_hint',
        value: value,
        severity: 'error',
      ));
    }
  }

  /// Validate keywords array
  void _validateKeywordsArray(dynamic value, int lineNumber, List<ValidationError> errors) {
    if (value is! List) {
      errors.add(ValidationError(
        message: 'Keywords must be an array',
        lineNumber: lineNumber,
        fieldPath: 'keywords',
        severity: 'error',
      ));
      return;
    }
    
    final keywords = value;
    for (int i = 0; i < keywords.length; i++) {
      if (keywords[i] is! String) {
        errors.add(ValidationError(
          message: 'Keyword at index $i must be a string',
          lineNumber: lineNumber,
          fieldPath: 'keywords[$i]',
          severity: 'error',
        ));
      }
    }
  }

  /// Validate emotions object
  void _validateEmotionsObject(dynamic value, int lineNumber, List<ValidationError> errors) {
    if (value is! Map<String, dynamic>) {
      errors.add(ValidationError(
        message: 'Emotions must be an object',
        lineNumber: lineNumber,
        fieldPath: 'emotions',
        severity: 'error',
      ));
      return;
    }
    
    final emotions = value;
    
    // Validate valence and arousal if present
    if (emotions.containsKey('valence')) {
      _validateNumericRange(emotions['valence'], 'emotions.valence', -1.0, 1.0, lineNumber, errors);
    }
    if (emotions.containsKey('arousal')) {
      _validateNumericRange(emotions['arousal'], 'emotions.arousal', 0.0, 1.0, lineNumber, errors);
    }
  }

  /// Validate numeric value within range
  void _validateNumericRange(
    dynamic value,
    String fieldPath,
    double min,
    double max,
    int lineNumber,
    List<ValidationError> errors,
  ) {
    if (value is! num) {
      errors.add(ValidationError(
        message: 'Field $fieldPath must be numeric',
        lineNumber: lineNumber,
        fieldPath: fieldPath,
        severity: 'error',
      ));
      return;
    }
    
    final numValue = value.toDouble();
    if (numValue < min || numValue > max) {
      errors.add(ValidationError(
        message: 'Field $fieldPath must be between $min and $max, got $numValue',
        lineNumber: lineNumber,
        fieldPath: fieldPath,
        value: value,
        severity: 'error',
      ));
    }
  }

  /// Validate relation type
  void _validateRelationType(dynamic value, int lineNumber, List<ValidationError> errors) {
    if (value is! String) {
      errors.add(ValidationError(
        message: 'Relation type must be a string',
        lineNumber: lineNumber,
        fieldPath: 'relation_type',
        severity: 'error',
      ));
      return;
    }
    
    const validRelations = [
      'temporal_adjacency', 'thematic_similarity', 'phase_similarity',
      'emotional_resonance', 'causal_link', 'contextual_reference'
    ];
    
    if (!validRelations.contains(value)) {
      errors.add(ValidationError(
        message: 'Unknown relation type: $value',
        lineNumber: lineNumber,
        fieldPath: 'relation_type',
        value: value,
        severity: 'warning', // Warning since new types may be added
      ));
    }
  }

  /// Validate integrity object
  void _validateIntegrityObject(dynamic value, int lineNumber, List<ValidationError> errors) {
    if (value is! Map<String, dynamic>) {
      errors.add(ValidationError(
        message: 'Integrity must be an object',
        lineNumber: lineNumber,
        fieldPath: 'integrity',
        severity: 'error',
      ));
      return;
    }
    
    final integrity = value;
    
    // Validate hash algorithm and value
    if (integrity.containsKey('algorithm') && integrity['algorithm'] is! String) {
      errors.add(ValidationError(
        message: 'Integrity algorithm must be a string',
        lineNumber: lineNumber,
        fieldPath: 'integrity.algorithm',
        severity: 'error',
      ));
    }
    
    if (integrity.containsKey('hash') && integrity['hash'] is! String) {
      errors.add(ValidationError(
        message: 'Integrity hash must be a string',
        lineNumber: lineNumber,
        fieldPath: 'integrity.hash',
        severity: 'error',
      ));
    }
  }

  /// Validate privacy object
  void _validatePrivacyObject(dynamic value, int lineNumber, List<ValidationError> errors) {
    if (value is! Map<String, dynamic>) {
      errors.add(ValidationError(
        message: 'Privacy must be an object',
        lineNumber: lineNumber,
        fieldPath: 'privacy',
        severity: 'error',
      ));
      return;
    }
    
    final privacy = value;
    
    // Validate boolean privacy flags
    final boolFields = ['has_pii', 'has_faces', 'has_location'];
    for (final field in boolFields) {
      if (privacy.containsKey(field) && privacy[field] is! bool) {
        errors.add(ValidationError(
          message: 'Privacy field $field must be boolean',
          lineNumber: lineNumber,
          fieldPath: 'privacy.$field',
          severity: 'error',
        ));
      }
    }
  }

  /// Validate provenance object
  void _validateProvenance(dynamic value, int lineNumber, List<ValidationError> errors) {
    if (value is! Map<String, dynamic>) {
      errors.add(ValidationError(
        message: 'Provenance must be an object',
        lineNumber: lineNumber,
        fieldPath: 'provenance',
        severity: 'error',
      ));
      return;
    }
  }

  /// Validate vector array for embeddings
  void _validateVectorArray(dynamic value, int lineNumber, List<ValidationError> errors) {
    if (value is! List) {
      errors.add(ValidationError(
        message: 'Vector must be an array',
        lineNumber: lineNumber,
        fieldPath: 'vector',
        severity: 'error',
      ));
      return;
    }
    
    final vector = value;
    if (vector.isEmpty) {
      errors.add(ValidationError(
        message: 'Vector cannot be empty',
        lineNumber: lineNumber,
        fieldPath: 'vector',
        severity: 'error',
      ));
      return;
    }
    
    for (int i = 0; i < vector.length; i++) {
      if (vector[i] is! num) {
        errors.add(ValidationError(
          message: 'Vector element at index $i must be numeric',
          lineNumber: lineNumber,
          fieldPath: 'vector[$i]',
          severity: 'error',
        ));
      }
    }
  }

  /// Validate embedding version
  void _validateEmbeddingVersion(dynamic value, int lineNumber, List<ValidationError> errors) {
    if (value is! String) {
      errors.add(ValidationError(
        message: 'Embedding version must be a string',
        lineNumber: lineNumber,
        fieldPath: 'embedding_version',
        severity: 'error',
      ));
    }
  }

  /// Check for unknown fields
  void _checkUnknownFields(
    Map<String, dynamic> json,
    Set<String> knownFields,
    String recordType,
    int lineNumber,
    List<ValidationError> errors,
  ) {
    for (final key in json.keys) {
      if (!knownFields.contains(key)) {
        errors.add(ValidationError(
          message: 'Unknown field in $recordType: $key',
          lineNumber: lineNumber,
          fieldPath: key,
          severity: strictMode ? 'error' : 'warning',
        ));
      }
    }
  }

  /// Get known fields for Node records
  Set<String> _getKnownNodeFields() => {
    'id', 'type', 'created_at', 'updated_at', 'narrative', 'phase_hint',
    'keywords', 'emotions', 'pointer_ref', 'embedding_ref', 'provenance',
    'labels', 'schema_version'
  };

  /// Get known fields for Edge records
  Set<String> _getKnownEdgeFields() => {
    'id', 'source', 'target', 'relation_type', 'weight', 'confidence',
    'created_at', 'provenance', 'labels', 'schema_version'
  };

  /// Get known fields for Pointer records
  Set<String> _getKnownPointerFields() => {
    'id', 'source_uri', 'cas_uri', 'descriptor', 'sampling_manifest',
    'integrity', 'provenance', 'privacy', 'labels', 'created_at', 'schema_version'
  };

  /// Get known fields for Embedding records
  Set<String> _getKnownEmbeddingFields() => {
    'id', 'model_id', 'vector', 'embedding_version', 'dim', 'node_ref',
    'created_at', 'provenance', 'labels', 'schema_version'
  };
}
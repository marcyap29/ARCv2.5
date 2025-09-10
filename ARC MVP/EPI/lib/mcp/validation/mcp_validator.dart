/// MCP Validator
/// 
/// Provides runtime validation for MCP records and bundles
/// following MCP v1 guardrails and schema requirements.

import 'dart:io';
import '../models/mcp_schemas.dart';
import '../export/ndjson_writer.dart';
import '../export/manifest_builder.dart';

class McpValidator {
  /// Validate a single node record
  static ValidationResult validateNode(McpNode node) {
    final errors = <String>[];

    // Required fields
    if (node.id.isEmpty) {
      errors.add('Node ID cannot be empty');
    }
    if (node.type.isEmpty) {
      errors.add('Node type cannot be empty');
    }
    if (node.schemaVersion != 'node.v1') {
      errors.add('Invalid schema version: ${node.schemaVersion}');
    }

    // Timestamp validation
    if (node.timestamp.isUtc == false) {
      errors.add('Timestamp must be in UTC');
    }

    // Content validation
    if (node.pointerRef == null && node.contentSummary == null) {
      errors.add('Node must have either pointer_ref or content_summary');
    }

    // Phase hint validation
    if (node.phaseHint != null) {
      final validPhases = [
        'Discovery', 'Expansion', 'Transition', 
        'Consolidation', 'Recovery', 'Breakthrough'
      ];
      if (!validPhases.contains(node.phaseHint)) {
        errors.add('Invalid phase hint: ${node.phaseHint}');
      }
    }

    // Keywords validation
    for (final keyword in node.keywords) {
      if (keyword.isEmpty) {
        errors.add('Keywords cannot be empty strings');
        break;
      }
    }

    // Emotions validation
    for (final entry in node.emotions.entries) {
      if (entry.value < 0.0 || entry.value > 1.0) {
        errors.add('Emotion values must be between 0.0 and 1.0: ${entry.key}=${entry.value}');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validate a single edge record
  static ValidationResult validateEdge(McpEdge edge) {
    final errors = <String>[];

    // Required fields
    if (edge.source.isEmpty) {
      errors.add('Edge source cannot be empty');
    }
    if (edge.target.isEmpty) {
      errors.add('Edge target cannot be empty');
    }
    if (edge.relation.isEmpty) {
      errors.add('Edge relation cannot be empty');
    }
    if (edge.schemaVersion != 'edge.v1') {
      errors.add('Invalid schema version: ${edge.schemaVersion}');
    }

    // Timestamp validation
    if (edge.timestamp.isUtc == false) {
      errors.add('Timestamp must be in UTC');
    }

    // Weight validation
    if (edge.weight != null && (edge.weight! < 0.0 || edge.weight! > 1.0)) {
      errors.add('Edge weight must be between 0.0 and 1.0');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validate a single pointer record
  static ValidationResult validatePointer(McpPointer pointer) {
    final errors = <String>[];

    // Required fields
    if (pointer.id.isEmpty) {
      errors.add('Pointer ID cannot be empty');
    }
    if (pointer.mediaType.isEmpty) {
      errors.add('Pointer media type cannot be empty');
    }
    if (pointer.schemaVersion != 'pointer.v1') {
      errors.add('Invalid schema version: ${pointer.schemaVersion}');
    }

    // Integrity validation
    if (pointer.integrity.contentHash.isEmpty) {
      errors.add('Content hash cannot be empty');
    }
    if (pointer.integrity.bytes < 0) {
      errors.add('Bytes count cannot be negative');
    }
    if (pointer.integrity.createdAt.isUtc == false) {
      errors.add('Created at timestamp must be in UTC');
    }

    // Content hash format validation (should be SHA-256)
    if (pointer.integrity.contentHash.length != 64) {
      errors.add('Content hash must be 64 characters (SHA-256)');
    }

    // Descriptor validation
    if (pointer.descriptor.length != null && pointer.descriptor.length! < 0) {
      errors.add('Descriptor length cannot be negative');
    }

    // Privacy validation
    if (pointer.privacy.sharingPolicy.isEmpty) {
      errors.add('Sharing policy cannot be empty');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validate a single embedding record
  static ValidationResult validateEmbedding(McpEmbedding embedding) {
    final errors = <String>[];

    // Required fields
    if (embedding.id.isEmpty) {
      errors.add('Embedding ID cannot be empty');
    }
    if (embedding.pointerRef.isEmpty) {
      errors.add('Pointer reference cannot be empty');
    }
    if (embedding.modelId.isEmpty) {
      errors.add('Model ID cannot be empty');
    }
    if (embedding.embeddingVersion.isEmpty) {
      errors.add('Embedding version cannot be empty');
    }
    if (embedding.schemaVersion != 'embedding.v1') {
      errors.add('Invalid schema version: ${embedding.schemaVersion}');
    }

    // Vector validation
    if (embedding.vector.isEmpty) {
      errors.add('Vector cannot be empty');
    }
    if (embedding.dim != embedding.vector.length) {
      errors.add('Vector dimension mismatch: expected ${embedding.dim}, got ${embedding.vector.length}');
    }

    // Check for NaN or infinite values
    for (int i = 0; i < embedding.vector.length; i++) {
      final value = embedding.vector[i];
      if (value.isNaN) {
        errors.add('Vector contains NaN at index $i');
      }
      if (value.isInfinite) {
        errors.add('Vector contains infinite value at index $i');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validate a complete MCP bundle
  static Future<ValidationResult> validateBundle(Directory bundleDir) async {
    final errors = <String>[];

    // Check required files exist
    final requiredFiles = [
      'manifest.json',
      'nodes.jsonl',
      'edges.jsonl',
      'pointers.jsonl',
      'embeddings.jsonl',
    ];

    for (final filename in requiredFiles) {
      final file = File('${bundleDir.path}/$filename');
      if (!await file.exists()) {
        errors.add('Required file missing: $filename');
      }
    }

    if (errors.isNotEmpty) {
      return ValidationResult(isValid: false, errors: errors);
    }

    // Validate manifest
    final manifestFile = File('${bundleDir.path}/manifest.json');
    if (!await McpManifestBuilder.validateManifest(manifestFile)) {
      errors.add('Invalid manifest.json');
    }

    // Validate NDJSON files
    final ndjsonFiles = {
      'nodes': File('${bundleDir.path}/nodes.jsonl'),
      'edges': File('${bundleDir.path}/edges.jsonl'),
      'pointers': File('${bundleDir.path}/pointers.jsonl'),
      'embeddings': File('${bundleDir.path}/embeddings.jsonl'),
    };

    for (final entry in ndjsonFiles.entries) {
      if (!await McpNdjsonWriter.validateNdjsonFile(entry.value)) {
        errors.add('Invalid NDJSON file: ${entry.key}');
      }
    }

    // Verify checksums if manifest is valid
    if (errors.isEmpty) {
      try {
        final manifest = await McpManifestBuilder.readManifest(manifestFile);
        if (!await McpManifestBuilder.verifyChecksums(manifest, ndjsonFiles)) {
          errors.add('Checksum verification failed');
        }
      } catch (e) {
        errors.add('Failed to verify checksums: $e');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validate SAGE narrative mapping
  static ValidationResult validateSageMapping(McpNarrative narrative) {
    final errors = <String>[];

    // At least one SAGE field should be present
    if (narrative.situation == null && 
        narrative.action == null && 
        narrative.growth == null && 
        narrative.essence == null) {
      errors.add('At least one SAGE field must be present');
    }

    // Check for empty strings
    if (narrative.situation?.isEmpty == true) {
      errors.add('Situation cannot be empty string');
    }
    if (narrative.action?.isEmpty == true) {
      errors.add('Action cannot be empty string');
    }
    if (narrative.growth?.isEmpty == true) {
      errors.add('Growth cannot be empty string');
    }
    if (narrative.essence?.isEmpty == true) {
      errors.add('Essence cannot be empty string');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validate UTC timestamp
  static bool isValidUtcTimestamp(DateTime timestamp) {
    return timestamp.isUtc;
  }

  /// Validate content hash format (SHA-256)
  static bool isValidContentHash(String hash) {
    final regex = RegExp(r'^[a-f0-9]{64}$');
    return regex.hasMatch(hash);
  }

  /// Validate CAS URI format
  static bool isValidCasUri(String uri) {
    final regex = RegExp(r'^cas://sha256/[a-f0-9]{64}$');
    return regex.hasMatch(uri);
  }
}

/// Validation result container
class ValidationResult {
  final bool isValid;
  final List<String> errors;

  const ValidationResult({
    required this.isValid,
    required this.errors,
  });

  @override
  String toString() {
    if (isValid) {
      return 'Validation passed';
    } else {
      return 'Validation failed:\n${errors.join('\n')}';
    }
  }
}

/// MCP Guardrails
class McpGuardrails {
  /// Enforce append-only semantics
  static bool isAppendOnly(List<McpNode> existingNodes, List<McpNode> newNodes) {
    final existingIds = existingNodes.map((n) => n.id).toSet();
    final newIds = newNodes.map((n) => n.id).toSet();
    
    // No overlapping IDs allowed
    return existingIds.intersection(newIds).isEmpty;
  }

  /// Enforce deterministic pointer structure
  static bool isDeterministicPointer(McpPointer pointer) {
    // Check that all required fields are present and non-null
    return pointer.id.isNotEmpty &&
           pointer.mediaType.isNotEmpty &&
           pointer.descriptor.metadata.isNotEmpty &&
           pointer.samplingManifest.metadata.isNotEmpty &&
           pointer.integrity.contentHash.isNotEmpty &&
           pointer.provenance.source.isNotEmpty &&
           pointer.privacy.sharingPolicy.isNotEmpty;
  }

  /// Enforce privacy propagation
  static bool hasPrivacyPropagation(McpPointer pointer) {
    // Check that privacy fields are properly set
    return pointer.privacy.sharingPolicy.isNotEmpty &&
           (pointer.privacy.containsPii || 
            pointer.privacy.facesDetected || 
            pointer.privacy.locationPrecision != null);
  }

  /// Enforce no raw dependency
  static bool hasNoRawDependency(McpPointer pointer) {
    // Bundle should be valid even if source_uri is unavailable
    return pointer.descriptor.metadata.isNotEmpty &&
           pointer.samplingManifest.metadata.isNotEmpty;
  }

  /// Enforce encoder provenance
  static bool hasEncoderProvenance(McpEmbedding embedding) {
    return embedding.modelId.isNotEmpty &&
           embedding.embeddingVersion.isNotEmpty &&
           embedding.dim > 0;
  }
}

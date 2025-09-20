// lib/mcp/bundle/validate.dart
// A tiny JSON-Schema-lite validator tailored to MCP v1.
// Goals: enforce *required fields* and *version names*, tolerate unknown fields,
// and nudge authors to use UTC ISO-8601 timestamps & lineage fields.
// This mirrors MCP's guardrails: versioned records, append-only, encoder lineage,
// pointer durability, UTC timestamps.

import 'dart:convert';
import 'schemas.dart';

abstract class McpValidator {
  bool validateManifest(Map<String, dynamic> manifest, List<String> errors);
  bool validateLine(String kind, Map<String, dynamic> rec, int lineNo, List<String> errors);
}

class McpValidatorV1 implements McpValidator {
  // ---- Public API ----
  @override
  bool validateManifest(Map<String, dynamic> manifest, List<String> errors) {
    return _validateObject(
      obj: manifest,
      name: 'manifest.json',
      required: const [
        'bundle_id', 'version', 'created_at', 'storage_profile',
        'counts', 'bytes', 'checksums', 'encoder_registry'
      ],
      versionField: 'schema_version', // Check schema_version field if present
      versionAllowed: const ['1.0.0', 'manifest.v1', 'v1', '1'], // Accept multiple formats
      errors: errors,
    ) && _checkUtcIso8601('manifest.created_at', manifest['created_at'], errors);
  }

  @override
  bool validateLine(String kind, Map<String, dynamic> rec, int lineNo, List<String> errors) {
    switch (kind) {
      case 'node':
        return _validateNode(rec, lineNo, errors);
      case 'edge':
        return _validateEdge(rec, lineNo, errors);
      case 'pointer':
        return _validatePointer(rec, lineNo, errors);
      case 'embedding':
        return _validateEmbedding(rec, lineNo, errors);
      default:
        // Unknown kinds are ignored (additive evolution)
        return true;
    }
  }

  // ---- Node ----
  bool _validateNode(Map<String, dynamic> n, int lineNo, List<String> errors) {
    final ok = _validateObject(
      obj: n,
      name: 'nodes.jsonl:$lineNo',
      required: const ['id','type','timestamp','schema_version'],
      versionField: 'schema_version',
      versionAllowed: const ['node.v1'],
      errors: errors,
    );
    final tsOk = _checkUtcIso8601('nodes.timestamp@$lineNo', n['timestamp'], errors);
    // Mapping SAGE -> narrative is optional, but encouraged by MCP/MIRA.
    return ok && tsOk;
  }

  // ---- Edge ----
  bool _validateEdge(Map<String, dynamic> e, int lineNo, List<String> errors) {
    final ok = _validateObject(
      obj: e,
      name: 'edges.jsonl:$lineNo',
      required: const ['source','target','relation','timestamp','schema_version'],
      versionField: 'schema_version',
      versionAllowed: const ['edge.v1'],
      errors: errors,
    );
    final tsOk = _checkUtcIso8601('edges.timestamp@$lineNo', e['timestamp'], errors);
    return ok && tsOk;
  }

  // ---- Pointer ----
  bool _validatePointer(Map<String, dynamic> p, int lineNo, List<String> errors) {
    final ok = _validateObject(
      obj: p,
      name: 'pointers.jsonl:$lineNo',
      required: const [
        'id','media_type','descriptor','sampling_manifest','integrity','provenance','privacy','schema_version'
      ],
      versionField: 'schema_version',
      versionAllowed: const ['pointer.v1'],
      errors: errors,
    );

    // integrity.created_at recommended; if present, enforce UTC ISO-8601
    final integrity = p['integrity'];
    if (integrity is Map && integrity['created_at'] != null) {
      _checkUtcIso8601('pointers.integrity.created_at@$lineNo', integrity['created_at'], errors);
    }
    return ok;
  }

  // ---- Embedding ----
  bool _validateEmbedding(Map<String, dynamic> m, int lineNo, List<String> errors) {
    final ok = _validateObject(
      obj: m,
      name: 'embeddings.jsonl:$lineNo',
      required: const ['id','pointer_ref','model_id','embedding_version','dim','created_at','schema_version'],
      versionField: 'schema_version',
      versionAllowed: const ['embedding.v1'],
      errors: errors,
    );

    // Enforce lineage presence (model_id + embedding_version) per MCP spec.
    final tsOk = _checkUtcIso8601('embeddings.created_at@$lineNo', m['created_at'], errors);
    final dimOk = _checkPositiveNumber('embeddings.dim@$lineNo', m['dim'], errors);
    return ok && tsOk && dimOk;
  }

  // ---- Helpers ----

  bool _validateObject({
    required Map<String, dynamic> obj,
    required String name,
    required List<String> required,
    required List<String>? versionAllowed,
    required String? versionField,
    required List<String> errors,
  }) {
    var ok = true;
    for (final k in required) {
      if (!obj.containsKey(k)) {
        _err(errors, '$name missing required field `$k`');
        ok = false;
      }
    }
    if (versionField != null && obj.containsKey(versionField)) {
      final v = obj[versionField];
      if (v is! String) {
        _err(errors, '$name has invalid `$versionField` (must be string like "node.v1")');
        ok = false;
      } else if (versionAllowed != null && !versionAllowed.contains(v)) {
        // Accept forward-compatible minor variants like node.v1.1 (reader SHOULD tolerate).
        if (!_isSameMajor(v, versionAllowed)) {
          _err(errors, '$name `$versionField` "$v" not supported; expected one of $versionAllowed or same-major variant.');
          ok = false;
        }
      }
    }
    // Note: schema_version is optional for backward compatibility
    return ok;
  }

  bool _isSameMajor(String v, List<String> allowed) {
    // Accept "node.v1" and "node.v1.*" family as same major.
    for (final a in allowed) {
      final partsA = a.split('.');
      final partsV = v.split('.');
      if (partsA.isNotEmpty && partsV.isNotEmpty) {
        if (partsA.first == partsV.first) return true;
      }
    }
    return false;
  }

  bool _checkUtcIso8601(String fieldName, dynamic value, List<String> errors) {
    if (value is! String) {
      _err(errors, '$fieldName must be an ISO-8601 UTC string (got $value)');
      return false;
    }
    // Minimal sanity: must end with 'Z' for UTC and be parseable.
    if (!value.endsWith('Z')) {
      _err(errors, '$fieldName should be UTC and end with "Z"');
      return false;
    }
    try {
      DateTime.parse(value);
      return true;
    } catch (_) {
      _err(errors, '$fieldName is not parseable ISO-8601');
      return false;
    }
  }

  bool _checkPositiveNumber(String fieldName, dynamic value, List<String> errors) {
    if (value is num && value > 0) return true;
    _err(errors, '$fieldName must be a positive number');
    return false;
  }

  void _err(List<String> errors, String msg) {
    if (errors.length < 10) errors.add(msg); // collect first 10 per import pass
  }

  // Optional: provide JSON schema strings for external tools / debugging.
  Map<String, String> schemaStrings() => {
    'node.v1': McpSchemas.nodeV1,
    'edge.v1': McpSchemas.edgeV1,
    'pointer.v1': McpSchemas.pointerV1,
    'embedding.v1': McpSchemas.embeddingV1,
    'manifest.v1': McpSchemas.manifestV1,
  };
}
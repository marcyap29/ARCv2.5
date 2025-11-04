// lib/mcp/bundle/schemas.dart
// Minimal embedded JSON Schemas (strings) for MCP v1 record types.
// These are intentionally small and permissive. Readers MUST accept unknown
// fields (additive evolution) and only require the minimal set.

class McpSchemas {
  static const String nodeV1 = r'''
{
  "title": "node.v1",
  "type": "object",
  "required": ["id","type","timestamp","schema_version"],
  "properties": {
    "id": {"type":"string"},
    "type": {"type":"string"},
    "timestamp": {"type":"string"},
    "phase_hint": {"type":"string"},
    "narrative": {
      "type":"object",
      "properties": {
        "situation":{"type":"string"},
        "action":{"type":"string"},
        "growth":{"type":"string"},
        "essence":{"type":"string"}
      },
      "additionalProperties": true
    },
    "keywords": {"type":"array"},
    "emotions": {"type":"object"},
    "pointer_ref": {"type":"string"},
    "embedding_ref": {"type":"string"},
    "provenance": {"type":"object"},
    "schema_version": {"type":"string"}
  },
  "additionalProperties": true
}
''';

  static const String edgeV1 = r'''
{
  "title": "edge.v1",
  "type": "object",
  "required": ["source","target","relation","timestamp","schema_version"],
  "properties": {
    "source":{"type":"string"},
    "target":{"type":"string"},
    "relation":{"type":"string"},
    "timestamp":{"type":"string"},
    "schema_version":{"type":"string"}
  },
  "additionalProperties": true
}
''';

  static const String pointerV1 = r'''
{
  "title": "pointer.v1",
  "type": "object",
  "required": ["id","media_type","descriptor","sampling_manifest","integrity","provenance","privacy","schema_version"],
  "properties": {
    "id":{"type":"string"},
    "media_type":{"type":"string"},
    "source_uri":{"type":"string"},
    "alt_uris":{"type":"array"},
    "descriptor":{"type":"object"},
    "sampling_manifest":{"type":"object"},
    "integrity":{"type":"object"},
    "provenance":{"type":"object"},
    "privacy":{"type":"object"},
    "labels":{"type":"array"},
    "schema_version":{"type":"string"}
  },
  "additionalProperties": true
}
''';

  static const String embeddingV1 = r'''
{
  "title": "embedding.v1",
  "type": "object",
  "required": ["id","pointer_ref","model_id","embedding_version","dim","created_at","schema_version"],
  "properties": {
    "id":{"type":"string"},
    "pointer_ref":{"type":"string"},
    "span_ref":{"type":"string"},
    "model_id":{"type":"string"},
    "embedding_version":{"type":"string"},
    "dim":{"type":"number"},
    "created_at":{"type":"string"},
    "schema_version":{"type":"string"}
  },
  "additionalProperties": true
}
''';

  static const String manifestV1 = r'''
{
  "title": "manifest.v1",
  "type": "object",
  "required": ["bundle_id","version","created_at","storage_profile","counts","bytes","checksums","encoder_registry"],
  "properties": {
    "bundle_id":{"type":"string"},
    "version":{"type":"string"},
    "created_at":{"type":"string"},
    "storage_profile":{"type":"string"},
    "counts":{"type":"object"},
    "bytes":{"type":"object"},
    "checksums":{"type":"object"},
    "encoder_registry":{"type":"array"},
    "cas_remotes":{"type":"array"},
    "notes":{"type":"string"}
  },
  "additionalProperties": true
}
''';
}
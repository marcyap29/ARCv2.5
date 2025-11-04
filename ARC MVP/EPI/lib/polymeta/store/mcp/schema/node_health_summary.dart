class NodeHealthSummaryV1 {
  final String id; // "node_health_sleep_<yyyymmdd>"
  final String type; // "health_summary"
  final DateTime timestamp;
  final String contentSummary; // short human-readable summary
  final List<String> keywords; // e.g. ["sleep","recovery"]
  final String pointerRef; // PointerHealthV1.id
  final String? embeddingRef; // optional
  final Map<String, dynamic> provenance; // {"source":"PRISM-VITAL"}
  final String schemaVersion; // "node.v1"

  const NodeHealthSummaryV1({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.contentSummary,
    required this.keywords,
    required this.pointerRef,
    this.embeddingRef,
    required this.provenance,
    required this.schemaVersion,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'content_summary': contentSummary,
        'keywords': List<String>.from(keywords)..sort(),
        'pointer_ref': pointerRef,
        if (embeddingRef != null) 'embedding_ref': embeddingRef,
        'provenance': _sorted(provenance),
        'schema_version': schemaVersion,
      };
}

Map<String, dynamic> _sorted(Map input) {
  final keys = input.keys.map((e) => e.toString()).toList()..sort();
  final out = <String, dynamic>{};
  for (final k in keys) {
    final v = input[k];
    if (v is Map) {
      out[k] = _sorted(v);
    } else if (v is List) {
      out[k] = v.map((e) => e is Map ? _sorted(e) : e).toList();
    } else {
      out[k] = v;
    }
  }
  return out;
}



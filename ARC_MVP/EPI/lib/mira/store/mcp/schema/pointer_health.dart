import 'dart:convert';

class VitalWindow {
  final String windowId;
  final DateTime start;
  final DateTime end;
  final Map<String, dynamic> summary; // e.g., {avg_hr, sleep_efficiency, deep_sleep_ratio}
  final String? embeddingRef;

  const VitalWindow({
    required this.windowId,
    required this.start,
    required this.end,
    required this.summary,
    this.embeddingRef,
  });

  Map<String, dynamic> toJson() => {
        'window_id': windowId,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'summary': _sorted(summary),
        if (embeddingRef != null) 'embedding_ref': embeddingRef,
      };
}

class PointerHealthV1 {
  final String id; // "ptr_health_<yyyymmdd>"
  final String mediaType; // "health"
  final Map<String, String> unitMap; // {"heart_rate":"bpm","steps":"count","hrv":"ms"}
  final String interval; // "1h" or "1d"
  final List<VitalWindow> windows; // aggregated buckets
  final DateTime createdAt;
  final String contentHash; // sha256 over canonicalized JSON body
  final Map<String, String> provenance; // device model, os version, sanitized
  final Map<String, dynamic> privacy; // contains_pii=false, sharing_policy
  final String schemaVersion; // "pointer.v1"

  const PointerHealthV1({
    required this.id,
    required this.mediaType,
    required this.unitMap,
    required this.interval,
    required this.windows,
    required this.createdAt,
    required this.contentHash,
    required this.provenance,
    required this.privacy,
    required this.schemaVersion,
  });

  Map<String, dynamic> toJson() => _sorted({
        'id': id,
        'media_type': mediaType,
        'descriptor': _sorted({
          'interval': interval,
          'unit_map': _sorted(unitMap),
        }),
        'sampling_manifest': _sorted({
          'windows': windows.map((w) => w.toJson()).toList(),
        }),
        'integrity': _sorted({'content_hash': contentHash}),
        'created_at': createdAt.toUtc().toIso8601String(),
        'provenance': _sorted(provenance),
        'privacy': _sorted(privacy),
        'schema_version': schemaVersion,
      });
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

String canonicalJson(Map<String, dynamic> json) {
  return const JsonEncoder.withIndent('').convert(_sorted(json));
}



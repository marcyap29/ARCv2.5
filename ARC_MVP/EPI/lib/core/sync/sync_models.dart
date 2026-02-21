enum SyncState { queued, syncing, failed, done }

enum SyncKind { journalEntry, arcformSnapshot, settings }

class SyncItem {
  final String id;            // uuid
  final SyncKind kind;
  final String refId;         // e.g., entryId
  final DateTime createdAt;
  final int retries;
  final SyncState state;      // start as queued
  final Map<String, dynamic> payload; // compact summary (no PII beyond needed IDs)

  SyncItem({
    required this.id,
    required this.kind,
    required this.refId,
    required this.createdAt,
    this.retries = 0,
    this.state = SyncState.queued,
    required this.payload,
  });

  SyncItem copyWith({
    String? id,
    SyncKind? kind,
    String? refId,
    DateTime? createdAt,
    int? retries,
    SyncState? state,
    Map<String, dynamic>? payload,
  }) {
    return SyncItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      refId: refId ?? this.refId,
      createdAt: createdAt ?? this.createdAt,
      retries: retries ?? this.retries,
      state: state ?? this.state,
      payload: payload ?? this.payload,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      'refId': refId,
      'createdAt': createdAt.toIso8601String(),
      'retries': retries,
      'state': state.name,
      'payload': payload,
    };
  }

  factory SyncItem.fromJson(Map<String, dynamic> json) {
    return SyncItem(
      id: json['id'] as String,
      kind: SyncKind.values.firstWhere((e) => e.name == json['kind']),
      refId: json['refId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retries: json['retries'] as int,
      state: SyncState.values.firstWhere((e) => e.name == json['state']),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
    );
  }
}

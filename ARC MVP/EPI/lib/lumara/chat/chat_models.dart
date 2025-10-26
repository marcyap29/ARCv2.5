// lib/lumara/chat/chat_models.dart
// Chat models for LUMARA chat system

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'chat_models.g.dart';

const _uuid = Uuid();

// Role constants for chat messages
class MessageRole {
  static const String user = 'user';
  static const String assistant = 'assistant';
  static const String system = 'system';
}

@HiveType(typeId: 70)
class ChatMessage extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String sessionId;

  @HiveField(2)
  final String role;

  @HiveField(3)
  final String textContent;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final String? originalTextHash;

  @HiveField(6)
  final String? provenance;

  @HiveField(7)
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.textContent,
    required this.createdAt,
    this.originalTextHash,
    this.provenance,
    this.metadata,
  });

  // Factory methods
  factory ChatMessage.createText({
    required String sessionId,
    required String role,
    required String content,
    String? provenance,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: _uuid.v4(),
      sessionId: sessionId,
      role: role,
      textContent: content,
      createdAt: DateTime.now(),
      provenance: provenance,
      metadata: metadata,
    );
  }

  factory ChatMessage.createLegacy({
    required String sessionId,
    required String role,
    required String content,
  }) {
    return ChatMessage(
      id: _uuid.v4(),
      sessionId: sessionId,
      role: role,
      textContent: content,
      createdAt: DateTime.now(),
    );
  }

  static bool isValidRole(String role) {
    return role == MessageRole.user ||
        role == MessageRole.assistant ||
        role == MessageRole.system;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      role: json['role'] as String,
      textContent: json['textContent'] as String,
      createdAt: DateTime.parse(json['createdAt']),
      originalTextHash: json['originalTextHash'] as String?,
      provenance: json['provenance'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'role': role,
      'textContent': textContent,
      'createdAt': createdAt.toIso8601String(),
      'originalTextHash': originalTextHash,
      'provenance': provenance,
      'metadata': metadata,
    };
  }
}

@HiveType(typeId: 71)
class ChatSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String subject;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final DateTime updatedAt;

  @HiveField(4)
  final bool isPinned;

  @HiveField(5)
  final bool isArchived;

  @HiveField(6)
  final DateTime? archivedAt;

  @HiveField(7)
  final List<String> tags;

  @HiveField(8)
  final int messageCount;

  @HiveField(9)
  final String? retention;

  @HiveField(10)
  final Map<String, dynamic>? metadata;

  ChatSession({
    required this.id,
    required this.subject,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.isArchived = false,
    this.archivedAt,
    List<String>? tags,
    this.messageCount = 0,
    this.retention,
    this.metadata,
  }) : tags = tags ?? [];

  // Factory method to create a new session
  factory ChatSession.create({
    required String subject,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    return ChatSession(
      id: _uuid.v4(),
      subject: subject,
      createdAt: now,
      updatedAt: now,
      tags: tags,
      metadata: metadata,
    );
  }

  // CopyWith method for updates
  ChatSession copyWith({
    String? subject,
    DateTime? updatedAt,
    bool? isPinned,
    bool? isArchived,
    DateTime? archivedAt,
    List<String>? tags,
    int? messageCount,
    String? retention,
    Map<String, dynamic>? metadata,
  }) {
    return ChatSession(
      id: id,
      subject: subject ?? this.subject,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      tags: tags ?? this.tags,
      messageCount: messageCount ?? this.messageCount,
      retention: retention ?? this.retention,
      metadata: metadata ?? this.metadata,
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      subject: json['subject'] as String,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isPinned: json['isPinned'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      archivedAt: json['archivedAt'] != null
          ? DateTime.parse(json['archivedAt'])
          : null,
      tags: json['tags'] != null
          ? (json['tags'] as List).cast<String>()
          : null,
      messageCount: json['messageCount'] as int? ?? 0,
      retention: json['retention'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPinned': isPinned,
      'isArchived': isArchived,
      'archivedAt': archivedAt?.toIso8601String(),
      'tags': tags.toList(),
      'messageCount': messageCount,
      'retention': retention,
      'metadata': metadata,
    };
  }
}
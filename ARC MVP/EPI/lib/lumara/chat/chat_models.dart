import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'ulid.dart';
import 'content_parts.dart';

part 'chat_models.g.dart';

/// Represents a chat session with LUMARA
@HiveType(typeId: 70)
class ChatSession extends Equatable {
  @HiveField(0)
  final String id; // ULID, stable

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
  final String retention; // "auto-archive-30d" | "pinned" | "manual"

  const ChatSession({
    required this.id,
    required this.subject,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.isArchived = false,
    this.archivedAt,
    this.tags = const [],
    this.messageCount = 0,
    this.retention = "auto-archive-30d",
  });

  /// Create a new chat session with generated ID
  factory ChatSession.create({
    required String subject,
    List<String> tags = const [],
  }) {
    final now = DateTime.now();
    return ChatSession(
      id: ULID.generate(),
      subject: subject,
      createdAt: now,
      updatedAt: now,
      tags: tags,
    );
  }

  /// Generate subject from first user message
  static String generateSubject(String firstMessage) {
    // Take first 8-12 words, trim punctuation
    final words = firstMessage
        .trim()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(10)
        .toList();

    if (words.isEmpty) {
      return 'New chat';
    }

    String subject = words.join(' ');
    if (subject.length > 50) {
      subject = '${subject.substring(0, 47)}...';
    }

    return subject;
  }

  ChatSession copyWith({
    String? subject,
    DateTime? updatedAt,
    bool? isPinned,
    bool? isArchived,
    DateTime? archivedAt,
    List<String>? tags,
    int? messageCount,
    String? retention,
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
    );
  }

  @override
  List<Object?> get props => [
        id,
        subject,
        createdAt,
        updatedAt,
        isPinned,
        isArchived,
        archivedAt,
        tags,
        messageCount,
        retention,
      ];
}

/// Represents a single message in a chat session
@HiveType(typeId: 71)
class ChatMessage extends Equatable {
  @HiveField(0)
  final String id; // ULID with msg: prefix

  @HiveField(1)
  final String sessionId; // ULID

  @HiveField(2)
  final String role; // 'user' | 'assistant' | 'system'

  @HiveField(3)
  final List<ContentPart> contentParts; // multimodal content

  @HiveField(4)
  final DateTime createdAt; // ISO 8601 UTC

  @HiveField(5)
  final String? originalTextHash; // for audit if content was redacted

  @HiveField(6)
  final Map<String, dynamic>? provenance; // device, appVersion, etc.

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.contentParts,
    required this.createdAt,
    this.originalTextHash,
    this.provenance,
  });

  /// Create a new chat message with generated ID
  factory ChatMessage.create({
    required String sessionId,
    required String role,
    required List<ContentPart> contentParts,
    String? originalTextHash,
    Map<String, dynamic>? provenance,
  }) {
    return ChatMessage(
      id: 'msg:${ULID.generate()}',
      sessionId: sessionId,
      role: role,
      contentParts: contentParts,
      createdAt: DateTime.now().toUtc(),
      originalTextHash: originalTextHash,
      provenance: provenance,
    );
  }

  /// Create a text-only message (legacy compatibility)
  factory ChatMessage.createText({
    required String sessionId,
    required String role,
    required String text,
    String? originalTextHash,
    Map<String, dynamic>? provenance,
  }) {
    return ChatMessage.create(
      sessionId: sessionId,
      role: role,
      contentParts: ContentPartUtils.fromLegacyContent(text),
      originalTextHash: originalTextHash,
      provenance: provenance,
    );
  }

  /// Legacy constructor for backward compatibility
  factory ChatMessage.createLegacy({
    required String id,
    required String sessionId,
    required String role,
    required String content,
    required DateTime createdAt,
    String? originalTextHash,
  }) {
    return ChatMessage(
      id: id,
      sessionId: sessionId,
      role: role,
      contentParts: ContentPartUtils.fromLegacyContent(content),
      createdAt: createdAt,
      originalTextHash: originalTextHash,
    );
  }

  /// Get text content from content parts
  String get textContent => ContentPartUtils.extractText(contentParts);

  /// Legacy compatibility: Get content as string (for backward compatibility)
  String get content => textContent;

  /// Check if message has media
  bool get hasMedia => ContentPartUtils.hasMedia(contentParts);

  /// Check if message has PRISM analysis
  bool get hasPrismAnalysis => ContentPartUtils.hasPrismAnalysis(contentParts);

  /// Get all media pointers
  List<MediaPointer> get mediaPointers => ContentPartUtils.getMediaPointers(contentParts);

  /// Get all PRISM summaries
  List<PrismSummary> get prismSummaries => ContentPartUtils.getPrismSummaries(contentParts);

  /// Validate message role
  static bool isValidRole(String role) {
    return ['user', 'assistant', 'system'].contains(role);
  }

  @override
  List<Object?> get props => [
        id,
        sessionId,
        role,
        contentParts,
        createdAt,
        originalTextHash,
        provenance,
      ];
}

/// Message role constants
class MessageRole {
  static const String user = 'user';
  static const String assistant = 'assistant';
  static const String system = 'system';
}
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'ulid.dart';

part 'chat_models.g.dart';

/// Represents a chat session with LUMARA
@HiveType(typeId: 20)
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
      ];
}

/// Represents a single message in a chat session
@HiveType(typeId: 21)
class ChatMessage extends Equatable {
  @HiveField(0)
  final String id; // ULID

  @HiveField(1)
  final String sessionId; // ULID

  @HiveField(2)
  final String role; // 'user' | 'assistant' | 'system'

  @HiveField(3)
  final String content; // redacted text if privacy rule applied

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final String? originalTextHash; // for audit if content was redacted

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.originalTextHash,
  });

  /// Create a new chat message with generated ID
  factory ChatMessage.create({
    required String sessionId,
    required String role,
    required String content,
    String? originalTextHash,
  }) {
    return ChatMessage(
      id: ULID.generate(),
      sessionId: sessionId,
      role: role,
      content: content,
      createdAt: DateTime.now(),
      originalTextHash: originalTextHash,
    );
  }

  /// Validate message role
  static bool isValidRole(String role) {
    return ['user', 'assistant', 'system'].contains(role);
  }

  @override
  List<Object?> get props => [
        id,
        sessionId,
        role,
        content,
        createdAt,
        originalTextHash,
      ];
}

/// Message role constants
class MessageRole {
  static const String user = 'user';
  static const String assistant = 'assistant';
  static const String system = 'system';
}
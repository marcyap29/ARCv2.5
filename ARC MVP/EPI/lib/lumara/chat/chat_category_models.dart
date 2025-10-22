import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'ulid.dart';
import 'chat_models.dart';

part 'chat_category_models.g.dart';

/// Represents a category for organizing chat sessions
@HiveType(typeId: 72)
class ChatCategory extends Equatable {
  @HiveField(0)
  final String id; // ULID, stable

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final String color; // Hex color code

  @HiveField(4)
  final String icon; // Material icon name

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime updatedAt;

  @HiveField(7)
  final int sessionCount;

  @HiveField(8)
  final bool isDefault; // System-created categories

  @HiveField(9)
  final int sortOrder; // For custom ordering

  const ChatCategory({
    required this.id,
    required this.name,
    this.description,
    required this.color,
    required this.icon,
    required this.createdAt,
    required this.updatedAt,
    this.sessionCount = 0,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  /// Create a new chat category with generated ID
  factory ChatCategory.create({
    required String name,
    String? description,
    required String color,
    required String icon,
    int sortOrder = 0,
  }) {
    final now = DateTime.now();
    return ChatCategory(
      id: ULID.generate(),
      name: name,
      description: description,
      color: color,
      icon: icon,
      createdAt: now,
      updatedAt: now,
      sortOrder: sortOrder,
    );
  }

  /// Create default categories
  static List<ChatCategory> createDefaultCategories() {
    final now = DateTime.now();
    return [
      ChatCategory(
        id: 'cat:general',
        name: 'General',
        description: 'General conversations with LUMARA',
        color: '#2196F3',
        icon: 'chat',
        createdAt: now,
        updatedAt: now,
        isDefault: true,
        sortOrder: 0,
      ),
      ChatCategory(
        id: 'cat:reflection',
        name: 'Reflection',
        description: 'Deep reflection and introspection',
        color: '#9C27B0',
        icon: 'psychology',
        createdAt: now,
        updatedAt: now,
        isDefault: true,
        sortOrder: 1,
      ),
      ChatCategory(
        id: 'cat:planning',
        name: 'Planning',
        description: 'Goal setting and future planning',
        color: '#FF9800',
        icon: 'event_note',
        createdAt: now,
        updatedAt: now,
        isDefault: true,
        sortOrder: 2,
      ),
      ChatCategory(
        id: 'cat:learning',
        name: 'Learning',
        description: 'Educational discussions and knowledge sharing',
        color: '#4CAF50',
        icon: 'school',
        createdAt: now,
        updatedAt: now,
        isDefault: true,
        sortOrder: 3,
      ),
      ChatCategory(
        id: 'cat:creative',
        name: 'Creative',
        description: 'Creative writing and brainstorming',
        color: '#E91E63',
        icon: 'palette',
        createdAt: now,
        updatedAt: now,
        isDefault: true,
        sortOrder: 4,
      ),
    ];
  }

  ChatCategory copyWith({
    String? name,
    String? description,
    String? color,
    String? icon,
    DateTime? updatedAt,
    int? sessionCount,
    int? sortOrder,
  }) {
    return ChatCategory(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sessionCount: sessionCount ?? this.sessionCount,
      isDefault: isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        color,
        icon,
        createdAt,
        updatedAt,
        sessionCount,
        isDefault,
        sortOrder,
      ];
}

/// Represents the relationship between a chat session and a category
@HiveType(typeId: 73)
class ChatSessionCategory extends Equatable {
  @HiveField(0)
  final String sessionId;

  @HiveField(1)
  final String categoryId;

  @HiveField(2)
  final DateTime assignedAt;

  const ChatSessionCategory({
    required this.sessionId,
    required this.categoryId,
    required this.assignedAt,
  });

  @override
  List<Object?> get props => [sessionId, categoryId, assignedAt];
}

/// Chat export format for saving/importing chats
@HiveType(typeId: 74)
class ChatExportData extends Equatable {
  @HiveField(0)
  final String version; // Export format version

  @HiveField(1)
  final DateTime exportedAt;

  @HiveField(2)
  final String exportedBy; // App version

  @HiveField(3)
  final List<ChatSession> sessions;

  @HiveField(4)
  final List<ChatMessage> messages;

  @HiveField(5)
  final List<ChatCategory> categories;

  @HiveField(6)
  final List<ChatSessionCategory> sessionCategories;

  const ChatExportData({
    required this.version,
    required this.exportedAt,
    required this.exportedBy,
    required this.sessions,
    required this.messages,
    required this.categories,
    required this.sessionCategories,
  });

  /// Create export data from current state
  factory ChatExportData.create({
    required List<ChatSession> sessions,
    required List<ChatMessage> messages,
    required List<ChatCategory> categories,
    required List<ChatSessionCategory> sessionCategories,
  }) {
    return ChatExportData(
      version: '1.0',
      exportedAt: DateTime.now(),
      exportedBy: 'ARC EPI v1.0',
      sessions: sessions,
      messages: messages,
      categories: categories,
      sessionCategories: sessionCategories,
    );
  }

  @override
  List<Object?> get props => [
        version,
        exportedAt,
        exportedBy,
        sessions,
        messages,
        categories,
        sessionCategories,
      ];

  /// Convert to JSON for export (simplified version)
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'exportedBy': exportedBy,
      'sessions': sessions.map((s) => {
        'id': s.id,
        'subject': s.subject,
        'createdAt': s.createdAt.toIso8601String(),
        'updatedAt': s.updatedAt.toIso8601String(),
        'isPinned': s.isPinned,
        'isArchived': s.isArchived,
        'archivedAt': s.archivedAt?.toIso8601String(),
        'tags': s.tags,
        'messageCount': s.messageCount,
        'retention': s.retention,
      }).toList(),
      'messages': messages.map((m) => {
        'id': m.id,
        'sessionId': m.sessionId,
        'role': m.role,
        'content': m.textContent,
        'createdAt': m.createdAt.toIso8601String(),
        'originalTextHash': m.originalTextHash,
        'provenance': m.provenance,
      }).toList(),
      'categories': categories.map((c) => {
        'id': c.id,
        'name': c.name,
        'description': c.description,
        'color': c.color,
        'icon': c.icon,
        'createdAt': c.createdAt.toIso8601String(),
        'updatedAt': c.updatedAt.toIso8601String(),
        'sessionCount': c.sessionCount,
        'isDefault': c.isDefault,
        'sortOrder': c.sortOrder,
      }).toList(),
      'sessionCategories': sessionCategories.map((sc) => {
        'sessionId': sc.sessionId,
        'categoryId': sc.categoryId,
        'assignedAt': sc.assignedAt.toIso8601String(),
      }).toList(),
    };
  }

  /// Create from JSON for import (simplified version)
  factory ChatExportData.fromJson(Map<String, dynamic> json) {
    return ChatExportData(
      version: json['version'] as String,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      exportedBy: json['exportedBy'] as String,
      sessions: (json['sessions'] as List)
          .map((s) => ChatSession(
                id: s['id'] as String,
                subject: s['subject'] as String,
                createdAt: DateTime.parse(s['createdAt'] as String),
                updatedAt: DateTime.parse(s['updatedAt'] as String),
                isPinned: s['isPinned'] as bool? ?? false,
                isArchived: s['isArchived'] as bool? ?? false,
                archivedAt: s['archivedAt'] != null ? DateTime.parse(s['archivedAt'] as String) : null,
                tags: (s['tags'] as List?)?.cast<String>() ?? [],
                messageCount: s['messageCount'] as int? ?? 0,
                retention: s['retention'] as String? ?? 'auto-archive-30d',
              ))
          .toList(),
      messages: (json['messages'] as List)
          .map((m) => ChatMessage.createText(
                sessionId: m['sessionId'] as String,
                role: m['role'] as String,
                text: m['content'] as String,
                originalTextHash: m['originalTextHash'] as String?,
                provenance: m['provenance'] as Map<String, dynamic>?,
              ))
          .toList(),
      categories: (json['categories'] as List)
          .map((c) => ChatCategory(
                id: c['id'] as String,
                name: c['name'] as String,
                description: c['description'] as String?,
                color: c['color'] as String,
                icon: c['icon'] as String,
                createdAt: DateTime.parse(c['createdAt'] as String),
                updatedAt: DateTime.parse(c['updatedAt'] as String),
                sessionCount: c['sessionCount'] as int? ?? 0,
                isDefault: c['isDefault'] as bool? ?? false,
                sortOrder: c['sortOrder'] as int? ?? 0,
              ))
          .toList(),
      sessionCategories: (json['sessionCategories'] as List)
          .map((sc) => ChatSessionCategory(
                sessionId: sc['sessionId'] as String,
                categoryId: sc['categoryId'] as String,
                assignedAt: DateTime.parse(sc['assignedAt'] as String),
              ))
          .toList(),
    );
  }
}

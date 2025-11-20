import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:my_app/arc/chat/chat/chat_repo.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:my_app/arc/chat/chat/privacy_redactor.dart';
import 'package:my_app/arc/chat/chat/provenance_tracker.dart';
import 'package:my_app/mira/ingest/chat_ingest.dart';
import 'package:my_app/mira/graph/chat_graph_builder.dart';
import '../adapters/to_mcp.dart';

/// MCP exporter for chat sessions and messages
class ChatMcpExporter {
  final ChatRepo _chatRepo;
  final ChatPrivacyRedactor _privacyRedactor;
  final ChatProvenanceTracker _provenanceTracker;

  ChatMcpExporter(
    this._chatRepo, {
    ChatPrivacyRedactor? privacyRedactor,
    ChatProvenanceTracker? provenanceTracker,
  }) : _privacyRedactor = privacyRedactor ?? const ChatPrivacyRedactor(),
       _provenanceTracker = provenanceTracker ?? ChatProvenanceTracker.instance;

  /// Export chats to MCP format
  Future<Directory> exportChatsToMcp({
    required Directory outputDir,
    bool includeArchived = true,
    DateTime? since,
    DateTime? until,
    String profile = "monthly_chat_archive",
    String? notes,
  }) async {
    // Create output directory
    await outputDir.create(recursive: true);

    // Initialize files
    final nodesFile = File('${outputDir.path}/nodes.jsonl');
    final edgesFile = File('${outputDir.path}/edges.jsonl');
    final pointersFile = File('${outputDir.path}/pointers.jsonl');

    final nodesStream = nodesFile.openWrite();
    final edgesStream = edgesFile.openWrite();
    final pointersStream = pointersFile.openWrite();

    int nodeCount = 0;
    int edgeCount = 0;
    int pointerCount = 0;

    try {
      // Get sessions
      final sessions = await _chatRepo.listAll(includeArchived: includeArchived);

      // Filter by date if specified
      final filteredSessions = sessions.where((session) {
        if (since != null && session.createdAt.isBefore(since)) return false;
        if (until != null && session.createdAt.isAfter(until)) return false;
        return true;
      }).toList();

      print('ChatMcpExporter: Exporting ${filteredSessions.length} sessions to ${outputDir.path}');

      // Export each session
      for (final session in filteredSessions) {
        // Get messages for this session
        final messages = await _chatRepo.getMessages(session.id, lazy: false);

        // Create MIRA graph fragment
        final fragment = ChatGraphBuilder.fromSessions(
          [session],
          {session.id: messages},
        );

        // Export session node using MIRA adapter
        final sessionNode = ChatIngest.toSessionNode(session);
        final sessionMcp = MiraToMcpAdapter.nodeToMcp(sessionNode);
        if (sessionMcp != null) {
          nodesStream.writeln(jsonEncode(sessionMcp));
          nodeCount++;
        }

        // Export session pointer
        final sessionPointer = _createSessionPointer(session);
        pointersStream.writeln(jsonEncode(sessionPointer));
        pointerCount++;

        // Export message nodes using MIRA adapter
        for (final message in messages) {
          final messageNode = ChatIngest.toMessageNode(message);
          final messageMcp = MiraToMcpAdapter.nodeToMcp(messageNode);
          if (messageMcp != null) {
            nodesStream.writeln(jsonEncode(messageMcp));
            nodeCount++;
          }
        }

        // Export edges using MIRA adapter
        for (final edge in fragment.edges) {
          final edgeMcp = MiraToMcpAdapter.edgeToMcp(edge);
          if (edgeMcp != null) {
            edgesStream.writeln(jsonEncode(edgeMcp));
            edgeCount++;
          }
        }
      }

      await nodesStream.flush();
      await edgesStream.flush();
      await pointersStream.flush();

      // Create manifest
      await _createManifest(
        outputDir: outputDir,
        nodeCount: nodeCount,
        edgeCount: edgeCount,
        pointerCount: pointerCount,
        profile: profile,
        notes: notes,
      );

      print('ChatMcpExporter: Export complete - $nodeCount nodes, $edgeCount edges, $pointerCount pointers');

    } finally {
      await nodesStream.close();
      await edgesStream.close();
      await pointersStream.close();
    }

    return outputDir;
  }

  /// Create MCP node.v2 for chat session
  Map<String, dynamic> _createSessionNode(ChatSession session) {
    return {
      "kind": "node",
      "type": "ChatSession",
      "id": "session:${session.id}",
      "timestamp": session.createdAt.toUtc().toIso8601String(),
      "content": {"title": session.subject},
      "metadata": {
        "isArchived": session.isArchived,
        "archivedAt": session.archivedAt?.toUtc().toIso8601String(),
        "isPinned": session.isPinned,
        "tags": session.tags,
        "messageCount": session.messageCount,
        "retention": "auto-archive-30d",
        "createdAt": session.createdAt.toUtc().toIso8601String(),
        "updatedAt": session.updatedAt.toUtc().toIso8601String(),
      },
      "schema_version": "node.v2"
    };
  }

  /// Create MCP node.v2 for chat message
  Map<String, dynamic> _createMessageNode(ChatMessage message) {
    // Process content for privacy
    final privacyResult = _privacyRedactor.processContent(message.textContent);

    final node = {
      "kind": "node",
      "type": "ChatMessage",
      "id": "msg:${message.id}",
      "timestamp": message.createdAt.toUtc().toIso8601String(),
      "content": {
        "mime": "text/plain",
        "text": privacyResult.content,
      },
      "metadata": {
        "role": message.role,
        "sessionId": message.sessionId,
      },
      "schema_version": "node.v2"
    };

    // Add privacy metadata if PII was detected
    if (privacyResult.containsPii) {
      final metadata = node["metadata"] as Map<String, dynamic>;
      metadata["privacy"] = privacyResult.getPrivacyMetadata();
    }

    return node;
  }

  /// Create MCP edge.v1 for contains relationship
  Map<String, dynamic> _createContainsEdge(String sessionId, String messageId, DateTime timestamp, int order) {
    return {
      "kind": "edge",
      "source": "session:$sessionId",
      "target": "msg:$messageId",
      "relation": "contains",
      "timestamp": timestamp.toUtc().toIso8601String(),
      "schema_version": "edge.v1",
      "metadata": {"order": order}
    };
  }

  /// Create MCP pointer for chat session
  Map<String, dynamic> _createSessionPointer(ChatSession session) {
    return {
      "kind": "pointer",
      "type": "ChatSession",
      "ref": "session:${session.id}",
      "title": session.subject,
      "metadata": {
        "isArchived": session.isArchived,
        "isPinned": session.isPinned,
        "messageCount": session.messageCount,
        "tags": session.tags,
      }
    };
  }

  /// Create MCP manifest with checksums
  Future<void> _createManifest({
    required Directory outputDir,
    required int nodeCount,
    required int edgeCount,
    required int pointerCount,
    required String profile,
    String? notes,
  }) async {
    // Calculate file checksums
    final nodesFile = File('${outputDir.path}/nodes.jsonl');
    final edgesFile = File('${outputDir.path}/edges.jsonl');
    final pointersFile = File('${outputDir.path}/pointers.jsonl');

    final nodesChecksum = await _calculateSha256(nodesFile);
    final edgesChecksum = await _calculateSha256(edgesFile);
    final pointersChecksum = await _calculateSha256(pointersFile);

    // Get provenance information
    final provenance = await _provenanceTracker.getProvenanceMetadata();

    final manifest = {
      "bundle_id": "mcp_chats_${DateTime.now().toUtc().toIso8601String().substring(0, 7)}",
      "version": "1.0.0",
      "schema_version": "1.0.0",
      "created_at": DateTime.now().toUtc().toIso8601String(),
      "profile": profile,
      "provenance": provenance,
      "files": {
        "nodes_jsonl": {
          "path": "nodes.jsonl",
          "records": nodeCount,
          "checksum": "sha256:$nodesChecksum"
        },
        "edges_jsonl": {
          "path": "edges.jsonl",
          "records": edgeCount,
          "checksum": "sha256:$edgesChecksum"
        },
        "pointers_jsonl": {
          "path": "pointers.jsonl",
          "records": pointerCount,
          "checksum": "sha256:$pointersChecksum"
        }
      },
      "schemas": {
        "node_v2": "schemas/node.v2.json",
        "chat_session_v1": "schemas/chat_session.v1.json",
        "chat_message_v1": "schemas/chat_message.v1.json",
        "edge_v1": "schemas/edge.v1.json"
      },
      "privacy": {
        "redaction_enabled": _privacyRedactor.enabled,
        "pii_detection_enabled": true,
      },
      "notes": notes ?? "Includes active and archived chat sessions. Retention policy: auto-archive-30d."
    };

    final manifestFile = File('${outputDir.path}/manifest.json');
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest)
    );
  }

  /// Calculate SHA-256 checksum of a file
  Future<String> _calculateSha256(File file) async {
    if (!await file.exists()) return '';

    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

/// Export modes for different use cases
enum ChatExportMode {
  fullArchive,    // Active + archived
  activeOnly,     // Active sessions only
  dateBounded,    // Custom date range
}

/// Export configuration
class ChatExportConfig {
  final ChatExportMode mode;
  final bool includeArchived;
  final DateTime? since;
  final DateTime? until;
  final String profile;
  final String? notes;

  const ChatExportConfig({
    this.mode = ChatExportMode.fullArchive,
    this.includeArchived = true,
    this.since,
    this.until,
    this.profile = "monthly_chat_archive",
    this.notes,
  });

  /// Create config for full archive export
  factory ChatExportConfig.fullArchive({String? notes}) {
    return ChatExportConfig(
      mode: ChatExportMode.fullArchive,
      includeArchived: true,
      profile: "full_chat_archive",
      notes: notes,
    );
  }

  /// Create config for active-only export
  factory ChatExportConfig.activeOnly({String? notes}) {
    return ChatExportConfig(
      mode: ChatExportMode.activeOnly,
      includeArchived: false,
      profile: "active_chat_archive",
      notes: notes,
    );
  }

  /// Create config for date-bounded export
  factory ChatExportConfig.dateBounded({
    required DateTime since,
    required DateTime until,
    bool includeArchived = true,
    String? notes,
  }) {
    return ChatExportConfig(
      mode: ChatExportMode.dateBounded,
      includeArchived: includeArchived,
      since: since,
      until: until,
      profile: "date_bounded_chat_archive",
      notes: notes,
    );
  }
}
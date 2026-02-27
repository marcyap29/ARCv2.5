import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import '../models/mcp_schemas.dart';
import '../validation/mcp_validator.dart';
import 'ndjson_writer.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';

/// MCP exporter for chat sessions and messages
class ChatMcpExporter {
  final Directory _outputDir;
  final McpStorageProfile _storageProfile;
  final String? _notes;

  ChatMcpExporter({
    required Directory outputDir,
    McpStorageProfile storageProfile = McpStorageProfile.balanced,
    String? notes,
  }) : _outputDir = outputDir,
       _storageProfile = storageProfile,
       _notes = notes;

  /// Export chat data to MCP bundle
  Future<ChatMcpExportResult> exportChats({
    required List<ChatSession> sessions,
    required List<ChatMessage> messages,
    ChatMcpExportScope scope = ChatMcpExportScope.all,
    DateTime? since,
    DateTime? until,
  }) async {
    try {
      // Filter data based on scope
      final filteredData = _filterDataByScope(sessions, messages, scope, since, until);
      
      // Create MCP nodes for sessions
      final sessionNodes = _createSessionNodes(filteredData.sessions);
      
      // Create MCP nodes for messages
      final messageNodes = _createMessageNodes(filteredData.messages);
      
      // Create edges between sessions and messages
      final edges = _createEdges(filteredData.sessions, filteredData.messages);
      
      // Create pointers for media content
      final pointers = _createPointers(filteredData.messages);
      
      // Create embeddings for semantic search
      final embeddings = _createEmbeddings(sessionNodes, messageNodes);
      
      // Write NDJSON files
      final ndjsonWriter = McpNdjsonWriter(outputDir: _outputDir);
      final ndjsonFiles = await ndjsonWriter.writeAll(
        nodes: [...sessionNodes, ...messageNodes],
        edges: edges,
        pointers: pointers,
        embeddings: embeddings,
      );
      
      // Create manifest
      final manifest = _createManifest(sessionNodes, messageNodes, edges, pointers, embeddings);
      final manifestFile = File(path.join(_outputDir.path, 'manifest.json'));
      await manifestFile.writeAsString(jsonEncode(manifest.toJson()));
      
      // Validate bundle
      final validationResult = await McpValidator.validateBundle(_outputDir);
      
      return ChatMcpExportResult(
        success: validationResult.isValid,
        bundlePath: _outputDir.path,
        sessionCount: sessionNodes.length,
        messageCount: messageNodes.length,
        pointerCount: pointers.length,
        embeddingCount: embeddings.length,
        errors: validationResult.errors,
      );
    } catch (e) {
      return ChatMcpExportResult(
        success: false,
        bundlePath: _outputDir.path,
        sessionCount: 0,
        messageCount: 0,
        pointerCount: 0,
        embeddingCount: 0,
        errors: [e.toString()],
      );
    }
  }

  /// Filter data based on export scope
  FilteredChatData _filterDataByScope(
    List<ChatSession> sessions,
    List<ChatMessage> messages,
    ChatMcpExportScope scope,
    DateTime? since,
    DateTime? until,
  ) {
    List<ChatSession> filteredSessions = sessions;
    List<ChatMessage> filteredMessages = messages;

    switch (scope) {
      case ChatMcpExportScope.all:
        // Include all sessions and messages
        break;
      case ChatMcpExportScope.activeOnly:
        // Only active (non-archived) sessions
        filteredSessions = sessions.where((s) => !s.isArchived).toList();
        final activeSessionIds = filteredSessions.map((s) => s.id).toSet();
        filteredMessages = messages.where((m) => activeSessionIds.contains(m.sessionId)).toList();
        break;
      case ChatMcpExportScope.dateBounded:
        if (since != null || until != null) {
          filteredSessions = sessions.where((s) {
            if (since != null && s.createdAt.isBefore(since)) return false;
            if (until != null && s.createdAt.isAfter(until)) return false;
            return true;
          }).toList();
          final filteredSessionIds = filteredSessions.map((s) => s.id).toSet();
          filteredMessages = messages.where((m) {
            if (!filteredSessionIds.contains(m.sessionId)) return false;
            if (since != null && m.createdAt.isBefore(since)) return false;
            if (until != null && m.createdAt.isAfter(until)) return false;
            return true;
          }).toList();
        }
        break;
    }

    return FilteredChatData(
      sessions: filteredSessions,
      messages: filteredMessages,
    );
  }

  /// Create MCP nodes for chat sessions
  List<McpNode> _createSessionNodes(List<ChatSession> sessions) {
    return sessions.map((session) {
      return McpNode(
        id: 'session:${session.id}',
        type: 'chat_session',
        timestamp: session.createdAt,
        contentSummary: session.subject,
        keywords: session.tags,
        narrative: McpNarrative(
          situation: 'Chat session: ${session.subject}',
          action: 'Conversation with LUMARA',
          growth: 'Reflective dialogue and insights',
          essence: 'Personal AI interaction',
        ),
        emotions: _extractSessionEmotions(session),
        provenance: const McpProvenance(
          source: 'lumara_chat',
          device: 'mobile',
          app: 'EPI',
          userId: null,
        ),
        metadata: {
          'isPinned': session.isPinned,
          'isArchived': session.isArchived,
          'archivedAt': session.archivedAt?.toIso8601String(),
          'messageCount': session.messageCount,
          'retention': session.retention,
        },
      );
    }).toList();
  }

  /// Create MCP nodes for chat messages
  List<McpNode> _createMessageNodes(List<ChatMessage> messages) {
    return messages.map((message) {
      // Extract text content and metadata
      final textContent = message.textContent;
      final hasMedia = message.hasMedia;
      final hasPrismAnalysis = message.hasPrismAnalysis;
      
      // Create content summary
      String contentSummary = textContent;
      if (hasMedia) {
        contentSummary += ' [Contains media]';
      }
      if (hasPrismAnalysis) {
        contentSummary += ' [Contains PRISM analysis]';
      }

      // Extract keywords from content
      final keywords = _extractMessageKeywords(message);

      return McpNode(
        id: message.id,
        type: 'chat_message',
        timestamp: message.createdAt,
        contentSummary: contentSummary,
        keywords: keywords,
        narrative: McpNarrative(
          situation: 'Message in chat conversation',
          action: message.role == 'user' ? 'User input' : 'LUMARA response',
          growth: 'Conversational exchange',
          essence: 'AI-human dialogue',
        ),
        emotions: _extractMessageEmotions(message),
        provenance: _extractMessageProvenance(message),
        metadata: {
          'role': message.role,
          'hasMedia': hasMedia,
          'hasPrismAnalysis': hasPrismAnalysis,
          'mediaCount': message.mediaPointers.length,
          'prismCount': message.prismSummaries.length,
          'originalTextHash': message.originalTextHash,
        },
      );
    }).toList();
  }

  /// Create edges between sessions and messages
  List<McpEdge> _createEdges(List<ChatSession> sessions, List<ChatMessage> messages) {
    final edges = <McpEdge>[];
    
    // Create contains edges from sessions to messages
    for (final session in sessions) {
      final sessionMessages = messages.where((m) => m.sessionId == session.id).toList();
      for (final message in sessionMessages) {
        edges.add(McpEdge(
          source: 'session:${session.id}',
          target: message.id,
          relation: 'contains',
          timestamp: message.createdAt,
          weight: 1.0,
          metadata: {
            'messageOrder': sessionMessages.indexOf(message),
          },
        ));
      }
    }
    
    return edges;
  }

  /// Create pointers for media content
  List<McpPointer> _createPointers(List<ChatMessage> messages) {
    final pointers = <McpPointer>[];
    
    for (final message in messages) {
      for (final mediaPointer in message.mediaPointers) {
        final pointer = McpPointer(
          id: 'pointer:${_generatePointerId(mediaPointer.uri)}',
          mediaType: _getMediaTypeFromUri(mediaPointer.uri),
          sourceUri: mediaPointer.uri,
          descriptor: McpDescriptor(
            mimeType: _getMimeTypeFromUri(mediaPointer.uri),
            metadata: mediaPointer.metadata,
          ),
          samplingManifest: McpSamplingManifest(
            metadata: {
              'messageId': message.id,
              'role': mediaPointer.role ?? 'primary',
            },
          ),
          integrity: McpIntegrity(
            contentHash: _generateContentHash(mediaPointer.uri),
            bytes: 0, // Will be updated when file is processed
            createdAt: DateTime.now(),
          ),
          provenance: const McpProvenance(
            source: 'lumara_chat',
            device: 'mobile',
            app: 'EPI',
            userId: null,
          ),
          privacy: const McpPrivacy(
            containsPii: false, // Will be updated by PRISM analysis
            facesDetected: false, // Will be updated by PRISM analysis
            sharingPolicy: 'private',
          ),
          labels: ['chat_media'],
        );
        pointers.add(pointer);
      }
    }
    
    return pointers;
  }

  /// Create embeddings for semantic search
  List<McpEmbedding> _createEmbeddings(List<McpNode> sessionNodes, List<McpNode> messageNodes) {
    final embeddings = <McpEmbedding>[];
    
    // Create embeddings for sessions
    for (final session in sessionNodes) {
      final embedding = McpEmbedding(
        id: 'embedding:${session.id}',
        pointerRef: session.id,
        vector: _generateEmbeddingVector(session.contentSummary ?? ''),
        modelId: 'text-embedding-ada-002',
        embeddingVersion: '1.0',
        dim: 1536,
        metadata: {
          'type': 'session',
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      embeddings.add(embedding);
    }
    
    // Create embeddings for messages
    for (final message in messageNodes) {
      final embedding = McpEmbedding(
        id: 'embedding:${message.id}',
        pointerRef: message.id,
        vector: _generateEmbeddingVector(message.contentSummary ?? ''),
        modelId: 'text-embedding-ada-002',
        embeddingVersion: '1.0',
        dim: 1536,
        metadata: {
          'type': 'message',
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      embeddings.add(embedding);
    }
    
    return embeddings;
  }

  /// Create MCP manifest
  McpManifest _createManifest(
    List<McpNode> sessionNodes,
    List<McpNode> messageNodes,
    List<McpEdge> edges,
    List<McpPointer> pointers,
    List<McpEmbedding> embeddings,
  ) {
    final allNodes = [...sessionNodes, ...messageNodes];
    
    return McpManifest(
      bundleId: 'chat_export_${DateTime.now().millisecondsSinceEpoch}',
      version: '1.0.0',
      createdAt: DateTime.now(),
      storageProfile: _storageProfile.value,
      counts: McpCounts(
        nodes: allNodes.length,
        edges: edges.length,
        pointers: pointers.length,
        embeddings: embeddings.length,
      ),
      checksums: const McpChecksums(), // Will be calculated by writer
      encoderRegistry: [
        const McpEncoderRegistry(
          modelId: 'text-embedding-ada-002',
          embeddingVersion: '1.0',
          dim: 1536,
        ),
      ],
      notes: _notes,
    );
  }

  // Helper methods
  Map<String, double> _extractSessionEmotions(ChatSession session) {
    // Simple emotion extraction based on session metadata
    return {
      'engagement': session.messageCount > 10 ? 0.8 : 0.5,
      'satisfaction': session.isPinned ? 0.9 : 0.6,
    };
  }

  Map<String, double> _extractMessageEmotions(ChatMessage message) {
    // Extract emotions from PRISM analysis if available
    final prismSummaries = message.prismSummaries;
    if (prismSummaries.isNotEmpty) {
      final emotion = prismSummaries.first.emotion;
      if (emotion != null) {
        return {
          'valence': emotion.valence,
          'arousal': emotion.arousal,
        };
      }
    }
    
    // Default neutral emotions
    return {
      'valence': 0.0,
      'arousal': 0.5,
    };
  }

  List<String> _extractMessageKeywords(ChatMessage message) {
    final keywords = <String>[];
    
    // Extract from text content
    final textContent = message.textContent;
    if (textContent.isNotEmpty) {
      // Simple keyword extraction (in real implementation, use proper NLP)
      final words = textContent.toLowerCase().split(RegExp(r'\W+'))
          .where((word) => word.length > 3)
          .take(10)
          .toList();
      keywords.addAll(words);
    }
    
    // Extract from PRISM analysis
    for (final prism in message.prismSummaries) {
      if (prism.objects != null) {
        keywords.addAll(prism.objects!);
      }
      if (prism.symbols != null) {
        keywords.addAll(prism.symbols!);
      }
    }
    
    return keywords.toSet().toList();
  }

  /// Extract MCP provenance from chat message
  /// Handles provenance as either a JSON string or checks metadata
  McpProvenance _extractMessageProvenance(ChatMessage message) {
    String? device = 'mobile';
    String? app = 'EPI';
    
    // Try to parse provenance if it's a JSON string
    if (message.provenance != null && message.provenance!.isNotEmpty) {
      try {
        final provenanceMap = jsonDecode(message.provenance!) as Map<String, dynamic>?;
        if (provenanceMap != null) {
          device = provenanceMap['device'] as String? ?? device;
          app = provenanceMap['appVersion'] as String? ?? provenanceMap['app'] as String? ?? app;
        }
      } catch (e) {
        // If provenance is not JSON, treat it as a simple string identifier
        // Use defaults
      }
    }
    
    // Check metadata as fallback
    if (message.metadata != null) {
      device = message.metadata!['device'] as String? ?? device;
      app = message.metadata!['appVersion'] as String? ?? message.metadata!['app'] as String? ?? app;
    }
    
    return McpProvenance(
      source: 'lumara_chat',
      device: device,
      app: app,
      userId: null,
    );
  }

  String _generatePointerId(String uri) {
    final hash = sha256.convert(utf8.encode(uri)).toString();
    return hash.substring(0, 16);
  }

  String _getMediaTypeFromUri(String uri) {
    if (uri.startsWith('photos://') || uri.startsWith('gphotos://')) {
      return 'image';
    } else if (uri.startsWith('file://')) {
      final ext = path.extension(uri).toLowerCase();
      if (['.mp3', '.wav', '.m4a'].contains(ext)) return 'audio';
      if (['.mp4', '.mov', '.avi'].contains(ext)) return 'video';
      if (['.jpg', '.jpeg', '.png', '.gif'].contains(ext)) return 'image';
    }
    return 'unknown';
  }

  String _getMimeTypeFromUri(String uri) {
    final ext = path.extension(uri).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.m4a':
        return 'audio/mp4';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      default:
        return 'application/octet-stream';
    }
  }

  String _generateContentHash(String uri) {
    return sha256.convert(utf8.encode(uri)).toString();
  }

  List<double> _generateEmbeddingVector(String text) {
    // Placeholder embedding generation
    // In real implementation, use actual embedding model
    final hash = sha256.convert(utf8.encode(text)).toString();
    final vector = <double>[];
    for (int i = 0; i < 1536; i += 4) {
      final hex = hash.substring(i % hash.length, (i % hash.length) + 4);
      vector.add(int.parse(hex, radix: 16) / 65535.0);
    }
    return vector;
  }
}

/// Export scope options
enum ChatMcpExportScope {
  all,
  activeOnly,
  dateBounded,
}

/// Filtered chat data
class FilteredChatData {
  final List<ChatSession> sessions;
  final List<ChatMessage> messages;

  FilteredChatData({
    required this.sessions,
    required this.messages,
  });
}

/// Export result
class ChatMcpExportResult {
  final bool success;
  final String bundlePath;
  final int sessionCount;
  final int messageCount;
  final int pointerCount;
  final int embeddingCount;
  final List<String> errors;

  ChatMcpExportResult({
    required this.success,
    required this.bundlePath,
    required this.sessionCount,
    required this.messageCount,
    required this.pointerCount,
    required this.embeddingCount,
    required this.errors,
  });
}

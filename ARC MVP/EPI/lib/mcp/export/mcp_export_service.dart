/// MCP Export Service
/// 
/// High-level orchestrator for exporting MIRA memory into MCP Memory Bundle format.
/// Handles SAGE-to-Node mapping, pointer creation, embedding generation, and edge derivation.
library;

import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../models/mcp_schemas.dart';
import '../validation/mcp_validator.dart';
import 'ndjson_writer.dart';
import 'manifest_builder.dart';
import 'checksum_utils.dart';
import 'chat_exporter.dart';
import '../../lumara/chat/chat_repo.dart';
import '../../lumara/chat/chat_models.dart';
import '../../arc/models/journal_entry_model.dart';
import '../../data/models/media_item.dart';

class McpExportService {
  final String bundleId;
  final McpStorageProfile storageProfile;
  final String? notes;
  final ChatRepo? chatRepo;
  final ChatMcpExporter? _chatExporter;

  McpExportService({
    String? bundleId,
    this.storageProfile = McpStorageProfile.balanced,
    this.notes,
    this.chatRepo,
  }) : bundleId = bundleId ?? McpManifestBuilder.generateBundleId(),
       _chatExporter = chatRepo != null ? ChatMcpExporter(chatRepo) : null;

  /// Export MIRA memory to MCP bundle (including chat data)
  Future<McpExportResult> exportToMcp({
    required Directory outputDir,
    required McpExportScope scope,
    required List<JournalEntry> journalEntries,
    List<MediaItem>? mediaFiles,
    Map<String, dynamic>? customScope,
    bool includeChats = true,
    bool includeArchivedChats = true,
  }) async {
    try {
      // Ensure output directory exists
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // Filter entries based on scope
      final filteredEntries = _filterEntriesByScope(journalEntries, scope, customScope);
      
      // Convert journal entries to MCP nodes (SAGE mapping)
      final nodes = await _convertJournalEntriesToNodes(filteredEntries);

      // Create pointers for media files
      final pointers = await _createPointersFromMedia(mediaFiles ?? []);

      // Export chat data if chat repository is available
      final chatData = await _exportChatData(scope, customScope, includeChats, includeArchivedChats);

      // Combine all nodes, edges, and pointers
      final allNodes = <McpNode>[...nodes, ...chatData.nodes];
      final allEdges = <McpEdge>[...chatData.edges];
      final allPointers = <McpPointer>[...pointers, ...chatData.pointers];

      // Generate embeddings for nodes and pointers
      final embeddings = await _generateEmbeddings(allNodes, allPointers);

      // Derive edges from relationships (journal entries)
      final journalEdges = await _deriveEdges(nodes, embeddings);
      final allCombinedEdges = <McpEdge>[...allEdges, ...journalEdges];
      
      // Validate all records
      final validationResult = await _validateRecords(allNodes, allCombinedEdges, allPointers, embeddings);
      if (!validationResult.isValid) {
        throw McpExportException('Validation failed: ${validationResult.errors.join(', ')}');
      }

      // Write NDJSON files
      final ndjsonWriter = McpNdjsonWriter(outputDir: outputDir);
      final ndjsonFiles = await ndjsonWriter.writeAll(
        nodes: allNodes,
        edges: allCombinedEdges,
        pointers: allPointers,
        embeddings: embeddings,
      );
      
      // Build and write manifest
      final manifestBuilder = McpManifestBuilder(
        bundleId: bundleId,
        storageProfile: storageProfile,
        notes: notes,
      );
      
      final counts = McpCounts(
        nodes: allNodes.length,
        edges: allCombinedEdges.length,
        pointers: allPointers.length,
        embeddings: embeddings.length,
      );
      
      final encoderRegistry = McpManifestBuilder.createEncoderRegistry(embeddings);
      
      final manifestFile = await manifestBuilder.buildAndWriteManifest(
        outputDir: outputDir,
        ndjsonFiles: ndjsonFiles,
        counts: counts,
        encoderRegistry: encoderRegistry,
      );
      
      return McpExportResult(
        success: true,
        bundleId: bundleId,
        outputDir: outputDir,
        manifestFile: manifestFile,
        ndjsonFiles: ndjsonFiles,
        counts: counts,
        encoderRegistry: encoderRegistry,
      );
      
    } catch (e) {
      return McpExportResult(
        success: false,
        error: e.toString(),
        bundleId: bundleId,
        outputDir: outputDir,
      );
    }
  }

  /// Filter journal entries based on export scope
  List<JournalEntry> _filterEntriesByScope(
    List<JournalEntry> entries,
    McpExportScope scope,
    Map<String, dynamic>? customScope,
  ) {
    final now = DateTime.now();
    
    switch (scope) {
      case McpExportScope.last30Days:
        final cutoff = now.subtract(const Duration(days: 30));
        return entries.where((e) => e.createdAt.isAfter(cutoff)).toList();
        
      case McpExportScope.last90Days:
        final cutoff = now.subtract(const Duration(days: 90));
        return entries.where((e) => e.createdAt.isAfter(cutoff)).toList();
        
      case McpExportScope.lastYear:
        final cutoff = now.subtract(const Duration(days: 365));
        return entries.where((e) => e.createdAt.isAfter(cutoff)).toList();
        
      case McpExportScope.all:
        return entries;
        
      case McpExportScope.custom:
        if (customScope == null) return entries;
        
        final startDate = customScope['start_date'] as DateTime?;
        final endDate = customScope['end_date'] as DateTime?;
        final tags = customScope['tags'] as List<String>?;
        
        var filtered = entries;
        
        if (startDate != null) {
          filtered = filtered.where((e) => e.createdAt.isAfter(startDate)).toList();
        }
        if (endDate != null) {
          filtered = filtered.where((e) => e.createdAt.isBefore(endDate)).toList();
        }
        if (tags != null && tags.isNotEmpty) {
          filtered = filtered.where((e) => 
            e.tags.any((tag) => tags.contains(tag))).toList();
        }
        
        return filtered;
    }
  }

  /// Convert journal entries to MCP nodes with SAGE mapping
  Future<List<McpNode>> _convertJournalEntriesToNodes(List<JournalEntry> entries) async {
    final nodes = <McpNode>[];

    print('📝 Converting ${entries.length} journal entries to MCP nodes...');

    for (final entry in entries) {
      print('🔄 Processing entry: "${entry.title}" (${entry.content.length} chars)');

      // Extract SAGE narrative from journal content
      final narrative = _extractSageNarrative(entry);

      // Determine phase hint from entry metadata
      final phaseHint = _determinePhaseHint(entry);

      // Extract emotions from entry
      final emotions = _extractEmotions(entry);

      // Create node ID
      final nodeId = 'entry_${entry.createdAt.year}_${entry.createdAt.month.toString().padLeft(2, '0')}_${entry.createdAt.day.toString().padLeft(2, '0')}_${entry.id}';

      print('   Node ID: $nodeId');
      print('   Content preserved in: contentSummary (${entry.content.length} chars), narrative.situation (${entry.content.length} chars), metadata');
      print('   Tags: ${entry.tags}');
      print('   Phase: $phaseHint');
      
      final node = McpNode(
        id: nodeId,
        type: 'journal_entry',
        timestamp: entry.createdAt.toUtc(),
        contentSummary: _createContentSummary(entry),
        phaseHint: phaseHint,
        keywords: entry.tags,
        narrative: narrative,
        emotions: emotions,
        provenance: McpProvenance(
          source: 'ARC',
          device: Platform.operatingSystem,
          app: 'EPI',
          importMethod: 'journal_entry',
          userId: null, // JournalEntry doesn't have userId in the real model
        ),
        // Add metadata to preserve additional journal entry fields
        metadata: {
          'journal_entry': {
            'id': entry.id,
            'title': entry.title,
            'content': entry.content, // Full content backup
            'mood': entry.mood,
            'emotion': entry.emotion,
            'emotion_reason': entry.emotionReason,
            'created_at': entry.createdAt.toIso8601String(),
            'updated_at': entry.updatedAt.toIso8601String(),
            'keywords': entry.keywords,
          },
          'export_info': {
            'exported_at': DateTime.now().toIso8601String(),
            'content_length': entry.content.length,
            'has_full_content': true,
          }
        },
      );

      print('✅ Created MCP node with enhanced metadata preservation');
      nodes.add(node);
    }

    print('✅ Converted all ${entries.length} journal entries to MCP nodes');
    return nodes;
  }

  /// Extract SAGE narrative from journal entry
  McpNarrative _extractSageNarrative(JournalEntry entry) {
    // Store the full content in the situation field to preserve it
    // This ensures complete content preservation for import restoration
    final content = entry.content;

    return McpNarrative(
      situation: content, // Store full content here for preservation
      action: _extractAction(content),
      growth: _extractGrowth(content),
      essence: _extractEssence(content),
    );
  }

  /// Extract situation from journal content
  String? _extractSituation(String content) {
    // Simplified: look for situation keywords
    final situationKeywords = ['situation', 'context', 'when', 'where', 'circumstance'];
    for (final keyword in situationKeywords) {
      if (content.toLowerCase().contains(keyword)) {
        return 'Situation extracted from journal entry';
      }
    }
    return null;
  }

  /// Extract action from journal content
  String? _extractAction(String content) {
    // Simplified: look for action keywords
    final actionKeywords = ['action', 'did', 'took', 'decided', 'chose'];
    for (final keyword in actionKeywords) {
      if (content.toLowerCase().contains(keyword)) {
        return 'Action extracted from journal entry';
      }
    }
    return null;
  }

  /// Extract growth from journal content
  String? _extractGrowth(String content) {
    // Simplified: look for growth keywords
    final growthKeywords = ['growth', 'learned', 'realized', 'understood', 'insight'];
    for (final keyword in growthKeywords) {
      if (content.toLowerCase().contains(keyword)) {
        return 'Growth extracted from journal entry';
      }
    }
    return null;
  }

  /// Extract essence from journal content
  String? _extractEssence(String content) {
    // Simplified: look for essence keywords
    final essenceKeywords = ['essence', 'core', 'meaning', 'purpose', 'value'];
    for (final keyword in essenceKeywords) {
      if (content.toLowerCase().contains(keyword)) {
        return 'Essence extracted from journal entry';
      }
    }
    return null;
  }

  /// Determine phase hint from journal entry
  String? _determinePhaseHint(JournalEntry entry) {
    // This would integrate with your existing phase detection system
    // For now, return a default or extract from entry metadata
    return entry.metadata?['phase'] as String?;
  }

  /// Extract emotions from journal entry
  Map<String, double> _extractEmotions(JournalEntry entry) {
    // This would integrate with your existing emotion analysis
    // For now, return a simple mapping
    return {
      'calm': 0.6,
      'curious': 0.4,
    };
  }

  /// Create content summary from journal entry
  String _createContentSummary(JournalEntry entry) {
    // For journal entries, preserve the full content in contentSummary
    // This ensures complete content preservation during export/import cycle
    return entry.content;
  }

  /// Create pointers from media files
  Future<List<McpPointer>> _createPointersFromMedia(List<MediaItem> mediaFiles) async {
    final pointers = <McpPointer>[];
    
    for (final mediaFile in mediaFiles) {
      final pointerId = 'ptr_${mediaFile.id}';
      
      // Create content hash
      final file = File(mediaFile.uri);
      final contentBytes = await file.readAsBytes();
      final contentHash = sha256.convert(contentBytes).toString();
      
      // Create CAS URI
      final casUri = McpChecksumUtils.generateCasUri(contentBytes);
      
      final pointer = McpPointer(
        id: pointerId,
        mediaType: mediaFile.type.name,
        sourceUri: mediaFile.uri,
        altUris: [casUri],
        descriptor: McpDescriptor(
          language: 'en', // Default language
          length: contentBytes.length,
          mimeType: _getMimeTypeForMediaType(mediaFile.type),
          metadata: {
            'original_filename': mediaFile.uri.split('/').last,
            'duration': mediaFile.duration?.inMicroseconds,
            'size_bytes': mediaFile.sizeBytes,
            'transcript': mediaFile.transcript,
            'ocr_text': mediaFile.ocrText,
          },
        ),
        samplingManifest: McpSamplingManifest(
          spans: _createSpansForMedia(mediaFile),
          keyframes: _createKeyframesForMedia(mediaFile),
          metadata: {
            'sampling_method': 'automatic',
            'quality': 'balanced',
          },
        ),
        integrity: McpIntegrity(
          contentHash: contentHash,
          bytes: contentBytes.length,
          mime: _getMimeTypeForMediaType(mediaFile.type),
          createdAt: mediaFile.createdAt.toUtc(),
        ),
        provenance: McpProvenance(
          source: 'ARC',
          device: Platform.operatingSystem,
          app: 'EPI',
          importMethod: 'media_import',
          userId: null, // MediaItem doesn't have userId
        ),
        privacy: McpPrivacy(
          containsPii: _detectPii(mediaFile),
          facesDetected: _detectFaces(mediaFile),
          locationPrecision: _detectLocation(mediaFile),
          sharingPolicy: 'private',
        ),
        labels: [], // MediaItem doesn't have tags
      );
      
      pointers.add(pointer);
    }
    
    return pointers;
  }

  /// Get MIME type for MediaType
  String _getMimeTypeForMediaType(MediaType type) {
    switch (type) {
      case MediaType.audio:
        return 'audio/mpeg';
      case MediaType.image:
        return 'image/jpeg';
      case MediaType.video:
        return 'video/mp4';
      case MediaType.file:
        return 'application/octet-stream';
    }
  }

  /// Create spans for media file
  List<McpSpan> _createSpansForMedia(MediaItem mediaFile) {
    // This would create text spans for audio transcripts, video captions, etc.
    return [];
  }

  /// Create keyframes for media file
  List<McpKeyframe> _createKeyframesForMedia(MediaItem mediaFile) {
    // This would create keyframes for video files
    return [];
  }

  /// Detect PII in media file
  bool _detectPii(MediaItem mediaFile) {
    // This would use your existing PII detection
    return false;
  }

  /// Detect faces in media file
  bool _detectFaces(MediaItem mediaFile) {
    // This would use your existing face detection
    return false;
  }

  /// Detect location in media file
  String? _detectLocation(MediaItem mediaFile) {
    // This would use your existing location detection
    return null;
  }

  /// Generate embeddings for nodes and pointers
  Future<List<McpEmbedding>> _generateEmbeddings(
    List<McpNode> nodes,
    List<McpPointer> pointers,
  ) async {
    final embeddings = <McpEmbedding>[];
    
    // Generate embeddings for nodes only if they reference a valid pointer
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final String? ptr = node.pointerRef; // optional in schema
      if (ptr != null && ptr.isNotEmpty) {
        final embeddingId = 'emb_node_$i';
        final vector = await _generateEmbeddingVector(node.contentSummary ?? '');
        final embedding = McpEmbedding(
          id: embeddingId,
          pointerRef: ptr,
          docScope: node.id,
          vector: vector,
          modelId: 'qwen-2.5-1.5b',
          embeddingVersion: '1.0.0',
          dim: vector.length,
        );
        embeddings.add(embedding);
      }
    }
    
    // Generate embeddings for pointers
    for (int i = 0; i < pointers.length; i++) {
      final pointer = pointers[i];
      final embeddingId = 'emb_ptr_$i';
      
      // This would use your existing embedding service
      final vector = await _generateEmbeddingVector(pointer.descriptor.metadata.toString());
      
      final embedding = McpEmbedding(
        id: embeddingId,
        pointerRef: pointer.id,
        vector: vector,
        modelId: 'qwen-2.5-1.5b',
        embeddingVersion: '1.0.0',
        dim: vector.length,
      );
      
      embeddings.add(embedding);
    }
    
    return embeddings;
  }

  /// Generate embedding vector for text
  Future<List<double>> _generateEmbeddingVector(String text) async {
    // This would use your existing embedding service
    // For now, return a dummy vector
    return List.generate(384, (index) => (index * 0.01) % 1.0);
  }

  /// Derive edges from relationships
  Future<List<McpEdge>> _deriveEdges(
    List<McpNode> nodes,
    List<McpEmbedding> embeddings,
  ) async {
    final edges = <McpEdge>[];
    
    // Create time adjacency edges
    for (int i = 0; i < nodes.length - 1; i++) {
      final current = nodes[i];
      final next = nodes[i + 1];
      
      final edge = McpEdge(
        source: current.id,
        target: next.id,
        relation: 'time_adjacent',
        timestamp: current.timestamp,
        weight: 0.8,
      );
      
      edges.add(edge);
    }
    
    // Create theme similarity edges based on embeddings
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final node1 = nodes[i];
        final node2 = nodes[j];
        
        // Find embeddings for these nodes
        final emb1 = embeddings.where((e) => e.docScope == node1.id).cast<McpEmbedding?>().firstOrNull;
        final emb2 = embeddings.where((e) => e.docScope == node2.id).cast<McpEmbedding?>().firstOrNull;
        if (emb1 == null || emb2 == null) {
          continue;
        }
        
        // Calculate cosine similarity
        final similarity = _calculateCosineSimilarity(emb1.vector, emb2.vector);
        
        if (similarity > 0.7) {
          final edge = McpEdge(
            source: node1.id,
            target: node2.id,
            relation: 'theme_similar',
            timestamp: node1.timestamp,
            weight: similarity,
          );
          
          edges.add(edge);
        }
      }
    }
    
    return edges;
  }

  /// Calculate cosine similarity between two vectors
  double _calculateCosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    normA = sqrt(normA);
    normB = sqrt(normB);
    
    if (normA == 0.0 || normB == 0.0) return 0.0;
    
    return dotProduct / (normA * normB);
  }

  /// Export chat data to MCP format
  Future<ChatExportData> _exportChatData(
    McpExportScope scope,
    Map<String, dynamic>? customScope,
    bool includeChats,
    bool includeArchivedChats,
  ) async {
    if (!includeChats || _chatExporter == null) {
      return ChatExportData(
        nodes: [],
        edges: [],
        pointers: [],
      );
    }

    try {
      // Apply date filtering based on scope for chats
      DateTime? since;
      DateTime? until;

      switch (scope) {
        case McpExportScope.last30Days:
          since = DateTime.now().subtract(const Duration(days: 30));
          break;
        case McpExportScope.last90Days:
          since = DateTime.now().subtract(const Duration(days: 90));
          break;
        case McpExportScope.lastYear:
          since = DateTime.now().subtract(const Duration(days: 365));
          break;
        case McpExportScope.custom:
          if (customScope != null) {
            since = customScope['start_date'] as DateTime?;
            until = customScope['end_date'] as DateTime?;
          }
          break;
        case McpExportScope.all:
          // No date filtering
          break;
      }

      // Get chat sessions and messages within scope
      final sessions = await chatRepo!.listAll(includeArchived: includeArchivedChats);

      // Filter sessions by date if specified
      final filteredSessions = sessions.where((session) {
        if (since != null && session.createdAt.isBefore(since)) return false;
        if (until != null && session.createdAt.isAfter(until)) return false;
        return true;
      }).toList();

      // Convert chat data to MCP format
      final chatNodes = <McpNode>[];
      final chatEdges = <McpEdge>[];
      final chatPointers = <McpPointer>[];

      for (final session in filteredSessions) {
        // Convert session to MCP node
        final sessionNode = await _convertChatSessionToNode(session);
        chatNodes.add(sessionNode);

        // Create session pointer for discoverability
        final sessionPointer = await _createChatSessionPointer(session);
        chatPointers.add(sessionPointer);

        // Get messages for this session
        final messages = await chatRepo!.getMessages(session.id, lazy: false);

        // Convert messages and create contains edges
        for (int i = 0; i < messages.length; i++) {
          final message = messages[i];

          // Convert message to MCP node
          final messageNode = await _convertChatMessageToNode(message);
          chatNodes.add(messageNode);

          // Create contains edge
          final containsEdge = await _createChatContainsEdge(session.id, message.id, message.createdAt, i);
          chatEdges.add(containsEdge);
        }
      }

      return ChatExportData(
        nodes: chatNodes,
        edges: chatEdges,
        pointers: chatPointers,
      );

    } catch (e) {
      print('Warning: Failed to export chat data: $e');
      return ChatExportData(
        nodes: [],
        edges: [],
        pointers: [],
      );
    }
  }

  /// Convert ChatSession to MCP Node
  Future<McpNode> _convertChatSessionToNode(ChatSession session) async {
    return McpNode(
      id: 'session:${session.id}',
      type: 'ChatSession',
      timestamp: session.createdAt.toUtc(),
      contentSummary: session.subject,
      keywords: session.tags.toList(),
        narrative: McpNarrative(
          situation: session.subject,
        ),
      provenance: McpProvenance(
        source: 'LUMARA',
        device: Platform.operatingSystem,
        app: 'EPI',
        importMethod: 'chat_session',
        userId: null, // Chat sessions don't have individual user IDs in this model
      ),
    );
  }

  /// Convert ChatMessage to MCP Node
  Future<McpNode> _convertChatMessageToNode(ChatMessage message) async {
    return McpNode(
      id: 'msg:${message.id}',
      type: 'ChatMessage',
      timestamp: message.createdAt.toUtc(),
      contentSummary: message.content.length > 100
          ? '${message.content.substring(0, 100)}...'
          : message.content,
      keywords: [],
      narrative: McpNarrative(
        situation: message.content,
      ),
      provenance: McpProvenance(
        source: 'LUMARA',
        device: Platform.operatingSystem,
        app: 'EPI',
        importMethod: 'chat_message',
        userId: null,
      ),
    );
  }

  /// Create MCP Pointer for ChatSession
  Future<McpPointer> _createChatSessionPointer(ChatSession session) async {
    return McpPointer(
      id: 'ptr_session:${session.id}',
      mediaType: 'application/json',
      descriptor: McpDescriptor(
        language: 'en',
        length: session.subject.length,
        mimeType: 'application/json',
        metadata: {
          'session_id': session.id,
          'subject': session.subject,
          'message_count': session.messageCount,
          'is_archived': session.isArchived,
          'is_pinned': session.isPinned,
          'tags': session.tags,
        },
      ),
      samplingManifest: McpSamplingManifest(
        spans: [],
        keyframes: [],
        metadata: {
          'sampling_method': 'none',
          'content_type': 'chat_session',
        },
      ),
      integrity: McpIntegrity(
        contentHash: 'dummy_hash_${session.id}',
        bytes: session.subject.length,
        mime: 'application/json',
        createdAt: session.createdAt.toUtc(),
      ),
      provenance: McpProvenance(
        source: 'LUMARA',
        device: Platform.operatingSystem,
        app: 'EPI',
        importMethod: 'chat_session_pointer',
        userId: null,
      ),
      privacy: McpPrivacy(
        containsPii: false,
        facesDetected: false,
        locationPrecision: null,
        sharingPolicy: 'private',
      ),
      labels: ['chat_session', ...session.tags],
    );
  }

  /// Create contains edge between session and message
  Future<McpEdge> _createChatContainsEdge(String sessionId, String messageId, DateTime timestamp, int order) async {
    return McpEdge(
      source: 'session:$sessionId',
      target: 'msg:$messageId',
      relation: 'contains',
      timestamp: timestamp.toUtc(),
      weight: 1.0,
    );
  }

  /// Validate all records
  Future<ValidationResult> _validateRecords(
    List<McpNode> nodes,
    List<McpEdge> edges,
    List<McpPointer> pointers,
    List<McpEmbedding> embeddings,
  ) async {
    final allErrors = <String>[];
    
    // Validate nodes
    for (final node in nodes) {
      final result = McpValidator.validateNode(node);
      if (!result.isValid) {
        allErrors.addAll(result.errors.map((e) => 'Node ${node.id}: $e'));
      }
    }
    
    // Validate edges
    for (final edge in edges) {
      final result = McpValidator.validateEdge(edge);
      if (!result.isValid) {
        allErrors.addAll(result.errors.map((e) => 'Edge ${edge.source}->${edge.target}: $e'));
      }
    }
    
    // Validate pointers
    for (final pointer in pointers) {
      final result = McpValidator.validatePointer(pointer);
      if (!result.isValid) {
        allErrors.addAll(result.errors.map((e) => 'Pointer ${pointer.id}: $e'));
      }
    }
    
    // Validate embeddings
    for (final embedding in embeddings) {
      final result = McpValidator.validateEmbedding(embedding);
      if (!result.isValid) {
        allErrors.addAll(result.errors.map((e) => 'Embedding ${embedding.id}: $e'));
      }
    }
    
    return ValidationResult(
      isValid: allErrors.isEmpty,
      errors: allErrors,
    );
  }
}

/// MCP Export Result
class McpExportResult {
  final bool success;
  final String? error;
  final String bundleId;
  final Directory outputDir;
  final File? manifestFile;
  final Map<String, File>? ndjsonFiles;
  final McpCounts? counts;
  final List<McpEncoderRegistry>? encoderRegistry;

  const McpExportResult({
    required this.success,
    this.error,
    required this.bundleId,
    required this.outputDir,
    this.manifestFile,
    this.ndjsonFiles,
    this.counts,
    this.encoderRegistry,
  });
}

/// MCP Export Exception
class McpExportException implements Exception {
  final String message;
  const McpExportException(this.message);
  
  @override
  String toString() => 'McpExportException: $message';
}


/// Container for chat export data
class ChatExportData {
  final List<McpNode> nodes;
  final List<McpEdge> edges;
  final List<McpPointer> pointers;

  const ChatExportData({
    required this.nodes,
    required this.edges,
    required this.pointers,
  });
}

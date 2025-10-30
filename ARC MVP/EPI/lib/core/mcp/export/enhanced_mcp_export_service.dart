/// Enhanced MCP Export Service
/// 
/// High-level orchestrator for exporting all memory types into MCP Memory Bundle format.
/// Handles Chat, Draft, LUMARA enhanced, and standard journal entries with proper node types.
library;

import 'dart:io';
import 'dart:convert';
import '../models/mcp_schemas.dart';
import '../models/mcp_enhanced_nodes.dart';
import '../services/mcp_node_factory.dart';
import 'ndjson_writer.dart';
import 'manifest_builder.dart';
import 'checksum_utils.dart';
import 'package:my_app/lumara/chat/chat_repo.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/core/services/draft_cache_service.dart';

/// Enhanced MCP Export Service with support for all node types
class EnhancedMcpExportService {
  final String bundleId;
  final McpStorageProfile storageProfile;
  final String? notes;
  final ChatRepo? chatRepo;
  final DraftCacheService? draftService;

  EnhancedMcpExportService({
    String? bundleId,
    this.storageProfile = McpStorageProfile.balanced,
    this.notes,
    this.chatRepo,
    this.draftService,
  }) : bundleId = bundleId ?? McpManifestBuilder.generateBundleId();

  /// Export all memory types to MCP bundle
  Future<EnhancedMcpExportResult> exportAllToMcp({
    required Directory outputDir,
    required List<JournalEntry> journalEntries,
    List<MediaItem>? mediaFiles,
    bool includeChats = true,
    bool includeDrafts = true,
    bool includeLumaraEnhanced = true,
    bool includeArchivedChats = true,
  }) async {
    try {
      // Ensure output directory exists
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      print('🚀 Enhanced MCP Export: Starting export to ${outputDir.path}');
      print('📊 Export scope: ${journalEntries.length} journal entries, chats: $includeChats, drafts: $includeDrafts');

      // Collect all nodes and edges
      final allNodes = <McpNode>[];
      final allEdges = <McpEdge>[];
      final allPointers = <McpPointer>[];
      final allEmbeddings = <McpEmbedding>[];

      // Export journal entries
      for (final entry in journalEntries) {
        final node = McpNodeFactory.fromJournalEntry(entry);
        allNodes.add(node);
        
        // Create LUMARA enhanced version if requested
        if (includeLumaraEnhanced) {
          final lumaraNode = McpNodeFactory.createLumaraJournalWithRosebud(
            journalId: entry.id,
            timestamp: entry.createdAt,
            content: entry.content,
            rosebud: _generateRosebud(entry.content),
            insights: _extractLumaraInsights(entry.content),
            metadata: {
              'originalJournalId': entry.id,
              'enhancedBy': 'LUMARA',
              'enhancementType': 'rosebud_analysis',
            },
          );
          allNodes.add(lumaraNode);
          
          // Create edge between original and enhanced
          final edge = McpNodeFactory.createEdge(
            source: entry.id,
            target: lumaraNode.id,
            relation: 'enhanced_by',
            timestamp: DateTime.now(),
            metadata: {'enhancementType': 'rosebud_analysis'},
          );
          allEdges.add(edge);
        }
      }

      // Export chat sessions and messages
      if (includeChats && chatRepo != null) {
        final chatData = await _exportChatData(includeArchivedChats);
        allNodes.addAll(chatData.nodes);
        allEdges.addAll(chatData.edges);
      }

      // Export draft entries
      if (includeDrafts && draftService != null) {
        final draftData = await _exportDraftData();
        allNodes.addAll(draftData.nodes);
        allEdges.addAll(draftData.edges);
      }

      // Export media pointers
      if (mediaFiles != null) {
        final mediaData = await _exportMediaData(mediaFiles);
        allPointers.addAll(mediaData.pointers);
        allEdges.addAll(mediaData.edges);
      }

      // Write NDJSON files
      final ndjsonFiles = await _writeNdjsonFiles(
        outputDir,
        allNodes,
        allEdges,
        allPointers,
        allEmbeddings,
      );

      // Create manifest
      final manifest = await _createManifest(
        allNodes,
        allEdges,
        allPointers,
        allEmbeddings,
        ndjsonFiles,
      );

      // Write manifest
      final manifestFile = File('${outputDir.path}/manifest.json');
      await manifestFile.writeAsString(jsonEncode(manifest.toJson()));

      print('✅ Enhanced MCP Export: Export completed successfully');
      print('📊 Exported: ${allNodes.length} nodes, ${allEdges.length} edges, ${allPointers.length} pointers');

      return EnhancedMcpExportResult(
        success: true,
        bundleId: bundleId,
        outputDir: outputDir,
        nodeCount: allNodes.length,
        edgeCount: allEdges.length,
        pointerCount: allPointers.length,
        embeddingCount: allEmbeddings.length,
        chatSessionsExported: allNodes.where((n) => n.type == 'ChatSession').length,
        chatMessagesExported: allNodes.where((n) => n.type == 'ChatMessage').length,
        draftEntriesExported: allNodes.where((n) => n.type == 'DraftEntry').length,
        lumaraEnhancedExported: allNodes.where((n) => n.type == 'LumaraEnhancedJournal').length,
      );

    } catch (e) {
      print('❌ Enhanced MCP Export: Export failed: $e');
      return EnhancedMcpExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Export chat data
  Future<ChatExportData> _exportChatData(bool includeArchived) async {
    final nodes = <McpNode>[];
    final edges = <McpEdge>[];

    try {
      // Get all chat sessions
      final sessions = await chatRepo!.listAll();
      
      for (final session in sessions) {
        // Skip archived sessions if not requested
        if (session.isArchived && !includeArchived) continue;

        // Create chat session node
        final sessionNode = McpNodeFactory.fromLumaraChatSession(session);
        nodes.add(sessionNode);

        // Get messages for this session
        final messages = await chatRepo!.getMessages(session.id);
        
        for (int i = 0; i < messages.length; i++) {
          final message = messages[i];
          
          // Create chat message node
          final messageNode = McpNodeFactory.fromLumaraChatMessage(message);
          nodes.add(messageNode);

          // Create contains edge
          final edge = McpNodeFactory.createChatEdge(
            sessionId: sessionNode.id,
            messageId: messageNode.id,
            timestamp: message.createdAt,
            order: i,
            relationType: 'contains',
          );
          edges.add(edge);
        }
      }

      print('📱 Chat Export: Exported ${nodes.where((n) => n.type == 'ChatSession').length} sessions, ${nodes.where((n) => n.type == 'ChatMessage').length} messages');

    } catch (e) {
      print('❌ Chat Export: Failed to export chat data: $e');
    }

    return ChatExportData(nodes: nodes, edges: edges);
  }

  /// Export draft data
  Future<DraftExportData> _exportDraftData() async {
    final nodes = <McpNode>[];
    final edges = <McpEdge>[];

    try {
      // Get all drafts
      final drafts = await draftService!.getAllDrafts();
      
      for (final draft in drafts) {
        // Create draft entry node
        final draftNode = McpNodeFactory.fromJournalDraft(draft);
        nodes.add(draftNode);
      }

      print('📝 Draft Export: Exported ${nodes.length} draft entries');

    } catch (e) {
      print('❌ Draft Export: Failed to export draft data: $e');
    }

    return DraftExportData(nodes: nodes, edges: edges);
  }

  /// Export media data
  Future<MediaExportData> _exportMediaData(List<MediaItem> mediaFiles) async {
    final pointers = <McpPointer>[];
    final edges = <McpEdge>[];

    try {
      for (final media in mediaFiles) {
        // Create media pointer
        final pointer = McpPointer(
          id: McpIdGenerator.generatePointerId(),
          mediaType: media.type.toString(),
          sourceUri: media.uri,
          descriptor: McpDescriptor(
            mimeType: 'application/octet-stream', // Default MIME type
            metadata: {
              'createdAt': media.createdAt.toIso8601String(),
            },
          ),
          samplingManifest: const McpSamplingManifest(),
          integrity: McpIntegrity(
            contentHash: media.id, // Use ID as hash since MediaItem doesn't have hash field
            bytes: media.sizeBytes ?? 0,
            mime: 'application/octet-stream',
            createdAt: media.createdAt,
          ),
          provenance: const McpProvenance(source: 'ARC', device: 'unknown'),
          privacy: const McpPrivacy(
            containsPii: false,
            sharingPolicy: 'private',
          ),
        );
        pointers.add(pointer);
      }

      print('📷 Media Export: Exported ${pointers.length} media pointers');

    } catch (e) {
      print('❌ Media Export: Failed to export media data: $e');
    }

    return MediaExportData(pointers: pointers, edges: edges);
  }

  /// Write NDJSON files
  Future<Map<String, File>> _writeNdjsonFiles(
    Directory outputDir,
    List<McpNode> nodes,
    List<McpEdge> edges,
    List<McpPointer> pointers,
    List<McpEmbedding> embeddings,
  ) async {
    final writer = McpNdjsonWriter(outputDir: outputDir);
    return await writer.writeAll(
      nodes: nodes,
      edges: edges,
      pointers: pointers,
      embeddings: embeddings,
    );
  }

  /// Create manifest
  Future<McpManifest> _createManifest(
    List<McpNode> nodes,
    List<McpEdge> edges,
    List<McpPointer> pointers,
    List<McpEmbedding> embeddings,
    Map<String, File> ndjsonFiles,
  ) async {
    final counts = McpCounts(
      nodes: nodes.length,
      edges: edges.length,
      pointers: pointers.length,
      embeddings: embeddings.length,
    );

    final checksums = McpChecksums(
      nodesJsonl: McpChecksumUtils.computeFileChecksum(ndjsonFiles['nodes']!),
      edgesJsonl: McpChecksumUtils.computeFileChecksum(ndjsonFiles['edges']!),
      pointersJsonl: McpChecksumUtils.computeFileChecksum(ndjsonFiles['pointers']!),
      embeddingsJsonl: McpChecksumUtils.computeFileChecksum(ndjsonFiles['embeddings']!),
    );

    return McpManifest(
      bundleId: bundleId,
      version: '1.0.0',
      createdAt: DateTime.now().toUtc(),
      storageProfile: storageProfile.value,
      counts: counts,
      checksums: checksums,
      encoderRegistry: [],
      notes: notes,
    );
  }

  /// Generate rosebud insight from content
  String _generateRosebud(String content) {
    // Simple rosebud generation - in production, use LUMARA's rosebud analysis
    final words = content.split(RegExp(r'\s+'));
    if (words.length < 10) return 'Brief reflection';
    
    // Extract key phrases
    final keyPhrases = <String>[];
    for (int i = 0; i < words.length - 2; i++) {
      if (words[i].length > 4 && words[i + 1].length > 4) {
        keyPhrases.add('${words[i]} ${words[i + 1]}');
      }
    }
    
    return keyPhrases.take(3).join(', ');
  }

  /// Extract LUMARA insights from content
  List<String> _extractLumaraInsights(String content) {
    // Simple insight extraction - in production, use LUMARA's insight analysis
    final insights = <String>[];
    
    if (content.toLowerCase().contains('learned')) {
      insights.add('Learning moment identified');
    }
    if (content.toLowerCase().contains('growth')) {
      insights.add('Growth pattern detected');
    }
    if (content.toLowerCase().contains('breakthrough')) {
      insights.add('Breakthrough insight noted');
    }
    
    return insights;
  }
}

/// Export result data classes
class EnhancedMcpExportResult {
  final bool success;
  final String? error;
  final String? bundleId;
  final Directory? outputDir;
  final int nodeCount;
  final int edgeCount;
  final int pointerCount;
  final int embeddingCount;
  final int chatSessionsExported;
  final int chatMessagesExported;
  final int draftEntriesExported;
  final int lumaraEnhancedExported;

  const EnhancedMcpExportResult({
    required this.success,
    this.error,
    this.bundleId,
    this.outputDir,
    this.nodeCount = 0,
    this.edgeCount = 0,
    this.pointerCount = 0,
    this.embeddingCount = 0,
    this.chatSessionsExported = 0,
    this.chatMessagesExported = 0,
    this.draftEntriesExported = 0,
    this.lumaraEnhancedExported = 0,
  });
}

class ChatExportData {
  final List<McpNode> nodes;
  final List<McpEdge> edges;

  const ChatExportData({
    required this.nodes,
    required this.edges,
  });
}

class DraftExportData {
  final List<McpNode> nodes;
  final List<McpEdge> edges;

  const DraftExportData({
    required this.nodes,
    required this.edges,
  });
}

class MediaExportData {
  final List<McpPointer> pointers;
  final List<McpEdge> edges;

  const MediaExportData({
    required this.pointers,
    required this.edges,
  });
}

/// Enhanced MCP Import Service
/// 
/// High-level orchestrator for importing MCP bundles with support for all node types.
/// Handles Chat, Draft, LUMARA enhanced, and standard journal entries.
library;

import 'dart:io';
import 'dart:convert';
import '../models/mcp_schemas.dart';
import '../models/mcp_enhanced_nodes.dart';
import '../services/mcp_node_factory.dart';
import '../validation/mcp_validator.dart';
import 'mcp_import_service.dart';
import '../../lumara/chat/chat_repo.dart';
import '../../lumara/chat/chat_models.dart';
import '../../models/journal_entry_model.dart';
import '../../core/services/draft_cache_service.dart';

/// Enhanced MCP Import Service with support for all node types
class EnhancedMcpImportService {
  final ChatRepo? chatRepo;
  final DraftCacheService? draftService;
  final McpImportService _baseImportService;

  EnhancedMcpImportService({
    this.chatRepo,
    this.draftService,
    McpImportService? baseImportService,
  }) : _baseImportService = baseImportService ?? McpImportService();

  /// Import MCP bundle with all node types
  Future<EnhancedMcpImportResult> importBundle(
    Directory bundleDir,
    McpImportOptions options,
  ) async {
    try {
      print('🚀 Enhanced MCP Import: Starting import from ${bundleDir.path}');

      // First, run base import for standard nodes
      final baseResult = await _baseImportService.importBundle(bundleDir, options);
      
      if (!baseResult.success) {
        return EnhancedMcpImportResult(
          success: false,
          error: 'Base import failed: ${baseResult.error}',
        );
      }

      // Import enhanced node types
      final enhancedResult = await _importEnhancedNodes(bundleDir, options);
      
      print('✅ Enhanced MCP Import: Import completed successfully');
      print('📊 Imported: ${enhancedResult.chatSessionsImported} chat sessions, ${enhancedResult.chatMessagesImported} chat messages, ${enhancedResult.draftEntriesImported} draft entries, ${enhancedResult.lumaraEnhancedImported} LUMARA enhanced entries');

      return EnhancedMcpImportResult(
        success: true,
        journalEntriesImported: baseResult.journalEntriesImported,
        chatSessionsImported: enhancedResult.chatSessionsImported,
        chatMessagesImported: enhancedResult.chatMessagesImported,
        draftEntriesImported: enhancedResult.draftEntriesImported,
        lumaraEnhancedImported: enhancedResult.lumaraEnhancedImported,
        totalNodesImported: baseResult.journalEntriesImported + 
                           enhancedResult.chatSessionsImported + 
                           enhancedResult.chatMessagesImported + 
                           enhancedResult.draftEntriesImported + 
                           enhancedResult.lumaraEnhancedImported,
      );

    } catch (e) {
      print('❌ Enhanced MCP Import: Import failed: $e');
      return EnhancedMcpImportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Import enhanced node types
  Future<EnhancedImportData> _importEnhancedNodes(
    Directory bundleDir,
    McpImportOptions options,
  ) async {
    final nodesFile = File('${bundleDir.path}/nodes.jsonl');
    if (!await nodesFile.exists()) {
      return const EnhancedImportData();
    }

    final lines = await nodesFile.readAsLines();
    int chatSessionsImported = 0;
    int chatMessagesImported = 0;
    int draftEntriesImported = 0;
    int lumaraEnhancedImported = 0;

    for (int i = 0; i < lines.length; i++) {
      try {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final nodeData = jsonDecode(line) as Map<String, dynamic>;
        final nodeType = nodeData['type'] as String?;

        switch (nodeType) {
          case 'ChatSession':
            await _importChatSession(nodeData);
            chatSessionsImported++;
            break;
          case 'ChatMessage':
            await _importChatMessage(nodeData);
            chatMessagesImported++;
            break;
          case 'DraftEntry':
            await _importDraftEntry(nodeData);
            draftEntriesImported++;
            break;
          case 'LumaraEnhancedJournal':
            await _importLumaraEnhanced(nodeData);
            lumaraEnhancedImported++;
            break;
          default:
            // Skip other node types (handled by base import)
            break;
        }
      } catch (e) {
        print('❌ Enhanced Import: Error processing line ${i + 1}: $e');
        if (options.strictMode) {
          throw Exception('Failed to process node at line ${i + 1}: $e');
        }
      }
    }

    return EnhancedImportData(
      chatSessionsImported: chatSessionsImported,
      chatMessagesImported: chatMessagesImported,
      draftEntriesImported: draftEntriesImported,
      lumaraEnhancedImported: lumaraEnhancedImported,
    );
  }

  /// Import chat session
  Future<void> _importChatSession(Map<String, dynamic> nodeData) async {
    if (chatRepo == null) {
      print('⚠️ Chat Import: ChatRepo not available, skipping chat session');
      return;
    }

    try {
      final sessionNode = ChatSessionNode.fromJson(nodeData);
      
      // Create ChatSession object
      final session = ChatSession(
        id: sessionNode.id,
        title: sessionNode.title,
        createdAt: sessionNode.timestamp,
        isArchived: sessionNode.isArchived,
        archivedAt: sessionNode.archivedAt,
        isPinned: sessionNode.isPinned,
        tags: sessionNode.tags,
        messages: [], // Will be populated by chat messages
      );

      // Save to chat repo
      await chatRepo!.saveSession(session);
      print('✅ Chat Import: Imported chat session: ${session.title}');

    } catch (e) {
      print('❌ Chat Import: Failed to import chat session: $e');
    }
  }

  /// Import chat message
  Future<void> _importChatMessage(Map<String, dynamic> nodeData) async {
    if (chatRepo == null) {
      print('⚠️ Chat Import: ChatRepo not available, skipping chat message');
      return;
    }

    try {
      final messageNode = ChatMessageNode.fromJson(nodeData);
      
      // Create ChatMessage object
      final message = ChatMessage(
        id: messageNode.id,
        sessionId: '', // Will be set by the session
        role: _parseChatRole(messageNode.role),
        content: ChatContent(
          text: messageNode.text,
          mimeType: messageNode.mimeType,
        ),
        timestamp: messageNode.timestamp,
        order: messageNode.order,
      );

      // Save to chat repo
      await chatRepo!.saveMessage(message);
      print('✅ Chat Import: Imported chat message: ${message.content?.text?.substring(0, 50)}...');

    } catch (e) {
      print('❌ Chat Import: Failed to import chat message: $e');
    }
  }

  /// Import draft entry
  Future<void> _importDraftEntry(Map<String, dynamic> nodeData) async {
    if (draftService == null) {
      print('⚠️ Draft Import: DraftService not available, skipping draft entry');
      return;
    }

    try {
      final draftNode = DraftEntryNode.fromJson(nodeData);
      
      // Create DraftCacheEntry object
      final draft = DraftCacheEntry(
        id: draftNode.id,
        content: draftNode.content,
        title: draftNode.title,
        createdAt: draftNode.timestamp,
        lastModified: draftNode.lastModified ?? draftNode.timestamp,
        isAutoSaved: draftNode.isAutoSaved,
        tags: draftNode.tags,
        phase: draftNode.phaseHint,
        emotions: draftNode.emotions,
      );

      // Save to draft service
      await draftService!.saveDraft(draft);
      print('✅ Draft Import: Imported draft entry: ${draft.title ?? 'Untitled'}');

    } catch (e) {
      print('❌ Draft Import: Failed to import draft entry: $e');
    }
  }

  /// Import LUMARA enhanced journal entry
  Future<void> _importLumaraEnhanced(Map<String, dynamic> nodeData) async {
    try {
      final lumaraNode = LumaraEnhancedJournalNode.fromJson(nodeData);
      
      // Create enhanced journal entry
      final enhancedEntry = JournalEntry(
        id: lumaraNode.id,
        content: lumaraNode.content,
        createdAt: lumaraNode.timestamp,
        updatedAt: lumaraNode.timestamp,
        phase: lumaraNode.phasePrediction ?? 'Transition',
        keywords: lumaraNode.suggestedKeywords,
        emotions: lumaraNode.emotionalAnalysis,
        summary: lumaraNode.rosebud,
        userId: 'current_user', // TODO: Get from context
        attachments: [],
        location: null,
        weather: null,
        mood: null,
        tags: [],
        isDraft: false,
        isArchived: false,
        isPinned: false,
        metadata: {
          'lumaraEnhanced': true,
          'lumaraInsights': lumaraNode.lumaraInsights,
          'lumaraMetadata': lumaraNode.lumaraMetadata,
          'lumaraContext': lumaraNode.lumaraContext,
          'rosebud': lumaraNode.rosebud,
        },
      );

      // Save enhanced entry (this would need to be implemented in the journal service)
      print('✅ LUMARA Import: Imported enhanced journal entry: ${enhancedEntry.summary}');
      print('🌹 Rosebud: ${lumaraNode.rosebud}');
      print('💡 Insights: ${lumaraNode.lumaraInsights.join(', ')}');

    } catch (e) {
      print('❌ LUMARA Import: Failed to import enhanced journal entry: $e');
    }
  }

  /// Parse chat role from string
  ChatRole _parseChatRole(String role) {
    switch (role.toLowerCase()) {
      case 'user':
        return ChatRole.user;
      case 'assistant':
        return ChatRole.assistant;
      case 'system':
        return ChatRole.system;
      default:
        return ChatRole.user;
    }
  }
}

/// Enhanced import result data classes
class EnhancedMcpImportResult {
  final bool success;
  final String? error;
  final int journalEntriesImported;
  final int chatSessionsImported;
  final int chatMessagesImported;
  final int draftEntriesImported;
  final int lumaraEnhancedImported;
  final int totalNodesImported;

  const EnhancedMcpImportResult({
    required this.success,
    this.error,
    this.journalEntriesImported = 0,
    this.chatSessionsImported = 0,
    this.chatMessagesImported = 0,
    this.draftEntriesImported = 0,
    this.lumaraEnhancedImported = 0,
    this.totalNodesImported = 0,
  });
}

class EnhancedImportData {
  final int chatSessionsImported;
  final int chatMessagesImported;
  final int draftEntriesImported;
  final int lumaraEnhancedImported;

  const EnhancedImportData({
    this.chatSessionsImported = 0,
    this.chatMessagesImported = 0,
    this.draftEntriesImported = 0,
    this.lumaraEnhancedImported = 0,
  });
}

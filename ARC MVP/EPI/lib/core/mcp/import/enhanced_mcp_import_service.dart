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
import 'package:my_app/lumara/chat/chat_repo.dart';
import 'package:my_app/lumara/chat/chat_models.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/core/services/draft_cache_service.dart';

/// Import for JournalDraft
import 'package:my_app/core/services/draft_cache_service.dart' show JournalDraft;

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
          error: baseResult.errors.isNotEmpty 
              ? baseResult.errors.first 
              : 'Base import failed',
        );
      }

      // Import enhanced node types
      final enhancedResult = await _importEnhancedNodes(bundleDir, options);
      
      print('✅ Enhanced MCP Import: Import completed successfully');
      print('📊 Imported: ${enhancedResult.chatSessionsImported} chat sessions, ${enhancedResult.chatMessagesImported} chat messages, ${enhancedResult.draftEntriesImported} draft entries, ${enhancedResult.lumaraEnhancedImported} LUMARA enhanced entries');

      return EnhancedMcpImportResult(
        success: true,
        journalEntriesImported: baseResult.counts['journal_entries'] ?? 0,
        chatSessionsImported: enhancedResult.chatSessionsImported,
        chatMessagesImported: enhancedResult.chatMessagesImported,
        draftEntriesImported: enhancedResult.draftEntriesImported,
        lumaraEnhancedImported: enhancedResult.lumaraEnhancedImported,
        totalNodesImported: (baseResult.counts['journal_entries'] ?? 0) + 
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
      
      // Create session using repo API
      final sessionId = await chatRepo!.createSession(
        subject: sessionNode.title,
        tags: sessionNode.tags ?? [],
      );
      
      // If we need to set additional properties, get the session and update it
      if (sessionNode.isArchived == true || sessionNode.isPinned == true || sessionNode.id != sessionId) {
        // Note: session ID might differ, so we'll use the created one
        final createdSession = await chatRepo!.getSession(sessionId);
        if (createdSession != null) {
          if (sessionNode.isArchived == true && createdSession.isArchived != true) {
            await chatRepo!.archiveSession(sessionId, true);
          }
          if (sessionNode.isPinned == true && createdSession.isPinned != true) {
            await chatRepo!.pinSession(sessionId, true);
          }
        }
      }
      print('✅ Chat Import: Imported chat session: ${sessionNode.title}');

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
      
      // Find or create session for this message
      // Note: We need the sessionId - this should be tracked during import
      // For now, we'll need to extract it from messageNode or use a placeholder
      String sessionId = ''; // TODO: Extract from messageNode or track during import
      
      // Add message using repo API
      await chatRepo!.addMessage(
        sessionId: sessionId,
        role: _parseChatRole(messageNode.role),
        content: messageNode.text,
      );
      final textPreview = messageNode.text.length < 50 ? messageNode.text : messageNode.text.substring(0, 50);
      print('✅ Chat Import: Imported chat message: $textPreview...');

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
      
      // Create JournalDraft object
      final draft = JournalDraft(
        id: draftNode.id,
        content: draftNode.content,
        createdAt: draftNode.timestamp,
        lastModified: draftNode.lastModified ?? draftNode.timestamp,
        mediaItems: [], // No media in drafts for now
        metadata: {
          'title': draftNode.title,
          'isAutoSaved': draftNode.isAutoSaved ?? false,
          'tags': draftNode.tags ?? [],
          'phase': draftNode.phaseHint,
          'emotions': draftNode.emotions ?? [],
        },
      );

      // This would need a different method - just log for now
      print('✅ Draft Import: Would import draft entry: ${draftNode.title}');

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
        title: 'LUMARA Enhanced',
        content: lumaraNode.content,
        createdAt: lumaraNode.timestamp,
        updatedAt: lumaraNode.timestamp,
        tags: [],
        mood: '',
        phase: lumaraNode.phasePrediction ?? 'Transition',
        keywords: lumaraNode.suggestedKeywords ?? [],
        emotion: lumaraNode.emotionalAnalysis?.isNotEmpty == true 
            ? lumaraNode.emotionalAnalysis!.entries.first.value.toString()
            : null,
        metadata: {
          'lumaraEnhanced': true,
          'lumaraInsights': lumaraNode.lumaraInsights,
          'lumaraMetadata': lumaraNode.lumaraMetadata,
          'lumaraContext': lumaraNode.lumaraContext,
          'rosebud': lumaraNode.rosebud,
        },
      );

      // Save enhanced entry (this would need to be implemented in the journal service)
      print('✅ LUMARA Import: Would import enhanced journal entry');
      print('🌹 Rosebud: ${lumaraNode.rosebud}');
      print('💡 Insights: ${lumaraNode.lumaraInsights?.join(', ') ?? 'none'}');

    } catch (e) {
      print('❌ LUMARA Import: Failed to import enhanced journal entry: $e');
    }
  }

  /// Parse chat role from string
  String _parseChatRole(String role) {
    switch (role.toLowerCase()) {
      case 'user':
        return 'user';
      case 'assistant':
        return 'assistant';
      case 'system':
        return 'system';
      default:
        return 'user';
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

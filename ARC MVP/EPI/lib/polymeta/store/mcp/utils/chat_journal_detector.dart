/// Utility functions for detecting and separating chat messages from journal entries
/// in MCP data structures. All functions are pure and unit-testable.

import 'package:my_app/polymeta/store/mcp/models/mcp_schemas.dart';
import 'package:my_app/models/journal_entry_model.dart';

class ChatJournalDetector {
  /// Detect if an MCP node represents a chat message
  static bool isChatMessageNode(McpNode node) {
    // Check metadata for explicit chat indicators
    if (node.metadata != null) {
      final source = node.metadata!['source'] as String?;
      if (source == 'LUMARA_Chat' || source == 'LUMARA_Assistant') {
        return true;
      }
      
      // Check for entry_type indicator
      final entryType = node.metadata!['entry_type'] as String?;
      if (entryType == 'user_input' && _isShortContent(node)) {
        return true;
      }
    }
    
    // Check content for LUMARA assistant messages
    final content = _extractContent(node)?.toLowerCase() ?? '';
    if (_isLumaraAssistantMessage(content)) {
      return true;
    }
    
    // Check for chat-like patterns
    if (_isChatLikePattern(content)) {
      return true;
    }
    
    return false;
  }

  /// Detect if a JournalEntry represents a chat message
  static bool isChatMessageEntry(JournalEntry entry) {
    // Check metadata for chat indicators
    if (entry.metadata != null) {
      final source = entry.metadata!['source'] as String?;
      if (source == 'LUMARA_Chat' || source == 'LUMARA_Assistant') {
        return true;
      }
    }
    
    // Check content for LUMARA assistant messages
    final content = entry.content.toLowerCase();
    if (_isLumaraAssistantMessage(content)) {
      return true;
    }
    
    // Check for chat-like patterns
    if (_isChatLikePattern(content)) {
      return true;
    }
    
    return false;
  }

  /// Separate a list of JournalEntries into chat and journal
  static (List<JournalEntry> chatMessages, List<JournalEntry> journalEntries) 
      separateJournalEntries(List<JournalEntry> entries) {
    final chatMessages = <JournalEntry>[];
    final journalEntries = <JournalEntry>[];
    
    for (final entry in entries) {
      if (isChatMessageEntry(entry)) {
        chatMessages.add(entry);
      } else {
        journalEntries.add(entry);
      }
    }
    
    return (chatMessages, journalEntries);
  }

  /// Separate a list of MCP nodes into chat and journal
  static (List<McpNode> chatNodes, List<McpNode> journalNodes) 
      separateMcpNodes(List<McpNode> nodes) {
    final chatNodes = <McpNode>[];
    final journalNodes = <McpNode>[];
    
    for (final node in nodes) {
      if (node.type == 'journal_entry') {
        if (isChatMessageNode(node)) {
          chatNodes.add(node);
        } else {
          journalNodes.add(node);
        }
      } else {
        // Non-journal nodes go to journal by default
        journalNodes.add(node);
      }
    }
    
    return (chatNodes, journalNodes);
  }

  /// Extract content from MCP node with fallback hierarchy
  static String? _extractContent(McpNode node) {
    // Try contentSummary first
    if (node.contentSummary != null && node.contentSummary!.isNotEmpty) {
      return node.contentSummary!.trim();
    }
    
    // Try metadata.content
    if (node.metadata != null) {
      final metaContent = node.metadata!['content'] as String?;
      if (metaContent != null && metaContent.isNotEmpty) {
        return metaContent.trim();
      }
      
      // Try journal_entry.content
      final journalMeta = node.metadata!['journal_entry'] as Map<String, dynamic>?;
      if (journalMeta != null) {
        final journalContent = journalMeta['content'] as String?;
        if (journalContent != null && journalContent.isNotEmpty) {
          return journalContent.trim();
        }
      }
    }
    
    return null;
  }

  /// Check if content is short (likely chat message)
  static bool _isShortContent(McpNode node) {
    final content = _extractContent(node) ?? '';
    return content.length < 200;
  }

  /// Check if content is a LUMARA assistant message
  static bool _isLumaraAssistantMessage(String content) {
    return content.contains('i\'m lumara') || 
           content.contains('your personal assistant') ||
           content.contains('what would you like to know') ||
           content.contains('i\'m here to help') ||
           content.contains('how can i assist') ||
           content.contains('let me help you');
  }

  /// Check if content matches chat-like patterns
  static bool _isChatLikePattern(String content) {
    return content.startsWith('tell me') || 
           content.startsWith('what do you think') ||
           content.startsWith('can you help') ||
           content.startsWith('how do i') ||
           content.startsWith('what should i') ||
           content.startsWith('i need help') ||
           content.startsWith('explain') ||
           content.startsWith('why') ||
           content.startsWith('how') ||
           content.startsWith('what');
  }
}

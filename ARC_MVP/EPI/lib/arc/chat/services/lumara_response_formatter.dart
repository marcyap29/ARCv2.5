// lib/lumara/services/lumara_response_formatter.dart
// Format LUMARA responses with visual distinction

import '../models/reflective_node.dart';

class LumaraResponseFormatter {
  String formatResponse(ReflectivePromptResponse response) {
    final buffer = StringBuffer();
    
    // Header with sparkle icon
    buffer.writeln('✨ Reflection\n');
    
    // Context if needed
    if (response.matchedNodes.isNotEmpty) {
      final topMatch = response.matchedNodes.first;
      buffer.writeln('_Connected to ${_formatSourceType(topMatch.sourceType)} from ${_formatDate(topMatch.approxDate)}_\n');
    }
    
    // Prompts
    for (int i = 0; i < response.reflectivePrompts.length; i++) {
      buffer.writeln(response.reflectivePrompts[i]);
      if (i < response.reflectivePrompts.length - 1) {
        buffer.writeln('\n---\n');
      }
    }
    
    // Cross-modal patterns (optional)
    if (response.crossModalPatterns?.isNotEmpty == true) {
      buffer.writeln('\n_Patterns detected: ${response.crossModalPatterns!.join(', ')}_');
    }
    
    return buffer.toString();
  }
  
  String formatForInsertion(String formatted) {
    // Wrap in italic markdown or special markers
    return '\n\n_${formatted}_\n\n';
  }
  
  String _formatSourceType(NodeType type) {
    switch (type) {
      case NodeType.journal:
        return 'journal entry';
      case NodeType.draft:
        return 'draft';
      case NodeType.chat:
        return 'chat';
      case NodeType.chatSession:
        return 'chat session';
      case NodeType.chatMessage:
        return 'chat message';
      case NodeType.photo:
        return 'photo';
      case NodeType.audio:
        return 'voice note';
      case NodeType.video:
        return 'video';
      case NodeType.phaseRegime:
        return 'phase regime';
    }
  }
  
  String _formatDate(DateTime? date) {
    if (date == null) return 'a past moment';
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 7) {
      return 'this week';
    } else if (difference.inDays < 30) {
      return 'last month';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).round();
      return '$months months ago';
    } else {
      final years = (difference.inDays / 365).round();
      return '$years years ago';
    }
  }
}
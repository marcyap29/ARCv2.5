/// Enhanced MCP Validator
/// 
/// Provides runtime validation for all MCP record types including
/// Chat, Draft, LUMARA enhanced, and standard journal entries.
library;

import '../models/mcp_schemas.dart';
import '../models/mcp_enhanced_nodes.dart';
import 'mcp_validator.dart';

/// Enhanced MCP Validator with support for all node types
class EnhancedMcpValidator {
  /// Validate a chat session node
  static ValidationResult validateChatSession(ChatSessionNode node) {
    final errors = <String>[];
    final warnings = <String>[];

    // Required fields
    if (node.id.isEmpty) {
      errors.add('Chat session ID cannot be empty');
    }
    if (!node.id.startsWith('session:')) {
      warnings.add('Chat session ID should start with "session:"');
    }
    if (node.title.isEmpty) {
      errors.add('Chat session title cannot be empty');
    }

    // Timestamp validation
    if (node.timestamp.isUtc == false) {
      errors.add('Timestamp must be in UTC');
    }

    // Metadata validation
    if (node.messageCount < 0) {
      errors.add('Message count cannot be negative');
    }
    if (node.isArchived && node.archivedAt == null) {
      warnings.add('Archived session should have archivedAt timestamp');
    }

    // Retention policy validation
    final validRetentionPolicies = [
      'auto-archive-30d',
      'auto-archive-90d',
      'indefinite',
      'manual',
    ];
    if (!validRetentionPolicies.contains(node.retention)) {
      warnings.add('Unknown retention policy: ${node.retention}');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validate a chat message node
  static ValidationResult validateChatMessage(ChatMessageNode node) {
    final errors = <String>[];
    final warnings = <String>[];

    // Required fields
    if (node.id.isEmpty) {
      errors.add('Chat message ID cannot be empty');
    }
    if (!node.id.startsWith('msg:')) {
      warnings.add('Chat message ID should start with "msg:"');
    }
    if (node.role.isEmpty) {
      errors.add('Chat message role cannot be empty');
    }
    if (node.text.isEmpty) {
      errors.add('Chat message text cannot be empty');
    }

    // Role validation
    final validRoles = ['user', 'assistant', 'system'];
    if (!validRoles.contains(node.role)) {
      errors.add('Invalid chat message role: ${node.role}');
    }

    // Timestamp validation
    if (node.timestamp.isUtc == false) {
      errors.add('Timestamp must be in UTC');
    }

    // MIME type validation
    if (node.mimeType.isEmpty) {
      warnings.add('MIME type should be specified');
    }

    // Order validation
    if (node.order < 0) {
      warnings.add('Message order should be non-negative');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validate a draft entry node
  static ValidationResult validateDraftEntry(DraftEntryNode node) {
    final errors = <String>[];
    final warnings = <String>[];

    // Required fields
    if (node.id.isEmpty) {
      errors.add('Draft entry ID cannot be empty');
    }
    if (!node.id.startsWith('draft:')) {
      warnings.add('Draft entry ID should start with "draft:"');
    }
    if (node.content.isEmpty) {
      errors.add('Draft entry content cannot be empty');
    }

    // Timestamp validation
    if (node.timestamp.isUtc == false) {
      errors.add('Timestamp must be in UTC');
    }

    // Content validation
    if (node.wordCount < 0) {
      errors.add('Word count cannot be negative');
    }
    if (node.wordCount == 0 && node.content.isNotEmpty) {
      warnings.add('Word count is 0 but content is not empty');
    }

    // Last modified validation
    if (node.lastModified != null && node.lastModified!.isBefore(node.timestamp)) {
      errors.add('Last modified cannot be before creation timestamp');
    }

    // Phase hint validation
    if (node.phaseHint != null) {
      final validPhases = [
        'Discovery', 'Expansion', 'Transition',
        'Consolidation', 'Recovery', 'Breakthrough'
      ];
      if (!validPhases.contains(node.phaseHint)) {
        warnings.add('Unknown phase hint: ${node.phaseHint}');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validate a LUMARA enhanced journal node
  static ValidationResult validateLumaraEnhancedJournal(LumaraEnhancedJournalNode node) {
    final errors = <String>[];
    final warnings = <String>[];

    // Required fields
    if (node.id.isEmpty) {
      errors.add('LUMARA enhanced journal ID cannot be empty');
    }
    if (!node.id.startsWith('lumara:')) {
      warnings.add('LUMARA enhanced journal ID should start with "lumara:"');
    }
    if (node.content.isEmpty) {
      errors.add('LUMARA enhanced journal content cannot be empty');
    }

    // Timestamp validation
    if (node.timestamp.isUtc == false) {
      errors.add('Timestamp must be in UTC');
    }

    // LUMARA specific validation
    if (node.rosebud != null && node.rosebud!.isEmpty) {
      warnings.add('Rosebud should not be empty if provided');
    }
    if (node.lumaraInsights.isEmpty) {
      warnings.add('LUMARA enhanced journal should have insights');
    }
    if (node.suggestedKeywords.isEmpty) {
      warnings.add('LUMARA enhanced journal should have suggested keywords');
    }

    // Phase prediction validation
    if (node.phasePrediction != null) {
      final validPhases = [
        'Discovery', 'Expansion', 'Transition',
        'Consolidation', 'Recovery', 'Breakthrough'
      ];
      if (!validPhases.contains(node.phasePrediction)) {
        warnings.add('Unknown phase prediction: ${node.phasePrediction}');
      }
    }

    // Emotional analysis validation
    for (final emotion in node.emotionalAnalysis.keys) {
      final value = node.emotionalAnalysis[emotion]!;
      if (value < 0.0 || value > 1.0) {
        errors.add('Emotional analysis value for $emotion must be between 0.0 and 1.0');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validate a chat edge
  static ValidationResult validateChatEdge(ChatEdge edge) {
    final errors = <String>[];
    final warnings = <String>[];

    // Required fields
    if (edge.source.isEmpty) {
      errors.add('Chat edge source cannot be empty');
    }
    if (edge.target.isEmpty) {
      errors.add('Chat edge target cannot be empty');
    }
    if (edge.relation.isEmpty) {
      errors.add('Chat edge relation cannot be empty');
    }

    // ID validation
    if (!edge.source.startsWith('session:')) {
      warnings.add('Chat edge source should be a session ID');
    }
    if (!edge.target.startsWith('msg:')) {
      warnings.add('Chat edge target should be a message ID');
    }

    // Relation validation
    final validRelations = ['contains', 'precedes', 'follows', 'related_to'];
    if (!validRelations.contains(edge.relation)) {
      warnings.add('Unknown chat edge relation: ${edge.relation}');
    }

    // Order validation
    if (edge.order != null && edge.order! < 0) {
      warnings.add('Chat edge order should be non-negative');
    }

    // Timestamp validation
    if (edge.timestamp.isUtc == false) {
      errors.add('Timestamp must be in UTC');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validate any MCP node type
  static ValidationResult validateAnyNode(dynamic node) {
    if (node is ChatSessionNode) {
      return validateChatSession(node);
    } else if (node is ChatMessageNode) {
      return validateChatMessage(node);
    } else if (node is DraftEntryNode) {
      return validateDraftEntry(node);
    } else if (node is LumaraEnhancedJournalNode) {
      return validateLumaraEnhancedJournal(node);
    } else if (node is McpNode) {
      return McpValidator.validateNode(node);
    } else {
      return ValidationResult(
        isValid: false,
        errors: ['Unknown node type: ${node.runtimeType}'],
        warnings: [],
      );
    }
  }

  /// Validate any MCP edge type
  static ValidationResult validateAnyEdge(dynamic edge) {
    if (edge is ChatEdge) {
      return validateChatEdge(edge);
    } else if (edge is McpEdge) {
      return McpValidator.validateEdge(edge);
    } else {
      return ValidationResult(
        isValid: false,
        errors: ['Unknown edge type: ${edge.runtimeType}'],
        warnings: [],
      );
    }
  }

  /// Validate a complete MCP bundle with all node types
  static BundleValidationResult validateEnhancedBundle({
    required List<McpNode> nodes,
    required List<McpEdge> edges,
    required List<McpPointer> pointers,
    required List<McpEmbedding> embeddings,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // Validate all nodes
    for (final node in nodes) {
      final result = validateAnyNode(node);
      if (!result.isValid) {
        errors.addAll(result.errors.map((e) => 'Node ${node.id}: $e'));
      }
      warnings.addAll(result.warnings.map((w) => 'Node ${node.id}: $w'));
    }

    // Validate all edges
    for (final edge in edges) {
      final result = validateAnyEdge(edge);
      if (!result.isValid) {
        errors.addAll(result.errors.map((e) => 'Edge ${edge.source}->${edge.target}: $e'));
      }
      warnings.addAll(result.warnings.map((w) => 'Edge ${edge.source}->${edge.target}: $w'));
    }

    // Validate node type distribution
    final nodeTypeCounts = <String, int>{};
    for (final node in nodes) {
      nodeTypeCounts[node.type] = (nodeTypeCounts[node.type] ?? 0) + 1;
    }

    // Check for expected node type relationships
    final chatSessions = nodes.where((n) => n.type == 'ChatSession').length;
    final chatMessages = nodes.where((n) => n.type == 'ChatMessage').length;
    final draftEntries = nodes.where((n) => n.type == 'DraftEntry').length;
    final lumaraEnhanced = nodes.where((n) => n.type == 'LumaraEnhancedJournal').length;

    if (chatSessions > 0 && chatMessages == 0) {
      warnings.add('Chat sessions found but no chat messages');
    }
    if (chatMessages > 0 && chatSessions == 0) {
      warnings.add('Chat messages found but no chat sessions');
    }
    if (lumaraEnhanced > 0) {
      warnings.add('LUMARA enhanced entries found: $lumaraEnhanced');
    }
    if (draftEntries > 0) {
      warnings.add('Draft entries found: $draftEntries');
    }

    return BundleValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      nodeTypeCounts: nodeTypeCounts,
      totalNodes: nodes.length,
      totalEdges: edges.length,
      totalPointers: pointers.length,
      totalEmbeddings: embeddings.length,
    );
  }
}

/// Enhanced validation result with additional metadata
class BundleValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, int> nodeTypeCounts;
  final int totalNodes;
  final int totalEdges;
  final int totalPointers;
  final int totalEmbeddings;

  const BundleValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.nodeTypeCounts,
    required this.totalNodes,
    required this.totalEdges,
    required this.totalPointers,
    required this.totalEmbeddings,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Bundle Validation Result:');
    buffer.writeln('Valid: $isValid');
    buffer.writeln('Nodes: $totalNodes, Edges: $totalEdges, Pointers: $totalPointers, Embeddings: $totalEmbeddings');
    buffer.writeln('Node Types: $nodeTypeCounts');
    if (errors.isNotEmpty) {
      buffer.writeln('Errors:');
      for (final error in errors) {
        buffer.writeln('  - $error');
      }
    }
    if (warnings.isNotEmpty) {
      buffer.writeln('Warnings:');
      for (final warning in warnings) {
        buffer.writeln('  - $warning');
      }
    }
    return buffer.toString();
  }
}

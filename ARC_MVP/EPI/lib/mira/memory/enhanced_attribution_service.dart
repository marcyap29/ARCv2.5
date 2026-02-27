// l../mira/memory/enhanced_attribution_service.dart
// Enhanced attribution service supporting multiple source types and cross-references

import 'dart:collection';
import 'enhanced_attribution_schema.dart';
import 'conversation_context_service.dart';
import '../../arc/chat/data/models/lumara_message.dart';
import '../../arc/chat/services/lumara_reflection_settings_service.dart';

/// Enhanced attribution service for multi-source memory tracking
class EnhancedAttributionService {
  final Map<String, EnhancedResponseTrace> _responseTraces = {};
  final Map<String, List<EnhancedAttributionTrace>> _sourceAttributions = {};
  final Map<String, List<CrossReference>> _crossReferences = {};
  final Queue<String> _recentResponses = Queue<String>();

  static const int _maxTraceHistory = 1000;

  /// Record memory usage with multiple source types including current conversation
  Future<String> recordMultiSourceMemoryUsage({
    required String responseId,
    required String responseContent,
    required String currentUserMessage,
    required String model,
    required Map<String, dynamic> context,
    List<EnhancedAttributionTrace> traces = const [],
    List<Map<String, dynamic>> journalEntries = const [],
    List<LumaraMessage> chatMessages = const [],
    List<LumaraMessage> currentSessionMessages = const [], // NEW: Current conversation context
    List<Map<String, dynamic>> mediaReferences = const [],
    Map<String, dynamic> arcformData = const {},
    bool includeConversationContext = true,
  }) async {
    // Get user's LUMARA settings for attribution control
    final settingsService = LumaraReflectionSettingsService.instance;
    final similarityThreshold = await settingsService.getSimilarityThreshold();
    final maxMatches = await settingsService.getEffectiveMaxMatches();
    final lookbackYears = await settingsService.getEffectiveLookbackYears();
    final crossModalEnabled = await settingsService.isCrossModalEnabled();

    print('LUMARA Debug: [Enhanced Attribution] Using settings - threshold: $similarityThreshold, maxMatches: $maxMatches, lookback: ${lookbackYears}y, crossModal: $crossModalEnabled');

    final allTraces = <EnhancedAttributionTrace>[];
    final crossRefs = <CrossReference>[];

    // Add provided traces
    allTraces.addAll(traces);

    // PRIORITY 1: Generate current conversation context attributions (respect maxMatches)
    if (includeConversationContext && currentSessionMessages.isNotEmpty) {
      final conversationTraces = ConversationContextService.generateCurrentConversationAttributions(
        currentResponseId: responseId,
        currentSessionMessages: currentSessionMessages,
        currentUserMessage: currentUserMessage,
        lookbackLimit: maxMatches, // Use maxMatches to control conversation lookback
      );
      allTraces.addAll(conversationTraces);

      // Add conversation context summary
      final conversationSummary = ConversationContextService.generateConversationContextSummary(conversationTraces);
      context['conversation_context_summary'] = conversationSummary;
    }

    // PRIORITY 2: Generate journal entry attributions (respect maxMatches and similarity)
    int journalCount = 0;
    for (final entry in journalEntries) {
      if (journalCount >= maxMatches) break;

      final trace = _createJournalEntryAttribution(entry, responseId);

      // Apply similarity threshold check
      final relevanceScore = _calculateContentRelevance(
        entry['content'] as String? ?? '',
        currentUserMessage,
      );

      if (relevanceScore >= similarityThreshold) {
        allTraces.add(trace);
        journalCount++;

        // Check for cross-references with other content
        crossRefs.addAll(await _findCrossReferences(entry['id'] as String? ?? 'unknown', SourceType.journalEntry));
      }
    }

    // PRIORITY 3: Generate chat message attributions (respect maxMatches and similarity)
    int chatCount = 0;
    for (final message in chatMessages) {
      if (chatCount >= maxMatches) break;

      // Apply similarity threshold check
      final relevanceScore = _calculateContentRelevance(message.content, currentUserMessage);

      if (relevanceScore >= similarityThreshold) {
        final trace = _createChatMessageAttribution(message, responseId);
        allTraces.add(trace);
        chatCount++;

        crossRefs.addAll(await _findCrossReferences(message.id, SourceType.chatMessage));
      }
    }

    // PRIORITY 4: Generate multi-modal media attributions (if cross-modal enabled)
    if (crossModalEnabled) {
      print('LUMARA Debug: [Enhanced Attribution] Processing ${mediaReferences.length} media references');
      int mediaCount = 0;

      for (final media in mediaReferences) {
        if (mediaCount >= maxMatches) break;

        // For media, check OCR/transcript content if available for relevance
        final mediaContent = media['ocr_text'] as String? ??
                           media['transcript'] as String? ??
                           media['description'] as String? ?? '';

        final relevanceScore = mediaContent.isNotEmpty ?
          _calculateContentRelevance(mediaContent, currentUserMessage) : 0.3; // Default relevance for media

        if (relevanceScore >= (similarityThreshold * 0.8)) { // Lower threshold for media content
          final trace = _createMediaAttribution(media, responseId);
          allTraces.add(trace);
          mediaCount++;

          // Add cross-references for media content
          final mediaId = media['id'] as String? ?? 'unknown_media';
          final mediaType = _getMediaSourceType(media['type']);
          crossRefs.addAll(await _findCrossReferences(mediaId, mediaType));
        }
      }
    } else {
      print('LUMARA Debug: [Enhanced Attribution] Cross-modal disabled - skipping media references');
    }

    // Generate ARCFORM attributions if present
    if (arcformData.isNotEmpty) {
      final trace = _createArcformAttribution(arcformData, responseId);
      allTraces.add(trace);
    }

    // Create response sections
    final sections = _createResponseSections(responseContent, allTraces);

    // Generate attribution summary
    final summary = _generateAttributionSummary(allTraces, crossRefs);

    // Create enhanced response trace
    final enhancedTrace = EnhancedResponseTrace(
      responseId: responseId,
      traces: allTraces,
      timestamp: DateTime.now(),
      model: model,
      context: context,
      sections: sections,
      summary: summary,
    );

    // Store the response trace
    _responseTraces[responseId] = enhancedTrace;
    _recentResponses.addLast(responseId);

    // Store source attributions
    for (final trace in allTraces) {
      _sourceAttributions.putIfAbsent(trace.nodeRef, () => []);
      _sourceAttributions[trace.nodeRef]!.add(trace);
    }

    // Store cross-references
    _crossReferences[responseId] = crossRefs;

    // Maintain trace history limit
    if (_recentResponses.length > _maxTraceHistory) {
      final oldResponseId = _recentResponses.removeFirst();
      _responseTraces.remove(oldResponseId);
      _crossReferences.remove(oldResponseId);
    }

    return responseId;
  }

  /// Create journal entry attribution
  EnhancedAttributionTrace _createJournalEntryAttribution(
    Map<String, dynamic> entry,
    String responseId
  ) {
    final confidence = _calculateJournalEntryConfidence(entry);
    final relation = _determineJournalRelation(entry);
    final excerpt = _extractJournalExcerpt(entry);

    return EnhancedAttributionFactory.fromJournalEntry(
      entryId: entry['id'] ?? 'unknown',
      relation: relation,
      confidence: confidence,
      excerpt: excerpt,
      reasoning: 'Journal entry provides relevant context and insights',
      phaseContext: entry['phase'],
      metadata: {
        'title': entry['title'] ?? '',
        'date': entry['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
        'word_count': (entry['content'] ?? '').split(' ').length,
        'emotions': entry['emotions'] ?? {},
        'keywords': entry['keywords'] ?? [],
      },
    );
  }

  /// Create chat message attribution
  EnhancedAttributionTrace _createChatMessageAttribution(
    LumaraMessage message,
    String responseId
  ) {
    final confidence = _calculateChatMessageConfidence(message);
    final relation = _determineChatRelation(message);
    final excerpt = _extractChatExcerpt(message);

    return EnhancedAttributionFactory.fromChatMessage(
      messageId: message.id,
      relation: relation,
      confidence: confidence,
      sessionId: message.metadata['sessionId']?.toString() ?? 'current',
      role: message.role.name,
      excerpt: excerpt,
      reasoning: message.role == LumaraMessageRole.assistant
          ? 'Previous LUMARA response provides context'
          : 'User message provides relevant query context',
    );
  }

  /// Create media attribution
  EnhancedAttributionTrace _createMediaAttribution(
    Map<String, dynamic> media,
    String responseId
  ) {
    final confidence = _calculateMediaConfidence(media);
    const relation = 'supports';
    final sourceType = _getMediaSourceType(media['type']);
    final excerpt = media['text_content'] ?? media['description'] ?? '';

    return EnhancedAttributionFactory.fromMediaContent(
      mediaId: media['id'],
      mediaType: sourceType,
      relation: relation,
      confidence: confidence,
      excerpt: excerpt,
      reasoning: 'Media content provides visual/audio context',
      metadata: {
        'filename': media['filename'],
        'duration': media['duration'],
        'size': media['size'],
      },
    );
  }

  /// Create ARCFORM attribution
  EnhancedAttributionTrace _createArcformAttribution(
    Map<String, dynamic> arcformData,
    String responseId
  ) {
    return EnhancedAttributionTrace(
      nodeRef: arcformData['id'] ?? 'arcform_${DateTime.now().millisecondsSinceEpoch}',
      sourceType: SourceType.phaseRegime,
      relation: 'contextualizes',
      confidence: 0.6,
      timestamp: DateTime.now(),
      excerpt: 'Phase tracking and emotional state data',
      reasoning: 'ARCFORM data provides phase and emotional context',
      sourceMetadata: arcformData,
    );
  }

  /// Create response sections for sectioned attribution
  List<ResponseSection> _createResponseSections(
    String responseContent,
    List<EnhancedAttributionTrace> traces
  ) {
    // Simple implementation - split by paragraphs
    final paragraphs = responseContent.split('\n\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    final sections = <ResponseSection>[];

    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i];
      final relevantTraces = _findRelevantTracesForSection(paragraph, traces);

      sections.add(ResponseSection(
        sectionId: 'section_$i',
        content: paragraph,
        attributionTraceIds: relevantTraces.map((t) => t.nodeRef).toList(),
        confidenceScore: relevantTraces.isNotEmpty
            ? relevantTraces.map((t) => t.confidence).reduce((a, b) => a + b) / relevantTraces.length
            : 0.0,
        primarySourceType: relevantTraces.isNotEmpty
            ? relevantTraces.first.sourceType
            : SourceType.insight,
      ));
    }

    return sections;
  }

  /// Generate attribution summary
  AttributionSummary _generateAttributionSummary(
    List<EnhancedAttributionTrace> traces,
    List<CrossReference> crossRefs
  ) {
    final sourceTypeBreakdown = <SourceType, int>{};
    final relationBreakdown = <String, int>{};
    final primarySources = <String>[];

    for (final trace in traces) {
      sourceTypeBreakdown[trace.sourceType] =
          (sourceTypeBreakdown[trace.sourceType] ?? 0) + 1;
      relationBreakdown[trace.relation] =
          (relationBreakdown[trace.relation] ?? 0) + 1;

      if (trace.confidence > 0.7) {
        primarySources.add(trace.nodeRef);
      }
    }

    final overallConfidence = traces.isNotEmpty
        ? traces.map((t) => t.confidence).reduce((a, b) => a + b) / traces.length
        : 0.0;

    return AttributionSummary(
      totalAttributions: traces.length,
      sourceTypeBreakdown: sourceTypeBreakdown,
      relationBreakdown: relationBreakdown,
      overallConfidence: overallConfidence,
      primarySources: primarySources,
      crossReferences: crossRefs,
    );
  }

  /// Find cross-references for a source
  Future<List<CrossReference>> _findCrossReferences(
    String sourceId,
    SourceType sourceType
  ) async {
    final crossRefs = <CrossReference>[];

    // Look for mentions in other journal entries
    if (sourceType == SourceType.journalEntry) {
      // TODO: Implement semantic search for related entries
      crossRefs.add(CrossReference(
        targetId: 'related_entry_placeholder',
        targetType: SourceType.journalEntry,
        relation: 'relates_to',
        strength: 0.8,
        description: 'Similar themes discussed',
        timestamp: DateTime.now(),
      ));
    }

    // Look for mentions in chat history
    if (sourceType != SourceType.chatMessage) {
      // TODO: Search chat history for related discussions
      crossRefs.add(CrossReference(
        targetId: 'chat_mention_placeholder',
        targetType: SourceType.chatMessage,
        relation: 'mentioned_in_chat',
        strength: 0.6,
        description: 'Previously discussed in conversation',
        timestamp: DateTime.now(),
      ));
    }

    return crossRefs;
  }

  /// Calculate confidence score for journal entry
  double _calculateJournalEntryConfidence(Map<String, dynamic> entry) {
    double confidence = 0.5; // Base confidence

    // Higher confidence for recent entries
    final createdAt = entry['createdAt'] is DateTime
        ? entry['createdAt'] as DateTime
        : DateTime.tryParse(entry['createdAt']?.toString() ?? '') ?? DateTime.now();
    final daysSince = DateTime.now().difference(createdAt).inDays;
    if (daysSince <= 7) {
      confidence += 0.3;
    } else if (daysSince <= 30) confidence += 0.2;
    else if (daysSince <= 90) confidence += 0.1;

    // Higher confidence for longer entries
    final content = entry['content']?.toString() ?? '';
    final wordCount = content.split(' ').length;
    if (wordCount > 200) {
      confidence += 0.2;
    } else if (wordCount > 100) confidence += 0.1;

    // Higher confidence if keywords match
    final keywords = entry['keywords'] as List<dynamic>? ?? [];
    if (keywords.isNotEmpty) confidence += 0.1;

    return confidence.clamp(0.0, 1.0);
  }

  /// Calculate confidence score for chat message
  double _calculateChatMessageConfidence(LumaraMessage message) {
    double confidence = 0.4; // Base confidence

    // Higher confidence for assistant responses
    if (message.role == LumaraMessageRole.assistant) confidence += 0.2;

    // Higher confidence for recent messages
    final daysSince = DateTime.now().difference(message.timestamp).inDays;
    if (daysSince <= 1) {
      confidence += 0.3;
    } else if (daysSince <= 7) confidence += 0.2;
    else if (daysSince <= 30) confidence += 0.1;

    // Higher confidence for longer messages
    final wordCount = message.content.split(' ').length;
    if (wordCount > 50) confidence += 0.1;

    return confidence.clamp(0.0, 1.0);
  }

  /// Calculate confidence score for media content
  double _calculateMediaConfidence(Map<String, dynamic> media) {
    double confidence = 0.3; // Base confidence for media

    // Higher confidence if text content is available
    if (media['text_content']?.isNotEmpty == true) confidence += 0.4;
    if (media['description']?.isNotEmpty == true) confidence += 0.2;

    return confidence.clamp(0.0, 1.0);
  }

  /// Determine relation type for journal entry
  String _determineJournalRelation(Map<String, dynamic> entry) {
    // Simple heuristic - could be enhanced with NLP
    final emotions = entry['emotions'] as Map<String, dynamic>? ?? {};
    if (emotions.isNotEmpty) {
      final positiveEmotions = ['happy', 'excited', 'grateful', 'confident'];
      final hasPositive = emotions.keys
          .any((emotion) => positiveEmotions.contains(emotion.toLowerCase()));
      return hasPositive ? 'supports' : 'contradicts';
    }
    return 'supports';
  }

  /// Determine relation type for chat message
  String _determineChatRelation(LumaraMessage message) {
    if (message.role == LumaraMessageRole.assistant) {
      return 'derives';
    }
    return 'references';
  }

  /// Extract excerpt from journal entry
  String? _extractJournalExcerpt(Map<String, dynamic> entry) {
    final content = entry['content']?.toString() ?? '';
    if (content.length <= 200) return content;

    // Extract first meaningful sentence or up to 200 characters
    final sentences = content.split(RegExp(r'[.!?]\s+'));
    if (sentences.isNotEmpty && sentences.first.length <= 200) {
      return '${sentences.first}.';
    }

    return '${content.substring(0, 197)}...';
  }

  /// Extract excerpt from chat message
  String? _extractChatExcerpt(LumaraMessage message) {
    if (message.content.length <= 150) return message.content;
    return '${message.content.substring(0, 147)}...';
  }

  /// Get media source type from media type string
  SourceType _getMediaSourceType(String? mediaType) {
    switch (mediaType?.toLowerCase()) {
      case 'image':
      case 'photo':
        return SourceType.photo;
      case 'audio':
        return SourceType.audio;
      case 'video':
        return SourceType.video;
      default:
        return SourceType.photo; // Default fallback
    }
  }

  /// Find relevant traces for a response section
  List<EnhancedAttributionTrace> _findRelevantTracesForSection(
    String sectionContent,
    List<EnhancedAttributionTrace> allTraces
  ) {
    // Simple keyword matching - could be enhanced with semantic similarity
    final sectionWords = sectionContent.toLowerCase().split(' ');
    final relevantTraces = <EnhancedAttributionTrace>[];

    for (final trace in allTraces) {
      if (trace.excerpt != null) {
        final excerptWords = trace.excerpt!.toLowerCase().split(' ');
        final commonWords = sectionWords
            .where((word) => excerptWords.contains(word))
            .length;

        // If more than 3 words in common, consider it relevant
        if (commonWords > 3) {
          relevantTraces.add(trace);
        }
      }
    }

    // Return top 3 most relevant traces
    relevantTraces.sort((a, b) => b.confidence.compareTo(a.confidence));
    return relevantTraces.take(3).toList();
  }

  /// Get enhanced response trace
  EnhancedResponseTrace? getEnhancedResponseTrace(String responseId) {
    return _responseTraces[responseId];
  }

  /// Get all attributions for a source
  List<EnhancedAttributionTrace> getSourceAttributions(String sourceId) {
    return _sourceAttributions[sourceId] ?? [];
  }

  /// Get cross-references for a response
  List<CrossReference> getCrossReferences(String responseId) {
    return _crossReferences[responseId] ?? [];
  }

  /// Generate human-readable explanation of attributions
  String generateAttributionExplanation(String responseId) {
    final trace = getEnhancedResponseTrace(responseId);
    if (trace == null) {
      return 'No attribution data available for this response.';
    }

    return trace.summary.generateDescription();
  }

  /// Get filtered attributions by source type
  List<EnhancedAttributionTrace> getAttributionsBySourceType(
    String responseId,
    SourceType sourceType
  ) {
    final trace = getEnhancedResponseTrace(responseId);
    if (trace == null) return [];

    return trace.traces
        .where((t) => t.sourceType == sourceType)
        .toList();
  }

  /// Get attribution statistics
  Map<String, dynamic> getEnhancedUsageStatistics() {
    final totalTraces = _responseTraces.values
        .map((rt) => rt.traces.length)
        .fold(0, (a, b) => a + b);

    final sourceTypeCounts = <SourceType, int>{};
    final relationCounts = <String, int>{};

    for (final responseTrace in _responseTraces.values) {
      for (final trace in responseTrace.traces) {
        sourceTypeCounts[trace.sourceType] =
            (sourceTypeCounts[trace.sourceType] ?? 0) + 1;
        relationCounts[trace.relation] =
            (relationCounts[trace.relation] ?? 0) + 1;
      }
    }

    return {
      'total_responses': _responseTraces.length,
      'total_attributions': totalTraces,
      'avg_attributions_per_response': _responseTraces.isNotEmpty
          ? totalTraces / _responseTraces.length
          : 0.0,
      'source_type_distribution': sourceTypeCounts.map(
        (key, value) => MapEntry(key.name, value)
      ),
      'relation_distribution': relationCounts,
      'cross_references_total': _crossReferences.values
          .map((refs) => refs.length)
          .fold(0, (a, b) => a + b),
      'transparency_score': _calculateEnhancedTransparencyScore(),
    };
  }

  /// Calculate enhanced transparency score
  double _calculateEnhancedTransparencyScore() {
    if (_responseTraces.isEmpty) return 1.0;

    int multiSourceResponses = 0;
    int totalCrossRefs = 0;

    for (final responseTrace in _responseTraces.values) {
      final sourceTypes = responseTrace.traces
          .map((t) => t.sourceType)
          .toSet();

      if (sourceTypes.length > 1) {
        multiSourceResponses++;
      }

      totalCrossRefs += responseTrace.summary.crossReferences.length;
    }

    final multiSourceRatio = multiSourceResponses / _responseTraces.length;
    final avgCrossRefs = totalCrossRefs / _responseTraces.length;

    return (multiSourceRatio * 0.6) + ((avgCrossRefs / 5).clamp(0.0, 1.0) * 0.4);
  }

  /// Clear all enhanced traces
  void clearAllEnhancedTraces() {
    _responseTraces.clear();
    _sourceAttributions.clear();
    _crossReferences.clear();
    _recentResponses.clear();
  }

  /// Export enhanced attribution data
  Map<String, dynamic> exportEnhancedAttributionData() {
    return {
      'export_timestamp': DateTime.now().toUtc().toIso8601String(),
      'enhanced_response_traces': _responseTraces.values
          .map((rt) => rt.toJson())
          .toList(),
      'source_attributions': _sourceAttributions.map((sourceId, traces) =>
          MapEntry(sourceId, traces.map((t) => t.toJson()).toList())),
      'cross_references': _crossReferences.map((responseId, refs) =>
          MapEntry(responseId, refs.map((r) => r.toJson()).toList())),
      'statistics': getEnhancedUsageStatistics(),
      'schema_version': 'enhanced_attribution_export.v1',
    };
  }

  /// Gather multi-source attribution traces for context (without recording response)
  Future<List<EnhancedAttributionTrace>> gatherContextTraces({
    required String userMessage,
    List<Map<String, dynamic>> journalEntries = const [],
    List<LumaraMessage> chatMessages = const [],
    List<LumaraMessage> currentSessionMessages = const [],
    List<Map<String, dynamic>> mediaReferences = const [],
    Map<String, dynamic> arcformData = const {},
  }) async {
    // Get user's LUMARA settings for attribution control
    final settingsService = LumaraReflectionSettingsService.instance;
    final similarityThreshold = await settingsService.getSimilarityThreshold();
    final maxMatches = await settingsService.getEffectiveMaxMatches();
    final crossModalEnabled = await settingsService.isCrossModalEnabled();

    print('LUMARA Debug: [Context Gathering] Using settings - threshold: $similarityThreshold, maxMatches: $maxMatches, crossModal: $crossModalEnabled');

    final allTraces = <EnhancedAttributionTrace>[];

    // Priority 1: Current conversation context
    if (currentSessionMessages.isNotEmpty) {
      final conversationTraces = ConversationContextService.generateCurrentConversationAttributions(
        currentResponseId: 'context_gathering_${DateTime.now().millisecondsSinceEpoch}',
        currentSessionMessages: currentSessionMessages,
        currentUserMessage: userMessage,
        lookbackLimit: maxMatches,
      );
      allTraces.addAll(conversationTraces);
    }

    // Priority 2: Journal entry attributions
    int journalCount = 0;
    for (final entry in journalEntries) {
      if (journalCount >= maxMatches) break;

      final relevanceScore = _calculateContentRelevance(
        entry['content'] as String? ?? '',
        userMessage,
      );

      if (relevanceScore >= similarityThreshold) {
        final trace = _createJournalEntryAttribution(entry, 'context_gathering');
        allTraces.add(trace);
        journalCount++;
      }
    }

    // Priority 3: Chat message attributions
    int chatCount = 0;
    for (final message in chatMessages) {
      if (chatCount >= maxMatches) break;

      final relevanceScore = _calculateContentRelevance(message.content, userMessage);

      if (relevanceScore >= similarityThreshold) {
        final trace = _createChatMessageAttribution(message, 'context_gathering');
        allTraces.add(trace);
        chatCount++;
      }
    }

    // Priority 4: Multi-modal media attributions
    if (crossModalEnabled) {
      print('LUMARA Debug: [Context Gathering] Processing ${mediaReferences.length} media references');
      int mediaCount = 0;

      for (final media in mediaReferences) {
        if (mediaCount >= maxMatches) break;

        final mediaContent = media['ocr_text'] as String? ??
                           media['transcript'] as String? ??
                           media['description'] as String? ?? '';

        final relevanceScore = mediaContent.isNotEmpty ?
          _calculateContentRelevance(mediaContent, userMessage) : 0.3;

        if (relevanceScore >= (similarityThreshold * 0.8)) {
          final trace = _createMediaAttribution(media, 'context_gathering');
          allTraces.add(trace);
          mediaCount++;
        }
      }
    }

    // Priority 5: ARCFORM data if available
    if (arcformData.isNotEmpty) {
      final trace = _createArcformAttribution(arcformData, 'context_gathering');
      allTraces.add(trace);
    }

    print('LUMARA Debug: [Context Gathering] Returning ${allTraces.length} total context traces');
    return allTraces;
  }

  /// Calculate content relevance score for similarity filtering
  double _calculateContentRelevance(String content, String userMessage) {
    final contentLower = content.toLowerCase();
    final messageLower = userMessage.toLowerCase();

    double score = 0.0;

    // Word overlap scoring
    final contentWords = contentLower.split(RegExp(r'\W+'));
    final messageWords = messageLower.split(RegExp(r'\W+'));

    final meaningfulContentWords = contentWords.where((w) => w.length > 3).toSet();
    final meaningfulMessageWords = messageWords.where((w) => w.length > 3).toSet();

    if (meaningfulMessageWords.isNotEmpty && meaningfulContentWords.isNotEmpty) {
      final overlap = meaningfulMessageWords.intersection(meaningfulContentWords).length;
      score += (overlap / meaningfulMessageWords.length) * 0.7;
    }

    // Context-specific keywords boost
    final contextKeywords = ['decision', 'choice', 'recommendation', 'advice', 'should', 'think', 'feel', 'emotion'];
    if (contextKeywords.any((keyword) => contentLower.contains(keyword))) {
      score += 0.2;
    }

    // Recent content gets slight boost
    score += 0.1;

    return score.clamp(0.0, 1.0);
  }
}
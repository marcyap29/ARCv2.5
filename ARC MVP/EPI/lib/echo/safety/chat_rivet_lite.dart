import 'dart:math' as math;
import '../../lumara/chat/chat_models.dart';
import '../../lumara/chat/content_parts.dart';

/// RIVET-lite validator for chat message readiness
/// Provides lightweight coherence and consistency checks
class ChatRivetLite {
  static const double _alignThreshold = 0.6;
  static const double _traceThreshold = 0.7;
  static const int _sustainmentWindow = 3;
  
  final List<ChatRivetEvent> _eventHistory = [];
  double _currentAlign = 0.0;
  double _currentTrace = 0.0;
  int _sustainmentCount = 0;
  bool _sawIndependentInWindow = false;

  /// Process a chat message and return readiness assessment
  Future<ChatRivetAssessment> assessMessage(ChatMessage message, {
    List<ChatMessage>? context,
    Map<String, dynamic>? retrievedFacts,
  }) async {
    // Create RIVET event from message
    final event = _createRivetEvent(message, context, retrievedFacts);
    
    // Update RIVET state
    await _updateRivetState(event);
    
    // Assess readiness
    final isReady = _assessReadiness();
    
    return ChatRivetAssessment(
      messageId: message.id,
      isReady: isReady,
      alignScore: _currentAlign,
      traceScore: _currentTrace,
      sustainmentCount: _sustainmentCount,
      sawIndependent: _sawIndependentInWindow,
      reasons: _getReadinessReasons(isReady),
      timestamp: DateTime.now(),
    );
  }

  /// Create RIVET event from chat message
  ChatRivetEvent _createRivetEvent(
    ChatMessage message,
    List<ChatMessage>? context,
    Map<String, dynamic>? retrievedFacts,
  ) {
    // Extract keywords from content
    final keywords = _extractKeywords(message);
    
    // Determine evidence source
    final source = _determineEvidenceSource(message, context);
    
    // Calculate coherence with context
    final coherence = _calculateCoherence(message, context);
    
    // Calculate consistency with retrieved facts
    final consistency = _calculateConsistency(message, retrievedFacts);
    
    return ChatRivetEvent(
      messageId: message.id,
      timestamp: message.createdAt,
      source: source,
      keywords: keywords,
      coherence: coherence,
      consistency: consistency,
      hasMedia: message.hasMedia,
      hasPrismAnalysis: message.hasPrismAnalysis,
      contextSize: context?.length ?? 0,
    );
  }

  /// Update RIVET state with new event
  Future<void> _updateRivetState(ChatRivetEvent event) async {
    _eventHistory.add(event);
    
    // Keep only recent events in window
    if (_eventHistory.length > _sustainmentWindow) {
      _eventHistory.removeAt(0);
    }
    
    // Calculate ALIGN score (agreement with context/facts)
    _currentAlign = _calculateAlignScore(event);
    
    // Calculate TRACE score (evidence sufficiency)
    _currentTrace = _calculateTraceScore(event);
    
    // Update sustainment count
    _updateSustainmentCount();
    
    // Check independence
    _sawIndependentInWindow = _checkIndependence();
  }

  /// Calculate ALIGN score (agreement with context)
  double _calculateAlignScore(ChatRivetEvent event) {
    if (_eventHistory.length < 2) return 0.5; // Neutral for first event
    
    final previousEvent = _eventHistory[_eventHistory.length - 2];
    
    // Coherence with previous message
    final coherenceScore = event.coherence;
    
    // Consistency with retrieved facts
    final consistencyScore = event.consistency;
    
    // Keyword overlap (semantic similarity)
    final keywordScore = _calculateKeywordOverlap(event.keywords, previousEvent.keywords);
    
    // Weighted average
    return (coherenceScore * 0.4 + consistencyScore * 0.4 + keywordScore * 0.2);
  }

  /// Calculate TRACE score (evidence sufficiency)
  double _calculateTraceScore(ChatRivetEvent event) {
    // Base evidence from message content
    double baseEvidence = 0.5;
    
    // Boost for media content (more evidence)
    if (event.hasMedia) baseEvidence += 0.2;
    
    // Boost for PRISM analysis (structured evidence)
    if (event.hasPrismAnalysis) baseEvidence += 0.3;
    
    // Boost for context size (more supporting evidence)
    if (event.contextSize > 0) {
      baseEvidence += math.min(event.contextSize * 0.05, 0.3);
    }
    
    // Independence multiplier
    final independenceMultiplier = _sawIndependentInWindow ? 1.2 : 1.0;
    
    // Novelty multiplier (keyword drift)
    final noveltyMultiplier = _calculateNoveltyMultiplier(event);
    
    return math.min(baseEvidence * independenceMultiplier * noveltyMultiplier, 1.0);
  }

  /// Update sustainment count
  void _updateSustainmentCount() {
    final meetsThresholds = _currentAlign >= _alignThreshold && _currentTrace >= _traceThreshold;
    
    if (meetsThresholds) {
      _sustainmentCount = math.min(_sustainmentCount + 1, _sustainmentWindow);
    } else {
      _sustainmentCount = 0;
    }
  }

  /// Check if there's independence in the current window
  bool _checkIndependence() {
    if (_eventHistory.length < 2) return true;
    
    // Check if any event in window is from different source or has different characteristics
    final currentEvent = _eventHistory.last;
    
    for (int i = 0; i < _eventHistory.length - 1; i++) {
      final event = _eventHistory[i];
      
      // Different source
      if (event.source != currentEvent.source) return true;
      
      // Different time of day (independence)
      final timeDiff = currentEvent.timestamp.difference(event.timestamp);
      if (timeDiff.inHours >= 4) return true;
      
      // Different content characteristics
      if (event.hasMedia != currentEvent.hasMedia) return true;
      if (event.hasPrismAnalysis != currentEvent.hasPrismAnalysis) return true;
    }
    
    return false;
  }

  /// Calculate novelty multiplier based on keyword drift
  double _calculateNoveltyMultiplier(ChatRivetEvent event) {
    if (_eventHistory.length < 2) return 1.1;
    
    final previousEvent = _eventHistory[_eventHistory.length - 2];
    final keywordOverlap = _calculateKeywordOverlap(event.keywords, previousEvent.keywords);
    final drift = 1.0 - keywordOverlap;
    
    return 1.0 + (drift * 0.5); // 1.0 to 1.5
  }

  /// Assess overall readiness
  bool _assessReadiness() {
    return _currentAlign >= _alignThreshold &&
           _currentTrace >= _traceThreshold &&
           _sustainmentCount >= _sustainmentWindow &&
           _sawIndependentInWindow;
  }

  /// Get readiness reasons
  List<String> _getReadinessReasons(bool isReady) {
    final reasons = <String>[];
    
    if (!isReady) {
      if (_currentAlign < _alignThreshold) {
        reasons.add('ALIGN score ${_currentAlign.toStringAsFixed(2)} below threshold $_alignThreshold');
      }
      if (_currentTrace < _traceThreshold) {
        reasons.add('TRACE score ${_currentTrace.toStringAsFixed(2)} below threshold $_traceThreshold');
      }
      if (_sustainmentCount < _sustainmentWindow) {
        reasons.add('Sustainment count $_sustainmentCount below window $_sustainmentWindow');
      }
      if (!_sawIndependentInWindow) {
        reasons.add('No independent evidence in current window');
      }
    } else {
      reasons.add('All readiness criteria met');
    }
    
    return reasons;
  }

  /// Extract keywords from message
  Set<String> _extractKeywords(ChatMessage message) {
    final keywords = <String>{};
    
    // Extract from text content
    final textContent = message.textContent.toLowerCase();
    final words = textContent.split(RegExp(r'\W+'))
        .where((word) => word.length > 3)
        .take(10)
        .toSet();
    keywords.addAll(words);
    
    // Extract from PRISM analysis
    for (final prism in message.prismSummaries) {
      if (prism.objects != null) {
        keywords.addAll(prism.objects!.map((obj) => obj.toLowerCase()));
      }
      if (prism.symbols != null) {
        keywords.addAll(prism.symbols!);
      }
    }
    
    return keywords;
  }

  /// Determine evidence source
  EvidenceSource _determineEvidenceSource(ChatMessage message, List<ChatMessage>? context) {
    if (message.hasMedia) return EvidenceSource.media;
    if (message.hasPrismAnalysis) return EvidenceSource.prism;
    if (context != null && context.isNotEmpty) return EvidenceSource.context;
    return EvidenceSource.direct;
  }

  /// Calculate coherence with context
  double _calculateCoherence(ChatMessage message, List<ChatMessage>? context) {
    if (context == null || context.isEmpty) return 0.5;
    
    // Simple coherence based on keyword overlap with recent context
    final messageKeywords = _extractKeywords(message);
    double totalOverlap = 0.0;
    
    for (final contextMessage in context.take(3)) {
      final contextKeywords = _extractKeywords(contextMessage);
      final overlap = _calculateKeywordOverlap(messageKeywords, contextKeywords);
      totalOverlap += overlap;
    }
    
    return totalOverlap / math.min(context.length, 3);
  }

  /// Calculate consistency with retrieved facts
  double _calculateConsistency(ChatMessage message, Map<String, dynamic>? facts) {
    if (facts == null || facts.isEmpty) return 0.5;
    
    // Simple consistency check based on keyword overlap with facts
    final messageKeywords = _extractKeywords(message);
    final factKeywords = facts.values
        .where((value) => value is String)
        .map((value) => value.toString().toLowerCase())
        .where((word) => word.length > 3)
        .toSet();
    
    return _calculateKeywordOverlap(messageKeywords, factKeywords);
  }

  /// Calculate keyword overlap (Jaccard similarity)
  double _calculateKeywordOverlap(Set<String> keywords1, Set<String> keywords2) {
    if (keywords1.isEmpty && keywords2.isEmpty) return 1.0;
    if (keywords1.isEmpty || keywords2.isEmpty) return 0.0;
    
    final intersection = keywords1.intersection(keywords2).length;
    final union = keywords1.union(keywords2).length;
    
    return intersection / union;
  }

  /// Reset RIVET state
  void reset() {
    _eventHistory.clear();
    _currentAlign = 0.0;
    _currentTrace = 0.0;
    _sustainmentCount = 0;
    _sawIndependentInWindow = false;
  }
}

/// RIVET event for chat messages
class ChatRivetEvent {
  final String messageId;
  final DateTime timestamp;
  final EvidenceSource source;
  final Set<String> keywords;
  final double coherence;
  final double consistency;
  final bool hasMedia;
  final bool hasPrismAnalysis;
  final int contextSize;

  ChatRivetEvent({
    required this.messageId,
    required this.timestamp,
    required this.source,
    required this.keywords,
    required this.coherence,
    required this.consistency,
    required this.hasMedia,
    required this.hasPrismAnalysis,
    required this.contextSize,
  });
}

/// Evidence source types
enum EvidenceSource {
  direct,
  context,
  media,
  prism,
}

/// RIVET assessment result
class ChatRivetAssessment {
  final String messageId;
  final bool isReady;
  final double alignScore;
  final double traceScore;
  final int sustainmentCount;
  final bool sawIndependent;
  final List<String> reasons;
  final DateTime timestamp;

  ChatRivetAssessment({
    required this.messageId,
    required this.isReady,
    required this.alignScore,
    required this.traceScore,
    required this.sustainmentCount,
    required this.sawIndependent,
    required this.reasons,
    required this.timestamp,
  });
}

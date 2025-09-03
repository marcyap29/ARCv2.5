/// Enhanced Keyword Extractor with RIVET Gating System
/// Implements P26 - Keyword Selection with evidence-based filtering
/// and semantic scoring for improved keyword quality and relevance.
library;

import 'dart:math';

/// Configuration for RIVET gating system
class RivetConfig {
  final int maxCandidates;
  final int preselectTop;
  final double tauAdd;
  final double tauDropRatio;
  final double minGapVsRandom;
  final int minEvidenceTypes;
  final double minPhaseMatch;
  final double minEmotionAmp;
  final int maxNewPerDay;
  final int minPhaseDwellDays;
  final double minPhaseDelta;

  const RivetConfig({
    this.maxCandidates = 20,
    this.preselectTop = 15,
    this.tauAdd = 0.15, // Lowered from 0.35 to be less restrictive
    this.tauDropRatio = 0.6,
    this.minGapVsRandom = 0.15,
    this.minEvidenceTypes = 1, // Lowered from 2 to be less restrictive
    this.minPhaseMatch = 0.10, // Lowered from 0.20 to be less restrictive
    this.minEmotionAmp = 0.05, // Lowered from 0.15 to be less restrictive
    this.maxNewPerDay = 2,
    this.minPhaseDwellDays = 3,
    this.minPhaseDelta = 0.12,
  });

  static const RivetConfig defaultConfig = RivetConfig();
}

/// Represents emotion detection for a keyword
class EmotionData {
  final String label;
  final double amplitude;

  const EmotionData({required this.label, required this.amplitude});

  Map<String, dynamic> toJson() => {
    'label': label,
    'amplitude': amplitude,
  };
}

/// Represents phase matching strength for a keyword
class PhaseMatchData {
  final String phase;
  final double strength;

  const PhaseMatchData({required this.phase, required this.strength});

  Map<String, dynamic> toJson() => {
    'phase': phase,
    'strength': strength,
  };
}

/// Evidence support for keyword selection
class EvidenceData {
  final Set<String> supportTypes;
  final List<List<int>> spanIndices;

  const EvidenceData({required this.supportTypes, required this.spanIndices});

  Map<String, dynamic> toJson() => {
    'support_types': supportTypes.toList(),
    'span_indices': spanIndices,
  };
}

/// RIVET gating decision result
class RivetDecision {
  final bool accept;
  final List<String> reasonCodes;
  final Map<String, dynamic> trace;

  const RivetDecision({
    required this.accept,
    required this.reasonCodes,
    required this.trace,
  });

  Map<String, dynamic> toJson() => {
    'gated_out': !accept,
    'reasons': reasonCodes,
  };
}

/// Enhanced keyword candidate with rich metadata
class KeywordCandidate {
  final String keyword;
  final double score;
  final EmotionData emotion;
  final PhaseMatchData phaseMatch;
  final EvidenceData evidence;
  final bool selected;
  final RivetDecision rivet;

  const KeywordCandidate({
    required this.keyword,
    required this.score,
    required this.emotion,
    required this.phaseMatch,
    required this.evidence,
    required this.selected,
    required this.rivet,
  });

  Map<String, dynamic> toJson() => {
    'keyword': keyword,
    'score': score,
    'emotion': emotion.toJson(),
    'phase_match': phaseMatch.toJson(),
    'evidence': evidence.toJson(),
    'selected': selected,
    'rivet': rivet.toJson(),
  };
}

/// Response format for P26 keyword extraction
class KeywordExtractionResponse {
  final Map<String, dynamic> meta;
  final List<KeywordCandidate> candidates;
  final List<String> chips;

  const KeywordExtractionResponse({
    required this.meta,
    required this.candidates,
    required this.chips,
  });

  Map<String, dynamic> toJson() => {
    'meta': meta,
    'candidates': candidates.map((c) => c.toJson()).toList(),
    'chips': chips,
  };
}

/// Enhanced Keyword Extractor with RIVET Gating
class EnhancedKeywordExtractor {
  static const RivetConfig _defaultConfig = RivetConfig.defaultConfig;

  /// Expanded curated keywords with semantic categories
  static const List<String> curatedKeywords = [
    // Core Emotions
    'grateful', 'anxious', 'hopeful', 'stressed', 'excited', 'calm', 'frustrated', 'peaceful',
    'overwhelmed', 'confident', 'uncertain', 'joyful', 'worried', 'relaxed', 'energized',
    'proud', 'ashamed', 'angry', 'content', 'sad', 'happy', 'fearful', 'optimistic',
    'bright', 'steady', 'focused', 'alive', 'coherent',
    
    // Life Domains
    'work', 'family', 'relationship', 'health', 'creativity', 'spirituality', 'money', 'career',
    'friendship', 'home', 'travel', 'learning', 'goals', 'dreams', 'purpose', 'community',
    'leadership', 'service', 'parenting', 'partnership', 'independence', 'belonging',
    
    // Growth & Transformation
    'growth', 'healing', 'breakthrough', 'challenge', 'transition', 'discovery', 'insight',
    'transformation', 'progress', 'setback', 'opportunity', 'balance', 'clarity', 'wisdom',
    'reflection', 'meditation', 'mindfulness', 'awareness', 'patterns', 'habits', 'change',
    'acceptance', 'forgiveness', 'compassion', 'resilience', 'courage', 'vulnerability',
    'momentum', 'threshold', 'crossing', 'barrier', 'speed', 'path', 'steps',
    
    // Technical & Development
    'mvp', 'prototype', 'system', 'integration', 'detection', 'recommendations', 'connect',
    'language', 'version', 'design', 'choices', 'visuals', 'stabilize', 'ship', 'experience',
    'arcform', 'phase', 'questionnaire', 'atlas', 'aurora', 'veil', 'polymeta',
    
    // Temporal & Process
    'beginning', 'ending', 'continuation', 'pause', 'acceleration', 'slowing', 'rhythm',
    'timing', 'season', 'cycle', 'milestone', 'anniversary', 'deadline', 'pressure',
    'first', 'time', 'today', 'loop', 'close', 'input', 'output', 'end', 'intent',
    
    // Relational & Social
    'connection', 'isolation', 'communication', 'conflict', 'harmony', 'support', 'trust',
    'betrayal', 'intimacy', 'distance', 'collaboration', 'competition', 'mentorship'
  ];

  /// Phase-keyword mapping for semantic matching
  static const Map<String, List<String>> phaseKeywordMap = {
    'Discovery': [
      'curious', 'exploring', 'learning', 'wondering', 'questioning', 'beginning',
      'new', 'fresh', 'potential', 'possibility', 'adventure', 'creativity', 'innovation'
    ],
    'Expansion': [
      'growing', 'expanding', 'reaching', 'stretching', 'building', 'developing',
      'flourishing', 'thriving', 'abundant', 'generous', 'confident', 'optimistic'
    ],
    'Transition': [
      'changing', 'shifting', 'moving', 'transitioning', 'evolving', 'adapting',
      'uncertain', 'between', 'liminal', 'threshold', 'crossing', 'bridge'
    ],
    'Consolidation': [
      'integrating', 'organizing', 'stabilizing', 'grounding', 'centering', 'anchoring',
      'weaving', 'connecting', 'synthesizing', 'harmonizing', 'routine', 'structure'
    ],
    'Recovery': [
      'healing', 'resting', 'restoring', 'recovering', 'gentle', 'nurturing',
      'calm', 'peaceful', 'soothing', 'quiet', 'stillness', 'retreat', 'sanctuary'
    ],
    'Breakthrough': [
      'breakthrough', 'clarity', 'insight', 'realization', 'epiphany', 'understanding',
      'liberation', 'freedom', 'transcendence', 'awakening', 'illumination', 'revelation'
    ],
  };

  /// Emotion keyword mapping for amplitude detection
  static const Map<String, double> emotionAmplitudeMap = {
    // High amplitude emotions
    'ecstatic': 0.95, 'devastated': 0.95, 'furious': 0.95, 'terrified': 0.95,
    'overjoyed': 0.90, 'heartbroken': 0.90, 'enraged': 0.90, 'panicked': 0.90,
    
    // Medium-high amplitude
    'excited': 0.80, 'anxious': 0.80, 'angry': 0.75, 'sad': 0.75,
    'joyful': 0.70, 'worried': 0.70, 'frustrated': 0.65, 'hopeful': 0.65,
    
    // Medium amplitude
    'happy': 0.60, 'nervous': 0.60, 'disappointed': 0.55, 'grateful': 0.55,
    'confident': 0.50, 'uncertain': 0.50, 'proud': 0.50, 'ashamed': 0.50,
    
    // Lower amplitude
    'content': 0.40, 'calm': 0.35, 'peaceful': 0.35, 'relaxed': 0.30,
    'neutral': 0.15, 'stable': 0.20, 'steady': 0.20,
  };

  /// Extract enhanced keywords with RIVET gating
  static KeywordExtractionResponse extractKeywords({
    required String entryText,
    required String currentPhase,
    RivetConfig config = _defaultConfig,
  }) {
    // Step 1: Generate raw candidates
    final rawCandidates = _generateCandidates(entryText);
    
    // Step 2: Score candidates with existing equation (AS-IS)
    final scoredCandidates = _scoreCandidates(rawCandidates, entryText, currentPhase);
    
    // Step 3: Apply RIVET gating
    final gatedCandidates = _applyRivetGating(scoredCandidates, config);
    
    // Step 4: Rank and truncate
    final rankedCandidates = _rankAndTruncate(gatedCandidates, config);
    
    // Step 5: Generate response
    return _generateResponse(rankedCandidates, currentPhase, config);
  }

  /// Generate raw keyword candidates from text
  static Set<String> _generateCandidates(String text) {
    final textLower = text.toLowerCase();
    final words = textLower.split(RegExp(r'\s+'));
    
    // Common stop words to filter out
    const stopWords = {
      'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by',
      'a', 'an', 'is', 'are', 'was', 'were', 'this', 'that', 'these', 'those',
      'have', 'has', 'had', 'will', 'would', 'could', 'should', 'may', 'might',
      'can', 'do', 'does', 'did', 'get', 'gets', 'got', 'go', 'goes', 'went',
      'gone', 'see', 'sees', 'saw', 'seen', 'know', 'knows', 'knew', 'known',
      'think', 'thinks', 'thought', 'feel', 'feels', 'felt', 'want', 'wants',
      'wanted', 'need', 'needs', 'needed', 'like', 'likes', 'liked', 'love',
      'loves', 'loved', 'make', 'makes', 'made', 'take', 'takes', 'took', 'taken',
      'come', 'comes', 'came', 'give', 'gives', 'gave', 'given', 'find', 'finds',
      'found', 'tell', 'tells', 'told', 'ask', 'asks', 'asked', 'try', 'tries',
      'tried', 'work', 'works', 'worked', 'seem', 'seems', 'seemed', 'turn',
      'turns', 'turned', 'start', 'starts', 'started', 'show', 'shows', 'showed',
      'hear', 'hears', 'heard', 'play', 'plays', 'played', 'run', 'runs', 'ran',
      'move', 'moves', 'moved', 'live', 'lives', 'lived', 'believe', 'believes',
      'believed', 'hold', 'holds', 'held', 'bring', 'brings', 'brought', 'happen',
      'happens', 'happened', 'write', 'writes', 'wrote', 'written', 'provide',
      'provides', 'provided', 'sit', 'sits', 'sat', 'stand', 'stands', 'stood',
      'lose', 'loses', 'lost', 'pay', 'pays', 'paid', 'meet', 'meets', 'met',
      'include', 'includes', 'included', 'continue', 'continues', 'continued',
      'set', 'sets', 'follow', 'follows', 'followed', 'stop', 'stops', 'stopped',
      'create', 'creates', 'created', 'speak', 'speaks', 'spoke', 'spoken',
      'read', 'reads', 'allow', 'allows', 'allowed', 'add', 'adds', 'added',
      'spend', 'spends', 'spent', 'grow', 'grows', 'grew', 'grown', 'open',
      'opens', 'opened', 'walk', 'walks', 'walked', 'win', 'wins', 'won',
      'offer', 'offers', 'offered', 'remember', 'remembers', 'remembered',
      'consider', 'considers', 'considered', 'appear', 'appears', 'appeared',
      'buy', 'buys', 'bought', 'wait', 'waits', 'waited', 'serve', 'serves',
      'served', 'die', 'dies', 'died', 'send', 'sends', 'sent', 'expect',
      'expects', 'expected', 'build', 'builds', 'built', 'stay', 'stays',
      'stayed', 'fall', 'falls', 'fell', 'fallen', 'cut', 'cuts', 'reach',
      'reaches', 'reached', 'kill', 'kills', 'killed', 'raise', 'raises',
      'raised', 'pass', 'passes', 'passed', 'sell', 'sells', 'sold',
      'require', 'requires', 'required', 'report', 'reports', 'reported',
      'decide', 'decides', 'decided', 'pull', 'pulls', 'pulled', 'today',
      'yesterday', 'tomorrow', 'time', 'day', 'days', 'week', 'weeks',
      'month', 'months', 'year', 'years', 'hour', 'hours', 'minute', 'minutes',
      'second', 'seconds', 'moment', 'moments', 'now', 'then', 'when', 'where',
      'why', 'how', 'what', 'who', 'which', 'whose', 'whom', 'here', 'there',
      'everywhere', 'somewhere', 'anywhere', 'nowhere', 'always', 'never',
      'sometimes', 'often', 'usually', 'rarely', 'seldom', 'once', 'twice',
      'again', 'still', 'yet', 'already', 'just', 'only', 'also', 'too',
      'very', 'much', 'many', 'most', 'more', 'less', 'little', 'few',
      'several', 'some', 'any', 'all', 'every', 'each', 'both', 'either',
      'neither', 'none', 'no', 'not', 'yes'
    };
    
    // Extract meaningful words (lowered minimum length to 2 for better coverage)
    final extractedWords = words
        .where((word) => word.length >= 2 && !stopWords.contains(word))
        .map((word) => word.replaceAll(RegExp(r'[^\w]'), ''))
        .where((word) => word.isNotEmpty)
        .toSet();
    
    // Find matching curated keywords
    final matchingCurated = curatedKeywords
        .where((keyword) => textLower.contains(keyword))
        .toSet();
    
    // Extract 2-word phrases for better context (lowered minimum length)
    final phrases = <String>{};
    for (int i = 0; i < words.length - 1; i++) {
      if (words[i].length >= 2 && words[i + 1].length >= 2 &&
          !stopWords.contains(words[i]) && !stopWords.contains(words[i + 1])) {
        final phrase = '${words[i]} ${words[i + 1]}';
        if (phrase.length <= 25) phrases.add(phrase); // Increased max length
      }
    }
    
    // Combine all candidates
    return {
      ...matchingCurated,
      ...extractedWords,
      ...phrases,
      ...curatedKeywords, // Include all curated for selection
    };
  }

  /// Score candidates using the EXACT existing equation (AS-IS)
  static List<Map<String, dynamic>> _scoreCandidates(
    Set<String> candidates,
    String entryText,
    String currentPhase,
  ) {
    final textLower = entryText.toLowerCase();
    final wordCount = entryText.split(RegExp(r'\s+')).length;
    final results = <Map<String, dynamic>>[];
    
    for (final candidate in candidates) {
      // Calculate TFIDF_u (simplified)
      final termFreq = _countOccurrences(textLower, candidate.toLowerCase()) / wordCount;
      final inverseDocFreq = log(100 / (1 + _getDocumentFrequency(candidate))); // Simulated
      final tfidf = termFreq * inverseDocFreq;
      
      // Calculate centrality (based on curated keyword presence and text occurrence)
      final isInText = textLower.contains(candidate.toLowerCase());
      final centrality = curatedKeywords.contains(candidate) 
          ? (isInText ? 0.9 : 0.7)  // Higher score if in text
          : (isInText ? 0.6 : 0.2); // Still give some score if in text
      
      // Calculate emotion amplitude
      final emotionAmp = _getEmotionAmplitude(candidate);
      final emotionLabel = _getEmotionLabel(candidate);
      
      // Calculate recency (simulated - would be from user history)
      const recency = 0.5; // Placeholder
      
      // Calculate phase match strength
      final phaseMatch = _getPhaseMatchStrength(candidate, currentPhase);
      
      // Calculate phrase quality (length and semantic coherence)
      final phraseQuality = _calculatePhraseQuality(candidate);
      
      // Apply EXACT scoring equation (AS-IS)
      final score = (0.45 * tfidf) +
                   (0.15 * centrality) +
                   (0.10 * emotionAmp) +
                   (0.10 * recency) +
                   (0.10 * phaseMatch) +
                   (0.10 * phraseQuality);
      
      // Normalize score to [0,1]
      final normalizedScore = (score).clamp(0.0, 1.0);
      
      // Detect support types
      final supportTypes = <String>{};
      if (tfidf > 0.1) supportTypes.add('tfidf');
      if (centrality > 0.5) supportTypes.add('centrality');
      if (emotionAmp > 0.2) supportTypes.add('emotion');
      if (recency > 0.3) supportTypes.add('recency');
      if (phaseMatch > 0.3) supportTypes.add('phase');
      if (phraseQuality > 0.4) supportTypes.add('phrase_quality');
      if (_countOccurrences(textLower, candidate.toLowerCase()) > 1) {
        supportTypes.add('span_count');
      }
      
      // Find span indices
      final spanIndices = _findSpanIndices(entryText, candidate);
      
      results.add({
        'keyword': candidate,
        'score': normalizedScore,
        'tfidf': tfidf,
        'centrality': centrality,
        'emotion_amp': emotionAmp,
        'emotion_label': emotionLabel,
        'recency': recency,
        'phase_match': phaseMatch,
        'phrase_quality': phraseQuality,
        'support_types': supportTypes,
        'span_indices': spanIndices,
      });
    }
    
    return results;
  }

  /// Apply RIVET gating to filter out weak candidates
  static List<Map<String, dynamic>> _applyRivetGating(
    List<Map<String, dynamic>> candidates,
    RivetConfig config,
  ) {
    final gatedCandidates = <Map<String, dynamic>>[];
    
    for (final candidate in candidates) {
      final decision = _rivetDecision(candidate, config);
      
      candidate['rivet_decision'] = decision;
      
      if (decision.accept) {
        gatedCandidates.add(candidate);
      }
    }
    
    // Fallback: if RIVET gating is too strict and we have no candidates,
    // take the top candidates by score regardless of RIVET decision
    if (gatedCandidates.isEmpty && candidates.isNotEmpty) {
      // Sort by score and take top candidates
      candidates.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
      final fallbackCandidates = candidates.take(config.maxCandidates).toList();
      
      // Mark them as accepted with fallback reason
      for (final candidate in fallbackCandidates) {
        candidate['rivet_decision'] = RivetDecision(
          accept: true,
          reasonCodes: ['FALLBACK_ACCEPTED'],
          trace: {'fallback': true, 'score': candidate['score']},
        );
      }
      
      return fallbackCandidates;
    }
    
    return gatedCandidates;
  }

  /// Make RIVET gating decision for a candidate
  static RivetDecision _rivetDecision(
    Map<String, dynamic> candidate,
    RivetConfig config,
  ) {
    final reasonCodes = <String>[];
    final trace = <String, dynamic>{};
    
    final score = candidate['score'] as double;
    final supportTypes = candidate['support_types'] as Set<String>;
    final phaseMatch = candidate['phase_match'] as double;
    final emotionAmp = candidate['emotion_amp'] as double;
    final keyword = candidate['keyword'] as String;
    
    trace['score'] = score;
    trace['support_types_count'] = supportTypes.length;
    trace['phase_match'] = phaseMatch;
    trace['emotion_amp'] = emotionAmp;
    
    // Gate 1: Minimum score threshold
    if (score < config.tauAdd) {
      reasonCodes.add('SCORE_TOO_LOW');
    }
    
    // Gate 2: Evidence types threshold
    if (supportTypes.length < config.minEvidenceTypes) {
      reasonCodes.add('INSUFFICIENT_EVIDENCE_TYPES');
    }
    
    // Gate 3: Phase match threshold (unless descriptive)
    final isDescriptive = _isDescriptiveTerm(keyword);
    if (!isDescriptive && phaseMatch < config.minPhaseMatch) {
      reasonCodes.add('WEAK_PHASE_MATCH');
    }
    
    // Gate 4: Emotion amplitude for emotion-anchored terms
    final isEmotionAnchored = supportTypes.contains('emotion');
    if (isEmotionAnchored && emotionAmp < config.minEmotionAmp) {
      reasonCodes.add('WEAK_EMOTION_AMPLITUDE');
    }
    
    final accept = reasonCodes.isEmpty;
    
    return RivetDecision(
      accept: accept,
      reasonCodes: reasonCodes,
      trace: trace,
    );
  }

  /// Rank and truncate candidates to final selection
  static List<Map<String, dynamic>> _rankAndTruncate(
    List<Map<String, dynamic>> candidates,
    RivetConfig config,
  ) {
    // Sort by: score DESC, phase_match DESC, emotion_amp DESC, centrality DESC
    candidates.sort((a, b) {
      final scoreComp = (b['score'] as double).compareTo(a['score'] as double);
      if (scoreComp != 0) return scoreComp;
      
      final phaseComp = (b['phase_match'] as double).compareTo(a['phase_match'] as double);
      if (phaseComp != 0) return phaseComp;
      
      final emotionComp = (b['emotion_amp'] as double).compareTo(a['emotion_amp'] as double);
      if (emotionComp != 0) return emotionComp;
      
      return (b['centrality'] as double).compareTo(a['centrality'] as double);
    });
    
    // Truncate to max candidates
    final truncated = candidates.take(config.maxCandidates).toList();
    
    // Mark preselected
    for (int i = 0; i < truncated.length; i++) {
      truncated[i]['selected'] = i < config.preselectTop;
    }
    
    return truncated;
  }

  /// Generate final response format
  static KeywordExtractionResponse _generateResponse(
    List<Map<String, dynamic>> candidates,
    String currentPhase,
    RivetConfig config,
  ) {
    final keywordCandidates = candidates.map((c) {
      final rivetDecision = c['rivet_decision'] as RivetDecision;
      
      return KeywordCandidate(
        keyword: c['keyword'] as String,
        score: c['score'] as double,
        emotion: EmotionData(
          label: c['emotion_label'] as String,
          amplitude: c['emotion_amp'] as double,
        ),
        phaseMatch: PhaseMatchData(
          phase: currentPhase,
          strength: c['phase_match'] as double,
        ),
        evidence: EvidenceData(
          supportTypes: c['support_types'] as Set<String>,
          spanIndices: c['span_indices'] as List<List<int>>,
        ),
        selected: c['selected'] as bool,
        rivet: rivetDecision,
      );
    }).toList();
    
    final chips = keywordCandidates
        .where((c) => c.selected)
        .map((c) => c.keyword)
        .toList();
    
    final meta = {
      'current_phase': currentPhase,
      'limits': {
        'max_candidates': config.maxCandidates,
        'preselect_top': config.preselectTop,
      },
      'equation': 'AS_IS',
      'notes': 'RIVET applied before truncation; deterministic ordering; no randomness.',
    };
    
    return KeywordExtractionResponse(
      meta: meta,
      candidates: keywordCandidates,
      chips: chips,
    );
  }

  // Helper methods for scoring calculations
  
  static int _countOccurrences(String text, String term) {
    return term.allMatches(text).length;
  }
  
  static double _getDocumentFrequency(String term) {
    // Simulated document frequency - would be from actual corpus stats
    if (curatedKeywords.contains(term)) return 10.0;
    if (term.length >= 8) return 5.0;
    return 15.0;
  }
  
  static double _getEmotionAmplitude(String term) {
    return emotionAmplitudeMap[term.toLowerCase()] ?? 0.0;
  }
  
  static String _getEmotionLabel(String term) {
    final amp = _getEmotionAmplitude(term);
    if (amp > 0.7) return 'high';
    if (amp > 0.4) return 'medium';
    if (amp > 0.1) return 'low';
    return 'none';
  }
  
  static double _getPhaseMatchStrength(String term, String phase) {
    final phaseKeywords = phaseKeywordMap[phase] ?? [];
    if (phaseKeywords.contains(term.toLowerCase())) return 0.9;
    
    // Partial matching for related terms
    for (final phaseKeyword in phaseKeywords) {
      if (term.toLowerCase().contains(phaseKeyword) || 
          phaseKeyword.contains(term.toLowerCase())) {
        return 0.6;
      }
    }
    
    return 0.1;
  }
  
  static double _calculatePhraseQuality(String phrase) {
    final words = phrase.split(' ');
    
    // Single word: base quality
    if (words.length == 1) {
      final word = words.first;
      if (word.length >= 6) return 0.7;
      if (word.length >= 4) return 0.5;
      return 0.3;
    }
    
    // Multi-word phrases: higher quality if semantic
    if (words.length == 2) {
      // Check if it's a meaningful phrase
      final isSemanticPhrase = curatedKeywords.any((kw) => 
        phrase.toLowerCase().contains(kw) || kw.contains(phrase.toLowerCase()));
      return isSemanticPhrase ? 0.8 : 0.6;
    }
    
    // Longer phrases get lower quality (too specific)
    return 0.4;
  }
  
  static List<List<int>> _findSpanIndices(String text, String term) {
    final indices = <List<int>>[];
    final textLower = text.toLowerCase();
    final termLower = term.toLowerCase();
    
    int start = 0;
    while (true) {
      final index = textLower.indexOf(termLower, start);
      if (index == -1) break;
      
      indices.add([index, index + term.length]);
      start = index + 1;
    }
    
    return indices;
  }
  
  static bool _isDescriptiveTerm(String term) {
    // Terms that are purely descriptive (names, dates, etc.) 
    // don't need strong phase matching
    final descriptivePatterns = [
      RegExp(r'^\d{4}$'), // years
      RegExp(r'^\d{1,2}[/-]\d{1,2}'), // dates
      RegExp(r'^[A-Z][a-z]+$'), // proper nouns
    ];
    
    return descriptivePatterns.any((pattern) => pattern.hasMatch(term));
  }
}
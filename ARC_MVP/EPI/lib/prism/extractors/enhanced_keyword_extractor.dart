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

  // Temporal analysis settings
  final bool enableTemporalAnalysis;
  final int temporalLookbackDays;
  final double recencyBoostFactor;
  final double overuseThreshold;         // If keyword used too often, reduce score
  final double underrepresentedBoost;    // Boost rarely used but relevant keywords

  const RivetConfig({
    this.maxCandidates = 20,
    this.preselectTop = 12,
    this.tauAdd = 0.25, // Raise gate to drop weak/noisy terms
    this.tauDropRatio = 0.6,
    this.minGapVsRandom = 0.15,
    this.minEvidenceTypes = 2, // Require at least two evidence signals
    this.minPhaseMatch = 0.20, // Require a real link to current phase
    this.minEmotionAmp = 0.10, // Ignore terms with negligible emotional signal
    this.maxNewPerDay = 2,
    this.minPhaseDwellDays = 3,
    this.minPhaseDelta = 0.12,
    this.enableTemporalAnalysis = true,
    this.temporalLookbackDays = 30,
    this.recencyBoostFactor = 1.2,
    this.overuseThreshold = 0.4,          // Used in >40% of recent entries
    this.underrepresentedBoost = 1.15,    // Boost underused keywords
  });

  static const RivetConfig defaultConfig = RivetConfig();
}

/// Historical keyword usage data for temporal analysis
class KeywordHistory {
  final String keyword;
  final int usageCount;
  final DateTime? lastUsed;
  final List<DateTime> usageDates;
  final double avgAmplitude;

  const KeywordHistory({
    required this.keyword,
    required this.usageCount,
    this.lastUsed,
    required this.usageDates,
    required this.avgAmplitude,
  });

  double get usageFrequency => usageDates.isEmpty ? 0.0 : usageCount / usageDates.length;

  Map<String, dynamic> toJson() => {
    'keyword': keyword,
    'usage_count': usageCount,
    'last_used': lastUsed?.toIso8601String(),
    'usage_dates': usageDates.map((d) => d.toIso8601String()).toList(),
    'avg_amplitude': avgAmplitude,
    'usage_frequency': usageFrequency,
  };
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
    // Positive Emotions
    'grateful', 'hopeful', 'excited', 'calm', 'peaceful', 'confident', 'joyful', 'relaxed',
    'energized', 'proud', 'happy', 'optimistic', 'bright', 'steady', 'focused', 'alive',
    'coherent', 'content', 'satisfied', 'fulfilled', 'blessed', 'thankful', 'serene',
    'delighted', 'elated', 'cheerful', 'uplifted', 'inspired', 'motivated', 'empowered',
    'loving', 'loved', 'appreciated', 'valued', 'understood', 'supported', 'safe',
    'secure', 'stable', 'grounded', 'centered', 'balanced', 'harmonious',

    // Negative Emotions - Anxiety & Fear
    'anxious', 'stressed', 'overwhelmed', 'worried', 'fearful', 'scared', 'terrified',
    'panicked', 'nervous', 'tense', 'uneasy', 'restless', 'on edge', 'paranoid',
    'threatened', 'insecure', 'vulnerable', 'exposed', 'unsafe', 'helpless', 'powerless',
    'trapped', 'suffocated', 'claustrophobic', 'apprehensive', 'dreadful', 'alarmed',

    // Negative Emotions - Sadness & Depression
    'sad', 'depressed', 'heartbroken', 'devastated', 'grief', 'grieving', 'mourning',
    'lonely', 'empty', 'hollow', 'numb', 'hopeless', 'despair', 'despairing', 'defeated',
    'broken', 'shattered', 'crushed', 'miserable', 'sorrowful', 'melancholy', 'gloomy',
    'dark', 'heavy', 'burdened', 'drained', 'exhausted', 'depleted', 'lifeless',
    'disconnected', 'isolated', 'alone', 'abandoned', 'rejected', 'unwanted', 'unloved',

    // Negative Emotions - Anger & Frustration
    'angry', 'frustrated', 'irritated', 'annoyed', 'furious', 'enraged', 'mad', 'livid',
    'bitter', 'resentful', 'hostile', 'aggressive', 'vengeful', 'spiteful', 'hateful',
    'disgusted', 'repulsed', 'contemptuous', 'indignant', 'outraged', 'infuriated',
    'agitated', 'exasperated', 'provoked', 'triggered', 'offended', 'hurt',

    // Negative Emotions - Shame & Guilt
    'ashamed', 'guilty', 'embarrassed', 'humiliated', 'mortified', 'degraded',
    'inadequate', 'unworthy', 'worthless', 'incompetent', 'failure', 'defective',
    'flawed', 'damaged', 'tainted', 'dirty', 'regretful', 'remorseful', 'apologetic',

    // Negative Emotions - Confusion & Doubt
    'uncertain', 'confused', 'lost', 'disoriented', 'bewildered', 'perplexed',
    'doubtful', 'skeptical', 'suspicious', 'distrustful', 'questioning', 'conflicted',
    'ambivalent', 'indecisive', 'torn', 'unclear', 'foggy', 'hazy',

    // Negative Emotions - Disappointment & Regret
    'disappointed', 'let down', 'discouraged', 'disillusioned', 'dismayed', 'deflated',
    'regretful', 'remorse', 'hindsight', 'wishing', 'if only', 'shouldve', 'missed opportunity',

    // Life Domains
    'work', 'family', 'relationship', 'health', 'creativity', 'spirituality', 'money', 'career',
    'friendship', 'home', 'travel', 'learning', 'goals', 'dreams', 'purpose', 'community',
    'leadership', 'service', 'parenting', 'partnership', 'independence', 'belonging',
    'job', 'school', 'finance', 'body', 'mind', 'soul', 'self', 'identity',

    // Growth & Transformation
    'growth', 'healing', 'breakthrough', 'challenge', 'transition', 'discovery', 'insight',
    'transformation', 'progress', 'setback', 'opportunity', 'balance', 'clarity', 'wisdom',
    'reflection', 'meditation', 'mindfulness', 'awareness', 'patterns', 'habits', 'change',
    'acceptance', 'forgiveness', 'compassion', 'resilience', 'courage', 'vulnerability',
    'momentum', 'threshold', 'crossing', 'barrier', 'speed', 'path', 'steps',
    'recovery', 'repair', 'rebuild', 'restart', 'renewal', 'rebirth', 'release', 'surrender',

    // Struggles & Challenges
    'struggle', 'difficulty', 'obstacle', 'problem', 'issue', 'crisis', 'emergency',
    'conflict', 'tension', 'strain', 'burden', 'weight', 'load', 'responsibility',
    'pressure', 'stress', 'demand', 'expectation', 'obligation', 'duty', 'hardship',
    'suffering', 'pain', 'hurt', 'wound', 'trauma', 'damage', 'loss', 'failure',

    // Technical & Development
    'mvp', 'prototype', 'system', 'integration', 'detection', 'recommendations', 'connect',
    'language', 'version', 'design', 'choices', 'visuals', 'stabilize', 'ship', 'experience',
    'arcform', 'phase', 'questionnaire', 'atlas', 'aurora', 'veil', 'mira',

    // Temporal & Process
    'beginning', 'ending', 'continuation', 'pause', 'acceleration', 'slowing', 'rhythm',
    'timing', 'season', 'cycle', 'milestone', 'anniversary', 'deadline', 'pressure',
    'first', 'time', 'today', 'loop', 'close', 'input', 'output', 'end', 'intent',

    // Relational & Social
    'connection', 'isolation', 'communication', 'conflict', 'harmony', 'support', 'trust',
    'betrayal', 'intimacy', 'distance', 'collaboration', 'competition', 'mentorship',
    'argument', 'fight', 'disagreement', 'misunderstanding', 'breakup', 'separation',
    'divorce', 'reunion', 'reconciliation', 'boundary', 'boundaries', 'space', 'closeness'
  ];

  /// Phase-keyword mapping for semantic matching
  static const Map<String, List<String>> phaseKeywordMap = {
    'Discovery': [
      // Mostly positive with some natural uncertainty
      'curious', 'exploring', 'learning', 'wondering', 'questioning', 'beginning',
      'new', 'fresh', 'potential', 'possibility', 'adventure', 'creativity', 'innovation',
      'excited', 'hopeful', 'inspired', 'motivated', 'discovering', 'finding',
      // Natural uncertainty in exploration (not negative, just neutral/exploratory)
      'uncertain', 'questioning', 'unclear', 'curious', 'exploring options'
    ],
    'Expansion': [
      // Positive
      'growing', 'expanding', 'reaching', 'stretching', 'building', 'developing',
      'flourishing', 'thriving', 'abundant', 'generous', 'confident', 'optimistic',
      'empowered', 'energized', 'proud', 'successful', 'achieving', 'momentum',
      // Negative/Mixed
      'pressure', 'stressed', 'overwhelmed', 'burden', 'responsibility', 'expectation',
      'demanding', 'exhausted', 'overextended', 'strained', 'stretched thin'
    ],
    'Transition': [
      // Positive
      'changing', 'shifting', 'moving', 'transitioning', 'evolving', 'adapting',
      'transforming', 'between', 'liminal', 'threshold', 'crossing', 'bridge',
      // Negative/Mixed
      'uncertain', 'confused', 'lost', 'disoriented', 'unstable', 'shaky',
      'anxious', 'worried', 'fearful', 'scared', 'insecure', 'vulnerable',
      'torn', 'conflicted', 'ambivalent', 'indecisive', 'hesitant', 'stuck',
      'letting go', 'release', 'ending', 'loss', 'grief', 'mourning'
    ],
    'Consolidation': [
      // Positive
      'integrating', 'organizing', 'stabilizing', 'grounding', 'centering', 'anchoring',
      'weaving', 'connecting', 'synthesizing', 'harmonizing', 'routine', 'structure',
      'balanced', 'steady', 'secure', 'stable', 'coherent', 'settled',
      // Negative/Mixed
      'tired', 'drained', 'depleted', 'exhausted', 'weary', 'heavy',
      'slowly improving', 'rebuilding', 'repairing', 'mending', 'recovering',
      'restoring order', 'picking up pieces', 'getting back', 'finding footing'
    ],
    'Recovery': [
      // Positive
      'healing', 'resting', 'restoring', 'recovering', 'gentle', 'nurturing',
      'calm', 'peaceful', 'soothing', 'quiet', 'stillness', 'retreat', 'sanctuary',
      'renewal', 'rebirth', 'regeneration', 'restoration',
      // Negative/Mixed (in recovery process)
      'wounded', 'hurt', 'pain', 'suffering', 'trauma', 'traumatized',
      'broken', 'damaged', 'injured', 'scarred', 'tender', 'fragile',
      'vulnerable', 'weak', 'depleted', 'exhausted', 'drained', 'empty',
      'grief', 'grieving', 'mourning', 'loss', 'sad', 'heartbroken',
      'slowly healing', 'mending', 'getting better', 'improving', 'on the mend'
    ],
    'Crucible': [
      // The intense pressure before breakthrough - struggle, determination
      'frustrated', 'stuck', 'blocked', 'struggling', 'trying', 'fighting',
      'desperate', 'determined', 'pushed', 'breaking point', 'enough',
      'cant take anymore', 'had enough', 'pushing through', 'intense',
      'pressure', 'challenge', 'testing', 'trials', 'at my limit', 'edge',
      'pushing boundaries', 'resistance', 'wrestling', 'grappling'
    ],
    'Breakthrough': [
      // Positive - the actual breakthrough moment and after
      'breakthrough', 'clarity', 'insight', 'realization', 'epiphany', 'understanding',
      'liberation', 'freedom', 'transcendence', 'awakening', 'illumination', 'revelation',
      'aha moment', 'finally', 'suddenly', 'click', 'makes sense', 'understand',
      'released', 'freed', 'unburdened', 'lighter', 'relief', 'enlightened',
      'transformed', 'clear', 'seeing', 'breakthrough moment', 'got it', 'eureka',
      'weight lifted', 'new perspective', 'shift', 'opened', 'unlocked'
    ],
  };

  /// Emotion keyword mapping for amplitude detection
  static const Map<String, double> emotionAmplitudeMap = {
    // Highest amplitude emotions (0.90-1.0)
    'ecstatic': 0.95, 'devastated': 0.95, 'furious': 0.95, 'terrified': 0.95,
    'overjoyed': 0.95, 'heartbroken': 0.95, 'enraged': 0.95, 'panicked': 0.95,
    'shattered': 0.92, 'crushed': 0.92, 'livid': 0.92, 'hopeless': 0.92,
    'despair': 0.90, 'despairing': 0.90, 'hateful': 0.90, 'traumatized': 0.90,

    // Very high amplitude emotions (0.80-0.89)
    'overwhelmed': 0.85, 'miserable': 0.85, 'outraged': 0.85, 'grief': 0.85,
    'grieving': 0.85, 'broken': 0.85, 'elated': 0.85, 'infuriated': 0.85,
    'excited': 0.80, 'anxious': 0.80, 'depressed': 0.80, 'bitter': 0.80,
    'resentful': 0.80, 'humiliated': 0.80, 'mortified': 0.80, 'disgusted': 0.80,

    // High amplitude emotions (0.70-0.79)
    'angry': 0.75, 'sad': 0.75, 'ashamed': 0.75, 'guilty': 0.75,
    'joyful': 0.75, 'inspired': 0.75, 'empowered': 0.75, 'loving': 0.75,
    'worried': 0.72, 'scared': 0.72, 'lonely': 0.72, 'abandoned': 0.72,
    'rejected': 0.72, 'worthless': 0.72, 'defeated': 0.72, 'trapped': 0.72,
    'hopeful': 0.70, 'frustrated': 0.70, 'stressed': 0.70, 'fearful': 0.70,

    // Medium-high amplitude (0.60-0.69)
    'happy': 0.65, 'nervous': 0.65, 'upset': 0.65, 'hurt': 0.65,
    'disappointed': 0.62, 'grateful': 0.62, 'irritated': 0.62, 'annoyed': 0.62,
    'embarrassed': 0.62, 'empty': 0.62, 'numb': 0.62, 'isolated': 0.62,
    'insecure': 0.60, 'helpless': 0.60, 'powerless': 0.60, 'drained': 0.60,
    'exhausted': 0.60, 'confused': 0.60, 'lost': 0.60, 'alone': 0.60,

    // Medium amplitude (0.50-0.59)
    'confident': 0.55, 'proud': 0.55, 'content': 0.55, 'satisfied': 0.55,
    'peaceful': 0.55, 'blessed': 0.55, 'appreciated': 0.55, 'loved': 0.55,
    'uncertain': 0.52, 'uneasy': 0.52, 'tense': 0.52, 'restless': 0.52,
    'regretful': 0.52, 'remorseful': 0.52, 'conflicted': 0.52, 'torn': 0.52,
    'heavy': 0.50, 'burdened': 0.50, 'dark': 0.50, 'gloomy': 0.50,

    // Lower-medium amplitude (0.40-0.49)
    'calm': 0.45, 'relaxed': 0.45, 'serene': 0.45, 'grounded': 0.45,
    'disconnected': 0.42, 'doubtful': 0.42, 'skeptical': 0.42, 'indecisive': 0.42,
    'discouraged': 0.42, 'deflated': 0.42, 'unfulfilled': 0.40, 'hollow': 0.40,

    // Low amplitude (0.30-0.39)
    'neutral': 0.35, 'stable': 0.35, 'steady': 0.35, 'balanced': 0.35,
    'centered': 0.35, 'unclear': 0.32, 'foggy': 0.32, 'hazy': 0.32,

    // Very low amplitude (0.20-0.29)
    'coherent': 0.25, 'focused': 0.25, 'curious': 0.25, 'wondering': 0.25,

    // Minimal amplitude (0.10-0.19)
    'aware': 0.15, 'mindful': 0.15, 'observing': 0.15, 'noticing': 0.15,
  };

  /// Extract enhanced keywords with RIVET gating and temporal analysis
  static KeywordExtractionResponse extractKeywords({
    required String entryText,
    required String currentPhase,
    RivetConfig config = _defaultConfig,
    Map<String, KeywordHistory>? keywordHistory,  // Optional historical data
  }) {
    // Step 1: Generate raw candidates
    final rawCandidates = _generateCandidates(entryText);

    // Step 2: Score candidates with existing equation (AS-IS)
    final scoredCandidates = _scoreCandidates(rawCandidates, entryText, currentPhase);

    // Step 2.5: Apply temporal adjustments if enabled and history provided
    if (config.enableTemporalAnalysis && keywordHistory != null) {
      _applyTemporalAdjustments(scoredCandidates, keywordHistory, config);
    }

    // Step 3: Apply RIVET gating
    final gatedCandidates = _applyRivetGating(scoredCandidates, config);

    // Step 4: Rank and truncate
    final rankedCandidates = _rankAndTruncate(gatedCandidates, config);

    // Step 5: Generate response
    return _generateResponse(rankedCandidates, currentPhase, config);
  }

  /// Apply temporal adjustments to candidate scores
  static void _applyTemporalAdjustments(
    List<Map<String, dynamic>> candidates,
    Map<String, KeywordHistory> history,
    RivetConfig config,
  ) {
    final now = DateTime.now();
    final lookbackCutoff = now.subtract(Duration(days: config.temporalLookbackDays));

    for (final candidate in candidates) {
      final keyword = candidate['keyword'] as String;
      final currentScore = candidate['score'] as double;
      final historyData = history[keyword.toLowerCase()];

      if (historyData == null) {
        // New keyword - apply underrepresented boost
        candidate['score'] = currentScore * config.underrepresentedBoost;
        candidate['temporal_adjustment'] = 'NEW_KEYWORD_BOOST';
        continue;
      }

      // Calculate usage frequency in lookback window
      final recentUsages = historyData.usageDates
          .where((date) => date.isAfter(lookbackCutoff))
          .length;

      final totalRecentEntries = history.values
          .expand((h) => h.usageDates)
          .where((date) => date.isAfter(lookbackCutoff))
          .toSet()
          .length;

      final usageRate = totalRecentEntries == 0 ? 0.0 : recentUsages / totalRecentEntries;

      // Apply adjustments based on usage patterns
      double adjustment = 1.0;
      String adjustmentReason = 'NONE';

      // Overused keywords get penalized
      if (usageRate > config.overuseThreshold) {
        adjustment = 0.85; // 15% penalty
        adjustmentReason = 'OVERUSE_PENALTY';
      }
      // Underused but relevant keywords get boosted
      else if (usageRate < 0.10 && currentScore > 0.3) {
        adjustment = config.underrepresentedBoost;
        adjustmentReason = 'UNDERREPRESENTED_BOOST';
      }
      // Keywords used recently but not overused maintain score
      else if (historyData.lastUsed != null &&
          historyData.lastUsed!.isAfter(now.subtract(const Duration(days: 7)))) {
        adjustment = 1.0;
        adjustmentReason = 'RECENT_USAGE_NEUTRAL';
      }
      // Long-dormant keywords get slight boost for diversity
      else if (historyData.lastUsed != null &&
          historyData.lastUsed!.isBefore(now.subtract(const Duration(days: 21)))) {
        adjustment = 1.10;
        adjustmentReason = 'DORMANT_DIVERSITY_BOOST';
      }

      candidate['score'] = (currentScore * adjustment).clamp(0.0, 1.0);
      candidate['temporal_adjustment'] = adjustmentReason;
      candidate['usage_rate'] = usageRate;
      candidate['recent_usages'] = recentUsages;
    }
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
      'neither', 'none', 'no', 'not', 'yes',
      // Pronouns and filler that add noise
      'i', 'im', 'ive', 'me', 'my', 'mine', 'myself',
      'you', 'your', 'yours', 'yourself', 'yourselves',
      'we', 'us', 'our', 'ours', 'ourselves',
      'they', 'them', 'their', 'theirs', 'themselves',
      'he', 'him', 'his', 'himself', 'she', 'her', 'hers', 'herself',
      'it', 'its', 'itself', 'be', 'being', 'been', 'am',
      'cause', 'because', 'due', 'etc', 'eg', 'ie',
      'new', 'initial', 'initially',
    };
    
    // Extract meaningful words; keep curated short terms, drop short generic tokens
    final extractedWords = <String>{};
    for (final raw in words) {
      final cleaned = raw.replaceAll(RegExp(r'[^\w]'), '');
      if (cleaned.isEmpty) continue;

      final isStopWord = stopWords.contains(cleaned);
      final isCurated = curatedKeywords.contains(cleaned);
      final isLongEnough = cleaned.length >= 4;

      if (isCurated || (!isStopWord && isLongEnough)) {
        extractedWords.add(cleaned);
      }
    }
    
    // Find matching curated keywords (only exact word matches, not partial)
    final matchingCurated = curatedKeywords
        .where((keyword) => _isExactWordMatch(textLower, keyword))
        .toSet();
    
    // Extract 2-word phrases for better context (favor specific, non-stop tokens)
    final phrases = <String>{};
    for (int i = 0; i < words.length - 1; i++) {
      final first = words[i].replaceAll(RegExp(r'[^\w]'), '');
      final second = words[i + 1].replaceAll(RegExp(r'[^\w]'), '');

      final firstOk = first.isNotEmpty && !stopWords.contains(first) &&
          (first.length >= 4 || curatedKeywords.contains(first));
      final secondOk = second.isNotEmpty && !stopWords.contains(second) &&
          (second.length >= 4 || curatedKeywords.contains(second));

      if (firstOk && secondOk) {
        final phrase = '$first $second';
        if (phrase.length <= 25) phrases.add(phrase); // Increased max length
      }
    }
    
    // Combine all candidates (only include curated keywords that actually appear in text)
    return {
      ...matchingCurated,
      ...extractedWords,
      ...phrases,
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
      final isInText = _isExactWordMatch(textLower, candidate.toLowerCase());
      final centrality = curatedKeywords.contains(candidate) 
          ? (isInText ? 0.9 : 0.0)  // Only score curated keywords if they're actually in text
          : (isInText ? 0.8 : 0.0); // Only score extracted words if they're in text
      
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

  /// Check if a keyword appears as an exact word in text (not as part of another word)
  static bool _isExactWordMatch(String text, String keyword) {
    final regex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b');
    return regex.hasMatch(text);
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

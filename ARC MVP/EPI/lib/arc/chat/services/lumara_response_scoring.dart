// lib/lumara/services/lumara_response_scoring.dart
// LUMARA Response Scoring Heuristic
// Evaluates responses for empathy:depth:agency balance and tone governance

/// Phase hint for context-aware scoring
enum PhaseHint {
  discovery,
  expansion,
  transition,
  consolidation,
  recovery,
  breakthrough,
}

/// Entry type for question bias tuning
enum EntryType {
  journal,
  draft,
  chat,
  photo,
  audio,
  video,
  voice,
}

/// Phase tuning for question bias
const Map<PhaseHint, String> _phaseTuning = {
  PhaseHint.discovery: 'high',
  PhaseHint.expansion: 'high',
  PhaseHint.transition: 'med',
  PhaseHint.consolidation: 'med',
  PhaseHint.recovery: 'low',
  PhaseHint.breakthrough: 'medHigh',
};

/// Entry type tuning for question bias
const Map<EntryType, String> _typeTuning = {
  EntryType.journal: 'med',
  EntryType.draft: 'high',
  EntryType.chat: 'med',
  EntryType.photo: 'low',
  EntryType.audio: 'low',
  EntryType.video: 'low',
  EntryType.voice: 'low',
};

/// Calculate question allowance based on phase, entry type, and abstract register
int questionAllowance(PhaseHint? phase, EntryType? entryType, bool isAbstract) {
  final p = phase != null ? _phaseTuning[phase] ?? 'med' : 'med';
  final t = entryType != null ? _typeTuning[entryType] ?? 'med' : 'med';
  
  final base = (p == 'high' ? 2 : p == 'medHigh' ? 2 : p == 'med' ? 1 : 1) +
               (t == 'high' ? 1 : t == 'med' ? 0 : 0);
  
  // Cap & adjust with Abstract Register rule
  final cap = isAbstract ? 2 : 1; // Abstract can lift to 2
  return [base, 1, 2, cap].reduce((a, b) => a < b ? a : b);
}

/// Input for scoring a LUMARA response
class ScoringInput {
  final String userText;
  final String candidate;
  final PhaseHint? phaseHint;
  final EntryType? entryType;
  final List<String> priorKeywords;
  final List<String> matchedNodeHints;

  const ScoringInput({
    required this.userText,
    required this.candidate,
    this.phaseHint,
    this.entryType,
    this.priorKeywords = const [],
    this.matchedNodeHints = const [],
  });
}

/// Detailed scoring breakdown
class ScoreBreakdown {
  final double empathy;
  final double depth;
  final double agency;
  final double structurePenalty;
  final double tonePenalty;
  final double resonance;
  final List<String> diagnostics;

  const ScoreBreakdown({
    required this.empathy,
    required this.depth,
    required this.agency,
    required this.structurePenalty,
    required this.tonePenalty,
    required this.resonance,
    required this.diagnostics,
  });
}

/// LUMARA Response Scoring Heuristic
/// Enhanced with Abstract Register detection for conceptual/reflective writing
class LumaraResponseScoring {
  // Abstract keywords for register detection
  static final List<String> _abstractKeywords = [
    'truth', 'meaning', 'purpose', 'reality', 'consequence', 'perspective', 'identity',
    'growth', 'preparation', 'journey', 'becoming', 'change', 'self', 'life', 'time',
    'energy', 'light', 'shadow', 'destiny', 'pattern', 'vision', 'clarity', 'understanding',
    'wisdom', 'insight', 'awareness', 'consciousness', 'essence', 'nature', 'spirit',
    'soul', 'heart', 'mind', 'being', 'existence', 'experience', 'transformation'
  ];

  // Bad tone patterns to penalize
  static final _badTonePatterns = [
    RegExp(r'\bwe\b', caseSensitive: false),
    RegExp(r'that s (amazing|awesome|great)!', caseSensitive: false),
    RegExp(r'!!!+'),
    RegExp(r'(smash|dont miss|keep going for more)', caseSensitive: false),
    RegExp(r'(as your therapist|diagnose|disorder)', caseSensitive: false),
  ];

  // Good invitational patterns to reward
  static final _goodInvitationalPatterns = [
    RegExp(r'\bwould it help\b', caseSensitive: false),
    RegExp(r'\bwhat feels\b', caseSensitive: false),
    RegExp(r'\bdoes it (fit|feel)\b', caseSensitive: false),
    RegExp(r'\bwhich (value|part)\b', caseSensitive: false),
    RegExp(r'\bif its right\b', caseSensitive: false),
  ];

  /// Detect if text is in abstract register
  static bool detectAbstractRegister(String text) {
    final words = text.toLowerCase().split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return false;
    
    final abstractCount = words.where((w) => _abstractKeywords.contains(w)).length;
    final ratio = abstractCount / words.length;
    
    final avgWordLen = words.join('').length / words.length;
    final sentenceCount = text.split(RegExp(r'[.!?]+')).length;
    final avgSentLen = words.length / sentenceCount;
    
    return (ratio > 0.03 && avgWordLen > 4.8 && avgSentLen > 9) || abstractCount >= 3;
  }

  /// Score a LUMARA response candidate
  /// Enhanced with Abstract Register detection for conceptual/reflective writing
  static ScoreBreakdown scoreLumaraResponse(ScoringInput input) {
    final diagnostics = <String>[];
    
    // Detect abstract register in user text
    final isAbstract = detectAbstractRegister(input.userText);
    if (isAbstract) {
      diagnostics.add('Abstract register detected - expecting 2 Clarify questions');
    }
    
    final userN = _normalizeText(input.userText);
    final candN = _normalizeText(input.candidate);
    
    final userSet = _tokenize(userN);
    final candSet = _tokenize(candN);
    
    // Structure checks
    final sentences = _splitSentences(input.candidate);
    final nSent = sentences.length;
    var structurePenalty = 0.0;
    
    if (nSent < 2) {
      structurePenalty += 0.25;
      diagnostics.add("Too short (<2 sentences).");
    }
    // Adjust length tolerance - allow longer responses for thorough answers
    // Increased limits to match in-journal LUMARA: 4-8 sentences for thorough answers
    final maxSentences = isAbstract ? 8 : 8; // Allow up to 8 sentences for thorough responses
    if (nSent > maxSentences) {
      structurePenalty += 0.1; // Reduced penalty - only penalize if extremely long (>8 sentences)
      diagnostics.add("Very long (>$maxSentences sentences) - consider if all content is necessary.");
    }
    
    final qCount = '?'.allMatches(input.candidate).length;
    // Calculate expected questions based on phase, entry type, and abstract register
    final expectedQuestions = questionAllowance(input.phaseHint, input.entryType, isAbstract);
    if (qCount < expectedQuestions) {
      structurePenalty += 0.2;
      diagnostics.add("Insufficient questions; expecting $expectedQuestions for ${isAbstract ? 'abstract' : 'concrete'} register with ${input.phaseHint?.name ?? 'unknown'} phase and ${input.entryType?.name ?? 'journal'} entry type.");
    }
    if (qCount > expectedQuestions + 1) {
      structurePenalty += 0.1;
      diagnostics.add("Too many questions; risks engagement feel.");
    }
    
    // Tone checks
    var tonePenalty = 0.0;
    for (final pattern in _badTonePatterns) {
      if (pattern.hasMatch(input.candidate)) {
        tonePenalty += 0.25;
        diagnostics.add("Tone issue: $pattern");
      }
    }
    
    final invitationalHits = _goodInvitationalPatterns
        .fold(0, (acc, pattern) => acc + (pattern.hasMatch(input.candidate) ? 1 : 0));
    
    // Phase-aware soft constraints
    if (input.phaseHint == PhaseHint.recovery) {
      if (RegExp(r'\byou should\b', caseSensitive: false).hasMatch(input.candidate)) {
        tonePenalty += 0.2;
        diagnostics.add("Directive tone discouraged in Recovery.");
      }
    }
    
    // Empathy score
    final overlap = _jaccard(userSet, candSet);
    var empathy = (overlap * 2.0).clamp(0.0, 1.0);
    // Soft boost if candidate references matched node gently
    if (input.matchedNodeHints.isNotEmpty &&
        RegExp(r'photo|entry|note|chat|draft', caseSensitive: false).hasMatch(candN)) {
      empathy = (empathy + 0.1).clamp(0.0, 1.0);
    }
    diagnostics.add("Empathy overlap=${overlap.toStringAsFixed(2)}");
    
    // Depth score
    final hasClarify = RegExp(r'\b(what|which|where|how|does|would)\b.*\?', caseSensitive: false)
        .hasMatch(input.candidate);
    final hasPattern = RegExp(
            r'\b(you have|you often|earlier|before|previous|pattern|theme|value)\b',
            caseSensitive: false).hasMatch(input.candidate) ||
        input.priorKeywords.any((k) => candN.contains(k.toLowerCase()));
    var depth = (hasClarify ? 0.5 : 0.0) + (hasPattern ? 0.4 : 0.0);
    if (invitationalHits > 0) depth += 0.1;
    // Boost depth score for abstract register (expects richer content)
    if (isAbstract) depth = (depth + 0.1).clamp(0.0, 1.0);
    depth = depth.clamp(0.0, 1.0);
    if (!hasPattern) diagnostics.add("Missing Highlight/pattern reflection.");
    if (!hasClarify) diagnostics.add("Missing Clarify question.");
    
    // Agency score
    final endsWithQuestion = RegExp(r'\?\s*$').hasMatch(input.candidate);
    final hasChoice = RegExp(r'\b(or|instead|if it|if that)\b', caseSensitive: false)
        .hasMatch(input.candidate);
    final avoidsPrescription =
        !RegExp(r'\b(you must|you need to|you should)\b', caseSensitive: false)
            .hasMatch(input.candidate);
    var agency = 0.0;
    if (endsWithQuestion) agency += 0.5;
    if (hasChoice) agency += 0.2;
    if (avoidsPrescription) agency += 0.3;
    if (invitationalHits > 0) agency += 0.1;
    agency = agency.clamp(0.0, 1.0);
    
    // Compose score with penalties
    final raw = 0.4 * empathy + 0.35 * depth + 0.25 * agency;
    final penalties = (structurePenalty + tonePenalty).clamp(0.0, 0.7);
    final resonance = (raw * (1 - penalties)).clamp(0.0, 1.0);
    
    return ScoreBreakdown(
      empathy: empathy,
      depth: depth,
      agency: agency,
      structurePenalty: structurePenalty,
      tonePenalty: tonePenalty,
      resonance: resonance,
      diagnostics: diagnostics,
    );
  }
  
  /// Auto-fix a response to meet ECHO standards
  static String autoTightenToEcho(String text) {
    // Remove exclamations
    var s = text.replaceAll(RegExp(r'!+'), '.');
    
    // Ensure <=4 sentences
    final parts = _splitSentences(s).take(4).toList();
    s = parts.join(' ');
    
    // Ensure exactly one invitational question at end using varied therapeutic closings
    if (!RegExp(r'\?\s*$').hasMatch(s)) {
      s = s.replaceAll(RegExp(r'\.\s*$'), '');
      s += '. ${_getTherapeuticClosingPhrase()}';
    }
    
    // Remove parasocial "we"
    s = s.replaceAll(RegExp(r'\bwe ', caseSensitive: false), 'you ');
    
    return s.trim();
  }

  /// Helper: normalize text
  static String _normalizeText(String t) {
    return t
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Helper: tokenize into set of words (length > 3)
  static Set<String> _tokenize(String t) {
    return t.split(' ').where((w) => w.length > 3).toSet();
  }

  /// Helper: Jaccard similarity
  static double _jaccard(Set<String> a, Set<String> b) {
    final inter = a.where((x) => b.contains(x)).length;
    final union = <String>[...a, ...b].toSet().length;
    return union == 0 ? 0 : inter / union;
  }

  /// Helper: split into sentences
  static List<String> _splitSentences(String t) {
    return t
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(RegExp(r'(?<=[\.\?\!])\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Get conservative, context-appropriate closing phrase
  /// NOTE: This is a fallback only. The LLM should generate contextually aligned endings
  /// based on the master prompt instructions. This function provides safe, generic endings
  /// when the LLM response doesn't already end with a question.
  /// 
  /// Conservative endings that work across contexts without introducing unrelated topics:
  static String _getTherapeuticClosingPhrase() {
    // Use a small set of conservative, context-neutral endings that don't shift focus
    // These are safe fallbacks that acknowledge the reflection without introducing new topics
    const conservativeEndings = [
      'What feels most important to you about this?',
      'Is there anything else you want to explore here?',
      'What would be helpful to focus on next?',
      'How does this sit with you?',
    ];
    
    // Use a simple rotation based on time (but with smaller set for more predictable behavior)
    final now = DateTime.now();
    final index = (now.second + now.minute) % conservativeEndings.length;
    
    return conservativeEndings[index];
  }
}

/// Minimum resonance threshold
const double minResonance = 0.62;


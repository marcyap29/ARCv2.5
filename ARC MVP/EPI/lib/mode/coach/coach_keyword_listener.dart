import 'dart:async';

class CoachKeywordListener {
  static const Map<String, double> _coachKeywords = {
    "coach": 1.0,
    "coaching": 1.0,
    "session": 0.9,
    "prep": 0.8,
    "homework": 0.8,
    "debrief": 0.8,
    "goals": 0.7,
    "accountability": 0.7,
    "check-in": 0.8,
    "therapy": 0.6,
    "therapist": 0.6,
    "mentor": 0.6,
    "checkin": 0.8,
    "therapeutic": 0.6,
    "guidance": 0.7,
    "support": 0.6,
    "reflection": 0.7,
    "insight": 0.7,
    "breakthrough": 0.8,
    "progress": 0.6,
    "development": 0.6,
    "growth": 0.6,
    "planning": 0.6,
    "strategy": 0.7,
    "action": 0.6,
    "commitment": 0.7,
    "follow-up": 0.7,
    "followup": 0.7,
    "review": 0.6,
    "assessment": 0.6,
  };

  static const double _threshold = 1.2;
  static const int _windowSize = 30;
  static const Duration _cooldownDuration = Duration(hours: 1);

  final StreamController<bool> _suggestionController = StreamController<bool>.broadcast();
  final Map<String, DateTime> _lastTriggered = {};

  Stream<bool> get suggestionStream => _suggestionController.stream;

  void dispose() {
    _suggestionController.close();
  }

  void analyzeText(String text, {String? contextId}) {
    if (text.isEmpty) return;

    // Check cooldown
    if (contextId != null && _lastTriggered.containsKey(contextId)) {
      final lastTriggered = _lastTriggered[contextId]!;
      if (DateTime.now().difference(lastTriggered) < _cooldownDuration) {
        return;
      }
    }

    final words = _extractWords(text);
    if (words.length < 3) return; // Need at least 3 words for meaningful analysis

    final score = _calculateScore(words);
    
    if (score >= _threshold) {
      _suggestionController.add(true);
      if (contextId != null) {
        _lastTriggered[contextId] = DateTime.now();
      }
    }
  }

  List<String> _extractWords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), ' ') // Remove punctuation except hyphens
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
  }

  double _calculateScore(List<String> words) {
    double totalScore = 0.0;
    int keywordCount = 0;

    // Use sliding window approach
    for (int i = 0; i <= words.length - _windowSize; i++) {
      final window = words.sublist(i, i + _windowSize);
      final windowScore = _calculateWindowScore(window);
      totalScore += windowScore;
      if (windowScore > 0) keywordCount++;
    }

    // Normalize by number of windows that contained keywords
    return keywordCount > 0 ? totalScore / keywordCount : 0.0;
  }

  double _calculateWindowScore(List<String> words) {
    double score = 0.0;
    final usedKeywords = <String>{};

    for (final word in words) {
      // Check exact match
      if (_coachKeywords.containsKey(word)) {
        if (!usedKeywords.contains(word)) {
          score += _coachKeywords[word]!;
          usedKeywords.add(word);
        }
      } else {
        // Check partial matches for compound words
        for (final keyword in _coachKeywords.keys) {
          if (word.contains(keyword) || keyword.contains(word)) {
            if (!usedKeywords.contains(keyword)) {
              score += _coachKeywords[keyword]! * 0.5; // Reduced score for partial match
              usedKeywords.add(keyword);
            }
          }
        }
      }
    }

    return score;
  }

  void resetCooldown(String contextId) {
    _lastTriggered.remove(contextId);
  }

  void resetAllCooldowns() {
    _lastTriggered.clear();
  }

  bool isInCooldown(String contextId) {
    if (!_lastTriggered.containsKey(contextId)) return false;
    
    final lastTriggered = _lastTriggered[contextId]!;
    return DateTime.now().difference(lastTriggered) < _cooldownDuration;
  }

  Duration getRemainingCooldown(String contextId) {
    if (!_lastTriggered.containsKey(contextId)) return Duration.zero;
    
    final lastTriggered = _lastTriggered[contextId]!;
    final elapsed = DateTime.now().difference(lastTriggered);
    final remaining = _cooldownDuration - elapsed;
    
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Map<String, double> getKeywordWeights() {
    return Map.unmodifiable(_coachKeywords);
  }

  double getThreshold() {
    return _threshold;
  }

  int getWindowSize() {
    return _windowSize;
  }
}

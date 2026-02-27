/// Filler Word Handler
/// 
/// Handles filler words ("um", "uh", "like", etc.) intelligently:
/// - Detects common filler words
/// - Adds grace period instead of full reset
/// - Differentiates between "thinking pause" vs "done speaking"
/// - Prevents premature endpoint detection during natural speech
library;

/// Filler word types
enum FillerType {
  thinkingSound,   // um, uh, er, ah
  softFiller,      // like, you know, I mean
  connector,       // so, well, and
}

/// Filler word data
class FillerWord {
  final String word;
  final FillerType type;
  final Duration gracePeriod;
  
  const FillerWord({
    required this.word,
    required this.type,
    required this.gracePeriod,
  });
}

/// Filler Word Handler
/// 
/// Provides intelligent handling of filler words in speech
class FillerWordHandler {
  /// Database of filler words with their types and grace periods
  static final List<FillerWord> _fillerWords = [
    // Thinking sounds - longest grace period (they're still thinking)
    const FillerWord(word: 'um', type: FillerType.thinkingSound, gracePeriod: Duration(milliseconds: 1000)),
    const FillerWord(word: 'uh', type: FillerType.thinkingSound, gracePeriod: Duration(milliseconds: 1000)),
    const FillerWord(word: 'er', type: FillerType.thinkingSound, gracePeriod: Duration(milliseconds: 1000)),
    const FillerWord(word: 'ah', type: FillerType.thinkingSound, gracePeriod: Duration(milliseconds: 1000)),
    const FillerWord(word: 'hmm', type: FillerType.thinkingSound, gracePeriod: Duration(milliseconds: 1000)),
    
    // Soft fillers - medium grace period
    const FillerWord(word: 'like', type: FillerType.softFiller, gracePeriod: Duration(milliseconds: 800)),
    const FillerWord(word: 'you know', type: FillerType.softFiller, gracePeriod: Duration(milliseconds: 800)),
    const FillerWord(word: 'i mean', type: FillerType.softFiller, gracePeriod: Duration(milliseconds: 800)),
    const FillerWord(word: 'kind of', type: FillerType.softFiller, gracePeriod: Duration(milliseconds: 800)),
    const FillerWord(word: 'sort of', type: FillerType.softFiller, gracePeriod: Duration(milliseconds: 800)),
    
    // Connectors - shorter grace period (might be transitioning)
    const FillerWord(word: 'so', type: FillerType.connector, gracePeriod: Duration(milliseconds: 600)),
    const FillerWord(word: 'well', type: FillerType.connector, gracePeriod: Duration(milliseconds: 600)),
    const FillerWord(word: 'and', type: FillerType.connector, gracePeriod: Duration(milliseconds: 600)),
    const FillerWord(word: 'but', type: FillerType.connector, gracePeriod: Duration(milliseconds: 600)),
  ];
  
  /// Default grace period for unrecognized fillers
  static const Duration _defaultGracePeriod = Duration(milliseconds: 800);
  
  /// Check if a word is a filler word
  bool isFillerWord(String word) {
    final normalized = word.toLowerCase().trim();
    return _fillerWords.any((fw) => fw.word == normalized);
  }
  
  /// Get filler word data
  FillerWord? getFillerWord(String word) {
    final normalized = word.toLowerCase().trim();
    try {
      return _fillerWords.firstWhere((fw) => fw.word == normalized);
    } catch (e) {
      return null;
    }
  }
  
  /// Get grace period for a specific word
  Duration getGracePeriod({String? word}) {
    if (word == null) {
      return _defaultGracePeriod;
    }
    
    final fillerWord = getFillerWord(word);
    return fillerWord?.gracePeriod ?? _defaultGracePeriod;
  }
  
  /// Get grace period by filler type
  Duration getGracePeriodByType(FillerType type) {
    final fillers = _fillerWords.where((fw) => fw.type == type);
    if (fillers.isEmpty) {
      return _defaultGracePeriod;
    }
    
    // Return average grace period for this type
    final total = fillers.fold<int>(
      0, 
      (sum, fw) => sum + fw.gracePeriod.inMilliseconds,
    );
    return Duration(milliseconds: total ~/ fillers.length);
  }
  
  /// Check if transcript ends with filler word
  bool endsWithFiller(String transcript) {
    if (transcript.trim().isEmpty) return false;
    
    final words = transcript.trim().toLowerCase().split(RegExp(r'\s+'));
    if (words.isEmpty) return false;
    
    final lastWord = words.last;
    return isFillerWord(lastWord);
  }
  
  /// Get last filler word from transcript
  String? getLastFillerWord(String transcript) {
    if (transcript.trim().isEmpty) return null;
    
    final words = transcript.trim().toLowerCase().split(RegExp(r'\s+'));
    if (words.isEmpty) return null;
    
    final lastWord = words.last;
    return isFillerWord(lastWord) ? lastWord : null;
  }
  
  /// Count consecutive filler words at end of transcript
  int countTrailingFillers(String transcript) {
    if (transcript.trim().isEmpty) return 0;
    
    final words = transcript.trim().toLowerCase().split(RegExp(r'\s+'));
    int count = 0;
    
    for (int i = words.length - 1; i >= 0; i--) {
      if (isFillerWord(words[i])) {
        count++;
      } else {
        break;
      }
    }
    
    return count;
  }
  
  /// Check if we're in a "filler storm" (multiple consecutive fillers)
  bool isFillerStorm(String transcript) {
    return countTrailingFillers(transcript) >= 3;
  }
  
  /// Get recommended action for filler detection
  FillerAction getRecommendedAction(String transcript) {
    if (!endsWithFiller(transcript)) {
      return FillerAction.none;
    }
    
    final fillerCount = countTrailingFillers(transcript);
    
    if (fillerCount >= 3) {
      // Filler storm - they might be struggling, give more time
      return FillerAction.extendThreshold;
    } else if (fillerCount == 2) {
      // Two fillers - add grace but watch closely
      return FillerAction.addGracePeriod;
    } else {
      // Single filler - normal grace period
      return FillerAction.addGracePeriod;
    }
  }
  
  /// Get all filler words in transcript
  List<String> findAllFillers(String transcript) {
    if (transcript.trim().isEmpty) return [];
    
    final words = transcript.trim().toLowerCase().split(RegExp(r'\s+'));
    return words.where(isFillerWord).toList();
  }
  
  /// Calculate filler density (percentage of words that are fillers)
  double calculateFillerDensity(String transcript) {
    if (transcript.trim().isEmpty) return 0.0;
    
    final words = transcript.trim().toLowerCase().split(RegExp(r'\s+'));
    if (words.isEmpty) return 0.0;
    
    final fillerCount = words.where(isFillerWord).length;
    return fillerCount / words.length;
  }
  
  /// Get detailed analysis of fillers in transcript
  Map<String, dynamic> analyzeFillers(String transcript) {
    final fillers = findAllFillers(transcript);
    final density = calculateFillerDensity(transcript);
    final trailingCount = countTrailingFillers(transcript);
    final isStorm = isFillerStorm(transcript);
    final endsWithFillerWord = endsWithFiller(transcript);
    
    return {
      'fillers': fillers,
      'filler_count': fillers.length,
      'filler_density': density,
      'trailing_fillers': trailingCount,
      'is_filler_storm': isStorm,
      'ends_with_filler': endsWithFillerWord,
      'recommended_action': getRecommendedAction(transcript).toString(),
    };
  }
}

/// Recommended action based on filler detection
enum FillerAction {
  none,              // No filler detected
  addGracePeriod,    // Add grace period for single/double filler
  extendThreshold,   // Extend threshold significantly for filler storm
}

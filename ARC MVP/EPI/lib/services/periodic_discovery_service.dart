import 'package:shared_preferences/shared_preferences.dart';
import 'phase_aware_analysis_service.dart';
import 'dignified_text_service.dart';
import '../telemetry/analytics.dart';

class PeriodicDiscoveryService {
  static final PeriodicDiscoveryService _instance = PeriodicDiscoveryService._internal();
  factory PeriodicDiscoveryService() => _instance;
  PeriodicDiscoveryService._internal();

  static const String _activationCountKey = 'lumara_activation_count';
  static const String _lastDiscoveryKey = 'last_discovery_date';
  static const int _discoveryInterval = 3; // Every 3rd activation

  final Analytics _analytics = Analytics();
  final PhaseAwareAnalysisService _phaseService = PhaseAwareAnalysisService();
  final DignifiedTextService _dignifiedService = DignifiedTextService();

  /// Check if it's time to show a discovery popup
  Future<bool> shouldShowDiscovery() async {
    final prefs = await SharedPreferences.getInstance();
    final activationCount = prefs.getInt(_activationCountKey) ?? 0;
    final lastDiscovery = prefs.getString(_lastDiscoveryKey);
    
    // Check if it's been at least 3 activations since last discovery
    final shouldShow = activationCount > 0 && 
                      activationCount % _discoveryInterval == 0 &&
                      (lastDiscovery == null || 
                       DateTime.now().difference(DateTime.parse(lastDiscovery)).inDays >= 1);
    
    return shouldShow;
  }

  /// Increment activation count
  Future<void> incrementActivationCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_activationCountKey) ?? 0;
    await prefs.setInt(_activationCountKey, currentCount + 1);
    
    _analytics.log('lumara_activation_count', {
      'count': currentCount + 1,
      'nextDiscoveryAt': ((currentCount + 1) ~/ _discoveryInterval + 1) * _discoveryInterval,
    });
  }

  /// Generate a unique discovery suggestion based on recent entries
  Future<DiscoverySuggestion> generateDiscoverySuggestion({
    required List<String> recentEntries,
    required String currentPhase,
  }) async {
    try {
      // Analyze the most recent entry for phase context
      final latestEntry = recentEntries.isNotEmpty ? recentEntries.first : '';
      final phaseContext = await _phaseService.analyzePhase(latestEntry);
      
      // Generate a unique discovery based on patterns
      final discovery = await _generateUniqueDiscovery(
        recentEntries: recentEntries,
        phaseContext: phaseContext,
        currentPhase: currentPhase,
      );
      
      // Mark discovery as shown
      await _markDiscoveryShown();
      
      _analytics.log('lumara_discovery_generated', {
        'detectedPhase': phaseContext.primaryPhase.name,
        'phaseConfidence': phaseContext.confidence,
        'discoveryType': discovery.type.name,
        'entriesAnalyzed': recentEntries.length,
      });
      
      return discovery;
    } catch (e) {
      _analytics.log('lumara_discovery_error', {'error': e.toString()});
      
      // Fallback discovery
      return DiscoverySuggestion(
        title: 'LUMARA has an insight for you',
        message: 'Based on your recent entries, I\'ve noticed some interesting patterns. Would you like to explore them?',
        suggestion: 'What patterns have you noticed in your recent reflections?',
        type: DiscoveryType.pattern,
        phaseContext: null,
      );
    }
  }

  /// Generate a unique discovery based on analysis
  Future<DiscoverySuggestion> _generateUniqueDiscovery({
    required List<String> recentEntries,
    required PhaseContext phaseContext,
    required String currentPhase,
  }) async {
    // Analyze patterns across recent entries
    final patterns = _analyzePatterns(recentEntries);
    final emotions = _analyzeEmotionalTrends(recentEntries);
    final themes = _analyzeThemes(recentEntries);
    
    // Determine discovery type based on patterns
    final discoveryType = _determineDiscoveryType(patterns, emotions, themes, phaseContext);
    
    // Generate discovery content using ECHO for dignified text
    final discovery = await _createDignifiedDiscoveryContent(
      type: discoveryType,
      patterns: patterns,
      emotions: emotions,
      themes: themes,
      phaseContext: phaseContext,
      currentPhase: currentPhase,
    );
    
    return discovery;
  }

  /// Analyze patterns across recent entries
  Map<String, dynamic> _analyzePatterns(List<String> entries) {
    final patterns = <String, int>{};
    final allWords = <String>[];
    
    for (final entry in entries) {
      final words = entry.toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((word) => word.length > 3)
          .toList();
      allWords.addAll(words);
    }
    
    // Count word frequencies
    for (final word in allWords) {
      patterns[word] = (patterns[word] ?? 0) + 1;
    }
    
    // Find most common words
    final commonWords = patterns.entries
        .where((e) => e.value > 1)
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    
    return {
      'commonWords': commonWords.take(5).map((e) => e.key).toList(),
      'totalWords': allWords.length,
      'uniqueWords': patterns.length,
      'repetitionRate': commonWords.isNotEmpty ? commonWords.first.value / allWords.length : 0.0,
    };
  }

  /// Analyze emotional trends across entries
  Map<String, dynamic> _analyzeEmotionalTrends(List<String> entries) {
    final emotionalWords = {
      'positive': ['happy', 'joy', 'excited', 'grateful', 'content', 'peaceful', 'hopeful', 'love', 'amazing', 'wonderful'],
      'negative': ['sad', 'angry', 'frustrated', 'anxious', 'worried', 'scared', 'depressed', 'hurt', 'pain', 'difficult'],
      'neutral': ['calm', 'focused', 'balanced', 'stable', 'centered', 'grounded', 'okay', 'fine', 'normal'],
    };
    
    final scores = <String, int>{};
    for (final entry in entries) {
      final words = entry.toLowerCase().split(RegExp(r'\s+'));
      for (final category in emotionalWords.keys) {
        for (final word in emotionalWords[category]!) {
          if (words.contains(word)) {
            scores[category] = (scores[category] ?? 0) + 1;
          }
        }
      }
    }
    
    return {
      'scores': scores,
      'dominantEmotion': scores.entries.isNotEmpty ? 
          scores.entries.reduce((a, b) => a.value > b.value ? a : b).key : 'neutral',
      'emotionalRange': scores.length,
    };
  }

  /// Analyze themes across entries
  Map<String, dynamic> _analyzeThemes(List<String> entries) {
    final themeKeywords = {
      'work': ['work', 'job', 'career', 'office', 'meeting', 'project', 'boss', 'colleague'],
      'relationships': ['friend', 'family', 'partner', 'relationship', 'love', 'marriage', 'dating'],
      'health': ['health', 'exercise', 'diet', 'doctor', 'medicine', 'pain', 'sick', 'wellness'],
      'personal': ['goal', 'dream', 'future', 'plan', 'growth', 'learning', 'skill', 'hobby'],
      'challenges': ['problem', 'challenge', 'difficult', 'struggle', 'obstacle', 'issue', 'crisis'],
    };
    
    final themeScores = <String, int>{};
    for (final entry in entries) {
      final words = entry.toLowerCase().split(RegExp(r'\s+'));
      for (final theme in themeKeywords.keys) {
        for (final keyword in themeKeywords[theme]!) {
          if (words.contains(keyword)) {
            themeScores[theme] = (themeScores[theme] ?? 0) + 1;
          }
        }
      }
    }
    
    return {
      'scores': themeScores,
      'dominantTheme': themeScores.entries.isNotEmpty ? 
          themeScores.entries.reduce((a, b) => a.value > b.value ? a : b).key : 'personal',
      'themeDiversity': themeScores.length,
    };
  }

  /// Determine discovery type based on analysis
  DiscoveryType _determineDiscoveryType(
    Map<String, dynamic> patterns,
    Map<String, dynamic> emotions,
    Map<String, dynamic> themes,
    PhaseContext phaseContext,
  ) {
    // Check for emotional patterns
    if (emotions['dominantEmotion'] == 'positive' && emotions['scores']['positive']! > 2) {
      return DiscoveryType.celebration;
    }
    
    if (emotions['dominantEmotion'] == 'negative' && emotions['scores']['negative']! > 2) {
      return DiscoveryType.support;
    }
    
    // Check for repetitive patterns
    if (patterns['repetitionRate'] > 0.1) {
      return DiscoveryType.pattern;
    }
    
    // Check for theme concentration
    if (themes['themeDiversity'] == 1 && themes['scores'].values.any((v) => v > 2)) {
      return DiscoveryType.focus;
    }
    
    // Check for phase-specific discoveries
    switch (phaseContext.primaryPhase) {
      case UserPhase.breakthrough:
        return DiscoveryType.breakthrough;
      case UserPhase.reflection:
        return DiscoveryType.support;
      case UserPhase.planning:
        return DiscoveryType.selfcare;
      case UserPhase.discovery:
        return DiscoveryType.exploration;
      default:
        return DiscoveryType.insight;
    }
  }

  /// Create dignified discovery content using ECHO
  Future<DiscoverySuggestion> _createDignifiedDiscoveryContent({
    required DiscoveryType type,
    required Map<String, dynamic> patterns,
    required Map<String, dynamic> emotions,
    required Map<String, dynamic> themes,
    required PhaseContext phaseContext,
    required String currentPhase,
  }) async {
    try {
      // Use ECHO to generate dignified content
      final discoveryContent = await _dignifiedService.generateDignifiedDiscovery(
        discoveryType: type.name,
        phase: currentPhase,
        patterns: patterns,
      );
      
      return DiscoverySuggestion(
        title: discoveryContent['title'] ?? _getFallbackTitle(type),
        message: discoveryContent['message'] ?? _getFallbackMessage(type),
        suggestion: discoveryContent['suggestion'] ?? _getFallbackSuggestion(type),
        type: type,
        phaseContext: phaseContext,
      );
    } catch (e) {
      _analytics.log('dignified_discovery_error', {'error': e.toString()});
      
      // Fallback to gentle, dignified content
      return DiscoverySuggestion(
        title: _getFallbackTitle(type),
        message: _getFallbackMessage(type),
        suggestion: _getFallbackSuggestion(type),
        type: type,
        phaseContext: phaseContext,
      );
    }
  }


  /// Mark discovery as shown
  Future<void> _markDiscoveryShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDiscoveryKey, DateTime.now().toIso8601String());
  }

  /// Reset activation count (for testing)
  Future<void> resetActivationCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activationCountKey);
    await prefs.remove(_lastDiscoveryKey);
  }

  /// Get fallback title for discovery type
  String _getFallbackTitle(DiscoveryType type) {
    switch (type) {
      case DiscoveryType.pattern:
        return 'LUMARA noticed something interesting';
      case DiscoveryType.celebration:
        return 'LUMARA wants to celebrate with you';
      case DiscoveryType.support:
        return 'LUMARA is here to support you';
      case DiscoveryType.focus:
        return 'LUMARA found your focus area';
      case DiscoveryType.breakthrough:
        return 'LUMARA senses a breakthrough';
      case DiscoveryType.selfcare:
        return 'LUMARA cares about your wellbeing';
      case DiscoveryType.exploration:
        return 'LUMARA found something to explore';
      case DiscoveryType.insight:
        return 'LUMARA has an insight for you';
    }
  }

  /// Get fallback message for discovery type
  String _getFallbackMessage(DiscoveryType type) {
    switch (type) {
      case DiscoveryType.pattern:
        return 'I\'ve noticed some interesting patterns in your recent entries. Would you like to explore what they might mean?';
      case DiscoveryType.celebration:
        return 'I\'ve noticed a lot of positive energy in your recent entries. Let\'s explore what\'s bringing you joy!';
      case DiscoveryType.support:
        return 'I\'ve sensed some challenges in your recent entries. I\'m here to help you process and work through them.';
      case DiscoveryType.focus:
        return 'I\'ve noticed you\'ve been writing a lot about a particular area. This seems to be an important focus for you right now.';
      case DiscoveryType.breakthrough:
        return 'I\'ve detected signs of a potential breakthrough in your recent entries. Let\'s explore this momentum!';
      case DiscoveryType.selfcare:
        return 'I\'ve noticed you might be feeling overwhelmed. Let\'s focus on what you need to feel more balanced.';
      case DiscoveryType.exploration:
        return 'I\'ve detected a sense of curiosity and exploration in your entries. Let\'s dive deeper!';
      case DiscoveryType.insight:
        return 'I\'ve discovered something interesting in your recent entries. Would you like to explore this insight?';
    }
  }

  /// Get fallback suggestion for discovery type
  String _getFallbackSuggestion(DiscoveryType type) {
    switch (type) {
      case DiscoveryType.pattern:
        return 'What do you think these patterns might be telling you about yourself?';
      case DiscoveryType.celebration:
        return 'What has been bringing you the most joy recently, and how can you cultivate more of it?';
      case DiscoveryType.support:
        return 'What support do you need most right now, and how can you give it to yourself?';
      case DiscoveryType.focus:
        return 'What deeper insights can you gain by exploring this area further?';
      case DiscoveryType.breakthrough:
        return 'What breakthrough are you experiencing, and how can you build on this energy?';
      case DiscoveryType.selfcare:
        return 'What would help you feel more rested and restored right now?';
      case DiscoveryType.exploration:
        return 'What new territory are you exploring, and what questions does it raise for you?';
      case DiscoveryType.insight:
        return 'What new understanding are you gaining about yourself or your situation?';
    }
  }
}

enum DiscoveryType {
  pattern,
  celebration,
  support,
  focus,
  breakthrough,
  selfcare,
  exploration,
  insight,
}

class DiscoverySuggestion {
  final String title;
  final String message;
  final String suggestion;
  final DiscoveryType type;
  final PhaseContext? phaseContext;

  DiscoverySuggestion({
    required this.title,
    required this.message,
    required this.suggestion,
    required this.type,
    this.phaseContext,
  });
}

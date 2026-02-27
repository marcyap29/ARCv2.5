import '../echo/echo_service.dart';
import '../echo/models/data/context_provider.dart';
import '../echo/models/data/context_scope.dart';

/// Service for generating dignified, user-facing text using ECHO module
class DignifiedTextService {
  static final DignifiedTextService _instance = DignifiedTextService._internal();
  factory DignifiedTextService() => _instance;
  DignifiedTextService._internal();

  late final EchoService _echoService;
  bool _initialized = false;

  /// Initialize the ECHO service
  Future<void> initialize() async {
    if (_initialized) return;
    
    const scope = LumaraScope(journal: true, phase: true);
    final contextProvider = ContextProvider(scope);
    _echoService = EchoService(contextProvider: contextProvider);
    _initialized = true;
  }

  /// Generate dignified phase-aware analysis text
  Future<String> generateDignifiedAnalysis({
    required String entryText,
    required String phase,
    required Map<String, dynamic> emotionalState,
    required Map<String, dynamic> physicalState,
  }) async {
    await initialize();

    // Create a dignified analysis request
    final analysisRequest = _createAnalysisRequest(entryText, phase, emotionalState, physicalState);
    
    try {
      final response = await _echoService.generateResponse(
        utterance: analysisRequest,
        timestamp: DateTime.now(),
        arcSource: 'journal_entry',
        resonanceMode: 'balanced',
        stylePrefs: _getDignifiedStylePrefs(phase),
      );
      
      return response.content;
    } catch (e) {
      // Fallback to gentle, dignified text
      return _getFallbackAnalysis(phase);
    }
  }

  /// Generate dignified AI suggestions
  Future<List<String>> generateDignifiedSuggestions({
    required String entryText,
    required String phase,
    required Map<String, dynamic> emotionalState,
  }) async {
    await initialize();

    final suggestionsRequest = _createSuggestionsRequest(entryText, phase, emotionalState);
    
    try {
      final response = await _echoService.generateResponse(
        utterance: suggestionsRequest,
        timestamp: DateTime.now(),
        arcSource: 'journal_entry',
        resonanceMode: 'supportive',
        stylePrefs: _getDignifiedStylePrefs(phase),
      );
      
      return _parseSuggestions(response.content);
    } catch (e) {
      // Fallback to gentle, dignified suggestions
      return _getFallbackSuggestions(phase);
    }
  }

  /// Generate dignified discovery popup content
  Future<Map<String, String>> generateDignifiedDiscovery({
    required String discoveryType,
    required String phase,
    required Map<String, dynamic> patterns,
  }) async {
    await initialize();

    final discoveryRequest = _createDiscoveryRequest(discoveryType, phase, patterns);
    
    try {
      final response = await _echoService.generateResponse(
        utterance: discoveryRequest,
        timestamp: DateTime.now(),
        arcSource: 'discovery',
        resonanceMode: 'gentle',
        stylePrefs: _getDignifiedStylePrefs(phase),
      );
      
      return _parseDiscoveryContent(response.content, discoveryType);
    } catch (e) {
      // Fallback to gentle, dignified discovery content
      return _getFallbackDiscoveryContent(discoveryType);
    }
  }

  String _createAnalysisRequest(String entryText, String phase, Map<String, dynamic> emotionalState, Map<String, dynamic> physicalState) {
    return '''
Please provide a gentle, dignified analysis of this journal entry. The user is in a $phase phase.

Entry: $entryText
Emotional state: ${_summarizeState(emotionalState)}
Physical state: ${_summarizeState(physicalState)}

Please provide:
- A compassionate, non-judgmental analysis
- Focus on strengths and growth opportunities
- Use gentle, supportive language
- Avoid triggering or overwhelming language
- Acknowledge their courage in sharing
''';
  }

  String _createSuggestionsRequest(String entryText, String phase, Map<String, dynamic> emotionalState) {
    return '''
Please generate 4-6 gentle, dignified reflection suggestions for this journal entry. The user is in a $phase phase.

Entry: $entryText
Emotional state: ${_summarizeState(emotionalState)}

Please provide:
- Gentle, open-ended questions
- Focus on self-discovery and growth
- Use supportive, non-judgmental language
- Avoid overwhelming or complex prompts
- Encourage self-compassion and reflection
''';
  }

  String _createDiscoveryRequest(String discoveryType, String phase, Map<String, dynamic> patterns) {
    return '''
Please create a gentle, dignified discovery popup for a user in a $phase phase. Discovery type: $discoveryType

Patterns detected: ${_summarizePatterns(patterns)}

Please provide:
- A warm, encouraging title
- A gentle, supportive message
- A thoughtful, open-ended suggestion
- Use language that honors their dignity
- Avoid overwhelming or triggering language
''';
  }

  Map<String, String> _parseDiscoveryContent(String content, String discoveryType) {
    // Simple parsing - in a real implementation, this would be more sophisticated
    final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    return {
      'title': lines.isNotEmpty ? lines[0] : 'LUMARA has an insight for you',
      'message': lines.length > 1 ? lines[1] : 'I\'ve noticed something interesting in your recent entries.',
      'suggestion': lines.length > 2 ? lines[2] : 'What patterns are you noticing in your reflections?',
    };
  }

  List<String> _parseSuggestions(String content) {
    return content
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.replaceAll(RegExp(r'^\d+\.\s*'), '').trim())
        .where((suggestion) => suggestion.isNotEmpty)
        .take(6)
        .toList();
  }

  Map<String, String> _getDignifiedStylePrefs(String phase) {
    return {
      'tone': 'gentle',
      'approach': 'supportive',
      'language': 'dignified',
      'phase': phase,
      'avoid_triggers': 'true',
    };
  }

  String _summarizeState(Map<String, dynamic> state) {
    if (state.isEmpty) return 'neutral';
    final dominant = state.entries.reduce((a, b) => a.value > b.value ? a : b);
    return '${dominant.key} (${dominant.value})';
  }

  String _summarizePatterns(Map<String, dynamic> patterns) {
    final commonWords = patterns['commonWords'] as List<String>? ?? [];
    return commonWords.take(3).join(', ');
  }

  String _getFallbackAnalysis(String phase) {
    return 'I can see you\'re in a period of $phase. Your reflections show thoughtfulness and courage. What would you like to explore further about this experience?';
  }

  List<String> _getFallbackSuggestions(String phase) {
    return [
      'What feels most important to you about this experience?',
      'How has this changed your perspective?',
      'What strengths do you see in yourself?',
      'What would you like to understand better?',
      'How can you honor your growth?',
    ];
  }

  Map<String, String> _getFallbackDiscoveryContent(String discoveryType) {
    return {
      'title': 'LUMARA has an insight for you',
      'message': 'I\'ve noticed some interesting patterns in your recent entries. Would you like to explore them together?',
      'suggestion': 'What patterns are you noticing in your reflections?',
    };
  }
}

/// ECHO Service - Expressive Contextual Heuristic Output
///
/// Core service that implements the ECHO system for generating dignified,
/// phase-aware responses that maintain LUMARA's voice across all interactions.

import 'dart:convert';
import 'package:my_app/services/gemini_send.dart';
import 'package:my_app/services/llm_bridge_adapter.dart';

import 'core/atlas_phase_integration.dart';
import 'core/mira_memory_grounding.dart';
import 'safety/rivet_lite_validator.dart';
import 'voice/lumara_voice_controller.dart';
import 'prompts/echo_system_prompt.dart';
import 'models/data/context_provider.dart';
import 'package:my_app/polymeta/mira_service.dart';

/// Core ECHO service for generating contextual, dignified responses
class EchoService {
  final AtlasPhaseIntegration _phaseIntegration;
  final MiraMemoryGrounding _memoryGrounding;
  final ContextProvider _contextProvider;
  late final ArcLLM _arcLLM;

  EchoService({
    required ContextProvider contextProvider,
  })  : _phaseIntegration = AtlasPhaseIntegration(),
        _memoryGrounding = MiraMemoryGrounding(MiraService.instance),
        _contextProvider = contextProvider {
    _arcLLM = provideArcLLM();
  }

  /// Generate a dignified, phase-aware response using the ECHO system
  Future<EchoResponse> generateResponse({
    required String utterance,
    required DateTime timestamp,
    String arcSource = 'journal_entry',
    String resonanceMode = 'balanced',
    Map<String, String>? stylePrefs,
  }) async {
    try {
      // Step 1: Update phase detection from ATLAS
      await _phaseIntegration.updatePhaseDetection();
      final atlasPhase = _phaseIntegration.getCurrentPhase();
      final phaseRules = _phaseIntegration.getPhaseResponseParameters();

      // Step 2: Retrieve relevant memory nodes from MIRA
      final memoryContext = await _memoryGrounding.retrieveGroundingMemory(
        userUtterance: utterance,
        atlasPhase: atlasPhase,
        emotionalContext: 'neutral', // Will be analyzed in next step
        maxNodes: 5,
      );

      // Step 3: Analyze emotional context
      final emotionContext = await _analyzeEmotionalContext(utterance);

      // Step 4: Build ECHO prompt
      final prompt = EchoSystemPrompt.build(
        utterance: utterance,
        timestamp: timestamp,
        arcSource: arcSource,
        atlasPhase: atlasPhase,
        phaseRules: phaseRules,
        emotionVectorSummary: _formatEmotionContext(emotionContext),
        resonanceMode: resonanceMode,
        retrievedNodesBlock: _formatMemoryNodes(_convertGroundingNodesToMemoryNodes(memoryContext.nodes)),
        stylePrefs: stylePrefs ?? LumaraVoiceController.voiceCharacteristics,
      );

      // Step 5: Generate response through LLM provider
      final rawResponse = await _generateWithProvider(prompt);

      // Step 6: Apply RIVET-lite safety validation
      final validation = await RivetLiteValidator.validateResponse(
        response: rawResponse,
        originalUtterance: utterance,
        memoryNodeIds: memoryContext.nodes.map((node) => node.nodeId).toList(),
        groundingConfidence: memoryContext.nodes.isNotEmpty ? 0.8 : 0.3,
      );

      // Step 7: Handle validation results
      String finalResponse = rawResponse;
      if (validation.requiresRevision) {
        finalResponse = await _handleValidationFailure(
          originalResponse: rawResponse,
          validation: validation,
          prompt: prompt,
        );
      }

      // Step 8: Apply phase-aware emotional resonance if needed
      if (_phaseIntegration.isInTransition() || resonanceMode == 'expressive') {
        final emotionVector = _parseEmotionVector(emotionContext);
        final resonance = _phaseIntegration.getPhaseEmotionalResonance(emotionVector);
        finalResponse = _integrateEmotionalResonance(finalResponse, resonance);
      }

      return EchoResponse(
        content: finalResponse,
        atlasPhase: atlasPhase,
        emotionContext: emotionContext,
        memoryGrounding: _convertGroundingNodesToMemoryNodes(memoryContext.nodes),
        validation: validation,
        phaseStability: _phaseIntegration.getPhaseStability(),
        isTransition: _phaseIntegration.isInTransition(),
        timestamp: timestamp,
      );
    } catch (e) {
      // Graceful fallback with dignified error response
      return _createFallbackResponse(utterance, timestamp, e);
    }
  }

  /// Generate response through configured LLM provider
  Future<String> _generateWithProvider(String prompt) async {
    try {
      // Check if Gemini API key is available
      const apiKey = String.fromEnvironment('GEMINI_API_KEY');
      if (apiKey.isNotEmpty) {
        // Use direct Gemini API for ECHO responses
        final response = await _arcLLM.generateEchoResponse(prompt);
        return response;
      } else {
        // Fallback to rule-based dignified response
        return await _generateDignifiedFallback(prompt);
      }
    } catch (e) {
      // Ultimate fallback to ensure we never fail silently
      return await _generateDignifiedFallback(prompt);
    }
  }

  /// Analyze emotional context from user utterance
  Future<Map<String, dynamic>> _analyzeEmotionalContext(String utterance) async {
    // Simple emotion detection based on keyword analysis
    // In a full implementation, this would integrate with PRISM module
    final emotions = <String, double>{};
    final lowerUtterance = utterance.toLowerCase();

    // Basic emotion detection patterns
    if (lowerUtterance.contains(RegExp(r'\b(excited|happy|joy|thrilled)\b'))) {
      emotions['joy'] = 0.8;
    }
    if (lowerUtterance.contains(RegExp(r'\b(worried|anxious|nervous|scared)\b'))) {
      emotions['anxiety'] = 0.7;
    }
    if (lowerUtterance.contains(RegExp(r'\b(sad|depressed|down|blue)\b'))) {
      emotions['sadness'] = 0.6;
    }
    if (lowerUtterance.contains(RegExp(r'\b(angry|mad|frustrated|annoyed)\b'))) {
      emotions['anger'] = 0.6;
    }
    if (lowerUtterance.contains(RegExp(r'\b(curious|wondering|interested)\b'))) {
      emotions['curiosity'] = 0.7;
    }
    if (lowerUtterance.contains(RegExp(r'\b(tired|exhausted|drained|overwhelmed)\b'))) {
      emotions['exhaustion'] = 0.8;
    }
    if (lowerUtterance.contains(RegExp(r'\b(unclear|confused|lost|uncertain)\b'))) {
      emotions['uncertainty'] = 0.6;
    }

    return {
      'emotions': emotions,
      'valence': _calculateValence(emotions),
      'arousal': _calculateArousal(emotions),
      'complexity': emotions.length,
    };
  }

  /// Calculate emotional valence (positive/negative)
  double _calculateValence(Map<String, double> emotions) {
    final positive = ['joy', 'excitement', 'curiosity'].fold<double>(0.0,
        (sum, emotion) => sum + (emotions[emotion] ?? 0.0));
    final negative = ['anxiety', 'sadness', 'anger'].fold<double>(0.0,
        (sum, emotion) => sum + (emotions[emotion] ?? 0.0));

    if (positive + negative == 0) return 0.0;
    return (positive - negative) / (positive + negative);
  }

  /// Calculate emotional arousal (high/low energy)
  double _calculateArousal(Map<String, double> emotions) {
    final highArousal = ['excitement', 'anxiety', 'anger'].fold<double>(0.0,
        (sum, emotion) => sum + (emotions[emotion] ?? 0.0));
    final lowArousal = ['sadness', 'exhaustion'].fold<double>(0.0,
        (sum, emotion) => sum + (emotions[emotion] ?? 0.0));

    return highArousal > lowArousal ? highArousal : -lowArousal;
  }

  /// Format emotion context for prompt
  String _formatEmotionContext(Map<String, dynamic> context) {
    final emotions = context['emotions'] as Map<String, double>;
    final valence = context['valence'] as double;
    final arousal = context['arousal'] as double;

    if (emotions.isEmpty) {
      return 'Neutral emotional tone, balanced valence (${valence.toStringAsFixed(2)})';
    }

    final topEmotions = emotions.entries
        .where((e) => e.value > 0.5)
        .map((e) => '${e.key} (${e.value.toStringAsFixed(1)})')
        .join(', ');

    return 'Emotions: $topEmotions | Valence: ${valence.toStringAsFixed(2)} | Arousal: ${arousal.toStringAsFixed(2)}';
  }

  /// Format memory nodes for prompt
  String _formatMemoryNodes(List<MemoryNode> nodes) {
    if (nodes.isEmpty) {
      return 'No relevant memory nodes retrieved. Respond based on general knowledge and dignity principles.';
    }

    return nodes.map((node) =>
        'Node ${node.id}: ${node.content} (relevance: ${node.relevance.toStringAsFixed(2)})'
    ).join('\n');
  }

  /// Parse emotion vector from context
  Map<String, double> _parseEmotionVector(Map<String, dynamic> context) {
    return (context['emotions'] as Map<String, double>?) ?? {};
  }

  /// Integrate emotional resonance into response
  String _integrateEmotionalResonance(String response, String resonance) {
    // Simple integration - in production this would be more sophisticated
    if (resonance.isNotEmpty && !response.contains(resonance)) {
      return '$resonance\n\n$response';
    }
    return response;
  }

  /// Handle validation failure by attempting to revise response
  Future<String> _handleValidationFailure(
    {required String originalResponse,
    required ValidationResult validation,
    required String prompt}) async {

    if (validation.recommendedAction == ValidationAction.reject) {
      return await _generateDignifiedFallback(prompt);
    }

    // Attempt one revision based on violation feedback
    final revisionPrompt = '''$prompt

REVISION INSTRUCTION:
The previous response had validation issues:
${validation.violations.map((v) => '- ${v.description}: ${v.suggestedFix}').join('\n')}

Please revise to address these concerns while maintaining LUMARA's dignified voice.''';

    try {
      return await _generateWithProvider(revisionPrompt);
    } catch (e) {
      return await _generateDignifiedFallback(prompt);
    }
  }

  /// Generate dignified fallback response when technical generation fails
  Future<String> _generateDignifiedFallback(String prompt) async {
    // Extract the user utterance from the prompt for context-aware fallback
    final utteranceMatch = RegExp(r'User utterance: (.+)').firstMatch(prompt);
    final utterance = utteranceMatch?.group(1) ?? '';

    if (utterance.toLowerCase().contains('help')) {
      return '''I'm here to support you in understanding your patterns and growth.

While I'm experiencing some technical limitations right now, what matters most is that you're taking time to reflect and reach out.

What feels most important for you to explore or understand about your current experience?''';
    }

    if (utterance.toLowerCase().contains('how are you')) {
      return '''Thank you for asking. I'm present with you in this moment of connection.

I exist to witness and reflect your journey, to help you see the patterns and growth that emerge from your experiences.

How are you feeling right now? What's alive in your world today?''';
    }

    // Default dignified response that embodies LUMARA's essence
    return '''I'm here with you in this moment of reflection.

Your willingness to pause, to inquire, to seek understanding - these are acts of courage. Even when technology has its limits, the human impulse toward growth and meaning remains constant.

What feels most true for you right now?''';
  }

  /// Create fallback response for system errors
  EchoResponse _createFallbackResponse(String utterance, DateTime timestamp, dynamic error) {
    return EchoResponse(
      content: '''I'm experiencing some technical difficulties, but I want to acknowledge your reach for connection and understanding.

Your question matters, even when systems stumble. Sometimes the most profound responses come not from perfect technology, but from the simple recognition that you're taking time to reflect and grow.

What feels most important for you to explore right now?''',
      atlasPhase: 'Discovery',
      emotionContext: {'emotions': <String, double>{}, 'valence': 0.0, 'arousal': 0.0},
      memoryGrounding: [],
      validation: ValidationResult(
        isValid: true,
        safetyScore: 1.0,
        violations: [],
        rivetMetrics: RivetMetrics(
          contradictions: 0,
          hallucinations: 0,
          uncertaintyTriggers: 0,
          alignScore: 1.0,
          riskScore: 0.0,
        ),
        recommendedAction: ValidationAction.approve,
      ),
      phaseStability: 1.0,
      isTransition: false,
      timestamp: timestamp,
      error: error.toString(),
    );
  }

  /// Convert GroundingNode list to MemoryNode list
  List<MemoryNode> _convertGroundingNodesToMemoryNodes(List<dynamic> groundingNodes) {
    return groundingNodes.map((node) => MemoryNode(
      id: node.nodeId,
      content: node.content,
      relevance: node.relevanceScore,
      type: node.nodeType,
      timestamp: node.timestamp ?? DateTime.now(),
    )).toList();
  }
}

/// Response from ECHO system with full context and validation
class EchoResponse {
  final String content;
  final String atlasPhase;
  final Map<String, dynamic> emotionContext;
  final List<MemoryNode> memoryGrounding;
  final ValidationResult validation;
  final double phaseStability;
  final bool isTransition;
  final DateTime timestamp;
  final String? error;

  EchoResponse({
    required this.content,
    required this.atlasPhase,
    required this.emotionContext,
    required this.memoryGrounding,
    required this.validation,
    required this.phaseStability,
    required this.isTransition,
    required this.timestamp,
    this.error,
  });

  bool get hasError => error != null;
  bool get isValid => validation.isValid;
  double get safetyScore => validation.safetyScore;

  /// Get summary of grounding sources
  String get groundingSummary {
    if (memoryGrounding.isEmpty) return 'No memory grounding';
    return '${memoryGrounding.length} memory nodes (avg relevance: ${_averageRelevance.toStringAsFixed(2)})';
  }

  double get _averageRelevance {
    if (memoryGrounding.isEmpty) return 0.0;
    return memoryGrounding.fold<double>(0.0, (sum, node) => sum + node.relevance) / memoryGrounding.length;
  }
}

/// Memory node for MIRA integration
class MemoryNode {
  final String id;
  final String content;
  final double relevance;
  final String type;
  final DateTime timestamp;

  MemoryNode({
    required this.id,
    required this.content,
    required this.relevance,
    required this.type,
    required this.timestamp,
  });
}

/// Extension for ArcLLM to support ECHO responses
extension ArcLLMEchoExtension on ArcLLM {
  Future<String> generateEchoResponse(String prompt) async {
    // Use existing chat functionality but with ECHO-specific prompt structure
    return await chat(
      userIntent: 'Generate dignified response using ECHO system',
      entryText: prompt,
      phaseHintJson: null,
      lastKeywordsJson: null,
    );
  }
}
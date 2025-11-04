/// LUMARA VEIL-EDGE Integration
/// 
/// Integrates VEIL-EDGE with the existing LUMARA chat system to provide
/// phase-reactive restorative responses.
/// Updated to use unified LUMARA prompt system (EPI v2.1)

import 'dart:async';
import 'dart:convert';
import '../../chat/chat_models.dart';
import '../../chat/chat_repo.dart';
import '../models/veil_edge_models.dart';
import '../services/veil_edge_service.dart';
import '../../../../aurora/models/circadian_context.dart';
import '../../prompts/lumara_unified_prompts.dart' show LumaraUnifiedPrompts, LumaraContext;
import '../../../../services/gemini_send.dart';

/// Integration service for LUMARA and VEIL-EDGE
class LumaraVeilEdgeIntegration {
  final VeilEdgeService _veilEdgeService;
  final ChatRepo _chatRepo;

  LumaraVeilEdgeIntegration({
    required ChatRepo chatRepo,
    VeilEdgeService? veilEdgeService,
  }) : _chatRepo = chatRepo,
       _veilEdgeService = veilEdgeService ?? VeilEdgeService();

  /// Process a chat message through VEIL-EDGE with AURORA circadian integration
  Future<ChatMessage> processMessage({
    required String sessionId,
    required String userMessage,
    required Map<String, dynamic> context,
  }) async {
    try {
      // Extract signals from user message and context
      final signals = _extractSignalsFromMessage(userMessage, context);
      
      // Get or create ATLAS state from context
      final atlas = _extractAtlasFromContext(context);
      
      // Get or create SENTINEL state from context
      final sentinel = _extractSentinelFromContext(context);
      
      // Get current RIVET state
      final rivet = _veilEdgeService.getCurrentRivetState();
      
      // Route through VEIL-EDGE (now includes AURORA circadian context)
      final routeResult = await _veilEdgeService.route(
        signals: signals,
        atlas: atlas,
        sentinel: sentinel,
        rivet: rivet,
      );
      
      // Get circadian context for enhanced response
      final circadianContext = await _veilEdgeService.getCurrentCircadianContext();
      
      // Generate LUMARA response using unified prompts with VEIL-EDGE routing
      final lumaraResponse = await _generateLumaraResponseWithCircadian(
        routeResult: routeResult,
        signals: signals,
        userMessage: userMessage,
        circadianContext: circadianContext,
        atlas: atlas, // Pass AtlasState for phase context
      );
      
      // Create chat message
      final chatMessage = ChatMessage(
        id: 'msg:${DateTime.now().millisecondsSinceEpoch}',
        sessionId: sessionId,
        role: 'assistant',
        textContent: lumaraResponse,
        createdAt: DateTime.now(),
        provenance: jsonEncode({
          'veil_edge': {
            'phase_group': routeResult.phaseGroup,
            'variant': routeResult.variant,
            'blocks_used': routeResult.blocks,
            'metadata': routeResult.metadata,
          },
          'aurora': {
            'circadian_window': circadianContext.window,
            'chronotype': circadianContext.chronotype,
            'rhythm_score': circadianContext.rhythmScore,
          },
        }),
      );
      
      // Save message to repository
      await _chatRepo.addMessage(
        sessionId: sessionId,
        role: 'assistant',
        content: lumaraResponse,
      );
      
      // Process log for RIVET updates
      await _processLogForRivet(routeResult, userMessage, lumaraResponse);
      
      return chatMessage;
      
    } catch (e) {
      // Fallback to standard LUMARA response on error
      return await _createFallbackMessage(sessionId, userMessage, e.toString());
    }
  }

  /// Extract user signals from message and context
  UserSignals _extractSignalsFromMessage(String message, Map<String, dynamic> context) {
    // Simple extraction - in practice this would use NLP
    final words = message.toLowerCase().split(' ');
    final actions = <String>[];
    final feelings = <String>[];
    final outcomes = <String>[];
    
    // Extract actions (verbs)
    for (final word in words) {
      if (_isActionWord(word)) {
        actions.add(word);
      }
    }
    
    // Extract feelings (emotion words)
    for (final word in words) {
      if (_isFeelingWord(word)) {
        feelings.add(word);
      }
    }
    
    // Extract outcomes from context
    if (context.containsKey('recent_outcomes')) {
      outcomes.addAll(List<String>.from(context['recent_outcomes']));
    }
    
    return UserSignals(
      actions: actions,
      feelings: feelings,
      words: words,
      outcomes: outcomes,
    );
  }

  /// Extract ATLAS state from context
  AtlasState _extractAtlasFromContext(Map<String, dynamic> context) {
    final phase = context['atlas_phase'] as String? ?? 'Discovery';
    final confidence = (context['atlas_confidence'] as num?)?.toDouble() ?? 0.7;
    final neighbor = context['atlas_neighbor'] as String? ?? 'Transition';
    
    return AtlasState(
      phase: phase,
      confidence: confidence,
      neighbor: neighbor,
    );
  }

  /// Extract SENTINEL state from context
  SentinelState _extractSentinelFromContext(Map<String, dynamic> context) {
    final state = context['sentinel_state'] as String? ?? 'ok';
    final notes = List<String>.from(context['sentinel_notes'] ?? []);
    
    return SentinelState(
      state: state,
      notes: notes,
    );
  }

  /// Generate LUMARA response using unified prompts with VEIL-EDGE routing
  /// Uses unified prompt system with recovery context and phase/energy data
  Future<String> _generateLumaraResponseWithCircadian({
    required VeilEdgeRouteResult routeResult,
    required UserSignals signals,
    required String userMessage,
    required CircadianContext circadianContext,
    AtlasState? atlas,
  }) async {
    try {
      // Get unified system prompt with recovery context
      // Extract phase data from AtlasState or routeResult
      final phaseName = _extractPhaseFromRouteResult(routeResult, atlas);
      final readiness = atlas?.confidence ?? 0.5;
      
      final systemPrompt = await LumaraUnifiedPrompts.instance.getSystemPrompt(
        context: LumaraContext.recovery,
        phaseData: {
          'phase': phaseName,
          'readiness': readiness,
        },
        energyData: {
          'level': _extractEnergyLevel(circadianContext),
          'timeOfDay': circadianContext.window,
        },
      );
      
      // Build user prompt incorporating VEIL-EDGE routing context
      final userPrompt = _buildUserPromptWithVeilContext(
        userMessage: userMessage,
        routeResult: routeResult,
        signals: signals,
        circadianContext: circadianContext,
      );
      
      // Call LLM with unified prompt system
      final response = await geminiSend(
        system: systemPrompt,
        user: userPrompt,
        jsonExpected: false,
      );
      
      return response.trim();
      
    } catch (e) {
      // Fallback to formatted response if LLM call fails
      print('VEIL-EDGE: LLM call failed, using fallback: $e');
      final prompt = _veilEdgeService.generatePromptWithCircadian(
        routeResult: routeResult,
        signals: signals,
        circadianContext: circadianContext,
        additionalVariables: {
          'user_message': userMessage,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      return _formatLumaraResponseWithCircadian(prompt, routeResult, circadianContext);
    }
  }
  
  /// Extract phase name from route result or Atlas state
  String _extractPhaseFromRouteResult(VeilEdgeRouteResult routeResult, AtlasState? atlas) {
    // Map phase groups to ATLAS phases
    final phaseGroup = routeResult.phaseGroup;
    if (phaseGroup.startsWith('R-')) return 'Recovery';
    if (phaseGroup.startsWith('T-')) return 'Transition';
    if (phaseGroup.startsWith('D-')) return 'Discovery';
    if (phaseGroup.startsWith('C-')) return 'Consolidation';
    
    // Fallback to Atlas phase if available
    return atlas?.phase ?? 'Recovery';
  }
  
  /// Extract energy level from circadian context
  String _extractEnergyLevel(CircadianContext circadianContext) {
    final score = circadianContext.rhythmScore;
    if (score >= 0.7) return 'high';
    if (score >= 0.4) return 'medium';
    return 'low';
  }
  
  /// Build user prompt incorporating VEIL-EDGE routing context
  String _buildUserPromptWithVeilContext({
    required String userMessage,
    required VeilEdgeRouteResult routeResult,
    required UserSignals signals,
    required CircadianContext circadianContext,
  }) {
    final buffer = StringBuffer();
    
    // Add user message
    buffer.writeln(userMessage);
    buffer.writeln();
    
    // Add VEIL-EDGE context
    buffer.writeln('Context:');
    buffer.writeln('- Phase group: ${routeResult.phaseGroup}');
    buffer.writeln('- Variant: ${routeResult.variant}');
    buffer.writeln('- Blocks: ${routeResult.blocks.join(", ")}');
    buffer.writeln('- Circadian window: ${circadianContext.window}');
    buffer.writeln('- Rhythm score: ${circadianContext.rhythmScore.toStringAsFixed(2)}');
    
    if (signals.feelings.isNotEmpty) {
      buffer.writeln('- Detected feelings: ${signals.feelings.join(", ")}');
    }
    
    return buffer.toString();
  }

  /// Format the VEIL-EDGE prompt as a LUMARA response with circadian awareness
  String _formatLumaraResponseWithCircadian(
    String prompt, 
    VeilEdgeRouteResult routeResult,
    CircadianContext circadianContext,
  ) {
    final buffer = StringBuffer();
    
    // Add LUMARA greeting with circadian awareness
    buffer.writeln(_getCircadianGreeting(circadianContext));
    buffer.writeln();
    
    // Add the VEIL-EDGE generated content
    buffer.writeln(prompt);
    buffer.writeln();
    
    // Add phase-specific closing with circadian awareness
    buffer.writeln(_getCircadianClosing(routeResult.phaseGroup, circadianContext));
    
    return buffer.toString().trim();
  }

  /// Get circadian-aware greeting
  String _getCircadianGreeting(CircadianContext circadianContext) {
    switch (circadianContext.window) {
      case 'morning':
        return "Good morning! I'm LUMARA, and I'm here to help you start your day with intention and clarity.";
      case 'afternoon':
        return "Good afternoon! I'm LUMARA, and I'm here to help you synthesize and make clear decisions.";
      case 'evening':
        return "Good evening! I'm LUMARA, and I'm here to help you wind down gently and reflect on your day.";
      default:
        return "Hello! I'm LUMARA, and I'm here to support you through this moment.";
    }
  }

  /// Get circadian-aware closing
  String _getCircadianClosing(String phaseGroup, CircadianContext circadianContext) {
    final baseClosing = _getPhaseClosing(phaseGroup);
    final circadianNote = _getCircadianNote(circadianContext);
    
    return "$baseClosing $circadianNote";
  }

  /// Get phase-specific closing
  String _getPhaseClosing(String phaseGroup) {
    switch (phaseGroup) {
      case 'D-B':
        return "Let's explore this together and find what works for you.";
      case 'T-D':
        return "I'm here to help you navigate this transition gently.";
      case 'R-T':
        return "Take care of yourself first - everything else can wait.";
      case 'C-R':
        return "Let's build on what's working and make it sustainable.";
      default:
        return "I'm here to support you however you need.";
    }
  }

  /// Get circadian-specific note
  String _getCircadianNote(CircadianContext circadianContext) {
    if (circadianContext.isEvening && circadianContext.rhythmScore < 0.45) {
      return "Given the time and your current rhythm, let's keep things gentle and restorative.";
    } else if (circadianContext.isMorning && circadianContext.isMorningPerson) {
      return "This morning energy feels aligned with your natural rhythm - let's make the most of it.";
    } else if (circadianContext.isEvening && circadianContext.isEveningPerson) {
      return "Your evening energy is flowing well - this is a good time for reflection and planning.";
    }
    return "";
  }

  /// Process log for RIVET updates
  Future<void> _processLogForRivet(
    VeilEdgeRouteResult routeResult,
    String userMessage,
    String lumaraResponse,
  ) async {
    try {
      final log = LogSchema(
        timestamp: DateTime.now(),
        phaseGroup: routeResult.phaseGroup,
        blocksUsed: routeResult.blocks,
        action: _extractActionFromResponse(lumaraResponse),
        outcomeMetric: {
          'name': 'response_quality',
          'value': _calculateResponseQuality(lumaraResponse),
          'unit': 'score',
        },
        ease: _extractEaseFromResponse(lumaraResponse),
        mood: _extractMoodFromResponse(lumaraResponse),
        energy: _extractEnergyFromResponse(lumaraResponse),
        note: _extractNoteFromResponse(lumaraResponse),
        sentinelState: routeResult.metadata['sentinel_state'] as String? ?? 'ok',
      );
      
      _veilEdgeService.processLog(log);
    } catch (e) {
      // Log error but don't fail the main flow
      print('VEIL-EDGE: Failed to process log: $e');
    }
  }

  /// Create fallback message on error
  Future<ChatMessage> _createFallbackMessage(String sessionId, String userMessage, String error) async {
    final fallbackResponse = "I'm here to help, but I'm experiencing some technical difficulties. "
        "Please try again, and I'll do my best to support you.";
    
    final chatMessage = ChatMessage(
      id: 'msg:${DateTime.now().millisecondsSinceEpoch}',
      sessionId: sessionId,
      role: 'assistant',
      textContent: fallbackResponse,
      createdAt: DateTime.now(),
      provenance: jsonEncode({
        'veil_edge': {
          'error': error,
          'fallback': true,
        },
      }),
    );
    
    await _chatRepo.addMessage(
      sessionId: sessionId,
      role: 'assistant',
      content: fallbackResponse,
    );
    return chatMessage;
  }

  /// Helper methods for signal extraction
  bool _isActionWord(String word) {
    const actionWords = {
      'try', 'do', 'make', 'create', 'build', 'start', 'stop', 'continue',
      'explore', 'test', 'learn', 'practice', 'work', 'play', 'rest'
    };
    return actionWords.contains(word);
  }

  bool _isFeelingWord(String word) {
    const feelingWords = {
      'happy', 'sad', 'angry', 'excited', 'worried', 'calm', 'stressed',
      'confident', 'uncertain', 'frustrated', 'hopeful', 'tired', 'energetic'
    };
    return feelingWords.contains(word);
  }

  String _extractActionFromResponse(String response) {
    // Simple extraction - in practice this would use NLP
    if (response.toLowerCase().contains('choose')) return 'choose';
    if (response.toLowerCase().contains('try')) return 'try';
    if (response.toLowerCase().contains('explore')) return 'explore';
    return 'reflect';
  }

  double _calculateResponseQuality(String response) {
    // Simple quality metric based on length and structure
    final length = response.length;
    final hasQuestions = response.contains('?');
    final hasActionWords = response.toLowerCase().split(' ').any(_isActionWord);
    
    double score = 5.0; // Base score
    if (length < 50) score -= 1.0;
    if (length > 200) score += 1.0;
    if (hasQuestions) score += 0.5;
    if (hasActionWords) score += 0.5;
    
    return score.clamp(1.0, 10.0);
  }

  int _extractEaseFromResponse(String response) {
    // Simple extraction based on keywords
    if (response.toLowerCase().contains('easy') || response.toLowerCase().contains('simple')) return 4;
    if (response.toLowerCase().contains('challenging') || response.toLowerCase().contains('difficult')) return 2;
    return 3; // Default
  }

  int _extractMoodFromResponse(String response) {
    // Simple extraction based on tone
    if (response.toLowerCase().contains('excited') || response.toLowerCase().contains('great')) return 4;
    if (response.toLowerCase().contains('worried') || response.toLowerCase().contains('concerned')) return 2;
    return 3; // Default
  }

  int _extractEnergyFromResponse(String response) {
    // Simple extraction based on energy words
    if (response.toLowerCase().contains('energetic') || response.toLowerCase().contains('ready')) return 4;
    if (response.toLowerCase().contains('tired') || response.toLowerCase().contains('rest')) return 2;
    return 3; // Default
  }

  String _extractNoteFromResponse(String response) {
    // Extract the last sentence as a note
    final sentences = response.split('.');
    if (sentences.length > 1) {
      return sentences[sentences.length - 2].trim();
    }
    return response.substring(0, response.length > 100 ? 100 : response.length);
  }

  /// Get integration status including circadian context
  Future<Map<String, dynamic>> getStatus() async {
    final veilEdgeStatus = await _veilEdgeService.getStatus();
    return {
      'integration': 'lumara_veil_edge',
      'veil_edge_status': veilEdgeStatus,
      'chat_repo_available': true,
      'aurora_integration': true,
    };
  }
}

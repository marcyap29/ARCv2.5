/// LUMARA VEIL-EDGE Integration
/// 
/// Integrates VEIL-EDGE with the existing LUMARA chat system to provide
/// phase-reactive restorative responses.

import 'dart:async';
import '../../chat/chat_models.dart';
import '../../chat/chat_repo.dart';
import '../../chat/content_parts.dart';
import '../models/veil_edge_models.dart';
import '../services/veil_edge_service.dart';

/// Integration service for LUMARA and VEIL-EDGE
class LumaraVeilEdgeIntegration {
  final VeilEdgeService _veilEdgeService;
  final ChatRepo _chatRepo;

  LumaraVeilEdgeIntegration({
    required ChatRepo chatRepo,
    VeilEdgeService? veilEdgeService,
  }) : _chatRepo = chatRepo,
       _veilEdgeService = veilEdgeService ?? VeilEdgeService();

  /// Process a chat message through VEIL-EDGE
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
      
      // Route through VEIL-EDGE
      final routeResult = _veilEdgeService.route(
        signals: signals,
        atlas: atlas,
        sentinel: sentinel,
        rivet: rivet,
      );
      
      // Generate LUMARA response using VEIL-EDGE prompts
      final lumaraResponse = await _generateLumaraResponse(
        routeResult: routeResult,
        signals: signals,
        userMessage: userMessage,
      );
      
      // Create chat message
      final chatMessage = ChatMessage(
        id: 'msg:${DateTime.now().millisecondsSinceEpoch}',
        sessionId: sessionId,
        role: 'assistant',
        contentParts: [
          TextContentPart(text: lumaraResponse),
        ],
        createdAt: DateTime.now(),
        provenance: {
          'veil_edge': {
            'phase_group': routeResult.phaseGroup,
            'variant': routeResult.variant,
            'blocks_used': routeResult.blocks,
            'metadata': routeResult.metadata,
          },
        },
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

  /// Generate LUMARA response using VEIL-EDGE prompts
  Future<String> _generateLumaraResponse({
    required VeilEdgeRouteResult routeResult,
    required UserSignals signals,
    required String userMessage,
  }) async {
    // Generate prompt using VEIL-EDGE
    final prompt = _veilEdgeService.generatePrompt(
      routeResult: routeResult,
      signals: signals,
      additionalVariables: {
        'user_message': userMessage,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    // In a real implementation, this would call the LLM
    // For now, return a formatted response
    return _formatLumaraResponse(prompt, routeResult);
  }

  /// Format the VEIL-EDGE prompt as a LUMARA response
  String _formatLumaraResponse(String prompt, VeilEdgeRouteResult routeResult) {
    final buffer = StringBuffer();
    
    // Add LUMARA greeting
    buffer.writeln("I'm LUMARA, and I'm here to support you through this moment.");
    buffer.writeln();
    
    // Add the VEIL-EDGE generated content
    buffer.writeln(prompt);
    buffer.writeln();
    
    // Add phase-specific closing
    switch (routeResult.phaseGroup) {
      case 'D-B':
        buffer.writeln("Let's explore this together and find what works for you.");
        break;
      case 'T-D':
        buffer.writeln("I'm here to help you navigate this transition gently.");
        break;
      case 'R-T':
        buffer.writeln("Take care of yourself first - everything else can wait.");
        break;
      case 'C-R':
        buffer.writeln("Let's build on what's working and make it sustainable.");
        break;
      default:
        buffer.writeln("I'm here to support you however you need.");
    }
    
    return buffer.toString().trim();
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
      
      await _veilEdgeService.processLog(log);
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
      contentParts: [
        TextContentPart(text: fallbackResponse),
      ],
      createdAt: DateTime.now(),
      provenance: {
        'veil_edge': {
          'error': error,
          'fallback': true,
        },
      },
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

  /// Get integration status
  Map<String, dynamic> getStatus() {
    return {
      'integration': 'lumara_veil_edge',
      'veil_edge_status': _veilEdgeService.getStatus(),
      'chat_repo_available': true,
    };
  }
}

import 'dart:async';
import '../../telemetry/analytics.dart';
import 'pii_scrub.dart';
import '../../lumara/services/enhanced_lumara_api.dart';

/// LUMARA inline API for generating contextual reflections within journal entries
/// This is now a compatibility layer that redirects to EnhancedLumaraApi
class LumaraInlineApi {
  final Analytics analytics;
  final EnhancedLumaraApi _enhancedApi;
  
  LumaraInlineApi(this.analytics) : _enhancedApi = EnhancedLumaraApi(analytics);

  /// Generate a prompted reflection based on user intent and current phase
  /// intent: ideas | think | perspective | next | analyze
  Future<String> generatePromptedReflection({
    required String entryText,
    required String intent,
    String? phase,
    String? userId,
  }) async {
    final scrubbed = PiiScrubber.rivetScrub(entryText);
    analytics.logLumaraEvent('inline_reflection_requested', data: {
      'intent': intent, 
      'phase': phase,
      'text_length': scrubbed.length,
    });

    // Redirect to enhanced API for real reflection generation
    return await _enhancedApi.generatePromptedReflection(
      entryText: scrubbed,
      intent: intent,
      phase: phase,
      userId: userId ?? 'default',
    );
  }

  /// Generate a softer tone variant (for Recovery phase or on request)
  Future<String> generateSofterReflection({
    required String entryText,
    required String intent,
    String? phase,
    String? userId,
  }) async {
    PiiScrubber.rivetScrub(entryText); // Scrub for privacy
    analytics.logLumaraEvent('softer_reflection_requested', data: {
      'intent': intent, 
      'phase': phase,
    });

    // For softer reflections, we could add a special intent or modify the phase
    // For now, use the standard reflection with a gentle phase hint
    final gentlePhase = phase == 'Recovery' ? phase : 'Recovery';
    return await _enhancedApi.generatePromptedReflection(
      entryText: entryText,
      intent: intent,
      phase: gentlePhase,
      userId: userId ?? 'default',
    );
  }

  /// Generate a more in-depth analysis
  Future<String> generateDeeperReflection({
    required String entryText,
    required String intent,
    String? phase,
    String? userId,
  }) async {
    PiiScrubber.rivetScrub(entryText); // Scrub for privacy
    analytics.logLumaraEvent('deeper_reflection_requested', data: {
      'intent': intent, 
      'phase': phase,
    });

    // For deeper analysis, use the 'analyze' intent which should generate more analytical prompts
    return await _enhancedApi.generatePromptedReflection(
      entryText: entryText,
      intent: 'analyze', // Force analytical intent
      phase: phase,
      userId: userId ?? 'default',
    );
  }
}
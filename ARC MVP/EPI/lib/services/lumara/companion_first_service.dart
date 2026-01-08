/// Companion-First LUMARA Service
/// Main integration point for the new Companion-first response system
///
/// This service integrates:
/// 1. Entry Classification
/// 2. User Intent Detection
/// 3. Companion-First Persona Selection
/// 4. Response Mode Configuration
/// 5. Master Prompt Building
/// 6. Validation and Logging
///
/// NO MANUAL PERSONA OVERRIDE - Personas are backend-only

import 'dart:convert';
import 'entry_classifier.dart';
import 'user_intent.dart';
import 'persona_selector.dart';
import 'response_mode_v2.dart';
import 'master_prompt_builder.dart';
import 'validation_service.dart';

class CompanionFirstService {

  /// Main entry point - NO MANUAL PERSONA OVERRIDE
  static Future<CompanionFirstResponse> generateResponse({
    required String userId,
    required String entryText,
    String? buttonPressed,
    bool enableLogging = true,
  }) async {
    try {
      // STEP 1: Classify entry type
      final entryType = EntryClassifier.classify(entryText);

      // STEP 2: Detect user intent from button
      final userIntent = UserIntentDetector.detectIntent(buttonPressed);

      // STEP 3: Get user state (integrate with existing systems)
      final currentPhase = await _getCurrentPhase(userId);
      final readinessScore = await _getReadinessScore(userId);
      final sentinelAlert = await _checkSentinel(userId);
      final emotionalIntensity = PersonaSelector.calculateEmotionalIntensity(entryText);

      // STEP 4: Select persona (COMPANION-FIRST LOGIC)
      final persona = PersonaSelector.selectPersona(
        entryType: entryType,
        userIntent: userIntent,
        phase: currentPhase,
        readinessScore: readinessScore,
        sentinelAlert: sentinelAlert,
        emotionalIntensity: emotionalIntensity,
      );

      // STEP 5: Configure response mode with entry text for personal vs. project detection
      final responseMode = ResponseMode.configure(
        persona: persona,
        entryType: entryType,
        userIntent: userIntent,
        entryText: entryText,
      );

      // STEP 6: Build master prompt with strict controls
      final masterPrompt = await MasterPromptBuilder.buildMasterPrompt(
        userId: userId,
        originalEntry: entryText,
        entryType: entryType,
        userIntent: userIntent,
        responseMode: responseMode,
        currentPhase: currentPhase,
        readinessScore: readinessScore,
        sentinelAlert: sentinelAlert,
      );

      // STEP 7: Generate response from LLM
      final response = await _callLLM(masterPrompt);

      // STEP 8: Validate response with strict checks
      final validation = ValidationService.validateResponse(response, responseMode, userId: userId);

      // STEP 9: Log results if enabled
      if (enableLogging) {
        await _logInteraction(
          userId: userId,
          entryType: entryType,
          userIntent: userIntent,
          persona: persona,
          responseMode: responseMode,
          response: response,
          validation: validation,
          originalEntry: entryText,
          emotionalIntensity: emotionalIntensity,
        );
      }

      return CompanionFirstResponse(
        response: response,
        persona: persona,
        entryType: entryType,
        userIntent: userIntent,
        responseMode: responseMode,
        validation: validation,
        debugInfo: _buildDebugInfo(
          entryType: entryType,
          userIntent: userIntent,
          persona: persona,
          currentPhase: currentPhase,
          readinessScore: readinessScore,
          sentinelAlert: sentinelAlert,
          emotionalIntensity: emotionalIntensity,
        ),
      );

    } catch (e, stackTrace) {
      print('❌ Error generating Companion-first response: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Log complete interaction for monitoring and improvement
  static Future<void> _logInteraction({
    required String userId,
    required EntryType entryType,
    required UserIntent userIntent,
    required String persona,
    required ResponseMode responseMode,
    required String response,
    required ValidationResult validation,
    required String originalEntry,
    required double emotionalIntensity,
  }) async {
    // Log persona distribution
    await ValidationLogger.logPersonaDistribution(
      userId: userId,
      entryType: entryType,
      userIntent: userIntent,
      selectedPersona: persona,
      selectionReason: _getPersonaSelectionReason(
        entryType,
        userIntent,
        persona,
        emotionalIntensity,
      ),
      wasCompanionFirst: persona == "companion",
    );

    // Log validation results if there were violations
    if (!validation.isValid) {
      await ValidationLogger.logValidation(
        userId: userId,
        validation: validation,
        entryType: entryType,
        persona: persona,
        originalEntry: originalEntry,
        responseText: response,
      );
    }
  }

  /// Get reason for persona selection (for logging)
  static String _getPersonaSelectionReason(
    EntryType entryType,
    UserIntent userIntent,
    String selectedPersona,
    double emotionalIntensity,
  ) {
    if (selectedPersona == "therapist" && emotionalIntensity > 0.5) {
      return "High emotional intensity";
    }
    if (userIntent == UserIntent.thinkThrough) {
      return "User pressed 'Think through'";
    }
    if (userIntent == UserIntent.suggestSteps) {
      return "User pressed 'Suggest steps'";
    }
    if (userIntent == UserIntent.differentPerspective) {
      return "User pressed 'Different perspective'";
    }
    if (entryType == EntryType.metaAnalysis) {
      return "Meta-analysis entry type";
    }
    if (selectedPersona == "companion") {
      return "Companion-first default";
    }
    return "Entry type: ${entryType.toString().split('.').last}";
  }

  /// Build debug information
  static Map<String, dynamic> _buildDebugInfo({
    required EntryType entryType,
    required UserIntent userIntent,
    required String persona,
    required String currentPhase,
    required int readinessScore,
    required bool sentinelAlert,
    required double emotionalIntensity,
  }) {
    return {
      'classification': {
        'entryType': entryType.toString().split('.').last,
        'description': EntryClassifier.getTypeDescription(entryType),
      },
      'userIntent': {
        'intent': userIntent.toString().split('.').last,
        'description': UserIntentDetector.getIntentDescription(userIntent),
      },
      'personaSelection': {
        'selectedPersona': persona,
        'description': PersonaSelector.getPersonaDescription(persona),
        'selectionReason': _getPersonaSelectionReason(entryType, userIntent, persona, emotionalIntensity),
        'isCompanionFirst': persona == "companion",
      },
      'userState': {
        'phase': currentPhase,
        'readinessScore': readinessScore,
        'sentinelAlert': sentinelAlert,
        'emotionalIntensity': emotionalIntensity,
      },
      'targetDistribution': PersonaSelector.getTargetDistribution(),
    };
  }

  // ========== INTEGRATION POINTS (Replace with your existing implementations) ==========

  /// Get current ATLAS phase
  static Future<String> _getCurrentPhase(String userId) async {
    // TODO: Integrate with your existing ATLAS phase detection
    return "Discovery"; // Placeholder
  }

  /// Get RIVET readiness score
  static Future<int> _getReadinessScore(String userId) async {
    // TODO: Integrate with your existing RIVET readiness calculation
    return 70; // Placeholder
  }

  /// Check SENTINEL safety alert
  static Future<bool> _checkSentinel(String userId) async {
    // TODO: Integrate with your existing SENTINEL safety check
    return false; // Placeholder
  }

  /// Call your LLM provider (cloud or on-device)
  static Future<String> _callLLM(String prompt) async {
    // TODO: Replace with your existing LLM API call
    // This should call your cloud provider (Gemini, Claude, etc.) or on-device model
    print('🤖 Would call LLM with prompt length: ${prompt.length}');
    return "This would be the LLM response based on the companion-first prompt.";
  }
}

/// Response container for Companion-first system
class CompanionFirstResponse {
  final String response;
  final String persona;
  final EntryType entryType;
  final UserIntent userIntent;
  final ResponseMode responseMode;
  final ValidationResult validation;
  final Map<String, dynamic> debugInfo;

  CompanionFirstResponse({
    required this.response,
    required this.persona,
    required this.entryType,
    required this.userIntent,
    required this.responseMode,
    required this.validation,
    required this.debugInfo,
  });

  /// Check if response is valid
  bool get isValid => validation.isValid;

  /// Get validation violations
  List<String> get violations => validation.violations;

  /// Check if Companion was selected
  bool get isCompanionFirst => persona == "companion";

  /// Get response summary for logging
  Map<String, dynamic> toSummary() {
    return {
      'persona': persona,
      'entryType': entryType.toString().split('.').last,
      'userIntent': userIntent.toString().split('.').last,
      'wordCount': validation.metrics['wordCount'],
      'isValid': validation.isValid,
      'violationCount': validation.violations.length,
      'isCompanionFirst': isCompanionFirst,
      'isPersonalContent': responseMode.isPersonalContent,
    };
  }

  /// Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'response': response,
      'persona': persona,
      'entryType': entryType.toString().split('.').last,
      'userIntent': userIntent.toString().split('.').last,
      'responseMode': responseMode.toJson(),
      'validation': validation.toJson(),
      'debugInfo': debugInfo,
    };
  }
}
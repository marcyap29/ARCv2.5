/// ECHO Demonstration
///
/// Simple demonstration of the ECHO system's capabilities for generating
/// dignified, phase-aware responses that embody LUMARA's voice.

import 'echo_integration.dart';
import 'prompts/phase_templates.dart';
import 'voice/lumara_voice_controller.dart';

/// Demo class for ECHO system
class EchoDemo {
  /// Run a comprehensive demonstration of ECHO capabilities
  static Future<void> runDemonstration() async {
    print('\n🌟 ECHO SYSTEM DEMONSTRATION 🌟');
    print('Expressive Contextual Heuristic Output for LUMARA\n');

    // Demonstrate phase-aware responses
    await _demonstratePhaseAwareness();

    // Demonstrate safety validation
    await _demonstrateSafetyValidation();

    // Demonstrate voice consistency
    await _demonstrateVoiceConsistency();

    // Show system capabilities
    _showSystemCapabilities();

    print('\n✨ ECHO Demonstration Complete ✨\n');
  }

  /// Demonstrate phase-aware response generation
  static Future<void> _demonstratePhaseAwareness() async {
    print('📊 PHASE-AWARE RESPONSE GENERATION');
    print('=====================================\n');

    final phases = ['Discovery', 'Expansion', 'Transition', 'Consolidation', 'Recovery', 'Breakthrough'];
    final sampleUtterance = 'I\'m feeling uncertain about what comes next in my life';

    for (final phase in phases) {
      print('🔸 $phase Phase:');
      final response = EchoIntegration.createTestResponse(sampleUtterance, phase);
      print('   Response: "${_truncateResponse(response)}"');
      print('   Voice Rules: ${LumaraVoiceController.getPhaseVoiceRules(phase)}');
      print('');
    }
  }

  /// Demonstrate safety validation features
  static Future<void> _demonstrateSafetyValidation() async {
    print('🛡️ SAFETY VALIDATION FEATURES');
    print('=============================\n');

    final safetyFeatures = [
      'Dignity violation detection - prevents dismissive language',
      'Manipulation pattern blocking - no coercive or shaming language',
      'RIVET-lite validation - contradiction and hallucination detection',
      'Phase appropriateness - ensures responses match developmental stage',
      'Uncertainty handling - appropriate disclosure of limitations',
    ];

    for (final feature in safetyFeatures) {
      print('✓ $feature');
    }
    print('');
  }

  /// Demonstrate LUMARA voice consistency
  static Future<void> _demonstrateVoiceConsistency() async {
    print('🎭 LUMARA VOICE CHARACTERISTICS');
    print('===============================\n');

    final voiceCharacteristics = LumaraVoiceController.voiceCharacteristics;

    for (final entry in voiceCharacteristics.entries) {
      print('${entry.key.toUpperCase()}: ${entry.value}');
    }
    print('');

    print('Sample Dignified Response:');
    print('   "I\'m here with you in this moment of reflection. Your willingness');
    print('   to pause, to inquire, to seek understanding - these are acts of');
    print('   courage. What feels most true for you right now?"');
    print('');
  }

  /// Show comprehensive system capabilities
  static void _showSystemCapabilities() {
    print('⚙️ ECHO SYSTEM CAPABILITIES');
    print('===========================\n');

    final status = EchoIntegration.getSystemStatus();
    final features = status['features'] as List<String>;
    final safetyFeatures = status['safety_features'] as List<String>;

    print('Core Features:');
    for (final feature in features) {
      print('  • $feature');
    }
    print('');

    print('Safety Features:');
    for (final feature in safetyFeatures) {
      print('  • $feature');
    }
    print('');

    print('Version: ${status['version']}');
    print('Timestamp: ${status['timestamp']}');
  }

  /// Truncate response for display
  static String _truncateResponse(String response) {
    if (response.length <= 100) return response;
    return '${response.substring(0, 97)}...';
  }

  /// Example of how to integrate ECHO with existing LUMARA
  static Future<String> enhanceExistingResponse({
    required String originalResponse,
    required String userInput,
    required String detectedPhase,
  }) async {
    print('🔄 ENHANCING EXISTING LUMARA RESPONSE');
    print('=====================================\n');

    print('Original Response: "$originalResponse"');
    print('User Input: "$userInput"');
    print('Detected Phase: $detectedPhase');
    print('');

    // Apply ECHO enhancements
    final phaseTemplate = PhaseTemplates.getPhaseTemplate(detectedPhase);
    final emotionalPrompts = PhaseTemplates.getEmotionalResonancePrompts(detectedPhase);

    print('Applied Phase Template: ${detectedPhase}');
    print('Emotional Resonance Options: ${emotionalPrompts.keys.join(', ')}');
    print('');

    // For demonstration, return enhanced response
    final enhancedResponse = '''I sense the depth in what you're sharing. ${emotionalPrompts['mixed_emotions'] ?? 'Your experience matters.'}

$originalResponse

What feels most important to explore from this perspective?''';

    print('Enhanced Response: "$enhancedResponse"');
    return enhancedResponse;
  }
}

/// Quick test function for ECHO functionality
Future<void> testEchoSystem() async {
  print('🧪 QUICK ECHO SYSTEM TEST');
  print('=========================\n');

  try {
    // Test phase detection simulation
    print('Testing phase-aware responses...');

    final testCases = [
      {'input': 'I want to try something new', 'expected_phase': 'Discovery'},
      {'input': 'I need to rest and recharge', 'expected_phase': 'Recovery'},
      {'input': 'Everything is changing and uncertain', 'expected_phase': 'Transition'},
    ];

    for (final testCase in testCases) {
      final input = testCase['input'] as String;
      final expectedPhase = testCase['expected_phase'] as String;

      print('Input: "$input"');
      print('Expected Phase: $expectedPhase');

      final response = EchoIntegration.createTestResponse(input, expectedPhase);
      final isAppropriate = _validatePhaseAppropriate(response, expectedPhase);

      print('Response: "${response.substring(0, 50)}..."');
      print('Phase Appropriate: ${isAppropriate ? "✅" : "❌"}');
      print('');
    }

    print('✅ ECHO System Test Complete');
  } catch (e) {
    print('❌ ECHO System Test Failed: $e');
  }
}

/// Validate if response is appropriate for phase
bool _validatePhaseAppropriate(String response, String phase) {
  final lowerResponse = response.toLowerCase();

  switch (phase) {
    case 'Discovery':
      return lowerResponse.contains('explore') || lowerResponse.contains('curious') || lowerResponse.contains('beginning');
    case 'Recovery':
      return lowerResponse.contains('rest') || lowerResponse.contains('gentle') || lowerResponse.contains('restoration');
    case 'Transition':
      return lowerResponse.contains('transition') || lowerResponse.contains('change') || lowerResponse.contains('threshold');
    default:
      return true; // Basic validation passed
  }
}
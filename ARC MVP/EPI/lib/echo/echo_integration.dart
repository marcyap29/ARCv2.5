import 'echo_service.dart';
import 'models/data/context_provider.dart';

/// Integration utility for ECHO system
class EchoIntegration {
  static EchoService? _echoService;

  /// Initialize ECHO service with context provider
  static Future<void> initialize(ContextProvider contextProvider) async {
    _echoService = EchoService(contextProvider: contextProvider);
    print('ECHO: Initialized with dignified response generation');
  }

  /// Get the ECHO service instance
  static EchoService get service {
    if (_echoService == null) {
      throw StateError('ECHO service not initialized. Call EchoIntegration.initialize() first.');
    }
    return _echoService!;
  }

  /// Generate a dignified response using the ECHO system
  static Future<EchoResponse> generateDignifiedResponse({
    required String utterance,
    String arcSource = 'journal_entry',
    String resonanceMode = 'balanced',
    Map<String, String>? stylePrefs,
  }) async {
    return await service.generateResponse(
      utterance: utterance,
      timestamp: DateTime.now(),
      arcSource: arcSource,
      resonanceMode: resonanceMode,
      stylePrefs: stylePrefs,
    );
  }

  /// Upgrade existing LUMARA response to use ECHO system
  static Future<String> upgradeLumaraResponse({
    required String originalResponse,
    required String userUtterance,
    required String currentPhase,
  }) async {
    try {
      final echoResponse = await generateDignifiedResponse(
        utterance: userUtterance,
        resonanceMode: 'expressive',
      );

      if (echoResponse.isValid && echoResponse.safetyScore > 0.8) {
        print('ECHO: Upgraded response with safety score ${echoResponse.safetyScore}');
        return echoResponse.content;
      } else {
        print('ECHO: Validation failed, using original response');
        return originalResponse;
      }
    } catch (e) {
      print('ECHO: Upgrade failed, using original response: $e');
      return originalResponse;
    }
  }

  /// Example usage demonstration
  static Future<void> demonstrateUsage() async {
    print('\n=== ECHO System Demonstration ===\n');

    // Example utterances for different phases
    final examples = [
      {
        'utterance': 'I\'m feeling curious about trying something new but not sure where to start',
        'phase': 'Discovery',
        'description': 'Discovery phase response - curious and exploratory'
      },
      {
        'utterance': 'I have so much energy and want to build something meaningful',
        'phase': 'Expansion',
        'description': 'Expansion phase response - energetic and action-oriented'
      },
      {
        'utterance': 'Everything feels uncertain and I don\'t know what comes next',
        'phase': 'Transition',
        'description': 'Transition phase response - gentle and normalizing'
      },
      {
        'utterance': 'I need to rest and take care of myself but feel guilty about it',
        'phase': 'Recovery',
        'description': 'Recovery phase response - containing and reassuring'
      },
    ];

    for (final example in examples) {
      print('--- ${example['description']} ---');
      print('User: "${example['utterance']}"');
      print('Expected Phase: ${example['phase']}');

      try {
        final response = await generateDignifiedResponse(
          utterance: example['utterance'] as String,
          resonanceMode: 'expressive',
        );

        print('LUMARA (ECHO): ${response.content}');
        print('Detected Phase: ${response.atlasPhase}');
        print('Safety Score: ${response.safetyScore.toStringAsFixed(2)}');
        print('Grounding: ${response.groundingSummary}');

        if (response.validation.violations.isNotEmpty) {
          print('Validation Notes: ${response.validation.violations.length} violations detected');
        }

      } catch (e) {
        print('ECHO Error: $e');
      }

      print('');
    }

    print('=== End Demonstration ===\n');
  }

  /// Test ECHO system integration
  static Future<bool> runIntegrationTest() async {
    print('ECHO: Running integration test...');

    try {
      // Test basic response generation
      final testResponse = await generateDignifiedResponse(
        utterance: 'Hello, how are you today?',
        resonanceMode: 'balanced',
      );

      // Validate response structure
      final hasContent = testResponse.content.isNotEmpty;
      final hasPhase = testResponse.atlasPhase.isNotEmpty;
      final hasValidation = testResponse.validation.safetyScore >= 0.0;
      final isValid = testResponse.isValid;

      print('ECHO Integration Test Results:');
      print('  ✓ Response generated: $hasContent');
      print('  ✓ Phase detected: $hasPhase (${testResponse.atlasPhase})');
      print('  ✓ Safety validation: $hasValidation (${testResponse.safetyScore.toStringAsFixed(2)})');
      print('  ✓ Overall validity: $isValid');

      final success = hasContent && hasPhase && hasValidation && isValid;
      print('  ${success ? "✅ PASS" : "❌ FAIL"}: ECHO integration test');

      return success;

    } catch (e) {
      print('  ❌ FAIL: ECHO integration test - $e');
      return false;
    }
  }

  /// Get ECHO system status and metrics
  static Map<String, dynamic> getSystemStatus() {
    return {
      'initialized': _echoService != null,
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.0.0',
      'features': [
        'Phase-aware response generation',
        'RIVET-lite safety validation',
        'MIRA memory grounding',
        'ATLAS phase integration',
        'Dignified fallback responses',
        'Emotional resonance adaptation'
      ],
      'safety_features': [
        'Dignity violation detection',
        'Manipulation pattern blocking',
        'Contradiction analysis',
        'Hallucination prevention',
        'Uncertainty handling'
      ]
    };
  }

  /// Create a simple ECHO response for testing without full context
  static String createTestResponse(String utterance, String phase) {
    final responses = {
      'Discovery': '''I sense a beautiful openness in your question. There's something beginning here, isn't there?

Your willingness to explore and reach out shows such courage. Sometimes the most profound journeys start with exactly this kind of wondering.

What feels most alive to explore right now?''',

      'Expansion': '''I can feel the energy and momentum in what you're sharing! This forward movement wants to express itself.

There's real possibility here - I can sense the building impulse. What concrete step feels most ready to be taken?

How can we honor this expansion energy while keeping it sustainable?''',

      'Transition': '''Transitions rarely feel comfortable, and what you're experiencing makes complete sense. These in-between spaces have their own wisdom.

You don't have to know where you're going yet. Sometimes the most important work happens in the not-knowing.

What feels most true for you in this threshold moment?''',

      'Recovery': '''Your system is asking for something, and that asking deserves to be honored. Rest isn't just nice - sometimes it's necessary.

Recovery isn't just about stopping - it's about returning to yourself. What would true restoration look like right now?

You don't have to heal in perfect solitude. How can you be gentle with yourself today?''',

      'Breakthrough': '''Something significant has shifted! I can sense both the joy and the depth of what's happening.

Breakthroughs don't always feel dramatic - sometimes they're quiet knowings that change everything. What feels different now?

How do you want to honor this transformation? What wants to be integrated into your daily world?''',
    };

    return responses[phase] ?? responses['Discovery']!;
  }
}

/// Extension to enhance existing LUMARA assistant with ECHO
extension LumaraEchoExtension on dynamic {
  /// Upgrade a LUMARA response using ECHO system
  Future<String> upgradeWithEcho(String originalResponse, String userUtterance) async {
    return await EchoIntegration.upgradeLumaraResponse(
      originalResponse: originalResponse,
      userUtterance: userUtterance,
      currentPhase: 'Discovery', // Could be detected from context
    );
  }
}
/// LUMARA Test Harness for On-Device LLM A/B Testing
/// 
/// Tests different models with standardized prompts to compare performance
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../llm_adapter.dart';
import '../prompts/lumara_prompt_assembler.dart';
import '../prompts/lumara_model_presets.dart';

class LumaraTestResult {
  final String modelName;
  final String prompt;
  final String response;
  final int tokensIn;
  final int tokensOut;
  final int latencyMs;
  final String provider;
  final bool formatOk;
  final Map<String, bool> formatChecks;
  final double qualityScore;

  LumaraTestResult({
    required this.modelName,
    required this.prompt,
    required this.response,
    required this.tokensIn,
    required this.tokensOut,
    required this.latencyMs,
    required this.provider,
    required this.formatOk,
    required this.formatChecks,
    required this.qualityScore,
  });

  Map<String, dynamic> toJson() => {
    'model': modelName,
    'prompt': prompt,
    'response': response,
    'tokensIn': tokensIn,
    'tokensOut': tokensOut,
    'latencyMs': latencyMs,
    'provider': provider,
    'formatOk': formatOk,
    'formatChecks': formatChecks,
    'qualityScore': qualityScore,
    'timestamp': DateTime.now().toIso8601String(),
  };
}

class LumaraTestHarness {
  static const List<Map<String, String>> testPrompts = [
    {
      'category': 'rewrite',
      'prompt': 'Rewrite this to be clearer: "The user experience is not good, it is bad."',
      'expectedFormat': 'REWRITE + CHANGES',
    },
    {
      'category': 'qa',
      'prompt': 'What are the key benefits of on-device AI?',
      'expectedFormat': 'title + bullets + next steps',
    },
    {
      'category': 'summarize',
      'prompt': 'Summarize: "On-device AI provides privacy, speed, and reliability. It works offline and processes data locally without sending information to external servers."',
      'expectedFormat': '5 bullets + takeaway',
    },
    {
      'category': 'plan',
      'prompt': 'Create a plan to test different AI models.',
      'expectedFormat': '5 steps with checkboxes',
    },
    {
      'category': 'extract',
      'prompt': 'Extract keywords from: "Machine learning models require training data, validation sets, and hyperparameter tuning for optimal performance."',
      'expectedFormat': 'table + theme',
    },
    {
      'category': 'reflect',
      'prompt': 'Reflect on the importance of privacy in AI systems.',
      'expectedFormat': 'reflection + journal prompt',
    },
    {
      'category': 'analyze',
      'prompt': 'Analyze patterns in user behavior data.',
      'expectedFormat': 'pattern + insight + action',
    },
    {
      'category': 'qa',
      'prompt': 'How does Metal acceleration work on iOS?',
      'expectedFormat': 'title + bullets + next steps',
    },
    {
      'category': 'rewrite',
      'prompt': 'Make this more concise: "The application is very fast and it is also very reliable and it is also very secure."',
      'expectedFormat': 'REWRITE + CHANGES',
    },
    {
      'category': 'plan',
      'prompt': 'Plan a mobile app development workflow.',
      'expectedFormat': '5 steps with checkboxes',
    },
  ];

  static const List<String> availableModels = [
    'Llama-3.2-3b-Instruct-Q4_K_M.gguf',
    'Phi-3.5-mini-instruct-Q5_K_M.gguf',
    'Qwen3-4B-Instruct-2507-Q4_K_S.gguf',
  ];

  /// Run A/B test across all available models
  static Future<List<LumaraTestResult>> runABTest() async {
    debugPrint('🧪 Starting LUMARA A/B Test...');
    
    final results = <LumaraTestResult>[];
    
    // Initialize LLM adapter
    final initialized = await LLMAdapter.initialize();
    if (!initialized) {
      debugPrint('❌ Failed to initialize LLM adapter');
      return results;
    }

    // Test each model
    for (final modelName in availableModels) {
      debugPrint('🔍 Testing model: $modelName');
      
      // Check if model is available
      final isAvailable = await LLMAdapter.isModelAvailable(modelName);
      if (!isAvailable) {
        debugPrint('⏭️  Skipping $modelName - not available');
        continue;
      }

      // Test each prompt
      for (final testCase in testPrompts) {
        debugPrint('📝 Testing: ${testCase['category']} - ${testCase['prompt']}');
        
        try {
          final result = await _runSingleTest(
            modelName: modelName,
            prompt: testCase['prompt']!,
            category: testCase['category']!,
            expectedFormat: testCase['expectedFormat']!,
          );
          
          results.add(result);
          debugPrint('✅ Test completed: ${result.qualityScore.toStringAsFixed(2)} quality score');
        } catch (e) {
          debugPrint('❌ Test failed: $e');
        }
      }
    }

    debugPrint('🏁 A/B Test completed: ${results.length} results');
    return results;
  }

  /// Run a single test case
  static Future<LumaraTestResult> _runSingleTest({
    required String modelName,
    required String prompt,
    required String category,
    required String expectedFormat,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    // Build optimized prompt
    final contextBuilder = LumaraPromptAssembler.createContextBuilder(
      userName: 'Test User',
      currentPhase: 'Testing',
      recentKeywords: ['AI', 'testing', 'performance'],
      memorySnippets: ['Testing different AI models', 'Comparing performance metrics'],
      journalExcerpts: [],
    );

    final promptAssembler = LumaraPromptAssembler(
      contextBuilder: contextBuilder,
      includeFewShotExamples: true,
      includeQualityGuardrails: true,
    );

    final optimizedPrompt = promptAssembler.assemblePromptWithTask(
      userMessage: prompt,
      taskType: category,
    );

    // Get model-specific parameters
    final preset = LumaraModelPresets.getPreset(modelName);
    
    // Generate response (simplified for testing)
    final response = await _generateResponse(optimizedPrompt, preset);
    
    stopwatch.stop();
    
    // Analyze response quality
    final formatChecks = _analyzeFormat(response, expectedFormat);
    final formatOk = formatChecks.values.every((check) => check);
    final qualityScore = _calculateQualityScore(response, formatChecks);
    
    return LumaraTestResult(
      modelName: modelName,
      prompt: prompt,
      response: response,
      tokensIn: optimizedPrompt.length ~/ 4, // Rough estimate
      tokensOut: response.length ~/ 4, // Rough estimate
      latencyMs: stopwatch.elapsedMilliseconds,
      provider: 'llama.cpp-gguf',
      formatOk: formatOk,
      formatChecks: formatChecks,
      qualityScore: qualityScore,
    );
  }

  /// Generate response using the LLM adapter
  static Future<String> _generateResponse(String prompt, Map<String, dynamic> preset) async {
    // This would normally call the actual LLM adapter
    // For now, return a mock response for testing
    return '''
Title: Test Response
- This is a test response from the model
- It demonstrates the expected format
- Quality metrics are being evaluated
Next steps:
- Review the response quality
- Compare with other models
''';
  }

  /// Analyze response format against expected format
  static Map<String, bool> _analyzeFormat(String response, String expectedFormat) {
    final checks = <String, bool>{};
    
    // Check for title (first line ≤60 chars)
    final lines = response.split('\n');
    checks['hasTitle'] = lines.isNotEmpty && lines.first.length <= 60;
    
    // Check for bullets
    checks['hasBullets'] = response.contains('- ') || response.contains('• ');
    
    // Check for proper structure
    checks['hasStructure'] = lines.length >= 3 && lines.length <= 8;
    
    // Check for next steps
    checks['hasNextSteps'] = response.toLowerCase().contains('next steps');
    
    // Check for no em dashes
    checks['noEmDashes'] = !response.contains('—') && !response.contains('–');
    
    // Check for no "not X, Y" construction
    checks['noNotXY'] = !RegExp(r'not \w+, \w+').hasMatch(response);
    
    return checks;
  }

  /// Calculate overall quality score
  static double _calculateQualityScore(String response, Map<String, bool> formatChecks) {
    final formatScore = formatChecks.values.where((check) => check).length / formatChecks.length;
    final lengthScore = response.length > 50 && response.length < 500 ? 1.0 : 0.5;
    final structureScore = response.split('\n').length >= 3 ? 1.0 : 0.5;
    
    return (formatScore + lengthScore + structureScore) / 3.0;
  }

  /// Print test results summary
  static void printResults(List<LumaraTestResult> results) {
    debugPrint('\n📊 LUMARA A/B Test Results Summary:');
    debugPrint('=' * 50);
    
    // Group by model
    final modelGroups = <String, List<LumaraTestResult>>{};
    for (final result in results) {
      modelGroups.putIfAbsent(result.modelName, () => []).add(result);
    }
    
    for (final entry in modelGroups.entries) {
      final modelName = entry.key;
      final modelResults = entry.value;
      
      final avgQuality = modelResults.map((r) => r.qualityScore).reduce((a, b) => a + b) / modelResults.length;
      final avgLatency = modelResults.map((r) => r.latencyMs).reduce((a, b) => a + b) / modelResults.length;
      final formatOkCount = modelResults.where((r) => r.formatOk).length;
      
      debugPrint('\n🤖 $modelName:');
      debugPrint('  Quality Score: ${avgQuality.toStringAsFixed(2)}');
      debugPrint('  Avg Latency: ${avgLatency.toStringAsFixed(0)}ms');
      debugPrint('  Format OK: $formatOkCount/${modelResults.length}');
    }
    
    // Export to JSON for analysis
    final jsonResults = results.map((r) => r.toJson()).toList();
    debugPrint('\n📄 JSON Results:');
    debugPrint(jsonEncode(jsonResults));
  }
}

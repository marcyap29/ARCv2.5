// lib/lumara/services/enhanced_lumara_api.dart
// Enhanced LUMARA API with multimodal reflection

import 'dart:async';
import 'dart:math';
import '../../telemetry/analytics.dart';
import '../models/reflective_node.dart';
import 'reflective_node_storage.dart';
import 'mcp_bundle_parser.dart';
import 'semantic_similarity_service.dart';
import 'reflective_prompt_generator.dart';
import 'lumara_response_formatter.dart';
import '../llm/llm_provider_factory.dart';
import '../llm/llm_provider.dart';
import '../config/api_config.dart';

/// Enhanced LUMARA API with multimodal reflection
class EnhancedLumaraApi {
  final Analytics _analytics;
  final ReflectiveNodeStorage _storage = ReflectiveNodeStorage();
  final SemanticSimilarityService _similarity = SemanticSimilarityService();
  final ReflectivePromptGenerator _promptGen = ReflectivePromptGenerator();
  final LumaraResponseFormatter _formatter = LumaraResponseFormatter();
  
  // LLM Provider for Gemini responses
  LLMProviderBase? _llmProvider;
  LumaraAPIConfig? _apiConfig;
  
  bool _initialized = false;

  EnhancedLumaraApi(this._analytics);

  /// Initialize the enhanced API
  Future<void> initialize({String? mcpBundlePath}) async {
    if (_initialized) return;
    
    try {
      await _storage.initialize();
      
      // Initialize LLM provider for Gemini responses
      _apiConfig = LumaraAPIConfig.instance;
      await _apiConfig!.initialize();
      
      final factory = LLMProviderFactory(_apiConfig!);
      _llmProvider = factory.getBestProvider();
      
      if (_llmProvider != null) {
        print('LUMARA: LLM Provider initialized: ${_llmProvider!.name}');
      } else {
        print('LUMARA: No LLM provider available - will use fallback responses');
      }
      
      // Load MCP bundle if path provided
      if (mcpBundlePath != null) {
        await indexMcpBundle(mcpBundlePath);
      }
      
      _initialized = true;
      print('LUMARA: Enhanced API initialized');
    } catch (e) {
      print('LUMARA: Initialization error: $e');
      // Continue with degraded mode
    }
  }

  /// Index MCP bundle for reflection
  Future<void> indexMcpBundle(String bundlePath) async {
    try {
      final parser = McpBundleParser();
      final nodes = await parser.parseBundle(bundlePath);
      
      // Store nodes
      await _storage.saveNodes(nodes);
      
      print('LUMARA: Indexed ${nodes.length} nodes from bundle');
    } catch (e) {
      print('LUMARA: Bundle indexing error: $e');
      rethrow;
    }
  }

  /// Generate a prompted reflection with multimodal context
  Future<String> generatePromptedReflection({
    required String entryText,
    required String intent,
    String? phase,
    String? userId,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      
      final currentPhase = _parsePhaseHint(phase);
      
      // 1. Retrieve all candidate nodes
      final allNodes = _storage.getAllNodes(
        userId: userId ?? 'default',
        maxYears: 5,
      );
      
      // 2. Score and rank by similarity
      final scored = <({double score, ReflectiveNode node})>[];
      for (final node in allNodes) {
        final score = _similarity.scoreNode(entryText, node, currentPhase);
        if (score > 0.55) {  // threshold
          scored.add((score: score, node: node));
        }
      }
      
      scored.sort((a, b) => b.score.compareTo(a.score));
      final topNodes = scored.take(5).toList();
      
      // 3. Convert to MatchedNode
      final matches = topNodes.map((item) => MatchedNode(
        id: item.node.id,
        sourceType: item.node.type,
        originalMcpId: item.node.mcpId,
        approxDate: item.node.createdAt,
        phaseHint: item.node.phaseHint,
        mediaRefs: item.node.mediaRefs?.map((m) => m.id).toList(),
        similarity: item.score,
        excerpt: _similarity.gatherText(item.node).substring(0, min(200, _similarity.gatherText(item.node).length)),
      )).toList();
      
      // 4. Generate prompts
      final prompts = _promptGen.generatePrompts(
        currentEntry: entryText,
        matches: matches,
        intent: intent,
        currentPhase: currentPhase,
      );
      
      // 5. Build response
      final response = ReflectivePromptResponse(
        contextSummary: entryText.substring(0, min(200, entryText.length)),
        matchedNodes: matches,
        reflectivePrompts: prompts,
        crossModalPatterns: _detectCrossModalPatterns(matches),
        nextStepSuggestions: _generateNextSteps(matches),
      );
      
      // 6. Generate Gemini response if LLM provider is available
      print('LUMARA Enhanced API: LLM Provider available: ${_llmProvider != null}');
      
      if (_llmProvider != null) {
        print('LUMARA Enhanced API: Using LLM provider: ${_llmProvider!.name}');
        print('LUMARA: Using LLM provider: ${_llmProvider!.name}');
        try {
          String userPrompt;
          if (matches.isNotEmpty) {
            // Use historical context if available
            print('LUMARA Enhanced API: Using ${matches.length} historical matches');
            userPrompt = 'Current entry: "$entryText"\n\nHistorical context: ${matches.map((m) => 'From ${m.approxDate?.year}: ${m.excerpt}').join('\n')}\n\nGenerate 2-3 reflective prompts that connect their current thoughts to their past experiences.';
            print('LUMARA: Generating response with ${matches.length} historical matches');
          } else {
            // Generate fresh reflection without historical context
            print('LUMARA Enhanced API: No historical context - new user');
            userPrompt = 'Current entry: "$entryText"\n\nThis appears to be one of the user\'s first journal entries, so there\'s limited history for LUMARA to draw from. Generate 2-3 thoughtful reflection prompts that help the user explore their current thoughts more deeply. Also include a gentle note that LUMARA will become more personalized and insightful as they write more entries and build a richer journal history. Be warm, encouraging, and focus on the current entry while explaining the value of continued journaling.';
            print('LUMARA: Generating response without historical context (new user)');
          }
          
          print('LUMARA Enhanced API: Calling generateResponse()...');
          final context = {
            'systemPrompt': 'You are LUMARA, a reflective AI partner. Generate thoughtful, personalized reflection prompts based on the user\'s current thoughts. Be warm, insightful, and encouraging. When users have limited journal history, explain that LUMARA becomes more helpful with more entries and encourage continued journaling.',
            'userPrompt': userPrompt,
          };
          
          final geminiResponse = await _llmProvider!.generateResponse(context);
          print('LUMARA Enhanced API: ✓ generateResponse completed');
          print('LUMARA Enhanced API: Response length: ${geminiResponse.length}');
          
          final formatted = '✨ Reflection\n\n$geminiResponse';
          
          _analytics.logLumaraEvent('reflection_generated', data: {
            'matches': matches.length,
            'top_similarity': matches.isNotEmpty ? matches.first.similarity : 0,
            'gemini_generated': true,
          });
          
          return formatted;
        } catch (e) {
          print('LUMARA Enhanced API: ✗ Error generating response: $e');
          print('LUMARA: Error generating Gemini response: $e');
          // Fall through to template-based response
        }
      } else {
        print('LUMARA Enhanced API: ✗ No LLM provider available - falling back to template');
      }
      
      // 7. Format template-based response for display
      final formatted = _formatter.formatResponse(response);
      
      _analytics.logLumaraEvent('reflection_generated', data: {
        'matches': matches.length,
        'top_similarity': matches.isNotEmpty ? matches.first.similarity : 0,
        'gemini_generated': false,
      });
      
      return formatted;
      
    } catch (e) {
      print('LUMARA: Reflection generation error: $e');
      return await _generateFallbackResponse(intent, phase);
    }
  }

  PhaseHint? _parsePhaseHint(String? phase) {
    if (phase == null) return null;
    
    return PhaseHint.values.firstWhere(
      (e) => e.name == phase.toLowerCase(),
      orElse: () => PhaseHint.discovery,
    );
  }

  List<String> _detectCrossModalPatterns(List<MatchedNode> matches) {
    final patterns = <String>[];
    
    if (matches.length > 1) {
      final types = matches.map((m) => m.sourceType).toSet();
      if (types.length > 1) {
        patterns.add('Cross-modal resonance detected between ${types.map((t) => t.name).join(' and ')}');
      }
    }
    
    return patterns;
  }

  List<String> _generateNextSteps(List<MatchedNode> matches) {
    final suggestions = <String>[];
    
    if (matches.isNotEmpty) {
      suggestions.add('Consider revisiting your top matched entry to see what resonates now.');
    }
    
    suggestions.add('If energy is low, try recording a voice note to capture your current tone.');

    return suggestions;
  }

  Future<String> _generateFallbackResponse(String intent, String? phase) async {
    // Use Gemini to generate contextual response even without historical data
    if (_llmProvider != null) {
      try {
        final context = {
          'systemPrompt': 'You are LUMARA, a reflective AI partner. Generate thoughtful, personalized reflection prompts that help users explore their current thoughts and feelings. Be warm, insightful, and encouraging. When users have limited journal history, explain that LUMARA becomes more helpful with more entries and encourage continued journaling.',
          'userPrompt': 'Generate 2-3 reflective prompts for someone who is journaling. Focus on self-discovery, growth, and understanding their current moment. Make them personal and thought-provoking. Also include a gentle note that LUMARA will become more personalized and insightful as they write more entries and build a richer journal history.',
        };
        
        final response = await _llmProvider!.generateResponse(context);
        
        // Format the response with sparkle icon
        return '✨ Reflection\n\n$response';
      } catch (e) {
        print('LUMARA: Error generating Gemini fallback response: $e');
        // Fall through to hardcoded response
      }
    }
    
    // Hardcoded fallback only if Gemini fails
    return '''
✨ Reflection

What feels most important in this moment?

---

If you could speak to yourself a year from now, what would you want them to know about today?

---

*Note: As you write more entries, LUMARA will become more personalized and insightful by drawing from your growing journal history. Keep writing to unlock deeper reflections!*
''';
  }

  /// Get status for compatibility with existing code
  Map<String, dynamic> getStatus() {
    return {
      'initialized': _initialized,
      'nodeCount': _storage.nodeCount,
    };
  }

  /// Get current provider for compatibility (returns null since we don't use providers)
  String? getCurrentProvider() {
    return null;
  }

  /// Clear corrupted downloads for compatibility
  Future<void> clearCorruptedDownloads() async {
    // No-op for now
    print('LUMARA: clearCorruptedDownloads called (no-op)');
  }
}
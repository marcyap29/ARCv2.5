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
import 'lumara_response_scoring.dart' as scoring;
import '../prompts/lumara_prompts.dart';

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
  
  // Rate limiting
  DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(seconds: 3);
  
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
    bool includeExpansionQuestions = false,
    String? mood,
    Map<String, dynamic>? chronoContext,
    String? chatContext,
    String? mediaContext,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }
      
      // Rate limiting check
      final now = DateTime.now();
      if (_lastRequestTime != null && 
          now.difference(_lastRequestTime!) < _minRequestInterval) {
        print('LUMARA: Rate limiting - too many requests, using fallback');
        return _generateIntelligentFallback(entryText, [], _parsePhaseHint(phase));
      }
      _lastRequestTime = now;
      
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
          // Build rich context string
          final contextParts = <String>[];
          contextParts.add('Current entry: "$entryText"');
          
          // Add mood/emotion context
          if (mood != null && mood.isNotEmpty) {
            contextParts.add('Mood: $mood');
          }
          
          // Add phase context
          if (phase != null && phase.isNotEmpty) {
            contextParts.add('Phase: $phase');
          }
          
          // Add circadian context
          if (chronoContext != null) {
            final window = chronoContext['window'] ?? 'unknown';
            final chronotype = chronoContext['chronotype'] ?? 'unknown';
            final rhythmScore = chronoContext['rhythmScore'] ?? 0.0;
            final isFragmented = chronoContext['isFragmented'] ?? false;
            contextParts.add('Circadian context: Time window: $window, Chronotype: $chronotype, Rhythm coherence: ${(rhythmScore * 100).toStringAsFixed(0)}%${isFragmented ? ' (fragmented)' : ''}');
          }
          
          // Add earlier entries context
          if (matches.isNotEmpty) {
            contextParts.add('Historical context from earlier entries: ${matches.map((m) => 'From ${m.approxDate?.year}: ${m.excerpt}').join('\n')}');
          }
          
          // Add chat context
          if (chatContext != null && chatContext.isNotEmpty) {
            contextParts.add('\n$chatContext');
          }
          
          // Add media context
          if (mediaContext != null && mediaContext.isNotEmpty) {
            contextParts.add('\n$mediaContext');
          }
          
          String userPrompt;
          if (includeExpansionQuestions) {
            // For first activation, allow full ECHO structure with expansion questions
            final baseContext = contextParts.join('\n\n');
            print('LUMARA Enhanced API: First activation with rich context - using full ECHO structure');
            userPrompt = '$baseContext\n\nFollow the ECHO structure (Empathize → Clarify → Highlight → Open) and include 1-2 clarifying expansion questions that help deepen the reflection. Consider the mood, phase, circadian context, recent chats, and any media when crafting questions that feel personally relevant and timely. Be thoughtful and allow for meaningful engagement.';
          } else {
            // For subsequent activations, keep brief
            if (matches.isNotEmpty) {
              // Use historical context if available
              print('LUMARA Enhanced API: Using ${matches.length} historical matches');
              userPrompt = 'Current entry: "$entryText"\n\nHistorical context: ${matches.map((m) => 'From ${m.approxDate?.year}: ${m.excerpt}').join('\n')}\n\nCRITICAL: Generate 1-2 sentences maximum (150 characters total) that connect their current thoughts to their past experiences. Be brief and profound.';
              print('LUMARA: Generating response with ${matches.length} historical matches');
            } else {
              // Generate fresh reflection without historical context
              print('LUMARA Enhanced API: No historical context - new user');
              userPrompt = 'Current entry: "$entryText"\n\nCRITICAL: Generate 1-2 sentences maximum (150 characters total). Be brief and profound. Focus on the current entry. Be warm, encouraging, and thought-provoking.';
              print('LUMARA: Generating response without historical context (new user)');
            }
          }
          
          print('LUMARA Enhanced API: Calling generateResponse()...');
          // Use the new in-journal ECHO prompt
          final context = {
            'systemPrompt': LumaraPrompts.inJournalPrompt,
            'userPrompt': userPrompt,
          };
          
          // Generate primary response with retry logic
          String? geminiResponse;
          int retryCount = 0;
          const maxRetries = 2;
          
          while (retryCount <= maxRetries) {
            try {
              geminiResponse = await _llmProvider!.generateResponse(context);
              break; // Success, exit retry loop
            } catch (e) {
              retryCount++;
              if (retryCount > maxRetries || 
                  (!e.toString().contains('503') && !e.toString().contains('overloaded'))) {
                rethrow; // Re-throw if not a retryable error or max retries reached
              }
              print('LUMARA: Gemini API retry $retryCount/$maxRetries - waiting 2 seconds...');
              await Future.delayed(const Duration(seconds: 2));
            }
          }
          
          if (geminiResponse == null) {
            throw Exception('Failed to generate response after $maxRetries retries');
          }
          print('LUMARA Enhanced API: ✓ generateResponse completed');
          print('LUMARA Enhanced API: Response length: ${geminiResponse.length}');
          
          // Score the response using the scoring heuristic
          final priorKeywords = matches
              .where((m) => m.excerpt != null)
              .map((m) => m.excerpt!.split(' ').take(5).join(' '))
              .toList();
          final matchedHints = matches.take(1).map((m) => m.id).toList();
          
          final scoringInput = scoring.ScoringInput(
            userText: entryText,
            candidate: geminiResponse,
            phaseHint: _convertToScoringPhaseHint(currentPhase),
            entryType: _convertToScoringEntryType(intent),
            priorKeywords: priorKeywords,
            matchedNodeHints: matchedHints,
          );
          
          var scoredResponse = geminiResponse;
          final breakdown = scoring.LumaraResponseScoring.scoreLumaraResponse(scoringInput);
          
          print('🌼 LUMARA Response Scoring: resonance=${breakdown.resonance.toStringAsFixed(2)}, empathy=${breakdown.empathy.toStringAsFixed(2)}, depth=${breakdown.depth.toStringAsFixed(2)}, agency=${breakdown.agency.toStringAsFixed(2)}');
          
          // If below threshold, auto-fix
          if (breakdown.resonance < scoring.minResonance) {
            print('🌼 Auto-fixing response below threshold (${breakdown.resonance.toStringAsFixed(2)})');
            scoredResponse = scoring.LumaraResponseScoring.autoTightenToEcho(geminiResponse);
            final fixedBreakdown = scoring.LumaraResponseScoring.scoreLumaraResponse(
              scoring.ScoringInput(
                userText: entryText,
                candidate: scoredResponse,
                phaseHint: _convertToScoringPhaseHint(currentPhase),
                priorKeywords: priorKeywords,
                matchedNodeHints: matchedHints,
              ),
            );
            print('🌼 After auto-fix: resonance=${fixedBreakdown.resonance.toStringAsFixed(2)}');
          }
          
          final formatted = '✨ Reflection\n\n$scoredResponse';
          
          _analytics.logLumaraEvent('reflection_generated', data: {
            'matches': matches.length,
            'top_similarity': matches.isNotEmpty ? matches.first.similarity : 0,
            'gemini_generated': true,
          });
          
          return formatted;
        } catch (e) {
          print('LUMARA Enhanced API: ✗ Error generating response: $e');
          print('LUMARA: Error generating Gemini response: $e');
          
          // Check if it's a Gemini API overload error
          if (e.toString().contains('503') || e.toString().contains('overloaded') || e.toString().contains('UNAVAILABLE')) {
            print('LUMARA: Gemini API overloaded - using intelligent fallback');
            return _generateIntelligentFallback(entryText, matches, currentPhase);
          }
          
          // Fall through to template-based response for other errors
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

  /// Convert reflective_node PhaseHint to scoring PhaseHint
  scoring.PhaseHint? _convertToScoringPhaseHint(PhaseHint? phase) {
    if (phase == null) return null;
    
    switch (phase) {
      case PhaseHint.discovery:
        return scoring.PhaseHint.discovery;
      case PhaseHint.expansion:
        return scoring.PhaseHint.expansion;
      case PhaseHint.transition:
        return scoring.PhaseHint.transition;
      case PhaseHint.consolidation:
        return scoring.PhaseHint.consolidation;
      case PhaseHint.recovery:
        return scoring.PhaseHint.recovery;
      case PhaseHint.breakthrough:
        return scoring.PhaseHint.breakthrough;
    }
  }

  /// Convert intent string to scoring EntryType
  scoring.EntryType? _convertToScoringEntryType(String? intent) {
    if (intent == null) return scoring.EntryType.journal;
    
    switch (intent.toLowerCase()) {
      case 'draft':
        return scoring.EntryType.draft;
      case 'chat':
        return scoring.EntryType.chat;
      case 'photo':
        return scoring.EntryType.photo;
      case 'audio':
        return scoring.EntryType.audio;
      case 'video':
        return scoring.EntryType.video;
      case 'voice':
        return scoring.EntryType.voice;
      default:
        return scoring.EntryType.journal;
    }
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

  /// Generate intelligent fallback when Gemini API is overloaded
  String _generateIntelligentFallback(String entryText, List<MatchedNode> matches, PhaseHint? currentPhase) {
    // Detect abstract register for appropriate response structure
    final isAbstract = scoring.LumaraResponseScoring.detectAbstractRegister(entryText);
    
    // Calculate question allowance based on phase and entry type
    final scoringPhase = _convertToScoringPhaseHint(currentPhase);
    final scoringEntryType = _convertToScoringEntryType('journal'); // Default to journal for fallback
    final qAllowance = scoring.questionAllowance(scoringPhase, scoringEntryType, isAbstract);
    
    // Generate ECHO-based response using template logic
    String empathize;
    List<String> clarify;
    String highlight;
    String open;
    
    // Empathize - mirror the tone
    if (isAbstract) {
      empathize = "This feels like a moment of reflection and scope where something meaningful is shifting.";
    } else {
      empathize = "This feels like a moment of strong emotion where something important is happening.";
    }
    
    // Clarify - adaptive questions based on allowance
    clarify = [];
    if (qAllowance >= 1) {
      clarify.add(isAbstract
          ? "What aspect of this experience feels most real to you right now?"
          : "What part of this feels most present for you now?");
    }
    if (qAllowance >= 2) {
      clarify.add(isAbstract
          ? "And what emotion sits beneath the perspective you're describing?"
          : "Would naming the feeling make this clearer?");
    }
    
    // Highlight - use matches if available
    if (matches.isNotEmpty) {
      highlight = "You've reflected on similar themes before — like ${matches.first.excerpt?.substring(0, 50) ?? 'your previous entries'}.";
    } else {
      highlight = "Your writing shows awareness developing through these moments.";
    }
    
    // Open - phase-aware ending
    switch (currentPhase) {
      case PhaseHint.recovery:
        open = "Would it help to rest with this feeling for now, or note one gentle step forward?";
        break;
      case PhaseHint.breakthrough:
        open = "What truth do you want to carry from this realization into your next phase?";
        break;
      case PhaseHint.transition:
      case PhaseHint.consolidation:
        open = "Would clarifying one anchor or value help guide your next move?";
        break;
      default:
        open = "Would it help to explore what this is teaching you, or pause and return later?";
    }
    
    // Combine into ECHO response
    final response = [empathize, ...clarify, highlight, open].join(' ');
    
    return '✨ Reflection\n\n$response';
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
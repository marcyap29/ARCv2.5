// lib/lumara/services/enhanced_lumara_api.dart
// Enhanced LUMARA API with multimodal reflection

import 'dart:async';
import 'dart:math';
import '../../../services/gemini_send.dart';
import 'lumara_reflection_settings_service.dart';
import '../llm/prompts/lumara_master_prompt.dart';
import 'lumara_control_state_builder.dart';
import '../../../mira/memory/sentence_extraction_util.dart';
import 'package:my_app/telemetry/analytics.dart';
import '../models/reflective_node.dart';
import '../models/lumara_reflection_options.dart' as models;
import 'reflective_node_storage.dart';
import 'mcp_bundle_parser.dart';
import 'semantic_similarity_service.dart';
import '../llm/llm_provider_factory.dart';
import '../llm/llm_provider.dart';
import '../config/api_config.dart';
import 'lumara_response_scoring.dart' as scoring;
import '../../../mira/memory/attribution_service.dart';
import '../../../mira/memory/enhanced_memory_schema.dart';
import '../../../arc/core/journal_repository.dart';
import '../../../models/journal_entry_model.dart';
import '../../../arc/chat/chat/chat_repo.dart';
import '../../../arc/chat/chat/chat_repo_impl.dart';
import '../../../arc/chat/chat/chat_models.dart';

/// Result of generating a reflection with attribution traces
class ReflectionResult {
  final String reflection;
  final List<AttributionTrace> attributionTraces;

  const ReflectionResult({
    required this.reflection,
    required this.attributionTraces,
  });
}

/// Enhanced LUMARA API with multimodal reflection
class EnhancedLumaraApi {
  final Analytics _analytics;
  final ReflectiveNodeStorage _storage = ReflectiveNodeStorage();
  final SemanticSimilarityService _similarity = SemanticSimilarityService();
  final AttributionService _attributionService = AttributionService();
  final JournalRepository _journalRepo = JournalRepository();
  final ChatRepo _chatRepo = ChatRepoImpl.instance;

  static const String _standardReflectionLengthRule =
      'Return the full reflection as 2–3 complete sentences so it stays concise inside the journal entry. Avoid bullet points.';
  static const String _deepReflectionLengthRule =
      'Return the full reflection as 3–5 complete sentences to provide noticeably more depth while still avoiding bullet points.';
  
  // LLM Provider tracking (for logging only - we use geminiSend directly)
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
  /// Supports v2.3 options: toneMode, conversationMode, regenerate, preferQuestionExpansion
  /// [onProgress] callback is called with progress messages during API calls
  /// Returns both the reflection text and attribution traces
  Future<ReflectionResult> generatePromptedReflection({
    required String entryText,
    required String intent,
    String? phase,
    String? userId,
    bool includeExpansionQuestions = false,
    String? mood,
    Map<String, dynamic>? chronoContext,
    String? chatContext,
    String? mediaContext,
    // New v2.3 options
    models.LumaraReflectionOptions? options,
    void Function(String message)? onProgress,
  }) async {
    // Convert legacy parameters to options if needed
    final reflectionOptions = options ?? models.LumaraReflectionOptions(
      preferQuestionExpansion: includeExpansionQuestions,
      toneMode: models.ToneMode.normal,
      regenerate: false,
      conversationMode: null,
    );
    
    final result = await generatePromptedReflectionV23(
      request: models.LumaraReflectionRequest(
        userText: entryText,
        phaseHint: _parsePhaseHintToV23(phase),
        entryType: _parseEntryType(intent),
        priorKeywords: [],
        matchedNodeHints: [],
        mediaCandidates: [],
        options: reflectionOptions,
      ),
      userId: userId,
      mood: mood,
      chronoContext: chronoContext,
      chatContext: chatContext,
      mediaContext: mediaContext,
      onProgress: onProgress,
    );
    
    return result;
  }

  /// Generate a prompted reflection using v2.3 unified request model
  /// Returns both the reflection text and attribution traces from the nodes used
  /// 
  /// For in-journal LUMARA, pass [entryId] to enforce per-entry usage limits.
  Future<ReflectionResult> generatePromptedReflectionV23({
    required models.LumaraReflectionRequest request,
    String? userId,
    String? mood,
    Map<String, dynamic>? chronoContext,
    String? chatContext,
    String? mediaContext,
    String? entryId, // For per-entry usage limit tracking
    void Function(String message)? onProgress,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      // ===========================================================
      // PRIORITY 2: Use on-device LUMARA with Firebase proxy for API key
      // ===========================================================
      final currentPhase = _convertFromV23PhaseHint(request.phaseHint);
      
      // 1. Get settings from service
      final settingsService = LumaraReflectionSettingsService.instance;
      final similarityThreshold = await settingsService.getSimilarityThreshold();
      final lookbackYears = await settingsService.getEffectiveLookbackYears();
      final maxMatches = await settingsService.getEffectiveMaxMatches();
      
      // Therapeutic mode is now handled by control state builder
      // No need to determine depth level here - it's in the control state JSON
      
      // 2. Retrieve all candidate nodes for context matching
      onProgress?.call('Preparing context...');

      final allNodes = _storage.getAllNodes(
        userId: userId ?? 'default',
        maxYears: lookbackYears,
      );

      // 3. Score and rank by similarity
      onProgress?.call('Analyzing your journal history...');
      final scored = <({double score, ReflectiveNode node})>[];

      for (final node in allNodes) {
        final score = _similarity.scoreNode(request.userText, node, currentPhase);
        if (score >= similarityThreshold) {  // Use threshold from settings
          scored.add((score: score, node: node));
        }
      }

      scored.sort((a, b) => b.score.compareTo(a.score));
      final topNodes = scored.take(maxMatches).toList();
      
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
      
      // 4. Always use Gemini API directly - no fallbacks, no hard-coded messages
      print('LUMARA Enhanced API v2.3: Calling Gemini API directly (no fallbacks)');
      print('LUMARA v2.3 Options: toneMode=${request.options.toneMode.name}, regenerate=${request.options.regenerate}, preferQuestionExpansion=${request.options.preferQuestionExpansion}, conversationMode=${request.options.conversationMode?.name}');
      
      // Always call Gemini API - same as main LUMARA chat
      try {
          String userPrompt;
          
          // Build context based on options
          final contextParts = <String>[];
          contextParts.add('Current entry: "${request.userText}"');
          
          // Add mood/emotion context
          if (mood != null && mood.isNotEmpty) {
            contextParts.add('Mood: $mood');
          }
          
          // Add phase context
          if (request.phaseHint != null) {
            contextParts.add('Phase: ${request.phaseHint!.name}');
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
          
          final baseContext = contextParts.join('\n\n');
          
          // Build prompt based on options
          if (request.options.conversationMode != null) {
            // Continuation dialogue mode
            final mode = request.options.conversationMode!;
            String modeInstruction = '';
            var lengthInstruction = _standardReflectionLengthRule;
            switch (mode) {
              case models.ConversationMode.ideas:
                modeInstruction = 'Expand Open step into 2–3 practical but gentle suggestions drawn from user\'s past successful patterns. Tone: Warm, creative.';
                break;
              case models.ConversationMode.think:
                modeInstruction = 'Generate logical scaffolding (mini reflection framework: What → Why → What now). Tone: Structured, steady.';
                break;
              case models.ConversationMode.perspective:
                modeInstruction = 'Reframe context using contrastive reasoning (e.g., "Another way to see this might be…"). Tone: Cognitive reframing.';
                break;
              case models.ConversationMode.nextSteps:
                modeInstruction = 'Provide small, phase-appropriate actions (Discovery → explore; Recovery → rest). Tone: Pragmatic, grounded.';
                break;
              case models.ConversationMode.reflectDeeply:
                modeInstruction = 'Invoke More Depth pipeline, reusing current reflection and adding a new Clarify + Open pair. Tone: Introspective.';
                lengthInstruction = _deepReflectionLengthRule;
                break;
              case models.ConversationMode.continueThought:
                modeInstruction = 'Resume the exact reflection that was interrupted. Continue the final idea without restarting context or repeating earlier lines. Pick up mid-sentence if needed.';
                break;
            }
            userPrompt = '$baseContext\n\n**FOCUS ON CURRENT ENTRY**: $modeInstruction Your response must stay focused on the CURRENT ENTRY marked above, not historical entries. Follow the ECHO structure (Empathize → Clarify → Highlight → Open). $lengthInstruction';
          } else if (request.options.regenerate) {
            // Regenerate: different rhetorical focus - FOCUS ON CURRENT ENTRY
            userPrompt = '$baseContext\n\n**FOCUS ON CURRENT ENTRY**: Rebuild reflection from the CURRENT ENTRY marked above with different rhetorical focus. Randomly vary Highlight and Open while staying relevant to what the user just wrote. Keep empathy level constant. Follow ECHO structure. $_standardReflectionLengthRule';
          } else if (request.options.toneMode == models.ToneMode.soft) {
            // Soften tone - FOCUS ON CURRENT ENTRY
            userPrompt = '$baseContext\n\n**FOCUS ON CURRENT ENTRY**: Rewrite in gentler, slower rhythm about the CURRENT ENTRY marked above. Reduce question count to 1. Add permission language ("It\'s okay if this takes time."). Apply tone-softening rule for Recovery/Consolidation even if phase is unknown. Follow ECHO structure. $_standardReflectionLengthRule';
          } else if (request.options.preferQuestionExpansion) {
            // More depth - FOCUS ON CURRENT ENTRY
            userPrompt = '$baseContext\n\n**FOCUS ON CURRENT ENTRY**: Expand Clarify and Highlight steps for richer introspection about the CURRENT ENTRY marked above. Add 1 additional reflective link that relates to what the user just wrote. Follow ECHO structure with deeper exploration. $_deepReflectionLengthRule';
          } else {
            // Default: first activation with rich context - EMPHASIZE CURRENT ENTRY
            userPrompt = '''$baseContext

**IMPORTANT INSTRUCTION**: Focus your reflection PRIMARILY on the CURRENT ENTRY marked above. The historical context is provided only for background understanding of patterns and themes. Your reflection must be directly relevant to and address the specific subject, situation, and emotions expressed in the CURRENT ENTRY.

Follow the ECHO structure (Empathize → Clarify → Highlight → Open) and include 1-2 clarifying expansion questions that help deepen the reflection about the CURRENT ENTRY. Consider the mood, phase, circadian context, recent chats, and any media when crafting questions that feel personally relevant and timely to what the user just wrote. Be thoughtful and allow for meaningful engagement. $_standardReflectionLengthRule''';
          }
          
          // Use Gemini API directly via geminiSend() - same as main LUMARA chat
          print('LUMARA Enhanced API v2.3: Calling Gemini API directly (same as main chat)');
          
          // Build PRISM activity context from request and matches
          // Query repositories for actual data instead of using empty arrays
          final recentJournalEntries = await _getRecentJournalEntries(limit: 20);
          final drafts = await _getDrafts(limit: 10);
          final recentChats = await _getRecentChats(limit: 10);
          final mediaFromEntries = await _extractMediaFromEntries(recentJournalEntries);
          
          // Prioritize current entry with special marking and weight multiple entries
          final allJournalEntries = [
            // Mark current entry as primary focus with special formatting
            '**CURRENT ENTRY (PRIMARY FOCUS)**: ${request.userText}',
            // Add blank line separator
            '',
            // Add recent entries as secondary context with reduced weight
            '**HISTORICAL CONTEXT (REFERENCE ONLY)**:',
            ...recentJournalEntries.map((e) => '- ${e.content}').take(15), // Reduce from 19 to 15 and mark as reference
          ];
          
          // Combine provided chat context with recent chats
          final allChats = <String>[];
          if (chatContext != null && chatContext.isNotEmpty) {
            allChats.add(chatContext);
          }
          allChats.addAll(recentChats);
          
          // Combine provided media context with media from entries
          final allMedia = <String>[];
          if (mediaContext != null && mediaContext.isNotEmpty) {
            allMedia.add(mediaContext);
          }
          allMedia.addAll(mediaFromEntries);
          
          final prismActivity = <String, dynamic>{
            'journal_entries': allJournalEntries,
            'drafts': drafts.map((e) => e.content).toList(),
            'chats': allChats,
            'media': allMedia,
            'patterns': matches.map((m) => m.excerpt ?? '').where((e) => e.isNotEmpty).toList(),
            'emotional_tone': mood ?? 'neutral',
            'cognitive_load': 'moderate', // Could be enhanced with analysis
          };
          
          // Build unified control state JSON
          final controlStateJson = await LumaraControlStateBuilder.buildControlState(
            userId: userId,
            prismActivity: prismActivity,
            chronoContext: chronoContext,
          );
          
          // Get master prompt with control state
          final systemPrompt = LumaraMasterPrompt.getMasterPrompt(controlStateJson);
          
          print('LUMARA Enhanced API v2.3: Using unified master prompt with control state');
          
          print('LUMARA Enhanced API v2.3: System prompt length: ${systemPrompt.length}');
          print('LUMARA Enhanced API v2.3: User prompt length: ${userPrompt.length}');
          
          onProgress?.call('Calling cloud API...');

          // Call Gemini API directly - no fallbacks, no hard-coded responses
          String? geminiResponse;
          int retryCount = 0;
          const maxRetries = 2;

          while (retryCount <= maxRetries && geminiResponse == null) {
            try {
              // Direct Gemini API call - same protocol as main LUMARA chat
              // Pass entryId for per-entry usage limit tracking (free tier: 5 per entry)
              geminiResponse = await geminiSend(
                system: systemPrompt,
                user: userPrompt,
                jsonExpected: false,
                entryId: entryId,
              );

              print('LUMARA: Gemini API response received (length: ${geminiResponse.length})');
              onProgress?.call('Processing response...');
              break; // Success, exit retry loop
            } catch (e) {
              retryCount++;
              if (retryCount > maxRetries) {
                print('LUMARA: Gemini API error after $maxRetries retries: $e');
                // Re-throw the error - no fallbacks, user needs to configure API key
                rethrow;
              }
              // Only retry on 503/overloaded errors
              if (!e.toString().contains('503') &&
                  !e.toString().contains('overloaded') &&
                  !e.toString().contains('UNAVAILABLE')) {
                print('LUMARA: Gemini API error (non-retryable): $e');
                // Re-throw immediately for non-retryable errors (like API key missing)
                rethrow;
              }
              onProgress?.call('Retrying API... ($retryCount/$maxRetries)');
              print('LUMARA: Gemini API retry $retryCount/$maxRetries - waiting 2 seconds...');
              await Future.delayed(const Duration(seconds: 2));
            }
          }

          if (geminiResponse == null) {
            throw Exception('Failed to generate response from Gemini API');
          }
          
          onProgress?.call('Finalizing insights...');
          print('LUMARA Enhanced API v2.3: ✓ Gemini API call completed');
          print('LUMARA Enhanced API v2.3: Response length: ${geminiResponse.length}');
          
          // Score the response using the scoring heuristic
          final priorKeywords = matches
              .where((m) => m.excerpt != null)
              .map((m) => m.excerpt!.split(' ').take(5).join(' '))
              .toList();
          final matchedHints = matches.take(1).map((m) => m.id).toList();
          
          final scoringInput = scoring.ScoringInput(
            userText: request.userText,
            candidate: geminiResponse,
            phaseHint: _convertToScoringPhaseHint(currentPhase),
            entryType: _convertToScoringEntryType(request.entryType.name),
            priorKeywords: priorKeywords,
            matchedNodeHints: matchedHints,
          );
          
          var scoredResponse = geminiResponse;
          final breakdown = scoring.LumaraResponseScoring.scoreLumaraResponse(scoringInput);
          
          print('🌼 LUMARA Response Scoring v2.3: resonance=${breakdown.resonance.toStringAsFixed(2)}, empathy=${breakdown.empathy.toStringAsFixed(2)}, depth=${breakdown.depth.toStringAsFixed(2)}, agency=${breakdown.agency.toStringAsFixed(2)}');
          
          // If below threshold, auto-fix
          if (breakdown.resonance < scoring.minResonance) {
            print('🌼 Auto-fixing response below threshold (${breakdown.resonance.toStringAsFixed(2)})');
            scoredResponse = scoring.LumaraResponseScoring.autoTightenToEcho(geminiResponse);
            final fixedBreakdown = scoring.LumaraResponseScoring.scoreLumaraResponse(
              scoring.ScoringInput(
                userText: request.userText,
                candidate: scoredResponse,
                phaseHint: _convertToScoringPhaseHint(currentPhase),
                priorKeywords: priorKeywords,
                matchedNodeHints: matchedHints,
              ),
            );
            print('🌼 After auto-fix: resonance=${fixedBreakdown.resonance.toStringAsFixed(2)}');
          }
          
          final formatted = '✨ Reflection\n\n$scoredResponse';
          
          // Create attribution traces from the matched nodes that were actually used
          final attributionTraces = <AttributionTrace>[];
          for (final match in matches) {
            // Determine relation type based on similarity score
            String relation = 'related';
            if (match.similarity >= 0.8) {
              relation = 'highly_relevant';
            } else if (match.similarity >= 0.6) {
              relation = 'relevant';
            } else {
              relation = 'somewhat_relevant';
            }
            
            // Get phase context from match
            String? phaseContext;
            if (match.phaseHint != null) {
              phaseContext = match.phaseHint!.name;
            }
            
            // Extract 2-3 relevant sentences from excerpt
            final excerptText = match.excerpt ?? '';
            final excerpt = excerptText.isNotEmpty
                ? (request.userText.isNotEmpty
                    ? extractRelevantSentences(
                        excerptText,
                        query: request.userText,
                        maxSentences: 3,
                      )
                    : extractRelevantSentences(
                        excerptText,
                        maxSentences: 3,
                      ))
                : '';
            
            // Create attribution trace
            final trace = _attributionService.createTrace(
              nodeRef: match.id,
              relation: relation,
              confidence: match.similarity,
              reasoning: 'Matched by semantic similarity (${(match.similarity * 100).toStringAsFixed(1)}%)',
              phaseContext: phaseContext,
              excerpt: excerpt,
            );
            
            attributionTraces.add(trace);
          }
          
          // Always create an attribution trace for the current entry being reflected on
          // Even if there are no matched nodes, the current entry is the primary source
          if (request.userText.isNotEmpty) {
            final currentEntryExcerpt = extractRelevantSentences(
              request.userText,
              query: request.userText, // Use entry text as query to get most relevant sentences
              maxSentences: 3,
            );
            
            // Try to extract entry ID from request if available, otherwise use a generated ID
            String entryId = 'current_entry';
            // Check if userText contains an entry ID pattern or if we can infer it
            // For now, use a generic ID since we don't have direct access to entry ID
            final currentEntryTrace = _attributionService.createTrace(
              nodeRef: entryId,
              relation: 'primary_source',
              confidence: 1.0,
              reasoning: 'Current journal entry - primary source for reflection',
              phaseContext: request.phaseHint?.name,
              excerpt: currentEntryExcerpt,
            );
            attributionTraces.add(currentEntryTrace);
            print('LUMARA Enhanced API v2.3: Created attribution trace for current entry');
          }
          
          print('LUMARA Enhanced API v2.3: Created ${attributionTraces.length} attribution traces (${matches.length} from matches + 1 for current entry)');
          
          _analytics.logLumaraEvent('reflection_generated_v23', data: {
            'matches': matches.length,
            'top_similarity': matches.isNotEmpty ? matches.first.similarity : 0,
            'gemini_generated': true,
            'toneMode': request.options.toneMode.name,
            'regenerate': request.options.regenerate,
            'preferQuestionExpansion': request.options.preferQuestionExpansion,
            'conversationMode': request.options.conversationMode?.name,
            'attribution_traces': attributionTraces.length,
          });
          
          return ReflectionResult(
            reflection: formatted,
            attributionTraces: attributionTraces,
          );
      } catch (e) {
        print('LUMARA Enhanced API: ✗ Error calling Gemini API: $e');
        // No fallbacks - rethrow the error so user knows API call failed
        // Same behavior as main LUMARA chat - no hard-coded responses
        rethrow;
      }
    } catch (e) {
      print('LUMARA Enhanced API: ✗ Fatal error: $e');
      rethrow;
    }
  }

  /// Helper: Convert v2.3 PhaseHint to internal PhaseHint
  PhaseHint? _convertFromV23PhaseHint(models.PhaseHint? phase) {
    if (phase == null) return null;
    // PhaseHint enum names should match between models
    return PhaseHint.values.firstWhere(
      (e) => e.name == phase.name,
      orElse: () => PhaseHint.discovery,
    );
  }

  /// Helper: Parse phase string to v2.3 PhaseHint
  models.PhaseHint? _parsePhaseHintToV23(String? phase) {
    if (phase == null) return null;
    return models.PhaseHint.values.firstWhere(
      (e) => e.name == phase.toLowerCase(),
      orElse: () => models.PhaseHint.discovery,
    );
  }

  /// Helper: Parse entry type string to v2.3 EntryType
  models.EntryType _parseEntryType(String intent) {
    return models.EntryType.values.firstWhere(
      (e) => e.name == intent.toLowerCase(),
      orElse: () => models.EntryType.journal,
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

  // Removed unused helper methods - we use Gemini API directly now

  // All hardcoded fallback methods removed - we only use Gemini API directly (same as main LUMARA chat)

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

  /// Get recent journal entries from repository
  Future<List<JournalEntry>> _getRecentJournalEntries({int limit = 20}) async {
    try {
      final allEntries = await _journalRepo.getAllJournalEntries();
      // Sort by date, newest first
      allEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return allEntries.take(limit).toList();
    } catch (e) {
      print('LUMARA Enhanced API: Error getting recent journal entries: $e');
      return [];
    }
  }

  /// Get draft entries from repository
  /// Drafts are entries with empty title or very short content
  Future<List<JournalEntry>> _getDrafts({int limit = 10}) async {
    try {
      final allEntries = await _journalRepo.getAllJournalEntries();
      final drafts = allEntries.where((entry) {
        // Consider it a draft if title is empty or content is very short
        return entry.title.isEmpty || entry.content.length < 50;
      }).toList();
      // Sort by date, newest first
      drafts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return drafts.take(limit).toList();
    } catch (e) {
      print('LUMARA Enhanced API: Error getting drafts: $e');
      return [];
    }
  }

  /// Get recent chats from repository
  Future<List<String>> _getRecentChats({int limit = 10}) async {
    try {
      await _chatRepo.initialize();
      final sessions = await _chatRepo.listActive();
      // Sort by most recent (assuming sessions have createdAt or similar)
      sessions.sort((a, b) {
        // Try to get creation date from metadata or use a default
        final aDate = a.metadata?['createdAt'] as DateTime?;
        final bDate = b.metadata?['createdAt'] as DateTime?;
        if (aDate != null && bDate != null) {
          return bDate.compareTo(aDate);
        }
        return 0;
      });
      
      final chatTexts = <String>[];
      for (final session in sessions.take(limit)) {
        try {
          final messages = await _chatRepo.getMessages(session.id, lazy: true);
          // Format messages as conversation text
          final conversationText = messages.map((msg) {
            final role = msg.role == MessageRole.user ? 'User' : 'LUMARA';
            return '$role: ${msg.textContent}';
          }).join('\n');
          if (conversationText.isNotEmpty) {
            chatTexts.add('Chat: ${session.subject}\n$conversationText');
          }
        } catch (e) {
          print('LUMARA Enhanced API: Error getting messages for session ${session.id}: $e');
        }
      }
      return chatTexts;
    } catch (e) {
      print('LUMARA Enhanced API: Error getting recent chats: $e');
      return [];
    }
  }

  /// Extract media references from journal entries
  Future<List<String>> _extractMediaFromEntries(List<JournalEntry> entries) async {
    final mediaRefs = <String>[];
    for (final entry in entries) {
      for (final media in entry.media) {
        // Include media type and any available transcript/OCR text
        final mediaDesc = '${media.type.name}: ${media.uri}';
        if (media.transcript != null && media.transcript!.isNotEmpty) {
          mediaRefs.add('$mediaDesc - Transcript: ${media.transcript}');
        } else if (media.ocrText != null && media.ocrText!.isNotEmpty) {
          mediaRefs.add('$mediaDesc - OCR: ${media.ocrText}');
        } else {
          mediaRefs.add(mediaDesc);
        }
      }
    }
    return mediaRefs;
  }

  /// Fallback method to call local Gemini API when Firebase backend fails
}

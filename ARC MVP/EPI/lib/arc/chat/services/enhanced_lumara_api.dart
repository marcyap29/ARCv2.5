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
import 'package:my_app/arc/internal/echo/prism_adapter.dart';
import 'package:my_app/arc/internal/echo/correlation_resistant_transformer.dart';

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
      'Provide a comprehensive, detailed response. Draw connections to past journal entries when relevant. Use historical context to show patterns, evolution, and continuity in the user\'s experience. Be thorough and detailed - there is no limit on response length. Let your response flow naturally to completion. Avoid bullet points. **REFLECTION DISCIPLINE**: Default to reflection-first, but feel free to offer gentle guidance, suggestions, goals, or habits when they naturally emerge from the reflection and feel helpful. You may use language like "This might be a good time to..." or "You might consider..." when patterns suggest helpful directions. Do not end with generic extension questions - let your persona naturally ask questions only when genuinely relevant, not as a default ending.';
  static const String _deepReflectionLengthRule =
      'Provide an extensive, in-depth exploration. Actively reference and analyze past journal entries to show longitudinal patterns, thematic evolution, and meaningful connections. Use historical context extensively to provide rich, contextualized reflection. Be thorough and detailed - there is no limit on response length. Let your response flow naturally to completion. Avoid bullet points. **REFLECTION DISCIPLINE**: Default to reflection-first, but feel free to offer gentle guidance, suggestions, goals, or habits when they naturally emerge from the reflection and feel helpful. You may use language like "This might be a good time to..." or "You might consider..." when patterns suggest helpful directions. Do not end with generic extension questions - let your persona naturally ask questions only when genuinely relevant, not as a default ending.';
  
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
  /// 
  /// For in-journal LUMARA, pass [entryId] to enforce per-entry usage limits.
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
    String? entryId, // For per-entry usage limit tracking
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
      entryId: entryId,
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
          // Step 1: Transform entry text for privacy protection (LOCAL ONLY)
          // This creates an abstract description instead of sending verbatim text
          final prismAdapter = PrismAdapter();
          final entryPrismResult = prismAdapter.scrub(request.userText);
          
          String entryDescription;
          if (entryPrismResult.hadPII) {
            // Transform to correlation-resistant payload to get semantic summary
            final entryTransformation = await prismAdapter.transformToCorrelationResistant(
              prismScrubbedText: entryPrismResult.scrubbedText,
              intent: 'journal_reflection',
              prismResult: entryPrismResult,
              rotationWindow: RotationWindow.session,
            );
            // Use semantic summary instead of verbatim text
            entryDescription = entryTransformation.cloudPayloadBlock.semanticSummary;
            print('LUMARA: Using abstract entry description (${entryDescription.length} chars) instead of verbatim text');
          } else {
            // No PII found, use original text (but still abstract it slightly for consistency)
            entryDescription = request.userText.length > 200 
                ? '${request.userText.substring(0, 200)}...' 
                : request.userText;
          }
          
          String userPrompt;
          
          // Build context based on options
          // Use abstract description instead of verbatim entry text
          final contextParts = <String>[];
          contextParts.add('Current entry: $entryDescription');
          
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
          
          // Add earlier entries context - emphasize active use
          if (matches.isNotEmpty) {
            contextParts.add('**HISTORICAL CONTEXT FROM EARLIER ENTRIES (USE ACTIVELY TO SHOW PATTERNS AND CONNECTIONS)**:\n${matches.map((m) => 'From ${m.approxDate?.year}: ${m.excerpt}').join('\n\n')}\n\n**IMPORTANT**: Actively reference these past entries in your reflection to show patterns, evolution, and meaningful connections to the current entry.');
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
                modeInstruction = 'Extend the previous reflection with additional detail, depth, or considerations. Build naturally on what was already said without repeating earlier content. If the previous reflection was complete, provide additional insights, examples, or perspectives that deepen the understanding. Keep the extension focused and valuable.';
                break;
            }
            userPrompt = '$baseContext\n\n**COMPREHENSIVE REFLECTION**: $modeInstruction Address the CURRENT ENTRY while actively drawing connections to past journal entries from the historical context. Use historical entries to show patterns, evolution, and meaningful connections. Be thorough and detailed - there is no limit on response length. Let your response flow naturally to completion. Follow the ECHO structure (Empathize → Clarify → Highlight → Open) with expanded detail. **REFLECTION DISCIPLINE**: Default to reflection-first, but feel free to offer gentle guidance, suggestions, goals, or habits when they naturally emerge from the reflection and feel helpful. Do not end with generic extension questions - let your persona naturally ask questions only when genuinely relevant, not as a default ending. $lengthInstruction';
          } else if (request.options.regenerate) {
            // Regenerate: different rhetorical focus - FOCUS ON CURRENT ENTRY
            userPrompt = '$baseContext\n\n**COMPREHENSIVE REFLECTION**: Rebuild reflection from the CURRENT ENTRY marked above with different rhetorical focus. Actively reference past journal entries to show patterns and connections. Be thorough and detailed - there is no limit on response length. Let your response flow naturally to completion. Randomly vary Highlight and Open while staying relevant to what the user just wrote. Keep empathy level constant. Follow ECHO structure with expanded detail. **REFLECTION DISCIPLINE**: Default to reflection-first, but feel free to offer gentle guidance, suggestions, goals, or habits when they naturally emerge from the reflection and feel helpful. Do not end with generic extension questions - let your persona naturally ask questions only when genuinely relevant, not as a default ending. $_standardReflectionLengthRule';
          } else if (request.options.toneMode == models.ToneMode.soft) {
            // Soften tone - FOCUS ON CURRENT ENTRY
            userPrompt = '$baseContext\n\n**COMPREHENSIVE REFLECTION**: Rewrite in gentler, slower rhythm about the CURRENT ENTRY marked above. Draw connections to past journal entries for context and continuity. Be thorough and detailed - there is no limit on response length. Let your response flow naturally to completion. Add permission language ("It\'s okay if this takes time."). Apply tone-softening rule for Recovery/Consolidation even if phase is unknown. Follow ECHO structure with expanded detail. **REFLECTION DISCIPLINE**: Default to reflection-first, but feel free to offer gentle guidance, suggestions, goals, or habits when they naturally emerge from the reflection and feel helpful. Do not end with generic extension questions - let your persona naturally ask questions only when genuinely relevant, not as a default ending. $_standardReflectionLengthRule';
          } else if (request.options.preferQuestionExpansion) {
            // More depth - FOCUS ON CURRENT ENTRY
            userPrompt = '$baseContext\n\n**COMPREHENSIVE REFLECTION**: Expand Clarify and Highlight steps for richer introspection about the CURRENT ENTRY marked above. Extensively reference past journal entries to show patterns, evolution, and meaningful connections. Be thorough and detailed - there is no limit on response length. Let your response flow naturally to completion. Add multiple reflective links that connect the current entry to historical patterns and themes. Follow ECHO structure with deep, detailed exploration. **REFLECTION DISCIPLINE**: Default to reflection-first, but feel free to offer gentle guidance, suggestions, goals, or habits when they naturally emerge from the reflection and feel helpful. Do not end with generic extension questions - let your persona naturally ask questions only when genuinely relevant, not as a default ending. $_deepReflectionLengthRule';
          } else {
            // Default: first activation with rich context - EMPHASIZE CURRENT ENTRY
            userPrompt = '''$baseContext

**IMPORTANT INSTRUCTION**: Provide a comprehensive reflection that:
1. Addresses the CURRENT ENTRY as the primary focus
2. ACTIVELY references and draws connections to past journal entries from the historical context
3. Shows patterns, themes, and evolution across the user's journal history
4. Uses historical entries to provide deeper context and meaning to the current entry

The historical context is not just background - it is essential material for understanding patterns, showing continuity, and providing rich, contextualized reflection. Draw explicit connections between the current entry and past entries when relevant.

**REFLECTION DISCIPLINE**:
- Your primary role is sense-making through reflection. Reflect lived experience accurately. Surface patterns. Situate moments within a larger arc.
- You are encouraged to offer gentle guidance, suggestions, goals, or habits when they naturally emerge from the reflection and feel helpful.
- You may use language like "This might be a good time to...", "You might consider...", or "It could be helpful to..." when patterns suggest helpful directions.
- Reference past entries for continuity and to suggest helpful directions when patterns emerge (e.g., "You previously set goals to..." or "This might be a good time to return to..." when relevant).
- Use SAGE internally to structure understanding, but do NOT label sections or turn it into an improvement framework.
- Growth may be framed as emerging awareness or as natural next steps when patterns suggest them.
- You may end with questions like "Does this resonate?" or "What do you want to do next?" when they feel natural and helpful.
- If guidance is not explicitly requested, do not provide it. When uncertain, reflect and stop.

Follow the ECHO structure (Empathize → Clarify → Highlight → Open) but expand each section with detail. Include connections to past entries in your Highlight section. Consider the mood, phase, circadian context, recent chats, and any media when crafting your reflection. Be thorough and detailed - there is no limit on response length. Let your response flow naturally to completion. $_standardReflectionLengthRule''';
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
            // Add recent entries as important context for pattern recognition
            '**HISTORICAL CONTEXT (USE ACTIVELY FOR PATTERNS AND CONNECTIONS)**:',
            ...recentJournalEntries.map((e) => '- ${e.content}').take(20), // Increase to 20 entries for richer context
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
          
          // Build unified control state JSON (pass user text for dynamic persona/response mode detection)
          final controlStateJson = await LumaraControlStateBuilder.buildControlState(
            userId: userId,
            prismActivity: prismActivity,
            chronoContext: chronoContext,
            userMessage: request.userText, // Pass user message for question intent detection
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
              // NOTE: userPrompt already contains abstracted entry description, not verbatim text
              // Skip transformation since we've already abstracted the entry text in the prompt
              geminiResponse = await geminiSend(
                system: systemPrompt,
                user: userPrompt,
                jsonExpected: false,
                entryId: entryId,
                intent: 'journal_reflection', // Specify intent for journal entries
                skipTransformation: true, // Skip transformation - entry already abstracted
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

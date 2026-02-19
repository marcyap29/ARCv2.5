// lib/lumara/services/enhanced_lumara_api.dart
// Enhanced LUMARA API with multimodal reflection

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../../../services/gemini_send.dart';
import 'groq_service.dart';
import 'lumara_reflection_settings_service.dart';
import '../llm/prompts/lumara_master_prompt.dart';
import '../../../mira/memory/sentence_extraction_util.dart';
import 'lumara_context_selector.dart';
import 'package:my_app/telemetry/analytics.dart';
import 'package:my_app/chronicle/query/query_router.dart';
import 'package:my_app/chronicle/query/context_builder.dart';
import 'package:my_app/chronicle/query/chronicle_context_cache.dart';
import 'package:my_app/chronicle/query/drill_down_handler.dart';
import 'package:my_app/chronicle/query/pattern_query_router.dart' hide QueryIntent, QueryResponse, QueryType;
import 'package:my_app/chronicle/embeddings/create_embedding_service.dart';
import 'package:my_app/chronicle/storage/chronicle_index_storage.dart';
import 'package:my_app/chronicle/index/chronicle_index_builder.dart';
import 'package:my_app/chronicle/matching/three_stage_matcher.dart';
import 'package:my_app/chronicle/core/chronicle_repos.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';
import 'package:my_app/chronicle/editing/contradiction_checker.dart';
import 'package:my_app/chronicle/storage/aggregation_repository.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';
import 'package:my_app/chronicle/models/chronicle_aggregation.dart';
import 'package:my_app/chronicle/models/query_plan.dart';
import 'package:my_app/chronicle/dual/services/dual_chronicle_services.dart';
import 'package:my_app/chronicle/dual/models/chronicle_models.dart';
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
import 'package:my_app/app/app_repos.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import '../../../models/journal_entry_model.dart';
import '../../../arc/chat/chat/chat_repo.dart';
import '../../../arc/chat/chat/chat_models.dart';
import 'package:my_app/arc/internal/echo/prism_adapter.dart';
import 'package:my_app/arc/internal/echo/correlation_resistant_transformer.dart';
import '../../../services/lumara/entry_classifier.dart';
import 'package:intl/intl.dart';
import '../../../services/lumara/response_mode.dart';
import '../../../services/lumara/classification_logger.dart';
import '../../../services/sentinel/sentinel_analyzer.dart';
import '../../../services/sentinel/crisis_mode.dart';
import '../../../models/engagement_discipline.dart' show EngagementMode;
import '../../../models/memory_focus_preset.dart' show MemoryFocusPreset;
import '../voice/prompts/voice_response_builders.dart';
import 'package:my_app/state/feature_flags.dart';
import 'package:my_app/lumara/models/intent_type.dart';
import 'package:my_app/lumara/orchestrator/lumara_orchestrator.dart';
import 'package:my_app/lumara/subsystems/chronicle_subsystem.dart';
import 'package:my_app/lumara/subsystems/writing_subsystem.dart';
import 'package:my_app/lumara/orchestrator/command_parser.dart';
import 'package:my_app/lumara/orchestrator/result_aggregator.dart';
import 'package:my_app/lumara/agents/writing/writing_agent.dart';
import 'package:my_app/lumara/agents/writing/writing_draft_repository.dart';
import 'arc_subsystem.dart';
import 'atlas_subsystem.dart';
import 'aurora_subsystem.dart';

/// Result of generating a reflection with attribution traces
class ReflectionResult {
  final String reflection;
  final List<AttributionTrace> attributionTraces;
  final String? persona; // Selected persona (companion, strategist, therapist, challenger)
  final bool? safetyOverride; // Whether safety override was triggered
  final double? sentinelScore; // Sentinel score if calculated

  const ReflectionResult({
    required this.reflection,
    required this.attributionTraces,
    this.persona,
    this.safetyOverride,
    this.sentinelScore,
  });
}

/// Response length target based on engagement mode
class ResponseLengthTarget {
  final int sentences;
  final int words;
  final String description;
  
  const ResponseLengthTarget({
    required this.sentences,
    required this.words,
    required this.description,
  });
}

/// Response parameters for LUMARA
class ResponseParameters {
  final int maxWords;
  final int targetWords;
  final int targetSentences;
  final int minPatternExamples;
  final int maxPatternExamples;
  final bool useStructuredFormat;
  final String lengthGuidance;
  
  ResponseParameters({
    required this.maxWords,
    required this.targetWords,
    required this.targetSentences,
    required this.minPatternExamples,
    required this.maxPatternExamples,
    required this.useStructuredFormat,
    required this.lengthGuidance,
  });
}

/// Enhanced LUMARA API with multimodal reflection
class EnhancedLumaraApi {
  final Analytics _analytics;
  final ReflectiveNodeStorage _storage = ReflectiveNodeStorage();
  final SemanticSimilarityService _similarity = SemanticSimilarityService();
  final AttributionService _attributionService = AttributionService();
  final JournalRepository _journalRepo = AppRepos.journal;
  final ChatRepo _chatRepo = AppRepos.chat;

  // CHRONICLE components (lazy initialization)
  ChronicleQueryRouter? _queryRouter;
  ChronicleContextBuilder? _contextBuilder;
  PatternQueryRouter? _patternQueryRouter;
  DrillDownHandler? _drillDownHandler;
  Layer0Repository? _layer0Repo;
  AggregationRepository? _aggregationRepo;
  bool _chronicleInitialized = false;

  /// Lazy-built when [FeatureFlags.useOrchestrator] is true and CHRONICLE is initialized.
  LumaraOrchestrator? _orchestrator;
  
  // LLM Provider tracking (for logging only - we use Groq primary, geminiSend fallback)
  LLMProviderBase? _llmProvider;
  LumaraAPIConfig? _apiConfig;
  GroqService? _groqService;

  bool _initialized = false;

  EnhancedLumaraApi(this._analytics);

  /// Groq service (Llama 3.3 70B / Mixtral). Created when Groq API key is available.
  GroqService? get _groq {
    if (_groqService != null) return _groqService;
    final key = _apiConfig?.getConfig(LLMProvider.groq)?.apiKey;
    if (key == null || key.isEmpty) return null;
    _groqService = GroqService(apiKey: key);
    return _groqService;
  }

  double _temperatureForMode(EngagementMode? mode) {
    switch (mode) {
      case EngagementMode.explore:
        return 0.8;
      case EngagementMode.integrate:
        return 0.7;
      case EngagementMode.reflect:
        return 0.6;
      default:
        return 0.7;
    }
  }

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
      
      // Initialize CHRONICLE components (non-blocking - graceful degradation if fails)
      _initializeChronicle();
      
      _initialized = true;
      print('LUMARA: Enhanced API initialized');
    } catch (e) {
      print('LUMARA: Initialization error: $e');
      // Continue with degraded mode
    }
  }

  /// Initialize CHRONICLE components (lazy, non-blocking)
  Future<void> _initializeChronicle() async {
    if (_chronicleInitialized) return;

    try {
      await ChronicleRepos.ensureLayer0Initialized();
      _layer0Repo = ChronicleRepos.layer0;
      _aggregationRepo = ChronicleRepos.aggregation;
      
      _queryRouter = ChronicleQueryRouter();
      _contextBuilder = ChronicleContextBuilder(
        aggregationRepo: _aggregationRepo!,
        cache: ChronicleContextCache.instance,
      );
      _drillDownHandler = DrillDownHandler(
        layer0Repo: _layer0Repo!,
        aggregationRepo: _aggregationRepo!,
        journalRepo: _journalRepo,
      );

      // Optional: pattern index (vectorizer) for cross-temporal theme queries
      try {
        final embedder = await createEmbeddingService();
        await embedder.initialize();
        final indexStorage = ChronicleIndexStorage();
        final indexBuilder = ChronicleIndexBuilder(
          embedder: embedder,
          storage: indexStorage,
        );
        final matcher = ThreeStagePatternMatcher(embedder);
        _patternQueryRouter = PatternQueryRouter(
          indexBuilder: indexBuilder,
          matcher: matcher,
          embedder: embedder,
        );
        print('✅ LUMARA: CHRONICLE pattern index (vectorizer) enabled');
      } catch (e) {
        print('⚠️ LUMARA: CHRONICLE pattern index unavailable (non-fatal): $e');
      }

      _chronicleInitialized = true;
      print('✅ LUMARA: CHRONICLE components initialized');
    } catch (e) {
      print('⚠️ LUMARA: CHRONICLE initialization failed (non-fatal): $e');
      // Continue without CHRONICLE - will fallback to raw entries
    }
  }

  /// Build orchestrator once when [FeatureFlags.useOrchestrator] is true and CHRONICLE is ready.
  void _ensureOrchestrator() {
    if (_orchestrator != null || !FeatureFlags.useOrchestrator) return;
    if (!_chronicleInitialized || _queryRouter == null || _contextBuilder == null) return;
    final self = this;
    final writingAgent = WritingAgent(
      draftRepository: WritingDraftRepositoryImpl(),
      getAgentOsPrefix: () => LumaraReflectionSettingsService.instance.getAgentOsPrefix(),
      generateContent: ({required systemPrompt, required userPrompt, maxTokens}) async {
        final g = self._groq;
        if (g == null) {
          throw StateError('Writing requires a cloud API key (Groq). Set it in LUMARA settings.');
        }
        return g.generateContent(
          prompt: userPrompt,
          systemPrompt: systemPrompt,
          maxTokens: maxTokens ?? 800,
        );
      },
    );
    _orchestrator = LumaraOrchestrator(
      subsystems: [
        ChronicleSubsystem(
          router: _queryRouter!,
          contextBuilder: _contextBuilder!,
          patternQueryRouter: _patternQueryRouter,
        ),
        ArcSubsystem(),
        AtlasSubsystem(),
        AuroraSubsystem(),
        WritingSubsystem(agent: writingAgent),
      ],
      parser: CommandParser(),
      aggregator: ResultAggregator(),
    );
    print('✅ LUMARA: Orchestrator initialized (CHRONICLE + ARC + ATLAS + AURORA + WRITING)');
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
  /// 
  /// [forceQuickResponse] - When true (e.g., for voice mode), bypasses heavy reflective
  /// processing and uses fast response paths regardless of content classification.
  /// This ensures voice conversations get quick responses (2-5 seconds vs 30-40 seconds).
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
    bool forceQuickResponse = false, // For voice mode - use fast paths
    bool skipHeavyProcessing = false, // Skip node matching/context retrieval but still use Master Prompt
    EngagementMode? voiceEngagementModeOverride, // When set (voice dropdown), use this for control state and prompt cap
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
      forceQuickResponse: forceQuickResponse,
      skipHeavyProcessing: skipHeavyProcessing,
      voiceEngagementModeOverride: voiceEngagementModeOverride,
      onProgress: onProgress,
    );
    
    return result;
  }

  /// Generate a prompted reflection using v2.3 unified request model
  /// Returns both the reflection text and attribution traces from the nodes used
  /// 
  /// For in-journal LUMARA, pass [entryId] to enforce per-entry usage limits.
  /// 
  /// [forceQuickResponse] - For voice mode: bypass heavy reflective processing,
  /// use fast paths (factual for questions, conversational for statements).
  Future<ReflectionResult> generatePromptedReflectionV23({
    required models.LumaraReflectionRequest request,
    String? userId,
    String? mood,
    Map<String, dynamic>? chronoContext,
    String? chatContext,
    String? mediaContext,
    String? entryId, // For per-entry usage limit tracking
    bool forceQuickResponse = false, // For voice mode - use fast paths
    bool skipHeavyProcessing = false, // Skip node matching/context retrieval but still use Master Prompt
    EngagementMode? voiceEngagementModeOverride, // When set (voice dropdown), use for control state and prompt cap
    void Function(String message)? onProgress,
    /// When set, stream response chunks to this callback (uses direct Gemini stream when available; else emits full response once)
    void Function(String chunk)? onStreamChunk,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      // ===========================================================
      // STEP 0: CLASSIFY ENTRY TYPE (NEW - BEFORE ANY OTHER PROCESSING)
      // ===========================================================
      EntryType entryType;
      
      if (forceQuickResponse && !skipHeavyProcessing) {
        // OLD VOICE MODE: Force fast paths regardless of content (bypasses Master Prompt)
        // Use factual for questions (100 words), conversational for statements (50 words)
        final isQuestion = request.userText.contains('?') || 
            RegExp(r'\b(what|how|why|when|where|who|which|can|could|would|should|is|are|do|does|did)\b', caseSensitive: false)
                .hasMatch(request.userText.split(' ').take(3).join(' '));
        
        entryType = isQuestion ? EntryType.factual : EntryType.conversational;
        print('LUMARA: Voice mode (legacy) - forcing ${entryType.name} path for fast response');
      } else {
        // Normal classification for journal/chat
        // When skipHeavyProcessing is true, we still classify normally but use Master Prompt
        entryType = EntryClassifier.classify(request.userText);
        if (skipHeavyProcessing) {
          print('LUMARA: Voice mode (Master Prompt) - classified as ${entryType.name}, skipping heavy processing');
        }
      }
      
      final responseMode = ResponseMode.forEntryType(entryType, request.userText);

      onProgress?.call('Entry classified as: ${EntryClassifier.getTypeDescription(entryType)}');

      // Log classification for monitoring (skip in voice mode to avoid Firestore permission-denied)
      if (userId != null && !skipHeavyProcessing) {
        await ClassificationLogger.logClassification(
          userId: userId,
          entryText: request.userText,
          classification: entryType,
          responseMode: responseMode,
        );
      }

      // ===========================================================
      // HANDLE DIFFERENT RESPONSE MODES
      // ===========================================================

      // When skipHeavyProcessing is true, use Master Prompt for ALL entry types
      // Otherwise, use fast paths for factual/conversational
      if (!skipHeavyProcessing) {
      if (entryType == EntryType.factual) {
        // FACTUAL MODE: Direct answer without full LUMARA processing
        return await _generateFactualResponse(request, responseMode, onProgress);
      } else if (entryType == EntryType.conversational) {
        // CONVERSATIONAL MODE: Brief acknowledgment
        return await _generateConversationalResponse(request, responseMode, onProgress);
        }
      }

      // FOR REFLECTIVE, ANALYTICAL, AND META-ANALYSIS: Continue with existing LUMARA processing
      // but modify it based on response mode

      // ===========================================================
      // PRIORITY 2: Use on-device LUMARA with Firebase proxy for API key
      // ===========================================================
      final currentPhase = _convertFromV23PhaseHint(request.phaseHint);
      
      // 1. Get settings from service (skip for voice mode to reduce latency)
      final settingsService = LumaraReflectionSettingsService.instance;
      
      // Therapeutic mode is now handled by control state builder
      // No need to determine depth level here - it's in the control state JSON
      
      // 2. Retrieve all candidate nodes for context matching (skip if skipHeavyProcessing is true)
      List<MatchedNode> matches = [];
      
      if (!skipHeavyProcessing) {
      // Only load these settings when needed (not voice mode)
      final similarityThreshold = await settingsService.getSimilarityThreshold();
      final lookbackYears = await settingsService.getEffectiveLookbackYears(); // Legacy: still used for node storage
      final maxMatches = await settingsService.getEffectiveMaxEntries(); // Updated to use maxEntries
      
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
        matches = topNodes.map((item) => MatchedNode(
        id: item.node.id,
        sourceType: item.node.type,
        originalMcpId: item.node.mcpId,
        approxDate: item.node.createdAt,
        phaseHint: item.node.phaseHint,
        mediaRefs: item.node.mediaRefs?.map((m) => m.id).toList(),
        similarity: item.score,
        excerpt: _similarity.gatherText(item.node).substring(0, min(200, _similarity.gatherText(item.node).length)),
      )).toList();
      } else {
        print('LUMARA: Skipping node matching and context retrieval for voice mode');
      }
      
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

          // CLASSIFICATION-AWARE PRIVACY: Preserve semantic content for factual/analytical entries
          if (entryType == EntryType.factual || entryType == EntryType.analytical) {
            // For factual/analytical entries, preserve the semantic content after PII scrubbing
            // These rarely contain sensitive personal info, and cloud needs to understand the question
            if (entryPrismResult.hadPII) {
              // Just use the PII-scrubbed text, don't abstract to generic summary
              entryDescription = entryPrismResult.scrubbedText;
              print('LUMARA: Using PII-scrubbed text for factual/analytical entry (${entryDescription.length} chars)');
            } else {
              // No PII, use original text for factual questions
              entryDescription = request.userText;
              print('LUMARA: Using original text for factual/analytical entry (no PII detected)');
            }
          } else {
            // For reflective/personal entries, use full abstraction for privacy
            if (entryPrismResult.hadPII) {
              // Transform to correlation-resistant payload to get semantic summary
              final entryTransformation = await prismAdapter.transformToCorrelationResistant(
                prismScrubbedText: entryPrismResult.scrubbedText,
                intent: 'journal_reflection',
                prismResult: entryPrismResult,
                rotationWindow: RotationWindow.session,
              );
              // Use semantic summary for personal/emotional entries
              entryDescription = entryTransformation.cloudPayloadBlock.semanticSummary;
              print('LUMARA: Using abstract entry description for reflective entry (${entryDescription.length} chars) instead of verbatim text');
            } else {
              // No PII found, but still abstract slightly for reflective entries for consistency
              entryDescription = request.userText.length > 200
                  ? '${request.userText.substring(0, 200)}...'
                  : request.userText;
            }
          }
          
          
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
          
          // Add earlier entries context - use for pattern recognition with dated examples
          if (matches.isNotEmpty) {
            contextParts.add('**HISTORICAL CONTEXT (Use for pattern recognition with dated examples)**:\n${matches.map((m) => 'From ${m.approxDate?.toString().substring(0, 10) ?? 'Unknown date'}: ${m.excerpt}').join('\n\n')}\n\n**PATTERN REQUIREMENT**: If showing patterns, reference specific dated examples from above (e.g., "in August", "on October 3rd"). Focus on meaningful patterns, not listing all projects.');
          }
          
          // Add chat context
          if (chatContext != null && chatContext.isNotEmpty) {
            contextParts.add('\n$chatContext');
          }
          
          // Add media context
          if (mediaContext != null && mediaContext.isNotEmpty) {
            contextParts.add('\n$mediaContext');
          }
          
          // Use Gemini API directly via geminiSend() - same as main LUMARA chat
          print('LUMARA Enhanced API v2.3: Calling Gemini API directly (same as main chat)');
          
          // Get Memory Focus preset and Engagement Mode for context selection
          // Skip context selection if skipHeavyProcessing is true (or when ARC from orchestrator)
          List<JournalEntry> recentJournalEntries = [];
          EngagementMode? engagementMode;
          List<Map<String, dynamic>>? recentEntriesFromArc;
          List<String>? entryContentsFromArc;
          
          if (!skipHeavyProcessing) {
          final memoryFocusPreset = await settingsService.getMemoryFocusPreset();
          final engagementSettings = await settingsService.getEngagementSettings();
            engagementMode = engagementSettings.activeMode;
          
          // Use new context selector instead of hard-coded limits (orchestrator may override with ARC data later)
          final contextSelector = LumaraContextSelector();
            recentJournalEntries = await contextSelector.selectContextEntries(
            memoryFocus: memoryFocusPreset,
            engagementMode: engagementMode,
            currentEntryText: request.userText,
            currentDate: DateTime.now(),
            entryId: entryId, // Use entryId parameter from function signature
          );
          } else {
            // Voice mode: use dropdown choice if provided, else settings
            if (voiceEngagementModeOverride != null) {
              engagementMode = voiceEngagementModeOverride;
              print('LUMARA: Voice mode using engagement override: ${engagementMode.name}');
            } else {
              final engagementSettings = await settingsService.getEngagementSettings();
              engagementMode = engagementSettings.activeMode;
            }
            
            // Voice mode: Detect if user is asking about history/past to load more context
            final userQuery = request.userText.toLowerCase();
            final isHistoricalQuery = userQuery.contains('last week') ||
                userQuery.contains('last month') ||
                userQuery.contains('recently') ||
                userQuery.contains('been writing') ||
                userQuery.contains('been talking') ||
                userQuery.contains('have i') ||
                userQuery.contains('did i') ||
                userQuery.contains('what was') ||
                userQuery.contains('remember when') ||
                userQuery.contains('earlier') ||
                userQuery.contains('before') ||
                userQuery.contains('history') ||
                userQuery.contains('past') ||
                RegExp(r'\b(january|february|march|april|may|june|july|august|september|october|november|december)\b').hasMatch(userQuery) ||
                RegExp(r'\b(yesterday|ago|previous)\b').hasMatch(userQuery);
            
            // Voice mode: Load 0 journal entries by default for speed; only load when user asks about history
            // (Context selector + Hive can add 2–5s; skipping gives much faster first response.)
            final voiceEntryLimit = isHistoricalQuery ? 10 : 0;
            if (voiceEntryLimit > 0) {
              final contextSelector = LumaraContextSelector();
              recentJournalEntries = await contextSelector.selectContextEntries(
                memoryFocus: MemoryFocusPreset.focused,
                engagementMode: engagementMode ?? EngagementMode.reflect,
                currentEntryText: request.userText,
                currentDate: DateTime.now(),
                entryId: entryId,
                customMaxEntries: voiceEntryLimit,
              );
              print('LUMARA: Voice mode loaded $voiceEntryLimit journal entries (historical query)');
            } else {
              print('LUMARA: Voice mode skipping journal context for speed (0 entries)');
            }
          }
          
          // Voice mode: skip chat history for speed (avoids Firestore init + permission issues)
          // Non-voice mode still loads up to 10 sessions
          final voiceChatLimit = skipHeavyProcessing ? 0 : 10;
          final recentChats = voiceChatLimit > 0
              ? await _getRecentChats(limit: voiceChatLimit)
              : <String>[];
          // Voice mode: skip media extraction (not supported in voice mode yet)
          final mediaFromEntries = skipHeavyProcessing ? <String>[] : await _extractMediaFromEntries(recentJournalEntries);
          
          // Get current date/time for consistent use throughout
          final now = DateTime.now();
          final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
          final todayDateStr = dateFormat.format(now);
          
          // ═══════════════════════════════════════════════════════════
          // STEP 0.5: ROUTE QUERY FOR CHRONICLE (if available)
          // ═══════════════════════════════════════════════════════════
          
          QueryPlan? queryPlan;
          String? chronicleContext;
          List<String>? chronicleLayerNames;
          String? chronicleMiniContext;
          String? atlasContext;
          String? auroraContext;
          LumaraPromptMode promptMode = LumaraPromptMode.rawBacked;
          // Reversible map for CHRONICLE PII restore after cloud response (device-only)
          Map<String, String> chronicleReversibleMap = {};
          
          // Voice mode: skip query router to save one Gemini round-trip (~5–15s). Use default plan.
          if (skipHeavyProcessing) {
            queryPlan = QueryPlan.rawEntry(intent: QueryIntent.temporalQuery);
            print('🔀 EnhancedLumaraApi: Voice mode - skipping query router (saves 1 Gemini call), using rawEntry plan');
          }
          // Orchestrator path: CHRONICLE + ARC via LumaraOrchestrator (when feature flag enabled)
          else if (FeatureFlags.useOrchestrator && _chronicleInitialized && _queryRouter != null && _contextBuilder != null && userId != null) {
            _ensureOrchestrator();
            try {
              final orchResult = await _orchestrator!.execute(request.userText, userId: userId, entryId: entryId);
              if (!orchResult.isError) {
                final ctxMap = orchResult.toContextMap();
                chronicleContext = ctxMap['CHRONICLE'];
                final chronData = orchResult.getSubsystemData('CHRONICLE');
                if (chronData != null && chronData['layers'] != null) {
                  chronicleLayerNames = List<String>.from(chronData['layers'] as List);
                }
                if (chronicleContext != null && chronicleContext.isNotEmpty) {
                  promptMode = LumaraPromptMode.chronicleBacked;
                  print('✅ EnhancedLumaraApi: CHRONICLE context from orchestrator (${chronicleLayerNames?.length ?? 0} layers)');
                } else {
                  print('🔀 EnhancedLumaraApi: Orchestrator ran but CHRONICLE had no context, using rawBacked');
                }
                final arcData = orchResult.getSubsystemData('ARC');
                if (arcData != null && arcData['recentEntries'] != null && arcData['entryContents'] != null) {
                  recentEntriesFromArc = List<Map<String, dynamic>>.from(arcData['recentEntries'] as List);
                  entryContentsFromArc = List<String>.from(arcData['entryContents'] as List);
                  print('✅ EnhancedLumaraApi: ARC context from orchestrator (${entryContentsFromArc.length} entries)');
                }
                atlasContext = ctxMap['ATLAS'];
                auroraContext = ctxMap['AURORA'];
                if (atlasContext != null && atlasContext.isNotEmpty) {
                  print('✅ EnhancedLumaraApi: ATLAS context from orchestrator');
                }
                if (auroraContext != null && auroraContext.isNotEmpty) {
                  print('✅ EnhancedLumaraApi: AURORA context from orchestrator');
                }
                // Writing Agent: if intent is content generation, return draft as reflection
                if (orchResult.intent.type == IntentType.contentGeneration) {
                  final writingData = orchResult.getSubsystemData('WRITING');
                  final draft = writingData?['draft'];
                  if (draft != null && draft is String) {
                    final draftStr = draft as String;
                    print('✅ EnhancedLumaraApi: Returning WRITING draft (${draftStr.length} chars)');
                    return ReflectionResult(
                      reflection: draftStr,
                      attributionTraces: [],
                    );
                  }
                }
              } else {
                final first = orchResult.subsystemResults.isNotEmpty ? orchResult.subsystemResults.first : null;
                final msg = first?.errorMessage ?? 'unknown';
                print('⚠️ EnhancedLumaraApi: Orchestrator error (non-fatal): $msg');
              }
            } catch (e) {
              print('⚠️ EnhancedLumaraApi: Orchestrator failed (non-fatal): $e');
            }
          }
          // Legacy: route query if CHRONICLE is available (text mode only)
          else if (_chronicleInitialized && _queryRouter != null && userId != null) {
            try {
              queryPlan = await _queryRouter!.route(
                query: request.userText,
                userContext: {
                  'userId': userId,
                  'currentPhase': request.phaseHint?.name,
                },
                mode: engagementMode,
                isVoice: skipHeavyProcessing,
              );
              
              print('🔀 EnhancedLumaraApi: Query routed - intent: ${queryPlan.intent}, usesChronicle: ${queryPlan.usesChronicle}, speedTarget: ${queryPlan.speedTarget}');
              
              if (queryPlan.usesChronicle && _contextBuilder != null) {
                if (skipHeavyProcessing) {
                  // Voice mode: only build mini-context (one layer) to avoid latency/timeout.
                  if (queryPlan.layers.isNotEmpty) {
                    final layer = queryPlan.layers.first;
                    final period = _getPeriodForLayer(layer, queryPlan.dateFilter, now);
                    if (period != null) {
                      chronicleMiniContext = await _contextBuilder!.buildMiniContext(
                        userId: userId,
                        layer: layer,
                        period: period,
                      );
                      if (chronicleMiniContext != null && chronicleMiniContext.isNotEmpty) {
                        print('✅ EnhancedLumaraApi: CHRONICLE mini-context loaded for voice (${layer.name})');
                      }
                    }
                  }
                } else {
                  // Text mode: load context (single-layer compressed for fast, full for normal/deep)
                  chronicleContext = await _contextBuilder!.buildContext(
                    userId: userId,
                    queryPlan: queryPlan,
                  );
                  
                  if (chronicleContext != null && chronicleContext.isNotEmpty) {
                    promptMode = queryPlan.drillDown 
                        ? LumaraPromptMode.hybrid 
                        : LumaraPromptMode.chronicleBacked;
                    
                    chronicleLayerNames = queryPlan.layers
                        .map((l) {
                          switch (l) {
                            case ChronicleLayer.monthly:
                              return 'Monthly';
                            case ChronicleLayer.yearly:
                              return 'Yearly';
                            case ChronicleLayer.multiyear:
                              return 'Multi-Year';
                            default:
                              return l.name;
                          }
                        })
                        .toList();
                    
                    print('✅ EnhancedLumaraApi: CHRONICLE context loaded (${queryPlan.layers.length} layers, ${queryPlan.speedTarget})');
                  } else {
                    print('⚠️ EnhancedLumaraApi: CHRONICLE context not available, falling back to raw entries');
                    promptMode = LumaraPromptMode.rawBacked;
                  }
                }
              }
              // Voice or instant speed: build mini-context even when plan has no layers (rawEntry)
              if (skipHeavyProcessing && _contextBuilder != null && chronicleMiniContext == null) {
                final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
                chronicleMiniContext = await _contextBuilder!.buildMiniContext(
                  userId: userId,
                  layer: ChronicleLayer.monthly,
                  period: period,
                );
                if (chronicleMiniContext != null && chronicleMiniContext.isNotEmpty) {
                  print('✅ EnhancedLumaraApi: CHRONICLE mini-context loaded for voice (current month)');
                }
              }
            } catch (e) {
              print('⚠️ EnhancedLumaraApi: Query routing failed (non-fatal): $e');
              // Fallback to raw mode
              promptMode = LumaraPromptMode.rawBacked;
            }
          }

          // Scrub CHRONICLE context before sending to cloud (PiiScrubber/PrismAdapter); restore PII when response returns
          final chroniclePrism = PrismAdapter();
          final chronicleContextChecked = chronicleContext;
          if (chronicleContextChecked != null && chronicleContextChecked.isNotEmpty) {
            final r = chroniclePrism.scrub(chronicleContextChecked);
            chronicleContext = r.scrubbedText;
            chronicleReversibleMap.addAll(r.reversibleMap);
          }
          final chronicleMiniContextChecked = chronicleMiniContext;
          if (chronicleMiniContextChecked != null && chronicleMiniContextChecked.isNotEmpty) {
            final r = chroniclePrism.scrub(chronicleMiniContextChecked);
            chronicleMiniContext = r.scrubbedText;
            chronicleReversibleMap.addAll(r.reversibleMap);
          }
          
          // Build base context with current entry explicitly labeled as TODAY
          // Only build if using raw mode or hybrid mode
          String? baseContext;
          if (promptMode == LumaraPromptMode.rawBacked || promptMode == LumaraPromptMode.hybrid) {
            final baseContextParts = <String>[];

            // Layer 0 date-range retrieval (e.g. "Show me February 3-9") when plan requests it
            if (userId != null &&
                _layer0Repo != null &&
                queryPlan != null &&
                queryPlan.layer0DateRange != null) {
              try {
                final range = queryPlan.layer0DateRange!;
                final layer0Entries = await _layer0Repo!.getEntriesInRange(
                  userId!,
                  range.start,
                  range.end,
                );
                if (layer0Entries.isNotEmpty) {
                  baseContextParts.add('**ENTRIES FOR REQUESTED DATE RANGE (CHRONICLE Layer 0):**');
                  baseContextParts.add(
                    'The following entries fall within the requested period (${range.start.toIso8601String().split('T')[0]} to ${range.end.toIso8601String().split('T')[0]}). Use these to answer specific recall questions.'
                  );
                  baseContextParts.add('');
                  for (final e in layer0Entries) {
                    final dateStr = '${e.timestamp.year}-${e.timestamp.month.toString().padLeft(2, '0')}-${e.timestamp.day.toString().padLeft(2, '0')}';
                    baseContextParts.add('$dateStr | entry_id: ${e.entryId}');
                    baseContextParts.add(e.content);
                    baseContextParts.add('');
                  }
                  baseContextParts.add('---');
                  baseContextParts.add('');
                  print('✅ EnhancedLumaraApi: Layer 0 date-range context added (${layer0Entries.length} entries)');
                }
              } catch (e) {
                print('⚠️ EnhancedLumaraApi: Layer 0 date-range retrieval failed (non-fatal): $e');
              }
            }

            baseContextParts.addAll(contextParts);
            baseContextParts.add('');
            baseContextParts.add('**CURRENT ENTRY (PRIMARY FOCUS - WRITTEN TODAY, $todayDateStr)**: ${request.userText}');
            baseContextParts.add('');
            baseContextParts.add('**HISTORICAL CONTEXT (Use for pattern recognition with dated examples)**:');
            baseContextParts.add('**NOTE**: The journal entries listed below (with "-" bullets) are PAST entries from your journal history. The CURRENT ENTRY above (marked "PRIMARY FOCUS - WRITTEN TODAY") is being written TODAY ($todayDateStr) and is NOT a past entry.');
            // Use ARC from orchestrator when present, else context selector entries
            if (entryContentsFromArc != null) {
              baseContextParts.addAll(entryContentsFromArc.map((s) => '- $s'));
            } else {
              baseContextParts.addAll(recentJournalEntries.map((e) => '- ${e.content}'));
            }
            
            baseContext = baseContextParts.join('\n\n');
            
            // Add supporting entries if drill-down needed
            if (promptMode == LumaraPromptMode.hybrid && queryPlan != null && queryPlan.drillDown && _drillDownHandler != null) {
              try {
                // Get aggregations for drill-down
                final aggregations = <ChronicleAggregation>[];
                for (final layer in queryPlan.layers) {
                  final period = _getPeriodForLayer(layer, queryPlan.dateFilter, now);
                  if (period != null && _aggregationRepo != null) {
                    final agg = await _aggregationRepo!.loadLayer(
                      userId: userId!,
                      layer: layer,
                      period: period,
                    );
                    if (agg != null) aggregations.add(agg);
                  }
                }
                
                if (aggregations.isNotEmpty) {
                  final supportingEntries = await _drillDownHandler!.loadSupportingEntries(
                    aggregations: aggregations,
                    maxEntries: 3,
                  );
                  
                  if (supportingEntries.isNotEmpty) {
                    final supportingContext = _drillDownHandler!.formatSupportingEntries(supportingEntries);
                    baseContext = '$baseContext\n\n$supportingContext';
                  }
                }
              } catch (e) {
                print('⚠️ EnhancedLumaraApi: Drill-down failed (non-fatal): $e');
              }
            }
          }

          // LUMARA CHRONICLE: load inferred patterns, causal chains, relationships, user-approved insights for inference
          String? lumaraChronicleContext;
          if (userId != null && userId.isNotEmpty) {
            try {
              lumaraChronicleContext = await _buildLumaraChronicleContext(userId);
              if (lumaraChronicleContext != null && lumaraChronicleContext.isNotEmpty) {
                print('✅ EnhancedLumaraApi: LUMARA CHRONICLE context loaded for inference');
              }
            } catch (e) {
              print('⚠️ EnhancedLumaraApi: LUMARA CHRONICLE context failed (non-fatal): $e');
            }
          }
          
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
          
          // Note: prismActivity is no longer used in simplified system
          // Historical context is built directly in user prompt
          
          // ═══════════════════════════════════════════════════════════
          // STEP 1: CHECK SENTINEL FOR CRISIS (HIGHEST PRIORITY)
          // ═══════════════════════════════════════════════════════════
          
          print('═══════════════════════════════════════════════════════════');
          print('🚀 LUMARA V23 Generation Starting');
          print('═══════════════════════════════════════════════════════════');
          
          String selectedPersona;
          bool safetyOverride = false;
          SentinelScore? sentinelScore;
          
          // Voice mode: skip crisis/Sentinel (Firestore) to reduce latency; use user-selected persona
          if (skipHeavyProcessing) {
            selectedPersona = _getPersonaFromConversationMode(request.options.conversationMode);
            print('🎯 USER-SELECTED PERSONA: $selectedPersona (voice mode - skipped crisis/Sentinel check)');
          } else if (userId != null) {
            // Check if already in crisis mode (within cooldown period)
            final alreadyInCrisis = await CrisisMode.isInCrisisMode(userId);
            
            // Calculate SENTINEL score with temporal clustering
            sentinelScore = await SentinelAnalyzer.calculateSentinelScore(
              userId: userId,
              currentEntryText: request.userText,
            );
            
            if (alreadyInCrisis || sentinelScore.alert) {
              // SAFETY OVERRIDE: Force Therapist mode regardless of user selection
              selectedPersona = 'therapist';
              safetyOverride = true;
              
              // Activate crisis mode if not already active
              if (!alreadyInCrisis && sentinelScore.alert) {
                await CrisisMode.activateCrisisMode(
                  userId: userId,
                  sentinelScore: sentinelScore,
                );
              }
              
              print('🚨 SAFETY OVERRIDE ACTIVE');
              print('   Already in crisis mode: $alreadyInCrisis');
              print('   Sentinel score: ${sentinelScore.score.toStringAsFixed(2)}');
              print('   Reason: ${sentinelScore.reason}');
              print('   → FORCING THERAPIST MODE');
              
              _analytics.logLumaraEvent('safety_override_triggered', data: {
                'sentinel_score': sentinelScore.score,
                'already_in_crisis': alreadyInCrisis,
                'reason': sentinelScore.reason,
                'original_mode': request.options.conversationMode?.name,
                'trigger_count': sentinelScore.triggerEntries.length,
                'timespan_days': sentinelScore.timespan.inDays,
              });
            } else {
              // NORMAL MODE: Respect user selection
              selectedPersona = _getPersonaFromConversationMode(
                request.options.conversationMode,
              );
              
              print('🎯 USER-SELECTED PERSONA: $selectedPersona');
              print('   Mode: ${request.options.conversationMode?.name ?? "default (companion)"}');
              print('   Sentinel score: ${sentinelScore.score.toStringAsFixed(2)} (below threshold)');
            }
          } else {
            // No user ID, default to Companion
            selectedPersona = _getPersonaFromConversationMode(
              request.options.conversationMode,
            );
            
            print('🎯 USER-SELECTED PERSONA: $selectedPersona (no Sentinel check - no userId)');
          }
          
          // ═══════════════════════════════════════════════════════════
          // STEP 2: SET RESPONSE PARAMETERS BASED ON PERSONA + ENGAGEMENT MODE
          // ═══════════════════════════════════════════════════════════
          
          // For voice mode (skipHeavyProcessing), use voice-specific word limits
          // Detect if this is voice mode by checking if chatContext contains voice mode instructions
          final isVoiceMode = skipHeavyProcessing && 
              chatContext != null &&
              chatContext.contains('VOICE MODE');
          
          // Voice mode: pass conversationMode null so we don't use think/ideas length override
          final responseParams = _getResponseParameters(
            selectedPersona, 
            safetyOverride,
            engagementMode: engagementMode,
            conversationMode: skipHeavyProcessing ? null : request.options.conversationMode,
            isVoiceMode: isVoiceMode,
            entryType: entryType,
          );
          
          print('');
          print('📊 RESPONSE PARAMETERS:');
          print('   Persona: $selectedPersona');
          print('   Engagement Mode: ${engagementMode != null ? engagementMode.name : "reflect"}');
          print('   Safety Override: $safetyOverride');
          print('   Target Words: ${responseParams.targetWords}');
          print('   Target Sentences: ${responseParams.targetSentences}');
          print('   Max Words (buffer): ${responseParams.maxWords}');
          print('   Pattern Examples: ${responseParams.minPatternExamples}-${responseParams.maxPatternExamples}');
          print('   Structured Format: ${responseParams.useStructuredFormat}');
          print('');
          
          // Use response parameters for control state
          final maxWords = responseParams.maxWords;
          final targetWords = responseParams.targetWords;
          final targetSentences = responseParams.targetSentences;
          final minPatternExamples = responseParams.minPatternExamples;
          final maxPatternExamples = responseParams.maxPatternExamples;
          final isPersonalContent = entryType == EntryType.reflective || entryType == EntryType.analytical;
          final useStructuredFormat = responseParams.useStructuredFormat;
          final entryClassification = entryType.toString().split('.').last;
          final effectivePersona = selectedPersona;
          final isWrittenUnlimited = maxWords >= _writtenUnlimitedMaxWords;
          
          // Build simplified control state for master prompt
          final simplifiedControlState = {
            'persona': {
              'effective': selectedPersona,
              'isAuto': false,
              'safetyOverride': safetyOverride,
            },
            'responseMode': {
              'targetWords': targetWords,
              'targetSentences': targetSentences,
              'maxWords': maxWords,
              'minPatternExamples': minPatternExamples,
              'maxPatternExamples': maxPatternExamples,
              'useStructuredFormat': useStructuredFormat,
              'isPersonalContent': isPersonalContent,
              'lengthGuidance': responseParams.lengthGuidance,
              if (isWrittenUnlimited) 'noWordLimit': true,
            },
            'engagement': {
              'mode': engagementMode != null ? engagementMode.name : 'reflect',
            },
            'entryClassification': entryClassification,
            'sentinel': sentinelScore != null ? {
              'score': sentinelScore.score,
              'alert': sentinelScore.alert,
              'reason': sentinelScore.reason,
            } : null,
            if (isWrittenUnlimited) 'responseLength': {
              'auto': true,
              'max_sentences': -1,
              'sentences_per_paragraph': 4,
            },
          };
          
          final simplifiedControlStateJson = jsonEncode(simplifiedControlState);
          
          // Get mode-specific instructions
          String modeSpecificInstructions = _getModeSpecificInstructions(
            conversationMode: request.options.conversationMode,
            regenerate: request.options.regenerate,
            toneMode: request.options.toneMode,
            preferQuestionExpansion: request.options.preferQuestionExpansion,
          );
          
          // If chatContext is provided (e.g., from voice mode), PREPEND it to mode-specific instructions
          // This ensures voice mode instructions are seen first and take priority
          if (chatContext != null && chatContext.isNotEmpty) {
            if (modeSpecificInstructions.isNotEmpty) {
              modeSpecificInstructions = '$chatContext\n\n═══════════════════════════════════════════════════════════\n\n$modeSpecificInstructions';
            } else {
              modeSpecificInstructions = chatContext;
            }
          }
          // Prepend ATLAS (phase) and AURORA (rhythm) context from orchestrator when present
          if ((atlasContext != null && atlasContext.isNotEmpty) || (auroraContext != null && auroraContext.isNotEmpty)) {
            final parts = <String>[];
            if (atlasContext != null && atlasContext.isNotEmpty) {
              parts.add('ATLAS (developmental phase): $atlasContext');
            }
            if (auroraContext != null && auroraContext.isNotEmpty) {
              parts.add('AURORA (rhythm/regulation): $auroraContext');
            }
            if (parts.isNotEmpty) {
              final enterpriseBlock = 'SUBSYSTEM CONTEXT (use to tailor response):\n${parts.join('\n')}';
              modeSpecificInstructions = modeSpecificInstructions.isEmpty
                  ? enterpriseBlock
                  : '$enterpriseBlock\n\n═══════════════════════════════════════════════════════════\n\n$modeSpecificInstructions';
            }
          }

          // Real-time pushback: if user message looks like a claim, check against CHRONICLE and inject truth_check context
          if (!skipHeavyProcessing && userId != null && _layer0Repo != null) {
            final checker = ChronicleContradictionChecker(layer0: _layer0Repo!);
            if (checker.detectsUserClaim(request.userText)) {
              final contradiction = await checker.checkAgainstChronicle(
                claim: request.userText,
                userId: userId,
              );
              if (contradiction != null) {
                final truthCheckBlock = contradiction.toTruthCheckBlock(request.userText);
                modeSpecificInstructions = modeSpecificInstructions.isEmpty
                    ? truthCheckBlock
                    : '$truthCheckBlock\n\n═══════════════════════════════════════════════════════════\n\n$modeSpecificInstructions';
                print('🔵 LUMARA V23: Injected truth_check pushback context (CHRONICLE contradicts user claim)');
              }
            }
          }
          
          // Get unified master prompt or voice-only trimmed prompt (use ARC data when from orchestrator)
          final recentEntries = recentEntriesFromArc ??
              recentJournalEntries
                  .map((entry) {
                    final daysAgo = now.difference(entry.createdAt).inDays;
                    final relativeDate = daysAgo == 0
                        ? 'today'
                        : daysAgo == 1
                            ? 'yesterday'
                            : '$daysAgo days ago';
                    return {
                      'date': entry.createdAt,
                      'relativeDate': relativeDate,
                      'daysAgo': daysAgo,
                      'title': entry.content.split('\n').first.trim().isEmpty
                          ? 'Untitled entry'
                          : entry.content.split('\n').first.trim(),
                      'id': entry.id,
                    };
                  })
                  .toList();
          
          String systemPrompt;
          String userPromptForApi = ''; // Voice (split payload) sets this; non-voice keeps empty
          if (skipHeavyProcessing) {
            // Voice mode: split payload for lower latency — short system + user = context + transcript
            const int voiceModeInstructionsMaxChars = 2500;
            String voiceModeInstructions = modeSpecificInstructions.isNotEmpty ? modeSpecificInstructions : '';
            if (voiceModeInstructions.length > voiceModeInstructionsMaxChars) {
              voiceModeInstructions = '${voiceModeInstructions.substring(0, voiceModeInstructionsMaxChars)}\n\n[instructions truncated for latency]';
              print('🔵 LUMARA V23: Voice mode instructions truncated to $voiceModeInstructionsMaxChars chars (was ${modeSpecificInstructions.length})');
            }
            final effectiveVoiceMode = voiceEngagementModeOverride ?? engagementMode ?? EngagementMode.reflect;
            final maxChars = VoiceResponseConfig.getVoicePromptMaxChars(effectiveVoiceMode);
            // System: short static instructions only (control state, word limit, crisis, PRISM, VOICE)
            systemPrompt = LumaraMasterPrompt.getVoicePromptSystemOnly(simplifiedControlStateJson);
            systemPrompt = LumaraMasterPrompt.injectDateContext(
              systemPrompt,
              recentEntries: null,
              currentDate: now,
            );
            // User: turn-specific context (mode instructions + chronicle + LUMARA CHRONICLE + transcript)
            String userMessage = LumaraMasterPrompt.buildVoiceUserMessage(
              entryText: request.userText,
              modeSpecificInstructions: voiceModeInstructions.isNotEmpty ? voiceModeInstructions : null,
              chronicleMiniContext: chronicleMiniContext,
              lumaraChronicleContext: lumaraChronicleContext,
            );
            // Cap combined size so system + user stay under maxChars
            final maxUserChars = (maxChars - systemPrompt.length).clamp(100, maxChars);
            if (userMessage.length > maxUserChars) {
              userMessage = '${userMessage.substring(0, maxUserChars)}\n\n[context truncated for latency]';
              print('🔵 LUMARA V23: Voice user message truncated to $maxUserChars chars (mode: ${effectiveVoiceMode.name})');
            }
            print('🔵 LUMARA V23: Voice split payload: system=${systemPrompt.length} chars, user=${userMessage.length} chars (cap: $maxChars)');
            if (chronicleMiniContext != null) {
              print('🔵 LUMARA V23: CHRONICLE mini-context included in user message');
            }
            userPromptForApi = userMessage;
          } else {
            // Non-voice: split payload for lower latency — short system + user = context + entry
            systemPrompt = LumaraMasterPrompt.getMasterPromptSystemOnly(simplifiedControlStateJson, now);
            userPromptForApi = LumaraMasterPrompt.buildMasterUserMessage(
              entryText: request.userText,
              recentEntries: recentEntries,
              baseContext: baseContext,
              chronicleContext: chronicleContext,
              chronicleLayers: chronicleLayerNames,
              lumaraChronicleContext: lumaraChronicleContext,
              mode: promptMode,
              currentDate: now,
              modeSpecificInstructions: modeSpecificInstructions.isNotEmpty ? modeSpecificInstructions : null,
            );
            print('🔵 LUMARA V23: Non-voice split payload: system=${systemPrompt.length} chars, user=${userPromptForApi.length} chars');
            if (chronicleContext != null) {
              print('🔵 LUMARA V23: CHRONICLE context included in user message (${chronicleLayerNames?.join(', ') ?? 'unknown layers'})');
            }
          }
          
          print('🔵 LUMARA V23: Unified prompt length: ${systemPrompt.length}');
          print('🔵 LUMARA V23: Persona=$selectedPersona, maxWords=$maxWords, patternExamples=$minPatternExamples-$maxPatternExamples');
          if (safetyOverride) {
            print('🚨 LUMARA V23: SAFETY OVERRIDE ACTIVE - Therapist mode forced');
          }
          
          onProgress?.call('Calling cloud API...');

          // Primary: Groq (Llama 3.3 70B → Mixtral fallback). Fallback: Gemini API.
          String? geminiResponse;
          int retryCount = 0;
          const maxRetries = 2;
          final useGroq = _groq != null;
          final temperature = _temperatureForMode(engagementMode);

          while (retryCount <= maxRetries && geminiResponse == null) {
            try {
              if (useGroq) {
                try {
                  // Try Groq first (Llama 3.3 70B → Mixtral backup)
                  if (onStreamChunk != null) {
                    final buffer = StringBuffer();
                    await for (final chunk in _groq!.generateContentStream(
                      prompt: userPromptForApi,
                      systemPrompt: systemPrompt,
                      model: GroqModel.llama33_70b,
                      temperature: temperature,
                    )) {
                      buffer.write(chunk);
                      onStreamChunk(chunk);
                    }
                    geminiResponse = buffer.toString();
                  } else {
                    geminiResponse = await _groq!.generateContent(
                      prompt: userPromptForApi,
                      systemPrompt: systemPrompt,
                      model: GroqModel.llama33_70b,
                      temperature: temperature,
                      fallbackToMixtral: true,
                    );
                  }
                  if (geminiResponse != null && geminiResponse.isNotEmpty) {
                    print('LUMARA: Groq API response received (length: ${geminiResponse.length})');
                    break;
                  }
                } catch (groqErr) {
                  print('LUMARA: Groq failed, falling back to Gemini: $groqErr');
                }
              }
              // Fallback to Gemini (when Groq not configured or Groq failed)
              if (geminiResponse == null || geminiResponse.isEmpty) {
                if (useGroq) {
                  print('LUMARA: Groq failed, falling back to Gemini');
                }
                if (onStreamChunk != null) {
                  try {
                    final buffer = StringBuffer();
                    await for (final chunk in geminiSendStream(
                      system: systemPrompt,
                      user: userPromptForApi,
                    )) {
                      buffer.write(chunk);
                      onStreamChunk(chunk);
                    }
                    geminiResponse = buffer.toString();
                  } catch (streamErr) {
                    print('LUMARA: Gemini stream not available ($streamErr), using non-streaming');
                    geminiResponse = await geminiSend(
                      system: systemPrompt,
                      user: userPromptForApi,
                      jsonExpected: false,
                      entryId: entryId,
                      intent: 'journal_reflection',
                      skipTransformation: true,
                    );
                    onStreamChunk(geminiResponse);
                  }
                } else {
                  geminiResponse = await geminiSend(
                    system: systemPrompt,
                    user: userPromptForApi,
                    jsonExpected: false,
                    entryId: entryId,
                    intent: 'journal_reflection',
                    skipTransformation: true,
                  );
                }
                print('LUMARA: Gemini API response received (length: ${geminiResponse.length})');
              }
              onProgress?.call('Processing response...');
              break;
            } catch (e) {
              retryCount++;
              if (retryCount > maxRetries) {
                print('LUMARA: Cloud API error after $maxRetries retries: $e');
                rethrow;
              }
              if (!e.toString().contains('503') &&
                  !e.toString().contains('overloaded') &&
                  !e.toString().contains('UNAVAILABLE')) {
                print('LUMARA: Cloud API error (non-retryable): $e');
                rethrow;
              }
              onProgress?.call('Retrying API... ($retryCount/$maxRetries)');
              await Future.delayed(const Duration(seconds: 2));
            }
          }

          if (geminiResponse == null) {
            throw Exception('Failed to generate response from cloud API (Groq/Gemini)');
          }

          // Restore PII in response when CHRONICLE context was scrubbed before send
          if (chronicleReversibleMap.isNotEmpty) {
            geminiResponse = chroniclePrism.restore(geminiResponse, chronicleReversibleMap);
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
          
          var scoredResponse = geminiResponse;
          
          // Validate and enforce word limit BEFORE scoring
          final words = scoredResponse.trim().split(RegExp(r'\s+'));
          final wordCount = words.length;
          
          print('📊 Initial word count: $wordCount words (limit: $maxWords)');
          
          // Always truncate if over limit (not just if > limit + 50)
          // This ensures responses never exceed the limit, preventing mid-sentence cuts
          if (wordCount > maxWords) {
            print('⚠️ WARNING: Response exceeds word limit by ${wordCount - maxWords} words');
            
            // Truncate to word limit, but stop at sentence boundaries
            final truncated = _truncateAtSentenceBoundary(scoredResponse, maxWords);
            scoredResponse = truncated;
            
            final newWordCount = scoredResponse.split(RegExp(r'\s+')).length;
            print('✂️ Truncated response to $newWordCount words (stopped at sentence boundary)');
          }
          
          // Create scoring input with potentially truncated response
          final scoringInput = scoring.ScoringInput(
            userText: request.userText,
            candidate: scoredResponse, // Use truncated response if it was truncated
            phaseHint: _convertToScoringPhaseHint(currentPhase),
            entryType: _convertToScoringEntryType(request.entryType.name),
            priorKeywords: priorKeywords,
            matchedNodeHints: matchedHints,
          );
          
          final breakdown = scoring.LumaraResponseScoring.scoreLumaraResponse(scoringInput);
          
          print('🌼 LUMARA Response Scoring v2.3: resonance=${breakdown.resonance.toStringAsFixed(2)}, empathy=${breakdown.empathy.toStringAsFixed(2)}, depth=${breakdown.depth.toStringAsFixed(2)}, agency=${breakdown.agency.toStringAsFixed(2)}');
          
          // If below threshold, auto-fix
          if (breakdown.resonance < scoring.minResonance) {
            print('🌼 Auto-fixing response below threshold (${breakdown.resonance.toStringAsFixed(2)})');
            scoredResponse = scoring.LumaraResponseScoring.autoTightenToEcho(scoredResponse);
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
          
          // Validate pattern examples for Companion mode
          if (effectivePersona == 'companion' && isPersonalContent) {
            final datePatterns = [
              RegExp(r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}\b', caseSensitive: false),
              RegExp(r'\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}\b', caseSensitive: false),
              RegExp(r'\bin (January|February|March|April|May|June|July|August|September|October|November|December)\b', caseSensitive: false),
              RegExp(r'\b(in|on|during|since|from)\s+(January|February|March|April|May|June|July|August|September|October|November|December)\b', caseSensitive: false),
              RegExp(r'\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{4}\b', caseSensitive: false),
              RegExp(r'\b\d{1,2}\s+(January|February|March|April|May|June|July|August|September|October|November|December)\b', caseSensitive: false),
            ];
            
            int dateCount = 0;
            for (final pattern in datePatterns) {
              dateCount += pattern.allMatches(scoredResponse).length;
            }
            
            if (dateCount < minPatternExamples) {
              print('⚠️ WARNING: Insufficient dated examples ($dateCount found, $minPatternExamples required)');
            } else {
              print('✅ Pattern examples: $dateCount dated examples found');
            }
            
            // Check for strategic buzzwords
            final buzzwords = [
              'strategic vision',
              'strategic positioning',
              'strategic considerations',
              'strategic planning',
              'market positioning',
              'epi architecture',
              'ppi principles',
              'fundamental',
              'integral steps',
              'manifesting',
            ];
            
            int buzzwordCount = 0;
            final lowerResponse = scoredResponse.toLowerCase();
            for (final word in buzzwords) {
              if (lowerResponse.contains(word)) {
                buzzwordCount++;
                print('⚠️ Strategic buzzword detected: "$word"');
              }
            }
            
            if (buzzwordCount > 0) {
              print('⚠️ WARNING: $buzzwordCount strategic buzzwords in personal reflection');
            }
          }
          
          // Don't add hardcoded header - LLM should follow persona instructions
          // Companion and Therapist use ✨ Reflection
          // Strategist uses ✨ Analysis  
          // Challenger uses no header
          final formatted = scoredResponse.trim();
          
          print('📊 Final word count: ${formatted.split(RegExp(r'\s+')).length} words');
          
          // Validate response
          _validateResponse(
            response: formatted,
            persona: selectedPersona,
            responseParams: responseParams,
          );
          
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
            
            // Get current phase from request phase hint
            final currentPhaseFromControlState = request.phaseHint?.name.toLowerCase();
            
            // Try to extract entry ID from request if available, otherwise use a generated ID
            String entryId = 'current_entry';
            // Check if userText contains an entry ID pattern or if we can infer it
            // For now, use a generic ID since we don't have direct access to entry ID
            final currentEntryTrace = _attributionService.createTrace(
              nodeRef: entryId,
              relation: 'primary_source',
              confidence: 1.0,
              reasoning: 'Current journal entry - primary source for reflection',
              phaseContext: currentPhaseFromControlState, // Use current phase from control state, not entry's stored phase
              excerpt: currentEntryExcerpt,
            );
            attributionTraces.add(currentEntryTrace);
            print('LUMARA Enhanced API v2.3: Created attribution trace for current entry with phase: $currentPhaseFromControlState');
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
          
          print('═══════════════════════════════════════════════════════════');
          print('✨ LUMARA V23 Generation Complete');
          print('═══════════════════════════════════════════════════════════');
          
          return ReflectionResult(
            reflection: formatted,
            attributionTraces: attributionTraces,
            persona: selectedPersona,
            safetyOverride: safetyOverride,
            sentinelScore: sentinelScore?.score,
          );
      } catch (e) {
        print('LUMARA Enhanced API: ✗ Error calling cloud AI: $e');
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

  /// Build a concise LUMARA CHRONICLE context string (patterns, causal chains, relationships, user-approved insights) for master prompt inference. Capped at ~2000 chars.
  Future<String?> _buildLumaraChronicleContext(String userId) async {
    try {
      final adapter = DualChronicleServices.chronicleQueryAdapter;
      final lumaraRepo = DualChronicleServices.lumaraChronicle;
      final annotations = await adapter.loadAnnotations(userId);
      final patterns = await lumaraRepo.loadPatterns(userId);
      final chains = await lumaraRepo.loadCausalChains(userId);
      final relationships = await lumaraRepo.loadRelationships(userId);
      final activePatterns = patterns.where((p) => p.status == InferenceStatus.active).take(10).toList();
      final activeChains = chains.where((c) => c.status == InferenceStatus.active).take(8).toList();
      final activeRels = relationships.where((r) => r.status == InferenceStatus.active).take(8).toList();
      final parts = <String>[];
      if (annotations.isNotEmpty) {
        parts.add('User-approved insights: ${annotations.take(5).map((a) => a.content.length > 80 ? "${a.content.substring(0, 80)}..." : a.content).join('; ')}');
      }
      if (activePatterns.isNotEmpty) {
        parts.add('Patterns: ${activePatterns.map((p) => p.description.length > 60 ? "${p.description.substring(0, 60)}..." : p.description).join('; ')}');
      }
      if (activeChains.isNotEmpty) {
        parts.add('Causal links: ${activeChains.map((c) => '"${c.trigger.length > 40 ? c.trigger.substring(0, 40) + "..." : c.trigger}" → "${c.response.length > 40 ? c.response.substring(0, 40) + "..." : c.response}"').join('; ')}');
      }
      if (activeRels.isNotEmpty) {
        parts.add('Relationships: ${activeRels.map((r) => '${r.entityName} (${r.role}): ${r.interactionPattern.length > 50 ? r.interactionPattern.substring(0, 50) + "..." : r.interactionPattern}').join('; ')}');
      }
      if (parts.isEmpty) return null;
      final out = parts.join('\n');
      return out.length > 2000 ? out.substring(0, 2000) : out;
    } catch (_) {
      return null;
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

  /// Get period identifier for a layer based on date filter or current period
  String? _getPeriodForLayer(ChronicleLayer layer, DateTimeRange? dateFilter, DateTime now) {
    if (dateFilter != null) {
      // Use date filter to determine period
      switch (layer) {
        case ChronicleLayer.monthly:
          return '${dateFilter.start.year}-${dateFilter.start.month.toString().padLeft(2, '0')}';
        case ChronicleLayer.yearly:
          return '${dateFilter.start.year}';
        case ChronicleLayer.multiyear:
          return '${dateFilter.start.year}-${dateFilter.end.year}';
        default:
          return null;
      }
    }

    // Default to current period
    switch (layer) {
      case ChronicleLayer.monthly:
        return '${now.year}-${now.month.toString().padLeft(2, '0')}';
      case ChronicleLayer.yearly:
        return '${now.year}';
      case ChronicleLayer.multiyear:
        // Default to last 5 years
        return '${now.year - 4}-${now.year}';
      default:
        return null;
    }
  }

  /// Fallback method to call local Gemini API when Firebase backend fails

  /// Generate a direct, factual response for simple questions
  Future<ReflectionResult> _generateFactualResponse(
    models.LumaraReflectionRequest request,
    ResponseMode responseMode,
    void Function(String message)? onProgress
  ) async {
    onProgress?.call('Generating direct answer...');

    // Create a simple, direct prompt for factual questions
    final factualPrompt = '''
You are LUMARA, providing a direct, factual answer to the user's question.

User Question: ${request.userText}

Instructions:
- Provide a clear, direct answer to the question
- Keep your response under ${responseMode.maxWords} words
- Be informative but concise
- Use a warm, helpful tone while staying focused on the facts
- Do not include reflection headers or extensive personal analysis
- Answer the question directly without turning it into a therapy session

Respond now:''';

    try {
      final response = await geminiSend(
        system: 'You are LUMARA, an AI assistant providing direct, factual answers.',
        user: factualPrompt,
        intent: 'factual_answer',
        skipTransformation: true, // Skip transformation for direct factual responses
      );

      if (response.isNotEmpty) {
        return ReflectionResult(
          reflection: response,
          attributionTraces: [], // No historical context needed for factual responses
        );
      } else {
        throw Exception('Empty response from cloud AI');
      }
    } catch (e) {
      print('Error generating factual response: $e');
      // Fallback response
      return ReflectionResult(
        reflection: "I understand you're asking about ${request.userText.split(' ').take(5).join(' ')}. I'm having trouble generating a response right now, but I'm here to help when you're ready to try again.",
        attributionTraces: [],
      );
    }
  }

  /// Generate a brief conversational response for mundane updates
  Future<ReflectionResult> _generateConversationalResponse(
    models.LumaraReflectionRequest request,
    ResponseMode responseMode,
    void Function(String message)? onProgress
  ) async {
    onProgress?.call('Generating brief acknowledgment...');

    // Create a minimal prompt for conversational acknowledgments
    final conversationalPrompt = '''
You are LUMARA, providing a brief, warm acknowledgment to the user's update.

User Update: ${request.userText}

Instructions:
- Provide a very brief, friendly acknowledgment (under ${responseMode.maxWords} words)
- Show that you heard them without over-analyzing
- Be warm and present but keep it short
- No reflection headers or extensive analysis needed
- This is just a simple life update that deserves a kind acknowledgment

Respond now:''';

    try {
      final response = await geminiSend(
        system: 'You are LUMARA, providing brief, warm acknowledgments to simple updates.',
        user: conversationalPrompt,
        intent: 'conversational_ack',
        skipTransformation: true, // Skip transformation for brief conversational responses
      );

      if (response.isNotEmpty) {
        return ReflectionResult(
          reflection: response,
          attributionTraces: [], // No historical context needed for conversational responses
        );
      } else {
        throw Exception('Empty response from cloud AI');
      }
    } catch (e) {
      print('Error generating conversational response: $e');
      // Fallback response
      return ReflectionResult(
        reflection: "Thanks for sharing that with me.",
        attributionTraces: [],
      );
    }
  }

  /// Truncate text at sentence boundary instead of mid-sentence
  String _truncateAtSentenceBoundary(String text, int maxWords) {
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length <= maxWords) return text;

    final truncated = words.take(maxWords).join(' ');
    final lastPeriod = truncated.lastIndexOf(RegExp(r'[.!?]'));

    return (lastPeriod > truncated.length * 0.7)
        ? truncated.substring(0, lastPeriod + 1).trim()
        : '${truncated.trim()}...';
  }
  
  /// Get persona from conversation mode (when NOT in emergency)
  String _getPersonaFromConversationMode(models.ConversationMode? mode) {
    if (mode == null) return 'companion';

    switch (mode) {
      case models.ConversationMode.think:
      case models.ConversationMode.nextSteps:
      case models.ConversationMode.perspective:
        return 'strategist';
      case models.ConversationMode.reflectDeeply:
        return 'therapist';
      case models.ConversationMode.ideas:
      case models.ConversationMode.continueThought:
        return 'companion';
    }
  }

  // Base response lengths by Engagement Mode (primary driver)
  // Default (reflect) = Claude-like: direct, concise. Explore/Integrate = pour out links and context.
  static final Map<EngagementMode, ResponseLengthTarget> engagementLengthTargets = {
    EngagementMode.reflect: const ResponseLengthTarget(
      sentences: 4,
      words: 120,
      description: 'Claude-like: direct, concise answer. No cross-entry dump.',
    ),
    EngagementMode.explore: const ResponseLengthTarget(
      sentences: 10,
      words: 400,
      description: 'Deeper investigation with follow-up questions and entry links',
    ),
    EngagementMode.integrate: const ResponseLengthTarget(
      sentences: 15,
      words: 500,
      description: 'Comprehensive cross-domain synthesis with full context',
    ),
  };

  // Persona modifies density/style, not length (multiplier on base)
  static const Map<String, double> personaDensityModifiers = {
    'companion': 1.0,     // Warm and conversational (neutral length)
    'strategist': 1.15,   // More analytical detail (+15%)
    'therapist': 0.9,     // More concise and clear (-10%) - Grounded persona
    'challenger': 0.85,   // Sharp and direct (-15%)
  };

  /// Written (chat/journal) text uses no length cap for Reflect, Explore, and Integrate (Claude-style).
  static const int _writtenUnlimitedMaxWords = 4096;

  /// Get response parameters based on engagement mode (primary) and persona (density modifier)
  /// Conversation modes can override engagement mode lengths for specific analysis types.
  /// Written chat and journal (non-voice) get unlimited length for Reflect, Explore, and Integrate.
  ResponseParameters _getResponseParameters(
    String persona, 
    bool safetyOverride, {
    EngagementMode? engagementMode,
    models.ConversationMode? conversationMode,
    bool isVoiceMode = false,
    EntryType? entryType,
  }) {
    // Voice mode: use VoiceResponseConfig word limits (reflect 100, explore 200, integrate 300)
    // and skip conversationMode override so we get brief responses, not think/ideas length.
    if (isVoiceMode) {
      final mode = engagementMode ?? EngagementMode.reflect;
      final maxWords = VoiceResponseConfig.getMaxWords(mode);
      final targetWords = maxWords;
      final sentences = mode == EngagementMode.reflect ? 4 : mode == EngagementMode.explore ? 6 : 8;
      return ResponseParameters(
        maxWords: maxWords,
        targetWords: targetWords,
        targetSentences: sentences,
        minPatternExamples: 0,
        maxPatternExamples: 2,
        useStructuredFormat: false,
        lengthGuidance: 'Voice mode: Stay at or under $maxWords words. Brief, conversational. No lists or markdown.',
      );
    }
    // Written text (chat or journal): no length limit for Reflect, Explore, or Integrate — Claude-style.
    if (!safetyOverride) {
      return ResponseParameters(
        maxWords: _writtenUnlimitedMaxWords,
        targetWords: _writtenUnlimitedMaxWords,
        targetSentences: 0, // 0 = no sentence cap
        minPatternExamples: 2,
        maxPatternExamples: 6,
        useStructuredFormat: false,
        lengthGuidance: 'Written conversation (chat or journal): No length limit. Respond at natural length like a full conversation assistant. Complete your thought fully. Use verbosity and engagement mode (reflect/explore/integrate) as guides for depth and style, not as caps.',
      );
    }
    if (safetyOverride) {
      // Emergency therapist mode: shorter, no examples needed
      return ResponseParameters(
        maxWords: 250, // 25% buffer on 200
        targetWords: 200,
        targetSentences: 5,
        minPatternExamples: 0,
        maxPatternExamples: 2,
        useStructuredFormat: false,
        lengthGuidance: 'Emergency mode: Brief, supportive response (~200 words, 5 sentences)',
      );
    }
    
    // Check if conversation mode overrides engagement mode length
    ResponseLengthTarget? conversationModeOverride;
    if (conversationMode != null) {
      switch (conversationMode) {
        case models.ConversationMode.ideas:
          // "Analyze" - longer than integrate (500 words, 15 sentences)
          conversationModeOverride = const ResponseLengthTarget(
            sentences: 18,
            words: 600,
            description: 'Extended analysis with practical suggestions',
          );
          break;
        case models.ConversationMode.think:
          // "Deep Analysis" - even longer than analyze
          conversationModeOverride = const ResponseLengthTarget(
            sentences: 22,
            words: 750,
            description: 'Comprehensive deep analysis with structured scaffolding',
          );
          break;
        default:
          // No override for other conversation modes
          break;
      }
    }
    
    // Use conversation mode override if available, otherwise use engagement mode
    final baseTarget = conversationModeOverride ?? engagementLengthTargets[engagementMode ?? EngagementMode.reflect]!;
    
    // Apply persona density modifier
    final personaModifier = personaDensityModifiers[persona] ?? 1.0;
    
    final targetWords = (baseTarget.words * personaModifier).round();
    final targetSentences = (baseTarget.sentences * personaModifier).round();
    final maxWords = (targetWords * 1.25).round(); // 25% buffer before truncation
    
    // Persona-specific settings (for pattern examples and format)
    int minPatternExamples;
    int maxPatternExamples;
    bool useStructuredFormat;
    
    switch (persona) {
      case 'companion':
        minPatternExamples = 2;
        maxPatternExamples = 4;
        useStructuredFormat = false;
        break;
      
      case 'strategist':
        minPatternExamples = 3;
        maxPatternExamples = 8;
        useStructuredFormat = true;
        break;
      
      case 'therapist':
        minPatternExamples = 1;
        maxPatternExamples = 3;
        useStructuredFormat = false;
        break;
      
      case 'challenger':
        minPatternExamples = 1;
        maxPatternExamples = 2;
        useStructuredFormat = false;
        break;
      
      default:
        minPatternExamples = 2;
        maxPatternExamples = 4;
        useStructuredFormat = false;
        break;
    }
    
    // Build length guidance for prompt
    String lengthGuidance;
    if (conversationModeOverride != null) {
      // Conversation mode override - use specific guidance
      lengthGuidance = '''
Target response length: $targetSentences sentences (~$targetWords words)
Context: ${baseTarget.description}

This is an extended analysis mode - provide comprehensive, detailed insights.
Stay within target length naturally. Quality over quantity.
''';
    } else {
      // Standard engagement mode guidance
      lengthGuidance = '''
Target response length: $targetSentences sentences (~$targetWords words)
Context: ${baseTarget.description}

Length guidelines by mode:
- REFLECT: Brief, surface-level observations only
- EXPLORE: Deeper investigation, include follow-up questions
- INTEGRATE: Comprehensive synthesis across domains and time

Stay within target length naturally. Quality over quantity.
''';
    }
    
    return ResponseParameters(
      maxWords: maxWords,
      targetWords: targetWords,
      targetSentences: targetSentences,
      minPatternExamples: minPatternExamples,
      maxPatternExamples: maxPatternExamples,
      useStructuredFormat: useStructuredFormat,
      lengthGuidance: lengthGuidance,
    );
  }

  /// Validate response meets requirements
  void _validateResponse({
    required String response,
    required String persona,
    required ResponseParameters responseParams,
  }) {
    final wordCount = response.split(RegExp(r'\s+')).length;
    
    print('');
    print('🔍 VALIDATION:');
    print('   Word count: $wordCount (max: ${responseParams.maxWords})');
    
    if (wordCount > responseParams.maxWords * 1.2) {
      print('   ⚠️  WARNING: Word count exceeds limit by >20%');
    }
    
    // Check for sycophancy in Companion mode
    if (persona == 'companion') {
      final sycophancyPhrases = [
        'great insight',
        'powerful realization',
        'brilliant',
        'amazing how',
        'incredible',
        'truly inspiring',
        'profound',
        'you\'re absolutely right',
        'what a',
        'such a great',
        'really important that you',
      ];
      
      final lowerResponse = response.toLowerCase();
      final foundSycophancy = <String>[];
      
      for (final phrase in sycophancyPhrases) {
        if (lowerResponse.contains(phrase)) {
          foundSycophancy.add(phrase);
        }
      }
      
      if (foundSycophancy.isNotEmpty) {
        print('   ⚠️  SYCOPHANCY DETECTED:');
        for (final phrase in foundSycophancy) {
          print('      - "$phrase"');
        }
        
        _analytics.logLumaraEvent('sycophancy_detected', data: {
          'phrases': foundSycophancy,
          'response_length': response.length,
        });
      } else {
        print('   ✅ No sycophancy detected');
      }
    }
    
    print('');
  }

  /// Build user prompt that RESPECTS control state constraints
  /// This replaces the broken prompts that were overriding master prompt constraints
  /// Get mode-specific instructions for the unified prompt
  String _getModeSpecificInstructions({
    models.ConversationMode? conversationMode,
    bool? regenerate,
    models.ToneMode? toneMode,
    bool? preferQuestionExpansion,
  }) {
    if (conversationMode != null) {
      switch (conversationMode) {
        case models.ConversationMode.ideas:
          return 'Expand with 2-3 practical suggestions drawn from past successful patterns.';
        case models.ConversationMode.think:
          return 'Generate logical scaffolding (What → Why → What now).';
        case models.ConversationMode.perspective:
          return 'Reframe using contrastive reasoning ("Another way to see this...").';
        case models.ConversationMode.nextSteps:
          return 'Provide small, phase-appropriate actions.';
        case models.ConversationMode.reflectDeeply:
          return 'Deep introspection with expanded Clarify and Highlight sections.';
        case models.ConversationMode.continueThought:
          return 'Extend previous reflection with additional insights, building naturally.';
      }
    } else if (regenerate == true) {
      return 'Rebuild reflection with different rhetorical focus.';
    } else if (toneMode == models.ToneMode.soft) {
      return 'Use gentler, slower rhythm. Add permission language.';
    } else if (preferQuestionExpansion == true) {
      return 'Expand Clarify and Highlight for richer introspection.';
    }
    
    return '';
  }
}

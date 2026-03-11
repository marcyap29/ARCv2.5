/// LUMARA Control State Builder
/// 
/// Builds the unified control state JSON that governs all LUMARA behavior.
/// Combines signals from ATLAS, VEIL, FAVORITES, PRISM, and THERAPY MODE.
library;

import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/prism/atlas/rivet/rivet_storage.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart';
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:my_app/arc/chat/services/lumara_reflection_settings_service.dart';
// Health & Readiness disabled - no health data access
// import 'package:my_app/services/health_data_service.dart';
import 'package:my_app/services/lumara/entry_classifier.dart';
import 'package:my_app/services/lumara/user_intent.dart';
import 'package:my_app/prism/atlas/phase/phase_history_repository.dart';
import 'package:my_app/chronicle/storage/chronicle_index_storage.dart';
import 'package:my_app/chronicle/models/chronicle_index.dart';

class LumaraControlStateBuilder {
  /// Build the unified control state JSON
  /// 
  /// This combines all behavioral signals into a single JSON structure
  /// that the master prompt uses to govern LUMARA's behavior.
  /// Written chat/journal use no length cap (Reflect, Explore, Integrate) — same as API.
  static const int writtenUnlimitedMaxWords = 4096;

  static Future<String> buildControlState({
    String? userId,
    Map<String, dynamic>? prismActivity,
    Map<String, dynamic>? chronoContext,
    String? userMessage, // NEW: User message for question intent detection
    int? maxWords, // NEW: Word limit from response mode
    UserIntent? userIntent, // NEW: User intent from conversation mode/button (from services/lumara/user_intent.dart)
    bool isVoiceMode = false, // NEW: Flag for voice mode (applies length multiplier)
    bool isWrittenConversation = false, // NEW: Written chat or journal → no length limit (Reflect/Explore/Integrate)
  }) async {
    final state = <String, dynamic>{};
    
    // ============================================================
    // A. ATLAS (Readiness + Safety Sentinel)
    // ============================================================
    final atlas = <String, dynamic>{};
    
    // Get current phase
    String currentPhase = 'Discovery';
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      
      final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
      if (currentRegime != null) {
        currentPhase = currentRegime.label.toString().split('.').last;
        currentPhase = currentPhase[0].toUpperCase() + currentPhase.substring(1);
      } else {
        currentPhase = await UserPhaseService.getCurrentPhase();
      }
    } catch (e) {
      print('LUMARA Control State: Error getting phase, using default: $e');
      currentPhase = await UserPhaseService.getCurrentPhase();
    }
    
    atlas['phase'] = currentPhase;
    
    // Get readiness score from RIVET
    double readinessScore = 50.0; // Default middle value
    bool sentinelAlert = false;
    
    try {
      if (!Hive.isBoxOpen(RivetBox.boxName)) {
        await Hive.openBox(RivetBox.boxName);
      }
      
      final rivetBox = Hive.box(RivetBox.boxName);
      final rivetStateData = rivetBox.get(userId ?? 'default');
      
      if (rivetStateData != null) {
        final rivetState = RivetState.fromJson(
          rivetStateData is Map<String, dynamic>
              ? rivetStateData
              : Map<String, dynamic>.from(rivetStateData as Map),
        );
        
        // Calculate readiness score from ALIGN and TRACE (0-100 scale)
        // Both need to be >= 0.6 for readiness, so readiness is average of both normalized to 100
        final alignNormalized = (rivetState.align * 100).clamp(0.0, 100.0);
        final traceNormalized = (rivetState.trace * 100).clamp(0.0, 100.0);
        readinessScore = ((alignNormalized + traceNormalized) / 2).roundToDouble();
      }
      
      // Check Sentinel state
      if (!Hive.isBoxOpen('sentinel_states')) {
        await Hive.openBox('sentinel_states');
      }
      
      final sentinelBox = Hive.box('sentinel_states');
      final sentinelData = sentinelBox.get(userId ?? 'default');
      
      if (sentinelData != null) {
        final sentinelState = sentinelData is Map<String, dynamic>
            ? sentinelData
            : Map<String, dynamic>.from(sentinelData as Map);
        
        final sentinelStateValue = sentinelState['state'] as String? ?? 'ok';
        sentinelAlert = sentinelStateValue == 'alert' || sentinelStateValue == 'watch';
      }
    } catch (e) {
      print('LUMARA Control State: Error getting ATLAS data: $e');
    }
    
    atlas['readinessScore'] = readinessScore.round();
    atlas['sentinelAlert'] = sentinelAlert;
    
    state['atlas'] = atlas;
    
    // ============================================================
    // B. VEIL (Tone Regulator + Rhythm Intelligence)
    // ============================================================
    final veil = <String, dynamic>{};
    
    // Get sophistication level (default to moderate)
    veil['sophisticationLevel'] = 'moderate'; // simple | moderate | analytical
    
    // Get recent activity (default to moderate)
    veil['recentActivity'] = 'moderate'; // low | moderate | high
    
    // Get time of day and usage pattern from chrono context or AURORA
    String timeOfDay = 'afternoon';
    String usagePattern = 'sporadic';
    
    if (chronoContext != null) {
      timeOfDay = chronoContext['window'] as String? ?? 'afternoon';
      usagePattern = chronoContext['chronotype'] as String? ?? 'sporadic';
    } else {
      // Infer from current time
      final hour = DateTime.now().hour;
      if (hour >= 5 && hour < 12) {
        timeOfDay = 'morning';
      } else if (hour >= 12 && hour < 17) {
        timeOfDay = 'afternoon';
      } else if (hour >= 17 && hour < 22) {
        timeOfDay = 'evening';
      } else {
        timeOfDay = 'night';
      }
    }
    
    veil['timeOfDay'] = timeOfDay;
    veil['usagePattern'] = usagePattern;
    
    // Health signals - use defaults only (health/readiness tabs removed; no HealthDataService access)
    final health = <String, dynamic>{
      'sleepQuality': 0.7, // 0-1, default to moderate
      'energyLevel': 0.7, // 0-1, default to moderate
      'medicationStatus': null, // Optional flag
    };
    // try {
    //   final healthService = HealthDataService.instance;
    //   final healthData = await healthService.getEffectiveHealthData();
    //   health['sleepQuality'] = healthData.sleepQuality;
    //   health['energyLevel'] = healthData.energyLevel;
    //   health['medicationStatus'] = healthData.medicationStatus;
    // } catch (e) { ... }
    veil['health'] = health;
    
    state['veil'] = veil;
    
    // ============================================================
    // C. FAVORITES (Top 40 Reinforced Signature)
    // ============================================================
    final favorites = <String, dynamic>{};
    
    try {
      final favoritesService = FavoritesService.instance;
      await favoritesService.initialize();
      final allFavorites = await favoritesService.getAllFavorites();
      
      if (allFavorites.isNotEmpty) {
        // Analyze favorites to extract profile
        // For now, use defaults - in future could analyze content for patterns
        favorites['favoritesProfile'] = {
          'directness': 0.5, // 0-1, default moderate
          'warmth': 0.6, // 0-1, default slightly warm
          'rigor': 0.5, // 0-1, default moderate
          'stepwise': 0.4, // 0-1, default moderate
          'systemsThinking': 0.5, // 0-1, default moderate
        };
        
        favorites['count'] = allFavorites.length;
      } else {
        favorites['favoritesProfile'] = null;
        favorites['count'] = 0;
      }
    } catch (e) {
      print('LUMARA Control State: Error getting favorites: $e');
      favorites['favoritesProfile'] = null;
      favorites['count'] = 0;
    }
    
    state['favorites'] = favorites;
    
    // ============================================================
    // D. PRISM (Multimodal Cognitive Context)
    // ============================================================
    final prism = <String, dynamic>{};
    
    // Start with provided PRISM activity or default
    Map<String, dynamic> finalPrismActivity;
    if (prismActivity != null) {
      finalPrismActivity = Map<String, dynamic>.from(prismActivity);
    } else {
      finalPrismActivity = {
        'journal_entries': [],
        'drafts': [],
        'chats': [],
        'media': [],
        'patterns': [],
        'emotional_tone': 'neutral',
        'cognitive_load': 'moderate',
      };
    }
    
    // Add saved chats and favorite journal entries with higher weight
    try {
      final favoritesService = FavoritesService.instance;
      await favoritesService.initialize();
      
      // Get saved chats and add to PRISM activity (with higher priority)
      final savedChats = await favoritesService.getSavedChats();
      if (savedChats.isNotEmpty) {
        final savedChatContents = savedChats.map((fav) => fav.content).toList();
        // Prepend saved chats to regular chats for higher weight
        final existingChats = finalPrismActivity['chats'] as List<dynamic>? ?? [];
        finalPrismActivity['chats'] = [...savedChatContents, ...existingChats];
      }
      
      // Get favorite journal entries and add to PRISM activity (with higher priority)
      final favoriteEntries = await favoritesService.getFavoriteJournalEntries();
      if (favoriteEntries.isNotEmpty) {
        final favoriteEntryContents = favoriteEntries.map((fav) => fav.content).toList();
        // Prepend favorite entries to regular entries for higher weight
        final existingEntries = finalPrismActivity['journal_entries'] as List<dynamic>? ?? [];
        finalPrismActivity['journal_entries'] = [...favoriteEntryContents, ...existingEntries];
      }
    } catch (e) {
      print('LUMARA Control State: Error adding favorites to PRISM activity: $e');
      // Continue without favorites if there's an error
    }
    
    prism['prism_activity'] = finalPrismActivity;
    state['prism'] = prism;
    
    // ============================================================
    // E. THERAPY MODE (fixed: off; sentinel can override to supportive)
    // ============================================================
    final therapy = <String, dynamic>{
      'therapyMode': sentinelAlert ? 'supportive' : 'off',
    };
    state['therapy'] = therapy;

    // ============================================================
    // F. PERSONA (fixed: companion — LUMARA Persona setting removed)
    // ============================================================
    final persona = <String, dynamic>{
      'selected': 'companion',
      'effective': 'companion',
      'isAuto': false,
    };
    if (userMessage != null && userMessage.trim().isNotEmpty) {
      try {
        final entryType = EntryClassifier.classify(userMessage);
        state['entryClassification'] = entryType.toString().split('.').last;
      } catch (e) {
        state['entryClassification'] = 'reflective';
      }
    } else {
      state['entryClassification'] = 'reflective';
    }
    state['persona'] = persona;

    // ============================================================
    // F2. QUESTION TYPE (Factual vs Reflective)
    // ============================================================
    final questionType = <String, dynamic>{};

    try {
      // Detect if this is a simple factual question
      bool isSimpleFactualQuestion = false;

      if (userMessage != null && userMessage.trim().isNotEmpty) {
        final lower = userMessage.toLowerCase();

        // Check for simple factual question patterns
        final factualQuestionPatterns = [
          'does this make sense', 'does that make sense', 'make sense?',
          'is this correct', 'is that correct', 'is this right', 'is that right',
          'am i right about', 'am i correct about', 'am i understanding',
          'is it true that', 'is it accurate that',
          'did i understand', 'do i have this right',
          'correct?', 'right?',
        ];

        if (factualQuestionPatterns.any((pattern) => lower.contains(pattern))) {
          // Check if it's actually asking for deep analysis disguised as factual
          final deepAnalysisIndicators = [
            'what does this mean for', 'what does this say about',
            'what should i do', 'how should i', 'what am i missing',
            'pattern', 'trend', 'theme',
          ];

          // If no deep analysis indicators, treat as simple factual question
          if (!deepAnalysisIndicators.any((indicator) => lower.contains(indicator))) {
            isSimpleFactualQuestion = true;
            print('LUMARA Control State: Detected simple factual question');
          }
        }
      }

      questionType['isSimpleFactual'] = isSimpleFactualQuestion;
    } catch (e) {
      print('LUMARA Control State: Error detecting question type: $e');
      questionType['isSimpleFactual'] = false;
    }

    state['questionType'] = questionType;

    // ============================================================
    // G. WEB ACCESS CAPABILITY
    // ============================================================
    final webAccess = <String, dynamic>{};
    
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      final webAccessEnabled = await settingsService.isWebAccessEnabled();
      webAccess['enabled'] = webAccessEnabled;
    } catch (e) {
      print('LUMARA Control State: Error getting web access setting: $e');
      webAccess['enabled'] = false; // Default to disabled
    }
    
    state['webAccess'] = webAccess;
    
    // ============================================================
    // H. RESPONSE MODE (Phase-Centric vs Historical vs LUMARA's Thoughts)
    // ============================================================
    final responseMode = <String, dynamic>{};
    
    try {
      // Detect response mode from user message if provided
      final detectedMode = _detectResponseMode(userMessage);
      responseMode['mode'] = detectedMode;
      responseMode['isAuto'] = true; // Always auto-detected for now
    } catch (e) {
      print('LUMARA Control State: Error detecting response mode: $e');
      responseMode['mode'] = 'phase_centric'; // Default
      responseMode['isAuto'] = true;
    }
    
    // Written conversation (chat or journal, not voice): no length limit for Reflect/Explore/Integrate
    if (isWrittenConversation && !isVoiceMode) {
      responseMode['maxWords'] = writtenUnlimitedMaxWords;
      responseMode['noWordLimit'] = true;
      print('LUMARA Control State: Written conversation - no word limit (chat/journal, Reflect/Explore/Integrate)');
    } else if (maxWords != null) {
      // Apply voice mode multiplier (1/3 to 1/2 reduction) if in voice mode
      int effectiveMaxWords = maxWords;
      if (isVoiceMode) {
        // Apply 0.6x multiplier (40% reduction, approximately 1/3 to 1/2 shorter)
        effectiveMaxWords = (maxWords * 0.6).round();
        print('LUMARA Control State: Voice mode - reducing word limit from $maxWords to $effectiveMaxWords (0.6x multiplier)');
      }
      
      responseMode['maxWords'] = effectiveMaxWords;
    } else {
      if (userMessage != null && userMessage.trim().isNotEmpty) {
        try {
          final entryType = EntryClassifier.classify(userMessage);
          switch (entryType) {
            case EntryType.factual:
              responseMode['maxWords'] = 100;
              break;
            case EntryType.conversational:
              responseMode['maxWords'] = 50;
              break;
            case EntryType.reflective:
            case EntryType.analytical:
              responseMode['maxWords'] = 250;
              break;
            case EntryType.metaAnalysis:
              responseMode['maxWords'] = 500;
              break;
          }
          int defaultMaxWords = responseMode['maxWords'] as int;
          if (isVoiceMode) {
            defaultMaxWords = (defaultMaxWords * 0.6).round();
            responseMode['maxWords'] = defaultMaxWords;
          }
        } catch (e) {
          int defaultWords = 250;
          if (isVoiceMode) defaultWords = (defaultWords * 0.6).round();
          responseMode['maxWords'] = defaultWords;
        }
      } else {
        int defaultWords = 250;
        if (isVoiceMode) defaultWords = (defaultWords * 0.6).round();
        responseMode['maxWords'] = defaultWords;
      }
    }
    
    state['responseMode'] = responseMode;

    // ============================================================
    // I. ENGAGEMENT (fixed: reflect — Engagement mode setting removed)
    // ============================================================
    final engagement = <String, dynamic>{
      'mode': 'reflect',
      'maxQuestionsPerResponse': 0,
      'allowCrossDomainSynthesis': false,
      'max_temporal_connections': 1,
      'max_explorative_questions': 0,
      'synthesis_allowed': {
        'faith_work': false,
        'relationship_work': false,
        'health_emotional': false,
        'creative_intellectual': false,
      },
      'allow_therapeutic_language': false,
      'allow_prescriptive_guidance': false,
      'response_length': 'moderate',
      'synthesis_depth': 'moderate',
      'protected_domains': <String>[],
    };
    state['engagement'] = engagement;

    // ============================================================
    // J. RESPONSE LENGTH CONTROLS
    // ============================================================
    final responseLength = <String, dynamic>{};
    try {
      if (isWrittenConversation && !isVoiceMode) {
        responseLength['auto'] = true;
        responseLength['max_sentences'] = -1;
        responseLength['sentences_per_paragraph'] = 4;
        responseLength['mode'] = 'unlimited';
      } else {
        final settingsService = LumaraReflectionSettingsService.instance;
        await settingsService.initialize();

        final mode = await settingsService.getResponseLengthMode(); // short|medium|long
        final mapping = {
          'short': 5,
          'medium': 12,
          'long': 20,
        };
        final maxSentences = mapping[mode] ?? 12;
        responseLength['auto'] = false;
        responseLength['max_sentences'] = maxSentences;
        responseLength['sentences_per_paragraph'] = 3;
        responseLength['mode'] = mode;
      }
    } catch (e) {
      responseLength['auto'] = isWrittenConversation && !isVoiceMode;
      responseLength['max_sentences'] = (isWrittenConversation && !isVoiceMode) ? -1 : 12;
      responseLength['sentences_per_paragraph'] = (isWrittenConversation && !isVoiceMode) ? 4 : 3;
      responseLength['mode'] = (isWrittenConversation && !isVoiceMode) ? 'unlimited' : 'medium';
    }
    state['responseLength'] = responseLength;

    // ============================================================
    // K. MEMORY RETRIEVAL PARAMETERS
    // ============================================================
    final memory = <String, dynamic>{};
    
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      
      // Memory search parameters
      memory['similarityThreshold'] = await settingsService.getSimilarityThreshold();
      memory['lookbackYears'] = await settingsService.getEffectiveLookbackYears();
      memory['maxMatches'] = await settingsService.getEffectiveMaxMatches();
      memory['crossModalEnabled'] = await settingsService.isCrossModalEnabled();
      memory['therapeuticDepth'] = null; // Therapeutic Depth setting removed
      memory['therapeuticAutoAdapt'] = false;
      memory['includeMedia'] = true;
    } catch (e) {
      print('LUMARA Control State: Error getting memory parameters: $e');
      memory['similarityThreshold'] = 0.55;
      memory['lookbackYears'] = 5;
      memory['maxMatches'] = 5;
      memory['crossModalEnabled'] = true;
      memory['therapeuticDepth'] = null;
      memory['therapeuticAutoAdapt'] = false;
      memory['includeMedia'] = true;
    }
    
    state['memory'] = memory;

    // ============================================================
    // L. TEMPORAL AWARENESS (for LAYER 2.5 prompt)
    // ============================================================
    final temporalAwareness = <String, dynamic>{};
    try {
      final msg = userMessage ?? '';
      temporalAwareness['currentCycleWeek'] = await _calculateCycleWeek(userId, atlas['phase'] as String?);
      temporalAwareness['historicalThresholdNear'] = await _checkTemporalThreshold(userId);
      temporalAwareness['seasonalPatternActive'] = await _checkSeasonalPattern(userId);
      temporalAwareness['expansionSignals'] = _detectExpansionLanguage(msg);
      temporalAwareness['consolidationSignals'] = _detectConsolidationLanguage(msg);
      temporalAwareness['compressionSignals'] = _detectCompressionLanguage(msg);
      temporalAwareness['decisionPointDetected'] = _isDecisionQuestion(msg);
      temporalAwareness['temporalQueryDetected'] = _isTemporalQuery(msg);
    } catch (e) {
      print('LUMARA Control State: Error building temporalAwareness (non-fatal): $e');
      temporalAwareness['currentCycleWeek'] = null;
      temporalAwareness['historicalThresholdNear'] = false;
      temporalAwareness['seasonalPatternActive'] = false;
      temporalAwareness['expansionSignals'] = false;
      temporalAwareness['consolidationSignals'] = false;
      temporalAwareness['compressionSignals'] = false;
      temporalAwareness['decisionPointDetected'] = false;
      temporalAwareness['temporalQueryDetected'] = false;
    }
    state['temporalAwareness'] = temporalAwareness;

    // ============================================================
    // M. USER PERSONALITY CONFIG (baseline from onboarding)
    // ============================================================
    final personalityConfig = <String, dynamic>{};
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      final configString = await settingsService.getPersonalityConfig();
      final userName = await settingsService.getUserName();
      if (configString != null && configString.isNotEmpty) {
        personalityConfig['config'] = configString;
      }
      if (userName.isNotEmpty) {
        personalityConfig['userName'] = userName;
      }
      if (personalityConfig.isNotEmpty) {
        state['personalityConfig'] = personalityConfig;
      }

      // Inferred preferences (overrides; high confidence overrides baseline)
      final inferred = await settingsService.getInferredPreferences();
      if (inferred.isNotEmpty) {
        state['inferredPreferences'] = inferred;
      }
    } catch (e) {
      print('LUMARA Control State: Error loading personality config: $e');
    }

    // ============================================================
    // Final computed behavioral parameters
    // ============================================================
    // These are derived from the above signals AND persona
    final behavior = <String, dynamic>{
      'toneMode': _computeToneMode(state),
      'warmth': _computeWarmth(state),
      'rigor': _computeRigor(state),
      'abstraction': _computeAbstraction(state),
      'verbosity': _computeVerbosity(state),
      'challengeLevel': _computeChallengeLevel(state),
    };
    
    // Apply persona-specific overrides
    _applyPersonaOverrides(behavior, state);

    // Apply engagement discipline behavioral modifications
    _applyEngagementOverrides(behavior, state);

    state['behavior'] = behavior;
    
    // Log critical values that master prompt will use
    final finalPersona = state['persona']?['effective'] as String? ?? 'companion';
    final finalMaxWords = state['responseMode']?['maxWords'] as int? ?? 250;
    final finalEntryClassification = state['entryClassification'] as String? ?? 'reflective';
    print('🔵 LUMARA Control State: FINAL VALUES FOR MASTER PROMPT:');
    print('   - persona.effective: $finalPersona');
    print('   - responseMode.maxWords: $finalMaxWords');
    print('   - entryClassification: $finalEntryClassification');
    print('   - Master prompt will read these values from control state JSON');
    
    // Convert to JSON string with pretty formatting
    final controlStateJson = const JsonEncoder.withIndent('  ').convert(state);
    
    // Log a sample of the JSON to verify structure
    if (controlStateJson.length > 500) {
      print('🔵 LUMARA Control State: JSON preview (first 500 chars):');
      print(controlStateJson.substring(0, 500));
    }
    
    return controlStateJson;
  }
  
  /// Compute tone mode from control state
  static String _computeToneMode(Map<String, dynamic> state) {
    final atlas = state['atlas'] as Map<String, dynamic>? ?? {};
    final veil = state['veil'] as Map<String, dynamic>? ?? {};
    final therapy = state['therapy'] as Map<String, dynamic>? ?? {};
    
    final sentinelAlert = atlas['sentinelAlert'] as bool? ?? false;
    final timeOfDay = veil['timeOfDay'] as String? ?? 'afternoon';
    final therapyMode = therapy['therapyMode'] as String? ?? 'off';
    
    if (sentinelAlert) {
      return 'supportive';
    }
    
    if (therapyMode == 'deep_therapeutic') {
      return 'reflective';
    }
    
    if (timeOfDay == 'night') {
      return 'gentle';
    }
    
    return 'balanced';
  }
  
  /// Compute warmth level (0-1)
  static double _computeWarmth(Map<String, dynamic> state) {
    final atlas = state['atlas'] as Map<String, dynamic>? ?? {};
    final veil = state['veil'] as Map<String, dynamic>? ?? {};
    final favorites = state['favorites'] as Map<String, dynamic>? ?? {};
    final therapy = state['therapy'] as Map<String, dynamic>? ?? {};

    final sentinelAlert = atlas['sentinelAlert'] as bool? ?? false;
    final health = veil['health'] as Map<String, dynamic>? ?? {};
    final sleepQuality = health['sleepQuality'] as double? ?? 0.7;
    final favoritesProfile = favorites['favoritesProfile'] as Map<String, dynamic>?;
    final therapyMode = therapy['therapyMode'] as String? ?? 'off';

    if (sentinelAlert) return 0.8;
    if (therapyMode == 'deep_therapeutic') return 0.7;

    double warmth = 0.6;
    if (sleepQuality < 0.5) warmth += 0.1;

    if (favoritesProfile != null) {
      final favWarmth = favoritesProfile['warmth'] as double? ?? 0.6;
      warmth = (warmth + favWarmth) / 2;
    }

    return warmth.clamp(0.0, 1.0);
  }
  
  /// Compute rigor level (0-1)
  static double _computeRigor(Map<String, dynamic> state) {
    final atlas = state['atlas'] as Map<String, dynamic>? ?? {};
    final veil = state['veil'] as Map<String, dynamic>? ?? {};
    final favorites = state['favorites'] as Map<String, dynamic>? ?? {};

    final readinessScore = atlas['readinessScore'] as int? ?? 50;
    final sophisticationLevel = veil['sophisticationLevel'] as String? ?? 'moderate';
    final favoritesProfile = favorites['favoritesProfile'] as Map<String, dynamic>?;

    double rigor = 0.5;

    if (readinessScore > 70) rigor += 0.2;
    if (sophisticationLevel == 'analytical') rigor += 0.2;
    if (sophisticationLevel == 'simple') rigor -= 0.2;

    if (favoritesProfile != null) {
      final favRigor = favoritesProfile['rigor'] as double? ?? 0.5;
      rigor = (rigor + favRigor) / 2;
    }

    return rigor.clamp(0.0, 1.0);
  }
  
  /// Compute abstraction level (0-1)
  static double _computeAbstraction(Map<String, dynamic> state) {
    final atlas = state['atlas'] as Map<String, dynamic>? ?? {};
    final veil = state['veil'] as Map<String, dynamic>? ?? {};

    final sentinelAlert = atlas['sentinelAlert'] as bool? ?? false;
    final health = veil['health'] as Map<String, dynamic>? ?? {};
    final sleepQuality = health['sleepQuality'] as double? ?? 0.7;
    final energyLevel = health['energyLevel'] as double? ?? 0.7;
    final timeOfDay = veil['timeOfDay'] as String? ?? 'afternoon';

    if (sentinelAlert) return 0.2;

    double abstraction = 0.5;
    if (sleepQuality < 0.5 || energyLevel < 0.5) abstraction -= 0.2;
    if (timeOfDay == 'night') abstraction -= 0.1;

    return abstraction.clamp(0.0, 1.0);
  }
  
  /// Compute verbosity level (0-1)
  /// 
  /// For regular chat, default to higher verbosity (0.7-0.8) for comprehensive responses.
  /// Only reduce verbosity if user has low energy or explicitly prefers concise responses.
  static double _computeVerbosity(Map<String, dynamic> state) {
    final veil = state['veil'] as Map<String, dynamic>? ?? {};
    final health = veil['health'] as Map<String, dynamic>? ?? {};
    final engagement = state['engagement'] as Map<String, dynamic>? ?? {};
    final energyLevel = health['energyLevel'] as double? ?? 0.7;
    final responseLength = engagement['response_length'] as String?;
    
    // Check if user has explicit response length preference
    if (responseLength == 'concise') {
      return 0.3; // Low verbosity for concise preference
    } else if (responseLength == 'detailed') {
      return 0.9; // High verbosity for detailed preference
    }
    
    // Default to moderate-high verbosity (0.7) for comprehensive chat responses
    // Only reduce if user has low energy
    double verbosity = 0.7; // Base verbosity - comprehensive responses by default
    
    if (energyLevel < 0.5) {
      verbosity = 0.5; // Slightly lower verbosity for low energy, but still moderate
    }
    
    return verbosity.clamp(0.0, 1.0);
  }
  
  /// Compute challenge level (0-1)
  static double _computeChallengeLevel(Map<String, dynamic> state) {
    final atlas = state['atlas'] as Map<String, dynamic>? ?? {};
    final veil = state['veil'] as Map<String, dynamic>? ?? {};
    final prism = state['prism'] as Map<String, dynamic>? ?? {};

    final sentinelAlert = atlas['sentinelAlert'] as bool? ?? false;
    final readinessScore = atlas['readinessScore'] as int? ?? 50;
    final health = veil['health'] as Map<String, dynamic>? ?? {};
    final sleepQuality = health['sleepQuality'] as double? ?? 0.7;
    final prismActivity = prism['prism_activity'] as Map<String, dynamic>?;
    final cognitiveLoad = prismActivity?['cognitive_load'] as String? ?? 'moderate';

    if (sentinelAlert) return 0.2;

    double challenge = 0.5;
    if (readinessScore > 70) challenge += 0.2;
    if (sleepQuality < 0.5) challenge -= 0.2;
    if (cognitiveLoad == 'high') challenge -= 0.1;
    if (cognitiveLoad == 'low') challenge += 0.1;

    return challenge.clamp(0.0, 1.0);
  }
  
  /// Detect response mode from user message
  static String _detectResponseMode(String? userMessage) {
    if (userMessage == null || userMessage.trim().isEmpty) {
      return 'phase_centric'; // Default
    }
    
    final lower = userMessage.toLowerCase();
    
    // Historical patterns mode
    final historicalPatterns = [
      'what patterns', 'patterns do you see', 'past entries',
      'historical', 'over time', 'across time', 'longitudinal',
      'how does this relate to my past', 'previous entries',
      'earlier entries', 'past journal', 'past experiences',
    ];
    if (historicalPatterns.any((pattern) => lower.contains(pattern))) {
      return 'historical_patterns';
    }
    
    // LUMARA's thoughts mode
    final lumaraThoughtsPatterns = [
      'what\'s your take', 'your thoughts', 'your opinion',
      'what do you think', 'your perspective', 'your view',
      'your analysis', 'your interpretation', 'your insight',
      'lumara\'s thoughts', 'your own', 'not tied to phase',
    ];
    if (lumaraThoughtsPatterns.any((pattern) => lower.contains(pattern))) {
      return 'lumara_thoughts';
    }
    
    // Hybrid mode (explicit request for multiple approaches)
    if (lower.contains('both') && (lower.contains('pattern') || lower.contains('phase'))) {
      return 'hybrid';
    }
    
    // Default: phase-centric
    return 'phase_centric';
  }
  
  /// Apply persona-specific behavioral overrides
  static void _applyPersonaOverrides(Map<String, dynamic> behavior, Map<String, dynamic> state) {
    final persona = state['persona'] as Map<String, dynamic>? ?? {};
    final effectivePersona = persona['effective'] as String? ?? 'companion';
    
    switch (effectivePersona) {
      case 'companion':
        // Warm, supportive, adaptive
        behavior['warmth'] = ((behavior['warmth'] as double? ?? 0.6) * 0.7 + 0.8 * 0.3).clamp(0.0, 1.0);
        behavior['rigor'] = ((behavior['rigor'] as double? ?? 0.5) * 0.7 + 0.4 * 0.3).clamp(0.0, 1.0);
        behavior['challengeLevel'] = ((behavior['challengeLevel'] as double? ?? 0.5) * 0.7 + 0.2 * 0.3).clamp(0.0, 1.0);
        behavior['outputStructure'] = 'conversational';
        behavior['actionOriented'] = false;
        break;
        
      case 'therapist':
        // Deep therapeutic, ECHO+SAGE, gentle pacing
        behavior['warmth'] = ((behavior['warmth'] as double? ?? 0.6) * 0.5 + 0.9 * 0.5).clamp(0.0, 1.0);
        behavior['rigor'] = ((behavior['rigor'] as double? ?? 0.5) * 0.5 + 0.3 * 0.5).clamp(0.0, 1.0);
        behavior['abstraction'] = ((behavior['abstraction'] as double? ?? 0.5) * 0.5 + 0.3 * 0.5).clamp(0.0, 1.0);
        behavior['challengeLevel'] = ((behavior['challengeLevel'] as double? ?? 0.5) * 0.5 + 0.1 * 0.5).clamp(0.0, 1.0);
        behavior['outputStructure'] = 'conversational';
        behavior['actionOriented'] = false;
        break;
        
      case 'strategist':
        // Operational, diagnostic, action-oriented
        // NOTE: Structured format is ONLY for explicit pattern analysis requests
        // Personal reflections should use conversational format even in strategist mode
        behavior['warmth'] = ((behavior['warmth'] as double? ?? 0.6) * 0.5 + 0.3 * 0.5).clamp(0.0, 1.0);
        behavior['rigor'] = ((behavior['rigor'] as double? ?? 0.5) * 0.5 + 0.9 * 0.5).clamp(0.0, 1.0);
        behavior['abstraction'] = ((behavior['abstraction'] as double? ?? 0.5) * 0.5 + 0.7 * 0.5).clamp(0.0, 1.0);
        behavior['challengeLevel'] = ((behavior['challengeLevel'] as double? ?? 0.5) * 0.5 + 0.7 * 0.5).clamp(0.0, 1.0);
        // Check if this is a meta-analysis request (explicit pattern analysis)
        // Only use structured format for explicit pattern requests, not personal reflections
        final entryType = state['entryClassification'] as String?;
        if (entryType == 'metaAnalysis') {
          behavior['outputStructure'] = 'structured'; // 5-section format for explicit pattern requests
        } else {
          behavior['outputStructure'] = 'conversational'; // Conversational for personal reflections
        }
        behavior['actionOriented'] = true;
        break;
        
      case 'challenger':
        // Direct, pushes growth, high challenge
        behavior['warmth'] = ((behavior['warmth'] as double? ?? 0.6) * 0.5 + 0.5 * 0.5).clamp(0.0, 1.0);
        behavior['rigor'] = ((behavior['rigor'] as double? ?? 0.5) * 0.5 + 0.8 * 0.5).clamp(0.0, 1.0);
        behavior['abstraction'] = ((behavior['abstraction'] as double? ?? 0.5) * 0.5 + 0.6 * 0.5).clamp(0.0, 1.0);
        behavior['challengeLevel'] = ((behavior['challengeLevel'] as double? ?? 0.5) * 0.3 + 0.9 * 0.7).clamp(0.0, 1.0);
        behavior['outputStructure'] = 'conversational';
        behavior['actionOriented'] = true;
        break;
    }
  }

  /// Apply engagement discipline overrides to behavioral parameters
  static void _applyEngagementOverrides(Map<String, dynamic> behavior, Map<String, dynamic> state) {
    final engagement = state['engagement'] as Map<String, dynamic>? ?? {};
    final behaviorParams = engagement['behavioral_params'] as Map<String, dynamic>? ?? {};

    if (behaviorParams.isNotEmpty) {
      // Apply engagement intensity to overall warmth and challenge
      final engagementIntensity = behaviorParams['engagement_intensity'] as double? ?? 0.6;
      final stoppingThreshold = behaviorParams['stopping_threshold'] as double? ?? 0.5;
      final questionPropensity = behaviorParams['question_propensity'] as double? ?? 0.3;

      // Modulate existing behavioral parameters based on engagement settings

      // Engagement intensity affects warmth (higher engagement = more warmth)
      if (behavior['warmth'] is double) {
        final currentWarmth = behavior['warmth'] as double;
        behavior['warmth'] = (currentWarmth * 0.8 + engagementIntensity * 0.2).clamp(0.0, 1.0);
      }

      // Stopping threshold affects verbosity (higher threshold = lower verbosity)
      if (behavior['verbosity'] is double) {
        final currentVerbosity = behavior['verbosity'] as double;
        final verbosityAdjustment = 1.0 - (stoppingThreshold * 0.3);
        behavior['verbosity'] = (currentVerbosity * verbosityAdjustment).clamp(0.0, 1.0);
      }

      // Question propensity affects challenge level and rigor
      if (behavior['challengeLevel'] is double) {
        final currentChallenge = behavior['challengeLevel'] as double;
        behavior['challengeLevel'] = (currentChallenge * 0.8 + questionPropensity * 0.2).clamp(0.0, 1.0);
      }

      if (behavior['rigor'] is double) {
        final currentRigor = behavior['rigor'] as double;
        final explorativeTendency = behaviorParams['explorative_tendency'] as double? ?? 0.5;
        behavior['rigor'] = (currentRigor * 0.8 + explorativeTendency * 0.2).clamp(0.0, 1.0);
      }

      // Add engagement-specific behavioral hints
      final engagementMode = engagement['mode'] as String? ?? 'reflect';
      behavior['engagementMode'] = engagementMode;
      behavior['maxTemporalConnections'] = engagement['max_temporal_connections'] as int? ?? 2;
      behavior['maxExplorativeQuestions'] = engagement['max_explorative_questions'] as int? ?? 1;
      behavior['allowTherapeuticLanguage'] = engagement['allow_therapeutic_language'] as bool? ?? false;
      behavior['allowPrescriptiveGuidance'] = engagement['allow_prescriptive_guidance'] as bool? ?? false;
    }
  }

  // ========== Temporal awareness helpers (for LAYER 2.5) ==========

  /// Compute dominant phase from phase scores (argmax).
  static String? _dominantPhase(PhaseHistoryEntry entry) {
    if (entry.phaseScores.isEmpty) return null;
    return entry.phaseScores.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  /// Phase start = timestamp of the oldest entry in the current run of [currentPhase]. Returns null if insufficient data.
  /// Assumes single-user device (phase history box not filtered by userId).
  static Future<int?> _calculateCycleWeek(String? userId, String? phase) async {
    if (userId == null) return null;
    try {
      await PhaseHistoryRepository.initialize();
      final entries = await PhaseHistoryRepository.getAllEntries();
      if (entries.length < 2) return null;
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final currentPhase = phase?.isNotEmpty == true
          ? phase
          : _dominantPhase(entries.first);
      if (currentPhase == null) return null;
      DateTime phaseStart = entries.first.timestamp;
      for (final e in entries) {
        if (_dominantPhase(e) != currentPhase) break;
        phaseStart = e.timestamp;
      }
      final now = DateTime.now();
      final days = now.difference(phaseStart).inDays;
      if (days < 0) return null;
      return (days / 7).floor();
    } catch (e) {
      return null;
    }
  }

  /// True if user is within ~1 week of a historical pattern duration (from pattern index typicalDurationDays).
  static Future<bool> _checkTemporalThreshold(String? userId) async {
    if (userId == null) return false;
    try {
      final cycleWeek = await _calculateCycleWeek(userId, null);
      if (cycleWeek == null) return false;
      final storage = ChronicleIndexStorage();
      final json = await storage.read(userId);
      if (json.isEmpty) return false;
      final index = ChronicleIndex.fromJson(json);
      for (final cluster in index.themeClusters.values) {
        final days = cluster.insights.typicalDurationDays;
        if (days == null) continue;
        final durationWeeks = (days / 7).round();
        if ((durationWeeks - cycleWeek).abs() <= 1) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// True if current month appears in 2+ years in pattern index appearances (seasonal recurrence).
  static Future<bool> _checkSeasonalPattern(String? userId) async {
    if (userId == null) return false;
    try {
      final storage = ChronicleIndexStorage();
      final json = await storage.read(userId);
      if (json.isEmpty) return false;
      final index = ChronicleIndex.fromJson(json);
      final currentMonth = DateTime.now().month.toString().padLeft(2, '0');
      final yearsWithThisMonth = <int>{};
      for (final cluster in index.themeClusters.values) {
        for (final app in cluster.appearances) {
          if (app.period.endsWith('-$currentMonth')) {
            final parts = app.period.split('-');
            if (parts.isNotEmpty) {
              final year = int.tryParse(parts[0]);
              if (year != null) yearsWithThisMonth.add(year);
            }
          }
        }
      }
      return yearsWithThisMonth.length >= 2;
    } catch (_) {
      return false;
    }
  }

  static bool _detectExpansionLanguage(String message) {
    const keywords = ['adding', 'building', 'what if', 'also', 'integrate', 'connect'];
    final lower = message.toLowerCase();
    return keywords.any((kw) => lower.contains(kw));
  }

  static bool _detectConsolidationLanguage(String message) {
    const keywords = ['focus', 'priority', 'ship', 'simple', 'mvp', 'what matters'];
    final lower = message.toLowerCase();
    return keywords.any((kw) => lower.contains(kw));
  }

  static bool _detectCompressionLanguage(String message) {
    const keywords = ['overwhelm', '80/20', 'too much', 'scope', 'constraint'];
    final lower = message.toLowerCase();
    return keywords.any((kw) => lower.contains(kw));
  }

  static bool _isDecisionQuestion(String message) {
    final lower = message.toLowerCase();
    return lower.contains('should i') || lower.contains('should we');
  }

  static bool _isTemporalQuery(String message) {
    const keywords = [
      'when', 'how long', 'last week', 'last month', 'february',
      'how have i changed', 'show me', 'what was i', 'january', 'march',
    ];
    final lower = message.toLowerCase();
    return keywords.any((kw) => lower.contains(kw));
  }
}

/// LUMARA Control State Builder
/// 
/// Builds the unified control state JSON that governs all LUMARA behavior.
/// Combines signals from ATLAS, VEIL, FAVORITES, PRISM, and THERAPY MODE.

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
import 'package:my_app/services/health_data_service.dart';
import 'package:my_app/services/lumara/entry_classifier.dart';
import 'package:my_app/services/lumara/user_intent.dart';
import 'package:my_app/services/lumara/persona_selector.dart';

class LumaraControlStateBuilder {
  /// Build the unified control state JSON
  /// 
  /// This combines all behavioral signals into a single JSON structure
  /// that the master prompt uses to govern LUMARA's behavior.
  static Future<String> buildControlState({
    String? userId,
    Map<String, dynamic>? prismActivity,
    Map<String, dynamic>? chronoContext,
    String? userMessage, // NEW: User message for question intent detection
    int? maxWords, // NEW: Word limit from response mode
    UserIntent? userIntent, // NEW: User intent from conversation mode/button (from services/lumara/user_intent.dart)
    bool isVoiceMode = false, // NEW: Flag for voice mode (applies length multiplier)
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
    
    // Get health signals from HealthDataService
    final health = <String, dynamic>{
      'sleepQuality': 0.7, // 0-1, default to moderate
      'energyLevel': 0.7, // 0-1, default to moderate
      'medicationStatus': null, // Optional flag
    };
    
    // Integrate with health tracking service
    try {
      final healthService = HealthDataService.instance;
      final healthData = await healthService.getEffectiveHealthData();
      health['sleepQuality'] = healthData.sleepQuality;
      health['energyLevel'] = healthData.energyLevel;
      health['medicationStatus'] = healthData.medicationStatus;
    } catch (e) {
      print('LUMARA Control State: Error getting health data, using defaults: $e');
    }
    
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
    // E. THERAPY MODE (ECHO + SAGE)
    // ============================================================
    final therapy = <String, dynamic>{};
    
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      final therapeuticEnabled = await settingsService.isTherapeuticPresenceEnabled();

      if (!therapeuticEnabled) {
        therapy['therapyMode'] = 'off';
      } else {
        final automaticMode = await settingsService.isTherapeuticAutomaticMode();
        if (automaticMode) {
          therapy['therapyMode'] = 'supportive';
        } else {
          final depthLevel = await settingsService.getTherapeuticDepthLevel();
          therapy['therapyMode'] = (depthLevel == 3) ? 'deep_therapeutic' : 'supportive';
        }
      }

      if (sentinelAlert) {
        therapy['therapyMode'] = 'supportive';
      }
    } catch (e) {
      print('LUMARA Control State: Error getting therapy mode: $e');
      therapy['therapyMode'] = 'off';
    }
    
    state['therapy'] = therapy;
    
    // ============================================================
    // F. LUMARA PERSONA
    // ============================================================
    final persona = <String, dynamic>{};
    
    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      final selectedPersona = await settingsService.getLumaraPersona();
      
      String effectivePersona;
      if (selectedPersona == LumaraPersona.auto) {
        // Auto-detect persona based on question intent first, then context
        // Pass userIntent if provided (from conversation mode/button)
        effectivePersona = _autoDetectPersona(state, sentinelAlert, userMessage, userIntent);
      } else {
        effectivePersona = selectedPersona.name;
      }
      
      persona['selected'] = selectedPersona.name;
      persona['effective'] = effectivePersona;
      persona['isAuto'] = selectedPersona == LumaraPersona.auto;
      
      // Log final persona selection
      final isCompanionFinal = effectivePersona == 'companion';
      final finalIcon = isCompanionFinal ? '🟢' : '🔴';
      print('$finalIcon LUMARA Control State: FINAL PERSONA = $effectivePersona (selected: ${selectedPersona.name}, isAuto: ${persona['isAuto']})');
      if (isCompanionFinal) {
        print('🟢 ✅ FINAL PERSONA IS COMPANION - System will use Companion mode!');
      }
      
      // Add entry classification for structured format detection
      if (userMessage != null && userMessage.trim().isNotEmpty) {
        try {
          final entryType = EntryClassifier.classify(userMessage);
          state['entryClassification'] = entryType.toString().split('.').last;
          print('🔵 LUMARA Control State: Entry classified as ${state['entryClassification']}');
        } catch (e) {
          print('🔴 LUMARA Control State: Error classifying entry: $e');
          state['entryClassification'] = 'reflective'; // Safe default
        }
      } else {
        state['entryClassification'] = 'reflective'; // Default for empty messages
      }
    } catch (e) {
      print('LUMARA Control State: Error getting persona: $e');
      persona['selected'] = 'auto';
      persona['effective'] = 'companion';
      persona['isAuto'] = true;
      state['entryClassification'] = 'reflective'; // Default
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
    
    // Add word limit if provided
    if (maxWords != null) {
      // Apply voice mode multiplier (1/3 to 1/2 reduction) if in voice mode
      int effectiveMaxWords = maxWords;
      if (isVoiceMode) {
        // Apply 0.6x multiplier (40% reduction, approximately 1/3 to 1/2 shorter)
        effectiveMaxWords = (maxWords * 0.6).round();
        print('LUMARA Control State: Voice mode - reducing word limit from $maxWords to $effectiveMaxWords (0.6x multiplier)');
      }
      
      // Override with Companion-first limits if persona is Companion
      final effectivePersona = state['persona']?['effective'] as String? ?? 'companion';
      if (effectivePersona == 'companion' && effectiveMaxWords > 250) {
        // Force Companion limit of 250 words for personal reflections
        responseMode['maxWords'] = 250;
        print('LUMARA Control State: Overrode word limit to 250 for Companion persona (was $effectiveMaxWords)');
      } else {
        responseMode['maxWords'] = effectiveMaxWords;
        print('LUMARA Control State: Word limit set to ${responseMode['maxWords']} words${isVoiceMode ? ' (voice mode)' : ''}');
      }
    } else {
      // Default word limits based on entry classification and persona
      if (userMessage != null && userMessage.trim().isNotEmpty) {
        try {
          final entryType = EntryClassifier.classify(userMessage);
          final effectivePersona = state['persona']?['effective'] as String? ?? 'companion';
          
          // Companion-first: Use 250 words for Companion persona
          if (effectivePersona == 'companion') {
            switch (entryType) {
              case EntryType.factual:
                responseMode['maxWords'] = 100;
                break;
              case EntryType.conversational:
                responseMode['maxWords'] = 50;
                break;
              case EntryType.reflective:
                responseMode['maxWords'] = 250; // Companion limit for personal reflections
                break;
              case EntryType.analytical:
                responseMode['maxWords'] = 250; // Companion limit
                break;
              case EntryType.metaAnalysis:
                responseMode['maxWords'] = 500; // Strategist for meta-analysis
                break;
            }
          } else {
            // Other personas use their own limits
            switch (entryType) {
              case EntryType.factual:
                responseMode['maxWords'] = 100;
                break;
              case EntryType.conversational:
                responseMode['maxWords'] = 50;
                break;
              case EntryType.reflective:
                responseMode['maxWords'] = 300;
                break;
              case EntryType.analytical:
                responseMode['maxWords'] = 300;
                break;
              case EntryType.metaAnalysis:
                responseMode['maxWords'] = 500;
                break;
            }
          }
          int defaultMaxWords = responseMode['maxWords'] as int;
          // Apply voice mode multiplier if in voice mode
          if (isVoiceMode) {
            defaultMaxWords = (defaultMaxWords * 0.6).round();
            responseMode['maxWords'] = defaultMaxWords;
            print('LUMARA Control State: Voice mode - reducing default word limit to $defaultMaxWords (0.6x multiplier)');
          }
          print('LUMARA Control State: Auto-set word limit to ${responseMode['maxWords']} for ${entryType.toString().split('.').last} (persona: $effectivePersona)${isVoiceMode ? ' [VOICE MODE]' : ''}');
        } catch (e) {
          print('LUMARA Control State: Error setting default word limit: $e');
          int defaultWords = 250;
          if (isVoiceMode) {
            defaultWords = (defaultWords * 0.6).round();
          }
          responseMode['maxWords'] = defaultWords; // Safe default
        }
      } else {
        int defaultWords = 250;
        if (isVoiceMode) {
          defaultWords = (defaultWords * 0.6).round();
        }
        responseMode['maxWords'] = defaultWords; // Default
      }
    }
    
    state['responseMode'] = responseMode;

    // ============================================================
    // I. ENGAGEMENT DISCIPLINE (Response Boundaries)
    // ============================================================
    final engagement = <String, dynamic>{};

    try {
      final settingsService = LumaraReflectionSettingsService.instance;
      final engagementSettings = await settingsService.getEngagementSettings();
      final activeMode = engagementSettings.activeMode;
      // Therapeutic language derived from Therapy Mode only (no separate toggle)
      final therapeuticEnabled = await settingsService.isTherapeuticPresenceEnabled();

      // Build simplified engagement control state using derived properties
      engagement.addAll({
        'mode': activeMode.toString().split('.').last, // 'reflect', 'explore', 'integrate'
        'maxQuestionsPerResponse': engagementSettings.maxQuestionsPerResponse,
        'allowCrossDomainSynthesis': engagementSettings.allowCrossDomainSynthesis,
        'max_temporal_connections': engagementSettings.responseDiscipline
            .getEffectiveMaxTemporalConnections(activeMode),
        'max_explorative_questions': engagementSettings.maxQuestionsPerResponse,
        'synthesis_allowed': {
          'faith_work': engagementSettings.allowCrossDomainSynthesis,
          'relationship_work': engagementSettings.allowCrossDomainSynthesis,
          'health_emotional': engagementSettings.allowCrossDomainSynthesis,
          'creative_intellectual': engagementSettings.allowCrossDomainSynthesis,
        },
        'allow_therapeutic_language': therapeuticEnabled,
        'allow_prescriptive_guidance': therapeuticEnabled,
        'response_length': engagementSettings.responseDiscipline.preferredLength.toString(),
        'synthesis_depth': engagementSettings.synthesisPreferences.synthesisDepth.toString(),
        'protected_domains': engagementSettings.synthesisPreferences.protectedDomains,
      });

    } catch (e) {
      print('LUMARA Control State: Error building engagement context: $e');
      // Provide fallback engagement settings (REFLECT mode defaults)
      engagement.addAll({
        'mode': 'reflect',
        'maxQuestionsPerResponse': 0,
        'allowCrossDomainSynthesis': false,
        'synthesis_allowed': {
          'faith_work': false,
          'relationship_work': false,
          'health_emotional': false,
          'creative_intellectual': false,
        },
        'max_temporal_connections': 1,
        'max_explorative_questions': 0,
        'allow_therapeutic_language': false,
        'allow_prescriptive_guidance': false,
        'response_length': 'moderate',
        'synthesis_depth': 'moderate',
        'protected_domains': <String>[],
      });
    }

    state['engagement'] = engagement;

    // ============================================================
    // J. RESPONSE LENGTH CONTROLS
    // ============================================================
    final responseLength = <String, dynamic>{};
    try {
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
    } catch (e) {
      responseLength['auto'] = false;
      responseLength['max_sentences'] = 12;
      responseLength['sentences_per_paragraph'] = 3;
      responseLength['mode'] = 'medium';
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
      
      // Therapeutic depth (affects memory retrieval scope)
      final therapeuticEnabled = await settingsService.isTherapeuticPresenceEnabled();
      if (therapeuticEnabled) {
        memory['therapeuticDepth'] = await settingsService.getTherapeuticDepthLevel();
        memory['therapeuticAutoAdapt'] = await settingsService.isTherapeuticAutomaticMode();
      } else {
        memory['therapeuticDepth'] = null;
        memory['therapeuticAutoAdapt'] = false;
      }
      
      // Include media in context (default: true, can be controlled by user preference)
      // For now, default to true - can be enhanced with user setting
      memory['includeMedia'] = true;
      
    } catch (e) {
      print('LUMARA Control State: Error getting memory parameters: $e');
      // Fallback defaults
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
  
  /// Auto-detect the best persona using Companion-First logic
  /// Uses the new PersonaSelector with entry classification and user intent
  static String _autoDetectPersona(Map<String, dynamic> state, bool sentinelAlert, [String? questionText, UserIntent? providedUserIntent]) {
    // Extract state values
    final atlas = state['atlas'] as Map<String, dynamic>? ?? {};
    final phase = atlas['phase'] as String? ?? 'Discovery';
    final readinessScore = (atlas['readinessScore'] as num?)?.toInt() ?? 50;
    
    // If no user message, default to Companion
    if (questionText == null || questionText.trim().isEmpty) {
      print('🔵 LUMARA Control State: No user message → Companion (default)');
      return 'companion';
    }
    
    // STEP 1: Classify entry type using new EntryClassifier
    final entryType = EntryClassifier.classify(questionText);
    final entryTypeDesc = EntryClassifier.getTypeDescription(entryType);
    print('🔵 LUMARA Control State: Entry classified as: $entryTypeDesc (${entryType.toString().split('.').last})');
    
    // STEP 2: Detect user intent
    // Use provided intent (from conversation mode/button) or default to reflect
    final userIntent = providedUserIntent ?? UserIntent.reflect;
    if (providedUserIntent != null) {
      print('🔵 LUMARA Control State: Using provided UserIntent: ${userIntent.toString().split('.').last}');
    } else {
      print('🔵 LUMARA Control State: No UserIntent provided, defaulting to reflect');
    }
    
    // STEP 3: Calculate emotional intensity
    final emotionalIntensity = PersonaSelector.calculateEmotionalIntensity(questionText);
    print('🔵 LUMARA Control State: Emotional intensity: $emotionalIntensity');
    
    // STEP 4: Use new Companion-First PersonaSelector
    final selectedPersona = PersonaSelector.selectPersona(
      entryType: entryType,
      userIntent: userIntent,
      phase: phase,
      readinessScore: readinessScore,
      sentinelAlert: sentinelAlert,
      emotionalIntensity: emotionalIntensity,
    );
    
    // Enhanced logging with clear indicators
    final isCompanion = selectedPersona == 'companion';
    final personaIcon = isCompanion ? '🟢' : '🔴';
    print('$personaIcon LUMARA Control State: PersonaSelector selected: $selectedPersona');
    if (isCompanion) {
      print('🟢 ✅ COMPANION MODE SELECTED - This is correct for personal reflections!');
    } else {
      print('🔴 ⚠️  Non-Companion selected: $selectedPersona (entryType: ${entryType.toString().split('.').last}, emotionalIntensity: $emotionalIntensity, readinessScore: $readinessScore)');
    }
    
    // Log selection reason
    String reason;
    if (sentinelAlert) {
      reason = 'Sentinel alert override';
    } else if (emotionalIntensity > 0.5 || readinessScore < 25) {
      reason = 'High distress override';
    } else if (entryType == EntryType.metaAnalysis) {
      reason = 'Meta-analysis entry type';
    } else if (entryType == EntryType.reflective) {
      if (emotionalIntensity > 0.4 && emotionalIntensity <= 0.5) {
        reason = 'Moderate-high emotional intensity';
      } else {
        reason = 'Companion-first default for reflective entries';
      }
    } else {
      reason = 'Companion-first default for ${entryType.toString().split('.').last} entries';
    }
    print('🔵 LUMARA Control State: Selection reason: $reason');
    
    return selectedPersona;
  }
  
  /// Detect persona from question text using pattern matching
  static String? _detectPersonaFromQuestion(String question) {
    if (question.isEmpty) return null;

    final lower = question.toLowerCase();

    // PRIORITY 1: Simple factual questions → return null for simple, direct answer
    // These should NOT trigger deep reflection - just answer the question
    final factualQuestionPatterns = [
      'does this make sense', 'does that make sense', 'make sense?',
      'is this correct', 'is that correct', 'is this right', 'is that right',
      'am i right about', 'am i correct about', 'am i understanding',
      'is it true that', 'is it accurate that',
      'did i understand', 'do i have this right',
      'correct?', 'right?', // Statement followed by verification
    ];

    // Check for factual verification questions
    if (factualQuestionPatterns.any((pattern) => lower.contains(pattern))) {
      // Check if it's actually asking for deep analysis disguised as factual
      final deepAnalysisIndicators = [
        'what does this mean for', 'what does this say about',
        'what should i do', 'how should i', 'what am i missing',
        'pattern', 'trend', 'theme',
      ];

      // If no deep analysis indicators, treat as simple factual question
      if (!deepAnalysisIndicators.any((indicator) => lower.contains(indicator))) {
        print('LUMARA Control State: Detected simple factual question - returning null for direct answer');
        return null; // null = no special persona, just answer the question simply
      }
    }

    // Explicit advice/opinion requests → prioritize strategist or challenger
    final explicitAdvicePatterns = [
      'tell me your thoughts', 'what do you think', 'what are your thoughts',
      'give me the hard truth', 'be honest', 'tell me straight',
      'what\'s your opinion', 'what\'s your take', 'what\'s your view',
      'am i missing anything', 'what am i missing', 'what\'s missing',
      'give me recommendations', 'what would you recommend', 'what do you recommend',
      'review this', 'analyze this', 'critique this',
      'is this reasonable', 'does this sound right', 'what\'s wrong with this',
      'give me advice', 'what should i do', 'help me decide',
    ];
    
    // Check for explicit advice requests first (high priority)
    if (explicitAdvicePatterns.any((pattern) => lower.contains(pattern))) {
      // If asking for "hard truth" or direct feedback → challenger
      if (lower.contains('hard truth') || lower.contains('be honest') || 
          lower.contains('tell me straight') || lower.contains('direct') ||
          lower.contains('what\'s wrong') || lower.contains('critique')) {
        return 'challenger';
      }
      // Otherwise → strategist for analytical/process-oriented advice
      return 'strategist';
    }
    
    // Strategic/Analytical questions → strategist
    final strategistPatterns = [
      'how should', 'what strategy', 'analyze', 'plan',
      'optimize', 'approach', 'method', 'tactic', 'strategy',
      'what steps', 'how to', 'best way', 'recommend',
    ];
    if (strategistPatterns.any((pattern) => lower.contains(pattern))) {
      return 'strategist';
    }
    
    // Challenging questions → challenger
    final challengerPatterns = [
      'challenge', 'what am i avoiding', 'honest',
      'push me', 'what am i missing', 'blind spot',
      'what am i not seeing', 'hard truth', 'direct',
      'what am i wrong', 'call me out',
      'hold me accountable', 'keep me accountable',
      'i need accountability', 'i need to be pushed',
      'i\'m making excuses', 'i\'m procrastinating',
      'call me on', 'be honest with me', 'don\'t let me',
    ];
    if (challengerPatterns.any((pattern) => lower.contains(pattern))) {
      return 'challenger';
    }
    
    // Support requests - need to distinguish emotional vs practical
    final supportPatterns = [
      'i need support', 'i need help', 'support me',
      'i\'m struggling', 'i\'m having trouble', 'i can\'t',
      'feeling overwhelmed', 'feeling lost', 'feeling stuck',
      'don\'t know what to do', 'need guidance', 'need someone',
    ];
    
    // Emotional support patterns → therapist or companion
    final emotionalSupportPatterns = [
      'feel', 'emotion', 'feeling', 'hurt', 'pain', 'sad',
      'anxious', 'worried', 'scared', 'afraid', 'lonely',
      'depressed', 'overwhelmed', 'exhausted', 'tired',
      'can\'t cope', 'can\'t handle', 'too much',
    ];
    
      // Practical support patterns → strategist or companion
      final practicalSupportPatterns = [
        'how do i', 'what should i do', 'what steps',
        'need to', 'have to', 'must', 'should i',
        'decision', 'choose', 'pick', 'option',
        'figure out', 'solve', 'fix', 'handle',
        'get started', 'begin', 'start',
      ];
      
      // Accountability/growth-pushing support → challenger
      final challengerSupportPatterns = [
        'push me', 'hold me accountable', 'keep me accountable',
        'challenge me', 'call me out', 'be direct',
        'tell me what i\'m avoiding', 'what am i avoiding',
        'i need to be pushed', 'i need accountability',
        'i\'m making excuses', 'i\'m procrastinating',
        'call me on', 'be honest with me', 'don\'t let me',
      ];
      
      // Check for support requests
      if (supportPatterns.any((pattern) => lower.contains(pattern))) {
        // If accountability/growth-pushing language → challenger
        if (challengerSupportPatterns.any((pattern) => lower.contains(pattern))) {
          return 'challenger';
        }
        // If emotional language present → therapist or companion
        if (emotionalSupportPatterns.any((pattern) => lower.contains(pattern))) {
          // High distress → therapist, moderate → companion
          if (lower.contains('can\'t cope') || lower.contains('too much') || 
              lower.contains('overwhelmed') || lower.contains('exhausted')) {
            return 'therapist';
          }
          return 'companion';
        }
        // If practical language present → strategist or companion
        if (practicalSupportPatterns.any((pattern) => lower.contains(pattern))) {
          // Clear action needed → strategist, general guidance → companion
          if (lower.contains('what steps') || lower.contains('how do i') ||
              lower.contains('figure out') || lower.contains('solve')) {
            return 'strategist';
          }
          return 'companion';
        }
        // General support request → companion (balanced, adaptive)
        return 'companion';
      }
    
    // Therapeutic questions → therapist
    final therapistPatterns = [
      'why do i', 'help me understand', 'process',
      'feel', 'emotion', 'support', 'why am i',
      'what does this mean', 'help me', 'struggling',
      'difficult', 'hard time', 'coping',
    ];
    if (therapistPatterns.any((pattern) => lower.contains(pattern))) {
      return 'therapist';
    }
    
    // Reflective/Exploratory questions → companion (default for questions)
    final companionPatterns = [
      'what do you think', 'your thoughts', 'explore',
      'reflect', 'consider', 'perspective', 'opinion',
      'what are your', 'tell me', 'share',
    ];
    if (companionPatterns.any((pattern) => lower.contains(pattern))) {
      return 'companion';
    }
    
    // No clear intent detected
    return null;
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
}

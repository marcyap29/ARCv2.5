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
import '../../../models/engagement_discipline.dart';

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
      final therapeuticAutomaticMode = await settingsService.isTherapeuticAutomaticMode();
      
      if (therapeuticEnabled) {
        if (therapeuticAutomaticMode) {
          // Automatic mode: system decides based on context
          // For now, default to supportive, but could be enhanced
          therapy['therapyMode'] = 'supportive';
        } else {
          // Manual mode: use user's selected depth level
          final depthLevel = await settingsService.getTherapeuticDepthLevel();
          if (depthLevel == 1) {
            therapy['therapyMode'] = 'supportive';
          } else if (depthLevel == 2) {
            therapy['therapyMode'] = 'supportive';
          } else if (depthLevel == 3) {
            therapy['therapyMode'] = 'deep_therapeutic';
          } else {
            therapy['therapyMode'] = 'supportive';
          }
        }
      } else {
        therapy['therapyMode'] = 'off';
      }
      
      // Override if sentinel alert is active
      if (sentinelAlert) {
        therapy['therapyMode'] = 'supportive'; // Force minimum supportive mode
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
        effectivePersona = _autoDetectPersona(state, sentinelAlert, userMessage);
      } else {
        effectivePersona = selectedPersona.name;
      }
      
      persona['selected'] = selectedPersona.name;
      persona['effective'] = effectivePersona;
      persona['isAuto'] = selectedPersona == LumaraPersona.auto;
    } catch (e) {
      print('LUMARA Control State: Error getting persona: $e');
      persona['selected'] = 'auto';
      persona['effective'] = 'companion';
      persona['isAuto'] = true;
    }
    
    state['persona'] = persona;
    
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
    
    state['responseMode'] = responseMode;

    // ============================================================
    // I. ENGAGEMENT DISCIPLINE (Response Boundaries)
    // ============================================================
    final engagement = <String, dynamic>{};

    try {
      final settingsService = LumaraReflectionSettingsService.instance;

      // Build engagement context with all necessary signals
      final engagementContext = await settingsService.buildEngagementContext(
        atlasPhase: atlas['phase'] as String? ?? 'Discovery',
        readinessScore: atlas['readinessScore'] as int? ?? 50,
        veilState: veil,
        favoritesProfile: (favorites['favoritesProfile'] as Map<String, dynamic>?) ?? {},
        sentinelAlert: sentinelAlert,
      );

      // Add engagement data to state
      engagement.addAll(engagementContext.toControlStateJson()['engagement'] as Map<String, dynamic>);

    } catch (e) {
      print('LUMARA Control State: Error building engagement context: $e');
      // Provide fallback engagement settings
      engagement.addAll({
        'mode': 'reflect',
        'synthesis_allowed': {
          'faith_work': false,
          'relationship_work': true,
          'health_emotional': true,
          'creative_intellectual': true,
        },
        'max_temporal_connections': 2,
        'max_explorative_questions': 1,
        'allow_therapeutic_language': false,
        'allow_prescriptive_guidance': false,
        'response_length': 'moderate',
        'synthesis_depth': 'moderate',
        'protected_domains': <String>[],
        'behavioral_params': {
          'engagement_intensity': 0.3,
          'explorative_tendency': 0.2,
          'synthesis_tendency': 0.1,
          'stopping_threshold': 0.7,
          'question_propensity': 0.1,
        },
      });
    }

    state['engagement'] = engagement;

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
    
    // Convert to JSON string with pretty formatting
    return const JsonEncoder.withIndent('  ').convert(state);
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
    
    double warmth = 0.6; // Base warmth
    
    if (sentinelAlert) {
      warmth = 0.8; // High warmth for safety
    }
    
    if (sleepQuality < 0.5) {
      warmth += 0.1; // Increase warmth for low sleep
    }
    
    if (favoritesProfile != null) {
      final favWarmth = favoritesProfile['warmth'] as double? ?? 0.6;
      warmth = (warmth + favWarmth) / 2; // Blend with favorites
    }
    
    if (therapyMode == 'deep_therapeutic') {
      warmth = 0.7; // Higher warmth for therapeutic mode
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
    
    double rigor = 0.5; // Base rigor
    
    if (readinessScore > 70) {
      rigor += 0.2; // Higher rigor for high readiness
    }
    
    if (sophisticationLevel == 'analytical') {
      rigor += 0.2;
    } else if (sophisticationLevel == 'simple') {
      rigor -= 0.2;
    }
    
    if (favoritesProfile != null) {
      final favRigor = favoritesProfile['rigor'] as double? ?? 0.5;
      rigor = (rigor + favRigor) / 2; // Blend with favorites
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
    
    double abstraction = 0.5; // Base abstraction
    
    if (sentinelAlert) {
      abstraction = 0.2; // Low abstraction for safety
    }
    
    if (sleepQuality < 0.5 || energyLevel < 0.5) {
      abstraction -= 0.2; // Lower abstraction for low energy/sleep
    }
    
    if (timeOfDay == 'night') {
      abstraction -= 0.1; // Lower abstraction at night
    }
    
    return abstraction.clamp(0.0, 1.0);
  }
  
  /// Compute verbosity level (0-1)
  static double _computeVerbosity(Map<String, dynamic> state) {
    final veil = state['veil'] as Map<String, dynamic>? ?? {};
    final health = veil['health'] as Map<String, dynamic>? ?? {};
    final energyLevel = health['energyLevel'] as double? ?? 0.7;
    
    double verbosity = 0.6; // Base verbosity
    
    if (energyLevel < 0.5) {
      verbosity = 0.4; // Lower verbosity for low energy
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
    
    double challenge = 0.5; // Base challenge
    
    if (sentinelAlert) {
      challenge = 0.2; // Low challenge for safety
    }
    
    if (readinessScore > 70) {
      challenge += 0.2; // Higher challenge for high readiness
    }
    
    if (sleepQuality < 0.5) {
      challenge -= 0.2; // Lower challenge for low sleep
    }
    
    if (cognitiveLoad == 'high') {
      challenge -= 0.1; // Lower challenge for high cognitive load
    } else if (cognitiveLoad == 'low') {
      challenge += 0.1; // Higher challenge for low cognitive load
    }
    
    return challenge.clamp(0.0, 1.0);
  }
  
  /// Auto-detect the best persona based on question intent first, then context signals
  static String _autoDetectPersona(Map<String, dynamic> state, bool sentinelAlert, [String? questionText]) {
    // First check question intent if provided (takes priority)
    if (questionText != null && questionText.trim().isNotEmpty) {
      final questionIntent = _detectPersonaFromQuestion(questionText);
      if (questionIntent != null) {
        print('LUMARA Control State: Detected persona from question: $questionIntent');
        return questionIntent; // Override context-based detection
      }
    }
    final atlas = state['atlas'] as Map<String, dynamic>? ?? {};
    final veil = state['veil'] as Map<String, dynamic>? ?? {};
    final therapy = state['therapy'] as Map<String, dynamic>? ?? {};
    final prism = state['prism'] as Map<String, dynamic>? ?? {};
    
    final readinessScore = atlas['readinessScore'] as int? ?? 50;
    final timeOfDay = veil['timeOfDay'] as String? ?? 'afternoon';
    final health = veil['health'] as Map<String, dynamic>? ?? {};
    final sleepQuality = health['sleepQuality'] as double? ?? 0.7;
    final energyLevel = health['energyLevel'] as double? ?? 0.7;
    final therapyMode = therapy['therapyMode'] as String? ?? 'off';
    final prismActivity = prism['prism_activity'] as Map<String, dynamic>?;
    final emotionalTone = prismActivity?['emotional_tone'] as String? ?? 'neutral';
    
    // Priority 1: Safety override - use therapist for sentinel alerts
    if (sentinelAlert) {
      return 'therapist';
    }
    
    // Priority 2: Deep therapeutic mode - use therapist
    if (therapyMode == 'deep_therapeutic') {
      return 'therapist';
    }
    
    // Priority 3: Emotional distress signals - use therapist
    if (emotionalTone == 'distressed' || emotionalTone == 'anxious' || emotionalTone == 'sad') {
      return 'therapist';
    }
    
    // Priority 4: Support requests - balance between companion/therapist, companion/strategist, and challenger
    if (questionText != null && questionText.trim().isNotEmpty) {
      final lower = questionText.toLowerCase();
      
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
          print('LUMARA Control State: Accountability support request → Challenger');
          return 'challenger';
        }
        // If emotional language present → therapist or companion
        if (emotionalSupportPatterns.any((pattern) => lower.contains(pattern))) {
          // High distress → therapist, moderate → companion
          if (lower.contains('can\'t cope') || lower.contains('too much') || 
              lower.contains('overwhelmed') || lower.contains('exhausted')) {
            print('LUMARA Control State: Emotional support request (high distress) → Therapist');
            return 'therapist';
          }
          print('LUMARA Control State: Emotional support request → Companion');
          return 'companion';
        }
        // If practical language present → strategist or companion
        if (practicalSupportPatterns.any((pattern) => lower.contains(pattern))) {
          // Clear action needed → strategist, general guidance → companion
          if (lower.contains('what steps') || lower.contains('how do i') ||
              lower.contains('figure out') || lower.contains('solve')) {
            print('LUMARA Control State: Practical support request (action needed) → Strategist');
            return 'strategist';
          }
          print('LUMARA Control State: Practical support request → Companion');
          return 'companion';
        }
        // General support request → companion (balanced, adaptive)
        print('LUMARA Control State: General support request → Companion');
        return 'companion';
      }
    }
    
    // Priority 5: Explicit advice requests (even if not caught by question detection)
    // Check question text for explicit advice patterns if available
    if (questionText != null && questionText.trim().isNotEmpty) {
      final lower = questionText.toLowerCase();
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
      
      if (explicitAdvicePatterns.any((pattern) => lower.contains(pattern))) {
        // If asking for "hard truth" or direct feedback → challenger
        if (lower.contains('hard truth') || lower.contains('be honest') || 
            lower.contains('tell me straight') || lower.contains('direct') ||
            lower.contains('what\'s wrong') || lower.contains('critique')) {
          print('LUMARA Control State: Explicit advice request detected → Challenger');
          return 'challenger';
        }
        // Otherwise → strategist for analytical/process-oriented advice
        print('LUMARA Control State: Explicit advice request detected → Strategist');
        return 'strategist';
      }
    }
    
    // Priority 6: High readiness + high energy - consider strategist or challenger
    if (readinessScore > 70 && energyLevel > 0.7) {
      // Morning with high energy = good for challenger
      if (timeOfDay == 'morning' && readinessScore > 80) {
        return 'challenger';
      }
      // Afternoon with high readiness = good for strategist
      if (timeOfDay == 'afternoon') {
        return 'strategist';
      }
    }
    
    // Priority 7: Analytical context - use strategist
    if (emotionalTone == 'analytical' || emotionalTone == 'curious') {
      return 'strategist';
    }
    
    // Priority 8: Evening/night or low energy - use companion
    if (timeOfDay == 'night' || timeOfDay == 'evening') {
      return 'companion';
    }
    
    if (sleepQuality < 0.5 || energyLevel < 0.5) {
      return 'companion';
    }
    
    // Default: companion for warm, adaptive support
    return 'companion';
  }
  
  /// Detect persona from question text using pattern matching
  static String? _detectPersonaFromQuestion(String question) {
    if (question.isEmpty) return null;
    
    final lower = question.toLowerCase();
    
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
        behavior['warmth'] = ((behavior['warmth'] as double? ?? 0.6) * 0.5 + 0.3 * 0.5).clamp(0.0, 1.0);
        behavior['rigor'] = ((behavior['rigor'] as double? ?? 0.5) * 0.5 + 0.9 * 0.5).clamp(0.0, 1.0);
        behavior['abstraction'] = ((behavior['abstraction'] as double? ?? 0.5) * 0.5 + 0.7 * 0.5).clamp(0.0, 1.0);
        behavior['challengeLevel'] = ((behavior['challengeLevel'] as double? ?? 0.5) * 0.5 + 0.7 * 0.5).clamp(0.0, 1.0);
        behavior['outputStructure'] = 'structured'; // 5-section format
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


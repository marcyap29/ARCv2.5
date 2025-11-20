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

class LumaraControlStateBuilder {
  /// Build the unified control state JSON
  /// 
  /// This combines all behavioral signals into a single JSON structure
  /// that the master prompt uses to govern LUMARA's behavior.
  static Future<String> buildControlState({
    String? userId,
    Map<String, dynamic>? prismActivity,
    Map<String, dynamic>? chronoContext,
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
    
    // Get health signals (default to neutral if not available)
    final health = <String, dynamic>{
      'sleepQuality': 0.7, // 0-1, default to moderate
      'energyLevel': 0.7, // 0-1, default to moderate
      'medicationStatus': null, // Optional flag
    };
    
    // TODO: Integrate with health tracking services when available
    // For now, use defaults
    
    veil['health'] = health;
    
    state['veil'] = veil;
    
    // ============================================================
    // C. FAVORITES (Top 25 Reinforced Signature)
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
    // Final computed behavioral parameters
    // ============================================================
    // These are derived from the above signals
    final behavior = <String, dynamic>{
      'toneMode': _computeToneMode(state),
      'warmth': _computeWarmth(state),
      'rigor': _computeRigor(state),
      'abstraction': _computeAbstraction(state),
      'verbosity': _computeVerbosity(state),
      'challengeLevel': _computeChallengeLevel(state),
    };
    
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
}


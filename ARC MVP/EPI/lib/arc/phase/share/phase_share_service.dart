// lib/arc/phase/share/phase_share_service.dart
// Service for managing phase sharing functionality

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/phase_models.dart';
import '../../../services/phase_regime_service.dart';
import 'phase_share_models.dart';
import 'phase_share_image_generator.dart';
import 'phase_share_privacy_validator.dart';

/// Service for phase sharing functionality
class PhaseShareService {
  static const String _sharePromptsEnabledKey = 'phase_share_prompts_enabled';
  static const String _hasSharedBeforeKey = 'phase_share_has_shared_before';
  static const String _shareConsentKey = 'phase_share_consent_given';

  static final PhaseShareService _instance = PhaseShareService._internal();
  factory PhaseShareService() => _instance;
  static PhaseShareService get instance => _instance;
  PhaseShareService._internal();

  /// Check if share prompts are enabled
  Future<bool> areSharePromptsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sharePromptsEnabledKey) ?? true;
  }

  /// Set share prompts enabled/disabled
  Future<void> setSharePromptsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sharePromptsEnabledKey, enabled);
  }

  /// Check if user has shared before
  Future<bool> hasSharedBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSharedBeforeKey) ?? false;
  }

  /// Mark that user has shared
  Future<void> markAsShared() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSharedBeforeKey, true);
  }

  /// Check if user has given consent
  Future<bool> hasGivenConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_shareConsentKey) ?? false;
  }

  /// Record user consent
  Future<void> recordConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shareConsentKey, true);
  }

  /// Get phase timeline data for last 6 months
  Future<List<PhaseTimelineData>> getTimelineData({
    required PhaseRegimeService phaseRegimeService,
    DateTime? currentDate,
  }) async {
    final now = currentDate ?? DateTime.now();
    final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
    
    final regimes = phaseRegimeService.phaseIndex.allRegimes
        .where((regime) {
          final regimeEnd = regime.end;
          if (regimeEnd == null) {
            return regime.start.isAfter(sixMonthsAgo) || regime.start.isBefore(now);
          }
          return regimeEnd.isAfter(sixMonthsAgo) || regime.start.isAfter(sixMonthsAgo);
        })
        .toList();

    // Sort by start date
    regimes.sort((a, b) => a.start.compareTo(b.start));

    // Convert to timeline data
    return regimes.map((regime) {
      final start = regime.start.isBefore(sixMonthsAgo) ? sixMonthsAgo : regime.start;
      final regimeEnd = regime.end;
      final end = regimeEnd != null && regimeEnd.isAfter(now) ? now : regimeEnd;
      
      return PhaseTimelineData(
        phase: regime.label,
        start: start,
        end: end,
        color: _getPhaseColor(regime.label),
      );
    }).toList();
  }

  /// Get phase count for a specific phase
  Future<int?> getPhaseCount({
    required PhaseRegimeService phaseRegimeService,
    required PhaseLabel phase,
  }) async {
    final regimes = phaseRegimeService.phaseIndex.allRegimes
        .where((regime) => regime.label == phase)
        .toList();
    
    if (regimes.isEmpty) return null;
    return regimes.length;
  }

  /// Get duration of previous phase
  Future<Duration?> getPreviousPhaseDuration({
    required PhaseRegimeService phaseRegimeService,
    required DateTime transitionDate,
  }) async {
    final regimes = phaseRegimeService.phaseIndex.allRegimes
        .where((regime) => 
            regime.end != null && 
            regime.end!.isBefore(transitionDate) &&
            regime.end!.isAfter(transitionDate.subtract(const Duration(days: 30))))
        .toList();

    if (regimes.isEmpty) return null;

    // Get the most recent completed regime before transition
    regimes.sort((a, b) => (b.end ?? DateTime.now()).compareTo(a.end ?? DateTime.now()));
    final previousRegime = regimes.first;

    if (previousRegime.end == null) return null;
    return previousRegime.end!.difference(previousRegime.start);
  }

  /// Generate share image
  Future<Uint8List> generateShareImage(
    PhaseShare share,
    SharePlatform platform,
  ) async {
    return await PhaseShareImageGenerator.generateImage(share, platform);
  }

  /// Validate share data
  ValidationResult validateShare(PhaseShare share) {
    return PhaseSharePrivacyValidator.validateShareData(share);
  }

  /// Get phase color
  static Color _getPhaseColor(PhaseLabel label) {
    switch (label) {
      case PhaseLabel.discovery:
        return const Color(0xFF7C3AED);
      case PhaseLabel.expansion:
        return const Color(0xFF059669);
      case PhaseLabel.transition:
        return const Color(0xFFD97706);
      case PhaseLabel.consolidation:
        return const Color(0xFF2563EB);
      case PhaseLabel.recovery:
        return const Color(0xFFDC2626);
      case PhaseLabel.breakthrough:
        return const Color(0xFFFBBF24);
    }
  }
}


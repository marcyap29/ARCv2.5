/// Centralized service for calculating operational readiness ratings
/// Combines phase detection with health data to produce 10-100 readiness scores
import 'package:my_app/services/phase_rating_ranges.dart';
import 'package:my_app/services/health_data_service.dart';
import 'package:my_app/services/phase_aware_analysis_service.dart';

class PhaseRatingService {
  /// Calculate operational readiness score (10-100) from phase context
  /// 
  /// This is the main method for getting a readiness rating. It combines:
  /// - Base phase rating (from phase range + confidence)
  /// - Health adjustments (sleep quality + energy level)
  /// 
  /// Returns a score from 10-100 where:
  /// - Lower scores (10-30) indicate need for rest/recovery
  /// - Higher scores (70-100) indicate readiness for duty
  static int calculateReadinessScore(PhaseContext context) {
    return context.operationalReadinessScore;
  }

  /// Get rating interpretation for commander dashboard
  /// 
  /// Provides human-readable interpretation of the readiness score
  /// for military commanders to understand personnel status.
  static String getReadinessInterpretation(int score) {
    if (score >= 85) {
      return 'Peak Performance - Ready for high-stress operations';
    } else if (score >= 70) {
      return 'High Readiness - Ready for standard operational duties';
    } else if (score >= 50) {
      return 'Moderate Readiness - Suitable for moderate tasks';
    } else if (score >= 30) {
      return 'Low Readiness - May need support or reduced tempo';
    } else {
      return 'Recovery Needed - Requires rest, medical attention, or reduced duties';
    }
  }

  /// Get readiness category (for color coding in UI)
  static ReadinessCategory getReadinessCategory(int score) {
    if (score >= 85) {
      return ReadinessCategory.excellent;
    } else if (score >= 70) {
      return ReadinessCategory.good;
    } else if (score >= 50) {
      return ReadinessCategory.moderate;
    } else if (score >= 30) {
      return ReadinessCategory.low;
    } else {
      return ReadinessCategory.critical;
    }
  }

  /// Calculate health-adjusted rating manually (for testing/debugging)
  /// 
  /// This method can be used to calculate ratings outside of PhaseContext
  static int calculateHealthAdjustedRating({
    required UserPhase phase,
    required double confidence,
    HealthData? healthData,
  }) {
    // Base rating from phase range + confidence
    final baseRating = PhaseRatingRanges.getRating(phase.name, confidence);

    // Apply health adjustment if health data is available
    if (healthData != null) {
      final healthFactor = (healthData.sleepQuality + healthData.energyLevel) / 2.0;
      
      if (healthFactor < 0.4) {
        // Poor health: Reduce rating by up to 20 points
        final reduction = (20 * (0.4 - healthFactor) / 0.4).round();
        return (baseRating - reduction).clamp(10, 100);
      } else if (healthFactor > 0.8) {
        // Excellent health: Boost rating by up to 10 points (cap at 100)
        final boost = (10 * (healthFactor - 0.8) / 0.2).round();
        return (baseRating + boost).clamp(10, 100);
      } else {
        // Moderate health: No adjustment
        return baseRating;
      }
    }

    // No health data, return base rating
    return baseRating;
  }
}

/// Readiness categories for UI color coding
enum ReadinessCategory {
  excellent,  // 85-100: Green
  good,        // 70-84: Light green
  moderate,    // 50-69: Yellow
  low,         // 30-49: Orange
  critical,    // 10-29: Red
}


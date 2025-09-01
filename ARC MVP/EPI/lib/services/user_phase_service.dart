import 'package:hive/hive.dart';
import 'package:my_app/core/models/arcform_snapshot.dart';
import 'package:my_app/features/arcforms/arcform_mvp_implementation.dart';

/// Service to manage the user's current ATLAS phase
class UserPhaseService {
  static const String _snapshotsBoxName = 'arcform_snapshots';
  
  /// Get the user's current phase from the most recent Arcform snapshot
  static Future<String> getCurrentPhase() async {
    try {
      final box = await Hive.openBox<ArcformSnapshot>(_snapshotsBoxName);
      
      if (box.isEmpty) {
        // No snapshots yet, default to Discovery for first-time users
        return 'Discovery';
      }
      
      // Get all snapshots and find the most recent one
      final allSnapshots = box.values.toList();
      allSnapshots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      final mostRecent = allSnapshots.first;
      return mostRecent.phase;
      
    } catch (e) {
      // Fallback to Discovery if there's any error
      return 'Discovery';
    }
  }
  
  /// Get the geometry pattern corresponding to a phase
  static ArcformGeometry getGeometryForPhase(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return ArcformGeometry.spiral;
      case 'expansion':
        return ArcformGeometry.flower;
      case 'transition':
        return ArcformGeometry.branch;
      case 'consolidation':
        return ArcformGeometry.weave;
      case 'recovery':
        return ArcformGeometry.glowCore;
      case 'breakthrough':
        return ArcformGeometry.fractal;
      default:
        return ArcformGeometry.spiral; // Default to Discovery
    }
  }
  
  /// Get the most recent Arcform snapshot for rendering
  static Future<ArcformSnapshot?> getMostRecentSnapshot() async {
    try {
      final box = await Hive.openBox<ArcformSnapshot>(_snapshotsBoxName);
      
      if (box.isEmpty) {
        return null;
      }
      
      // Get all snapshots and find the most recent one
      final allSnapshots = box.values.toList();
      allSnapshots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return allSnapshots.first;
      
    } catch (e) {
      return null;
    }
  }
  
  /// Check if user has consented to their current phase
  static Future<bool> hasUserConsentedToCurrentPhase() async {
    final snapshot = await getMostRecentSnapshot();
    return snapshot?.userConsentedPhase ?? false;
  }
  
  /// Get a user-friendly description of the current phase
  static String getPhaseDescription(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return 'Exploring new ground; curiosity leads you.';
      case 'expansion':
        return 'Growing outward; energy and possibility.';
      case 'transition':
        return 'Moving between states; navigating change.';
      case 'consolidation':
        return 'Integrating wisdom; finding your center.';
      case 'recovery':
        return 'Healing and restoration; gentle renewal.';
      case 'breakthrough':
        return 'Transcending limits; quantum leaps forward.';
      default:
        return 'Your current phase in the journey.';
    }
  }
  
  /// Get the recommendation rationale for the current phase
  static Future<String?> getCurrentPhaseRationale() async {
    final snapshot = await getMostRecentSnapshot();
    return snapshot?.recommendationRationale;
  }
}
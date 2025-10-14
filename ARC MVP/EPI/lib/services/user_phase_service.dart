import 'package:hive/hive.dart';
import 'package:my_app/core/models/arcform_snapshot.dart';
import 'package:my_app/features/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/models/user_profile_model.dart';

/// Service to manage the user's current ATLAS phase
class UserPhaseService {
  static const String _snapshotsBoxName = 'arcform_snapshots';
  
  /// Helper method to get user profile safely
  static Future<UserProfile?> _getUserProfile() async {
    try {
      Box<UserProfile> userBox;
      if (Hive.isBoxOpen('user_profile')) {
        userBox = Hive.box<UserProfile>('user_profile');
      } else {
        userBox = await Hive.openBox<UserProfile>('user_profile');
      }
      return userBox.get('profile');
    } catch (e) {
      print('DEBUG: Error getting user profile: $e');
      return null;
    }
  }
  
  /// Get the user's current phase, prioritizing UserProfile over snapshots
  static Future<String> getCurrentPhase() async {
    try {
      // Always check UserProfile first - this is the authoritative source
      final userProfile = await _getUserProfile();
      
      if (userProfile?.onboardingCurrentSeason != null && 
          userProfile!.onboardingCurrentSeason!.isNotEmpty) {
        print('DEBUG: Using phase from UserProfile: ${userProfile.onboardingCurrentSeason}');
        return userProfile.onboardingCurrentSeason!;
      }
      
      // Only fall back to snapshots if no UserProfile phase exists
      // AND the user has completed onboarding (to avoid using stale data)
      if (userProfile?.onboardingCompleted == true) {
        print('DEBUG: User completed onboarding but no phase set, checking snapshots');
        
        Box<ArcformSnapshot> box;
        if (Hive.isBoxOpen(_snapshotsBoxName)) {
          box = Hive.box<ArcformSnapshot>(_snapshotsBoxName);
        } else {
          box = await Hive.openBox<ArcformSnapshot>(_snapshotsBoxName);
        }
        
        if (box.isNotEmpty) {
          // Get all snapshots and find the most recent one
          final allSnapshots = box.values.toList();
          allSnapshots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          final mostRecent = allSnapshots.first;
          print('DEBUG: Using phase from arcform snapshot: ${mostRecent.phase}');
          return mostRecent.phase;
        }
      }
      
      // NEW RULE: Auto-default to Discovery if no phase is found
      // This handles cases where user skipped quiz or system couldn't determine phase
      print('DEBUG: No phase found, auto-defaulting to Discovery');
      return 'Discovery';
      
    } catch (e) {
      print('DEBUG: Error getting current phase: $e');
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
      Box<ArcformSnapshot> box;
      if (Hive.isBoxOpen(_snapshotsBoxName)) {
        box = Hive.box<ArcformSnapshot>(_snapshotsBoxName);
      } else {
        box = await Hive.openBox<ArcformSnapshot>(_snapshotsBoxName);
      }
      
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
  
  /// Validate that a phase selection was properly saved
  static Future<bool> validatePhaseSelection(String expectedPhase) async {
    try {
      final currentPhase = await getCurrentPhase();
      final isValid = currentPhase == expectedPhase;
      
      if (isValid) {
        print('DEBUG: Phase selection validated: $expectedPhase');
      } else {
        print('DEBUG: Phase selection validation failed: expected $expectedPhase, got $currentPhase');
      }
      
      return isValid;
    } catch (e) {
      print('DEBUG: Error validating phase selection: $e');
      return false;
    }
  }
  
  /// Force update the user's phase (useful for debugging)
  static Future<bool> forceUpdatePhase(String newPhase) async {
    try {
      final userProfile = await _getUserProfile();
      if (userProfile == null) {
        print('DEBUG: Cannot update phase - no user profile found');
        return false;
      }
      
      final updatedProfile = userProfile.copyWith(
        onboardingCurrentSeason: newPhase,
      );
      
      Box<UserProfile> userBox;
      if (Hive.isBoxOpen('user_profile')) {
        userBox = Hive.box<UserProfile>('user_profile');
      } else {
        userBox = await Hive.openBox<UserProfile>('user_profile');
      }
      
      await userBox.put('profile', updatedProfile);
      print('DEBUG: Force updated phase to: $newPhase');
      return true;
    } catch (e) {
      print('DEBUG: Error force updating phase: $e');
      return false;
    }
  }
}
import 'package:hive/hive.dart';
import 'package:my_app/core/models/arcform_snapshot.dart';
import 'package:my_app/arc/ui/arcforms/arcform_mvp_implementation.dart';
import 'package:my_app/models/user_profile_model.dart';

/// Service to manage the user's current ATLAS phase.
///
/// **SOP – Phase determination (display):**
/// 1. **RIVET activity (1a):** If RIVET gate is open and a phase regime exists, use that phase.
/// 2. **Phase quiz result (1b):** If not from 1a, use UserProfile/quiz phase when set.
/// 3. **Default (new user / skipped quiz):** If neither 1a nor 1b, use Discovery until RIVET has enough activity.
/// Display this phase on startup (spin) and in the timeline phase preview.
class UserPhaseService {
  static const String _snapshotsBoxName = 'arcform_snapshots';
  
  /// Returns the phase to display everywhere (splash, timeline preview).
  /// SOP: 1a RIVET (when gate open + regime), else 1b quiz result, else Discovery.
  static String getDisplayPhase({
    String? regimePhase,
    required bool rivetGateOpen,
    required String profilePhase,
  }) {
    if (rivetGateOpen && regimePhase != null && regimePhase.trim().isNotEmpty) {
      return regimePhase.trim();
    }
    if (profilePhase.trim().isNotEmpty) {
      return profilePhase.trim();
    }
    return 'Discovery';
  }
  
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
      // Fallback: currentPhase (set with onboardingCurrentSeason in forceUpdatePhase)
      if (userProfile?.currentPhase != null && userProfile!.currentPhase.isNotEmpty) {
        print('DEBUG: Using phase from UserProfile.currentPhase: ${userProfile.currentPhase}');
        return userProfile.currentPhase;
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
      
      // No default: quiz is the starting phase; if no phase is found, return empty.
      // RIVET/regimes fill out over time; gate open determines a new phase after the starting one.
      print('DEBUG: No phase found (quiz is starting phase; no phase set yet)');
      return '';
      
    } catch (e) {
      print('DEBUG: Error getting current phase: $e');
      return '';
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
      Box<UserProfile> userBox;
      if (Hive.isBoxOpen('user_profile')) {
        userBox = Hive.box<UserProfile>('user_profile');
      } else {
        userBox = await Hive.openBox<UserProfile>('user_profile');
      }
      
      final userProfile = await _getUserProfile();
      
      UserProfile updatedProfile;
      if (userProfile == null) {
        // Create a new profile with the phase if none exists
        print('DEBUG: No user profile found, creating one with phase: $newPhase');
        updatedProfile = UserProfile(
          id: 'default_user',
          name: 'User',
          email: '',
          createdAt: DateTime.now(),
          preferences: const {},
          onboardingCurrentSeason: newPhase,
          currentPhase: newPhase,
          onboardingCompleted: false,
          lastPhaseChangeAt: DateTime.now(),
        );
      } else {
        updatedProfile = userProfile.copyWith(
          onboardingCurrentSeason: newPhase,
          currentPhase: newPhase,
          lastPhaseChangeAt: DateTime.now(),
        );
      }
      
      await userBox.put('profile', updatedProfile);
      print('DEBUG: Force updated phase to: $newPhase');
      return true;
    } catch (e) {
      print('DEBUG: Error force updating phase: $e');
      return false;
    }
  }

  /// Set onboarding as completed in UserProfile (so splash screen goes to HomeView on next launch).
  static Future<bool> setOnboardingCompleted(bool value) async {
    try {
      final userProfile = await _getUserProfile();
      if (userProfile == null) return false;
      final updatedProfile = userProfile.copyWith(onboardingCompleted: value);
      Box<UserProfile> userBox;
      if (Hive.isBoxOpen('user_profile')) {
        userBox = Hive.box<UserProfile>('user_profile');
      } else {
        userBox = await Hive.openBox<UserProfile>('user_profile');
      }
      await userBox.put('profile', updatedProfile);
      return true;
    } catch (e) {
      print('DEBUG: Error setting onboardingCompleted: $e');
      return false;
    }
  }
}
import 'package:hive/hive.dart';
import 'package:my_app/main/bootstrap.dart';
import 'package:my_app/models/user_profile_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Maps Chronicle / profile data to an internal Agents persona key (not shown in UI).
/// Set [UserProfile.preferences]\['chronicle_profession'] to
/// `founder` | `student` | `coach` | `artist` from onboarding or profile fields.
class AgentsPersonaResolver {
  AgentsPersonaResolver._();

  static const String chronicleProfessionKey = 'chronicle_profession';

  /// Secure profile form keys ([UserProfileService]) — synced to Hive for Agents routing.
  static const String agentsRoleFormKey = 'agents_role';
  static const String schoolOrProfessionFormKey = 'school_or_profession';

  /// Cached from My Profile when Hive [UserProfile] is not yet available.
  static const String prefsChronicleProfessionKey = 'lumara_chronicle_profession';

  static const Set<String> _validKeys = {
    'founder',
    'student',
    'coach',
    'artist',
  };

  /// Returns a key present in [AgentsData.personas], defaulting to `founder`.
  static String resolvePersonaKey() {
    try {
      if (!Hive.isBoxOpen(Boxes.userProfile)) return 'founder';
      final box = Hive.box<UserProfile>(Boxes.userProfile);
      final profile = box.get('profile');
      if (profile == null) return 'founder';

      final raw = profile.preferences[chronicleProfessionKey]?.toString().trim().toLowerCase();
      if (raw != null && raw.isNotEmpty) {
        if (_validKeys.contains(raw)) return raw;
        for (final k in _validKeys) {
          if (raw.contains(k)) return k;
        }
      }

      final school = profile.preferences[schoolOrProfessionFormKey]?.toString().trim().toLowerCase() ?? '';
      if (school.isNotEmpty) {
        for (final k in _validKeys) {
          if (school.contains(k)) return k;
        }
      }

      final purpose = profile.onboardingPurpose?.toLowerCase() ?? '';
      if (purpose.contains('coach')) return 'coach';
      if (purpose.contains('artist') || purpose.contains('creative')) return 'artist';
      if (purpose.contains('student') || purpose.contains('reflection')) return 'student';
      if (purpose.contains('founder') ||
          purpose.contains('growth') ||
          purpose.contains('recovery')) {
        return 'founder';
      }
    } catch (_) {
      /* Hive may be unavailable in tests */
    }
    return 'founder';
  }

  /// Prefer this for UI: checks SharedPreferences (set from My Profile) then [resolvePersonaKey].
  static Future<String> resolvePersonaKeyResolved() async {
    final prefs = await SharedPreferences.getInstance();
    final sp = prefs.getString(prefsChronicleProfessionKey)?.trim().toLowerCase();
    if (sp != null && sp.isNotEmpty && _validKeys.contains(sp)) {
      return sp;
    }
    return resolvePersonaKey();
  }

  /// Writes role + school/company text from My Profile into [UserProfile.preferences] for Agents.
  static Future<void> syncFormFieldsToHive(Map<String, String> profileFields) async {
    try {
      if (!Hive.isBoxOpen(Boxes.userProfile)) return;
      final box = Hive.box<UserProfile>(Boxes.userProfile);
      final profile = box.get('profile');
      if (profile == null) return;
      final prefs = Map<String, dynamic>.from(profile.preferences);
      final role = profileFields[agentsRoleFormKey]?.trim().toLowerCase();
      if (role != null && role.isNotEmpty && _validKeys.contains(role)) {
        prefs[chronicleProfessionKey] = role;
      } else {
        prefs.remove(chronicleProfessionKey);
      }
      final school = profileFields[schoolOrProfessionFormKey]?.trim();
      if (school != null && school.isNotEmpty) {
        prefs[schoolOrProfessionFormKey] = school;
      } else {
        prefs.remove(schoolOrProfessionFormKey);
      }
      await box.put('profile', profile.copyWith(preferences: prefs));
    } catch (_) {}

    final prefsStore = await SharedPreferences.getInstance();
    final role = profileFields[agentsRoleFormKey]?.trim().toLowerCase();
    if (role != null && role.isNotEmpty && _validKeys.contains(role)) {
      await prefsStore.setString(prefsChronicleProfessionKey, role);
    } else {
      await prefsStore.remove(prefsChronicleProfessionKey);
    }
  }
}

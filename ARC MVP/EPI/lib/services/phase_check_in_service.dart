// Phase Check-in service: monthly phase recalibration (confirm or run diagnostic).

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/models/phase_check_in_model.dart';
import 'package:my_app/models/user_profile_model.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/services/phase_service_registry.dart';
import 'package:my_app/prism/atlas/rivet/rivet_provider.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';
import 'package:my_app/chronicle/core/chronicle_repos.dart';
import 'package:my_app/services/firebase_auth_service.dart';

const String _boxName = 'phase_check_ins';
const String _prefDismissedAt = 'phase_check_in_dismissed_at';
const String _prefReminderEnabled = 'phase_check_in_reminder_enabled';
const String _prefIntervalDays = 'phase_check_in_interval_days';
const int _defaultDaysBetweenCheckIns = 30;
const int _daysBeforeReShowAfterDismiss = 7;

/// Service for monthly Phase Check-in: confirm current phase or run 3-question diagnostic.
class PhaseCheckInService {
  PhaseCheckInService._();
  static final PhaseCheckInService instance = PhaseCheckInService._();

  static String get _userId =>
      FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';

  Future<Box<PhaseCheckIn>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<PhaseCheckIn>(_boxName);
    }
    return Hive.openBox<PhaseCheckIn>(_boxName);
  }

  /// True if reminder is enabled (user preference).
  Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefReminderEnabled) ?? true;
  }

  /// Set whether the automatic Phase Check-in reminder is shown when due.
  Future<void> setReminderEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefReminderEnabled, value);
  }

  /// Get the configured interval (days between check-ins). Default 30; allowed 14, 30, 60.
  Future<int> getIntervalDays() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_prefIntervalDays);
    if (v == null) return _defaultDaysBetweenCheckIns;
    if (v == 14 || v == 30 || v == 60) return v;
    return _defaultDaysBetweenCheckIns;
  }

  /// Set interval (days) between check-ins. Use 14, 30, or 60.
  Future<void> setIntervalDays(int days) async {
    if (days != 14 && days != 30 && days != 60) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefIntervalDays, days);
  }

  /// True if a check-in is due: reminder enabled, N days since last completed check-in (or account creation),
  /// and either not dismissed or dismissed 7+ days ago. N = user-configured interval.
  Future<bool> isCheckInDue() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefReminderEnabled) == false) return false;
    final dismissedAtMillis = prefs.getInt(_prefDismissedAt);
    if (dismissedAtMillis != null) {
      final dismissedAt = DateTime.fromMillisecondsSinceEpoch(dismissedAtMillis);
      if (DateTime.now().difference(dismissedAt).inDays < _daysBeforeReShowAfterDismiss) {
        return false;
      }
    }

    final intervalDays = await getIntervalDays();
    final lastDue = await _getLastCheckInNextDue();
    if (lastDue != null) {
      return DateTime.now().isAfter(lastDue) || !lastDue.difference(DateTime.now()).isNegative;
    }
    // No check-in yet: due after interval days from account creation
    final createdAt = await _getAccountCreatedAt();
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt).inDays >= intervalDays;
  }

  Future<DateTime?> _getLastCheckInNextDue() async {
    final box = await _openBox();
    final forUser = box.values
        .where((c) => c.userId == _userId)
        .where((c) => c.nextCheckInDue != null)
        .toList();
    if (forUser.isEmpty) return null;
    forUser.sort((a, b) => (b.nextCheckInDue!).compareTo(a.nextCheckInDue!));
    return forUser.first.nextCheckInDue;
  }

  /// Account creation date for "30 days since account creation" when no check-in yet.
  Future<DateTime?> _getAccountCreatedAt() async {
    try {
      Box<UserProfile> userBox;
      if (Hive.isBoxOpen('user_profile')) {
        userBox = Hive.box<UserProfile>('user_profile');
      } else {
        userBox = await Hive.openBox<UserProfile>('user_profile');
      }
      return userBox.get('profile')?.createdAt;
    } catch (_) {
      return null;
    }
  }

  /// Current phase for confirmation screen (display name).
  /// Uses same logic as Phase page: profile first, then regime; RIVET gate respected.
  Future<String> getCurrentPhaseName() async {
    final display = await getDisplayPhaseName();
    return display.isEmpty ? 'Discovery' : display;
  }

  /// Display phase name using same source as Phase page (profile first, then regime).
  Future<String> getDisplayPhaseName() async {
    try {
      final profile = await _getUserProfile();
      final profilePhase = profile?.onboardingCurrentSeason?.trim() ??
          profile?.currentPhase.trim() ??
          '';

      String? regimePhase;
      bool rivetGateOpen = false;
      try {
        final regimeService = await PhaseServiceRegistry.phaseRegimeService;
        final index = regimeService.phaseIndex;
        final currentRegime = index.currentRegime;
        if (currentRegime != null) {
          regimePhase = _phaseLabelToName(currentRegime.label);
        } else if (index.allRegimes.isNotEmpty) {
          final sorted = List<PhaseRegime>.from(index.allRegimes)
            ..sort((a, b) => b.start.compareTo(a.start));
          regimePhase = _phaseLabelToName(sorted.first.label);
        }
        final rivetProvider = RivetProvider();
        if (!rivetProvider.isAvailable) {
          await rivetProvider.initialize(_userId);
        }
        rivetGateOpen = rivetProvider.service?.wouldGateOpen() ?? false;
      } catch (_) {
        // Regime/RIVET optional; fall back to profile
      }

      final raw = UserPhaseService.getDisplayPhase(
        regimePhase: regimePhase,
        rivetGateOpen: rivetGateOpen,
        profilePhase: profilePhase,
      );
      if (raw.isEmpty) return '';
      return raw.substring(0, 1).toUpperCase() + raw.substring(1).toLowerCase();
    } catch (_) {
      return '';
    }
  }

  static Future<UserProfile?> _getUserProfile() async {
    try {
      Box<UserProfile> userBox;
      if (Hive.isBoxOpen('user_profile')) {
        userBox = Hive.box<UserProfile>('user_profile');
      } else {
        userBox = await Hive.openBox<UserProfile>('user_profile');
      }
      return userBox.get('profile');
    } catch (_) {
      return null;
    }
  }

  static String _phaseLabelToName(PhaseLabel label) {
    final name = label.name;
    return name.substring(0, 1).toUpperCase() + name.substring(1).toLowerCase();
  }

  /// User confirmed "Yes, this fits". Log check-in and reset timer per configured interval.
  Future<void> confirmPhase(String phaseName) async {
    final box = await _openBox();
    final normalized = _normalizePhaseName(phaseName);
    final intervalDays = await getIntervalDays();
    final nextDue = DateTime.now().add(Duration(days: intervalDays));
    final checkIn = PhaseCheckIn(
      id: '${_userId}_${DateTime.now().millisecondsSinceEpoch}',
      userId: _userId,
      checkInDate: DateTime.now(),
      previousPhase: normalized,
      confirmedPhase: normalized,
      wasConfirmed: true,
      wasRecalibrated: false,
      nextCheckInDue: nextDue,
    );
    await box.add(checkIn);
    await _clearDismissedPref();
  }

  /// Process diagnostic answers (Q1–Q3) and return suggested phase name.
  /// Uses simple voting: each answer maps to a phase, return majority; tie → current phase.
  Future<String> processDiagnostic(Map<String, String> answers) async {
    const focusMap = {
      'recovering': 'Recovery',
      'exploring': 'Discovery',
      'building': 'Expansion',
      'breakthrough': 'Breakthrough',
      'integrating': 'Consolidation',
      'maintaining': 'Consolidation',
    };
    const workMap = {
      'healing': 'Recovery',
      'exploratory': 'Discovery',
      'building': 'Expansion',
      'transformative': 'Breakthrough',
      'expansive': 'Expansion',
      'maintenance': 'Consolidation',
    };
    const energyMap = {
      'limited': 'Recovery',
      'scattered': 'Transition',
      'focused': 'Expansion',
      'surging': 'Breakthrough',
      'steady': 'Expansion',
      'calm': 'Consolidation',
    };

    final votes = <String, int>{};
    void add(String? key, Map<String, String> map) {
      if (key == null) return;
      final phase = map[key];
      if (phase != null) votes[phase] = (votes[phase] ?? 0) + 1;
    }
    add(answers['q1'], focusMap);
    add(answers['q2'], workMap);
    add(answers['q3'], energyMap);

    if (votes.isEmpty) return await getCurrentPhaseName();
    final sorted = votes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  /// Apply phase change from check-in: update profile, optionally log to changelog, save check-in record.
  Future<void> updatePhaseFromCheckIn({
    required String newPhaseName,
    required String previousPhaseName,
    required bool wasManualOverride,
    String? reason,
    Map<String, dynamic>? diagnosticAnswers,
  }) async {
    final normalized = _normalizePhaseName(newPhaseName);
    await UserPhaseService.forceUpdatePhase(normalized);

    final box = await _openBox();
    final intervalDays = await getIntervalDays();
    final nextDue = DateTime.now().add(Duration(days: intervalDays));
    final checkIn = PhaseCheckIn(
      id: '${_userId}_${DateTime.now().millisecondsSinceEpoch}',
      userId: _userId,
      checkInDate: DateTime.now(),
      previousPhase: previousPhaseName,
      confirmedPhase: normalized,
      wasConfirmed: false,
      wasRecalibrated: diagnosticAnswers != null,
      diagnosticAnswers: diagnosticAnswers,
      wasManualOverride: wasManualOverride,
      manualOverrideReason: reason,
      nextCheckInDue: nextDue,
    );
    await box.add(checkIn);

    try {
      final changelogRepo = ChronicleRepos.changelog;
      await changelogRepo.log(
        userId: _userId,
        layer: ChronicleLayer.layer0,
        action: 'phase_updated',
        metadata: {
          'source': 'check_in',
          'previous_phase': previousPhaseName,
          'new_phase': normalized,
          'was_manual_override': wasManualOverride,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
    } catch (e) {
      debugPrint('PhaseCheckInService: changelog log failed: $e');
    }
    await _clearDismissedPref();
  }

  /// Record that user dismissed the check-in (will re-show after 7 days).
  Future<void> recordDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefDismissedAt, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _clearDismissedPref() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefDismissedAt);
  }

  /// Full check-in history for this user.
  Future<List<PhaseCheckIn>> getCheckInHistory() async {
    final box = await _openBox();
    final list = box.values.where((c) => c.userId == _userId).toList();
    list.sort((a, b) => b.checkInDate.compareTo(a.checkInDate));
    return list;
  }

  static String _normalizePhaseName(String name) {
    final t = name.trim();
    if (t.isEmpty) return 'Discovery';
    return t.substring(0, 1).toUpperCase() + t.substring(1).toLowerCase();
  }
}

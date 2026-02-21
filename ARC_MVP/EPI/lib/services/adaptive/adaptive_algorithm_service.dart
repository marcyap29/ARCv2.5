import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/services/adaptive/user_cadence_detector.dart';
import 'package:my_app/services/adaptive/adaptive_config.dart';
import 'package:my_app/services/adaptive/adaptive_sentinel_calculator.dart';

/// Orchestration service for adaptive algorithms
class AdaptiveAlgorithmService {

  UserCadenceProfile? _cachedProfile;
  AdaptiveConfig? _currentConfig;
  AdaptiveSentinelCalculator? _sentinelCalc;

  static final _firestore = FirebaseFirestore.instance;

  AdaptiveAlgorithmService();

  /// Initialize service for a user
  Future<void> initialize(String userId) async {
    // Load cached profile from storage
    _cachedProfile = await _loadCadenceProfile(userId);

    if (_cachedProfile != null) {
      _currentConfig = AdaptiveConfig.forUserType(_cachedProfile!.currentType);
      _sentinelCalc = AdaptiveSentinelCalculator(_currentConfig!.sentinel);
    } else {
      // First time user - default to weekly (most forgiving)
      _currentConfig = AdaptiveConfig.forUserType(UserType.insufficientData);
      _sentinelCalc = AdaptiveSentinelCalculator(_currentConfig!.sentinel);
    }
  }

  /// Update cadence if needed
  Future<void> updateCadenceIfNeeded(
    String userId,
    List<JournalEntry> allEntries,
  ) async {
    if (_cachedProfile == null) {
      // First calculation
      await _recalculateCadence(userId, allEntries);
      return;
    }

    final newEntriesSinceCalc =
        allEntries.length - _cachedProfile!.entriesAtLastCalculation;

    if (UserTypeClassifier.shouldRecalculate(newEntriesSinceCalc)) {
      await _recalculateCadence(userId, allEntries);
    }
  }

  /// Recalculate user cadence
  Future<void> _recalculateCadence(
    String userId,
    List<JournalEntry> allEntries,
  ) async {
    final metrics = UserCadenceDetector.calculateCadence(allEntries);
    final newType = UserTypeClassifier.classifyUser(metrics);

    final oldType = _cachedProfile?.currentType;

    // Create new profile
    final history = List<UserTypeTransition>.from(_cachedProfile?.typeHistory ?? []);

    if (oldType != null && oldType != newType) {
      history.add(UserTypeTransition(
        fromType: oldType,
        toType: newType,
        transitionDate: DateTime.now(),
        totalEntriesAtTransition: allEntries.length,
      ));
    }

    _cachedProfile = UserCadenceProfile(
      currentType: newType,
      metrics: metrics,
      lastCalculated: DateTime.now(),
      entriesAtLastCalculation: allEntries.length,
      typeHistory: history,
    );

    // Save to storage
    await _saveCadenceProfile(userId, _cachedProfile!);

    // Update config if type changed
    if (oldType != newType) {
      await _transitionToNewConfig(newType);
    }
  }

  /// Transition to new configuration
  Future<void> _transitionToNewConfig(UserType newType) async {
    final newConfig = AdaptiveConfig.forUserType(newType);

    // For now, immediately switch (can add gradual transition later)
    _currentConfig = newConfig;
    _sentinelCalc = AdaptiveSentinelCalculator(_currentConfig!.sentinel);
  }

  /// Calculate emotional density
  double calculateEmotionalDensity(JournalEntry entry) {
    if (_sentinelCalc == null) {
      throw StateError('Service not initialized. Call initialize() first.');
    }
    return _sentinelCalc!.calculateEmotionalDensity(entry);
  }

  /// Get current user type
  UserType? getCurrentUserType() {
    return _cachedProfile?.currentType;
  }

  /// Get current configuration
  AdaptiveConfig getCurrentConfig() {
    if (_currentConfig == null) {
      throw StateError('Service not initialized. Call initialize() first.');
    }
    return _currentConfig!;
  }

  /// Load cadence profile from storage
  Future<UserCadenceProfile?> _loadCadenceProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('adaptive_state')
          .doc('cadence_profile')
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return UserCadenceProfile.fromJson(doc.data()!);
    } catch (e) {
      print('Error loading cadence profile: $e');
      return null;
    }
  }

  /// Save cadence profile to storage
  Future<void> _saveCadenceProfile(
    String userId,
    UserCadenceProfile profile,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('adaptive_state')
          .doc('cadence_profile')
          .set(profile.toJson());
    } catch (e) {
      print('Error saving cadence profile: $e');
    }
  }
}


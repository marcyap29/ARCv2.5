import 'mira_models.dart';
import 'mira_service.dart';

/// State for MIRA insights
abstract class MiraState {}

/// Initial state
class MiraInitial extends MiraState {}

/// Loading state
class MiraLoading extends MiraState {}

/// Loaded state with insights data
class MiraLoaded extends MiraState {
  final List<MiraKeywordStat> topKeywords;
  final List<MiraPairStat> pairsOnRise;
  final List<MiraPhasePoint> phaseTrajectory;
  final List<MiraKeywordStat> breakthroughPrecursors;
  final Duration window;
  final String granularity;

  MiraLoaded({
    required this.topKeywords,
    required this.pairsOnRise,
    required this.phaseTrajectory,
    required this.breakthroughPrecursors,
    required this.window,
    required this.granularity,
  });

  MiraLoaded copyWith({
    List<MiraKeywordStat>? topKeywords,
    List<MiraPairStat>? pairsOnRise,
    List<MiraPhasePoint>? phaseTrajectory,
    List<MiraKeywordStat>? breakthroughPrecursors,
    Duration? window,
    String? granularity,
  }) {
    return MiraLoaded(
      topKeywords: topKeywords ?? this.topKeywords,
      pairsOnRise: pairsOnRise ?? this.pairsOnRise,
      phaseTrajectory: phaseTrajectory ?? this.phaseTrajectory,
      breakthroughPrecursors: breakthroughPrecursors ?? this.breakthroughPrecursors,
      window: window ?? this.window,
      granularity: granularity ?? this.granularity,
    );
  }
}

/// Error state
class MiraError extends MiraState {
  final String message;

  MiraError(this.message);
}

/// Cubit for managing MIRA insights state
class MiraCubit {
  final MiraService _miraService;
  MiraState _state = MiraInitial();
  
  // Default window settings
  Duration _defaultWindow = const Duration(days: 14);
  String _defaultGranularity = "day";

  MiraCubit({
    MiraService? miraService,
  }) : _miraService = miraService ?? MiraService();

  /// Get current state
  MiraState get state => _state;

  /// Emit a new state
  void emit(MiraState newState) {
    _state = newState;
  }

  /// Initialize the cubit
  Future<void> init() async {
    try {
      await _miraService.init();
      await loadInsights();
    } catch (e) {
      emit(MiraError('Failed to initialize MIRA: $e'));
    }
  }

  /// Load all insights with current window settings
  Future<void> loadInsights() async {
    emit(MiraLoading());
    
    try {
      final topKeywords = await _miraService.topKeywords(
        window: _defaultWindow,
        limit: 10,
      );
      
      final pairsOnRise = await _miraService.cooccurrencePairsOnRise(
        window: _defaultWindow,
        limit: 10,
      );
      
      final phaseTrajectory = await _miraService.phaseTrajectory(
        window: const Duration(days: 30), // Longer window for phase trajectory
        granularity: _defaultGranularity,
      );
      
      final breakthroughPrecursors = await _miraService.breakthroughPrecursors(
        lookback: const Duration(days: 30),
        limit: 10,
      );
      
      emit(MiraLoaded(
        topKeywords: topKeywords,
        pairsOnRise: pairsOnRise,
        phaseTrajectory: phaseTrajectory,
        breakthroughPrecursors: breakthroughPrecursors,
        window: _defaultWindow,
        granularity: _defaultGranularity,
      ));
    } catch (e) {
      emit(MiraError('Failed to load insights: $e'));
    }
  }

  /// Update the time window and reload insights
  Future<void> updateWindow(Duration window) async {
    _defaultWindow = window;
    await loadInsights();
  }

  /// Update the granularity and reload insights
  Future<void> updateGranularity(String granularity) async {
    _defaultGranularity = granularity;
    await loadInsights();
  }

  /// Refresh insights without changing settings
  Future<void> refresh() async {
    await loadInsights();
  }

  /// Get top keywords only
  Future<List<MiraKeywordStat>> getTopKeywords({
    Duration? window,
    int limit = 10,
  }) async {
    try {
      return await _miraService.topKeywords(
        window: window ?? _defaultWindow,
        limit: limit,
      );
    } catch (e) {
      print('Error getting top keywords: $e');
      return [];
    }
  }

  /// Get co-occurrence pairs on the rise only
  Future<List<MiraPairStat>> getPairsOnRise({
    Duration? window,
    int limit = 10,
  }) async {
    try {
      return await _miraService.cooccurrencePairsOnRise(
        window: window ?? _defaultWindow,
        limit: limit,
      );
    } catch (e) {
      print('Error getting pairs on rise: $e');
      return [];
    }
  }

  /// Get phase trajectory only
  Future<List<MiraPhasePoint>> getPhaseTrajectory({
    Duration? window,
    String? granularity,
  }) async {
    try {
      return await _miraService.phaseTrajectory(
        window: window ?? const Duration(days: 30),
        granularity: granularity ?? _defaultGranularity,
      );
    } catch (e) {
      print('Error getting phase trajectory: $e');
      return [];
    }
  }

  /// Get breakthrough precursors only
  Future<List<MiraKeywordStat>> getBreakthroughPrecursors({
    Duration? lookback,
    int limit = 10,
  }) async {
    try {
      return await _miraService.breakthroughPrecursors(
        lookback: lookback ?? const Duration(days: 30),
        limit: limit,
      );
    } catch (e) {
      print('Error getting breakthrough precursors: $e');
      return [];
    }
  }

  /// Calculate trace score for RIVET
  double calculateTraceScore({
    required List<String> candidateKeywords,
    DateTime? now,
  }) {
    try {
      return _miraService.traceScoreFromGraph(
        candidateKeywords: candidateKeywords,
        now: now ?? DateTime.now(),
      );
    } catch (e) {
      print('Error calculating trace score: $e');
      return 0.0;
    }
  }

  /// Get current window setting
  Duration get currentWindow => _defaultWindow;

  /// Get current granularity setting
  String get currentGranularity => _defaultGranularity;

  /// Get service statistics
  Map<String, dynamic> getStats() {
    return _miraService.getStats();
  }

  /// Clear all data (for testing)
  Future<void> clearAll() async {
    await _miraService.clearAll();
    emit(MiraInitial());
  }

  /// Close the cubit
  Future<void> close() async {
    await _miraService.close();
  }
}

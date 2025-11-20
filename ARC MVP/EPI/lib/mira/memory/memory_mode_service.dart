// lib/mira/memory/memory_mode_service.dart
// Memory retrieval modes for user control over memory usage
// Provides soft/hard/suggestive/ask-first memory access patterns

import 'package:hive/hive.dart';
import 'enhanced_memory_schema.dart';

/// Memory retrieval modes for user control
enum MemoryMode {
  /// Always-on: Automatically use all relevant memories
  alwaysOn,

  /// Suggestive: Show what memories could help, let user choose
  suggestive,

  /// Ask-first: Prompt before recalling memories
  askFirst,

  /// High-confidence: Only use memories with high confidence scores
  highConfidenceOnly,

  /// Soft: Use memories as gentle context, not hard facts
  soft,

  /// Hard: Treat memories as authoritative facts
  hard,

  /// Disabled: Don't use memories for this domain/session
  disabled,
}

/// Configuration for memory modes
class MemoryModeConfig {
  /// Global default mode
  final MemoryMode globalMode;

  /// Per-domain mode overrides
  final Map<MemoryDomain, MemoryMode> domainModes;

  /// Per-session mode (temporary override)
  final MemoryMode? sessionMode;

  /// Confidence threshold for high_confidence_only mode
  final double highConfidenceThreshold;

  /// Whether to show suggestions in UI
  final bool showSuggestions;

  const MemoryModeConfig({
    this.globalMode = MemoryMode.suggestive,
    this.domainModes = const {},
    this.sessionMode,
    this.highConfidenceThreshold = 0.75,
    this.showSuggestions = true,
  });

  MemoryModeConfig copyWith({
    MemoryMode? globalMode,
    Map<MemoryDomain, MemoryMode>? domainModes,
    MemoryMode? sessionMode,
    double? highConfidenceThreshold,
    bool? showSuggestions,
    bool clearSessionMode = false,
  }) {
    return MemoryModeConfig(
      globalMode: globalMode ?? this.globalMode,
      domainModes: domainModes ?? this.domainModes,
      sessionMode: clearSessionMode ? null : (sessionMode ?? this.sessionMode),
      highConfidenceThreshold: highConfidenceThreshold ?? this.highConfidenceThreshold,
      showSuggestions: showSuggestions ?? this.showSuggestions,
    );
  }

  Map<String, dynamic> toJson() => {
    'global_mode': globalMode.name,
    'domain_modes': domainModes.map((k, v) => MapEntry(k.name, v.name)),
    'session_mode': sessionMode?.name,
    'high_confidence_threshold': highConfidenceThreshold,
    'show_suggestions': showSuggestions,
  };

  factory MemoryModeConfig.fromJson(Map<String, dynamic> json) {
    return MemoryModeConfig(
      globalMode: MemoryMode.values.firstWhere(
        (e) => e.name == json['global_mode'],
        orElse: () => MemoryMode.suggestive,
      ),
      domainModes: (json['domain_modes'] as Map?)?.map(
        (k, v) => MapEntry(
          MemoryDomain.values.firstWhere((e) => e.name == k.toString()),
          MemoryMode.values.firstWhere((e) => e.name == v.toString()),
        ),
      ) ?? {},
      sessionMode: json['session_mode'] != null
          ? MemoryMode.values.firstWhere((e) => e.name == json['session_mode'])
          : null,
      highConfidenceThreshold: json['high_confidence_threshold']?.toDouble() ?? 0.75,
      showSuggestions: json['show_suggestions'] ?? true,
    );
  }
}

/// Service for managing memory retrieval modes
class MemoryModeService {
  static const String _configBoxName = 'memory_mode_config';
  static const String _configKey = 'current_config';

  MemoryModeConfig _config;
  Box<Map>? _configBox;

  MemoryModeService({
    MemoryModeConfig? config,
  }) : _config = config ?? const MemoryModeConfig();

  /// Initialize the service and load saved configuration
  Future<void> initialize() async {
    try {
      if (!Hive.isBoxOpen(_configBoxName)) {
        _configBox = await Hive.openBox<Map>(_configBoxName);
      } else {
        _configBox = Hive.box<Map>(_configBoxName);
      }

      // Load saved configuration
      final savedConfig = _configBox?.get(_configKey);
      if (savedConfig != null) {
        _config = MemoryModeConfig.fromJson(Map<String, dynamic>.from(savedConfig));
        print('MemoryModeService: Loaded config - Global: ${_config.globalMode.name}');
      } else {
        print('MemoryModeService: Using default config - Global: ${_config.globalMode.name}');
      }
    } catch (e) {
      print('MemoryModeService: Error initializing: $e');
      // Continue with default config
    }
  }

  /// Get current configuration
  MemoryModeConfig get config => _config;

  /// Get effective mode for current context
  /// Priority: session > domain > global
  MemoryMode getEffectiveMode({
    MemoryDomain? domain,
    String? sessionId,
  }) {
    // Priority 1: Session mode (temporary override)
    if (_config.sessionMode != null) {
      return _config.sessionMode!;
    }

    // Priority 2: Domain-specific mode
    if (domain != null && _config.domainModes.containsKey(domain)) {
      return _config.domainModes[domain]!;
    }

    // Priority 3: Global default mode
    return _config.globalMode;
  }

  /// Update global mode
  Future<void> setGlobalMode(MemoryMode mode) async {
    _config = _config.copyWith(globalMode: mode);
    await _persistConfig();
    print('MemoryModeService: Set global mode to ${mode.name}');
  }

  /// Set mode for specific domain
  Future<void> setDomainMode(MemoryDomain domain, MemoryMode mode) async {
    final updatedDomainModes = Map<MemoryDomain, MemoryMode>.from(_config.domainModes);
    updatedDomainModes[domain] = mode;

    _config = _config.copyWith(domainModes: updatedDomainModes);
    await _persistConfig();
    print('MemoryModeService: Set ${domain.name} mode to ${mode.name}');
  }

  /// Clear domain mode (revert to global)
  Future<void> clearDomainMode(MemoryDomain domain) async {
    final updatedDomainModes = Map<MemoryDomain, MemoryMode>.from(_config.domainModes);
    updatedDomainModes.remove(domain);

    _config = _config.copyWith(domainModes: updatedDomainModes);
    await _persistConfig();
    print('MemoryModeService: Cleared ${domain.name} mode, using global');
  }

  /// Set temporary session mode
  void setSessionMode(MemoryMode? mode) {
    _config = _config.copyWith(
      sessionMode: mode,
      clearSessionMode: mode == null,
    );
    print('MemoryModeService: Set session mode to ${mode?.name ?? "null"}');
  }

  /// Clear session mode
  void clearSessionMode() {
    _config = _config.copyWith(clearSessionMode: true);
    print('MemoryModeService: Cleared session mode');
  }

  /// Set high confidence threshold
  Future<void> setHighConfidenceThreshold(double threshold) async {
    if (threshold < 0.0 || threshold > 1.0) {
      throw ArgumentError('Threshold must be between 0.0 and 1.0');
    }

    _config = _config.copyWith(highConfidenceThreshold: threshold);
    await _persistConfig();
    print('MemoryModeService: Set confidence threshold to $threshold');
  }

  /// Set whether to show suggestions
  Future<void> setShowSuggestions(bool show) async {
    _config = _config.copyWith(showSuggestions: show);
    await _persistConfig();
  }

  /// Check if memories should be retrieved for this mode
  bool shouldRetrieveMemories(MemoryMode mode) {
    return mode != MemoryMode.disabled;
  }

  /// Check if user prompt is needed before retrieval
  bool needsUserPrompt(MemoryMode mode) {
    return mode == MemoryMode.askFirst || mode == MemoryMode.suggestive;
  }

  /// Check if mode treats memories as authoritative
  bool isAuthoritativeMode(MemoryMode mode) {
    return mode == MemoryMode.hard || mode == MemoryMode.alwaysOn;
  }

  /// Check if mode uses gentle context
  bool isGentleMode(MemoryMode mode) {
    return mode == MemoryMode.soft || mode == MemoryMode.suggestive;
  }

  /// Apply mode-specific filtering to memories
  List<EnhancedMiraNode> applyModeFilter({
    required List<EnhancedMiraNode> memories,
    required MemoryMode mode,
    Map<String, double>? confidenceScores,
  }) {
    switch (mode) {
      case MemoryMode.disabled:
        return [];

      case MemoryMode.highConfidenceOnly:
        return memories.where((node) {
          final confidence = confidenceScores?[node.id] ?? 0.0;
          return confidence >= _config.highConfidenceThreshold;
        }).toList();

      case MemoryMode.soft:
      case MemoryMode.hard:
      case MemoryMode.alwaysOn:
      case MemoryMode.suggestive:
      case MemoryMode.askFirst:
        // No filtering for these modes - handled at retrieval level
        return memories;
    }
  }

  /// Get prompt text for ask_first mode
  String getAskFirstPrompt({
    required int memoryCount,
    required MemoryDomain domain,
  }) {
    if (memoryCount == 0) {
      return 'No ${_getDomainDisplayName(domain)} memories found.';
    }

    if (memoryCount == 1) {
      return 'I found 1 relevant ${_getDomainDisplayName(domain)} memory that could help. Would you like me to use it?';
    }

    return 'I found $memoryCount relevant ${_getDomainDisplayName(domain)} memories that could help. Would you like me to use them?';
  }

  /// Get suggestion text for suggestive mode
  String getSuggestionText({
    required List<EnhancedMiraNode> memories,
    required MemoryDomain domain,
  }) {
    if (memories.isEmpty) {
      return '';
    }

    if (memories.length == 1) {
      final preview = _getMemoryPreview(memories.first);
      return 'Memory available: $preview';
    }

    final count = memories.length;
    final topMemories = memories.take(3).map((m) => _getMemoryPreview(m)).join(', ');

    return '$count memories available: $topMemories';
  }

  /// Get memory preview text (first 50 chars)
  String _getMemoryPreview(EnhancedMiraNode memory) {
    final content = memory.data['content']?.toString() ?? '';
    if (content.isEmpty) return '(empty)';

    return content.length > 50
        ? '${content.substring(0, 50)}...'
        : content;
  }

  /// Get display name for domain
  String _getDomainDisplayName(MemoryDomain domain) {
    return domain.name;
  }

  /// Get display name for mode
  static String getModeDisplayName(MemoryMode mode) {
    switch (mode) {
      case MemoryMode.alwaysOn:
        return 'Always On';
      case MemoryMode.suggestive:
        return 'Suggestive';
      case MemoryMode.askFirst:
        return 'Ask First';
      case MemoryMode.highConfidenceOnly:
        return 'High Confidence Only';
      case MemoryMode.soft:
        return 'Soft';
      case MemoryMode.hard:
        return 'Hard';
      case MemoryMode.disabled:
        return 'Disabled';
    }
  }

  /// Get description for mode
  static String getModeDescription(MemoryMode mode, {double? threshold}) {
    switch (mode) {
      case MemoryMode.alwaysOn:
        return 'Automatically uses all relevant memories without prompting';
      case MemoryMode.suggestive:
        return 'Shows available memories and lets you choose whether to use them';
      case MemoryMode.askFirst:
        return 'Asks permission before recalling any memories';
      case MemoryMode.highConfidenceOnly:
        final thresholdPercent = ((threshold ?? 0.75) * 100).toInt();
        return 'Only uses memories with high confidence scores ($thresholdPercent%+)';
      case MemoryMode.soft:
        return 'Uses memories as gentle context, not hard facts';
      case MemoryMode.hard:
        return 'Treats memories as authoritative facts';
      case MemoryMode.disabled:
        return 'Does not use memories for this domain';
    }
  }

  /// Reset to default configuration
  Future<void> resetToDefaults() async {
    _config = const MemoryModeConfig();
    await _persistConfig();
    print('MemoryModeService: Reset to default configuration');
  }

  /// Persist configuration to storage
  Future<void> _persistConfig() async {
    try {
      if (_configBox == null) {
        await initialize();
      }

      await _configBox?.put(_configKey, _config.toJson());
    } catch (e) {
      print('MemoryModeService: Error persisting config: $e');
    }
  }

  /// Get statistics about mode usage
  Map<String, dynamic> getStatistics() {
    return {
      'global_mode': _config.globalMode.name,
      'domain_overrides': _config.domainModes.length,
      'session_mode_active': _config.sessionMode != null,
      'high_confidence_threshold': _config.highConfidenceThreshold,
      'show_suggestions': _config.showSuggestions,
      'domain_modes': _config.domainModes.map((k, v) => MapEntry(k.name, v.name)),
    };
  }
}
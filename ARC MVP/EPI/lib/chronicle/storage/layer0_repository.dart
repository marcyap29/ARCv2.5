import 'package:hive/hive.dart';
import 'raw_entry_schema.dart';

// TODO: Uncomment after running build_runner
// part 'layer0_repository.g.dart';

/// Hive model for Chronicle Raw Entry (Layer 0)
@HiveType(typeId: 110)
class ChronicleRawEntry extends HiveObject {
  @HiveField(0)
  final String entryId;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final Map<String, dynamic> metadata;

  @HiveField(4)
  final Map<String, dynamic> analysis;

  @HiveField(5)
  final String userId;

  ChronicleRawEntry({
    required this.entryId,
    required this.timestamp,
    required this.content,
    required this.metadata,
    required this.analysis,
    required this.userId,
  });

  /// Convert to RawEntrySchema for easier access
  RawEntrySchema toSchema() {
    return RawEntrySchema(
      entryId: entryId,
      timestamp: timestamp,
      content: content,
      metadata: RawEntryMetadata.fromJson(metadata),
      analysis: RawEntryAnalysis.fromJson(analysis),
    );
  }

  /// Create from RawEntrySchema
  factory ChronicleRawEntry.fromSchema(RawEntrySchema schema, String userId) {
    return ChronicleRawEntry(
      entryId: schema.entryId,
      timestamp: schema.timestamp,
      content: schema.content,
      metadata: schema.metadata.toJson(),
      analysis: schema.analysis.toJson(),
      userId: userId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entry_id': entryId,
      'timestamp': timestamp.toIso8601String(),
      'content': content,
      'metadata': metadata,
      'analysis': analysis,
      'user_id': userId,
    };
  }

  factory ChronicleRawEntry.fromJson(Map<String, dynamic> json) {
    return ChronicleRawEntry(
      entryId: json['entry_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      content: json['content'] as String,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map),
      analysis: Map<String, dynamic>.from(json['analysis'] as Map),
      userId: json['user_id'] as String,
    );
  }
}

/// Repository for Layer 0 (Raw Entries) storage
/// 
/// Uses Hive box for fast indexed queries.
/// Retention: 30-90 days (configurable by tier)
class Layer0Repository {
  static const String boxName = 'chronicle_raw_entries';
  Box<ChronicleRawEntry>? _box;
  bool _initialized = false;

  /// Initialize the Hive box
  Future<void> initialize() async {
    if (_initialized && _box != null && _box!.isOpen) return;

    try {
      // Adapter will be auto-registered when .g.dart file is imported
      // Just ensure it's registered before opening box
      if (!Hive.isAdapterRegistered(110)) {
        // Try to import the generated adapter
        // If build_runner hasn't run yet, this will fail gracefully
        try {
          // The adapter will be registered when the .g.dart file is imported
          // For now, we'll handle the case where it's not generated yet
          print('⚠️ Layer0Repository: Adapter not registered. Run build_runner to generate adapter.');
        } catch (e) {
          print('⚠️ Layer0Repository: Adapter registration issue: $e');
        }
      }

      _box = await Hive.openBox<ChronicleRawEntry>(boxName);
      _initialized = true;
      print('✅ Layer0Repository: Initialized Hive box $boxName');
    } catch (e) {
      print('❌ Layer0Repository: Failed to initialize: $e');
      // Don't rethrow - allow graceful degradation
      // The adapter will be available after build_runner completes
    }
  }

  /// Ensure box is open before operations
  Future<void> _ensureBox() async {
    if (!_initialized || _box == null || !_box!.isOpen) {
      await initialize();
    }
  }

  /// Save a raw entry to Layer 0
  Future<void> saveEntry(ChronicleRawEntry entry) async {
    await _ensureBox();
    await _box!.put(entry.entryId, entry);
  }

  /// Get entry by ID
  Future<ChronicleRawEntry?> getEntry(String entryId) async {
    await _ensureBox();
    return _box!.get(entryId);
  }

  /// Get distinct month strings (e.g. "2025-01") that have at least one entry for [userId].
  /// Used by batch synthesis so we only synthesize months that have Layer 0 data.
  Future<List<String>> getMonthsWithEntries(String userId) async {
    await _ensureBox();
    final months = <String>{};
    for (final entry in _box!.values) {
      if (entry.userId == userId) {
        final month = '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}';
        months.add(month);
      }
    }
    final list = months.toList()..sort();
    return list;
  }

  /// Get all entries for a specific month
  /// 
  /// [month] Format: "2025-01"
  Future<List<ChronicleRawEntry>> getEntriesForMonth(
    String userId,
    String month,
  ) async {
    await _ensureBox();

    final startDate = DateTime.parse('$month-01');
    final endDate = DateTime(startDate.year, startDate.month + 1, 0, 23, 59, 59);

    return _box!.values
        .where((entry) =>
            entry.userId == userId &&
            entry.timestamp.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
            entry.timestamp.isBefore(endDate.add(const Duration(seconds: 1))))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Get entries in a date range
  Future<List<ChronicleRawEntry>> getEntriesInRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    await _ensureBox();

    return _box!.values
        .where((entry) =>
            entry.userId == userId &&
            entry.timestamp.isAfter(start.subtract(const Duration(seconds: 1))) &&
            entry.timestamp.isBefore(end.add(const Duration(seconds: 1))))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Query entries by theme
  Future<List<ChronicleRawEntry>> queryByTheme(
    String userId,
    String theme,
  ) async {
    await _ensureBox();

    return _box!.values
        .where((entry) {
          if (entry.userId != userId) return false;
          final themes = entry.analysis['extracted_themes'] as List?;
          return themes?.contains(theme) ?? false;
        })
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Query entries by phase
  Future<List<ChronicleRawEntry>> queryByPhase(
    String userId,
    String phase,
  ) async {
    await _ensureBox();

    return _box!.values
        .where((entry) {
          if (entry.userId != userId) return false;
          return entry.analysis['atlas_phase'] == phase;
        })
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Cleanup old entries based on retention policy
  /// 
  /// [retentionDays] Number of days to retain (30-90 based on tier)
  Future<int> cleanupOldEntries(String userId, int retentionDays) async {
    await _ensureBox();

    final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
    final keysToDelete = <dynamic>[];

    for (final entry in _box!.values) {
      if (entry.userId == userId && entry.timestamp.isBefore(cutoffDate)) {
        keysToDelete.add(entry.entryId);
      }
    }

    if (keysToDelete.isNotEmpty) {
      await _box!.deleteAll(keysToDelete);
      print('🗑️ Layer0Repository: Deleted ${keysToDelete.length} old entries (older than $retentionDays days)');
    }

    return keysToDelete.length;
  }

  /// Get count of entries for a user
  Future<int> getEntryCount(String userId) async {
    await _ensureBox();
    return _box!.values.where((entry) => entry.userId == userId).length;
  }

  /// Delete a specific entry
  Future<void> deleteEntry(String entryId) async {
    await _ensureBox();
    await _box!.delete(entryId);
  }

  /// Close the box
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _initialized = false;
    }
  }
}

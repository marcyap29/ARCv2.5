import 'package:hive/hive.dart';
// For generating unique IDs
// For firstWhereOrNull

part 'phase_history_repository.g.dart'; // Hive generated file

/// Data model for storing phase score history entries
@HiveType(typeId: 3) // Ensure this is a unique typeId
class PhaseHistoryEntry extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final DateTime timestamp;
  
  @HiveField(2)
  final Map<String, double> phaseScores; // phase -> score (0-1)
  
  @HiveField(3)
  final String journalEntryId; // Reference to the journal entry that generated these scores
  
  @HiveField(4)
  final String emotion;
  
  @HiveField(5)
  final String reason;
  
  @HiveField(6)
  final String text;

  @HiveField(7)
  final int? operationalReadinessScore; // 10-100 rating for military readiness
  
  @HiveField(8)
  final Map<String, dynamic>? healthData; // Health data snapshot (sleepQuality, energyLevel)

  PhaseHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.phaseScores,
    required this.journalEntryId,
    required this.emotion,
    required this.reason,
    required this.text,
    this.operationalReadinessScore,
    this.healthData,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'phaseScores': phaseScores,
      'journalEntryId': journalEntryId,
      'emotion': emotion,
      'reason': reason,
      'text': text,
      'operationalReadinessScore': operationalReadinessScore,
      'healthData': healthData,
    };
  }

  factory PhaseHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PhaseHistoryEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      phaseScores: Map<String, double>.from(json['phaseScores'] as Map),
      journalEntryId: json['journalEntryId'] as String,
      emotion: json['emotion'] as String,
      reason: json['reason'] as String,
      text: json['text'] as String,
      operationalReadinessScore: json['operationalReadinessScore'] as int?,
      healthData: json['healthData'] != null 
          ? Map<String, dynamic>.from(json['healthData'] as Map)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhaseHistoryEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Repository for managing phase history data persistence
class PhaseHistoryRepository {
  static const String _boxName = 'phase_history_v1';
  static Box<Map>? _box;

  /// Initialize the Hive box for phase history
  static Future<void> initialize() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<Map>(_boxName);
    }
  }

  /// Ensure the box is open before operations
  static Future<void> _ensureBoxOpen() async {
    if (_box == null || !_box!.isOpen) {
      await initialize();
    }
  }

  /// Add a new phase history entry
  static Future<void> addEntry(PhaseHistoryEntry entry) async {
    await _ensureBoxOpen();
    await _box!.put(entry.id, entry.toJson());
  }

  /// Get all phase history entries, sorted by timestamp (oldest first)
  static Future<List<PhaseHistoryEntry>> getAllEntries() async {
    await _ensureBoxOpen();
    final entries = _box!.values
        .map((json) => PhaseHistoryEntry.fromJson(Map<String, dynamic>.from(json)))
        .toList();
    
    // Sort by timestamp (oldest first)
    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return entries;
  }

  /// Get phase history entries for a specific time range
  static Future<List<PhaseHistoryEntry>> getEntriesInRange(
    DateTime start,
    DateTime end,
  ) async {
    final allEntries = await getAllEntries();
    return allEntries
        .where((entry) => 
            !entry.timestamp.isBefore(start) && 
            !entry.timestamp.isAfter(end))
        .toList();
  }

  /// Get the most recent N phase history entries
  static Future<List<PhaseHistoryEntry>> getRecentEntries(int count) async {
    final allEntries = await getAllEntries();
    if (allEntries.length <= count) {
      return allEntries;
    }
    return allEntries.sublist(allEntries.length - count);
  }

  /// Get phase history entries for a specific journal entry
  static Future<PhaseHistoryEntry?> getEntryByJournalId(String journalEntryId) async {
    await _ensureBoxOpen();
    final entries = _box!.values
        .map((json) => PhaseHistoryEntry.fromJson(Map<String, dynamic>.from(json)))
        .where((entry) => entry.journalEntryId == journalEntryId)
        .toList();
    
    return entries.isNotEmpty ? entries.first : null;
  }

  /// Get phase history entries for a specific phase
  static Future<List<PhaseHistoryEntry>> getEntriesForPhase(String phase) async {
    final allEntries = await getAllEntries();
    return allEntries
        .where((entry) => entry.phaseScores.containsKey(phase))
        .toList();
  }

  /// Get the average score for a specific phase over a time range
  static Future<double> getAverageScoreForPhase(
    String phase,
    DateTime start,
    DateTime end,
  ) async {
    final entries = await getEntriesInRange(start, end);
    if (entries.isEmpty) return 0.0;

    final totalScore = entries
        .map((entry) => entry.phaseScores[phase] ?? 0.0)
        .fold(0.0, (sum, score) => sum + score);
    
    return totalScore / entries.length;
  }

  /// Get the trend for a specific phase over time (positive = increasing, negative = decreasing)
  static Future<double> getPhaseTrend(String phase, {int lookbackDays = 7}) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: lookbackDays));
    final entries = await getEntriesInRange(start, now);
    
    if (entries.length < 2) return 0.0;

    // Calculate simple linear trend
    final scores = entries
        .map((entry) => entry.phaseScores[phase] ?? 0.0)
        .toList();
    
    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    for (int i = 0; i < scores.length; i++) {
      sumX += i.toDouble();
      sumY += scores[i];
      sumXY += i * scores[i];
      sumXX += i * i;
    }
    
    final n = scores.length.toDouble();
    final slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    return slope;
  }

  /// Get phase history statistics
  static Future<Map<String, dynamic>> getStatistics() async {
    final allEntries = await getAllEntries();
    if (allEntries.isEmpty) {
      return {
        'totalEntries': 0,
        'dateRange': null,
        'mostCommonPhase': null,
        'averageScores': <String, double>{},
      };
    }

    // Calculate date range
    final timestamps = allEntries.map((e) => e.timestamp).toList();
    timestamps.sort();
    final dateRange = {
      'start': timestamps.first.toIso8601String(),
      'end': timestamps.last.toIso8601String(),
    };

    // Calculate most common phase (highest average score)
    final phaseAverages = <String, double>{};
    for (final phase in ['Discovery', 'Expansion', 'Transition', 'Consolidation', 'Recovery', 'Breakthrough']) {
      final scores = allEntries
          .map((entry) => entry.phaseScores[phase] ?? 0.0)
          .toList();
      phaseAverages[phase] = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
    }

    final mostCommonPhase = phaseAverages.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return {
      'totalEntries': allEntries.length,
      'dateRange': dateRange,
      'mostCommonPhase': mostCommonPhase,
      'averageScores': phaseAverages,
    };
  }

  /// Delete a specific phase history entry
  static Future<void> deleteEntry(String entryId) async {
    await _ensureBoxOpen();
    await _box!.delete(entryId);
  }

  /// Delete all phase history entries
  static Future<void> clearAll() async {
    await _ensureBoxOpen();
    await _box!.clear();
  }

  /// Delete entries older than a specific date
  static Future<int> deleteEntriesOlderThan(DateTime cutoff) async {
    final allEntries = await getAllEntries();
    final toDelete = allEntries
        .where((entry) => entry.timestamp.isBefore(cutoff))
        .toList();
    
    for (final entry in toDelete) {
      await deleteEntry(entry.id);
    }
    
    return toDelete.length;
  }

  /// Get the count of entries
  static Future<int> getEntryCount() async {
    await _ensureBoxOpen();
    return _box!.length;
  }

  /// Check if the repository has any data
  static Future<bool> hasData() async {
    return await getEntryCount() > 0;
  }

  /// Close the Hive box (call when app is shutting down)
  static Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
  }
}

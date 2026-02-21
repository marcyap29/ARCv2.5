import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'entry_classifier.dart';
import 'response_mode.dart';

class ClassificationLogger {
  static const String _collection = 'classification_logs';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Log classification for analytics and refinement
  static Future<void> logClassification({
    required String userId,
    required String entryText,
    required EntryType classification,
    required ResponseMode responseMode,
    String? response,
    Map<String, dynamic>? debugInfo,
  }) async {
    try {
      final wordCount = entryText.split(RegExp(r'\s+')).length;
      final responseWordCount = response?.split(RegExp(r'\s+')).length;

      await _firestore.collection(_collection).add({
        'user_id': userId,
        'entry_preview': _truncateText(entryText, 200),
        'entry_word_count': wordCount,
        'classification': classification.toString().split('.').last,
        'response_mode': responseMode.toJson(),
        'response_word_count': responseWordCount,
        'response_preview': response != null ? _truncateText(response, 200) : null,
        'debug_info': debugInfo,
        'timestamp': FieldValue.serverTimestamp(),
        'version': '1.0.0', // For tracking classification algorithm versions
      });
    } catch (e) {
      print('Error logging classification: $e');
      // Don't throw - logging failure shouldn't break the main flow
    }
  }

  /// Log response validation results
  static Future<void> logValidation({
    required String userId,
    required EntryType entryType,
    required String response,
    required ResponseMode responseMode,
    required Map<String, dynamic> violations,
  }) async {
    try {
      await _firestore.collection('classification_validations').add({
        'user_id': userId,
        'entry_type': entryType.toString().split('.').last,
        'response_word_count': response.split(RegExp(r'\s+')).length,
        'max_words': responseMode.maxWords,
        'violations': violations,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging validation: $e');
    }
  }

  /// Log user feedback on classification accuracy
  static Future<void> logUserFeedback({
    required String userId,
    required String entryText,
    required EntryType predictedType,
    required bool wasAppropriate,
    EntryType? userCorrectedType,
    String? feedbackNote,
  }) async {
    try {
      await _firestore.collection('classification_feedback').add({
        'user_id': userId,
        'entry_preview': _truncateText(entryText, 200),
        'predicted_type': predictedType.toString().split('.').last,
        'was_appropriate': wasAppropriate,
        'user_corrected_type': userCorrectedType?.toString().split('.').last,
        'feedback_note': feedbackNote,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging user feedback: $e');
    }
  }

  /// Get classification metrics for monitoring dashboard
  static Future<ClassificationMetrics> getMetrics({
    required DateTime startDate,
    required DateTime endDate,
    String? userId,
  }) async {
    try {
      Query query = _firestore.collection(_collection)
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate);

      if (userId != null) {
        query = query.where('user_id', isEqualTo: userId);
      }

      final snapshot = await query.get();
      return ClassificationMetrics.fromDocuments(snapshot.docs);
    } catch (e) {
      print('Error getting classification metrics: $e');
      return ClassificationMetrics.empty();
    }
  }

  /// Get misclassification analysis for tuning
  static Future<List<ClassificationError>> analyzeMisclassifications({
    int limit = 100,
    String? userId,
  }) async {
    try {
      Query query = _firestore.collection('classification_feedback')
          .where('was_appropriate', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (userId != null) {
        query = query.where('user_id', isEqualTo: userId);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) =>
        ClassificationError.fromDocument(doc)
      ).toList();
    } catch (e) {
      print('Error analyzing misclassifications: $e');
      return [];
    }
  }

  /// Truncate text for storage
  static String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength - 3) + '...';
  }
}

class ClassificationMetrics {
  final Map<EntryType, int> entryTypeCounts;
  final Map<EntryType, double> avgWordCounts;
  final Map<EntryType, double> avgResponseWords;
  final Map<EntryType, Duration> avgResponseTime;
  final int phaseViolations;
  final int wordCountViolations;
  final int headerViolations;
  final Map<EntryType, double> thumbsUpRate;
  final Map<EntryType, double> thumbsDownRate;

  ClassificationMetrics({
    required this.entryTypeCounts,
    required this.avgWordCounts,
    required this.avgResponseWords,
    required this.avgResponseTime,
    required this.phaseViolations,
    required this.wordCountViolations,
    required this.headerViolations,
    required this.thumbsUpRate,
    required this.thumbsDownRate,
  });

  factory ClassificationMetrics.fromDocuments(List<QueryDocumentSnapshot> docs) {
    final entryTypeCounts = <EntryType, int>{};
    final entryTypeWordSums = <EntryType, List<int>>{};
    final responseTypeWordSums = <EntryType, List<int>>{};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final classificationStr = data['classification'] as String;
      final entryType = EntryType.values.firstWhere(
        (e) => e.toString().split('.').last == classificationStr,
        orElse: () => EntryType.reflective,
      );

      entryTypeCounts[entryType] = (entryTypeCounts[entryType] ?? 0) + 1;

      final entryWordCount = data['entry_word_count'] as int? ?? 0;
      entryTypeWordSums.putIfAbsent(entryType, () => []).add(entryWordCount);

      final responseWordCount = data['response_word_count'] as int?;
      if (responseWordCount != null) {
        responseTypeWordSums.putIfAbsent(entryType, () => []).add(responseWordCount);
      }
    }

    // Calculate averages
    final avgWordCounts = <EntryType, double>{};
    final avgResponseWords = <EntryType, double>{};

    for (final entryType in EntryType.values) {
      final entryWords = entryTypeWordSums[entryType] ?? [];
      avgWordCounts[entryType] = entryWords.isEmpty
        ? 0.0
        : entryWords.reduce((a, b) => a + b) / entryWords.length;

      final responseWords = responseTypeWordSums[entryType] ?? [];
      avgResponseWords[entryType] = responseWords.isEmpty
        ? 0.0
        : responseWords.reduce((a, b) => a + b) / responseWords.length;
    }

    return ClassificationMetrics(
      entryTypeCounts: entryTypeCounts,
      avgWordCounts: avgWordCounts,
      avgResponseWords: avgResponseWords,
      avgResponseTime: {}, // TODO: Implement timing tracking
      phaseViolations: 0, // TODO: Implement violation tracking
      wordCountViolations: 0,
      headerViolations: 0,
      thumbsUpRate: {}, // TODO: Implement feedback tracking
      thumbsDownRate: {},
    );
  }

  factory ClassificationMetrics.empty() {
    return ClassificationMetrics(
      entryTypeCounts: {},
      avgWordCounts: {},
      avgResponseWords: {},
      avgResponseTime: {},
      phaseViolations: 0,
      wordCountViolations: 0,
      headerViolations: 0,
      thumbsUpRate: {},
      thumbsDownRate: {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entryTypeCounts': entryTypeCounts.map(
        (key, value) => MapEntry(key.toString().split('.').last, value),
      ),
      'avgWordCounts': avgWordCounts.map(
        (key, value) => MapEntry(key.toString().split('.').last, value),
      ),
      'avgResponseWords': avgResponseWords.map(
        (key, value) => MapEntry(key.toString().split('.').last, value),
      ),
      'violations': {
        'phase': phaseViolations,
        'wordCount': wordCountViolations,
        'header': headerViolations,
      },
    };
  }
}

class ClassificationError {
  final String userId;
  final String entryPreview;
  final EntryType predictedType;
  final EntryType? correctedType;
  final String? feedbackNote;
  final DateTime timestamp;

  ClassificationError({
    required this.userId,
    required this.entryPreview,
    required this.predictedType,
    this.correctedType,
    this.feedbackNote,
    required this.timestamp,
  });

  factory ClassificationError.fromDocument(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final predictedTypeStr = data['predicted_type'] as String;
    final predictedType = EntryType.values.firstWhere(
      (e) => e.toString().split('.').last == predictedTypeStr,
      orElse: () => EntryType.reflective,
    );

    EntryType? correctedType;
    final correctedTypeStr = data['user_corrected_type'] as String?;
    if (correctedTypeStr != null) {
      correctedType = EntryType.values.firstWhere(
        (e) => e.toString().split('.').last == correctedTypeStr,
        orElse: () => EntryType.reflective,
      );
    }

    return ClassificationError(
      userId: data['user_id'] as String,
      entryPreview: data['entry_preview'] as String,
      predictedType: predictedType,
      correctedType: correctedType,
      feedbackNote: data['feedback_note'] as String?,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'entryPreview': entryPreview,
      'predictedType': predictedType.toString().split('.').last,
      'correctedType': correctedType?.toString().split('.').last,
      'feedbackNote': feedbackNote,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Response feedback for user satisfaction tracking
class ResponseFeedback {
  final String responseId;
  final EntryType predictedType;
  final bool wasAppropriate;
  final EntryType? userCorrectedType;
  final String? feedbackNote;
  final DateTime timestamp;

  ResponseFeedback({
    required this.responseId,
    required this.predictedType,
    required this.wasAppropriate,
    this.userCorrectedType,
    this.feedbackNote,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'responseId': responseId,
      'predictedType': predictedType.toString().split('.').last,
      'wasAppropriate': wasAppropriate,
      'userCorrectedType': userCorrectedType?.toString().split('.').last,
      'feedbackNote': feedbackNote,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Validation result for response quality
class ValidationResult {
  final bool isValid;
  final List<String> violations;
  final Map<String, dynamic> metrics;

  ValidationResult({
    required this.isValid,
    required this.violations,
    required this.metrics,
  });

  Map<String, dynamic> toJson() {
    return {
      'isValid': isValid,
      'violations': violations,
      'metrics': metrics,
    };
  }
}
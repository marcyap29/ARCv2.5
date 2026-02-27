import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/services/sentinel/sentinel_config.dart';

/// Temporal Sentinel: Crisis detection based on emotional clustering over time
class SentinelAnalyzer {
  static final _firestore = FirebaseFirestore.instance;
  
  /// Calculate SENTINEL score with temporal decay
  /// Returns 0.0 (no alert) to 1.0 (crisis alert)
  static Future<SentinelScore> calculateSentinelScore({
    required String userId,
    required String currentEntryText,
  }) async {
    
    // Get recent entries with crisis indicators
    final recentCrisisEntries = await _getRecentCrisisEntries(userId);
    
    // Calculate current entry emotional intensity
    final currentIntensity = _calculateEmotionalIntensity(currentEntryText);
    final hasCrisisLanguage = _detectSelfHarmLanguage(currentEntryText);
    
    // If current entry has explicit crisis language, immediate alert
    if (hasCrisisLanguage) {
      return SentinelScore(
        score: 1.0,
        alert: true,
        reason: 'Explicit crisis language detected',
        triggerEntries: [currentEntryText],
        timespan: Duration.zero,
      );
    }
    
    // Check RIVET for dangerous phase transitions
    try {
      final dangerousTransition = await _checkRivetDangerousTransition(userId);
      if (dangerousTransition) {
        return SentinelScore(
          score: 1.0,
          alert: true,
          reason: 'RIVET detected dangerous phase transition',
          triggerEntries: [currentEntryText],
          timespan: Duration.zero,
        );
      }
    } catch (e) {
      print('Sentinel: Error checking RIVET: $e');
      // Continue with normal analysis
    }
    
    // Calculate temporal clustering of high-intensity entries
    final clusterScore = _calculateTemporalClustering(
      recentCrisisEntries,
      currentIntensity,
    );
    
    // Alert if clustering score exceeds threshold
    final alert = clusterScore >= SentinelConfig.ALERT_THRESHOLD;
    
    return SentinelScore(
      score: clusterScore,
      alert: alert,
      reason: alert 
        ? 'High emotional intensity clustered over ${recentCrisisEntries.length} entries'
        : 'Normal emotional variance',
      triggerEntries: recentCrisisEntries.map((e) => e.text).toList(),
      timespan: recentCrisisEntries.isEmpty 
        ? Duration.zero
        : DateTime.now().difference(recentCrisisEntries.last.timestamp),
    );
  }
  
  /// Check RIVET for dangerous phase transitions
  static Future<bool> _checkRivetDangerousTransition(String userId) async {
    try {
      // Import and check RIVET phase and readiness
      // This is a placeholder - actual implementation depends on RIVET structure
      // TODO: Integrate with actual RIVET service
      return false;
    } catch (e) {
      print('Sentinel: Error checking RIVET transition: $e');
      return false;
    }
  }
  
  /// Calculate how clustered high-intensity emotions are over time
  /// Returns 0.0 (dispersed/normal) to 1.0 (tightly clustered/crisis)
  static double _calculateTemporalClustering(
    List<CrisisEntry> recentEntries,
    double currentIntensity,
  ) {
    if (recentEntries.isEmpty) {
      // No history, just use current intensity
      return currentIntensity;
    }
    
    final now = DateTime.now();
    
    // Count high-intensity entries in each window
    int count1Day = 0;
    int count3Day = 0;
    int count7Day = 0;
    int count30Day = 0;
    double totalIntensity1Day = 0.0;
    double totalIntensity3Day = 0.0;
    double totalIntensity7Day = 0.0;
    
    for (final entry in recentEntries) {
      final daysSince = now.difference(entry.timestamp).inDays;
      
      if (daysSince <= SentinelConfig.WINDOW_1_DAY) {
        count1Day++;
        totalIntensity1Day += entry.intensity;
      }
      if (daysSince <= SentinelConfig.WINDOW_3_DAY) {
        count3Day++;
        totalIntensity3Day += entry.intensity;
      }
      if (daysSince <= SentinelConfig.WINDOW_7_DAY) {
        count7Day++;
        totalIntensity7Day += entry.intensity;
      }
      if (daysSince <= SentinelConfig.WINDOW_30_DAY) {
        count30Day++;
      }
    }
    
    // Add current entry to counts
    count1Day++;
    count3Day++;
    count7Day++;
    count30Day++;
    totalIntensity1Day += currentIntensity;
    totalIntensity3Day += currentIntensity;
    totalIntensity7Day += currentIntensity;
    
    // Calculate frequency scores (normalized)
    final freq1Day = (count1Day / SentinelConfig.FREQ_THRESHOLD_1DAY).clamp(0.0, 1.0);
    final freq3Day = (count3Day / SentinelConfig.FREQ_THRESHOLD_3DAY).clamp(0.0, 1.0);
    final freq7Day = (count7Day / SentinelConfig.FREQ_THRESHOLD_7DAY).clamp(0.0, 1.0);
    final freq30Day = (count30Day / SentinelConfig.FREQ_THRESHOLD_30DAY).clamp(0.0, 1.0);
    
    // Calculate average intensity in each window
    final avgIntensity1Day = count1Day > 0 ? totalIntensity1Day / count1Day : 0.0;
    final avgIntensity3Day = count3Day > 0 ? totalIntensity3Day / count3Day : 0.0;
    final avgIntensity7Day = count7Day > 0 ? totalIntensity7Day / count7Day : 0.0;
    
    // Combine frequency × intensity with temporal weighting
    final score1Day = (freq1Day * avgIntensity1Day) * SentinelConfig.WEIGHT_1DAY;
    final score3Day = (freq3Day * avgIntensity3Day) * SentinelConfig.WEIGHT_3DAY;
    final score7Day = (freq7Day * avgIntensity7Day) * SentinelConfig.WEIGHT_7DAY;
    final score30Day = freq30Day * SentinelConfig.WEIGHT_30DAY;
    
    // Final score is weighted average
    final finalScore = (score1Day + score3Day + score7Day + score30Day) / 2.2;
    
    return finalScore.clamp(0.0, 1.0);
  }
  
  /// Get recent journal entries with crisis indicators
  static Future<List<CrisisEntry>> _getRecentCrisisEntries(String userId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: SentinelConfig.WINDOW_30_DAY));
      
      final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('journal_entries')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('timestamp', descending: true)
        .get();
      
      final crisisEntries = <CrisisEntry>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final text = data['entry_text'] as String? ?? '';
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        
        final intensity = _calculateEmotionalIntensity(text);
        
        // Only include entries with elevated intensity
        if (intensity >= SentinelConfig.MIN_CRISIS_INTENSITY) {
          crisisEntries.add(CrisisEntry(
            text: text,
            intensity: intensity,
            timestamp: timestamp,
          ));
        }
      }
      
      return crisisEntries;
      
    } catch (e) {
      print('Error fetching recent crisis entries: $e');
      return [];
    }
  }
  
  /// Detect self-harm or suicide language
  static bool _detectSelfHarmLanguage(String text) {
    final lowerText = text.toLowerCase();
    
    final criticalPhrases = [
      'want to die',
      'kill myself',
      'end my life',
      'not worth living',
      'better off dead',
      'suicide',
      'self harm',
      'hurt myself',
      'end it all',
    ];
    
    for (final phrase in criticalPhrases) {
      if (lowerText.contains(phrase)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Calculate emotional intensity from entry text
  static double _calculateEmotionalIntensity(String text) {
    final lowerText = text.toLowerCase();
    
    // High-intensity emotional words
    final intensityMarkers = [
      'devastated',
      'destroyed',
      'shattered',
      'broken',
      'overwhelmed',
      'terrified',
      'panic',
      'desperate',
      'anguish',
      'agony',
      'torture',
      'unbearable',
      'excruciating',
      'can\'t do this',
      'can\'t take it',
      'falling apart',
      'give up',
      'hopeless',
      'worthless',
    ];
    
    int count = 0;
    for (final marker in intensityMarkers) {
      if (lowerText.contains(marker)) {
        count++;
      }
    }
    
    // Normalize to 0-1 scale
    return (count * 0.25).clamp(0.0, 1.0);
  }
}

/// SENTINEL score result
class SentinelScore {
  final double score;           // 0.0 to 1.0
  final bool alert;             // true if crisis mode should activate
  final String reason;          // Why this score was given
  final List<String> triggerEntries;  // Which entries contributed
  final Duration timespan;      // Time period analyzed
  
  SentinelScore({
    required this.score,
    required this.alert,
    required this.reason,
    required this.triggerEntries,
    required this.timespan,
  });
}

/// Crisis entry with intensity
class CrisisEntry {
  final String text;
  final double intensity;
  final DateTime timestamp;
  
  CrisisEntry({
    required this.text,
    required this.intensity,
    required this.timestamp,
  });
}


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/services/sentinel/sentinel_analyzer.dart';
import 'package:my_app/services/sentinel/sentinel_config.dart';

/// Manages crisis mode activation and deactivation with 48-hour cooldown
class CrisisMode {
  static final _firestore = FirebaseFirestore.instance;
  
  /// Check if user is currently in crisis mode
  static Future<bool> isInCrisisMode(String userId) async {
    try {
      final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('sentinel_state')
        .doc('crisis_mode')
        .get();
      
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      final activatedAt = (data['activated_at'] as Timestamp).toDate();
      final hoursSince = DateTime.now().difference(activatedAt).inHours;
      
      // Auto-deactivate after cooldown period
      if (hoursSince >= SentinelConfig.CRISIS_COOLDOWN_HOURS) {
        await _deactivateCrisisMode(userId, 'cooldown_expired');
        return false;
      }
      
      return true;
      
    } catch (e) {
      print('Error checking crisis mode: $e');
      return false;
    }
  }
  
  /// Get crisis mode details (for UI display)
  static Future<CrisisModeInfo?> getCrisisModeInfo(String userId) async {
    try {
      final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('sentinel_state')
        .doc('crisis_mode')
        .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      final activatedAt = (data['activated_at'] as Timestamp).toDate();
      final hoursSince = DateTime.now().difference(activatedAt).inHours;
      final hoursRemaining = SentinelConfig.CRISIS_COOLDOWN_HOURS - hoursSince;
      
      return CrisisModeInfo(
        activatedAt: activatedAt,
        sentinelScore: data['sentinel_score'] as double? ?? 0.0,
        reason: data['reason'] as String? ?? 'Unknown',
        triggerCount: data['trigger_count'] as int? ?? 0,
        timespanDays: data['timespan_days'] as int? ?? 0,
        hoursRemaining: hoursRemaining.clamp(0, SentinelConfig.CRISIS_COOLDOWN_HOURS),
      );
      
    } catch (e) {
      print('Error getting crisis mode info: $e');
      return null;
    }
  }
  
  /// Activate crisis mode with timestamp
  static Future<void> activateCrisisMode({
    required String userId,
    required SentinelScore sentinelScore,
  }) async {
    await _firestore
      .collection('users')
      .doc(userId)
      .collection('sentinel_state')
      .doc('crisis_mode')
      .set({
        'activated_at': FieldValue.serverTimestamp(),
        'sentinel_score': sentinelScore.score,
        'reason': sentinelScore.reason,
        'trigger_count': sentinelScore.triggerEntries.length,
        'timespan_days': sentinelScore.timespan.inDays,
      });
    
    print('🚨 CRISIS MODE ACTIVATED');
    print('   User: $userId');
    print('   Score: ${sentinelScore.score.toStringAsFixed(2)}');
    print('   Reason: ${sentinelScore.reason}');
    print('   Cooldown: ${SentinelConfig.CRISIS_COOLDOWN_HOURS} hours');
    
    // Analytics logging would go here
  }
  
  /// Deactivate crisis mode (auto or manual)
  static Future<void> _deactivateCrisisMode(String userId, String reason) async {
    await _firestore
      .collection('users')
      .doc(userId)
      .collection('sentinel_state')
      .doc('crisis_mode')
      .delete();
    
    print('✅ CRISIS MODE DEACTIVATED');
    print('   User: $userId');
    print('   Reason: $reason');
    
    // Analytics logging would go here
  }
  
  /// Manually deactivate (user requests or admin override)
  static Future<void> manualDeactivate(String userId) async {
    await _deactivateCrisisMode(userId, 'manual_override');
  }
}

/// Crisis mode information for UI display
class CrisisModeInfo {
  final DateTime activatedAt;
  final double sentinelScore;
  final String reason;
  final int triggerCount;
  final int timespanDays;
  final int hoursRemaining;
  
  CrisisModeInfo({
    required this.activatedAt,
    required this.sentinelScore,
    required this.reason,
    required this.triggerCount,
    required this.timespanDays,
    required this.hoursRemaining,
  });
}


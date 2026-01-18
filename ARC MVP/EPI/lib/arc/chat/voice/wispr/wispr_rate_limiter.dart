/// Wispr Flow Rate Limiter
/// 
/// Firebase-based rate limiting to prevent API abuse
/// - Tracks usage per user
/// - Daily and hourly limits
/// - Warns users when approaching limits
/// - Graceful degradation when limits exceeded

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Usage limits configuration
class WisprUsageLimits {
  final int dailyMinutes;
  final int hourlyMinutes;
  final int warningThresholdPercent;
  
  const WisprUsageLimits({
    this.dailyMinutes = 60, // 60 minutes per day
    this.hourlyMinutes = 15, // 15 minutes per hour
    this.warningThresholdPercent = 80, // Warn at 80%
  });
  
  int get dailySeconds => dailyMinutes * 60;
  int get hourlySeconds => hourlyMinutes * 60;
  int get dailyWarningSeconds => (dailySeconds * warningThresholdPercent ~/ 100);
  int get hourlyWarningSeconds => (hourlySeconds * warningThresholdPercent ~/ 100);
}

/// Usage statistics
class WisprUsageStats {
  final int dailySecondsUsed;
  final int hourlySecondsUsed;
  final int dailyLimit;
  final int hourlyLimit;
  final DateTime lastUpdated;
  
  const WisprUsageStats({
    required this.dailySecondsUsed,
    required this.hourlySecondsUsed,
    required this.dailyLimit,
    required this.hourlyLimit,
    required this.lastUpdated,
  });
  
  int get dailySecondsRemaining => dailyLimit - dailySecondsUsed;
  int get hourlySecondsRemaining => hourlyLimit - hourlySecondsUsed;
  
  int get dailyMinutesRemaining => dailySecondsRemaining ~/ 60;
  int get hourlyMinutesRemaining => hourlySecondsRemaining ~/ 60;
  
  double get dailyUsagePercent => (dailySecondsUsed / dailyLimit) * 100;
  double get hourlyUsagePercent => (hourlySecondsUsed / hourlyLimit) * 100;
  
  bool get isDailyLimitExceeded => dailySecondsUsed >= dailyLimit;
  bool get isHourlyLimitExceeded => hourlySecondsUsed >= hourlyLimit;
  bool get isLimitExceeded => isDailyLimitExceeded || isHourlyLimitExceeded;
  
  bool get isApproachingDailyLimit => dailyUsagePercent >= 80;
  bool get isApproachingHourlyLimit => hourlyUsagePercent >= 80;
  bool get isApproachingLimit => isApproachingDailyLimit || isApproachingHourlyLimit;
}

/// Rate limit result
enum RateLimitResult {
  allowed,
  dailyLimitExceeded,
  hourlyLimitExceeded,
  approachingLimit,
}

/// Rate limiter for Wispr Flow usage
class WisprRateLimiter {
  final FirebaseFirestore _firestore;
  final WisprUsageLimits _limits;
  final String _userId;
  
  DateTime? _sessionStartTime;
  
  WisprRateLimiter({
    required FirebaseFirestore firestore,
    required String userId,
    WisprUsageLimits? limits,
  })  : _firestore = firestore,
        _userId = userId,
        _limits = limits ?? const WisprUsageLimits();
  
  /// Check if user can start a new voice session
  Future<RateLimitResult> checkLimit() async {
    try {
      final stats = await getUsageStats();
      
      if (stats.isDailyLimitExceeded) {
        debugPrint('WisprRateLimit: Daily limit exceeded for user $_userId');
        return RateLimitResult.dailyLimitExceeded;
      }
      
      if (stats.isHourlyLimitExceeded) {
        debugPrint('WisprRateLimit: Hourly limit exceeded for user $_userId');
        return RateLimitResult.hourlyLimitExceeded;
      }
      
      if (stats.isApproachingLimit) {
        debugPrint('WisprRateLimit: User $_userId approaching limit');
        return RateLimitResult.approachingLimit;
      }
      
      return RateLimitResult.allowed;
      
    } catch (e) {
      debugPrint('WisprRateLimit: Error checking limit: $e');
      // On error, allow usage (fail open)
      return RateLimitResult.allowed;
    }
  }
  
  /// Get current usage statistics
  Future<WisprUsageStats> getUsageStats() async {
    final now = DateTime.now();
    final today = _getDateKey(now);
    final currentHour = _getHourKey(now);
    
    final docRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('wispr_usage')
        .doc(today);
    
    final snapshot = await docRef.get();
    
    if (!snapshot.exists) {
      return WisprUsageStats(
        dailySecondsUsed: 0,
        hourlySecondsUsed: 0,
        dailyLimit: _limits.dailySeconds,
        hourlyLimit: _limits.hourlySeconds,
        lastUpdated: now,
      );
    }
    
    final data = snapshot.data()!;
    final dailySeconds = data['total_seconds'] as int? ?? 0;
    final hourlyData = data['hourly'] as Map<String, dynamic>? ?? {};
    final hourlySeconds = hourlyData[currentHour] as int? ?? 0;
    
    return WisprUsageStats(
      dailySecondsUsed: dailySeconds,
      hourlySecondsUsed: hourlySeconds,
      dailyLimit: _limits.dailySeconds,
      hourlyLimit: _limits.hourlySeconds,
      lastUpdated: (data['last_updated'] as Timestamp?)?.toDate() ?? now,
    );
  }
  
  /// Start tracking a session
  void startSession() {
    _sessionStartTime = DateTime.now();
    debugPrint('WisprRateLimit: Session started for user $_userId');
  }
  
  /// End tracking and record usage
  Future<void> endSession() async {
    if (_sessionStartTime == null) {
      debugPrint('WisprRateLimit: No session to end');
      return;
    }
    
    final duration = DateTime.now().difference(_sessionStartTime!);
    final seconds = duration.inSeconds;
    
    debugPrint('WisprRateLimit: Session ended. Duration: ${seconds}s');
    
    await _recordUsage(seconds);
    _sessionStartTime = null;
  }
  
  /// Record usage in Firestore
  Future<void> _recordUsage(int seconds) async {
    if (seconds <= 0) {
      debugPrint('WisprRateLimit: No usage to record');
      return;
    }
    
    try {
      final now = DateTime.now();
      final today = _getDateKey(now);
      final currentHour = _getHourKey(now);
      
      final docRef = _firestore
          .collection('users')
          .doc(_userId)
          .collection('wispr_usage')
          .doc(today);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        
        if (!snapshot.exists) {
          // Create new document
          transaction.set(docRef, {
            'total_seconds': seconds,
            'hourly': {currentHour: seconds},
            'last_updated': FieldValue.serverTimestamp(),
            'date': today,
          });
        } else {
          // Update existing document
          final data = snapshot.data()!;
          final currentTotal = data['total_seconds'] as int? ?? 0;
          final hourlyData = data['hourly'] as Map<String, dynamic>? ?? {};
          final currentHourly = hourlyData[currentHour] as int? ?? 0;
          
          transaction.update(docRef, {
            'total_seconds': currentTotal + seconds,
            'hourly.$currentHour': currentHourly + seconds,
            'last_updated': FieldValue.serverTimestamp(),
          });
        }
      });
      
      debugPrint('WisprRateLimit: Recorded ${seconds}s usage for user $_userId');
      
    } catch (e) {
      debugPrint('WisprRateLimit: Error recording usage: $e');
      // Don't throw - usage tracking failures shouldn't break the app
    }
  }
  
  /// Get date key for Firestore document (YYYY-MM-DD)
  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  /// Get hour key for hourly tracking (HH)
  String _getHourKey(DateTime date) {
    return date.hour.toString().padLeft(2, '0');
  }
  
  /// Clean up old usage data (call periodically)
  Future<void> cleanupOldData({int daysToKeep = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final cutoffKey = _getDateKey(cutoffDate);
      
      final querySnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('wispr_usage')
          .where('date', isLessThan: cutoffKey)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('WisprRateLimit: Cleaned up ${querySnapshot.docs.length} old records');
      
    } catch (e) {
      debugPrint('WisprRateLimit: Error cleaning up old data: $e');
    }
  }
  
  /// Get formatted warning message
  String getWarningMessage(WisprUsageStats stats) {
    if (stats.isDailyLimitExceeded) {
      return 'You\'ve reached your daily voice limit. Try again tomorrow.';
    }
    
    if (stats.isHourlyLimitExceeded) {
      return 'You\'ve reached your hourly voice limit. Try again in ${60 - DateTime.now().minute} minutes.';
    }
    
    if (stats.isApproachingDailyLimit) {
      return 'You have ${stats.dailyMinutesRemaining} minutes of voice time remaining today.';
    }
    
    if (stats.isApproachingHourlyLimit) {
      return 'You have ${stats.hourlyMinutesRemaining} minutes of voice time remaining this hour.';
    }
    
    return '';
  }
}

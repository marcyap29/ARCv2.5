/// Voice Usage Service
/// 
/// Tracks voice mode usage with monthly limits:
/// - Free users: 60 minutes per month
/// - Premium/Founders: Unlimited
/// 
/// Usage is stored locally and resets on the first of each month.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/services/subscription_service.dart';

/// Voice usage limits by subscription tier
class VoiceUsageLimits {
  /// Free users get 60 minutes per month
  static const int freeMinutesPerMonth = 60;
  
  /// Premium and Founders get unlimited (-1 = unlimited)
  static const int unlimitedMinutes = -1;
}

/// Voice usage statistics
class VoiceUsageStats {
  final int minutesUsed;
  final int minutesLimit; // -1 = unlimited
  final DateTime? lastUpdated;
  final String currentMonth; // Format: "2026-01"
  
  const VoiceUsageStats({
    required this.minutesUsed,
    required this.minutesLimit,
    this.lastUpdated,
    required this.currentMonth,
  });
  
  /// Minutes remaining (-1 if unlimited)
  int get minutesRemaining {
    if (minutesLimit == VoiceUsageLimits.unlimitedMinutes) return -1;
    return (minutesLimit - minutesUsed).clamp(0, minutesLimit);
  }
  
  /// Whether the user has exceeded their limit
  bool get isLimitExceeded {
    if (minutesLimit == VoiceUsageLimits.unlimitedMinutes) return false;
    return minutesUsed >= minutesLimit;
  }
  
  /// Whether the user is approaching their limit (80%+)
  bool get isApproachingLimit {
    if (minutesLimit == VoiceUsageLimits.unlimitedMinutes) return false;
    return minutesUsed >= (minutesLimit * 0.8);
  }
  
  /// Usage percentage (0-100, -1 if unlimited)
  double get usagePercent {
    if (minutesLimit == VoiceUsageLimits.unlimitedMinutes) return -1;
    if (minutesLimit == 0) return 100;
    return (minutesUsed / minutesLimit * 100).clamp(0, 100);
  }
  
  /// Whether this user has unlimited voice
  bool get isUnlimited => minutesLimit == VoiceUsageLimits.unlimitedMinutes;
}

/// Result of checking if voice can be used
class VoiceUsageCheckResult {
  final bool canUse;
  final String? message;
  final VoiceUsageStats stats;
  
  const VoiceUsageCheckResult({
    required this.canUse,
    this.message,
    required this.stats,
  });
}

/// Voice usage tracking service
class VoiceUsageService {
  static final VoiceUsageService _instance = VoiceUsageService._internal();
  factory VoiceUsageService() => _instance;
  VoiceUsageService._internal();
  
  static VoiceUsageService get instance => _instance;
  
  // SharedPreferences keys
  static const String _minutesUsedKey = 'voice_minutes_used';
  static const String _monthKey = 'voice_usage_month';
  static const String _lastUpdatedKey = 'voice_usage_last_updated';
  
  SharedPreferences? _prefs;
  
  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _checkMonthReset();
  }
  
  /// Ensure prefs are initialized
  Future<SharedPreferences> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }
  
  /// Get the current month string (e.g., "2026-01")
  String _getCurrentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }
  
  /// Check if we need to reset usage for a new month
  Future<void> _checkMonthReset() async {
    final prefs = await _ensurePrefs();
    final storedMonth = prefs.getString(_monthKey);
    final currentMonth = _getCurrentMonth();
    
    if (storedMonth != currentMonth) {
      // New month - reset usage
      debugPrint('VoiceUsage: New month detected ($storedMonth → $currentMonth), resetting usage');
      await prefs.setInt(_minutesUsedKey, 0);
      await prefs.setString(_monthKey, currentMonth);
      await prefs.setString(_lastUpdatedKey, DateTime.now().toIso8601String());
    }
  }
  
  /// Get usage limit based on subscription tier
  /// 
  /// Premium users (including founders) get unlimited voice
  /// Free users get 60 minutes per month
  Future<int> _getUsageLimit() async {
    final tier = await SubscriptionService.instance.getSubscriptionTier();
    
    switch (tier) {
      case SubscriptionTier.premium:
        return VoiceUsageLimits.unlimitedMinutes;
      case SubscriptionTier.free:
        return VoiceUsageLimits.freeMinutesPerMonth;
    }
  }
  
  /// Get current usage statistics
  Future<VoiceUsageStats> getUsageStats() async {
    await _checkMonthReset();
    final prefs = await _ensurePrefs();
    
    final minutesUsed = prefs.getInt(_minutesUsedKey) ?? 0;
    final minutesLimit = await _getUsageLimit();
    final lastUpdatedStr = prefs.getString(_lastUpdatedKey);
    final currentMonth = _getCurrentMonth();
    
    DateTime? lastUpdated;
    if (lastUpdatedStr != null) {
      try {
        lastUpdated = DateTime.parse(lastUpdatedStr);
      } catch (_) {}
    }
    
    return VoiceUsageStats(
      minutesUsed: minutesUsed,
      minutesLimit: minutesLimit,
      lastUpdated: lastUpdated,
      currentMonth: currentMonth,
    );
  }
  
  /// Check if voice can be used (returns result with stats)
  Future<VoiceUsageCheckResult> canUseVoice() async {
    final stats = await getUsageStats();
    
    if (stats.isLimitExceeded) {
      return VoiceUsageCheckResult(
        canUse: false,
        message: 'You\'ve used all ${stats.minutesLimit} minutes of voice mode this month. '
            'Upgrade to Premium for unlimited voice conversations.',
        stats: stats,
      );
    }
    
    if (stats.isApproachingLimit) {
      final remaining = stats.minutesRemaining;
      return VoiceUsageCheckResult(
        canUse: true,
        message: '$remaining minutes remaining this month',
        stats: stats,
      );
    }
    
    return VoiceUsageCheckResult(
      canUse: true,
      stats: stats,
    );
  }
  
  /// Record voice usage (in seconds)
  /// 
  /// Call this when a voice session ends with the duration
  Future<void> recordUsage(int seconds) async {
    if (seconds <= 0) return;
    
    await _checkMonthReset();
    final prefs = await _ensurePrefs();
    
    // Get current limit to check if unlimited
    final limit = await _getUsageLimit();
    if (limit == VoiceUsageLimits.unlimitedMinutes) {
      debugPrint('VoiceUsage: Unlimited user, not tracking');
      return; // Don't track for unlimited users
    }
    
    // Convert seconds to minutes (round up)
    final minutes = (seconds / 60).ceil();
    
    final currentUsed = prefs.getInt(_minutesUsedKey) ?? 0;
    final newUsed = currentUsed + minutes;
    
    await prefs.setInt(_minutesUsedKey, newUsed);
    await prefs.setString(_lastUpdatedKey, DateTime.now().toIso8601String());
    
    debugPrint('VoiceUsage: Recorded $minutes minutes (total: $newUsed/${VoiceUsageLimits.freeMinutesPerMonth})');
  }
  
  /// Get a friendly message about remaining usage
  Future<String> getUsageMessage() async {
    final stats = await getUsageStats();
    
    if (stats.isUnlimited) {
      return 'Unlimited voice mode';
    }
    
    if (stats.isLimitExceeded) {
      return 'Monthly limit reached (${stats.minutesLimit} min)';
    }
    
    return '${stats.minutesRemaining} min remaining this month';
  }
  
  /// Check if current user has unlimited voice
  Future<bool> hasUnlimitedVoice() async {
    final limit = await _getUsageLimit();
    return limit == VoiceUsageLimits.unlimitedMinutes;
  }
  
  /// Reset usage (for testing or admin purposes)
  Future<void> resetUsage() async {
    final prefs = await _ensurePrefs();
    await prefs.setInt(_minutesUsedKey, 0);
    await prefs.setString(_lastUpdatedKey, DateTime.now().toIso8601String());
    debugPrint('VoiceUsage: Usage reset to 0');
  }
}

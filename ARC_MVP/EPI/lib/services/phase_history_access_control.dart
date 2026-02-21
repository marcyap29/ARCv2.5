// lib/services/phase_history_access_control.dart
// Access control wrapper for phase history based on subscription tier

import 'package:flutter/foundation.dart';
import 'package:my_app/services/subscription_service.dart';
import 'package:my_app/prism/atlas/phase/phase_history_repository.dart';

/// Access control service for phase history based on subscription tier
class PhaseHistoryAccessControl {
  static final PhaseHistoryAccessControl _instance = PhaseHistoryAccessControl._internal();
  factory PhaseHistoryAccessControl() => _instance;
  PhaseHistoryAccessControl._internal();

  static PhaseHistoryAccessControl get instance => _instance;

  // Free tier can access last 30 days of phase history
  static const Duration _freeTierHistoryLimit = Duration(days: 30);

  /// Get all phase history entries with subscription-based access control
  /// Free tier: Last 30 days only
  /// Premium tier: Full access
  Future<List<PhaseHistoryEntry>> getAllEntries() async {
    try {
      final tier = await SubscriptionService.instance.getSubscriptionTier();
      final allEntries = await PhaseHistoryRepository.getAllEntries();

      if (tier == SubscriptionTier.premium) {
        debugPrint('PhaseHistoryAccessControl: Premium tier - full access (${allEntries.length} entries)');
        return allEntries;
      }

      // Free tier - limit to last 30 days
      final cutoffDate = DateTime.now().subtract(_freeTierHistoryLimit);
      final limitedEntries = allEntries
          .where((entry) => entry.timestamp.isAfter(cutoffDate))
          .toList();

      debugPrint('PhaseHistoryAccessControl: Free tier - limited to last 30 days (${limitedEntries.length}/${allEntries.length} entries)');
      return limitedEntries;
    } catch (e) {
      debugPrint('PhaseHistoryAccessControl: Error in getAllEntries: $e');
      // Fallback to free tier limits on error
      final allEntries = await PhaseHistoryRepository.getAllEntries();
      final cutoffDate = DateTime.now().subtract(_freeTierHistoryLimit);
      return allEntries
          .where((entry) => entry.timestamp.isAfter(cutoffDate))
          .toList();
    }
  }

  /// Get phase history entries for a specific time range with access control
  Future<List<PhaseHistoryEntry>> getEntriesInRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final tier = await SubscriptionService.instance.getSubscriptionTier();

      // Premium tier - no restrictions
      if (tier == SubscriptionTier.premium) {
        return await PhaseHistoryRepository.getEntriesInRange(start, end);
      }

      // Free tier - enforce 30-day limit
      final cutoffDate = DateTime.now().subtract(_freeTierHistoryLimit);
      final effectiveStart = start.isBefore(cutoffDate) ? cutoffDate : start;

      debugPrint('PhaseHistoryAccessControl: Free tier - adjusted start date from $start to $effectiveStart');
      return await PhaseHistoryRepository.getEntriesInRange(effectiveStart, end);
    } catch (e) {
      debugPrint('PhaseHistoryAccessControl: Error in getEntriesInRange: $e');
      // Fallback to free tier limits on error
      final cutoffDate = DateTime.now().subtract(_freeTierHistoryLimit);
      final effectiveStart = start.isBefore(cutoffDate) ? cutoffDate : start;
      return await PhaseHistoryRepository.getEntriesInRange(effectiveStart, end);
    }
  }

  /// Get recent phase history entries with access control
  Future<List<PhaseHistoryEntry>> getRecentEntries(int count) async {
    try {
      final tier = await SubscriptionService.instance.getSubscriptionTier();

      // Premium tier - no restrictions
      if (tier == SubscriptionTier.premium) {
        return await PhaseHistoryRepository.getRecentEntries(count);
      }

      // Free tier - limit to 30 days
      final allRecent = await PhaseHistoryRepository.getRecentEntries(count);
      final cutoffDate = DateTime.now().subtract(_freeTierHistoryLimit);
      final filtered = allRecent
          .where((entry) => entry.timestamp.isAfter(cutoffDate))
          .toList();

      debugPrint('PhaseHistoryAccessControl: Free tier - filtered recent entries (${filtered.length}/${allRecent.length})');
      return filtered;
    } catch (e) {
      debugPrint('PhaseHistoryAccessControl: Error in getRecentEntries: $e');
      // Fallback to free tier limits on error
      final allRecent = await PhaseHistoryRepository.getRecentEntries(count);
      final cutoffDate = DateTime.now().subtract(_freeTierHistoryLimit);
      return allRecent
          .where((entry) => entry.timestamp.isAfter(cutoffDate))
          .toList();
    }
  }

  /// Check if user has access to a specific date range
  Future<bool> hasAccessToDateRange(DateTime start, DateTime end) async {
    try {
      final tier = await SubscriptionService.instance.getSubscriptionTier();

      // Premium always has access
      if (tier == SubscriptionTier.premium) {
        return true;
      }

      // Free tier - check if range is within 30 days
      final cutoffDate = DateTime.now().subtract(_freeTierHistoryLimit);
      return !start.isBefore(cutoffDate);
    } catch (e) {
      debugPrint('PhaseHistoryAccessControl: Error checking access: $e');
      // Restrictive default on error
      return false;
    }
  }

  /// Get the effective access date for the current tier
  Future<DateTime> getEffectiveAccessDate() async {
    try {
      final tier = await SubscriptionService.instance.getSubscriptionTier();

      if (tier == SubscriptionTier.premium) {
        // Premium has unlimited access - return very old date
        return DateTime(2000, 1, 1);
      }

      // Free tier - 30 days from now
      return DateTime.now().subtract(_freeTierHistoryLimit);
    } catch (e) {
      debugPrint('PhaseHistoryAccessControl: Error getting effective date: $e');
      // Conservative default on error
      return DateTime.now().subtract(_freeTierHistoryLimit);
    }
  }

  /// Get a user-friendly message about phase history access restrictions
  Future<String> getAccessLimitMessage() async {
    try {
      final tier = await SubscriptionService.instance.getSubscriptionTier();

      if (tier == SubscriptionTier.premium) {
        return 'You have full access to all phase history.';
      }

      return 'Free tier: Access limited to last 30 days. Upgrade to Premium for full history access.';
    } catch (e) {
      debugPrint('PhaseHistoryAccessControl: Error getting message: $e');
      return 'Access limited to recent history.';
    }
  }

  /// Check if user can access full phase history
  Future<bool> hasFullAccess() async {
    try {
      return await SubscriptionService.instance.hasPremiumAccess();
    } catch (e) {
      debugPrint('PhaseHistoryAccessControl: Error checking full access: $e');
      return false;
    }
  }

  /// Get statistics about accessible phase history
  Future<Map<String, dynamic>> getAccessStats() async {
    try {
      final tier = await SubscriptionService.instance.getSubscriptionTier();
      final allEntries = await PhaseHistoryRepository.getAllEntries();
      final accessibleEntries = await getAllEntries();

      return {
        'tier': tier.displayName,
        'totalEntries': allEntries.length,
        'accessibleEntries': accessibleEntries.length,
        'restrictedEntries': allEntries.length - accessibleEntries.length,
        'hasFullAccess': tier == SubscriptionTier.premium,
        'accessLimitDays': tier == SubscriptionTier.free ? 30 : null,
      };
    } catch (e) {
      debugPrint('PhaseHistoryAccessControl: Error getting stats: $e');
      return {
        'tier': 'Unknown',
        'totalEntries': 0,
        'accessibleEntries': 0,
        'restrictedEntries': 0,
        'hasFullAccess': false,
        'accessLimitDays': 30,
      };
    }
  }
}



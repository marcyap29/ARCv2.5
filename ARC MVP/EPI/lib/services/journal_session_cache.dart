import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to cache journal entry session data for restoration
class JournalSessionCache {
  static const String _cacheKey = 'journal_session_cache';
  static const String _emotionKey = 'journal_session_emotion';
  static const String _reasonKey = 'journal_session_reason';
  static const String _textContentKey = 'journal_session_text_content';
  static const String _mediaItemsKey = 'journal_session_media_items';
  static const String _timestampKey = 'journal_session_timestamp';

  /// Cache the current journal session data
  static Future<void> cacheSession({
    String? emotion,
    String? reason,
    String? textContent,
    List<Map<String, dynamic>>? mediaItems,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cache individual fields
      if (emotion != null) {
        await prefs.setString(_emotionKey, emotion);
      }
      if (reason != null) {
        await prefs.setString(_reasonKey, reason);
      }
      if (textContent != null) {
        await prefs.setString(_textContentKey, textContent);
      }
      if (mediaItems != null) {
        await prefs.setString(_mediaItemsKey, jsonEncode(mediaItems));
      }
      
      // Update timestamp
      await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
      
      print('DEBUG: Journal session cached - emotion: $emotion, reason: $reason, textLength: ${textContent?.length ?? 0}');
    } catch (e) {
      print('ERROR: Failed to cache journal session: $e');
    }
  }

  /// Restore the cached journal session data
  static Future<JournalSessionData?> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if cache exists and is recent (within 24 hours)
      final timestamp = prefs.getInt(_timestampKey);
      if (timestamp == null) return null;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final hoursSinceCache = now.difference(cacheTime).inHours;
      
      // Only restore if cache is less than 24 hours old
      if (hoursSinceCache > 24) {
        print('DEBUG: Journal session cache expired (${hoursSinceCache}h old)');
        await clearSession();
        return null;
      }
      
      final emotion = prefs.getString(_emotionKey);
      final reason = prefs.getString(_reasonKey);
      final textContent = prefs.getString(_textContentKey);
      final mediaItemsJson = prefs.getString(_mediaItemsKey);
      
      List<Map<String, dynamic>>? mediaItems;
      if (mediaItemsJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(mediaItemsJson);
          mediaItems = decoded.cast<Map<String, dynamic>>();
        } catch (e) {
          print('ERROR: Failed to decode media items: $e');
        }
      }
      
      // Only return data if we have at least an emotion or text content
      if (emotion != null || textContent != null) {
        print('DEBUG: Journal session restored - emotion: $emotion, reason: $reason, textLength: ${textContent?.length ?? 0}');
        return JournalSessionData(
          emotion: emotion,
          reason: reason,
          textContent: textContent,
          mediaItems: mediaItems,
          timestamp: cacheTime,
        );
      }
      
      return null;
    } catch (e) {
      print('ERROR: Failed to restore journal session: $e');
      return null;
    }
  }

  /// Clear the cached session data
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_emotionKey);
      await prefs.remove(_reasonKey);
      await prefs.remove(_textContentKey);
      await prefs.remove(_mediaItemsKey);
      await prefs.remove(_timestampKey);
      print('DEBUG: Journal session cache cleared');
    } catch (e) {
      print('ERROR: Failed to clear journal session: $e');
    }
  }

  /// Check if there's a valid cached session
  static Future<bool> hasCachedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_timestampKey);
      if (timestamp == null) return false;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final hoursSinceCache = now.difference(cacheTime).inHours;
      
      return hoursSinceCache <= 24;
    } catch (e) {
      print('ERROR: Failed to check cached session: $e');
      return false;
    }
  }
}

/// Data class for journal session cache
class JournalSessionData {
  final String? emotion;
  final String? reason;
  final String? textContent;
  final List<Map<String, dynamic>>? mediaItems;
  final DateTime timestamp;

  JournalSessionData({
    this.emotion,
    this.reason,
    this.textContent,
    this.mediaItems,
    required this.timestamp,
  });

  /// Check if this session has meaningful data
  bool get hasData => emotion != null || (textContent?.isNotEmpty ?? false);

  /// Get a summary of the cached data
  String get summary {
    final parts = <String>[];
    if (emotion != null) parts.add('Emotion: $emotion');
    if (reason != null) parts.add('Reason: $reason');
    if (textContent?.isNotEmpty ?? false) {
      parts.add('Text: ${textContent!.length} chars');
    }
    if (mediaItems?.isNotEmpty ?? false) {
      parts.add('Media: ${mediaItems!.length} items');
    }
    return parts.join(', ');
  }
}

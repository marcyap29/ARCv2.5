/// Pending Conversation Service
/// 
/// Tracks user inputs that were submitted but didn't receive a response
/// (e.g., due to phone call, app crash, network error).
/// Allows resubmission of these inputs.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Pending conversation input
class PendingInput {
  final String userText;
  final String mode; // 'voice' or 'chat'
  final DateTime timestamp;
  final Map<String, dynamic>? context; // Additional context (voice context, conversation mode, etc.)
  final String? sessionId; // Session ID if applicable

  PendingInput({
    required this.userText,
    required this.mode,
    required this.timestamp,
    this.context,
    this.sessionId,
  });

  Map<String, dynamic> toJson() => {
    'userText': userText,
    'mode': mode,
    'timestamp': timestamp.toIso8601String(),
    'context': context,
    'sessionId': sessionId,
  };

  factory PendingInput.fromJson(Map<String, dynamic> json) => PendingInput(
    userText: json['userText'] as String,
    mode: json['mode'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    context: json['context'] as Map<String, dynamic>?,
    sessionId: json['sessionId'] as String?,
  );
}

/// Service to manage pending conversation inputs
class PendingConversationService {
  static const String _pendingInputKey = 'pending_conversation_input';
  static const String _pendingInputTimestampKey = 'pending_conversation_timestamp';
  static const String _cleanShutdownKey = 'app_clean_shutdown';
  static const String _crashDetectedKey = 'crash_detected';

  /// Save a pending input (when user submits but response hasn't completed)
  static Future<void> savePendingInput(PendingInput input) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingInputKey, jsonEncode(input.toJson()));
      await prefs.setString(_pendingInputTimestampKey, input.timestamp.toIso8601String());
      print('PendingConversationService: Saved pending input (${input.mode} mode)');
    } catch (e) {
      print('PendingConversationService: Error saving pending input: $e');
    }
  }

  /// Get pending input if it exists
  static Future<PendingInput?> getPendingInput() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final inputJson = prefs.getString(_pendingInputKey);
      if (inputJson == null) return null;

      final input = PendingInput.fromJson(jsonDecode(inputJson) as Map<String, dynamic>);
      
      // Check if input is too old (older than 1 hour, likely stale)
      final now = DateTime.now();
      final age = now.difference(input.timestamp);
      if (age.inHours > 1) {
        print('PendingConversationService: Pending input is too old (${age.inHours}h), clearing');
        await clearPendingInput();
        return null;
      }

      return input;
    } catch (e) {
      print('PendingConversationService: Error getting pending input: $e');
      return null;
    }
  }

  /// Clear pending input (when response completes successfully)
  static Future<void> clearPendingInput() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingInputKey);
      await prefs.remove(_pendingInputTimestampKey);
      // Mark clean shutdown when clearing pending input
      await prefs.setBool(_cleanShutdownKey, true);
      print('PendingConversationService: Cleared pending input');
    } catch (e) {
      print('PendingConversationService: Error clearing pending input: $e');
    }
  }

  /// Mark app shutdown as clean (call this when app is closing normally)
  static Future<void> markCleanShutdown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cleanShutdownKey, true);
    } catch (e) {
      print('PendingConversationService: Error marking clean shutdown: $e');
    }
  }

  /// Check if app crashed (had pending input but didn't shut down cleanly)
  static Future<bool> checkForCrash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if there's a pending input
      final hasPending = await hasPendingInput();
      if (!hasPending) {
        // No pending input, no crash
        await prefs.remove(_crashDetectedKey);
        return false;
      }

      // Check if app shut down cleanly
      final cleanShutdown = prefs.getBool(_cleanShutdownKey) ?? false;
      
      if (!cleanShutdown) {
        // Had pending input but didn't shut down cleanly = crash detected
        await prefs.setBool(_crashDetectedKey, true);
        return true;
      }

      // Had pending input but shut down cleanly = no crash (user just closed app)
      await prefs.remove(_crashDetectedKey);
      return false;
    } catch (e) {
      print('PendingConversationService: Error checking for crash: $e');
      return false;
    }
  }

  /// Clear crash detection flag (after showing banner to user)
  static Future<void> clearCrashDetection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_crashDetectedKey);
      // Reset clean shutdown flag for next session
      await prefs.setBool(_cleanShutdownKey, false);
    } catch (e) {
      print('PendingConversationService: Error clearing crash detection: $e');
    }
  }

  /// Initialize on app start - checks for crash and marks shutdown as not clean for next time
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Mark shutdown as not clean initially (will be set to true if app closes normally)
      await prefs.setBool(_cleanShutdownKey, false);
      print('PendingConversationService: Initialized - will detect crashes');
    } catch (e) {
      print('PendingConversationService: Error initializing: $e');
    }
  }

  /// Check if there's a pending input
  static Future<bool> hasPendingInput() async {
    final input = await getPendingInput();
    return input != null;
  }
}

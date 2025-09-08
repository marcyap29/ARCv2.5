import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'fr_settings.dart';
import 'fr_settings_cubit.dart';
import 'widgets/what_changes_sheet.dart';

class FRModeSuggestionService {
  static const String _hiveBox = 'fr_mode_suggestions';
  static const String _dismissedKey = 'dismissed_suggestion';
  static const String _lastSuggestionKey = 'last_suggestion_time';
  
  late final Box _box;

  FRModeSuggestionService() {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox(_hiveBox);
  }

  /// Check if we should suggest first responder mode based on text content
  Future<bool> shouldSuggestFRMode(String text, FRSettings currentSettings) async {
    // Don't suggest if FR mode is already enabled
    if (currentSettings.isEnabled) return false;
    
    // Don't suggest if user dismissed permanently
    if (await _wasPermanentlyDismissed()) return false;
    
    // Don't suggest too frequently (once per day max)
    if (await _wasRecentlySuggested()) return false;
    
    // Check if text contains first responder keywords
    final frScore = _calculateFRScore(text.toLowerCase());
    
    // Threshold for suggesting FR mode (can be adjusted)
    return frScore >= 2;
  }

  /// Show first responder mode suggestion popup
  void showFRModeSuggestion(
    BuildContext context,
    FRSettingsCubit frCubit, {
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.local_hospital_outlined,
              color: Color(0xFF4F46E5),
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'First Responder Mode?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your journal contains first responder terminology. Would you like to enable specialized tools for first responders?',
              style: TextStyle(
                color: Color(0xFFB4B4C7),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Features include:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• Text redaction for sharing entries\n'
              '• Rapid debrief after heavy calls\n'
              '• Post-call check-in suggestions\n'
              '• Shift-aware prompting',
              style: TextStyle(
                color: Color(0xFFB4B4C7),
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _recordDismissal(temporary: true);
              onDismiss?.call();
            },
            child: const Text(
              'Not now',
              style: TextStyle(
                color: Color(0xFFB4B4C7),
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _recordDismissal(temporary: true);
              _showNeverAskOption(context);
            },
            child: const Text(
              'Never ask',
              style: TextStyle(
                color: Color(0xFFB4B4C7),
                fontSize: 14,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _recordSuggestionShown();
              _showWhatChangesAndEnable(context, frCubit);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Enable',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showNeverAskOption(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Disable Suggestions?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Are you sure you want to permanently disable first responder mode suggestions? You can still enable it manually in Settings.',
          style: TextStyle(
            color: Color(0xFFB4B4C7),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFB4B4C7)),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _recordDismissal(temporary: false);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showWhatChangesAndEnable(BuildContext context, FRSettingsCubit frCubit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const WhatChangesSheet(),
    ).then((_) {
      // Enable FR mode after user sees what changes
      frCubit.toggleMasterSwitch(true);
    });
  }

  /// Calculate first responder score based on keyword presence
  int _calculateFRScore(String text) {
    int score = 0;
    
    // First responder keywords (medium weight)
    final frKeywords = [
      'call', 'scene', 'patient', 'victim', 'emergency', 'trauma', 'accident',
      'fire', 'rescue', 'ambulance', 'hospital', 'injury', 'ems', 'cpr',
      'code', 'dispatch', 'response', 'unit', 'medic', 'paramedic',
      'police', 'officer', 'firefighter', 'first responder', 'shift'
    ];
    
    for (final keyword in frKeywords) {
      if (text.contains(keyword)) {
        score += 1;
      }
    }
    
    // Crisis terms (higher weight)
    final crisisTerms = [
      'overdose', 'cardiac arrest', 'crash', 'fatality', 'deceased',
      'critical', 'severe', 'casualties', 'disaster', 'shooting',
      'stabbing', 'violence', 'traumatic', 'code blue', 'code red'
    ];
    
    for (final term in crisisTerms) {
      if (text.contains(term)) {
        score += 2;
      }
    }
    
    // Professional terminology (high weight)
    final professionalTerms = [
      'on duty', 'off duty', 'radio', '10-4', 'copy that', 'dispatch',
      'en route', 'on scene', 'code', 'unit', 'responding'
    ];
    
    for (final term in professionalTerms) {
      if (text.contains(term)) {
        score += 2;
      }
    }
    
    return score;
  }

  Future<bool> _wasPermanentlyDismissed() async {
    final dismissal = _box.get(_dismissedKey);
    return dismissal == 'permanent';
  }

  Future<bool> _wasRecentlySuggested() async {
    final lastSuggestion = _box.get(_lastSuggestionKey);
    if (lastSuggestion == null) return false;
    
    final lastTime = DateTime.fromMillisecondsSinceEpoch(lastSuggestion as int);
    final now = DateTime.now();
    final difference = now.difference(lastTime);
    
    // Don't suggest again within 24 hours
    return difference.inHours < 24;
  }

  void _recordSuggestionShown() {
    _box.put(_lastSuggestionKey, DateTime.now().millisecondsSinceEpoch);
  }

  void _recordDismissal({required bool temporary}) {
    if (temporary) {
      _recordSuggestionShown(); // Use the same cooldown mechanism
    } else {
      _box.put(_dismissedKey, 'permanent');
    }
  }

  /// Reset all suggestion states (useful for testing)
  Future<void> resetSuggestionStates() async {
    await _box.delete(_dismissedKey);
    await _box.delete(_lastSuggestionKey);
  }
}
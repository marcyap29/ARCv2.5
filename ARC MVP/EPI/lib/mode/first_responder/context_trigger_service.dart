import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../models/journal_entry_model.dart';
import 'fr_settings.dart';
import 'debrief/debrief_flow_screen.dart';
import '../../features/arcforms/services/emotional_valence_service.dart';

class ContextTriggerService {
  static const String _lastTriggerKey = 'last_debrief_trigger';
  static const String _dismissedTodayKey = 'dismissed_debrief_today';
  
  final Box _box;
  final EmotionalValenceService _emotionalService = EmotionalValenceService();

  ContextTriggerService(this._box);

  /// Check if we should offer a debrief after saving this entry
  Future<bool> shouldOfferDebrief({
    required JournalEntry entry,
    required FRSettings settings,
  }) async {
    // Check if feature is enabled
    if (!settings.postHeavyEntryCheckIn) return false;
    
    // Check if already dismissed today
    if (await _wasDismissedToday()) return false;
    
    // Check if we recently offered a debrief (within last 2 hours)
    if (await _wasRecentlyTriggered()) return false;
    
    // Analyze entry intensity
    final isHeavyEntry = await _isHeavyEntry(entry);
    
    return isHeavyEntry;
  }

  /// Show the debrief offer snackbar
  void showDebriefOffer(
    BuildContext context, {
    required VoidCallback onStartDebrief,
    required VoidCallback onDismiss,
  }) {
    final snackBar = SnackBar(
      content: const Text(
        'Start a quick debrief?',
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF4F46E5), // FR primary color
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: 'Begin',
        textColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _recordTriggerShown();
          onStartDebrief();
        },
      ),
      onVisible: () {
        _recordTriggerShown();
        // Listen for snackbar dismissal
        Future.delayed(const Duration(seconds: 8), () {
          if (context.mounted) {
            onDismiss();
          }
        });
      },
      dismissDirection: DismissDirection.horizontal,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Launch the debrief flow
  void launchDebriefFlow(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DebriefFlowScreen(
          onCompleted: () {
            // Debrief completed - could trigger analytics or other actions
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }

  /// Mark that user dismissed the offer for today
  Future<void> markDismissedToday() async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month}-${today.day}';
    await _box.put(_dismissedTodayKey, dateKey);
  }

  /// Check if the entry qualifies as "heavy" based on multiple factors
  Future<bool> _isHeavyEntry(JournalEntry entry) async {
    int heavyScore = 0;
    
    // 1. Check for FR-related keywords
    final frKeywords = _getFRKeywords();
    final entryText = entry.content.toLowerCase();
    final foundFRKeywords = frKeywords.where(
      (keyword) => entryText.contains(keyword.toLowerCase())
    ).length;
    
    if (foundFRKeywords >= 3) {
      heavyScore += 2;
    } else if (foundFRKeywords >= 1) heavyScore += 1;
    
    // 2. Check emotional valence using existing service
    final keywords = entry.keywords;
    int negativeEmotions = 0;
    for (final keyword in keywords) {
      final color = _emotionalService.getEmotionalColor(keyword);
      // Check if color tends toward red/orange spectrum (negative emotions)
      if (_isNegativeEmotionalColor(color)) {
        negativeEmotions++;
      }
    }
    
    if (negativeEmotions >= 3) {
      heavyScore += 2;
    } else if (negativeEmotions >= 1) heavyScore += 1;
    
    // 3. Check entry length (longer entries might indicate processing heavy content)
    final wordCount = entryText.split(' ').length;
    if (wordCount >= 200) heavyScore += 1;
    
    // 4. Check for crisis-related terms
    final crisisTerms = _getCrisisTerms();
    final foundCrisisTerms = crisisTerms.where(
      (term) => entryText.contains(term.toLowerCase())
    ).length;
    
    if (foundCrisisTerms >= 1) heavyScore += 2;
    
    // 5. Check mood if available
    final mood = entry.mood;
    if (['difficult', 'challenging', 'tough', 'hard', 'overwhelmed'].contains(mood)) {
      heavyScore += 1;
    }
    
    // Threshold for offering debrief (can be adjusted)
    return heavyScore >= 3;
  }

  List<String> _getFRKeywords() {
    return [
      'call', 'scene', 'patient', 'victim', 'emergency', 'trauma', 'accident',
      'fire', 'rescue', 'ambulance', 'hospital', 'injury', 'death', 'loss',
      'code', 'dispatch', 'response', 'unit', 'medic', 'paramedic', 'ems',
      'police', 'officer', 'firefighter', 'first responder', 'shift',
      'overtime', 'exhausted', 'stress', 'pressure', 'adrenaline'
    ];
  }

  List<String> _getCrisisTerms() {
    return [
      'suicide', 'overdose', 'cardiac arrest', 'crash', 'fatality', 'deceased',
      'critical', 'severe', 'multiple casualties', 'mass casualty', 'disaster',
      'shooting', 'stabbing', 'violence', 'abuse', 'neglect', 'pediatric',
      'infant', 'child', 'family', 'witnessed', 'traumatic'
    ];
  }

  bool _isNegativeEmotionalColor(Color color) {
    // Simple heuristic: colors with high red component and lower green/blue
    // typically indicate negative emotions in the emotional valence system
    return color.red > 180 && 
           (color.green < 150 || color.blue < 150);
  }

  Future<bool> _wasDismissedToday() async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month}-${today.day}';
    final dismissedDate = _box.get(_dismissedTodayKey);
    return dismissedDate == dateKey;
  }

  Future<bool> _wasRecentlyTriggered() async {
    final lastTrigger = _box.get(_lastTriggerKey);
    if (lastTrigger == null) return false;
    
    final lastTriggerTime = DateTime.fromMillisecondsSinceEpoch(lastTrigger as int);
    final now = DateTime.now();
    final difference = now.difference(lastTriggerTime);
    
    // Don't trigger again within 2 hours
    return difference.inHours < 2;
  }

  void _recordTriggerShown() {
    _box.put(_lastTriggerKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Reset all trigger states (useful for testing or debugging)
  Future<void> resetTriggerStates() async {
    await _box.delete(_lastTriggerKey);
    await _box.delete(_dismissedTodayKey);
  }

  /// Get trigger statistics (for debugging or analytics)
  Map<String, dynamic> getTriggerStats() {
    return {
      'lastTrigger': _box.get(_lastTriggerKey),
      'dismissedToday': _box.get(_dismissedTodayKey),
    };
  }
}
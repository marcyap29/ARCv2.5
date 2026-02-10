class Copy {
  // Start Entry Flow
  static const String emotionTitle = "How are you feeling today?";
  static const String reasonTitle = "What's most connected to that feeling?";
  static const String editorPlaceholder = "Write what is true right now.";
  static const String editorSubtext = "You can always add more later.";
  
  // Phase Recommendation
  static const String recModalTitle = "We sensed a phase for this moment.";
  static String recModalBody(String phase) => 
      "Based on what you shared, $phase may fit. You can keep it, or explore the others.";
  static String keepPhase(String phase) => "Keep $phase";
  static const String seeOtherPhases = "See other phases";
  
  // Phase Consent
  static String consentTitle(String phase) => "Change your phase to $phase?";
  static const String consentBody = "Your Arcform's shape will update.";
  static const String cancel = "Cancel";
  static const String ok = "OK";
  
  // Phase Descriptions
  static const Map<String, String> phaseDescriptions = {
    'Discovery': 'Exploring new ground; curiosity leads you.',
    'Expansion': 'Growing outward; energy and possibility.',
    'Transition': 'Between places; moving from one shape to another.',
    'Consolidation': 'Weaving pieces together; grounding.',
    'Recovery': 'Rest and repair; gentleness and breath.',
    'Breakthrough': 'Sudden clarity; a pattern becomes light.',
  };
  
  // Emotions
  static const List<String> emotions = [
    'Excited', 'Happy', 'Blessed', 'Relaxed', 
    'Depressed', 'Stressed', 'Anxious', 'Angry', 'Other'
  ];
  
  // Emotion Reasons
  static const List<String> emotionReasons = [
    'My Faith', 'Relationship', 'Finances', 'Work', 
    'School', 'Family', 'Health', 'Weather', 'Other'
  ];
  
  // RIVET Simple Copy (P27) - Simplified UI/UX
  static const String rivetTitle = "Phase Change Readiness";
  static const String rivetSubtitle = "Your journal entries show you're ready for a new phase";
  static const String rivetTooltip = "We analyze your journal entries to determine when you're ready for a new phase.";
  
  // Simplified status messages
  static const String rivetStatusReady = "Ready to explore a new phase";
  static const String rivetStatusAlmost = "Almost ready - keep journaling for 1-2 more days";
  static const String rivetStatusNotReady = "Keep journaling to unlock your next phase";
  
  // Action buttons
  static const String rivetActionChangePhase = "Change Phase";
  static const String rivetActionKeepJournaling = "Keep Journaling";
  static const String rivetActionWhy = "Why?";
  
  // Progress indicators
  static const String rivetProgressReady = "Ready";
  static const String rivetProgressAlmost = "Almost ready";
  static const String rivetProgressNotReady = "Not ready";
  
  static const String rivetDetailsTitle = "Why is this held?";
  static const String rivetDetailsBlurb = "LUMARA changes your phase only when three checks pass: your entries match a new phase, we have enough confidence, and the signal stays consistent for a short time with one independent confirmation.";
  static String rivetDetailsValuesMatch(int percent) => "Match: $percent%";
  static String rivetDetailsValuesConfidence(int percent) => "Confidence: $percent%";
  static String rivetDetailsValuesConsistency(int current, int target) => "Consistency: $current/$target days";
  static String rivetDetailsValuesIndependent(String yesNo) => "Independent check: $yesNo";
  
  static const String rivetStateReady = "Ready to switch. All checks passed.";
  static const String rivetStateAlmost = "Almost there. Confidence looks good. We are waiting for one more day of similar entries.";
  static const String rivetStateHold = "On hold. Your recent entries do not yet match a new phase.";
  
  static const String rivetNudge = "What to do: Add one or two entries over the next couple of days. A second, separate signal will unlock the change.";
}
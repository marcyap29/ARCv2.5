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
  
  // RIVET Simple Copy (P27)
  static const String rivetTitle = "Phase change safety check";
  static const String rivetSubtitle = "ARC only switches phases when the signal is clear.";
  static const String rivetTooltip = "RIVET is the safety system that prevents jumpy phase flips.";
  
  static const String rivetDialMatch = "Match";
  static const String rivetDialConfidence = "Confidence";
  static const String rivetDialGood = "Good";
  static const String rivetDialLow = "Low";
  
  static const String rivetBannerHeld = "Holding steady. We need a clearer signal before changing your phase.";
  static const String rivetBannerReady = "Ready to switch. All checks passed.";
  static const String rivetBannerWhy = "Why held?";
  
  static String rivetCheckMatch(String level) => "Match: $level";
  static String rivetCheckConfidence(String level) => "Confidence: $level";
  static String rivetCheckConsistency(int current, int target) => "Consistency: $current/$target days";
  static const String rivetCheckIndependentMissing = "Independent check: Missing";
  static const String rivetCheckIndependentOk = "Independent check: Complete";
  
  static const String rivetDetailsTitle = "Why is this held?";
  static const String rivetDetailsBlurb = "ARC changes your phase only when three checks pass: your entries match a new phase, we have enough confidence, and the signal stays consistent for a short time with one independent confirmation.";
  static String rivetDetailsValuesMatch(int percent) => "Match: $percent%";
  static String rivetDetailsValuesConfidence(int percent) => "Confidence: $percent%";
  static String rivetDetailsValuesConsistency(int current, int target) => "Consistency: $current/$target days";
  static String rivetDetailsValuesIndependent(String yesNo) => "Independent check: $yesNo";
  
  static const String rivetStateReady = "Ready to switch. All checks passed.";
  static const String rivetStateAlmost = "Almost there. Confidence looks good. We are waiting for one more day of similar entries.";
  static const String rivetStateHold = "On hold. Your recent entries do not yet match a new phase.";
  
  static const String rivetNudge = "What to do: Add one or two entries over the next couple of days. A second, separate signal will unlock the change.";
}
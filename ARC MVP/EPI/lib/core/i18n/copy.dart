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
}
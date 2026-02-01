// lib/arc/internal/echo/phase/quiz_models.dart
// Models for PhaseQuizV2 onboarding quiz system

/// Quiz question definition
class QuizQuestion {
  final String id;
  final String text;
  final String? subtitle;
  final List<QuizOption> options;
  final QuizCategory category;
  final bool multiSelect;
  final int? maxSelections;
  
  const QuizQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.category,
    this.subtitle,
    this.multiSelect = false,
    this.maxSelections,
  });
}

/// Quiz option (answer choice)
class QuizOption {
  final String value;      // Internal ID (e.g., 'transition')
  final String label;      // Display text
  
  const QuizOption(this.value, this.label);
}

/// Quiz categories for organizing questions
enum QuizCategory {
  phase,       // Current phase identification
  themes,      // Primary focus areas
  temporal,    // When this started
  emotional,   // Emotional state
  momentum,    // Direction of change
  stakes,      // What matters most
  behavioral,  // Approach style
  support,     // Support system
}

/// User's compiled profile from quiz answers
class UserProfile {
  String? currentPhase;
  List<String> dominantThemes = [];
  String? inflectionTiming;
  String? emotionalState;
  String? momentum;
  String? stakes;
  String? approachStyle;
  String? support;
  
  UserProfile();
  
  /// Convert to JSON for metadata storage
  Map<String, dynamic> toJson() {
    return {
      'currentPhase': currentPhase,
      'dominantThemes': dominantThemes,
      'inflectionTiming': inflectionTiming,
      'emotionalState': emotionalState,
      'momentum': momentum,
      'stakes': stakes,
      'approachStyle': approachStyle,
      'support': support,
    };
  }
  
  /// Create from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final profile = UserProfile();
    profile.currentPhase = json['currentPhase'];
    profile.dominantThemes = List<String>.from(json['dominantThemes'] ?? []);
    profile.inflectionTiming = json['inflectionTiming'];
    profile.emotionalState = json['emotionalState'];
    profile.momentum = json['momentum'];
    profile.stakes = json['stakes'];
    profile.approachStyle = json['approachStyle'];
    profile.support = json['support'];
    return profile;
  }
}

/// Quiz answer (what user selected for a question)
class QuizAnswer {
  final List<String> selectedOptions;
  
  QuizAnswer(this.selectedOptions);
  
  bool get isEmpty => selectedOptions.isEmpty;
  bool get isNotEmpty => selectedOptions.isNotEmpty;
}

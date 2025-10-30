/// AURORA - Circadian Intelligence Module
/// 
/// Models for circadian context and rhythm analysis

/// Circadian context containing window, chronotype, and rhythm score
class CircadianContext {
  final String window;     // 'morning' | 'afternoon' | 'evening'
  final String chronotype; // 'morning' | 'balanced' | 'evening'
  final double rhythmScore; // 0..1

  const CircadianContext({
    required this.window,
    required this.chronotype,
    required this.rhythmScore,
  });

  factory CircadianContext.fromJson(Map<String, dynamic> json) {
    return CircadianContext(
      window: json['window'] as String,
      chronotype: json['chronotype'] as String,
      rhythmScore: (json['rhythm_score'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'window': window,
      'chronotype': chronotype,
      'rhythm_score': rhythmScore,
    };
  }

  /// Check if this is a morning context
  bool get isMorning => window == 'morning';
  
  /// Check if this is an afternoon context
  bool get isAfternoon => window == 'afternoon';
  
  /// Check if this is an evening context
  bool get isEvening => window == 'evening';

  /// Check if user is a morning person
  bool get isMorningPerson => chronotype == 'morning';
  
  /// Check if user is an evening person
  bool get isEveningPerson => chronotype == 'evening';
  
  /// Check if user has balanced chronotype
  bool get isBalanced => chronotype == 'balanced';

  /// Check if rhythm is fragmented (low score)
  bool get isFragmented => rhythmScore < 0.45;
  
  /// Alias for isFragmented (for compatibility)
  bool get isRhythmFragmented => isFragmented;
  
  /// Check if rhythm is coherent (high score)
  bool get isCoherent => rhythmScore >= 0.55;

  @override
  String toString() {
    return 'CircadianContext(window: $window, chronotype: $chronotype, rhythmScore: ${rhythmScore.toStringAsFixed(2)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CircadianContext &&
        other.window == window &&
        other.chronotype == chronotype &&
        other.rhythmScore == rhythmScore;
  }

  @override
  int get hashCode => Object.hash(window, chronotype, rhythmScore);
}

/// Circadian profile containing learned patterns
class CircadianProfile {
  final String chronotype;
  final List<double> hourlyActivity; // 24-hour activity curve
  final double rhythmScore;
  final DateTime lastUpdated;
  final int entryCount;

  const CircadianProfile({
    required this.chronotype,
    required this.hourlyActivity,
    required this.rhythmScore,
    required this.lastUpdated,
    required this.entryCount,
  });

  factory CircadianProfile.fromJson(Map<String, dynamic> json) {
    return CircadianProfile(
      chronotype: json['chronotype'] as String,
      hourlyActivity: List<double>.from(json['hourly_activity'] as List),
      rhythmScore: (json['rhythm_score'] as num).toDouble(),
      lastUpdated: DateTime.parse(json['last_updated'] as String),
      entryCount: json['entry_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chronotype': chronotype,
      'hourly_activity': hourlyActivity,
      'rhythm_score': rhythmScore,
      'last_updated': lastUpdated.toIso8601String(),
      'entry_count': entryCount,
    };
  }

  /// Get the peak activity hour (0-23)
  int get peakHour {
    double maxActivity = hourlyActivity[0];
    int peakHour = 0;
    
    for (int i = 1; i < hourlyActivity.length; i++) {
      if (hourlyActivity[i] > maxActivity) {
        maxActivity = hourlyActivity[i];
        peakHour = i;
      }
    }
    
    return peakHour;
  }

  /// Get activity level for a specific hour
  double getActivityForHour(int hour) {
    if (hour < 0 || hour >= 24) return 0.0;
    return hourlyActivity[hour];
  }

  /// Check if the profile is based on sufficient data
  bool get isReliable => entryCount >= 8;

  @override
  String toString() {
    return 'CircadianProfile(chronotype: $chronotype, peakHour: $peakHour, rhythmScore: ${rhythmScore.toStringAsFixed(2)}, entries: $entryCount)';
  }
}

import 'package:equatable/equatable.dart';

/// P32: Grounding Pack Models
/// 30-90 second grounding exercises for first responders

/// Types of grounding exercises
enum GroundingExerciseType {
  boxBreathing,
  sensoryScan,
  muscleRelease,
  visualization,
  counting,
  affirmations,
}

/// Grounding exercise model
class GroundingExercise extends Equatable {
  final String id;
  final String title;
  final String description;
  final GroundingExerciseType type;
  final int durationSeconds;
  final List<String> instructions;
  final String? audioPrompt;
  final String? visualPrompt;
  final List<String> affirmations;
  final String category;

  const GroundingExercise({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.durationSeconds,
    required this.instructions,
    this.audioPrompt,
    this.visualPrompt,
    this.affirmations = const [],
    this.category = 'general',
  });

  /// Get duration in minutes
  double get durationMinutes => durationSeconds / 60.0;

  /// Get formatted duration string
  String get durationString {
    if (durationSeconds < 60) {
      return '${durationSeconds}s';
    } else {
      final minutes = durationSeconds ~/ 60;
      final seconds = durationSeconds % 60;
      if (seconds == 0) {
        return '${minutes}m';
      } else {
        return '${minutes}m ${seconds}s';
      }
    }
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        type,
        durationSeconds,
        instructions,
        audioPrompt,
        visualPrompt,
        affirmations,
        category,
      ];
}

/// Predefined grounding exercises
class GroundingExercises {
  static const List<GroundingExercise> exercises = [
    GroundingExercise(
      id: 'box_breathing',
      title: 'Box Breathing',
      description: '4-4-4-4 breathing pattern to calm your nervous system',
      type: GroundingExerciseType.boxBreathing,
      durationSeconds: 60,
      instructions: [
        'Sit comfortably with your back straight',
        'Inhale slowly for 4 counts',
        'Hold your breath for 4 counts',
        'Exhale slowly for 4 counts',
        'Hold empty for 4 counts',
        'Repeat for 1 minute',
        'Let your shoulders drop and relax',
      ],
      audioPrompt: 'Inhale 4, hold 4, exhale 4, hold 4. Repeat for one minute.',
      category: 'breathing',
    ),
    
    GroundingExercise(
      id: 'sensory_scan',
      title: '5-4-3-2-1 Sensory Scan',
      description: 'Ground yourself using your five senses',
      type: GroundingExerciseType.sensoryScan,
      durationSeconds: 90,
      instructions: [
        'Look around and name 5 things you can see',
        'Touch 4 things and notice their texture',
        'Listen for 3 sounds you can hear',
        'Identify 2 things you can smell',
        'Name 1 thing you can taste',
        'Take a deep breath and notice how you feel',
      ],
      category: 'sensory',
    ),
    
    GroundingExercise(
      id: 'muscle_release',
      title: 'Progressive Muscle Release',
      description: 'Release tension by tensing and relaxing muscle groups',
      type: GroundingExerciseType.muscleRelease,
      durationSeconds: 120,
      instructions: [
        'Start with your hands - make fists and hold for 5 seconds',
        'Release and notice the relaxation',
        'Tense your shoulders up to your ears for 5 seconds',
        'Release and let them drop',
        'Tense your jaw for 5 seconds, then release',
        'Tense your stomach muscles for 5 seconds, then release',
        'Finish with 3 deep breaths',
      ],
      category: 'physical',
    ),
    
    GroundingExercise(
      id: 'safe_place',
      title: 'Safe Place Visualization',
      description: 'Create a mental safe space for calm and peace',
      type: GroundingExerciseType.visualization,
      durationSeconds: 90,
      instructions: [
        'Close your eyes and imagine a safe, peaceful place',
        'Notice the colors, sounds, and smells around you',
        'Feel the temperature and texture of the environment',
        'Take a few moments to fully experience this place',
        'When you\'re ready, slowly open your eyes',
        'Carry this sense of safety with you',
      ],
      visualPrompt: 'Imagine your favorite peaceful place - beach, forest, or home',
      category: 'visualization',
    ),
    
    GroundingExercise(
      id: 'counting_backwards',
      title: 'Count Backwards from 100',
      description: 'Focus your mind by counting backwards',
      type: GroundingExerciseType.counting,
      durationSeconds: 60,
      instructions: [
        'Start counting backwards from 100',
        'Count by 3s: 100, 97, 94, 91...',
        'If you lose track, start over from 100',
        'Focus only on the numbers',
        'When you reach 1, take a deep breath',
        'Notice how your mind feels more focused',
      ],
      category: 'cognitive',
    ),
    
    GroundingExercise(
      id: 'affirmations',
      title: 'Positive Affirmations',
      description: 'Repeat positive statements to build resilience',
      type: GroundingExerciseType.affirmations,
      durationSeconds: 45,
      instructions: [
        'Take a deep breath and center yourself',
        'Repeat: "I am safe in this moment"',
        'Repeat: "I have the strength to handle this"',
        'Repeat: "This feeling will pass"',
        'Repeat: "I am doing my best"',
        'Take another deep breath and feel your strength',
      ],
      affirmations: [
        'I am safe in this moment',
        'I have the strength to handle this',
        'This feeling will pass',
        'I am doing my best',
        'I am resilient and capable',
      ],
      category: 'emotional',
    ),
  ];

  /// Get exercises by category
  static List<GroundingExercise> getByCategory(String category) {
    return exercises.where((exercise) => exercise.category == category).toList();
  }

  /// Get exercises by type
  static List<GroundingExercise> getByType(GroundingExerciseType type) {
    return exercises.where((exercise) => exercise.type == type).toList();
  }

  /// Get exercises by duration range
  static List<GroundingExercise> getByDuration(int minSeconds, int maxSeconds) {
    return exercises.where((exercise) => 
        exercise.durationSeconds >= minSeconds && 
        exercise.durationSeconds <= maxSeconds).toList();
  }

  /// Get quick exercises (30-60 seconds)
  static List<GroundingExercise> getQuickExercises() {
    return getByDuration(30, 60);
  }

  /// Get medium exercises (60-90 seconds)
  static List<GroundingExercise> getMediumExercises() {
    return getByDuration(60, 90);
  }

  /// Get long exercises (90+ seconds)
  static List<GroundingExercise> getLongExercises() {
    return getByDuration(90, 300);
  }

  /// Get recommended exercises for stress level
  static List<GroundingExercise> getRecommendedForStress(int stressLevel) {
    if (stressLevel <= 3) {
      return getQuickExercises();
    } else if (stressLevel <= 6) {
      return getMediumExercises();
    } else {
      return getLongExercises();
    }
  }
}

/// Grounding session tracking
class GroundingSession extends Equatable {
  final String id;
  final String exerciseId;
  final DateTime startTime;
  final DateTime? endTime;
  final int stressLevelBefore;
  final int? stressLevelAfter;
  final bool completed;
  final String? notes;
  final String? trigger;

  const GroundingSession({
    required this.id,
    required this.exerciseId,
    required this.startTime,
    this.endTime,
    required this.stressLevelBefore,
    this.stressLevelAfter,
    this.completed = false,
    this.notes,
    this.trigger,
  });

  /// Get session duration
  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  /// Get stress reduction
  int? get stressReduction {
    if (stressLevelAfter == null) return null;
    return stressLevelBefore - stressLevelAfter!;
  }

  /// Check if session was effective
  bool get wasEffective {
    if (stressReduction == null) return false;
    return stressReduction! > 0;
  }

  GroundingSession copyWith({
    String? id,
    String? exerciseId,
    DateTime? startTime,
    DateTime? endTime,
    int? stressLevelBefore,
    int? stressLevelAfter,
    bool? completed,
    String? notes,
    String? trigger,
  }) {
    return GroundingSession(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      stressLevelBefore: stressLevelBefore ?? this.stressLevelBefore,
      stressLevelAfter: stressLevelAfter ?? this.stressLevelAfter,
      completed: completed ?? this.completed,
      notes: notes ?? this.notes,
      trigger: trigger ?? this.trigger,
    );
  }

  @override
  List<Object?> get props => [
        id,
        exerciseId,
        startTime,
        endTime,
        stressLevelBefore,
        stressLevelAfter,
        completed,
        notes,
        trigger,
      ];
}

/// Grounding statistics
class GroundingStatistics {
  final int totalSessions;
  final int completedSessions;
  final double averageStressReduction;
  final Map<String, int> exerciseUsage;
  final Map<String, double> exerciseEffectiveness;
  final List<String> mostEffectiveExercises;
  final double completionRate;

  const GroundingStatistics({
    required this.totalSessions,
    required this.completedSessions,
    required this.averageStressReduction,
    required this.exerciseUsage,
    required this.exerciseEffectiveness,
    required this.mostEffectiveExercises,
    required this.completionRate,
  });

  /// Check if statistics show good grounding habits
  bool get hasGoodHabits => completionRate > 0.7 && averageStressReduction > 1.0;
}

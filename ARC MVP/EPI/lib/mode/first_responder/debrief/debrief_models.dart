import 'package:equatable/equatable.dart';
import '../debrief/voice_debrief_service.dart';

class DebriefRecord extends Equatable {
  final String id;
  final DateTime createdAt;
  final String snapshot;
  final List<String> wentWell;   // chips + free text merged
  final List<String> wasHard;
  final int bodyScore;           // 1..5
  final bool breathCompleted;
  final String essence;
  final String nextStep;
  final List<VoiceRecording> voiceRecordings; // P28: Voice recordings for each step

  const DebriefRecord({
    required this.id,
    required this.createdAt,
    required this.snapshot,
    required this.wentWell,
    required this.wasHard,
    required this.bodyScore,
    required this.breathCompleted,
    required this.essence,
    required this.nextStep,
    this.voiceRecordings = const [],
  });

  @override
  List<Object?> get props => [
    id, createdAt, snapshot, wentWell, wasHard, 
    bodyScore, breathCompleted, essence, nextStep, voiceRecordings
  ];

  DebriefRecord copyWith({
    String? id,
    DateTime? createdAt,
    String? snapshot,
    List<String>? wentWell,
    List<String>? wasHard,
    int? bodyScore,
    bool? breathCompleted,
    String? essence,
    String? nextStep,
    List<VoiceRecording>? voiceRecordings,
  }) {
    return DebriefRecord(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      snapshot: snapshot ?? this.snapshot,
      wentWell: wentWell ?? this.wentWell,
      wasHard: wasHard ?? this.wasHard,
      bodyScore: bodyScore ?? this.bodyScore,
      breathCompleted: breathCompleted ?? this.breathCompleted,
      essence: essence ?? this.essence,
      nextStep: nextStep ?? this.nextStep,
      voiceRecordings: voiceRecordings ?? this.voiceRecordings,
    );
  }
}

enum DebriefStep {
  snapshot,
  reflection,
  bodyCheck,
  breathing,
  essence,
}

extension DebriefStepExtension on DebriefStep {
  String get title {
    switch (this) {
      case DebriefStep.snapshot:
        return 'Snapshot';
      case DebriefStep.reflection:
        return 'What went well / What was hard';
      case DebriefStep.bodyCheck:
        return 'Body check';
      case DebriefStep.breathing:
        return 'Two breaths';
      case DebriefStep.essence:
        return 'Essence & next step';
    }
  }

  String get prompt {
    switch (this) {
      case DebriefStep.snapshot:
        return 'Brief factual snapshot. Who/what/where in 1–3 lines.';
      case DebriefStep.reflection:
        return 'Select what went well and what was challenging.';
      case DebriefStep.bodyCheck:
        return 'How is your body right now?';
      case DebriefStep.breathing:
        return 'Take two deep breaths with me.';
      case DebriefStep.essence:
        return 'What\'s one thing to carry forward?';
    }
  }

  String get microcopy {
    switch (this) {
      case DebriefStep.snapshot:
        return 'Short is perfect.';
      case DebriefStep.reflection:
        return 'You can skip any step.';
      case DebriefStep.bodyCheck:
        return 'Just notice, no judgment.';
      case DebriefStep.breathing:
        return 'Optional but helpful.';
      case DebriefStep.essence:
        return 'One line is enough.';
    }
  }

  int get estimatedSeconds {
    switch (this) {
      case DebriefStep.snapshot:
        return 60;
      case DebriefStep.reflection:
        return 45;
      case DebriefStep.bodyCheck:
        return 15;
      case DebriefStep.breathing:
        return 40;
      case DebriefStep.essence:
        return 40;
    }
  }
}

// Predefined chips for quick selection
class DebriefChips {
  static const List<String> wentWell = [
    'Communication',
    'Teamwork', 
    'Technique',
    'Calm under pressure',
    'Quick thinking',
    'Patient care',
    'Scene safety',
    'Coordination',
  ];

  static const List<String> wasHard = [
    'Time pressure',
    'Uncertainty',
    'Environment',
    'Outcome',
    'Resources',
    'Communication',
    'Equipment',
    'Weather',
  ];

  static const List<String> bodySymptoms = [
    'Tight chest',
    'Shaky',
    'Headache',
    'Tense shoulders',
    'Okay',
    'Tired',
    'Restless',
    'Sore',
  ];
}
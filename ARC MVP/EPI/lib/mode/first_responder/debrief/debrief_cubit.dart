import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'debrief_models.dart';

// States
abstract class DebriefState extends Equatable {
  const DebriefState();
  
  @override
  List<Object?> get props => [];
}

class DebriefInitial extends DebriefState {
  const DebriefInitial();
}

class DebriefInProgress extends DebriefState {
  final DebriefStep currentStep;
  final DebriefRecord record;
  final DateTime startTime;
  final int stepCount;

  const DebriefInProgress({
    required this.currentStep,
    required this.record,
    required this.startTime,
    required this.stepCount,
  });

  @override
  List<Object?> get props => [currentStep, record, startTime, stepCount];

  DebriefInProgress copyWith({
    DebriefStep? currentStep,
    DebriefRecord? record,
    DateTime? startTime,
    int? stepCount,
  }) {
    return DebriefInProgress(
      currentStep: currentStep ?? this.currentStep,
      record: record ?? this.record,
      startTime: startTime ?? this.startTime,
      stepCount: stepCount ?? this.stepCount,
    );
  }
}

class DebriefCompleted extends DebriefState {
  final DebriefRecord record;
  final Duration totalDuration;
  final int stepsCompleted;

  const DebriefCompleted({
    required this.record,
    required this.totalDuration,
    required this.stepsCompleted,
  });

  @override
  List<Object?> get props => [record, totalDuration, stepsCompleted];
}

class DebriefError extends DebriefState {
  final String message;

  const DebriefError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class DebriefCubit extends Cubit<DebriefState> {
  static const _uuid = Uuid();

  DebriefCubit() : super(const DebriefInitial());

  void startDebrief() {
    final now = DateTime.now();
    final initialRecord = DebriefRecord(
      id: _uuid.v4(),
      createdAt: now,
      snapshot: '',
      wentWell: [],
      wasHard: [],
      bodyScore: 3,
      breathCompleted: false,
      essence: '',
      nextStep: '',
    );

    emit(DebriefInProgress(
      currentStep: DebriefStep.snapshot,
      record: initialRecord,
      startTime: now,
      stepCount: 0,
    ));
  }

  void updateSnapshot(String snapshot) {
    final currentState = state;
    if (currentState is DebriefInProgress) {
      final updatedRecord = currentState.record.copyWith(snapshot: snapshot);
      emit(currentState.copyWith(record: updatedRecord));
    }
  }

  void updateWentWell(List<String> wentWell) {
    final currentState = state;
    if (currentState is DebriefInProgress) {
      final updatedRecord = currentState.record.copyWith(wentWell: wentWell);
      emit(currentState.copyWith(record: updatedRecord));
    }
  }

  void updateWasHard(List<String> wasHard) {
    final currentState = state;
    if (currentState is DebriefInProgress) {
      final updatedRecord = currentState.record.copyWith(wasHard: wasHard);
      emit(currentState.copyWith(record: updatedRecord));
    }
  }

  void updateBodyScore(int score) {
    final currentState = state;
    if (currentState is DebriefInProgress) {
      final updatedRecord = currentState.record.copyWith(bodyScore: score);
      emit(currentState.copyWith(record: updatedRecord));
    }
  }

  void markBreathCompleted() {
    final currentState = state;
    if (currentState is DebriefInProgress) {
      final updatedRecord = currentState.record.copyWith(breathCompleted: true);
      emit(currentState.copyWith(record: updatedRecord));
    }
  }

  void updateEssence(String essence) {
    final currentState = state;
    if (currentState is DebriefInProgress) {
      final updatedRecord = currentState.record.copyWith(essence: essence);
      emit(currentState.copyWith(record: updatedRecord));
    }
  }

  void updateNextStep(String nextStep) {
    final currentState = state;
    if (currentState is DebriefInProgress) {
      final updatedRecord = currentState.record.copyWith(nextStep: nextStep);
      emit(currentState.copyWith(record: updatedRecord));
    }
  }

  void goToNextStep() {
    final currentState = state;
    if (currentState is DebriefInProgress) {
      final currentStepIndex = DebriefStep.values.indexOf(currentState.currentStep);
      
      if (currentStepIndex < DebriefStep.values.length - 1) {
        final nextStep = DebriefStep.values[currentStepIndex + 1];
        emit(currentState.copyWith(
          currentStep: nextStep,
          stepCount: currentState.stepCount + 1,
        ));
      }
    }
  }

  void goToPreviousStep() {
    final currentState = state;
    if (currentState is DebriefInProgress) {
      final currentStepIndex = DebriefStep.values.indexOf(currentState.currentStep);
      
      if (currentStepIndex > 0) {
        final previousStep = DebriefStep.values[currentStepIndex - 1];
        emit(currentState.copyWith(
          currentStep: previousStep,
          stepCount: currentState.stepCount > 0 ? currentState.stepCount - 1 : 0,
        ));
      }
    }
  }

  void skipStep() {
    goToNextStep();
  }

  void completeDebrief() {
    final currentState = state;
    if (currentState is DebriefInProgress) {
      final duration = DateTime.now().difference(currentState.startTime);
      
      emit(DebriefCompleted(
        record: currentState.record,
        totalDuration: duration,
        stepsCompleted: currentState.stepCount + 1,
      ));
    }
  }

  void reset() {
    emit(const DebriefInitial());
  }

  // Helper methods
  bool get canGoBack {
    final currentState = state;
    if (currentState is DebriefInProgress) {
      return DebriefStep.values.indexOf(currentState.currentStep) > 0;
    }
    return false;
  }

  bool get canGoNext {
    final currentState = state;
    if (currentState is DebriefInProgress) {
      return DebriefStep.values.indexOf(currentState.currentStep) < DebriefStep.values.length - 1;
    }
    return false;
  }

  bool get isLastStep {
    final currentState = state;
    if (currentState is DebriefInProgress) {
      return currentState.currentStep == DebriefStep.values.last;
    }
    return false;
  }

  Duration get estimatedRemainingTime {
    final currentState = state;
    if (currentState is DebriefInProgress) {
      final currentStepIndex = DebriefStep.values.indexOf(currentState.currentStep);
      final remainingSteps = DebriefStep.values.skip(currentStepIndex + 1);
      final totalSeconds = remainingSteps.fold(0, (sum, step) => sum + step.estimatedSeconds);
      return Duration(seconds: totalSeconds);
    }
    return Duration.zero;
  }
}
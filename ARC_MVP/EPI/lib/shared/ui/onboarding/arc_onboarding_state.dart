// lib/shared/ui/onboarding/arc_onboarding_state.dart
// State for ARC onboarding sequence

import 'package:equatable/equatable.dart';
import 'package:my_app/models/phase_models.dart';

enum OnboardingScreen {
  logoReveal,
  lumaraIntro,
  arcIntro,
  narrativeIntelligence,
  sentinelIntro,
  phaseExplanation,
  phaseQuiz,
  phaseAnalysis,
  phaseReveal,
  complete,
}

class PhaseAnalysis {
  final PhaseLabel phase;
  final ConfidenceLevel confidence;
  final String recognitionStatement;
  final String trackingQuestion;
  final String reasoning; // Internal, not shown to user

  const PhaseAnalysis({
    required this.phase,
    required this.confidence,
    required this.recognitionStatement,
    required this.trackingQuestion,
    required this.reasoning,
  });
}

enum ConfidenceLevel {
  high,
  medium,
  low,
}

class ArcOnboardingState extends Equatable {
  final OnboardingScreen currentScreen;
  final Map<int, String> quizResponses; // question index -> response
  final PhaseAnalysis? phaseAnalysis;
  final bool isLoading;

  const ArcOnboardingState({
    this.currentScreen = OnboardingScreen.lumaraIntro, // Start with LUMARA intro, skip logo reveal
    this.quizResponses = const {},
    this.phaseAnalysis,
    this.isLoading = false,
  });

  ArcOnboardingState copyWith({
    OnboardingScreen? currentScreen,
    Map<int, String>? quizResponses,
    PhaseAnalysis? phaseAnalysis,
    bool? isLoading,
  }) {
    return ArcOnboardingState(
      currentScreen: currentScreen ?? this.currentScreen,
      quizResponses: quizResponses ?? this.quizResponses,
      phaseAnalysis: phaseAnalysis ?? this.phaseAnalysis,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        currentScreen,
        quizResponses,
        phaseAnalysis,
        isLoading,
      ];
}

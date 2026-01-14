// lib/shared/ui/onboarding/arc_onboarding_cubit.dart
// Cubit for managing ARC onboarding sequence state

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/ui/onboarding/arc_onboarding_state.dart';
import 'package:my_app/shared/ui/onboarding/onboarding_phase_detector.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';

class ArcOnboardingCubit extends Cubit<ArcOnboardingState> {
  ArcOnboardingCubit() : super(const ArcOnboardingState(
    currentScreen: OnboardingScreen.lumaraIntro, // Start with LUMARA intro, skip logo reveal
  ));

  final Logger _logger = Logger();
  final OnboardingPhaseDetector _phaseDetector = OnboardingPhaseDetector();

  void nextScreen() {
    final current = state.currentScreen;
    OnboardingScreen? next;

    switch (current) {
      case OnboardingScreen.logoReveal:
        // Skip logo reveal, go to LUMARA intro
        next = OnboardingScreen.lumaraIntro;
        break;
      case OnboardingScreen.lumaraIntro:
        next = OnboardingScreen.arcIntro;
        break;
      case OnboardingScreen.arcIntro:
        next = OnboardingScreen.narrativeIntelligence;
        break;
      case OnboardingScreen.narrativeIntelligence:
        next = OnboardingScreen.phaseQuiz;
        break;
      case OnboardingScreen.phaseQuiz:
      case OnboardingScreen.phaseAnalysis:
      case OnboardingScreen.phaseReveal:
      case OnboardingScreen.complete:
        return; // Don't advance from these screens
    }

    emit(state.copyWith(currentScreen: next));
  }

  void startPhaseQuiz() {
    emit(state.copyWith(currentScreen: OnboardingScreen.phaseQuiz));
  }

  void submitQuizResponse(int questionIndex, String response) {
    final updatedResponses = Map<int, String>.from(state.quizResponses);
    updatedResponses[questionIndex] = response;
    emit(state.copyWith(quizResponses: updatedResponses));
  }

  Future<void> completeQuiz() async {
    emit(state.copyWith(
      currentScreen: OnboardingScreen.phaseAnalysis,
      isLoading: true,
    ));

    try {
      // Analyze responses
      final analysis = await _phaseDetector.analyzeOnboardingResponses(
        responses: state.quizResponses,
        timestamp: DateTime.now(),
      );

      // Save responses as journal entries (metadata flagged)
      await _saveQuizResponsesAsEntries();

      // Set user phase
      await _setUserPhase(analysis.phase);

      emit(state.copyWith(
        phaseAnalysis: analysis,
        currentScreen: OnboardingScreen.phaseReveal,
        isLoading: false,
      ));
    } catch (e, stackTrace) {
      _logger.e('Error completing quiz: $e\nStackTrace: $stackTrace');
      // Default to Discovery phase on error
      final defaultAnalysis = PhaseAnalysis(
        phase: PhaseLabel.discovery,
        confidence: ConfidenceLevel.low,
        recognitionStatement: "Let's begin your journey.",
        trackingQuestion: "What are you discovering?",
        reasoning: "Error during analysis, defaulting to Discovery",
      );
      emit(state.copyWith(
        phaseAnalysis: defaultAnalysis,
        currentScreen: OnboardingScreen.phaseReveal,
        isLoading: false,
      ));
    }
  }

  Future<void> _saveQuizResponsesAsEntries() async {
    try {
      final journalBox = Hive.box<JournalEntry>('journal_entries');
      final now = DateTime.now();

      for (final entry in state.quizResponses.entries) {
        final questionNumber = entry.key + 1;
        final response = entry.value;

        final journalEntry = JournalEntry(
          id: 'onboarding_q${questionNumber}_${now.millisecondsSinceEpoch}',
          title: 'Onboarding Response - Question $questionNumber',
          content: response,
          createdAt: now,
          updatedAt: now,
          tags: ['onboarding', 'phase_detection'],
          mood: 'Reflective',
          audioUri: null,
          sageAnnotation: null,
          keywords: [],
        );

        await journalBox.put(journalEntry.id, journalEntry);
      }

      _logger.i('Saved ${state.quizResponses.length} quiz responses as journal entries');
    } catch (e) {
      _logger.e('Error saving quiz responses: $e');
    }
  }

  Future<void> _setUserPhase(PhaseLabel phase) async {
    try {
      // Convert PhaseLabel to string format expected by UserPhaseService
      final phaseString = phase.name;
      await UserPhaseService.forceUpdatePhase(phaseString);
      _logger.i('Set user phase to: $phaseString');
    } catch (e) {
      _logger.e('Error setting user phase: $e');
    }
  }

  void completeOnboarding() {
    emit(state.copyWith(currentScreen: OnboardingScreen.complete));
  }

  /// Skip directly to main page (for users with saved content)
  void skipToMainPage() {
    _logger.d('Skipping to main page');
    completeOnboarding();
  }

  /// Skip quiz for returning users or users with existing phase data
  Future<void> skipQuiz() async {
    _logger.d('Skipping quiz for returning user');
    
    emit(state.copyWith(
      currentScreen: OnboardingScreen.phaseAnalysis,
      isLoading: true,
    ));

    try {
      // Get existing phase or default to Discovery
      String phaseString = 'Discovery';
      try {
        phaseString = await UserPhaseService.getCurrentPhase();
      } catch (e) {
        _logger.w('Could not get existing phase, defaulting to Discovery: $e');
      }

      // Convert to PhaseLabel
      PhaseLabel phase = PhaseLabel.discovery;
      try {
        phase = PhaseLabel.values.firstWhere(
          (p) => p.name == phaseString.toLowerCase(),
          orElse: () => PhaseLabel.discovery,
        );
      } catch (e) {
        _logger.w('Could not parse phase, defaulting to Discovery: $e');
      }

      // Create default analysis for skipped quiz
      final defaultAnalysis = PhaseAnalysis(
        phase: phase,
        confidence: ConfidenceLevel.low,
        recognitionStatement: "Welcome back. Your phase constellation will fill with words and patterns as you journal.",
        trackingQuestion: "What are you exploring?",
        reasoning: "Quiz skipped - using existing phase: $phaseString",
      );

      // Set user phase if not already set
      await _setUserPhase(phase);

      emit(state.copyWith(
        phaseAnalysis: defaultAnalysis,
        currentScreen: OnboardingScreen.phaseReveal,
        isLoading: false,
      ));
    } catch (e, stackTrace) {
      _logger.e('Error skipping quiz: $e\nStackTrace: $stackTrace');
      // Default to Discovery phase on error
      final defaultAnalysis = PhaseAnalysis(
        phase: PhaseLabel.discovery,
        confidence: ConfidenceLevel.low,
        recognitionStatement: "Welcome back. Let's begin your journey.",
        trackingQuestion: "What are you discovering?",
        reasoning: "Error during skip, defaulting to Discovery",
      );
      emit(state.copyWith(
        phaseAnalysis: defaultAnalysis,
        currentScreen: OnboardingScreen.phaseReveal,
        isLoading: false,
      ));
    }
  }
}

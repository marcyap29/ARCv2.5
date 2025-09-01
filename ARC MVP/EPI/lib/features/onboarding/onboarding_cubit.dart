import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/home/home_view.dart';
import 'package:my_app/features/onboarding/onboarding_state.dart';
import 'package:hive/hive.dart';
import 'package:my_app/models/user_profile_model.dart';
import 'package:logger/logger.dart';
import 'package:my_app/services/starter_arcform_service.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit() : super(const OnboardingState());

  final PageController pageController = PageController();
  final Logger _logger = Logger();

  void updatePage(int page) {
    _logger.d('Updating onboarding page to: $page');
    emit(state.copyWith(currentPage: page));
  }

  void selectPurpose(String purpose) {
    _logger.d('Selecting purpose: $purpose');
    emit(state.copyWith(purpose: purpose));
    _nextPage();
  }

  void selectFeeling(String feeling) {
    _logger.d('Selecting feeling: $feeling');
    emit(state.copyWith(feeling: feeling));
    _nextPage();
  }

  void selectCurrentSeason(String season) {
    _logger.d('Selecting current season: $season');
    emit(state.copyWith(currentSeason: season));
    _nextPage();
  }

  void setCentralWord(String word) {
    _logger.d('Setting central word: $word');
    emit(state.copyWith(centralWord: word));
    _nextPage();
  }

  void selectRhythm(String rhythm) {
    _logger.d('Selecting rhythm: $rhythm');
    emit(state.copyWith(rhythm: rhythm));
    _completeOnboarding();
  }

  void _nextPage() {
    if (state.currentPage < 4) {
      pageController.animateToPage(
        state.currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeOnboarding() async {
    _logger.d('Completing onboarding process');
    try {
      final userBox = await Hive.openBox<UserProfile>('user_profile');
      UserProfile? userProfile = userBox.get('profile');

      userProfile ??= UserProfile(
          id: 'default',
          name: 'User',
          email: '',
          createdAt: DateTime.now(),
          preferences: const {},
        );

      final updatedProfile = userProfile.copyWith(
        onboardingPurpose: state.purpose,
        onboardingFeeling: state.feeling,
        onboardingRhythm: state.rhythm,
        onboardingCurrentSeason: state.currentSeason,
        onboardingCentralWord: state.centralWord,
        onboardingCompleted: true,
      );

      await userBox.put('profile', updatedProfile);
      emit(state.copyWith(isCompleted: true));

      // Generate starter Arcform from onboarding data (non-blocking)
      try {
        final starterArcform = StarterArcformService.createFromOnboarding(updatedProfile);
        // Persist starter arcform as a journal-like entry for continuity
        final journalBox = await Hive.openBox('journal_entries');
        final journalEntry = {
          'id': starterArcform.id,
          'title': starterArcform.title,
          'content': starterArcform.content,
          'createdAt': starterArcform.createdAt.toIso8601String(),
          'updatedAt': starterArcform.createdAt.toIso8601String(),
          'tags': starterArcform.keywords,
          'mood': updatedProfile.onboardingFeeling ?? 'Hopeful',
          'audioUri': null,
          'sageAnnotation': null,
          'keywords': starterArcform.keywords,
        };
        await journalBox.put(journalEntry['id'], journalEntry);
        _logger.i('Saved starter Arcform as journal entry: ${journalEntry['id']}');
      } catch (e, stackTrace) {
        _logger.e('Error creating starter Arcform: $e', stackTrace);
      }

      // Navigation will be handled by BlocListener in the UI
      _logger.i('Onboarding completed successfully');
    } catch (e, stackTrace) {
      _logger.e('Error completing onboarding: $e', stackTrace);
      // We'll let the error bubble up to Sentry for tracking
      rethrow;
    }
  }

  void skipOnboarding() async {
    _logger.d('Skipping onboarding process');
    try {
      final userBox = await Hive.openBox<UserProfile>('user_profile');
      UserProfile? userProfile = userBox.get('profile');

      userProfile ??= UserProfile(
          id: 'default',
          name: 'User',
          email: '',
          createdAt: DateTime.now(),
          preferences: const {},
        );

      final updatedProfile = userProfile.copyWith(
        onboardingCompleted: true,
      );

      await userBox.put('profile', updatedProfile);
      emit(state.copyWith(isCompleted: true));

      // Navigation will be handled by BlocListener in the UI
      _logger.i('Onboarding skipped');
    } catch (e, stackTrace) {
      _logger.e('Error skipping onboarding: $e', stackTrace);
      // We'll let the error bubble up to Sentry for tracking
      rethrow;
    }
  }

  void _navigateToHome() {
    // Navigation is handled by BlocListener in the UI
    // This method is kept for potential future use but not called
  }

  @override
  Future<void> close() {
    pageController.dispose();
    return super.close();
  }
}

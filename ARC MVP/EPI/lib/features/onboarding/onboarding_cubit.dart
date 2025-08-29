import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/home/home_view.dart';
import 'package:my_app/features/onboarding/onboarding_state.dart';
import 'package:hive/hive.dart';
import 'package:my_app/models/user_profile_model.dart';
import 'package:logger/logger.dart';

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

  void selectRhythm(String rhythm) {
    _logger.d('Selecting rhythm: $rhythm');
    emit(state.copyWith(rhythm: rhythm));
    _completeOnboarding();
  }

  void _nextPage() {
    if (state.currentPage < 2) {
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

      if (userProfile == null) {
        userProfile = UserProfile(
          id: 'default',
          name: 'User',
          email: '',
          createdAt: DateTime.now(),
          preferences: {},
        );
      }

      final updatedProfile = userProfile.copyWith(
        onboardingPurpose: state.purpose,
        onboardingFeeling: state.feeling,
        onboardingRhythm: state.rhythm,
        onboardingCompleted: true,
      );

      await userBox.put('profile', updatedProfile);
      emit(state.copyWith(isCompleted: true));

      // Navigate to HomeView after a short delay to ensure state is updated
      await Future.delayed(const Duration(milliseconds: 100));
      _navigateToHome();

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

      if (userProfile == null) {
        userProfile = UserProfile(
          id: 'default',
          name: 'User',
          email: '',
          createdAt: DateTime.now(),
          preferences: {},
        );
      }

      final updatedProfile = userProfile.copyWith(
        onboardingCompleted: true,
      );

      await userBox.put('profile', updatedProfile);
      emit(state.copyWith(isCompleted: true));

      // Navigate to HomeView after a short delay to ensure state is updated
      await Future.delayed(const Duration(milliseconds: 100));
      _navigateToHome();

      _logger.i('Onboarding skipped');
    } catch (e, stackTrace) {
      _logger.e('Error skipping onboarding: $e', stackTrace);
      // We'll let the error bubble up to Sentry for tracking
      rethrow;
    }
  }

  void _navigateToHome() {
    // Use the root navigator to ensure we navigate to the home screen properly
    Navigator.of(pageController.context, rootNavigator: true)
        .pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeView()),
      (route) => false,
    );
  }

  @override
  Future<void> close() {
    pageController.dispose();
    return super.close();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/onboarding/onboarding_cubit.dart';
import 'package:my_app/features/onboarding/onboarding_state.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OnboardingCubit(),
      child: const OnboardingViewContent(),
    );
  }
}

class OnboardingViewContent extends StatelessWidget {
  const OnboardingViewContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: kcPrimaryGradient,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Skip button
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextButton(
                        onPressed: () {
                          context.read<OnboardingCubit>().skipOnboarding();
                        },
                        child: Text(
                          'Skip for now',
                          style: buttonStyle(context).copyWith(
                            color: kcSecondaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Progress dots
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          width: 8.0,
                          height: 8.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == state.currentPage
                                ? kcPrimaryColor
                                : kcSecondaryColor.withOpacity(0.5),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Content based on current page
                  Expanded(
                    child: PageView(
                      controller:
                          context.read<OnboardingCubit>().pageController,
                      onPageChanged: (index) {
                        context.read<OnboardingCubit>().updatePage(index);
                      },
                      physics: const NeverScrollableScrollPhysics(),
                      children: const [
                        _OnboardingPage1(),
                        _OnboardingPage2(),
                        _OnboardingPage3(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingPage1 extends StatelessWidget {
  const _OnboardingPage1();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'What brings you here?',
            style: heading1Style(context).copyWith(
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Select the option that resonates most with your intentions today.',
            style: bodyStyle(context).copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          const _OptionGrid(
            options: [
              'Self-discovery',
              'Coaching',
              'Journaling',
              'Growth',
              'Recovery',
            ],
            type: OnboardingOptionType.purpose,
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage2 extends StatelessWidget {
  const _OnboardingPage2();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'How do you want to feel while journaling?',
            style: heading1Style(context).copyWith(
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Choose the emotional quality you\'d like to cultivate in this space.',
            style: bodyStyle(context).copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          const _OptionGrid(
            options: [
              'Calm',
              'Energized',
              'Reflective',
              'Focused',
            ],
            type: OnboardingOptionType.feeling,
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage3 extends StatelessWidget {
  const _OnboardingPage3();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'What rhythm fits you best?',
            style: heading1Style(context).copyWith(
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Pick a cadence that feels natural and sustainable for you.',
            style: bodyStyle(context).copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          const _OptionGrid(
            options: [
              'Daily',
              'Weekly',
              'Free-flow',
            ],
            type: OnboardingOptionType.rhythm,
          ),
        ],
      ),
    );
  }
}

enum OnboardingOptionType { purpose, feeling, rhythm }

class _OptionGrid extends StatelessWidget {
  final List<String> options;
  final OnboardingOptionType type;

  const _OptionGrid({
    required this.options,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        String? selectedOption;
        switch (type) {
          case OnboardingOptionType.purpose:
            selectedOption = state.purpose;
            break;
          case OnboardingOptionType.feeling:
            selectedOption = state.feeling;
            break;
          case OnboardingOptionType.rhythm:
            selectedOption = state.rhythm;
            break;
        }

        return Column(
          children: options.map((option) {
            final isSelected = selectedOption == option;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ElevatedButton(
                onPressed: () {
                  switch (type) {
                    case OnboardingOptionType.purpose:
                      context.read<OnboardingCubit>().selectPurpose(option);
                      break;
                    case OnboardingOptionType.feeling:
                      context.read<OnboardingCubit>().selectFeeling(option);
                      break;
                    case OnboardingOptionType.rhythm:
                      context.read<OnboardingCubit>().selectRhythm(option);
                      break;
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                  foregroundColor: isSelected
                      ? kcPrimaryGradient.colors.first
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: isSelected ? 4 : 0,
                  side: BorderSide(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  option,
                  style: buttonStyle(context).copyWith(
                    color: isSelected
                        ? kcPrimaryGradient.colors.first
                        : Colors.white,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

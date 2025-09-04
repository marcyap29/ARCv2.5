import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/onboarding/onboarding_cubit.dart';
import 'package:my_app/features/onboarding/onboarding_state.dart';
import 'package:my_app/features/onboarding/widgets/central_word_input.dart';
import 'package:my_app/features/onboarding/widgets/atlas_phase_grid.dart';
import 'package:my_app/features/home/home_view.dart';
import 'package:my_app/features/onboarding/phase_celebration_view.dart';
import 'package:my_app/services/user_phase_service.dart';
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
    return BlocListener<OnboardingCubit, OnboardingState>(
      listener: (context, state) async {
        if (state.isCompleted) {
          final currentPhase = await UserPhaseService.getCurrentPhase();
          final phaseDescription = UserPhaseService.getPhaseDescription(currentPhase);
          
          String phaseEmoji;
          switch (currentPhase.toLowerCase()) {
            case 'discovery':
              phaseEmoji = '🔍';
              break;
            case 'expansion':
              phaseEmoji = '🌸';
              break;
            case 'transition':
              phaseEmoji = '🌊';
              break;
            case 'consolidation':
              phaseEmoji = '🧘';
              break;
            case 'recovery':
              phaseEmoji = '🌱';
              break;
            case 'breakthrough':
              phaseEmoji = '⚡';
              break;
            default:
              phaseEmoji = '🔍';
          }
          
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => PhaseCelebrationView(
                discoveredPhase: currentPhase,
                phaseDescription: phaseDescription,
                phaseEmoji: phaseEmoji,
              ),
            ),
            (route) => false,
          );
        }
      },
      child: BlocBuilder<OnboardingCubit, OnboardingState>(
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
                      children: List.generate(5, (index) {
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
                        _OnboardingPage1(), // Purpose
                        _OnboardingPage2(), // Mood/Feeling
                        _OnboardingPage4(), // Core Word (moved up)
                        _OnboardingPage5(), // Rhythm
                        _OnboardingPage3(), // Phase Selection (moved to end)
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        },
      ),
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
            'How are you feeling right now?',
            style: heading1Style(context).copyWith(
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Choose the emotional quality that resonates with your current state.',
            style: bodyStyle(context).copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          const _MoodChipsGrid(
            options: [
              'Calm',
              'Hopeful',
              'Stressed',
              'Tired',
              'Grateful',
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
            'What word feels most central to your story right now?',
            style: heading1Style(context).copyWith(
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'If your story could be held in a single word, what would it be? Write the word that matters most.',
            style: bodyStyle(context).copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          const CentralWordInput(),
        ],
      ),
    );
  }
}

class _OnboardingPage4 extends StatelessWidget {
  const _OnboardingPage4();

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

class _OnboardingPage5 extends StatelessWidget {
  const _OnboardingPage5();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            'Which season best describes where you are in life right now?',
            style: heading1Style(context).copyWith(
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Every journey has a season. Choose the one that feels closest to your life right now.',
            style: bodyStyle(context).copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          const ATLASPhaseGrid(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

enum OnboardingOptionType { purpose, feeling, rhythm, currentSeason }

class _MoodChipsGrid extends StatelessWidget {
  final List<String> options;
  final OnboardingOptionType type;

  const _MoodChipsGrid({
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
          case OnboardingOptionType.currentSeason:
            selectedOption = state.currentSeason;
            break;
        }

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: options.map((option) {
            final isSelected = selectedOption == option;
            return GestureDetector(
              onTap: () {
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
                  case OnboardingOptionType.currentSeason:
                    context.read<OnboardingCubit>().selectCurrentSeason(option);
                    break;
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.white 
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected 
                        ? Colors.transparent 
                        : Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: kcPrimaryColor.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ] : null,
                ),
                child: Text(
                  option,
                  style: buttonStyle(context).copyWith(
                    color: isSelected
                        ? kcPrimaryGradient.colors.first
                        : Colors.white,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
          case OnboardingOptionType.currentSeason:
            selectedOption = state.currentSeason;
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
                    case OnboardingOptionType.currentSeason:
                      context.read<OnboardingCubit>().selectCurrentSeason(option);
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

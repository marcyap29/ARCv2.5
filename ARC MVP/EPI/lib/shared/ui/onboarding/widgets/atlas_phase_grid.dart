import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/ui/onboarding/onboarding_cubit.dart';
import 'package:my_app/shared/ui/onboarding/onboarding_state.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class ATLASPhaseGrid extends StatelessWidget {
  const ATLASPhaseGrid({super.key});

  // ATLAS Phase mapping with emojis and descriptions
  static const Map<String, Map<String, String>> atlasPhases = {
    'Discovery': {
      'emoji': '🌱',
      'description': 'I\'m exploring something new',
      'geometry': 'spiral',
    },
    'Expansion': {
      'emoji': '🌸',
      'description': 'I\'m growing and reaching outward',
      'geometry': 'flower',
    },
    'Transition': {
      'emoji': '🌿',
      'description': 'I\'m in between, shifting paths',
      'geometry': 'branch',
    },
    'Consolidation': {
      'emoji': '🧵',
      'description': 'I\'m weaving things together, grounding',
      'geometry': 'weave',
    },
    'Recovery': {
      'emoji': '✨',
      'description': 'I\'m healing or resting',
      'geometry': 'glowCore',
    },
    'Breakthrough': {
      'emoji': '💥',
      'description': 'I\'m seeing sudden change or insight',
      'geometry': 'fractal',
    },
  };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        return Column(
          children: atlasPhases.entries.map((phase) {
              final phaseName = phase.key;
              final phaseData = phase.value;
              final isSelected = state.currentSeason == phaseName;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: GestureDetector(
                  onTap: () {
                    context.read<OnboardingCubit>().selectCurrentSeason(phaseName);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Colors.white 
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
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
                    child: Row(
                      children: [
                        Text(
                          phaseData['emoji']!,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                phaseName,
                                style: heading3Style(context).copyWith(
                                  color: isSelected
                                      ? kcPrimaryGradient.colors.first
                                      : Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                phaseData['description']!,
                                style: captionStyle(context).copyWith(
                                  color: isSelected
                                      ? kcPrimaryGradient.colors.first.withOpacity(0.8)
                                      : Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
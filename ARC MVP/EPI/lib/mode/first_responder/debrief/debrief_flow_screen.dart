import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'debrief_cubit.dart';
import 'debrief_models.dart';
import 'widgets/debrief_timer.dart';
import 'widgets/debrief_breath_widget.dart';

class DebriefFlowScreen extends StatefulWidget {
  final VoidCallback? onCompleted;
  
  const DebriefFlowScreen({
    super.key,
    this.onCompleted,
  });

  @override
  State<DebriefFlowScreen> createState() => _DebriefFlowScreenState();
}

class _DebriefFlowScreenState extends State<DebriefFlowScreen> {
  final TextEditingController _snapshotController = TextEditingController();
  final TextEditingController _essenceController = TextEditingController();
  final TextEditingController _nextStepController = TextEditingController();
  
  final Set<String> _selectedWentWell = <String>{};
  final Set<String> _selectedWasHard = <String>{};
  final Set<String> _selectedBodySymptoms = <String>{};
  
  int _bodyScore = 3;

  @override
  void dispose() {
    _snapshotController.dispose();
    _essenceController.dispose();
    _nextStepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DebriefCubit()..startDebrief(),
      child: BlocConsumer<DebriefCubit, DebriefState>(
        listener: (context, state) {
          if (state is DebriefCompleted) {
            widget.onCompleted?.call();
          }
        },
        builder: (context, state) {
          if (state is DebriefInProgress) {
            return _buildFlowScreen(context, state);
          } else if (state is DebriefCompleted) {
            return _buildCompletedScreen(context, state);
          } else {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
        },
      ),
    );
  }

  Widget _buildFlowScreen(BuildContext context, DebriefInProgress state) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: kcSecondaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: DebriefTimer(
          startTime: state.startTime,
          currentStep: state.currentStep,
          estimatedRemaining: context.read<DebriefCubit>().estimatedRemainingTime,
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              context.read<DebriefCubit>().skipStep();
            },
            child: Text(
              'Skip',
              style: captionStyle(context).copyWith(
                color: kcSecondaryColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(state.currentStep),
            
            // Step content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildStepContent(context, state),
              ),
            ),
            
            // Navigation buttons
            _buildNavigationButtons(context, state),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(DebriefStep currentStep) {
    final steps = DebriefStep.values;
    final currentIndex = steps.indexOf(currentStep);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final isActive = index == currentIndex;
          final isCompleted = index < currentIndex;
          
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < steps.length - 1 ? 8 : 0),
              decoration: BoxDecoration(
                color: isActive || isCompleted 
                    ? kcPrimaryColor 
                    : kcSurfaceAltColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStepContent(BuildContext context, DebriefInProgress state) {
    switch (state.currentStep) {
      case DebriefStep.snapshot:
        return _buildSnapshotStep(context, state);
      case DebriefStep.reflection:
        return _buildReflectionStep(context, state);
      case DebriefStep.bodyCheck:
        return _buildBodyCheckStep(context, state);
      case DebriefStep.breathing:
        return _buildBreathingStep(context, state);
      case DebriefStep.essence:
        return _buildEssenceStep(context, state);
    }
  }

  Widget _buildSnapshotStep(BuildContext context, DebriefInProgress state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.currentStep.title,
          style: heading1Style(context).copyWith(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          state.currentStep.prompt,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryColor,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          state.currentStep.microcopy,
          style: captionStyle(context).copyWith(
            color: kcSecondaryColor.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _snapshotController,
          maxLines: 4,
          maxLength: 300,
          style: bodyStyle(context).copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Brief factual overview...',
            hintStyle: bodyStyle(context).copyWith(
              color: kcSecondaryColor.withOpacity(0.5),
            ),
            filled: true,
            fillColor: kcSurfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) {
            context.read<DebriefCubit>().updateSnapshot(value);
          },
        ),
      ],
    );
  }

  Widget _buildReflectionStep(BuildContext context, DebriefInProgress state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.currentStep.title,
          style: heading1Style(context).copyWith(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          state.currentStep.microcopy,
          style: captionStyle(context).copyWith(
            color: kcSecondaryColor.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 24),
        
        // Went well section
        Text(
          'What went well',
          style: heading3Style(context).copyWith(
            color: const Color(0xFF6BE3A0),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DebriefChips.wentWell.map((chip) {
            final isSelected = _selectedWentWell.contains(chip);
            return ChoiceChip(
              label: Text(chip),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedWentWell.add(chip);
                  } else {
                    _selectedWentWell.remove(chip);
                  }
                });
                context.read<DebriefCubit>().updateWentWell(_selectedWentWell.toList());
              },
              selectedColor: const Color(0xFF6BE3A0).withOpacity(0.3),
              backgroundColor: kcSurfaceAltColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : kcSecondaryColor,
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 24),
        
        // Was hard section
        Text(
          'What was challenging',
          style: heading3Style(context).copyWith(
            color: const Color(0xFFFF6B6B),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DebriefChips.wasHard.map((chip) {
            final isSelected = _selectedWasHard.contains(chip);
            return ChoiceChip(
              label: Text(chip),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedWasHard.add(chip);
                  } else {
                    _selectedWasHard.remove(chip);
                  }
                });
                context.read<DebriefCubit>().updateWasHard(_selectedWasHard.toList());
              },
              selectedColor: const Color(0xFFFF6B6B).withOpacity(0.3),
              backgroundColor: kcSurfaceAltColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : kcSecondaryColor,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBodyCheckStep(BuildContext context, DebriefInProgress state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.currentStep.title,
          style: heading1Style(context).copyWith(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          state.currentStep.prompt,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryColor,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          state.currentStep.microcopy,
          style: captionStyle(context).copyWith(
            color: kcSecondaryColor.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 32),
        
        // Body score slider
        Text(
          'Overall feeling: ${_bodyScore}/5',
          style: heading3Style(context).copyWith(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: kcPrimaryColor,
            inactiveTrackColor: kcSurfaceAltColor,
            thumbColor: kcPrimaryColor,
            overlayColor: kcPrimaryColor.withOpacity(0.2),
          ),
          child: Slider(
            value: _bodyScore.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: _bodyScore.toString(),
            onChanged: (value) {
              setState(() {
                _bodyScore = value.round();
              });
              context.read<DebriefCubit>().updateBodyScore(_bodyScore);
            },
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Body symptoms
        Text(
          'Notice any physical sensations?',
          style: heading3Style(context).copyWith(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DebriefChips.bodySymptoms.map((symptom) {
            final isSelected = _selectedBodySymptoms.contains(symptom);
            return ChoiceChip(
              label: Text(symptom),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedBodySymptoms.add(symptom);
                  } else {
                    _selectedBodySymptoms.remove(symptom);
                  }
                });
              },
              selectedColor: kcPrimaryColor.withOpacity(0.3),
              backgroundColor: kcSurfaceAltColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : kcSecondaryColor,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBreathingStep(BuildContext context, DebriefInProgress state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.currentStep.title,
          style: heading1Style(context).copyWith(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          state.currentStep.microcopy,
          style: captionStyle(context).copyWith(
            color: kcSecondaryColor.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        
        DebriefBreathWidget(
          onCompleted: () {
            context.read<DebriefCubit>().markBreathCompleted();
          },
          onSkipped: () {
            context.read<DebriefCubit>().skipStep();
          },
        ),
      ],
    );
  }

  Widget _buildEssenceStep(BuildContext context, DebriefInProgress state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.currentStep.title,
          style: heading1Style(context).copyWith(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          state.currentStep.microcopy,
          style: captionStyle(context).copyWith(
            color: kcSecondaryColor.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 24),
        
        // Essence field
        Text(
          'One thing to carry forward',
          style: heading3Style(context).copyWith(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _essenceController,
          maxLines: 2,
          style: bodyStyle(context).copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'What will you remember from this?',
            hintStyle: bodyStyle(context).copyWith(
              color: kcSecondaryColor.withOpacity(0.5),
            ),
            filled: true,
            fillColor: kcSurfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) {
            context.read<DebriefCubit>().updateEssence(value);
          },
        ),
        
        const SizedBox(height: 24),
        
        // Next step field
        Text(
          'Smallest next step (optional)',
          style: heading3Style(context).copyWith(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nextStepController,
          maxLines: 2,
          style: bodyStyle(context).copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Rest, hydrate, check in with partner...',
            hintStyle: bodyStyle(context).copyWith(
              color: kcSecondaryColor.withOpacity(0.5),
            ),
            filled: true,
            fillColor: kcSurfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) {
            context.read<DebriefCubit>().updateNextStep(value);
          },
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(BuildContext context, DebriefInProgress state) {
    final cubit = context.read<DebriefCubit>();
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (cubit.canGoBack)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  cubit.goToPreviousStep();
                },
                child: Text(
                  'Back',
                  style: buttonStyle(context).copyWith(
                    color: kcSecondaryColor,
                  ),
                ),
              ),
            ),
          
          if (cubit.canGoBack) const SizedBox(width: 12),
          
          Expanded(
            flex: cubit.canGoBack ? 1 : 2,
            child: FilledButton(
              onPressed: () {
                if (cubit.isLastStep) {
                  cubit.completeDebrief();
                } else {
                  cubit.goToNextStep();
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: kcPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                cubit.isLastStep ? 'Save Debrief' : 'Next',
                style: buttonStyle(context).copyWith(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedScreen(BuildContext context, DebriefCompleted state) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              
              // Success icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF6BE3A0).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Color(0xFF6BE3A0),
                  size: 40,
                ),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                'Debrief Complete',
                style: heading1Style(context).copyWith(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
              
              const SizedBox(height: 12),
              
              Text(
                'Completed in ${state.totalDuration.inMinutes}m ${state.totalDuration.inSeconds % 60}s',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryColor,
                  fontSize: 16,
                ),
              ),
              
              const Spacer(),
              
              // Actions
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: kcPrimaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Done',
                    style: buttonStyle(context).copyWith(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              OutlinedButton(
                onPressed: () {
                  // TODO: Implement share with redaction
                },
                child: Text(
                  'Share (redacted)',
                  style: buttonStyle(context).copyWith(
                    color: kcSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
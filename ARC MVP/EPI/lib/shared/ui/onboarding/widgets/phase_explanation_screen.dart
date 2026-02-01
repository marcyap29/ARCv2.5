// lib/shared/ui/onboarding/widgets/phase_explanation_screen.dart
// Phase Explanation Screen with rotating phase displays

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/ui/onboarding/arc_onboarding_cubit.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/ui/splash/animated_phase_shape.dart';

class PhaseExplanationScreen extends StatefulWidget {
  const PhaseExplanationScreen({super.key});

  @override
  State<PhaseExplanationScreen> createState() => _PhaseExplanationScreenState();
}

class _PhaseExplanationScreenState extends State<PhaseExplanationScreen>
    with TickerProviderStateMixin {
  int _currentPhaseIndex = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<PhaseLabel> _phases = PhaseLabel.values;
  final Duration _phaseDisplayDuration = const Duration(seconds: 3);
  final Duration _fadeDuration = const Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: _fadeDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Start with first phase visible
    _fadeController.forward();

    // Start phase rotation
    _startPhaseRotation();
  }

  void _startPhaseRotation() {
    Future.delayed(_phaseDisplayDuration, () {
      if (!mounted) return;
      
      // Fade out current phase
      _fadeController.reverse().then((_) {
        if (!mounted) return;
        
        // Move to next phase
        setState(() {
          _currentPhaseIndex = (_currentPhaseIndex + 1) % _phases.length;
        });
        
        // Fade in new phase
        _fadeController.forward();
        
        // Continue rotation
        _startPhaseRotation();
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  String _getPhaseName(PhaseLabel phase) {
    final phaseString = phase.toString().split('.').last;
    return phaseString[0].toUpperCase() + phaseString.substring(1);
  }

  String _getPhaseDescription(PhaseLabel phase) {
    return UserPhaseService.getPhaseDescription(_getPhaseName(phase));
  }

  @override
  Widget build(BuildContext context) {
    final currentPhase = _phases[_currentPhaseIndex];
    final phaseName = _getPhaseName(currentPhase);
    final phaseDescription = _getPhaseDescription(currentPhase);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _LayeredScreenContent(
          gradientColors: [
            kcPrimaryColor.withOpacity(0.2),
            Colors.black,
          ],
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                
                // Title
                Text(
                  "Understanding Your Phase",
                  style: heading1Style(context).copyWith(
                    color: Colors.white,
                    fontSize: 28,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Main explanation text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    children: [
                      Text(
                        "Your life moves through phases—not random moments, but developmental stages that shape how you see yourself and what questions matter most.",
                        style: bodyStyle(context).copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Discovery. Expansion. Transition. Consolidation. Recovery. Breakthrough.",
                        style: bodyStyle(context).copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Each phase has its own character, its own questions, its own way of seeing. When you're in Discovery, you're exploring new territory. In Expansion, you're reaching outward. Transition is the space between. Consolidation is integration. Recovery is restoration. Breakthrough is sudden clarity.",
                        style: bodyStyle(context).copyWith(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "The phase quiz helps me understand which phase you're in right now. I'll ask you five questions about where you are, what's occupying your thoughts, and what's changing. Your answers help me see the pattern you're living—not just what happened, but what it means for where you're going.",
                        style: bodyStyle(context).copyWith(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "This is your starting assessment. As you journal, I'll refine my understanding based on sustained patterns over time, not single entries. Your phase constellation will fill with words and insights as we talk.",
                        style: bodyStyle(context).copyWith(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Rotating phase display window
                Container(
                  width: 280,
                  height: 320,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: kcPrimaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Phase shape
                            AnimatedPhaseShape(
                              phase: phaseName.toLowerCase(),
                              size: 150,
                              rotationDuration: const Duration(seconds: 10),
                            ),
                            const SizedBox(height: 24),
                            
                            // Phase name
                            Text(
                              phaseName,
                              style: heading2Style(context).copyWith(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Phase description
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(
                                phaseDescription,
                                style: bodyStyle(context).copyWith(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Start Phase Quiz button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        context.read<ArcOnboardingCubit>().startPhaseQuiz();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kcPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Start Phase Quiz',
                        style: buttonStyle(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Skip button: SOP2 - default to Discovery, show phase reveal, then continue until RIVET identifies new phase
                TextButton(
                  onPressed: () {
                    context.read<ArcOnboardingCubit>().skipQuiz();
                  },
                  child: Text(
                    'Skip Phase Quiz',
                    style: bodyStyle(context).copyWith(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget that provides layered content structure for smooth transitions
class _LayeredScreenContent extends StatelessWidget {
  final List<Color> gradientColors;
  final Widget child;

  const _LayeredScreenContent({
    required this.gradientColors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
      ),
      child: Center(
        child: child,
      ),
    );
  }
}

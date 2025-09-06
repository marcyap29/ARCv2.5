import 'package:flutter/material.dart';
import 'package:my_app/features/home/home_view.dart';
import 'package:my_app/features/onboarding/onboarding_view.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/core/services/audio_service.dart';

class PhaseQuizPromptView extends StatefulWidget {
  const PhaseQuizPromptView({super.key});

  @override
  State<PhaseQuizPromptView> createState() => _PhaseQuizPromptViewState();
}

class _PhaseQuizPromptViewState extends State<PhaseQuizPromptView> {
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    _initializeSmartAudio();
  }

  void _initializeSmartAudio() async {
    try {
      // Check if audio service is already initialized and playing
      if (_audioService.isInitialized && _audioService.isPlaying) {
        print('DEBUG: PhaseQuizPromptView - Music already playing, continuing seamlessly');
        return;
      }

      // If not playing, initialize and start ethereal music
      print('DEBUG: PhaseQuizPromptView - Starting ethereal music (cold start scenario)');
      await _audioService.initialize();
      
      if (_audioService.isAvailable && !_audioService.isMuted) {
        await _audioService.switchToEtherealTrack();
        await _audioService.fadeInEthereal(duration: const Duration(seconds: 3));
        
        // Play for 2 loops then fade out
        _scheduleFadeOut();
      }
    } catch (e) {
      print('DEBUG: PhaseQuizPromptView - Audio not available: $e');
    }
  }

  void _scheduleFadeOut() async {
    // Wait for approximately 2 loops of the ethereal track
    // Assuming track is about 2-3 minutes, wait for 4-6 minutes total
    await Future.delayed(const Duration(minutes: 5));
    
    // Fade out over 10 seconds
    await _audioService.fadeOut(duration: const Duration(seconds: 10));
    print('DEBUG: PhaseQuizPromptView - Ethereal music faded out after 2 loops');
  }

  @override
  void dispose() {
    // Don't dispose audio service here as it might be used by other screens
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C0F14),
              Color(0xFF121621),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: kcPrimaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.quiz,
                    size: 40,
                    color: kcPrimaryColor,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Title
                Text(
                  'Ready to discover your phase?',
                  style: heading1Style(context).copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Description
                Text(
                  'It looks like you haven\'t set up your personal phase yet. Take a quick quiz to discover which season of life you\'re in right now.',
                  style: bodyStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                
                // Take Quiz Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OnboardingView(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Take Phase Quiz',
                      style: heading3Style(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Skip Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeView(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: Text(
                      'Skip for now',
                      style: heading3Style(context).copyWith(
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Help text
                Text(
                  'You can always take the quiz later from the main menu',
                  style: captionStyle(context).copyWith(
                    color: Colors.white.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

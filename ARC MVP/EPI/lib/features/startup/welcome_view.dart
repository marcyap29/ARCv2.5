import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:my_app/features/onboarding/onboarding_view.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView>
    with TickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late AnimationController _glowController;
  late AnimationController _fadeController;
  bool _isAudioPlaying = false;
  bool _isAudioMuted = false;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
    _initializeAnimations();
  }

  void _initializeAudio() async {
    _audioPlayer = AudioPlayer();
    try {
      // For now, we'll use a placeholder. In production, replace with actual ambient audio
      // await _audioPlayer.setAsset('assets/audio/ambient_welcome.mp3');
      // await _audioPlayer.setLoopMode(LoopMode.one);
      // await _audioPlayer.play();
      // setState(() => _isAudioPlaying = true);
    } catch (e) {
      // Audio file not found, continue without audio
      debugPrint('Audio not available: $e');
    }
  }

  void _initializeAnimations() {
    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Start fade in
    _fadeController.forward();
  }

  void _toggleAudio() {
    if (_isAudioMuted) {
      _audioPlayer.setVolume(0.5);
      setState(() => _isAudioMuted = false);
    } else {
      _audioPlayer.setVolume(0.0);
      setState(() => _isAudioMuted = true);
    }
  }

  void _skipAudio() {
    _audioPlayer.stop();
    setState(() => _isAudioPlaying = false);
  }

  void _beginJourney() async {
    // Fade out audio
    if (_isAudioPlaying) {
      await _audioPlayer.setVolume(0.0);
      await _audioPlayer.stop();
    }

    // Fade out screen
    await _fadeController.reverse();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const OnboardingView(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _glowController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeController,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0C0F14),
                Color(0xFF121621),
                Color(0xFF171C29),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Audio controls
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isAudioPlaying) ...[
                          IconButton(
                            onPressed: _toggleAudio,
                            icon: Icon(
                              _isAudioMuted ? Icons.volume_off : Icons.volume_up,
                              color: Colors.white.withOpacity(0.7),
                              size: 24,
                            ),
                          ),
                          IconButton(
                            onPressed: _skipAudio,
                            icon: Icon(
                              Icons.skip_next,
                              color: Colors.white.withOpacity(0.7),
                              size: 24,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Main content
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App title with glow animation
                      AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          return Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: kcPrimaryColor.withOpacity(
                                    0.3 + (0.2 * _glowController.value),
                                  ),
                                  blurRadius: 40 + (20 * _glowController.value),
                                  spreadRadius: 10 + (5 * _glowController.value),
                                ),
                              ],
                            ),
                            child: Text(
                              'EPI',
                              style: heading1Style(context).copyWith(
                                fontSize: 72,
                                fontWeight: FontWeight.w300,
                                color: Colors.white,
                                letterSpacing: 8,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Tagline
                      Text(
                        'Evolving Personal Intelligence',
                        style: heading2Style(context).copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w300,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),

                      // Subtitle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'A new kind of intelligence that grows with you',
                          style: bodyStyle(context).copyWith(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 80),

                      // Begin journey button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(
                            minWidth: 240,
                            maxWidth: 320,
                            minHeight: 56,
                          ),
                          decoration: BoxDecoration(
                            gradient: kcPrimaryGradient,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: kcPrimaryColor.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _beginJourney,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                            child: Text(
                              'Begin Your Journey',
                              style: buttonStyle(context).copyWith(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom spacing
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

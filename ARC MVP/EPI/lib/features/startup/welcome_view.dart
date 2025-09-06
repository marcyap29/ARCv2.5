import 'package:flutter/material.dart';
import 'package:my_app/core/services/audio_service.dart';
import 'package:my_app/features/startup/phase_quiz_prompt_view.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _glowController;
  late AnimationController _fadeController;
  final AudioService _audioService = AudioService();
  bool _isAudioPlaying = false;
  bool _isAudioMuted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAudio();
    _initializeAnimations();
  }

  void _initializeAudio() async {
    try {
      await _audioService.initialize();
      if (_audioService.isAvailable && !_audioService.isMuted) {
        // Start with ethereal track and fade in gently
        await _audioService.switchToEtherealTrack();
        await _audioService.fadeInEthereal(duration: const Duration(seconds: 3));
        setState(() {
          _isAudioPlaying = _audioService.isPlaying;
          _isAudioMuted = _audioService.isMuted;
        });
      }
    } catch (e) {
      // Audio not available, continue without audio
      debugPrint('Audio not available: $e');
    }
  }

  void _initializeAnimations() {
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Start fade in
    _fadeController.forward();
  }

  void _toggleAudio() async {
    await _audioService.toggleMute();
    setState(() {
      _isAudioMuted = _audioService.isMuted;
    });
  }

  void _skipAudio() async {
    await _audioService.stop();
    setState(() => _isAudioPlaying = false);
  }

  void _beginJourney() async {
    // Wait 1-2 seconds before starting transition
    await Future.delayed(const Duration(seconds: 1));
    
    // Fade out audio
    if (_isAudioPlaying) {
      await _audioService.fadeOut(duration: const Duration(seconds: 2));
    }

    // Fade out screen
    await _fadeController.reverse();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const PhaseQuizPromptView(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
        _audioService.pause();
        break;
      case AppLifecycleState.resumed:
        if (_isAudioPlaying && !_isAudioMuted) {
          _audioService.resume();
        }
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioService.dispose();
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
                                // Outer pulsing glow
                                BoxShadow(
                                  color: kcPrimaryColor.withOpacity(
                                    0.4 + (0.3 * _glowController.value),
                                  ),
                                  blurRadius: 60 + (30 * _glowController.value),
                                  spreadRadius: 15 + (10 * _glowController.value),
                                ),
                                // Inner pulsing glow
                                BoxShadow(
                                  color: kcPrimaryColor.withOpacity(
                                    0.6 + (0.4 * _glowController.value),
                                  ),
                                  blurRadius: 30 + (15 * _glowController.value),
                                  spreadRadius: 5 + (3 * _glowController.value),
                                ),
                                // Core bright glow
                                BoxShadow(
                                  color: kcPrimaryColor.withOpacity(
                                    0.8 + (0.2 * _glowController.value),
                                  ),
                                  blurRadius: 15 + (8 * _glowController.value),
                                  spreadRadius: 2 + (1 * _glowController.value),
                                ),
                              ],
                            ),
                            child: Text(
                              'ARC',
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

                      const SizedBox(height: 40),

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
                              'Continue Your Journey',
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

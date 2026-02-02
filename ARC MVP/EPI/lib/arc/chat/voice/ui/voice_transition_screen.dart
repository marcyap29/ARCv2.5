/// Voice Transition Screen
///
/// Shown for a minimum of 4 seconds when moving from main menu to voice mode.
/// Gives Wispr (and other services) time to connect before the user sees the
/// talk button, avoiding "press talk too fast before service is ready" issues.

import 'package:flutter/material.dart';
import '../services/voice_session_service.dart';

class VoiceTransitionScreen extends StatefulWidget {
  /// Future that initializes the voice session (LUMARA API, Wispr, etc.).
  final Future<VoiceSessionService?> Function() initFuture;

  /// Minimum time to show this screen (e.g. 4 seconds) so services can connect.
  final Duration minTransitionDuration;

  /// Called when init succeeded; caller should push VoiceModeScreen.
  final void Function(VoiceSessionService sessionService) onSuccess;

  /// Called when init failed; caller may show error.
  final void Function(String message) onError;

  const VoiceTransitionScreen({
    super.key,
    required this.initFuture,
    this.minTransitionDuration = const Duration(seconds: 4),
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<VoiceTransitionScreen> createState() => _VoiceTransitionScreenState();
}

class _VoiceTransitionScreenState extends State<VoiceTransitionScreen> {
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _runTransition();
  }

  Future<void> _runTransition() async {
    final minDelay = Future<void>.delayed(widget.minTransitionDuration);
    VoiceSessionService? sessionService;
    String? errorMessage;

    try {
      sessionService = await widget.initFuture();
    } catch (e, st) {
      debugPrint('VoiceTransition: init failed: $e\n$st');
      errorMessage = e.toString();
    }

    await minDelay;

    if (!mounted) return;
    if (_completed) return;
    _completed = true;

    if (sessionService != null) {
      Navigator.of(context).pop();
      widget.onSuccess(sessionService);
    } else {
      Navigator.of(context).pop();
      widget.onError(errorMessage ?? 'Failed to initialize voice mode.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFFC9A227)),
              const SizedBox(height: 24),
              Text(
                'Preparing voice…',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connecting…',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

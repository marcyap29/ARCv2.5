import 'package:flutter/foundation.dart';

enum VCState { idle, listening, thinking, speaking, error }

typedef PipelineFn = Future<void> Function(String userText);
typedef SpeakFn = Future<void> Function(String text);
typedef StartListenFn = Future<void> Function();
typedef StopAndGetFinalFn = Future<String?> Function();
typedef EndSessionFn = Future<void> Function(); // Callback for end session

class PushToTalkController extends ChangeNotifier {
  VCState _state = VCState.idle;
  VCState get state => _state;
  bool _isFirstTap = true; // Track if this is the first tap (start conversation)
  
  final StartListenFn startListening;
  final StopAndGetFinalFn stopAndGetFinal;
  final PipelineFn processUserText;  // includes routing and calling speak()
  final void Function(VCState)? onState;
  final EndSessionFn? onEndSession; // Callback for end session (summary generation)

  PushToTalkController({
    required this.startListening,
    required this.stopAndGetFinal,
    required this.processUserText,
    this.onState,
    this.onEndSession, // ADD THIS
  });

  void _setState(VCState newState) {
    if (_state != newState) {
      _state = newState;
      onState?.call(_state);
      notifyListeners();
    }
  }

  /// Handle microphone tap
  /// First tap: Start conversation and begin listening
  /// Subsequent taps: Process accumulated text and get LUMARA response
  Future<void> onMicTap() async {
    if (_state == VCState.idle || _isFirstTap) {
      // First tap: Start conversation
      _isFirstTap = false;
      _setState(VCState.listening);
      await startListening();
      return;
    }
    if (_state == VCState.listening) {
      // Subsequent taps: Process accumulated text and get LUMARA response
      _setState(VCState.thinking);
      final text = await stopAndGetFinal();
      if (text == null || text.trim().isEmpty) {
        // No text accumulated, just resume listening
        _setState(VCState.listening);
        await startListening();
        return;
      }
      await processUserText(text);
    }
  }

  void onSpeakingStart() {
    _setState(VCState.speaking);
  }

  /// Called after LUMARA finishes speaking
  /// Auto-resumes listening for the next turn in the conversation
  Future<void> onSpeakingDone() async {
    // Auto-resume listening for next turn
    _setState(VCState.listening);
    await startListening();
  }

  /// End session: Stop listening and save transcript, but do NOT trigger LUMARA response
  /// LUMARA responses only happen when microphone button is tapped, not when ending session
  Future<void> endSession() async {
    // Stop listening immediately - don't process or trigger LUMARA response
    // Just stop and save the transcript
    if (_state == VCState.listening || _state == VCState.speaking || _state == VCState.thinking) {
      // Stop listening to get final transcript (but don't process it)
      await stopAndGetFinal();
    }
    
    // Immediately set state to idle - this stops all transcript updates and shows final transcript
    _isFirstTap = true;
    _setState(VCState.idle);
    
    // Call end session callback (for summary generation) - this happens after state is idle
    // so UI updates immediately
    if (onEndSession != null) {
      // Run summary generation in background, don't block UI
      onEndSession!().catchError((e) {
        debugPrint('Error in endSession callback: $e');
      });
    }
  }
}

import 'package:flutter/foundation.dart';

enum VCState { idle, listening, thinking, speaking, error }

typedef PipelineFn = Future<void> Function(String userText);
typedef SpeakFn = Future<void> Function(String text);
typedef StartListenFn = Future<void> Function();
typedef StopAndGetFinalFn = Future<String?> Function();

class PushToTalkController extends ChangeNotifier {
  VCState _state = VCState.idle;
  VCState get state => _state;
  
  final StartListenFn startListening;
  final StopAndGetFinalFn stopAndGetFinal;
  final PipelineFn processUserText;  // includes routing and calling speak()
  final void Function(VCState)? onState;

  PushToTalkController({
    required this.startListening,
    required this.stopAndGetFinal,
    required this.processUserText,
    this.onState,
  });

  void _setState(VCState newState) {
    if (_state != newState) {
      _state = newState;
      onState?.call(_state);
      notifyListeners();
    }
  }

  Future<void> onMicTap() async {
    if (_state == VCState.idle) {
      _setState(VCState.listening);
      await startListening();
      return;
    }
    if (_state == VCState.listening) {
      _setState(VCState.thinking);
      final text = await stopAndGetFinal();
      if (text == null || text.trim().isEmpty) {
        _setState(VCState.idle);
        return;
      }
      await processUserText(text);
    }
  }

  void onSpeakingStart() {
    _setState(VCState.speaking);
  }

  Future<void> onSpeakingDone() async {
    _setState(VCState.listening);
    await startListening();
  }

  void endSession() {
    _setState(VCState.idle);
  }
}


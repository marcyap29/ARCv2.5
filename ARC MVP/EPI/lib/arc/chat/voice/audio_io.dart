import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class AudioIO {
  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _sttInitialized = false;
  String? _tempAudioPath;
  bool _isSpeaking = false;

  /// Initialize speech-to-text
  Future<bool> initializeSTT() async {
    if (_sttInitialized) return true;
    
    final available = await _stt.initialize(
      onError: (error) => print('STT Error: $error'),
      onStatus: (status) => print('STT Status: $status'),
    );
    
    _sttInitialized = available;
    return available;
  }

  /// Initialize text-to-speech
  Future<void> initializeTTS() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  /// Start listening and return transcript stream
  Future<void> startListening({
    required Function(String partial) onPartialResult,
    required Function(String finalResult) onFinalResult,
    Function(String error)? onError,
    Function(double level)? onSoundLevelChange, // Audio level callback (0.0-1.0)
  }) async {
    if (!_sttInitialized) {
      final initialized = await initializeSTT();
      if (!initialized) {
        onError?.call('Speech recognition not available');
        return;
      }
    }

    await _stt.listen(
      onResult: (result) {
        // Auto-capitalize speech-to-text results
        final capitalizedText = _capitalizeText(result.recognizedWords);
        if (result.finalResult) {
          onFinalResult(capitalizedText);
        } else {
          onPartialResult(capitalizedText);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 10), // Increased from 2s to allow natural pauses
      partialResults: true,
      localeId: "en_US",
      onSoundLevelChange: onSoundLevelChange != null
          ? (level) {
              // speech_to_text provides level in dB (typically -160 to 0)
              // Pass it through to the callback for normalization
              onSoundLevelChange(level);
            }
          : null,
      cancelOnError: true,
      listenMode: stt.ListenMode.dictation, // Changed from confirmation to dictation for longer speech
    );
  }

  /// Stop listening and get final transcript
  Future<String?> stopListening() async {
    await _stt.stop();
    // Note: final result comes via onFinalResult callback
    return null;
  }

  /// Cancel listening
  Future<void> cancelListening() async {
    await _stt.cancel();
  }

  /// Speak text using TTS
  Future<void> speak(String text, {
    Function()? onStart,
    Function()? onComplete,
    Function(String)? onError,
  }) async {
    try {
      _isSpeaking = true;
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        onComplete?.call();
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        onError?.call(msg);
      });

      onStart?.call();
      await _tts.speak(text);
    } catch (e) {
      _isSpeaking = false;
      onError?.call(e.toString());
    }
  }

  /// Stop TTS playback
  Future<void> stopSpeaking() async {
    _isSpeaking = false;
    await _tts.stop();
  }

  /// Create temporary audio file path
  Future<String> createTempAudioPath() async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _tempAudioPath = '${dir.path}/voice_$timestamp.m4a';
    return _tempAudioPath!;
  }

  /// Clean up temporary audio file
  Future<void> cleanupTempAudio() async {
    if (_tempAudioPath != null) {
      try {
        final file = File(_tempAudioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error cleaning up temp audio: $e');
      }
      _tempAudioPath = null;
    }
  }

  /// Check if STT is available
  bool get isSTTAvailable => _sttInitialized;

  /// Check if currently listening
  bool get isListening => _stt.isListening;

  /// Check if currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Capitalize the first letter of text (for speech-to-text auto-capitalization)
  String _capitalizeText(String text) {
    if (text.isEmpty) return text;
    // Capitalize first letter and keep the rest as-is
    return text[0].toUpperCase() + (text.length > 1 ? text.substring(1) : '');
  }
}


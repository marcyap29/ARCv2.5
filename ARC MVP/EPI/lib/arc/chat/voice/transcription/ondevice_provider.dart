/// On-device transcription provider using speech_to_text plugin
/// 
/// This wraps the existing AudioIO functionality as a TranscriptionProvider
/// for seamless integration with the transcription router.

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'transcription_provider.dart';

class OnDeviceTranscriptionProvider implements TranscriptionProvider {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _initialized = false;
  ProviderStatus _status = ProviderStatus.idle;
  
  @override
  String get name => 'On-Device (speech_to_text)';
  
  @override
  bool get requiresNetwork => false;
  
  @override
  ProviderStatus get status => _status;
  
  @override
  bool get isListening => _stt.isListening;

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    
    _status = ProviderStatus.initializing;
    
    try {
      final available = await _stt.initialize(
        onError: (error) => print('OnDevice STT Error: $error'),
        onStatus: (status) => print('OnDevice STT Status: $status'),
      );
      
      _initialized = available;
      _status = available ? ProviderStatus.idle : ProviderStatus.unavailable;
      return available;
    } catch (e) {
      print('OnDevice STT initialization error: $e');
      _status = ProviderStatus.error;
      return false;
    }
  }

  @override
  Future<void> startListening({
    required Function(TranscriptSegment segment) onPartialResult,
    required Function(TranscriptSegment segment) onFinalResult,
    Function(String error)? onError,
    Function(double level)? onSoundLevel,
  }) async {
    if (!_initialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError?.call('On-device speech recognition not available');
        return;
      }
    }

    _status = ProviderStatus.listening;

    await _stt.listen(
      onResult: (result) {
        final segment = TranscriptSegment(
          text: _capitalizeText(result.recognizedWords),
          isFinal: result.finalResult,
          confidence: result.confidence,
        );
        
        if (result.finalResult) {
          onFinalResult(segment);
        } else {
          onPartialResult(segment);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 10),
      partialResults: true,
      localeId: "en_US",
      onSoundLevelChange: onSoundLevel != null
          ? (level) {
              // Normalize dB level to 0.0-1.0 range
              // speech_to_text typically provides -160 to 0 dB
              final normalized = ((level + 160) / 160).clamp(0.0, 1.0);
              onSoundLevel(normalized);
            }
          : null,
      cancelOnError: false,
      listenMode: stt.ListenMode.dictation,
    );
  }

  @override
  Future<void> stopListening() async {
    _status = ProviderStatus.processing;
    await _stt.stop();
    _status = ProviderStatus.idle;
  }

  @override
  Future<void> cancelListening() async {
    await _stt.cancel();
    _status = ProviderStatus.idle;
  }

  @override
  Future<bool> isAvailable() async {
    if (!_initialized) {
      return await initialize();
    }
    return _initialized;
  }

  @override
  Future<void> dispose() async {
    await _stt.cancel();
    _status = ProviderStatus.idle;
  }

  /// Capitalize text with sentence capitalization
  String _capitalizeText(String text) {
    if (text.isEmpty) return text;
    
    final sentencePattern = RegExp(r'([.!?]\s*)');
    final parts = text.split(sentencePattern);
    
    final buffer = StringBuffer();
    bool capitalizeNext = true;
    
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      
      if (part.isEmpty) continue;
      
      if (sentencePattern.hasMatch(part)) {
        buffer.write(part);
        capitalizeNext = true;
      } else {
        if (capitalizeNext && part.isNotEmpty) {
          final firstChar = part[0].toUpperCase();
          final rest = part.length > 1 ? part.substring(1) : '';
          buffer.write(firstChar + rest);
          capitalizeNext = false;
        } else {
          buffer.write(part);
        }
      }
    }
    
    final result = buffer.toString();
    if (result.isNotEmpty && result[0] != result[0].toUpperCase()) {
      return result[0].toUpperCase() + (result.length > 1 ? result.substring(1) : '');
    }
    
    return result.isNotEmpty ? result : text;
  }
}

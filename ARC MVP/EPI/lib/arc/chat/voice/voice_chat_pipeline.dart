import 'audio_io.dart';
import 'prism_scrubber.dart';
import '../services/enhanced_lumara_api.dart';

abstract class VoiceChatPipeline {
  Future<String> transcribe(String audioPath);        // Mode A
  Future<String> scrubPII(String transcript);         // Mode A
  Future<String> callLLMText(String text, {Map<String, dynamic>? ctx});  // A
  Future<String> callLLMAudio(String audioPath, {Map<String, dynamic>? ctx}); // B
  Future<void> speak(String text);
}

class ModeAPipeline implements VoiceChatPipeline {
  final AudioIO _audioIO;
  final EnhancedLumaraApi _lumaraApi;

  ModeAPipeline(this._audioIO, this._lumaraApi);

  @override
  Future<String> transcribe(String audioPath) async {
    // For Mode A, we use live STT (already handled in AudioIO)
    // This method is kept for compatibility but audioPath is not used
    // The actual transcription happens via startListening callbacks
    return '';
  }

  @override
  Future<String> scrubPII(String transcript) async {
    return PrismScrubber.scrub(transcript);
  }

  @override
  Future<String> callLLMText(String text, {Map<String, dynamic>? ctx}) async {
    try {
      // Use EnhancedLumaraApi for chat responses
      final result = await _lumaraApi.generatePromptedReflection(
        entryText: text,
        intent: 'chat',
        phase: ctx?['phase'] as String?,
        userId: ctx?['userId'] as String?,
        chatContext: ctx?['chatContext'] as String?,
        onProgress: (msg) => print('LLM Progress: $msg'),
      );
      return result.reflection;
    } catch (e) {
      print('LLM Error: $e');
      // Fallback to simple response
      return "I'm sorry, I couldn't process that request right now. Please try again.";
    }
  }

  @override
  Future<String> callLLMAudio(String audioPath, {Map<String, dynamic>? ctx}) async {
    throw UnimplementedError('Mode A does not support audio input to LLM');
  }

  @override
  Future<void> speak(String text) async {
    await _audioIO.speak(text);
  }
}

class ModeBPipeline implements VoiceChatPipeline {
  final AudioIO _audioIO;
  final EnhancedLumaraApi _lumaraApi;

  ModeBPipeline(this._audioIO, this._lumaraApi);

  @override
  Future<String> transcribe(String audioPath) async {
    throw UnimplementedError('Mode B does not use local transcription');
  }

  @override
  Future<String> scrubPII(String transcript) async {
    // Mode B sends audio directly, no scrubbing needed
    return transcript;
  }

  @override
  Future<String> callLLMText(String text, {Map<String, dynamic>? ctx}) async {
    throw UnimplementedError('Mode B uses audio input, not text');
  }

  @override
  Future<String> callLLMAudio(String audioPath, {Map<String, dynamic>? ctx}) async {
    try {
      // TODO: Implement audio-to-LLM API call
      // For now, return placeholder
      return "Mode B (audio-to-LLM) is not yet implemented. Please use Mode A.";
    } catch (e) {
      print('LLM Audio Error: $e');
      return "I'm sorry, I couldn't process that audio right now.";
    }
  }

  @override
  Future<void> speak(String text) async {
    await _audioIO.speak(text);
  }
}


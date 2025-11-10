import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'audio_io.dart';
import 'push_to_talk_controller.dart';
import 'voice_chat_pipeline.dart';
import 'voice_orchestrator.dart';
import 'context_memory.dart';
import 'voice_diagnostics.dart';
import '../../journal/journal_manager.dart';
import '../main_chat_manager.dart';
import '../../files/file_manager.dart';
import '../services/enhanced_lumara_api.dart';
import '../../core/journal_capture_cubit.dart';
import '../bloc/lumara_assistant_cubit.dart';
import '../data/context_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceChatService {
  final AudioIO _audioIO = AudioIO();
  final VoiceDiagnostics _diagnostics = VoiceDiagnostics();
  final ContextMemory _memory = ContextMemory();
  
  PushToTalkController? _controller;
  VoiceChatPipeline? _pipeline;
  VoiceOrchestrator? _orchestrator;
  
  String? _partialTranscript;
  final StreamController<String> _partialTranscriptController = StreamController<String>.broadcast();
  
  bool _useModeA = true; // Default to Mode A (STT → PRISM → LLM → TTS)
  
  // Dependencies
  final EnhancedLumaraApi? _lumaraApi;
  final JournalCaptureCubit? _journalCubit;
  final LumaraAssistantCubit? _chatCubit;
  final ContextProvider? _contextProvider;

  VoiceChatService({
    EnhancedLumaraApi? lumaraApi,
    JournalCaptureCubit? journalCubit,
    LumaraAssistantCubit? chatCubit,
    ContextProvider? contextProvider,
  }) : _lumaraApi = lumaraApi,
       _journalCubit = journalCubit,
       _chatCubit = chatCubit,
       _contextProvider = contextProvider;

  /// Initialize the voice chat service
  Future<bool> initialize() async {
    try {
      // Direct check: if microphone is granted, proceed immediately
      // Don't request permissions here - that should be done by the UI before calling initialize()
      final micStatus = await Permission.microphone.status;
      debugPrint('VoiceChatService: Microphone status = $micStatus');
      
      if (!micStatus.isGranted) {
        debugPrint('VoiceChatService: Microphone not granted - initialization should be called after permissions are granted');
        return false;
      }
      
      debugPrint('VoiceChatService: Microphone granted, proceeding with initialization...');

      debugPrint('VoiceChatService: All permissions granted, initializing audio I/O...');
      
      // Initialize audio I/O (STT should already be initialized by permission request)
      final sttInitialized = await _audioIO.initializeSTT();
      if (!sttInitialized) {
        debugPrint('VoiceChatService: Failed to initialize STT');
        return false;
      }
      await _audioIO.initializeTTS();

      // Load mode preference
      final prefs = await SharedPreferences.getInstance();
      _useModeA = prefs.getBool('voice_mode_a') ?? true;

      // Create pipeline
      if (_lumaraApi == null) {
        throw Exception('EnhancedLumaraApi is required');
      }
      _pipeline = _useModeA
          ? ModeAPipeline(_audioIO, _lumaraApi!)
          : ModeBPipeline(_audioIO, _lumaraApi!);

      // Create managers
      final journalManager = JournalManager(captureCubit: _journalCubit);
      final chatManager = MainChatManager(
        assistantCubit: _chatCubit,
        contextProvider: _contextProvider,
      );
      final fileManager = FileManager();

      // Create orchestrator (stored but not directly used - accessed via pipeline)
      final orchestrator = VoiceOrchestrator(
        pipeline: _pipeline!,
        memory: _memory,
        journal: journalManager,
        chat: chatManager,
        files: fileManager,
      );
      _orchestrator = orchestrator;

      // Create controller with state callback
      _controller = PushToTalkController(
        startListening: _startListening,
        stopAndGetFinal: _stopAndGetFinal,
        processUserText: _processUserText,
        onState: (state) {
          // State changes are tracked in controller.state
          // UI can read state directly from controller
        },
      );

      return true;
    } catch (e) {
      debugPrint('VoiceChatService initialization error: $e');
      return false;
    }
  }

  /// Start listening
  Future<void> _startListening() async {
    _diagnostics.record('t_mic_start');
    _partialTranscript = '';

    await _audioIO.startListening(
      onPartialResult: (partial) {
        _partialTranscript = partial;
        _partialTranscriptController.add(partial);
      },
      onFinalResult: (finalResult) {
        _partialTranscript = finalResult;
        _partialTranscriptController.add(finalResult);
      },
      onError: (error) {
        debugPrint('STT Error: $error');
        _controller?.endSession();
      },
    );
  }

  /// Stop listening and get final transcript
  Future<String?> _stopAndGetFinal() async {
    await _audioIO.stopListening();
    _diagnostics.record('t_final_text');
    return _partialTranscript;
  }

  /// Process user text through the pipeline
  Future<void> _processUserText(String userText) async {
    try {
      _diagnostics.record('t_user_text_received');

      // Use orchestrator to route intent and process
      if (_orchestrator != null) {
        await _orchestrator!.process(userText);
        _diagnostics.record('t_tts_end');
        await _controller?.onSpeakingDone();
      } else {
        // Fallback: Mode A pipeline directly
        if (_useModeA && _pipeline is ModeAPipeline) {
          final pipeline = _pipeline as ModeAPipeline;
          
          // Scrub PII
          final scrubbed = await pipeline.scrubPII(userText);
          _diagnostics.record('t_scrub_done');

          // Call LLM
          final reply = await pipeline.callLLMText(
            scrubbed,
            ctx: _memory.toCtx(),
          );
          _diagnostics.record('t_llm_reply');

          // Speak reply
          _controller?.onSpeakingStart();
          await pipeline.speak(reply);
          _diagnostics.record('t_tts_end');
          await _controller?.onSpeakingDone();
        } else {
          // Mode B: Audio → LLM → TTS (not fully implemented)
          throw UnimplementedError('Mode B not yet implemented');
        }
      }
    } catch (e) {
      debugPrint('Error processing user text: $e');
      _controller?.endSession();
    }
  }

  /// Toggle between Mode A and Mode B
  Future<void> toggleMode() async {
    _useModeA = !_useModeA;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_mode_a', _useModeA);

    // Reinitialize with new mode
    await initialize();
  }

  /// Get the controller
  PushToTalkController? get controller => _controller;

  /// Get diagnostics
  VoiceDiagnostics get diagnostics => _diagnostics;

  /// Get partial transcript stream
  Stream<String> get partialTranscriptStream => _partialTranscriptController.stream;

  /// Get current partial transcript
  String? get partialTranscript => _partialTranscript;

  /// Check if Mode A is enabled
  bool get useModeA => _useModeA;

  /// Cleanup
  void dispose() {
    _audioIO.cleanupTempAudio();
    _partialTranscriptController.close();
  }
}


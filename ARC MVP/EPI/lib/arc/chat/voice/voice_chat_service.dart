import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'audio_io.dart';
import 'push_to_talk_controller.dart';
import 'voice_chat_pipeline.dart';
import 'voice_orchestrator.dart'; // VoiceContext is defined here
import 'context_memory.dart';
import 'voice_diagnostics.dart';
import 'prism_scrubber.dart';
import '../../journal/journal_manager.dart';
import '../main_chat_manager.dart';
import '../../files/file_manager.dart';
import '../services/enhanced_lumara_api.dart';
import '../../core/journal_capture_cubit.dart';
import '../bloc/lumara_assistant_cubit.dart';
import '../data/context_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../mira/memory/enhanced_memory_schema.dart';

class VoiceChatService {
  final AudioIO _audioIO = AudioIO();
  final VoiceDiagnostics _diagnostics = VoiceDiagnostics();
  final ContextMemory _memory = ContextMemory();
  
  PushToTalkController? _controller;
  VoiceChatPipeline? _pipeline;
  VoiceOrchestrator? _orchestrator;
  
  String? _partialTranscript;
  String? _finalTranscript; // Store final transcript when session ends
  String _accumulatedTranscript = ''; // Accumulates text across pauses
  final StreamController<String> _partialTranscriptController = StreamController<String>.broadcast();
  
  bool _useModeA = true; // Default to Mode A (STT → PRISM → LLM → TTS)
  VoiceContext _context = VoiceContext.chat; // Default to chat context
  
  // Conversation tracking for summary generation
  String _fullConversationText = ''; // Track full conversation for summary
  Function(String)? _onTextWritten; // Callback to write text to journal view
  
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
    VoiceContext context = VoiceContext.chat,
    Function(String)? onTextWritten, // Callback to write text to journal view
  }) : _lumaraApi = lumaraApi,
       _journalCubit = journalCubit,
       _chatCubit = chatCubit,
       _contextProvider = contextProvider,
       _context = context,
       _onTextWritten = onTextWritten;
  
  /// Set the context mode (chat or journal)
  void setContext(VoiceContext context) {
    _context = context;
  }
  
  /// Get the current context mode
  VoiceContext get context => _context;

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

      // Create orchestrator with context and text writer callback
      final orchestrator = VoiceOrchestrator(
        pipeline: _pipeline!,
        memory: _memory,
        journal: journalManager,
        chat: chatManager,
        files: fileManager,
        context: _context,
        onTextWritten: (text) {
          // Track full conversation for summary
          _fullConversationText += text;
          // Write to journal view
          _onTextWritten?.call(text);
        },
        onSpeakingStart: () {
          // Notify controller that TTS is starting
          _controller?.onSpeakingStart();
        },
        onSpeakingDone: () async {
          // Notify controller that TTS is done and auto-resume listening
          await _controller?.onSpeakingDone();
        },
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
        onEndSession: endSessionAndGenerateSummary, // Generate summary when session ends
      );

      return true;
    } catch (e) {
      debugPrint('VoiceChatService initialization error: $e');
      return false;
    }
  }

  /// Start listening
  Future<void> _startListening({bool isResume = false}) async {
    if (!isResume) {
    _diagnostics.record('t_mic_start');
    _partialTranscript = '';
      _finalTranscript = null; // Clear final transcript when starting new session
      _accumulatedTranscript = ''; // Reset accumulated transcript on new session
      _fullConversationText = ''; // Reset conversation text on new session
    }

    await _audioIO.startListening(
      onPartialResult: (partial) {
        // Only update transcript if we're still listening (not idle/ended)
        final currentState = _controller?.state;
        if (currentState == VCState.listening) {
          // Show accumulated + current partial
          final displayText = _accumulatedTranscript.isEmpty 
              ? partial 
              : '$_accumulatedTranscript $partial';
          _partialTranscript = displayText;
          _partialTranscriptController.add(displayText);
        } else if (currentState == VCState.idle) {
          // Session ended - stop updating transcript
          _audioIO.stopListening();
        }
      },
      onFinalResult: (finalResult) {
        // Only accumulate if we're still in listening state (user hasn't tapped button yet)
        // Also check that we're not idle (session ended)
        final currentState = _controller?.state;
        if (currentState == VCState.listening) {
          // Accumulate the final result from this segment
          if (_accumulatedTranscript.isEmpty) {
            _accumulatedTranscript = finalResult;
          } else {
            _accumulatedTranscript = '$_accumulatedTranscript $finalResult';
          }
          _partialTranscript = _accumulatedTranscript;
          _partialTranscriptController.add(_accumulatedTranscript);
          
          // Auto-resume listening if STT stopped due to pause
          // This allows user to pause and think, then continue speaking
          if (!_audioIO.isListening) {
            debugPrint('STT stopped due to pause, auto-resuming to continue transcription...');
            // Small delay to ensure STT has fully stopped
            Future.delayed(const Duration(milliseconds: 300), () {
              // Double-check we're still in listening state and not idle before resuming
              final state = _controller?.state;
              if (state == VCState.listening && !_audioIO.isListening) {
                _startListening(isResume: true);
              }
            });
          }
        } else if (currentState == VCState.idle) {
          // Session ended - stop updating transcript
          debugPrint('Session ended, stopping transcript updates');
          _audioIO.stopListening();
        }
      },
      onError: (error) {
        debugPrint('STT Error: $error');
        _controller?.endSession();
      },
    );
  }

  /// Stop listening and get final transcript
  Future<String?> _stopAndGetFinal() async {
    // Stop listening immediately
    await _audioIO.stopListening();
    _diagnostics.record('t_final_text');
    
    // Return accumulated transcript (includes all segments from pauses in this turn)
    final finalText = _accumulatedTranscript.isNotEmpty 
        ? _accumulatedTranscript 
        : _partialTranscript ?? '';
    
    // Don't reset accumulated transcript here - keep it for processing
    // It will be reset when a new session starts
    
    return finalText;
  }

  /// Process user text through the pipeline
  /// After processing, resets accumulated transcript for next turn
  Future<void> _processUserText(String userText) async {
    try {
      _diagnostics.record('t_user_text_received');

      // Use orchestrator to route intent and process
      if (_orchestrator != null) {
        await _orchestrator!.process(userText);
        _diagnostics.record('t_tts_end');
        
        // Reset accumulated transcript for next turn
        _accumulatedTranscript = '';
        _partialTranscript = '';
        
        // onSpeakingDone is called by orchestrator's callback
        // No need to call it here - it will set state to idle (ready)
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
          
          // Reset accumulated transcript for next turn
          _accumulatedTranscript = '';
          _partialTranscript = '';
          
          // Set to idle (ready) - user must press mic again
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

  /// Generate summary of full conversation
  /// Creates JSON representation, scrubs PII, sends for summary, then restores PII
  Future<String> _generateSummary(String fullText) async {
    if (_lumaraApi == null || fullText.trim().isEmpty) {
      return '';
    }
    
    // Only generate summary if content is substantial (more than 50 words)
    final wordCount = fullText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (wordCount < 50) {
      return ''; // Skip summary for very short entries
    }
    
    // Check if summary already exists
    if (fullText.startsWith('## Summary\n\n')) {
      return ''; // Already has a summary
    }
    
    try {
      // Create JSON representation of the entry
      // Scrub PII from the content before sending
      final scrubbingResult = PrismScrubber.scrubWithMapping(fullText);
      final scrubbedContent = scrubbingResult.scrubbedText;
      
      // Generate summary using scrubbed content
      final result = await _lumaraApi!.generatePromptedReflection(
        entryText: scrubbedContent,
        intent: 'summary',
        phase: null,
        userId: null,
        chatContext: 'Generate a brief 2-3 sentence summary of this journal entry that captures the key points, main topics discussed, and any important insights. Focus on what the user learned or reflected on.',
        onProgress: (msg) => debugPrint('Summary generation: $msg'),
      );
      
      // Restore PII in the returned summary
      final summaryWithPII = PrismScrubber.restore(
        result.reflection,
        scrubbingResult.reversibleMap,
      );
      
      return summaryWithPII;
    } catch (e) {
      debugPrint('Error generating summary: $e');
      return '';
    }
  }
  
  /// End session and generate summary for journal entries
  Future<void> endSessionAndGenerateSummary() async {
    // Save final transcript before clearing - do this first so UI can show it immediately
    String? finalUserText;
    if (_accumulatedTranscript.isNotEmpty) {
      _finalTranscript = _accumulatedTranscript;
      finalUserText = _accumulatedTranscript;
    } else if (_partialTranscript != null && _partialTranscript!.isNotEmpty) {
      _finalTranscript = _partialTranscript;
      finalUserText = _partialTranscript;
    }
    
    // Stop listening to prevent any more updates
    await _audioIO.stopListening();
    
    // Update partial transcript to show final transcript immediately
    _partialTranscript = _finalTranscript;
    if (_finalTranscript != null) {
      _partialTranscriptController.add(_finalTranscript!);
    }
    
    // For journal context: Write any unprocessed user text to journal
    // (text that was spoken but not yet processed via mic button tap)
    if (_context == VoiceContext.journal && finalUserText != null && finalUserText.trim().isNotEmpty) {
      // Check if this text was already written (it would be in _fullConversationText)
      // If not, write it now
      final userTextFormatted = '**You:** $finalUserText\n\n';
      
      // Only write if it's not already in the conversation text
      // (to avoid duplicates if user tapped mic button before ending)
      if (!_fullConversationText.contains(finalUserText.trim())) {
        _onTextWritten?.call(userTextFormatted);
        _fullConversationText += userTextFormatted;
      }
    }
    
    // Generate summary in background (don't block UI)
    // Note: Summary will be prepended when saving via JournalCaptureCubit._generateSummary
    // We don't write it here to avoid appending - it will be prepended during save
    if (_context == VoiceContext.journal && _fullConversationText.isNotEmpty) {
      // Store the full conversation text for summary generation during save
      // The summary will be generated and prepended in JournalCaptureCubit.saveEntryWithKeywords
      // Reset conversation text after storing (summary generation happens during save)
      _fullConversationText = '';
    } else {
      // Reset conversation text immediately if no summary needed
      _fullConversationText = '';
    }
    
    // Reset accumulated transcript for next session
    _accumulatedTranscript = '';
  }

  /// Toggle between Mode A and Mode B
  Future<void> toggleMode() async {
    _useModeA = !_useModeA;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_mode_a', _useModeA);

    // Reinitialize with new mode
    await initialize();
  }
  
  /// Update context and reinitialize orchestrator
  Future<void> updateContext(VoiceContext newContext) async {
    if (_context != newContext) {
      _context = newContext;
      // Recreate orchestrator with new context
      if (_pipeline != null && _lumaraApi != null) {
        final journalManager = JournalManager(captureCubit: _journalCubit);
        final chatManager = MainChatManager(
          assistantCubit: _chatCubit,
          contextProvider: _contextProvider,
        );
        final fileManager = FileManager();
        
        _orchestrator = VoiceOrchestrator(
          pipeline: _pipeline!,
          memory: _memory,
          journal: journalManager,
          chat: chatManager,
          files: fileManager,
          context: _context,
          onTextWritten: (text) {
            // Track full conversation for summary
            _fullConversationText += text;
            // Write to journal view
            _onTextWritten?.call(text);
          },
        );
      }
    }
  }

  /// Get the controller
  PushToTalkController? get controller => _controller;

  /// Get diagnostics
  VoiceDiagnostics get diagnostics => _diagnostics;

  /// Get partial transcript stream
  Stream<String> get partialTranscriptStream => _partialTranscriptController.stream;

  /// Get current partial transcript (or final transcript if session ended)
  String? get partialTranscript => _finalTranscript ?? _partialTranscript;
  
  /// Get attribution traces for a LUMARA response
  List<AttributionTrace>? getAttributionTraces(String responseText) {
    return _orchestrator?.getAttributionTraces(responseText);
  }

  /// Check if Mode A is enabled
  bool get useModeA => _useModeA;

  /// Cleanup
  void dispose() {
    _audioIO.cleanupTempAudio();
    _partialTranscriptController.close();
  }
}

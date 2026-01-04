/// New Voice Journal Service
/// 
/// A fresh implementation of voice journaling with push-to-talk functionality
/// and session summarization using the new VOICE_JOURNAL_MODE and 
/// VOICE_JOURNAL_SUMMARIZATION prompts.
/// 
/// Uses on-device transcription (speech_to_text plugin) - no cloud services required.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../services/firebase_auth_service.dart';
import '../../services/enhanced_lumara_api.dart';
import '../../services/lumara_control_state_builder.dart';
import '../../../core/journal_capture_cubit.dart';
import '../../../core/journal_repository.dart';
import '../../../../services/user_phase_service.dart';
import '../transcription/ondevice_provider.dart';
import '../transcription/transcription_provider.dart';
import '../../../../arc/internal/echo/prism_adapter.dart';
import '../../../../arc/internal/echo/correlation_resistant_transformer.dart';
import 'package:my_app/arc/chat/models/lumara_reflection_options.dart' as lumara_models;
import 'package:my_app/models/journal_entry_model.dart';

/// Voice Journal State
enum VoiceJournalState {
  idle,           // Ready to start
  listening,      // Recording user speech
  transcribing,   // Processing transcription
  scrubbing,      // PRISM scrubbing
  thinking,       // LUMARA generating response
  speaking,       // TTS playing response
  processing,     // General processing state
  error,          // Error occurred
}

/// Voice Journal Turn
class VoiceJournalTurn {
  final String id;
  final String userTranscript;
  final String? lumaraResponse;
  final DateTime timestamp;
  final Map<String, String>? reversibleMap; // For PII restoration
  final CloudPayloadBlock? cloudPayload; // Correlation-resistant payload

  VoiceJournalTurn({
    required this.id,
    required this.userTranscript,
    this.lumaraResponse,
    required this.timestamp,
    this.reversibleMap,
    this.cloudPayload,
  });
}

/// Voice Journal Session
class VoiceJournalSession {
  final String id;
  final DateTime startTime;
  final List<VoiceJournalTurn> turns;
  String? title;
  String? summary;
  String? fullTranscript;

  VoiceJournalSession({
    required this.id,
    required this.startTime,
    this.turns = const [],
    this.title,
    this.summary,
    this.fullTranscript,
  });

  VoiceJournalSession copyWith({
    String? id,
    DateTime? startTime,
    List<VoiceJournalTurn>? turns,
    String? title,
    String? summary,
    String? fullTranscript,
  }) {
    return VoiceJournalSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      turns: turns ?? this.turns,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      fullTranscript: fullTranscript ?? this.fullTranscript,
    );
  }
}

/// Callbacks
typedef OnStateChange = void Function(VoiceJournalState state);
typedef OnTranscriptUpdate = void Function(String transcript);
typedef OnLumaraResponse = void Function(String response);
typedef OnSessionComplete = void Function(VoiceJournalSession session);
typedef OnError = void Function(String error);

/// New Voice Journal Service
/// 
/// Implements push-to-talk voice journaling with:
/// - Real-time on-device transcription (speech_to_text)
/// - PRISM PII scrubbing
/// - Correlation-resistant transformation
/// - LUMARA responses using VOICE_JOURNAL_MODE prompt
/// - Session summarization using VOICE_JOURNAL_SUMMARIZATION prompt
class NewVoiceJournalService {
  final EnhancedLumaraApi _lumaraApi;
  final JournalCaptureCubit? _journalCubit;
  final JournalRepository _journalRepository;
  final PrismAdapter _prism;
  
  // State
  VoiceJournalState _state = VoiceJournalState.idle;
  VoiceJournalState get state => _state;
  
  // Session
  VoiceJournalSession? _currentSession;
  VoiceJournalSession? get currentSession => _currentSession;
  
  // Transcription
  TranscriptionProvider? _transcriptionProvider;
  String _currentTranscript = '';
  List<TranscriptSegment> _transcriptSegments = [];
  
  // Callbacks
  OnStateChange? onStateChange;
  OnTranscriptUpdate? onTranscriptUpdate;
  OnLumaraResponse? onLumaraResponse;
  OnSessionComplete? onSessionComplete;
  OnError? onError;
  
  // Audio level stream
  final StreamController<double> _audioLevelController = 
      StreamController<double>.broadcast();
  Stream<double> get audioLevelStream => _audioLevelController.stream;
  
  bool _isInitialized = false;
  bool _isRecording = false;

  NewVoiceJournalService({
    required EnhancedLumaraApi lumaraApi,
    required JournalRepository journalRepository,
    JournalCaptureCubit? journalCubit,
  })  : _lumaraApi = lumaraApi,
        _journalRepository = journalRepository,
        _journalCubit = journalCubit,
        _prism = PrismAdapter();

  /// Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // Initialize on-device transcription provider
      _transcriptionProvider = OnDeviceTranscriptionProvider();
      await _transcriptionProvider!.initialize();
      
      _isInitialized = true;
      _updateState(VoiceJournalState.idle);
      return true;
    } catch (e) {
      debugPrint('NewVoiceJournalService: Error initializing: $e');
      _updateState(VoiceJournalState.error);
      onError?.call('Failed to initialize: $e');
      return false;
    }
  }

  /// Start a new session
  Future<void> startSession() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    _currentSession = VoiceJournalSession(
      id: const Uuid().v4(),
      startTime: DateTime.now(),
    );
    
    _updateState(VoiceJournalState.idle);
  }

  /// Start listening (push-to-talk pressed)
  Future<void> startListening() async {
    if (_state != VoiceJournalState.idle && _state != VoiceJournalState.speaking) {
      return;
    }
    
    if (_currentSession == null) {
      await startSession();
    }
    
    try {
      _isRecording = true;
      _currentTranscript = '';
      _transcriptSegments = [];
      _updateState(VoiceJournalState.listening);
      
      // Start transcription
      await _transcriptionProvider!.startListening(
        onPartialResult: (segment) {
          _transcriptSegments.add(segment);
          _currentTranscript = _transcriptSegments
              .where((s) => s.isFinal)
              .map((s) => s.text)
              .join(' ');
          if (!segment.isFinal) {
            _currentTranscript += ' ${segment.text}';
          }
          onTranscriptUpdate?.call(_currentTranscript);
        },
        onFinalResult: (segment) {
          _transcriptSegments.add(segment);
          _currentTranscript = _transcriptSegments
              .where((s) => s.isFinal)
              .map((s) => s.text)
              .join(' ');
          onTranscriptUpdate?.call(_currentTranscript);
        },
        onError: (error) {
          debugPrint('NewVoiceJournalService: Transcription error: $error');
          onError?.call('Transcription error: $error');
        },
        onSoundLevel: (level) {
          _audioLevelController.add(level);
        },
      );
    } catch (e) {
      debugPrint('NewVoiceJournalService: Error starting listening: $e');
      _updateState(VoiceJournalState.error);
      onError?.call('Failed to start listening: $e');
    }
  }

  /// Stop listening and process (push-to-talk released)
  Future<void> stopListeningAndProcess() async {
    if (!_isRecording) return;
    
    try {
      _isRecording = false;
      
      // Stop transcription
      await _transcriptionProvider!.stopListening();
      
      // Get final transcript from segments
      _currentTranscript = _transcriptSegments
          .where((s) => s.isFinal)
          .map((s) => s.text)
          .join(' ')
          .trim();
      
      if (_currentTranscript.trim().isEmpty) {
        _updateState(VoiceJournalState.idle);
        return;
      }
      
      // Process the turn
      await _processTurn(_currentTranscript);
    } catch (e) {
      debugPrint('NewVoiceJournalService: Error stopping listening: $e');
      _updateState(VoiceJournalState.error);
      onError?.call('Failed to process: $e');
    }
  }

  /// Process a user turn
  Future<void> _processTurn(String rawTranscript) async {
    try {
      _updateState(VoiceJournalState.transcribing);
      
      // Step 1: PRISM Scrubbing
      _updateState(VoiceJournalState.scrubbing);
      final prismResult = _prism.scrub(rawTranscript);
      
      if (!_prism.isSafeToSend(prismResult.scrubbedText)) {
        throw Exception('PII still detected after scrubbing');
      }
      
      // Step 2: Correlation-Resistant Transformation
      final transformationResult = await _prism.transformToCorrelationResistant(
        prismScrubbedText: prismResult.scrubbedText,
        intent: 'voice_journal',
        prismResult: prismResult,
        rotationWindow: RotationWindow.session,
      );
      
      // Step 3: Generate LUMARA response using VOICE_JOURNAL_MODE prompt
      _updateState(VoiceJournalState.thinking);
      final lumaraResponse = await _generateLumaraResponse(
        transformationResult.cloudPayloadBlock,
        transformationResult.localAuditBlock,
      );
      
      // Step 4: Restore PII in response
      final restoredResponse = _prism.restore(
        lumaraResponse,
        prismResult.reversibleMap,
      );
      
      // Step 5: Save turn
      final turn = VoiceJournalTurn(
        id: const Uuid().v4(),
        userTranscript: rawTranscript,
        lumaraResponse: restoredResponse,
        timestamp: DateTime.now(),
        reversibleMap: prismResult.reversibleMap,
        cloudPayload: transformationResult.cloudPayloadBlock,
      );
      
      _currentSession = _currentSession!.copyWith(
        turns: [..._currentSession!.turns, turn],
      );
      
      onLumaraResponse?.call(restoredResponse);
      
      // Step 6: Play TTS (if needed)
      // TODO: Implement TTS playback
      
      _updateState(VoiceJournalState.idle);
    } catch (e) {
      debugPrint('NewVoiceJournalService: Error processing turn: $e');
      _updateState(VoiceJournalState.error);
      onError?.call('Failed to process turn: $e');
    }
  }

  /// Generate LUMARA response using VOICE_JOURNAL_MODE prompt
  Future<String> _generateLumaraResponse(
    CloudPayloadBlock cloudPayload,
    LocalAuditBlock localAudit,
  ) async {
    try {
      // Get user ID
      final userId = FirebaseAuthService().currentUser?.uid;
      
      // Get current phase
      final currentPhase = await UserPhaseService.getCurrentPhase();
      
      // Build control state
      final controlStateJson = await LumaraControlStateBuilder.buildControlState(
        userId: userId,
        prismActivity: {
          'journal_entries': [],
          'chats': [],
          'media': [],
          'patterns': [],
          'emotional_tone': 'neutral',
          'cognitive_load': 'moderate',
        },
        chronoContext: null,
        userMessage: cloudPayload.semanticSummary,
      );
      
      // Build VOICE_JOURNAL_MODE system prompt
      final systemPrompt = _buildVoiceJournalModePrompt(controlStateJson);
      
      // Build user prompt from cloud payload
      final userPrompt = _buildUserPromptFromPayload(cloudPayload);
      
      // Generate response
      final result = await _lumaraApi.generatePromptedReflection(
        entryText: userPrompt,
        intent: 'voice_journal',
        phase: currentPhase,
        userId: userId,
        includeExpansionQuestions: false,
        mood: null,
        chronoContext: null,
        chatContext: systemPrompt,
        mediaContext: null,
        entryId: null,
        options: lumara_models.LumaraReflectionOptions(
          preferQuestionExpansion: false,
          toneMode: lumara_models.ToneMode.normal,
          regenerate: false,
        ),
        onProgress: (message) {
          // Silent progress
        },
      );
      
      return result.reflection;
    } catch (e) {
      debugPrint('NewVoiceJournalService: Error generating LUMARA response: $e');
      rethrow;
    }
  }

  /// Build VOICE_JOURNAL_MODE system prompt
  String _buildVoiceJournalModePrompt(String controlStateJson) {
    return '''[VOICE_JOURNAL_MODE]

You are LUMARA in Voice Journal mode—a real-time conversational interface for reflective journaling.

INTERACTION MODEL:
- User speaks by pressing and holding a button, releases to hear your response
- This is spoken dialogue: responses should be natural, conversational, appropriately brief
- Typical response length: 2-4 sentences. Match the weight of what the user shared.
- Let the conversation breathe. Not every exchange needs a follow-up question.

VOICE-SPECIFIC ADAPTATIONS:
- Your responses will be synthesized to speech. Write for the ear, not the eye.
- Avoid lists, bullet points, numbered items—anything that sounds like written text
- Use natural spoken transitions ("That connects to something you mentioned earlier..." not "Additionally,...")
- Contractions are good. Sentence fragments are fine when natural.
- Avoid filler acknowledgments ("I hear you," "That makes sense")—just respond substantively

CONVERSATION FLOW:
- Each turn is a discrete exchange. The user controls pacing via the push-to-talk button.
- Don't summarize or wrap up prematurely—follow the user's lead
- When the user seems to be winding down naturally, acknowledge that gently without forcing closure
- If content seems sparse or fragmented, the user may still be formulating thoughts—respond to what's there

INPUT FORMAT:
- You receive structured CloudPayloadBlock JSON, not verbatim transcription
- Entities appear as rotating aliases: PERSON(H:xxx, S:symbol), ORG(H:xxx, S:symbol), LOC(H:xxx, S:symbol)
- Work with the semantic_summary and themes fields for meaning
- Reference entities by their alias naturally ("the person you mentioned," "that situation at work")

RESPONSE GENERATION:
- Apply current Engagement Mode (REFLECT/EXPLORE/INTEGRATE) from Control State
- Apply current Persona from Control State  
- Respect max_temporal_connections, max_explorative_questions, and language boundary settings
- Honor protected domains—do not synthesize across them even if thematically relevant

SESSION CONTEXT:
- The user will end the session by pressing a stop button
- The full conversation will then be processed into a journal entry with title and summary
- Your role during conversation is presence and engagement, not documentation

UNIFIED CONTROL STATE:
$controlStateJson
''';
  }

  /// Build user prompt from cloud payload
  String _buildUserPromptFromPayload(CloudPayloadBlock payload) {
    final buffer = StringBuffer();
    
    buffer.writeln('Semantic Summary: ${payload.semanticSummary}');
    buffer.writeln('Themes: ${payload.themes.join(", ")}');
    
    if (payload.entities.isNotEmpty) {
      buffer.writeln('Entities:');
      payload.entities.forEach((type, entities) {
        buffer.writeln('  $type: ${entities.join(", ")}');
      });
    }
    
    if (payload.constraints.isNotEmpty) {
      buffer.writeln('Constraints: ${payload.constraints.join(", ")}');
    }
    
    return buffer.toString();
  }

  /// End session and generate summary
  Future<VoiceJournalSession> endSessionAndSummarize() async {
    if (_currentSession == null || _currentSession!.turns.isEmpty) {
      throw Exception('No active session or no turns to summarize');
    }
    
    try {
      _updateState(VoiceJournalState.processing);
      
      // Generate summary using VOICE_JOURNAL_SUMMARIZATION prompt
      final summaryResult = await _generateSessionSummary(_currentSession!);
      
      // Update session with title and summary
      _currentSession = _currentSession!.copyWith(
        title: summaryResult['title'],
        summary: summaryResult['summary'],
        fullTranscript: summaryResult['transcript'],
      );
      
      onSessionComplete?.call(_currentSession!);
      
      _updateState(VoiceJournalState.idle);
      return _currentSession!;
    } catch (e) {
      debugPrint('NewVoiceJournalService: Error summarizing session: $e');
      _updateState(VoiceJournalState.error);
      onError?.call('Failed to summarize session: $e');
      rethrow;
    }
  }

  /// Generate session summary using VOICE_JOURNAL_SUMMARIZATION prompt
  Future<Map<String, String>> _generateSessionSummary(VoiceJournalSession session) async {
    try {
      // Build conversation transcript
      final transcriptBuffer = StringBuffer();
      for (final turn in session.turns) {
        transcriptBuffer.writeln('User: ${turn.userTranscript}');
        if (turn.lumaraResponse != null) {
          transcriptBuffer.writeln('LUMARA: ${turn.lumaraResponse}');
        }
      }
      
      // Build metadata
      final duration = DateTime.now().difference(session.startTime);
      
      // Get user ID and phase
      final userId = FirebaseAuthService().currentUser?.uid;
      final currentPhase = await UserPhaseService.getCurrentPhase();
      
      // Build summarization prompt
      final systemPrompt = '''[VOICE_JOURNAL_SUMMARIZATION]

You are processing a completed Voice Journal conversation to create a journal entry.

INPUT:
- Full conversation transcript (user turns + LUMARA responses)
- Entities as rotating aliases: PERSON(H:xxx, S:symbol), ORG(H:xxx, S:symbol), LOC(H:xxx, S:symbol)
- Conversation metadata (duration, turn count, timestamps)

OUTPUT REQUIREMENTS:

1. TITLE (required)
   - 3-8 words capturing the core subject or theme
   - Should read naturally as a journal entry title
   - Use the user's framing, not clinical language
   - Examples: "Processing the promotion decision" / "Feeling stuck on the project" / "Reconnecting after the argument"

2. SUMMARY (required)
   - 1-3 sentences prepended to the top of the entry
   - Captures the arc of the conversation: what was explored, any shifts or realizations
   - Written in third-person perspective about the user ("Explored feelings about..." not "You explored...")
   - Should orient a future reader (including the user) to what this entry contains

3. TRANSCRIPT (required)
   - Detailed but not verbatim—capture the substance of each exchange
   - Preserve the user's language and framing where meaningful
   - Clean up speech artifacts (um, uh, false starts, repetitions)
   - Maintain conversational flow and emotional texture
   - Format as natural paragraphs, not turn-by-turn dialogue
   - Integrate LUMARA's contributions naturally ("After reflecting on X, the realization emerged that...")

FORMATTING:
[TITLE]
{generated title}
[SUMMARY]
{1-3 sentence overview}
[ENTRY]
{detailed narrative transcript}

GUIDANCE:
- The entry should read as a coherent reflection, not a chat log
- Preserve emotional honesty—don't sanitize or uplift artificially
- If the conversation wandered across topics, the title should reflect the dominant thread
- If no clear resolution emerged, that's fine—reflect the open-endedness
- Reference entities by natural descriptors ("a colleague," "the situation at home") not aliases
''';
      
      final userPrompt = '''Conversation Transcript:
${transcriptBuffer.toString()}

Metadata:
- Duration: ${duration.inSeconds} seconds
- Turns: ${session.turns.length}
- Start Time: ${session.startTime.toIso8601String()}

Generate the title, summary, and transcript following the format specified.''';
      
      // Generate summary
      final result = await _lumaraApi.generatePromptedReflection(
        entryText: userPrompt,
        intent: 'voice_journal_summarization',
        phase: currentPhase,
        userId: userId,
        includeExpansionQuestions: false,
        mood: null,
        chronoContext: null,
        chatContext: systemPrompt,
        mediaContext: null,
        entryId: null,
        options: lumara_models.LumaraReflectionOptions(
          preferQuestionExpansion: false,
          toneMode: lumara_models.ToneMode.normal,
          regenerate: false,
        ),
        onProgress: (message) {
          // Silent progress
        },
      );
      
      // Parse response
      final response = result.reflection;
      final title = _extractSection(response, 'TITLE');
      final summary = _extractSection(response, 'SUMMARY');
      final transcript = _extractSection(response, 'ENTRY');
      
      return {
        'title': title ?? 'Voice Journal Entry',
        'summary': summary ?? '',
        'transcript': transcript ?? response,
      };
    } catch (e) {
      debugPrint('NewVoiceJournalService: Error generating summary: $e');
      rethrow;
    }
  }

  /// Extract section from formatted response
  String? _extractSection(String response, String section) {
    final pattern = RegExp('\\[$section\\]\\s*(.*?)(?=\\[|\\\$)', dotAll: true);
    final match = pattern.firstMatch(response);
    return match?.group(1)?.trim();
  }

  /// Save session as journal entry
  Future<String?> saveSessionAsEntry() async {
    if (_currentSession == null) {
      return null;
    }
    
    try {
      final session = _currentSession!;
      
      // Use journal capture cubit if available
      if (_journalCubit != null) {
        _journalCubit!.saveEntryWithKeywords(
          content: session.fullTranscript ?? '',
          mood: 'neutral',
          selectedKeywords: [], // Could extract from themes
          title: session.title,
        );
        
        // Add overview if summary exists
        if (session.summary != null && session.summary!.isNotEmpty) {
          // The overview will be set via the entry's overview field
          // This is handled in the saveEntryWithKeywords method
        }
      } else {
        // Direct repository save
        final entry = JournalEntry(
          id: const Uuid().v4(),
          title: session.title ?? 'Voice Journal Entry',
          content: session.fullTranscript ?? '',
          createdAt: session.startTime,
          updatedAt: DateTime.now(),
          tags: const [],
          mood: 'neutral',
          keywords: [],
          overview: session.summary,
        );
        
        await _journalRepository.createJournalEntry(entry);
      }
      
      return session.id;
    } catch (e) {
      debugPrint('NewVoiceJournalService: Error saving entry: $e');
      onError?.call('Failed to save entry: $e');
      return null;
    }
  }

  /// Update state and notify listeners
  void _updateState(VoiceJournalState newState) {
    _state = newState;
    onStateChange?.call(newState);
  }

  /// Dispose resources
  void dispose() {
    _transcriptionProvider?.stopListening();
    _audioLevelController.close();
  }
}


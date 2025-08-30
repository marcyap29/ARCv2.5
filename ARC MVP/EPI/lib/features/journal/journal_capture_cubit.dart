import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/journal/journal_capture_state.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/repositories/journal_repository.dart';
import 'package:my_app/features/journal/sage_annotation_model.dart';
import 'package:my_app/models/arcform_snapshot_model.dart';
import 'package:my_app/features/arcforms/arcform_mvp_implementation.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hive/hive.dart';

class JournalCaptureCubit extends Cubit<JournalCaptureState> {
  final JournalRepository _journalRepository;
  String _draftContent = '';
  static const _autoSaveDelay = Duration(seconds: 3);
  DateTime? _lastSaveTime;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isPlaying = false;
  String? _audioPath;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  String? _transcription;

  JournalCaptureCubit(this._journalRepository) : super(JournalCaptureInitial());

  void updateDraft(String content) {
    _draftContent = content;
    _autoSaveDraft();
  }

  void _autoSaveDraft() {
    // Auto-save after delay if content has changed
    if (_lastSaveTime == null ||
        DateTime.now().difference(_lastSaveTime!) > _autoSaveDelay) {
      _lastSaveTime = DateTime.now();
      // In a real implementation, we would save to a drafts repository
      // For now, we just update the state to indicate draft saved
      emit(JournalCaptureDraftSaved());
    }
  }

  void saveEntry({required String content, required String mood}) async {
    try {
      // Extract keywords using ARC MVP keyword extractor
      final keywords = SimpleKeywordExtractor.extractKeywords(content);
      
      final now = DateTime.now();
      final entry = JournalEntry(
        id: const Uuid().v4(),
        title: _generateTitle(content),
        content: content,
        createdAt: now,
        updatedAt: now,
        tags: const [], // Tags could be extracted from content in a more advanced implementation
        mood: mood,
        audioUri: _audioPath,
        keywords: keywords, // Now populated with extracted keywords
      );

      // Save the entry first
      await _journalRepository.createJournalEntry(entry);

      // Process SAGE annotation in background
      _processSAGEAnnotation(entry);

      // Create Arcform using ARC MVP service
      _createArcformSnapshot(entry);

      emit(JournalCaptureSaved());
    } catch (e) {
      emit(JournalCaptureError('Failed to save entry: ${e.toString()}'));
    }
  }

  void _processSAGEAnnotation(JournalEntry entry) async {
    try {
      // In a real implementation, this would call an AI service
      // For now, we'll simulate the processing with a delay
      await Future.delayed(const Duration(seconds: 2));

      // Generate simulated SAGE annotation
      const annotation = SAGEAnnotation(
        situation:
            "User described a situation involving work challenges and personal reflection",
        action:
            "User took time to write in their journal and reflect on their experiences",
        growth:
            "User is developing self-awareness and emotional processing skills",
        essence:
            "The core of this entry is about personal growth through self-reflection",
        confidence: 0.85,
      );

      // Update the entry with the annotation
      final updatedEntry = entry.copyWith(sageAnnotation: annotation);
      await _journalRepository.updateJournalEntry(updatedEntry);
    } catch (e) {
      // Silently fail if SAGE processing fails - it's not critical
      print('SAGE annotation failed: $e');
    }
  }

  void _createArcformSnapshot(JournalEntry entry) async {
    try {
      // Create Arcform using the ARC MVP service
      final arcformService = ArcformMVPService();
      final arcform = arcformService.createArcformFromEntry(
        entryId: entry.id,
        title: entry.title,
        content: entry.content,
        mood: entry.mood,
        keywords: entry.keywords,
      );

      // Save to SimpleArcformStorage (in-memory for now)
      SimpleArcformStorage.saveArcform(arcform);

      // Also save as ArcformSnapshot for backward compatibility
      final snapshot = ArcformSnapshot(
        id: const Uuid().v4(),
        arcformId: entry.id,
        data: {
          'keywords': arcform.keywords,
          'geometry': arcform.geometry.name,
          'colorMap': arcform.colorMap,
          'edges': arcform.edges,
          'phaseHint': arcform.phaseHint,
        },
        timestamp: arcform.createdAt,
        notes: 'Generated from journal entry using ARC MVP',
      );

      // Save the snapshot to Hive
      final snapshotBox = await Hive.openBox<ArcformSnapshot>('arcform_snapshots');
      await snapshotBox.put(snapshot.id, snapshot);
      
      print('Arcform created: ${arcform.geometry.name} with ${arcform.keywords.length} keywords');
    } catch (e) {
      print('Arcform snapshot creation failed: $e');
    }
  }

  String _generateTitle(String content) {
    // Simple title generation from first few words
    final words = content.split(' ');
    if (words.isEmpty) return 'Untitled';

    final titleWords = words.take(3);
    return '${titleWords.join(' ')}${words.length > 3 ? '...' : ''}';
  }

  // Audio recording methods
  Future<void> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      emit(JournalCapturePermissionGranted());
    } else {
      emit(const JournalCapturePermissionDenied(
          'Microphone permission is required to record audio.'));
    }
  }

  Future<void> startRecording() async {
    try {
      if (!_isRecording) {
        final status = await Permission.microphone.status;
        if (!status.isGranted) {
          emit(const JournalCapturePermissionDenied(
              'Microphone permission is required to record audio.'));
          return;
        }

        final tempDir = await getTemporaryDirectory();
        _audioPath = '${tempDir.path}/${const Uuid().v4()}.m4a';

        // In a real implementation, you would use a proper audio recording package
        // For now, we'll simulate the recording process
        _isRecording = true;
        _isPaused = false;
        _recordingDuration = Duration.zero;

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _recordingDuration += const Duration(seconds: 1);
          emit(JournalCaptureRecording(recordingDuration: _recordingDuration));
        });

        emit(JournalCaptureRecording(recordingDuration: _recordingDuration));
      }
    } catch (e) {
      emit(JournalCaptureError('Failed to start recording: ${e.toString()}'));
    }
  }

  Future<void> pauseRecording() async {
    try {
      if (_isRecording && !_isPaused) {
        // In a real implementation, you would pause the actual recording
        _isPaused = true;
        _recordingTimer?.cancel();
        emit(JournalCaptureRecordingPaused(
            recordingDuration: _recordingDuration));
      }
    } catch (e) {
      emit(JournalCaptureError('Failed to pause recording: ${e.toString()}'));
    }
  }

  Future<void> stopRecording() async {
    try {
      if (_isRecording) {
        // In a real implementation, you would stop the actual recording
        _isRecording = false;
        _isPaused = false;
        _recordingTimer?.cancel();
        emit(JournalCaptureRecordingStopped(
            recordingDuration: _recordingDuration, audioPath: _audioPath!));
      }
    } catch (e) {
      emit(JournalCaptureError('Failed to stop recording: ${e.toString()}'));
    }
  }

  Future<void> playRecording() async {
    try {
      if (_audioPath != null) {
        _isPlaying = true;
        emit(JournalCapturePlaying());
        // In a real implementation, you would play the actual audio file
        // For now, we'll simulate playback
        await Future.delayed(const Duration(seconds: 3));
        _isPlaying = false;
        emit(JournalCapturePlaybackStopped());
      }
    } catch (e) {
      _isPlaying = false;
      emit(JournalCaptureError('Failed to play recording: ${e.toString()}'));
    }
  }

  Future<void> stopPlayback() async {
    try {
      // In a real implementation, you would stop the actual playback
      _isPlaying = false;
      emit(JournalCapturePlaybackStopped());
    } catch (e) {
      emit(JournalCaptureError('Failed to stop playback: ${e.toString()}'));
    }
  }

  Future<void> transcribeAudio() async {
    try {
      if (_audioPath == null) {
        emit(const JournalCaptureError('No audio recording found'));
        return;
      }

      emit(JournalCaptureTranscribing());

      // In a real implementation, you would call an actual transcription service
      // For this example, we'll simulate transcription with a delay
      await Future.delayed(const Duration(seconds: 2));

      // Simulated transcription result
      _transcription =
          "This is a simulated transcription of your voice journal entry. In a real implementation, this would be the actual transcription from a service like OpenAI's Whisper API.";

      emit(JournalCaptureTranscribed(transcription: _transcription!));
    } catch (e) {
      emit(JournalCaptureError('Failed to transcribe audio: ${e.toString()}'));
    }
  }

  void updateTranscription(String transcription) {
    _transcription = transcription;
  }

  String? get transcription => _transcription;

  @override
  Future<void> close() {
    _recordingTimer?.cancel();
    _audioPlayer.dispose();
    return super.close();
  }
}

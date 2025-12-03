import 'package:equatable/equatable.dart';
import 'package:my_app/core/services/draft_cache_service.dart';
import 'package:my_app/core/services/journal_version_service.dart';
import 'package:my_app/data/models/media_item.dart';

abstract class JournalCaptureState extends Equatable {
  const JournalCaptureState();

  @override
  List<Object> get props => [];
}

class JournalCaptureInitial extends JournalCaptureState {}

class JournalCaptureDraftSaved extends JournalCaptureState {}

class JournalCaptureSaved extends JournalCaptureState {}

class JournalCaptureError extends JournalCaptureState {
  final String message;

  const JournalCaptureError(this.message);

  @override
  List<Object> get props => [message];
}

// Add missing state classes for audio functionality
class JournalCapturePermissionGranted extends JournalCaptureState {}

class JournalCapturePermissionDenied extends JournalCaptureState {
  final String message;

  const JournalCapturePermissionDenied(this.message);

  @override
  List<Object> get props => [message];
}

class JournalCaptureRecording extends JournalCaptureState {
  final Duration recordingDuration;

  const JournalCaptureRecording({required this.recordingDuration});

  @override
  List<Object> get props => [recordingDuration];
}

class JournalCaptureRecordingPaused extends JournalCaptureState {
  final Duration recordingDuration;

  const JournalCaptureRecordingPaused({required this.recordingDuration});

  @override
  List<Object> get props => [recordingDuration];
}

class JournalCaptureRecordingStopped extends JournalCaptureState {
  final Duration recordingDuration;
  final String audioPath;

  const JournalCaptureRecordingStopped({
    required this.recordingDuration,
    required this.audioPath,
  });

  @override
  List<Object> get props => [recordingDuration, audioPath];
}

class JournalCapturePlaying extends JournalCaptureState {}

class JournalCapturePlaybackStopped extends JournalCaptureState {}

class JournalCaptureTranscribing extends JournalCaptureState {}

class JournalCaptureTranscribed extends JournalCaptureState {
  final String transcription;

  const JournalCaptureTranscribed({required this.transcription});

  @override
  List<Object> get props => [transcription];
}


// Draft-related states
class JournalCaptureDraftRecoverable extends JournalCaptureState {
  final JournalDraft recoverableDraft;

  const JournalCaptureDraftRecoverable({
    required this.recoverableDraft,
  });

  @override
  List<Object> get props => [recoverableDraft];
}

class JournalCaptureDraftStarted extends JournalCaptureState {
  final String draftId;

  const JournalCaptureDraftStarted({
    required this.draftId,
  });

  @override
  List<Object> get props => [draftId];
}

class JournalCaptureDraftRestored extends JournalCaptureState {
  final JournalDraft draft;
  final String content;
  final List<MediaItem> mediaItems;

  const JournalCaptureDraftRestored({
    required this.draft,
    required this.content,
    required this.mediaItems,
  });

  @override
  List<Object> get props => [draft, content, mediaItems];
}

class JournalCaptureDraftDiscarded extends JournalCaptureState {}

class JournalCaptureMediaAdded extends JournalCaptureState {
  final MediaItem mediaItem;

  const JournalCaptureMediaAdded({
    required this.mediaItem,
  });

  @override
  List<Object> get props => [mediaItem];
}

class JournalCaptureMediaRemoved extends JournalCaptureState {
  final MediaItem mediaItem;

  const JournalCaptureMediaRemoved({
    required this.mediaItem,
  });

  @override
  List<Object> get props => [mediaItem];
}

class JournalCaptureConflictDetected extends JournalCaptureState {
  final ConflictInfo conflict;

  const JournalCaptureConflictDetected({
    required this.conflict,
  });

  @override
  List<Object> get props => [conflict];
}

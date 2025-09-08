import 'package:equatable/equatable.dart';
import 'package:my_app/mode/first_responder/fr_settings_cubit.dart';

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

class JournalCaptureFRSuggestionTriggered extends JournalCaptureState {
  final String draftContent;
  final FRSettingsCubit frCubit;

  const JournalCaptureFRSuggestionTriggered({
    required this.draftContent,
    required this.frCubit,
  });

  @override
  List<Object> get props => [draftContent, frCubit];
}

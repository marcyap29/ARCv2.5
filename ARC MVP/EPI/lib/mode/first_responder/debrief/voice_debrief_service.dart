import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:record/record.dart';  // Temporarily disabled
import 'package:path/path.dart' as path;
import 'package:my_app/arc/chat/llm/bridge.pigeon.dart';

/// P28: Voice Debrief Service
/// Handles voice recording, transcription, and storage for debrief sessions
class VoiceDebriefService {
  static final VoiceDebriefService _instance = VoiceDebriefService._internal();
  factory VoiceDebriefService() => _instance;
  VoiceDebriefService._internal();

  // final AudioRecorder _recorder = AudioRecorder();  // Temporarily disabled
  final bool _isRecording = false;
  StreamController<RecordingState>? _recordingStateController;
  Timer? _recordingTimer;

  /// Get recording state stream
  Stream<RecordingState> get recordingStateStream {
    _recordingStateController ??= StreamController<RecordingState>.broadcast();
    return _recordingStateController!.stream;
  }

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Get current recording duration
  Duration get currentDuration => Duration.zero; // Temporarily disabled

  /// Start voice recording
  Future<bool> startRecording({String? fileName}) async {
    // Temporarily disabled due to record package version conflicts
    debugPrint('Voice recording temporarily disabled');
    return false;
    
    /* Original implementation commented out:
    try {
      // Check microphone permission
      final permission = await Permission.microphone.request();
      if (permission != PermissionStatus.granted) {
        throw Exception('Microphone permission denied');
      }

      // Check if already recording
      if (_isRecording) {
        throw Exception('Already recording');
      }

      // Get recording directory
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory(path.join(directory.path, 'debrief_recordings'));
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      // Generate filename if not provided
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final finalFileName = fileName ?? 'debrief_$timestamp.m4a';
      _currentRecordingPath = path.join(recordingsDir.path, finalFileName);

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _startRecordingTimer();
      _recordingStateController?.add(RecordingState.recording);

      return true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _recordingStateController?.add(RecordingState.error);
      return false;
    }
    */
  }

  /// Stop voice recording
  Future<VoiceRecording?> stopRecording() async {
    // Temporarily disabled due to record package version conflicts
    debugPrint('Voice recording temporarily disabled');
    return null;
  }

  /// Pause recording
  Future<bool> pauseRecording() async {
    // Temporarily disabled due to record package version conflicts
    debugPrint('Voice recording temporarily disabled');
    return false;
  }

  /// Resume recording
  Future<bool> resumeRecording() async {
    // Temporarily disabled due to record package version conflicts
    debugPrint('Voice recording temporarily disabled');
    return false;
  }

  /// Cancel current recording
  Future<bool> cancelRecording() async {
    // Temporarily disabled due to record package version conflicts
    debugPrint('Voice recording temporarily disabled');
    return false;
  }

  /// Get all saved recordings
  Future<List<VoiceRecording>> getAllRecordings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory(path.join(directory.path, 'debrief_recordings'));
      
      if (!await recordingsDir.exists()) {
        return [];
      }

      final files = await recordingsDir.list().toList();
      final recordings = <VoiceRecording>[];

      for (final file in files) {
        if (file is File && file.path.endsWith('.m4a')) {
          final stat = await file.stat();
          recordings.add(VoiceRecording(
            id: path.basenameWithoutExtension(file.path),
            filePath: file.path,
            fileName: path.basename(file.path),
            duration: Duration.zero, // Would need to extract from file metadata
            fileSize: stat.size,
            createdAt: stat.modified,
          ));
        }
      }

      // Sort by creation date (newest first)
      recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return recordings;
    } catch (e) {
      debugPrint('Error getting recordings: $e');
      return [];
    }
  }

  /// Delete a recording
  Future<bool> deleteRecording(String recordingId) async {
    try {
      final recordings = await getAllRecordings();
      final recording = recordings.firstWhere(
        (r) => r.id == recordingId,
        orElse: () => throw Exception('Recording not found'),
      );

      final file = File(recording.filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting recording: $e');
      return false;
    }
  }

  /// Transcribe audio file using native bridge
  Future<String?> transcribeAudio(String filePath) async {
    try {
      // TODO: Implement native transcription bridge method
      // For now, return a placeholder message
      debugPrint('Native transcription not yet implemented, using placeholder');
      return 'Audio transcription not yet implemented. Audio file saved at: $filePath';
    } catch (e) {
      debugPrint('Error transcribing audio: $e');
      // Fallback message if native transcription fails
      return 'Audio transcription failed. Audio file saved at: $filePath';
    }
  }

  /// Get recording statistics
  Future<VoiceRecordingStatistics> getStatistics() async {
    try {
      final recordings = await getAllRecordings();
      
      if (recordings.isEmpty) {
        return const VoiceRecordingStatistics(
          totalRecordings: 0,
          totalDuration: Duration.zero,
          totalFileSize: 0,
          averageDuration: Duration.zero,
        );
      }

      final totalDuration = recordings.fold<Duration>(
        Duration.zero,
        (sum, recording) => sum + recording.duration,
      );

      final totalFileSize = recordings.fold<int>(
        0,
        (sum, recording) => sum + recording.fileSize,
      );

      final averageDuration = Duration(
        milliseconds: totalDuration.inMilliseconds ~/ recordings.length,
      );

      return VoiceRecordingStatistics(
        totalRecordings: recordings.length,
        totalDuration: totalDuration,
        totalFileSize: totalFileSize,
        averageDuration: averageDuration,
      );
    } catch (e) {
      debugPrint('Error getting statistics: $e');
      return const VoiceRecordingStatistics(
        totalRecordings: 0,
        totalDuration: Duration.zero,
        totalFileSize: 0,
        averageDuration: Duration.zero,
      );
    }
  }

  /// Dispose resources
  void dispose() {
    _recordingStateController?.close();
    _recordingTimer?.cancel();
    // _recorder.dispose(); // Temporarily disabled
  }


}

/// Recording states
enum RecordingState {
  idle,
  recording,
  paused,
  stopped,
  cancelled,
  error,
}

/// Voice recording model
class VoiceRecording {
  final String id;
  final String filePath;
  final String fileName;
  final Duration duration;
  final int fileSize;
  final DateTime createdAt;
  final String? transcription;
  final String? debriefStepId; // Which debrief step this recording belongs to

  const VoiceRecording({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.duration,
    required this.fileSize,
    required this.createdAt,
    this.transcription,
    this.debriefStepId,
  });

  VoiceRecording copyWith({
    String? id,
    String? filePath,
    String? fileName,
    Duration? duration,
    int? fileSize,
    DateTime? createdAt,
    String? transcription,
    String? debriefStepId,
  }) {
    return VoiceRecording(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      transcription: transcription ?? this.transcription,
      debriefStepId: debriefStepId ?? this.debriefStepId,
    );
  }

  /// Get formatted file size
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '${fileSize}B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }

  /// Get formatted duration
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Voice recording statistics
class VoiceRecordingStatistics {
  final int totalRecordings;
  final Duration totalDuration;
  final int totalFileSize;
  final Duration averageDuration;

  const VoiceRecordingStatistics({
    required this.totalRecordings,
    required this.totalDuration,
    required this.totalFileSize,
    required this.averageDuration,
  });

  /// Get formatted total duration
  String get formattedTotalDuration {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Get formatted total file size
  String get formattedTotalFileSize {
    if (totalFileSize < 1024 * 1024) {
      return '${(totalFileSize / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(totalFileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
}

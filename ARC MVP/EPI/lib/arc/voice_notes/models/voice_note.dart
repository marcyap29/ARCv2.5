import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'voice_note.g.dart';

/// Represents a quick voice capture saved to the Ideas inbox.
/// These are transcribed voice notes that can later be converted to journal entries
/// or used as quick thought captures.
@HiveType(typeId: 120)
class VoiceNote extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final String transcription;

  @HiveField(3)
  final List<String> tags;

  @HiveField(4)
  final bool archived;

  @HiveField(5)
  final bool convertedToJournal;

  @HiveField(6)
  final String? convertedEntryId; // ID of journal entry if converted

  @HiveField(7)
  final int? durationMs; // Original audio duration in milliseconds

  const VoiceNote({
    required this.id,
    required this.timestamp,
    required this.transcription,
    this.tags = const [],
    this.archived = false,
    this.convertedToJournal = false,
    this.convertedEntryId,
    this.durationMs,
  });

  /// Create a new voice note with generated ID
  factory VoiceNote.create({
    required String transcription,
    List<String> tags = const [],
    int? durationMs,
  }) {
    return VoiceNote(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      transcription: transcription,
      tags: tags,
      durationMs: durationMs,
    );
  }

  /// Create a copy with updated fields
  VoiceNote copyWith({
    String? id,
    DateTime? timestamp,
    String? transcription,
    List<String>? tags,
    bool? archived,
    bool? convertedToJournal,
    String? convertedEntryId,
    int? durationMs,
  }) {
    return VoiceNote(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      transcription: transcription ?? this.transcription,
      tags: tags ?? this.tags,
      archived: archived ?? this.archived,
      convertedToJournal: convertedToJournal ?? this.convertedToJournal,
      convertedEntryId: convertedEntryId ?? this.convertedEntryId,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  /// Mark as archived
  VoiceNote archive() => copyWith(archived: true);

  /// Mark as converted to journal entry
  VoiceNote markConverted(String entryId) => copyWith(
        convertedToJournal: true,
        convertedEntryId: entryId,
      );

  /// Get a preview of the transcription (first 100 chars)
  String get preview {
    if (transcription.length <= 100) return transcription;
    return '${transcription.substring(0, 100)}...';
  }

  /// Get word count
  int get wordCount => transcription.split(RegExp(r'\s+')).length;

  @override
  List<Object?> get props => [
        id,
        timestamp,
        transcription,
        tags,
        archived,
        convertedToJournal,
        convertedEntryId,
        durationMs,
      ];
}

/// Enum for voice processing choices after transcription
enum VoiceProcessingChoice {
  /// Save as a quick voice note to Ideas inbox (default)
  saveAsVoiceNote,

  /// Continue to full LUMARA conversation
  talkWithLumara,

  /// Add transcription to the normal Conversations timeline as a journal entry
  addToTimeline,

  /// User dismissed modal (tap outside or slide down)
  cancel,
}

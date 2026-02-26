import 'package:equatable/equatable.dart';
import 'package:my_app/data/models/media_item.dart';

class TimelineEntry extends Equatable {
  final String id;
  final String date;
  final String monthYear;
  final String preview;
  final String? title; // Optional title for the entry
  final bool hasArcform;
  final List<String> keywords;
  final String? phase; // ATLAS phase at time of entry
  final String? geometry; // Geometry pattern at time of entry
  final List<MediaItem> media; // Multimodal media attachments
  final DateTime createdAt; // Original date for sorting
  final bool hasLumaraBlocks; // Whether entry has LUMARA inline blocks
  /// Entry format for grouping: journal, chat, voice, writing, research, reflection. Null treated as journal.
  final String? entryFormat;
  /// Import source when entry was imported: GOOGLE_DRIVE, ARCHX, ZIP, NATIVE, OTHER. Null or NATIVE = not imported.
  final String? importSource;

  const TimelineEntry({
    required this.id,
    required this.date,
    required this.monthYear,
    required this.preview,
    this.title,
    required this.hasArcform,
    this.keywords = const [],
    this.phase,
    this.geometry,
    this.media = const [],
    required this.createdAt,
    this.hasLumaraBlocks = false,
    this.entryFormat,
    this.importSource,
  });

  /// Display label for this entry's format (e.g. "Writing", "Research").
  String get entryFormatLabel {
    switch (entryFormat) {
      case 'writing':
        return 'Writing';
      case 'research':
        return 'Research';
      case 'chat':
        return 'Chat';
      case 'voice':
        return 'Voice';
      case 'reflection':
        return 'Reflection';
      case 'journal':
      default:
        return 'Journal';
    }
  }

  /// Display label for timeline: CHAT, Voice, Reflection, Import (Drive), Import (ARCX), Journal, etc.
  String get formatDisplayLabel {
    if (importSource != null && importSource!.isNotEmpty && importSource != 'NATIVE') {
      switch (importSource!.toUpperCase()) {
        case 'GOOGLE_DRIVE':
          return 'Import (Drive)';
        case 'ARCHX':
          return 'Import (ARCX)';
        case 'ZIP':
          return 'Import (ZIP)';
        case 'OTHER':
          return 'Import';
        default:
          return 'Import';
      }
    }
    switch (entryFormat) {
      case 'chat':
        return 'CHAT';
      case 'voice':
        return 'Voice';
      case 'reflection':
        return 'Reflection';
      case 'writing':
        return 'Writing';
      case 'research':
        return 'Research';
      case 'journal':
      default:
        return 'Journal';
    }
  }

  @override
  List<Object?> get props => [id, date, monthYear, preview, title, hasArcform, keywords, phase, geometry, media, createdAt, hasLumaraBlocks, entryFormat, importSource];
}

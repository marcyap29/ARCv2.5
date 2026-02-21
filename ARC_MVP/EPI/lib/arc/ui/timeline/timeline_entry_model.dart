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
  /// Entry format for grouping: journal, chat, voice, writing, research. Null treated as journal.
  final String? entryFormat;

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
      case 'journal':
      default:
        return 'Journal';
    }
  }

  @override
  List<Object?> get props => [id, date, monthYear, preview, title, hasArcform, keywords, phase, geometry, media, createdAt, hasLumaraBlocks, entryFormat];
}

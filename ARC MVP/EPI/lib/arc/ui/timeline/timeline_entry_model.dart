import 'package:equatable/equatable.dart';
import 'package:my_app/data/models/media_item.dart';

class TimelineEntry extends Equatable {
  final String id;
  final String date;
  final String monthYear;
  final String preview;
  final bool hasArcform;
  final List<String> keywords;
  final String? phase; // ATLAS phase at time of entry
  final String? geometry; // Geometry pattern at time of entry
  final List<MediaItem> media; // Multimodal media attachments
  final DateTime createdAt; // Original date for sorting

  const TimelineEntry({
    required this.id,
    required this.date,
    required this.monthYear,
    required this.preview,
    required this.hasArcform,
    this.keywords = const [],
    this.phase,
    this.geometry,
    this.media = const [],
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, date, monthYear, preview, hasArcform, keywords, phase, geometry, media, createdAt];
}

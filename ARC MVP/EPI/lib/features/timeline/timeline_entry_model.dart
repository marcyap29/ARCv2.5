import 'package:equatable/equatable.dart';

class TimelineEntry extends Equatable {
  final String id;
  final String date;
  final String monthYear;
  final String preview;
  final bool hasArcform;
  final List<String> keywords;
  final String? phase; // ATLAS phase at time of entry
  final String? geometry; // Geometry pattern at time of entry

  const TimelineEntry({
    required this.id,
    required this.date,
    required this.monthYear,
    required this.preview,
    required this.hasArcform,
    this.keywords = const [],
    this.phase,
    this.geometry,
  });

  @override
  List<Object?> get props => [id, date, monthYear, preview, hasArcform, keywords, phase, geometry];
}

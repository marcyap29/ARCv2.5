import 'package:equatable/equatable.dart';
import 'package:my_app/arc/ui/timeline/timeline_entry_model.dart';

enum TimelineFilter { all, textOnly, withArcform }

class TimelineMonthGroup extends Equatable {
  final String month;
  final List<TimelineEntry> entries;

  const TimelineMonthGroup({
    required this.month,
    required this.entries,
  });

  @override
  List<Object?> get props => [month, entries];
}

abstract class TimelineState extends Equatable {
  const TimelineState();

  @override
  List<Object?> get props => [];
}

class TimelineInitial extends TimelineState {
  const TimelineInitial();
}

class TimelineLoading extends TimelineState {
  const TimelineLoading();
}

class TimelineLoaded extends TimelineState {
  final List<TimelineMonthGroup> groupedEntries;
  final TimelineFilter filter;
  final bool hasMore;
  final int version; // Add version for stable hashing

  const TimelineLoaded({
    required this.groupedEntries,
    required this.filter,
    required this.hasMore,
    this.version = 0,
  });

  // Add stable hash for UI rebuilds
  int get hashForUi => Object.hashAll(groupedEntries.map((g) => g.entries.map((e) => e.id))) ^ version.hashCode;

  TimelineLoaded copyWith({
    List<TimelineMonthGroup>? groupedEntries,
    TimelineFilter? filter,
    bool? hasMore,
    int? version,
  }) {
    return TimelineLoaded(
      groupedEntries: groupedEntries ?? this.groupedEntries,
      filter: filter ?? this.filter,
      hasMore: hasMore ?? this.hasMore,
      version: version ?? this.version + 1,
    );
  }

  @override
  List<Object?> get props => [groupedEntries, filter, hasMore, version];
}

class TimelineEmpty extends TimelineState {
  const TimelineEmpty();
}

class TimelineError extends TimelineState {
  final String message;

  const TimelineError({required this.message});

  @override
  List<Object?> get props => [message];
}

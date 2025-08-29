import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/timeline/timeline_state.dart';
import 'package:my_app/features/timeline/timeline_entry_model.dart';
import 'package:my_app/repositories/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';

class TimelineCubit extends Cubit<TimelineState> {
  final JournalRepository _journalRepository;
  static const int _pageSize = 10;
  int _currentPage = 0;
  bool _hasMore = true;

  TimelineCubit({JournalRepository? journalRepository})
      : _journalRepository = journalRepository ?? JournalRepository(),
        super(const TimelineInitial());

  void loadEntries() {
    emit(const TimelineLoading());
    _currentPage = 0;
    _hasMore = true;
    _loadEntries();
  }

  void loadMoreEntries() {
    if (!_hasMore) return;
    _currentPage++;
    _loadEntries();
  }

  void refreshEntries() {
    _currentPage = 0;
    _hasMore = true;
    _loadEntries();
  }

  void setFilter(TimelineFilter filter) {
    if (state is TimelineLoaded) {
      final currentState = state as TimelineLoaded;
      if (currentState.filter == filter) return;

      emit(const TimelineLoading());
      _currentPage = 0;
      _hasMore = true;
      _loadEntries(filter: filter);
    }
  }

  void _loadEntries({TimelineFilter? filter}) {
    try {
      final currentState = state is TimelineLoaded
          ? state as TimelineLoaded
          : TimelineLoaded(
              groupedEntries: [],
              filter: TimelineFilter.all,
              hasMore: true,
            );

      final effectiveFilter = filter ?? currentState.filter;

      final newEntries = _journalRepository.getEntriesPaginated(
        page: _currentPage,
        pageSize: _pageSize,
        filter: effectiveFilter,
      );

      // Check if we've reached the end
      _hasMore = newEntries.length == _pageSize;

      // Group entries by month
      final groupedEntries = _groupEntriesByMonth(
        [
          ...currentState.groupedEntries.expand((g) => g.entries),
          ..._mapToTimelineEntries(newEntries)
        ],
      );

      emit(TimelineLoaded(
        groupedEntries: groupedEntries,
        filter: effectiveFilter,
        hasMore: _hasMore,
      ));
    } catch (e) {
      emit(TimelineError(message: 'Failed to load timeline entries'));
    }
  }

  List<TimelineMonthGroup> _groupEntriesByMonth(List<TimelineEntry> entries) {
    final groups = <String, List<TimelineEntry>>{};

    for (final entry in entries) {
      if (!groups.containsKey(entry.monthYear)) {
        groups[entry.monthYear] = [];
      }
      groups[entry.monthYear]!.add(entry);
    }

    return groups.entries
        .map((entry) => TimelineMonthGroup(
              month: entry.key,
              entries: entry.value,
            ))
        .toList();
  }

  List<TimelineEntry> _mapToTimelineEntries(List<JournalEntry> journalEntries) {
    return journalEntries.map((entry) {
      return TimelineEntry(
        id: entry.id,
        date: _formatDate(entry.createdAt),
        monthYear: _formatMonthYear(entry.createdAt),
        preview: entry.content.isNotEmpty
            ? entry.content
            : 'Entry with Arcform snapshot', // Fallback if no content
        hasArcform: entry.sageAnnotation != null,
      );
    }).toList();
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatMonthYear(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

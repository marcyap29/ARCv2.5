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
          : const TimelineLoaded(
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
      emit(const TimelineError(message: 'Failed to load timeline entries'));
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
      // Determine phase from entry data
      String? phase;
      if (entry.sageAnnotation != null) {
        // Extract phase from sageAnnotation if available
        phase = _determinePhaseFromAnnotation(entry.sageAnnotation!);
      } else {
        // Determine phase from content and other factors
        phase = _determinePhaseFromContent(entry);
      }
      
      return TimelineEntry(
        id: entry.id,
        date: _formatDate(entry.createdAt),
        monthYear: _formatMonthYear(entry.createdAt),
        preview: entry.content.isNotEmpty
            ? entry.content
            : 'Entry with Arcform snapshot', // Fallback if no content
        hasArcform: entry.sageAnnotation != null,
        keywords: _extractKeywords(entry),
        phase: phase,
      );
    }).toList();
  }

  String? _determinePhaseFromAnnotation(Map<String, dynamic> annotation) {
    // Look for phase information in the sage annotation
    if (annotation.containsKey('recommendedPhase')) {
      return annotation['recommendedPhase'] as String?;
    }
    if (annotation.containsKey('phase')) {
      return annotation['phase'] as String?;
    }
    return null;
  }

  String _determinePhaseFromContent(JournalEntry entry) {
    // Simple content analysis to determine phase
    final content = entry.content.toLowerCase();
    
    if (content.contains('discover') || content.contains('explore') || content.contains('new') || content.contains('beginning')) {
      return 'Discovery';
    } else if (content.contains('grow') || content.contains('expand') || content.contains('possibility') || content.contains('energy')) {
      return 'Expansion';
    } else if (content.contains('change') || content.contains('transition') || content.contains('moving') || content.contains('shift')) {
      return 'Transition';
    } else if (content.contains('integrate') || content.contains('wisdom') || content.contains('balance') || content.contains('center')) {
      return 'Consolidation';
    } else if (content.contains('heal') || content.contains('recover') || content.contains('restore') || content.contains('rest')) {
      return 'Recovery';
    } else if (content.contains('breakthrough') || content.contains('transcend') || content.contains('quantum') || content.contains('beyond')) {
      return 'Breakthrough';
    }
    
    // Default based on entry characteristics
    return 'Discovery';
  }

  List<String> _extractKeywords(JournalEntry entry) {
    // Extract keywords from sage annotation if available
    if (entry.sageAnnotation != null) {
      final annotation = entry.sageAnnotation!;
      if (annotation.containsKey('keywords')) {
        final keywords = annotation['keywords'];
        if (keywords is List) {
          return keywords.map((k) => k.toString()).toList();
        }
      }
    }
    
    // Fallback: extract simple keywords from content
    final words = entry.content.toLowerCase().split(RegExp(r'\W+'));
    final importantWords = words.where((word) => 
      word.length > 4 && 
      !_stopWords.contains(word)
    ).take(3).toList();
    
    return importantWords;
  }

  static const _stopWords = {
    'that', 'this', 'with', 'have', 'will', 'been', 'from', 'they', 
    'know', 'want', 'been', 'good', 'much', 'some', 'time', 'very',
    'when', 'come', 'here', 'just', 'like', 'long', 'make', 'many',
    'over', 'such', 'take', 'than', 'them', 'well', 'were'
  };

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

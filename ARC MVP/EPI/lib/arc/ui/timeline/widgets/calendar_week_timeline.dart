// lib/arc/ui/timeline/widgets/calendar_week_timeline.dart
// Calendar week view for timeline visualization

import 'package:flutter/material.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/services/phase_index.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/arc/ui/timeline/timeline_state.dart';
import 'package:my_app/arc/ui/timeline/timeline_entry_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CalendarWeekTimeline extends StatefulWidget {
  final Function(DateTime)? onDateTap;
  final ValueNotifier<DateTime>? weekStartNotifier;
  
  const CalendarWeekTimeline({
    super.key,
    this.onDateTap,
    this.weekStartNotifier,
  });

  @override
  State<CalendarWeekTimeline> createState() => _CalendarWeekTimelineState();
}

class _CalendarWeekTimelineState extends State<CalendarWeekTimeline> {
  PhaseIndex? _phaseIndex;
  DateTime _currentWeekStart = _getWeekStart(DateTime.now());
  bool _isLoading = true;
  Set<DateTime> _datesWithEntries = {};
  final JournalRepository _journalRepo = JournalRepository();
  ValueNotifier<DateTime>? _externalWeekNotifier;

  static DateTime _getWeekStart(DateTime date) {
    // Get Monday of the week
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  void _syncWeekFromNotifier() {
    final notifier = _externalWeekNotifier;
    if (notifier == null) return;
    final value = notifier.value;
    if (!_isSameWeek(value, _currentWeekStart)) {
      setState(() {
        _currentWeekStart = value;
      });
    }
  }

  void _updateWeekState(DateTime date) {
    final newWeek = _getWeekStart(date);
    if (!_isSameWeek(newWeek, _currentWeekStart)) {
      setState(() {
        _currentWeekStart = newWeek;
      });
    }
    _externalWeekNotifier?.value = newWeek;
  }

  bool _isSameWeek(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _shiftWeek(Duration offset) {
    final newWeek = _currentWeekStart.add(offset);
    setState(() {
      _currentWeekStart = newWeek;
    });
    _externalWeekNotifier?.value = newWeek;
  }

  @override
  void initState() {
    _externalWeekNotifier = widget.weekStartNotifier;
    _externalWeekNotifier?.addListener(_syncWeekFromNotifier);
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load phase data
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      
      // Load dates with entries from timeline cubit if available
      final cubit = context.read<TimelineCubit>();
      final currentState = cubit.state;
      
      final datesWithEntries = <DateTime>{};
      
      if (currentState is TimelineLoaded) {
        // Use timeline entries from cubit
        for (final group in currentState.groupedEntries) {
          for (final entry in group.entries) {
            // Normalize to date only (remove time component)
            final dateOnly = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
            datesWithEntries.add(dateOnly);
          }
        }
      } else {
        // Fallback to journal repository if timeline not loaded yet
        final entries = _journalRepo.getAllJournalEntries();
      for (final entry in entries) {
        // Normalize to date only (remove time component)
        final dateOnly = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
        datesWithEntries.add(dateOnly);
        }
      }
      
      setState(() {
        _phaseIndex = phaseRegimeService.phaseIndex;
        _datesWithEntries = datesWithEntries;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getPhaseColor(PhaseLabel? label) {
    if (label == null) return Colors.grey;
    const colors = {
      PhaseLabel.discovery: Colors.blue,
      PhaseLabel.expansion: Colors.green,
      PhaseLabel.transition: Color(0xFFFF9500), // Brighter orange to match journal entries
      PhaseLabel.consolidation: Colors.purple,
      PhaseLabel.recovery: Colors.red,
      PhaseLabel.breakthrough: Colors.amber,
    };
    return colors[label] ?? Colors.grey;
  }
  
  void _navigateToDateEntries(DateTime targetDate) {
    // Call the callback if provided, otherwise use the default implementation
    if (widget.onDateTap != null) {
      widget.onDateTap!(targetDate);
      _updateWeekState(targetDate);
      return;
    }
    
    // Default: Find entries for this date
    final cubit = context.read<TimelineCubit>();
    final currentState = cubit.state;
    
    if (currentState is! TimelineLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Timeline not loaded yet'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Flatten all entries from grouped structure
    final allEntries = <TimelineEntry>[];
    for (final group in currentState.groupedEntries) {
      allEntries.addAll(group.entries);
    }
    
    // Filter entries for the target date
    final targetDateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final entriesForDate = allEntries.where((entry) {
      final entryDateOnly = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
      return entryDateOnly == targetDateOnly;
    }).toList();
    
    if (entriesForDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No entries found for ${targetDate.month}/${targetDate.day}/${targetDate.year}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found ${entriesForDate.length} entr${entriesForDate.length == 1 ? 'y' : 'ies'} for this date'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Set<DateTime> _getDatesWithEntriesFromTimeline(TimelineState timelineState) {
    if (timelineState is TimelineLoaded) {
      final datesWithEntries = <DateTime>{};
      for (final group in timelineState.groupedEntries) {
        for (final entry in group.entries) {
          final dateOnly = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
          datesWithEntries.add(dateOnly);
        }
      }
      return datesWithEntries;
    }
    return _datesWithEntries; // Return existing if timeline not loaded
  }

  @override
  void didUpdateWidget(covariant CalendarWeekTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekStartNotifier != widget.weekStartNotifier) {
      oldWidget.weekStartNotifier?.removeListener(_syncWeekFromNotifier);
      _externalWeekNotifier = widget.weekStartNotifier;
      _externalWeekNotifier?.addListener(_syncWeekFromNotifier);
    }
  }

  @override
  void dispose() {
    _externalWeekNotifier?.removeListener(_syncWeekFromNotifier);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to timeline cubit changes to get dates with entries
    return BlocBuilder<TimelineCubit, TimelineState>(
      builder: (context, timelineState) {
        // Get dates with entries from timeline state
        final datesWithEntries = _getDatesWithEntriesFromTimeline(timelineState);
        if (_datesWithEntries.length != datesWithEntries.length ||
            !datesWithEntries.containsAll(_datesWithEntries)) {
          _datesWithEntries = datesWithEntries;
        }
        
    if (_isLoading) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final weekDays = List.generate(7, (index) => _currentWeekStart.add(Duration(days: index)));

    return Container(
      height: 60, // Reduced height
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: kcBorderColor),
        borderRadius: BorderRadius.circular(8),
        color: kcSurfaceAltColor.withOpacity(0.3),
      ),
      child: Row(
        children: [
          // Week navigation
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: () {
              _shiftWeek(const Duration(days: -7));
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          // Calendar squares
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: weekDays.map((day) {
                final regime = _phaseIndex?.regimeFor(day);
                final phaseColor = _getPhaseColor(regime?.label);
                final isToday = day.year == DateTime.now().year &&
                    day.month == DateTime.now().month &&
                    day.day == DateTime.now().day;
                final dayDateOnly = DateTime(day.year, day.month, day.day);
                final hasEntries = datesWithEntries.contains(dayDateOnly);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _navigateToDateEntries(day);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: phaseColor.withOpacity(0.3),
                        border: Border.all(
                          color: isToday ? Colors.white : phaseColor.withOpacity(0.5),
                          width: isToday ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getDayName(day.weekday),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: kcPrimaryTextColor.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: kcPrimaryTextColor,
                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          // Dot indicator for dates with entries
                          if (hasEntries)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: phaseColor,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: () {
              _shiftWeek(const Duration(days: 7));
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
      },
    );
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}


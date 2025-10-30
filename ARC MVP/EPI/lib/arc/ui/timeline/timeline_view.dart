import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/arc/ui/timeline/timeline_state.dart';
import 'package:my_app/arc/ui/timeline/widgets/interactive_timeline_view.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/services/journal_session_cache.dart';
import 'package:my_app/ui/journal/journal_screen.dart';
import 'package:my_app/arc/ui/timeline/timeline_entry_model.dart';

class TimelineView extends StatelessWidget {
  const TimelineView({super.key});

  @override
  Widget build(BuildContext context) {
    return const TimelineViewContent();
  }
}

class TimelineViewContent extends StatefulWidget {
  const TimelineViewContent({super.key});

  @override
  State<TimelineViewContent> createState() => _TimelineViewContentState();
}

class _TimelineViewContentState extends State<TimelineViewContent> {
  final ScrollController _scrollController = ScrollController();
  late TimelineCubit _timelineCubit;
  final GlobalKey<InteractiveTimelineViewState> _timelineViewKey = GlobalKey<InteractiveTimelineViewState>();
  
  // Selection state - will be synced with InteractiveTimelineView
  bool _isSelectionMode = false;
  int _selectedCount = 0;
  int _totalEntries = 0;

  @override
  void initState() {
    super.initState();
    _timelineCubit = context.read<TimelineCubit>();
    _scrollController.addListener(_onScroll);
    // Refresh timeline when view is first shown to ensure latest data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timelineCubit.refreshEntries();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _timelineCubit.loadMoreEntries();
    }
  }

  void _onWritePressed() async {
    // Clear any existing session cache to ensure fresh start
    await JournalSessionCache.clearSession();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JournalScreen(),
      ),
    );
  }

  void _showJumpToDateDialog() {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    ).then((selectedDate) {
      if (selectedDate != null) {
        _jumpToDate(selectedDate);
      }
    });
  }

  void _jumpToDate(DateTime targetDate) {
    // Get current state to access entries
    final currentState = _timelineCubit.state;
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
    
    if (allEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No entries available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Sort entries by date (newest first, same as display)
    final sortedEntries = List<TimelineEntry>.from(allEntries);
    sortedEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Find the closest entry to the target date
    int closestIndex = 0;
    int minDaysDifference = 999999;
    
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final daysDifference = (entry.createdAt.difference(targetDate).inDays).abs();
      
      if (daysDifference < minDaysDifference) {
        minDaysDifference = daysDifference;
        closestIndex = i;
      }
    }
    
    // Scroll to the closest entry
    if (_scrollController.hasClients) {
      final itemHeight = 200.0; // Approximate height of each timeline entry
      final targetOffset = closestIndex * itemHeight;
      
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
    
    // Show feedback
    final closestEntry = sortedEntries[closestIndex];
    final daysDiff = (closestEntry.createdAt.difference(targetDate).inDays).abs();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Jumped to entry from ${closestEntry.createdAt.toString().split(' ')[0]} (${daysDiff} days ${targetDate.isBefore(closestEntry.createdAt) ? 'after' : 'before'} target date)'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimelineCubit, TimelineState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_isSelectionMode ? 'Select Entries' : 'Timeline'),
            leading: _isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _timelineViewKey.currentState?.exitSelectionMode();
                      setState(() {
                        _isSelectionMode = false;
                        _selectedCount = 0;
                      });
                    },
                  )
                : null,
            actions: [
              if (_isSelectionMode) ...[
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: () {
                    if (_selectedCount == _totalEntries) {
                      _timelineViewKey.currentState?.deselectAll();
                    } else {
                      _timelineViewKey.currentState?.selectAll();
                    }
                  },
                  tooltip: _selectedCount == _totalEntries
                      ? 'Deselect All'
                      : 'Select All',
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _timelineViewKey.currentState?.clearSelection();
                  },
                  tooltip: 'Clear Selection',
                ),
                if (_selectedCount > 0)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      _timelineViewKey.currentState?.deleteSelectedEntries();
                    },
                    tooltip: 'Delete Selected',
                  ),
              ] else ...[
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: _showJumpToDateDialog,
                tooltip: 'Jump to Date',
              ),
                IconButton(
                  icon: const Icon(Icons.checklist),
                  onPressed: () {
                    _timelineViewKey.currentState?.enterSelectionMode();
                    setState(() {
                      _isSelectionMode = true;
                    });
                  },
                  tooltip: 'Select Mode',
                ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _onWritePressed,
                tooltip: 'New Entry',
              ),
              ],
            ],
          ),
          body: Column(
            children: [
              _buildFilterButtons(state),
              Expanded(
                child: InteractiveTimelineView(
                  key: _timelineViewKey,
                  onJumpToDate: _showJumpToDateDialog,
                  onSelectionChanged: (isSelectionMode, selectedCount, totalEntries) {
                    // Only update state if values actually changed to prevent rebuild loops
                    if (_isSelectionMode != isSelectionMode || 
                        _selectedCount != selectedCount || 
                        _totalEntries != totalEntries) {
                      setState(() {
                        _isSelectionMode = isSelectionMode;
                        _selectedCount = selectedCount;
                        _totalEntries = totalEntries;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterButtons(TimelineState state) {
    // Get the current filter from the state if it's loaded
    TimelineFilter currentFilter = TimelineFilter.all;
    if (state is TimelineLoaded) {
      currentFilter = state.filter;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            FilterChip(
              label: const Text('All'),
              selected: currentFilter == TimelineFilter.all,
              onSelected: (_) =>
                  context.read<TimelineCubit>().setFilter(TimelineFilter.all),
              selectedColor: kcPrimaryColor.withOpacity(0.3),
              backgroundColor: kcSurfaceAltColor,
              labelStyle: const TextStyle(color: kcPrimaryTextColor),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Text only'),
              selected: currentFilter == TimelineFilter.textOnly,
              onSelected: (_) => context
                  .read<TimelineCubit>()
                  .setFilter(TimelineFilter.textOnly),
              selectedColor: kcPrimaryColor.withOpacity(0.3),
              backgroundColor: kcSurfaceAltColor,
              labelStyle: const TextStyle(color: kcPrimaryTextColor),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('With Arcform'),
              selected: currentFilter == TimelineFilter.withArcform,
              onSelected: (_) => context
                  .read<TimelineCubit>()
                  .setFilter(TimelineFilter.withArcform),
              selectedColor: kcPrimaryColor.withOpacity(0.3),
              backgroundColor: kcSurfaceAltColor,
              labelStyle: const TextStyle(color: kcPrimaryTextColor),
            ),
          ],
        ),
      ),
    );
  }
}

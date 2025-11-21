import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/arc/ui/timeline/timeline_state.dart';
import 'package:my_app/arc/ui/timeline/widgets/interactive_timeline_view.dart';
import 'package:my_app/arc/ui/timeline/widgets/current_phase_arcform_preview.dart';
import 'package:my_app/arc/ui/timeline/widgets/calendar_week_timeline.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/ui/timeline/timeline_entry_model.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/arc/ui/timeline/favorite_journal_entries_view.dart';
import 'package:my_app/shared/ui/settings/settings_view.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

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
  late AutoScrollController _scrollController;
  late TimelineCubit _timelineCubit;
  final GlobalKey<InteractiveTimelineViewState> _timelineViewKey = GlobalKey<InteractiveTimelineViewState>();
  final TextEditingController _searchController = TextEditingController();
  
  // Selection state - will be synced with InteractiveTimelineView
  bool _isSelectionMode = false;
  int _selectedCount = 0;
  int _totalEntries = 0;
  
  // Search expansion state
  bool _isSearchExpanded = false;
  bool _isArcformTimelineVisible = false;
  final ValueNotifier<DateTime> _weekNotifier = ValueNotifier(_calculateWeekStart(DateTime.now()));
  bool _isProgrammaticScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = AutoScrollController(
      viewportBoundaryGetter: () => Rect.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom),
    );
    _timelineCubit = context.read<TimelineCubit>();
    _scrollController.addListener(_onScroll);
    // Sync search controller with state
    _searchController.addListener(() {
      // Controller updates are handled by onChanged callback
    });
    // Refresh timeline when view is first shown to ensure latest data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timelineCubit.refreshEntries();
      // Check for phase changes and refresh Arcform visualization
      _checkAndRefreshPhase();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for phase changes when view becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRefreshPhase();
    });
  }

  /// Check if phase has changed and refresh Arcform preview if needed
  Future<void> _checkAndRefreshPhase() async {
    // Phase refresh is now handled by CurrentPhaseArcformPreview itself
    // This method is kept for potential future use but does nothing
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _weekNotifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _timelineCubit.loadMoreEntries();
    }
  }

  static DateTime _calculateWeekStart(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
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
    final weekStart = _calculateWeekStart(targetDate);
    if (_weekNotifier.value != weekStart) {
      _weekNotifier.value = weekStart;
    }
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
    
    // Find entries for the target date (exact match first)
    final targetDateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final exactMatches = sortedEntries.where((entry) {
      final entryDateOnly = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
      return entryDateOnly == targetDateOnly;
    }).toList();
    
    int targetIndex;
    TimelineEntry targetEntry;
    
    if (exactMatches.isNotEmpty) {
      // Use the first exact match
      targetEntry = exactMatches.first;
      targetIndex = sortedEntries.indexOf(targetEntry);
    } else {
    // Find the closest entry to the target date
    int closestIndex = 0;
    int minDaysDifference = 999999;
    
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
        final entryDateOnly = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
        final daysDifference = (entryDateOnly.difference(targetDateOnly).inDays).abs();
      
      if (daysDifference < minDaysDifference) {
        minDaysDifference = daysDifference;
        closestIndex = i;
      }
    }
      targetIndex = closestIndex;
      targetEntry = sortedEntries[targetIndex];
    }
    
    // Use AutoScrollController to scroll to the specific index
    // Wait multiple frames to ensure the list is fully built and rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isProgrammaticScroll = true;
      Future.delayed(const Duration(milliseconds: 200), () {
        // Find the entry in the current state
        final currentState = _timelineCubit.state;
        if (currentState is TimelineLoaded) {
          final allEntries = <TimelineEntry>[];
          for (final group in currentState.groupedEntries) {
            allEntries.addAll(group.entries);
          }
          
          final sortedEntries = List<TimelineEntry>.from(allEntries);
          sortedEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          final targetEntryId = targetEntry.id;
          final actualIndex = sortedEntries.indexWhere((e) => e.id == targetEntryId);
          
          if (actualIndex >= 0) {
            _scrollController.scrollToIndex(
              actualIndex,
              preferPosition: AutoScrollPosition.begin,
              duration: const Duration(milliseconds: 1000),
            ).then((_) {
              // Reset flag after scroll animation completes
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  _isProgrammaticScroll = false;
                }
              });
            });
          } else {
            _isProgrammaticScroll = false;
          }
        } else {
          _isProgrammaticScroll = false;
        }
      });
    });
    
    // Show feedback
    final entryDateOnly = DateTime(targetEntry.createdAt.year, targetEntry.createdAt.month, targetEntry.createdAt.day);
    final daysDiff = (entryDateOnly.difference(targetDateOnly).inDays).abs();
    if (daysDiff == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found entry for ${targetDate.month}/${targetDate.day}/${targetDate.year}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Jumped to entry from ${targetEntry.createdAt.toString().split(' ')[0]} (${daysDiff} days ${targetDateOnly.isBefore(entryDateOnly) ? 'after' : 'before'} target date)'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimelineCubit, TimelineState>(
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                return <Widget>[
                  // Custom header (replaces AppBar) - always visible, scrolls with content
                  if (!_isArcformTimelineVisible)
                    SliverToBoxAdapter(
                      child: _buildScrollableHeader(),
                    ),
                  // Timeline visualization (calendar week) - scrolls with content, below header
                  if (!_isArcformTimelineVisible && !_isSelectionMode)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: CalendarWeekTimeline(
                          onDateTap: (date) {
                            final weekStart = _calculateWeekStart(date);
                            _weekNotifier.value = weekStart;
                            _jumpToDate(date);
                          },
                          weekStartNotifier: _weekNotifier,
                        ),
                      ),
                    ),
                  // Phase preview - scrolls with content, below timeline visualization
                  if (!_isArcformTimelineVisible && !_isSelectionMode)
                    SliverToBoxAdapter(
                      child: const CurrentPhaseArcformPreview(),
                    ),
                  // Search bar - scrolls with content
                  if (!_isArcformTimelineVisible && _isSearchExpanded)
                    SliverToBoxAdapter(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Column(
                                children: [
                                  _buildSearchBar(state),
                                  _buildFilterButtons(state),
                                ],
                        ),
                      ),
              ),
                  // Phase legend dropdown for arcform timeline
                  if (_isArcformTimelineVisible)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: _buildPhaseLegendDropdown(context),
                      ),
              ),
                ];
              },
              body: InteractiveTimelineView(
                  key: _timelineViewKey,
                  scrollController: _scrollController, // Pass the AutoScrollController
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
                  onArcformTimelineVisibilityChanged: (visible) {
                    setState(() {
                      _isArcformTimelineVisible = visible;
                      if (visible && _isSearchExpanded) {
                        _isSearchExpanded = false;
                        _searchController.clear();
                        _timelineCubit.setSearchQuery('');
                      }
                    });
                  },
                  onVisibleEntryDateChanged: (date) {
                    if (!_isProgrammaticScroll) {
                      _weekNotifier.value = _calculateWeekStart(date);
                    }
                  },
                ),
          ),
        ),
        );
      },
    );
  }

  /// Build scrollable header that replaces AppBar
  Widget _buildScrollableHeader() {
    if (_isArcformTimelineVisible) {
      return const SizedBox.shrink();
    }

    return Container(
      color: kcBackgroundColor,
      child: Container(
        height: kToolbarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (_isSelectionMode)
              IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _timelineViewKey.currentState?.exitSelectionMode();
                setState(() {
                  _isSelectionMode = false;
                  _selectedCount = 0;
                });
              },
              ),
            // Timeline label with icon - centered
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timeline, size: 21),
                  const SizedBox(width: 4),
                  Text(
                    _isSelectionMode ? 'Select Entries' : 'Timeline',
                    style: heading1Style(context).copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Actions
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
            tooltip:
                _selectedCount == _totalEntries ? 'Deselect All' : 'Select All',
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'jump_to_date':
                      _showJumpToDateDialog();
                      break;
                    case 'search':
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
                        if (!_isSearchExpanded) {
                _searchController.clear();
                _timelineCubit.setSearchQuery('');
              }
                      });
                      break;
                    case 'favorites':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FavoriteJournalEntriesView(),
                        ),
                      );
                      break;
                    case 'select_mode':
              _timelineViewKey.currentState?.enterSelectionMode();
              setState(() {
                _isSelectionMode = true;
              });
                      break;
                    case 'settings':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsView(),
                        ),
                      );
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'jump_to_date',
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 12),
                        const Text('Jump to Date'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'search',
                    child: Row(
                      children: [
                        Icon(
                          _isSearchExpanded ? Icons.search_off : Icons.search,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(_isSearchExpanded ? 'Hide Search' : 'Search Entries'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'favorites',
                    child: Row(
                      children: [
                        const Icon(Icons.bookmark, color: Color(0xFF2196F3), size: 20),
                        const SizedBox(width: 12),
                        const Text('Favorite Journal Entries'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'select_mode',
                    child: Row(
                      children: [
                        const Icon(Icons.checklist, size: 20),
                        const SizedBox(width: 12),
                        const Text('Select Mode'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'settings',
                    child: Row(
                      children: [
                        const Icon(Icons.settings, size: 20),
                        const SizedBox(width: 12),
                        const Text('Settings'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(TimelineState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: kcSurfaceAltColor,
        border: Border(
          bottom: BorderSide(
            color: kcBorderColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: BlocBuilder<TimelineCubit, TimelineState>(
              builder: (context, timelineState) {
                final currentQuery = timelineState is TimelineLoaded 
                    ? timelineState.searchQuery 
                    : '';
                
                // Sync controller with state if they differ
                if (_searchController.text != currentQuery) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_searchController.text != currentQuery) {
                      _searchController.text = currentQuery;
                    }
                  });
                }
                
                return TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search entries or dates (MM/DD/YYYY)...',
                    prefixIcon: const Icon(Icons.search, color: kcPrimaryTextColor),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: kcPrimaryTextColor),
                            onPressed: () {
                              _searchController.clear();
                              _timelineCubit.setSearchQuery('');
                            },
                          )
                        : null,
                filled: true,
                fillColor: kcSurfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kcBorderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kcBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kcPrimaryColor, width: 2),
                ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(color: kcPrimaryTextColor),
                  onChanged: (value) {
                    _timelineCubit.setSearchQuery(value);
                  },
                );
              },
            ),
          ),
        ],
      ),
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

  Widget _buildPhaseLegendDropdown(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(Icons.palette, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Phase Legend',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    // All phase labels
                    ...PhaseLabel.values.map((label) {
                      final color = _phaseColor(label);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.7),
                              border: Border.all(color: color, width: 2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label.name.toUpperCase(),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      );
                    }).toList(),
                    // No Phase / Unknown Phase entry
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: kcSecondaryTextColor.withOpacity(0.7),
                            border: Border.all(color: kcSecondaryTextColor, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'NO PHASE',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildLegendSource(theme,
                        label: 'User Set',
                        color: theme.colorScheme.primary,
                        filled: true),
                    const SizedBox(width: 16),
                    _buildLegendSource(theme,
                        label: 'RIVET Detected',
                        color: Colors.grey,
                        filled: false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _phaseColor(PhaseLabel label) {
    switch (label) {
      case PhaseLabel.discovery:
        return Colors.blue;
      case PhaseLabel.expansion:
        return Colors.green;
      case PhaseLabel.transition:
        return Colors.orange;
      case PhaseLabel.consolidation:
        return Colors.purple;
      case PhaseLabel.recovery:
        return Colors.red;
      case PhaseLabel.breakthrough:
        return Colors.amber;
    }
  }

  Widget _buildLegendSource(ThemeData theme,
      {required String label, required Color color, required bool filled}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? Colors.white : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

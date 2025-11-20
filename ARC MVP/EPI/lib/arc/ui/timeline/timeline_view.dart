import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/arc/ui/timeline/timeline_state.dart';
import 'package:my_app/arc/ui/timeline/widgets/interactive_timeline_view.dart';
import 'package:my_app/arc/ui/timeline/widgets/current_phase_arcform_preview.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/ui/timeline/timeline_entry_model.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/arc/ui/timeline/favorite_journal_entries_view.dart';
import 'package:my_app/shared/ui/settings/settings_view.dart';

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
  final TextEditingController _searchController = TextEditingController();
  
  // Selection state - will be synced with InteractiveTimelineView
  bool _isSelectionMode = false;
  int _selectedCount = 0;
  int _totalEntries = 0;
  
  // Search expansion state
  bool _isSearchExpanded = false;
  bool _isArcformTimelineVisible = false;
  
  // Top bar visibility state
  bool _isTopBarVisible = false;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _timelineCubit.loadMoreEntries();
    }
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
          body: SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                return <Widget>[
                  // Subtle tab hint for top bar
                  if (!_isArcformTimelineVisible && !_isTopBarVisible)
                    SliverToBoxAdapter(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isTopBarVisible = true;
                          });
                        },
                        child: Container(
                          height: 24, // Increased from 8 to 24 for easier clicking
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: kcSurfaceAltColor.withOpacity(0.4), // Slightly more visible
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 60, // Increased from 40 to 60
                              height: 4, // Increased from 3 to 4
                              decoration: BoxDecoration(
                                color: kcPrimaryTextColor.withOpacity(0.5), // More visible
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Custom header (replaces AppBar) - scrolls with content, collapsible
                  if (!_isArcformTimelineVisible && _isTopBarVisible)
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildScrollableHeader(),
                          // Close button to hide the bar
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isTopBarVisible = false;
                              });
                            },
                            child: Container(
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: kcSurfaceAltColor.withOpacity(0.3),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.keyboard_arrow_up,
                                  size: 16,
                                  color: kcPrimaryTextColor.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Phase preview - scrolls with content
                  if (!_isArcformTimelineVisible && !_isSelectionMode)
                    SliverToBoxAdapter(
                      child: const CurrentPhaseArcformPreview(),
                    ),
                  // Timeline label - below Phase Preview, above journal entries
                  if (!_isArcformTimelineVisible && !_isSelectionMode)
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6), // Reduced by 1/2 from 12 to 6
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.timeline, size: 21), // Increased by 1/2 from 14 to 21
                            const SizedBox(width: 4),
                            Text(
                              'Timeline',
                              style: heading3Style(context).copyWith(
                                fontSize: 17.0625, // Increased by 1/2 from 11.375 to 17.0625
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                scrollController: null, // Let NestedScrollView handle scrolling coordination
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
      child: Column(
        children: [
          // Header bar with Timeline label, title and actions
          Container(
            height: kToolbarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
                Expanded(
                  child: Text(
                    _isSelectionMode ? 'Select Entries' : '',
                    style: heading1Style(context).copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
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
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _showJumpToDateDialog,
            tooltip: 'Jump to Date',
          ),
          IconButton(
            icon: Icon(_isSearchExpanded ? Icons.search_off : Icons.search),
            onPressed: () {
              final wasExpanded = _isSearchExpanded;
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
              });
              if (wasExpanded) {
                _searchController.clear();
                _timelineCubit.setSearchQuery('');
              }
            },
            tooltip: _isSearchExpanded ? 'Hide Search' : 'Search Entries',
          ),
                  IconButton(
                    icon: const Icon(Icons.bookmark, color: Color(0xFF2196F3)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FavoriteJournalEntriesView(),
                        ),
                      );
                    },
                    tooltip: 'Favorite Journal Entries',
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
            icon: const Icon(Icons.settings, size: 14),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsView(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ],
            ),
          ),
        ],
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
                    hintText: 'Search entries...',
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

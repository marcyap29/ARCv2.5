import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/arc/ui/timeline/timeline_state.dart';
import 'package:my_app/arc/ui/timeline/widgets/interactive_timeline_view.dart';
import 'package:my_app/arc/ui/timeline/widgets/calendar_week_timeline.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/ui/timeline/timeline_entry_model.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/arc/ui/timeline/favorite_journal_entries_view.dart';
import 'package:my_app/shared/ui/settings/settings_view.dart';
import 'package:my_app/arc/core/journal_repository.dart';
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
  DateTime? _lastVisibleEntryDate;
  DateTime? _pendingScrollDate;

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

  void _preserveScrollPosition() {
    if (_lastVisibleEntryDate != null) {
      _pendingScrollDate = _lastVisibleEntryDate;
    }
  }

  static DateTime _calculateWeekStart(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  String _formatMonthYear(DateTime date) {
    const months = [
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
      'December',
    ];
    final monthName = months[date.month - 1];
    return '$monthName ${date.year}';
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

    // Flatten all entries from grouped structure and apply same filtering as InteractiveTimelineView
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

    // Deduplicate by ID (same as InteractiveTimelineView._getFilteredEntries)
    final Map<String, TimelineEntry> uniqueEntries = {};
    for (final entry in allEntries) {
      if (!uniqueEntries.containsKey(entry.id)) {
        uniqueEntries[entry.id] = entry;
      }
    }
    final deduplicatedEntries = uniqueEntries.values.toList();
    
    // Apply filter (same as InteractiveTimelineView)
    List<TimelineEntry> filteredEntries;
    switch (currentState.filter) {
      case TimelineFilter.all:
        filteredEntries = deduplicatedEntries;
        break;
      case TimelineFilter.textOnly:
        filteredEntries = deduplicatedEntries.where((entry) => !entry.hasArcform).toList();
        break;
      case TimelineFilter.withArcform:
        filteredEntries = deduplicatedEntries.where((entry) => entry.hasArcform).toList();
        break;
    }

    // Sort entries by date (newest first, same as display)
    final sortedEntries = List<TimelineEntry>.from(filteredEntries);
    sortedEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Find entries for the target date (exact match first)
    final targetDateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);
    print('DEBUG: Jumping to date: $targetDateOnly');
    
    final exactMatches = sortedEntries.where((entry) {
      final entryDateOnly = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
      final isMatch = entryDateOnly == targetDateOnly;
      if (isMatch) {
        print('DEBUG: Found exact match: ${entry.createdAt} (ID: ${entry.id})');
      }
      return isMatch;
    }).toList();
    
    print('DEBUG: Found ${exactMatches.length} exact matches for $targetDateOnly');
    
    int targetIndex;
    TimelineEntry targetEntry;
    
    if (exactMatches.isNotEmpty) {
      // Use the first exact match (newest first, so this is the most recent entry on that date)
      targetEntry = exactMatches.first;
      targetIndex = sortedEntries.indexOf(targetEntry);
      print('DEBUG: Using exact match at index $targetIndex: ${targetEntry.createdAt}');
    } else {
      // Find the closest entry to the target date
      // Prefer entries on or before the target date, but if none exist, use the closest after
      int closestIndex = 0;
      int minDaysDifference = 999999;
      int? bestBeforeIndex;
      int minDaysBefore = 999999;
      
      for (int i = 0; i < sortedEntries.length; i++) {
        final entry = sortedEntries[i];
        final entryDateOnly = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
        final daysDifference = entryDateOnly.difference(targetDateOnly).inDays;
        
        // Prefer entries on or before the target date
        if (daysDifference <= 0) {
          final absDiff = daysDifference.abs();
          if (absDiff < minDaysBefore) {
            minDaysBefore = absDiff;
            bestBeforeIndex = i;
          }
        }
        
        // Also track the absolute closest for fallback
        final absDifference = daysDifference.abs();
        if (absDifference < minDaysDifference) {
          minDaysDifference = absDifference;
          closestIndex = i;
        }
      }
      
      // Use the best entry on or before target date, or fall back to closest overall
      if (bestBeforeIndex != null) {
        targetIndex = bestBeforeIndex;
      } else {
        targetIndex = closestIndex;
      }
      targetEntry = sortedEntries[targetIndex];
    }
    
    // Use AutoScrollController to scroll to the specific index
    // Wait multiple frames to ensure the list is fully built and rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isProgrammaticScroll = true;
      Future.delayed(const Duration(milliseconds: 200), () {
        // Find the entry in the current state using the same filtering logic as InteractiveTimelineView
        final currentState = _timelineCubit.state;
        if (currentState is TimelineLoaded) {
          // Use the same filtering/deduplication logic as InteractiveTimelineView._getFilteredEntries
          final allEntries = <TimelineEntry>[];
          for (final group in currentState.groupedEntries) {
            allEntries.addAll(group.entries);
          }
          
          // Deduplicate by ID (same as InteractiveTimelineView)
          final Map<String, TimelineEntry> uniqueEntries = {};
          for (final entry in allEntries) {
            if (!uniqueEntries.containsKey(entry.id)) {
              uniqueEntries[entry.id] = entry;
            }
          }
          final deduplicatedEntries = uniqueEntries.values.toList();
          
          // Apply filter (same as InteractiveTimelineView)
          List<TimelineEntry> filteredEntries;
          switch (currentState.filter) {
            case TimelineFilter.all:
              filteredEntries = deduplicatedEntries;
              break;
            case TimelineFilter.textOnly:
              filteredEntries = deduplicatedEntries.where((entry) => !entry.hasArcform).toList();
              break;
            case TimelineFilter.withArcform:
              filteredEntries = deduplicatedEntries.where((entry) => entry.hasArcform).toList();
              break;
          }
          
          // Sort entries by date (newest first, same as display)
          filteredEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          final targetEntryId = targetEntry.id;
          final actualIndex = filteredEntries.indexWhere((e) => e.id == targetEntryId);
          
          print('DEBUG: Scroll - Found entry at index $actualIndex (target ID: $targetEntryId)');
          print('DEBUG: Scroll - Total filtered entries: ${filteredEntries.length}');
          
          if (actualIndex >= 0) {
            // Account for arcform preview if it's shown (adds 1 to index)
            final showArcformPreview = !_isArcformTimelineVisible && !_isSelectionMode;
            final scrollIndex = showArcformPreview ? actualIndex + 1 : actualIndex;
            
            print('DEBUG: Scroll - Scrolling to index $scrollIndex (arcform preview: $showArcformPreview)');
            
            _scrollController.scrollToIndex(
              scrollIndex,
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
            print('DEBUG: Scroll - Entry not found in filtered list!');
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

  Future<void> _removeDuplicateEntries() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcSurfaceColor,
        title: Text(
          'Remove Duplicate Entries',
          style: heading1Style(context),
        ),
        content: Text(
          'This will scan all journal entries and remove duplicates, keeping the most recent version of each. This action cannot be undone.',
          style: bodyStyle(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: buttonStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: Text(
              'Remove Duplicates',
              style: buttonStyle(context),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: kcSurfaceColor,
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(
              'Scanning for duplicates...',
              style: bodyStyle(context),
            ),
          ],
        ),
      ),
    );

    try {
      final journalRepository = JournalRepository();
      final deletedCount = await journalRepository.removeDuplicateEntries();

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Refresh timeline
      _timelineCubit.refreshEntries();

      // Show result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deletedCount > 0
                ? 'Removed $deletedCount duplicate ${deletedCount == 1 ? 'entry' : 'entries'}'
                : 'No duplicate entries found',
          ),
          backgroundColor: deletedCount > 0 ? kcSuccessColor : kcSecondaryTextColor,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove duplicates: $e'),
          backgroundColor: kcDangerColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TimelineCubit, TimelineState>(
      listener: (context, state) {
        if (state is TimelineLoaded && _pendingScrollDate != null) {
          final dateToRestore = _pendingScrollDate!;
          _pendingScrollDate = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _jumpToDate(dateToRestore);
          });
        }
      },
      child: BlocBuilder<TimelineCubit, TimelineState>(
        builder: (context, state) {
          return Scaffold(
            body: SafeArea(
              child: NestedScrollView(
                headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                  return <Widget>[
                    if (!_isArcformTimelineVisible)
                      SliverToBoxAdapter(
                        child: _buildScrollableHeader(),
                      ),
                    if (!_isArcformTimelineVisible && !_isSelectionMode)
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _CalendarWeekHeaderDelegate(
                          child: Container(
                            color: kcBackgroundColor,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: ValueListenableBuilder<DateTime>(
                              valueListenable: _weekNotifier,
                              builder: (context, weekStart, _) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatMonthYear(weekStart),
                                    style: heading2Style(context).copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  CalendarWeekTimeline(
                                    onDateTap: (date) {
                                      final weekStart = _calculateWeekStart(date);
                                      _weekNotifier.value = weekStart;
                                      _jumpToDate(date);
                                    },
                                    weekStartNotifier: _weekNotifier,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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
                    if (_isArcformTimelineVisible)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: _buildPhaseLegendDropdown(context),
                        ),
                      ),
                  ];
                },
                body: InteractiveTimelineView(
                  key: _timelineViewKey,
                  scrollController: _scrollController,
                  showArcformPreview: !_isArcformTimelineVisible && !_isSelectionMode,
                  onJumpToDate: _showJumpToDateDialog,
                  onRequestPreserveScrollPosition: _preserveScrollPosition,
                  onSelectionChanged: (isSelectionMode, selectedCount, totalEntries) {
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
                    _lastVisibleEntryDate = date;
                    if (!_isProgrammaticScroll) {
                      _weekNotifier.value = _calculateWeekStart(date);
                    }
                  },
                ),
              ),
            ),
          );
        },
      ),
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
                    case 'remove_duplicates':
                      _removeDuplicateEntries();
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
                    value: 'remove_duplicates',
                    child: Row(
                      children: [
                        const Icon(Icons.cleaning_services, color: Colors.orange, size: 20),
                        const SizedBox(width: 12),
                        const Text('Remove Duplicate Entries'),
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

// Delegate for pinned calendar week header
class _CalendarWeekHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _CalendarWeekHeaderDelegate({required this.child});

  @override
  double get minExtent => 108.0; // ~24 (month text) + 8 (spacing) + 60 (calendar) + 16 (padding)

  @override
  double get maxExtent => 108.0; // ~24 (month text) + 8 (spacing) + 60 (calendar) + 16 (padding)

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_CalendarWeekHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}

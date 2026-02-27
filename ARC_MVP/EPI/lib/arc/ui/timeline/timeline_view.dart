import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/arc/ui/timeline/timeline_state.dart';
import 'package:my_app/arc/ui/timeline/widgets/interactive_timeline_view.dart';
import 'package:my_app/arc/ui/timeline/widgets/calendar_week_timeline.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/ui/timeline/timeline_entry_model.dart';
import 'package:my_app/arc/ui/timeline/favorite_journal_entries_view.dart';
import 'package:my_app/shared/ui/settings/settings_view.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class TimelineView extends StatelessWidget {
  /// If set, timeline will scroll to this entry once loaded (e.g. from Chronicle).
  final String? initialScrollToEntryId;

  const TimelineView({super.key, this.initialScrollToEntryId});

  @override
  Widget build(BuildContext context) {
    return TimelineViewContent(initialScrollToEntryId: initialScrollToEntryId);
  }
}

class TimelineViewContent extends StatefulWidget {
  final String? initialScrollToEntryId;

  const TimelineViewContent({super.key, this.initialScrollToEntryId});

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
  String? _pendingScrollEntryId;
  
  // Scroll button visibility
  bool _showScrollToTop = false;
  bool _showScrollToBottom = false;

  // View: group by format (Writing, Research, Chat, Voice, Journal) with collapsible sections
  bool _groupByFormat = false;
  Set<String> _collapsedFormats = {};

  @override
  void initState() {
    super.initState();
    _pendingScrollEntryId = widget.initialScrollToEntryId;
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
    final position = _scrollController.position;
    
    // Check if we should load more entries
    // Load more when we're about 75% through the loaded entries (15 out of 20 shown)
    final currentState = _timelineCubit.state;
    if (currentState is TimelineLoaded && currentState.hasMore) {
      // Count total entries loaded
      int totalEntriesLoaded = 0;
      for (final group in currentState.groupedEntries) {
        totalEntriesLoaded += group.entries.length;
      }
      
      // If we have at least 20 entries loaded, check scroll position
      // Trigger when we're 75% through (15 entries shown = 5 left)
      if (totalEntriesLoaded >= 20) {
        // Calculate scroll percentage
        final scrollPercentage = position.pixels / (position.maxScrollExtent > 0 ? position.maxScrollExtent : 1);
        // Load more when we're at 75% scroll (meaning 15 entries shown out of 20)
        if (scrollPercentage >= 0.75) {
          _timelineCubit.loadMoreEntries();
        }
      } else {
        // For smaller lists, use pixel-based detection
        if (position.pixels >= position.maxScrollExtent - 200) {
          _timelineCubit.loadMoreEntries();
        }
      }
    }
    
    // Track scroll position for scroll buttons
    final isNearTop = position.pixels <= 100;
    final isNearBottom = position.pixels >= position.maxScrollExtent - 100;
    
    // Show scroll-to-top when scrolled down, scroll-to-bottom when scrolled up
    final shouldShowTop = !isNearTop;
    final shouldShowBottom = !isNearBottom && position.maxScrollExtent > 200;
    
    if (_showScrollToTop != shouldShowTop || _showScrollToBottom != shouldShowBottom) {
      setState(() {
        _showScrollToTop = shouldShowTop;
        _showScrollToBottom = shouldShowBottom;
      });
    }
  }
  
  /// Scroll to top (newest entries)
  void _scrollToTopOfList() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        _showScrollToTop = false;
      });
    }
  }
  
  /// Scroll to bottom (older entries)
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        _showScrollToBottom = false;
      });
    }
  }

  void _preserveScrollPosition() {
    if (_lastVisibleEntryDate != null) {
      _pendingScrollDate = _lastVisibleEntryDate;
    }
  }

  List<TimelineEntry> _getFilteredEntriesFromState(TimelineLoaded state) {
    final allEntries = <TimelineEntry>[];
    for (final group in state.groupedEntries) {
      allEntries.addAll(group.entries);
    }

    final Map<String, TimelineEntry> uniqueEntries = {};
    for (final entry in allEntries) {
      uniqueEntries.putIfAbsent(entry.id, () => entry);
    }

    List<TimelineEntry> filteredEntries;
    switch (state.filter) {
      case TimelineFilter.all:
        filteredEntries = uniqueEntries.values.toList();
        break;
      case TimelineFilter.textOnly:
        filteredEntries =
            uniqueEntries.values.where((entry) => !entry.hasArcform).toList();
        break;
      case TimelineFilter.withArcform:
        filteredEntries =
            uniqueEntries.values.where((entry) => entry.hasArcform).toList();
        break;
    }

    filteredEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filteredEntries;
  }

  Future<void> _scrollToTop() async {
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

    final filteredEntries = _getFilteredEntriesFromState(currentState);
    if (filteredEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No entries to scroll to'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!_scrollController.hasClients) {
      return;
    }

    final latestEntry = filteredEntries.first;
    final showArcformPreview = !_isArcformTimelineVisible && !_isSelectionMode;
    final targetIndex = showArcformPreview ? 1 : 0;

    _isProgrammaticScroll = true;
    await _scrollController.scrollToIndex(
      targetIndex,
      preferPosition: AutoScrollPosition.begin,
      duration: const Duration(milliseconds: 500),
    );

    _weekNotifier.value = _calculateWeekStart(latestEntry.createdAt);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _isProgrammaticScroll = false;
      }
    });
  }

  void _jumpToEntryId(String entryId) {
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

    final sortedEntries = _getFilteredEntriesFromState(currentState);
    final targetIndex = sortedEntries.indexWhere((e) => e.id == entryId);
    if (targetIndex < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry not found on timeline'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final targetEntry = sortedEntries[targetIndex];
    final weekStart = _calculateWeekStart(targetEntry.createdAt);
    if (_weekNotifier.value != weekStart) {
      _weekNotifier.value = weekStart;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isProgrammaticScroll = true;
      Future.delayed(const Duration(milliseconds: 200), () {
        final currentState = _timelineCubit.state;
        if (currentState is TimelineLoaded) {
          final filteredEntries = _getFilteredEntriesFromState(currentState);
          final actualIndex = filteredEntries.indexWhere((e) => e.id == entryId);
          if (actualIndex >= 0) {
            final showArcformPreview = !_isArcformTimelineVisible && !_isSelectionMode;
            final scrollIndex = showArcformPreview ? actualIndex + 1 : actualIndex;
            _scrollController.scrollToIndex(
              scrollIndex,
              preferPosition: AutoScrollPosition.middle,
              duration: const Duration(milliseconds: 800),
            ).then((_) {
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) _isProgrammaticScroll = false;
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

    final label = (targetEntry.title?.trim().isNotEmpty == true
            ? targetEntry.title!
            : targetEntry.preview)
        .replaceAll('\n', ' ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Jumped to entry: ${label.length > 45 ? "${label.substring(0, 45)}…" : label}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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

    final sortedEntries = _getFilteredEntriesFromState(currentState);
    if (sortedEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No entries available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
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
          final filteredEntries = _getFilteredEntriesFromState(currentState);
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
          content: Text('Jumped to entry from ${targetEntry.createdAt.toString().split(' ')[0]} ($daysDiff days ${targetDateOnly.isBefore(entryDateOnly) ? 'after' : 'before'} target date)'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TimelineCubit, TimelineState>(
      listener: (context, state) {
        if (state is! TimelineLoaded) return;
        if (_pendingScrollDate != null) {
          final dateToRestore = _pendingScrollDate!;
          _pendingScrollDate = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _jumpToDate(dateToRestore);
          });
          return;
        }
        if (_pendingScrollEntryId == null) return;
        final entryId = _pendingScrollEntryId!;
        final sortedEntries = _getFilteredEntriesFromState(state);
        final found = sortedEntries.any((e) => e.id == entryId);
        if (found) {
          _pendingScrollEntryId = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _jumpToEntryId(entryId);
          });
        } else if (state.hasMore) {
          _timelineCubit.loadMoreEntries();
        } else {
          _pendingScrollEntryId = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Entry not found on timeline'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          });
        }
      },
      child: BlocBuilder<TimelineCubit, TimelineState>(
        builder: (context, state) {
          return Stack(
            children: [
              Scaffold(
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
                        // Phase legend removed (reposition: phases not shown to user)
                      ];
                    },
                    body: InteractiveTimelineView(
                      key: _timelineViewKey,
                      scrollController: _scrollController,
                      showArcformPreview: false, // Phase window hidden from user (reposition)
                      groupByFormat: _groupByFormat,
                      collapsedFormats: _collapsedFormats,
                      onToggleFormatSection: (formatKey) {
                        setState(() {
                          if (_collapsedFormats.contains(formatKey)) {
                            _collapsedFormats = Set.from(_collapsedFormats)..remove(formatKey);
                          } else {
                            _collapsedFormats = Set.from(_collapsedFormats)..add(formatKey);
                          }
                        });
                      },
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
              ),
              // Floating scroll-to-top button (newest entries)
              if (_showScrollToTop)
                Positioned(
                  bottom: 140, // Above scroll-to-bottom button
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'timelineScrollToTop',
                    onPressed: _scrollToTopOfList,
                    backgroundColor: kcSurfaceAltColor,
                    elevation: 4,
                    child: const Icon(
                      Icons.keyboard_arrow_up,
                      color: Colors.white,
                    ),
                  ),
                ),
              // Floating scroll-to-bottom button (older entries)
              if (_showScrollToBottom)
                Positioned(
                  bottom: 80, // Above the nav bar
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'timelineScrollToBottom',
                    onPressed: _scrollToBottom,
                    backgroundColor: kcSurfaceAltColor,
                    elevation: 4,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
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
            // Timeline label with icon - left-aligned with spacing
            Flexible(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (!_isSelectionMode) ...[
                    const Icon(Icons.chat_bubble_outline, size: 21),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      _isSelectionMode ? 'Select Entries' : 'Conversations',
                      style: heading1Style(context).copyWith(
                        fontSize: _isSelectionMode ? 18 : 20,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Actions
          // Add a button to scroll to the latest entry
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: 'Jump to Latest',
            onPressed: _scrollToTop,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Timeline tips',
            onPressed: _showTimelineTipsSheet,
          ),
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
          if (_selectedCount > 0)
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: () {
                _timelineViewKey.currentState?.exportSelectedEntries();
              },
              tooltip: 'Export Selected',
              color: kcAccentColor,
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
                    case 'group_by_format':
                      setState(() {
                        _groupByFormat = !_groupByFormat;
                        if (!_groupByFormat) _collapsedFormats = {};
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
                  const PopupMenuItem<String>(
                    value: 'jump_to_date',
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 20),
                        SizedBox(width: 12),
                        Text('Jump to Date'),
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
                    value: 'group_by_format',
                    child: Row(
                      children: [
                        Icon(
                          _groupByFormat ? Icons.view_stream : Icons.view_list,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(_groupByFormat ? 'Chronological view' : 'Group by format'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'favorites',
                    child: Row(
                      children: [
                        Icon(Icons.bookmark, color: Color(0xFF2196F3), size: 20),
                        SizedBox(width: 12),
                        Text('Favorite Journal Entries'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'select_mode',
                    child: Row(
                      children: [
                        Icon(Icons.checklist, size: 20),
                        SizedBox(width: 12),
                        Text('Select Mode'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings, size: 20),
                        SizedBox(width: 12),
                        Text('Settings'),
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
                  borderSide: const BorderSide(color: kcBorderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kcBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kcPrimaryColor, width: 2),
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

  /// Timeline tips (phase legend removed for reposition).
  void _showTimelineTipsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kcSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.help_outline),
                    const SizedBox(width: 8),
                    Text('Timeline tips', style: heading2Style(context)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Scroll to explore your entries. Tap the format bar on the left of an entry to open the arcform timeline. Long-press an entry for options. Use the menu to jump to a date, group by format, or export.',
                  style: bodyStyle(context).copyWith(
                    color: kcSecondaryTextColor,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}

// Delegate for pinned calendar week header
class _CalendarWeekHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _CalendarWeekHeaderDelegate({required this.child});

  @override
  double get minExtent => 114.0; // Constrain to safe size to avoid layoutExtent > paintExtent errors

  @override
  double get maxExtent => 114.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Constrain child to fit within declared extent and clip overflow
    return ClipRect(
      child: SizedBox(
        height: maxExtent,
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_CalendarWeekHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}

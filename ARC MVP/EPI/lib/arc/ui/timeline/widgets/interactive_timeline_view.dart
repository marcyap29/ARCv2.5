import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/ui/timeline/timeline_cubit.dart';
import 'package:my_app/arc/ui/timeline/timeline_state.dart';
import 'package:my_app/arc/ui/timeline/timeline_entry_model.dart';
import 'package:my_app/arc/ui/timeline/widgets/entry_content_renderer.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/ui/journal/journal_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:my_app/arc/ui/arcforms/arcform_renderer_state.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/shared/ui/onboarding/phase_quiz_prompt_view.dart';
import 'package:my_app/prism/atlas/rivet/rivet_provider.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart';
import 'package:my_app/core/services/draft_cache_service.dart';
import 'package:my_app/prism/atlas/rivet/rivet_service.dart';
import 'package:hive/hive.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/arc/ui/arcforms/phase_recommender.dart';
import 'package:my_app/polymeta/mira_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;

class InteractiveTimelineView extends StatefulWidget {
  final VoidCallback? onJumpToDate;
  final Function(bool isSelectionMode, int selectedCount, int totalEntries)? onSelectionChanged;
  
  const InteractiveTimelineView({
    super.key,
    this.onJumpToDate,
    this.onSelectionChanged,
  });

  @override
  State<InteractiveTimelineView> createState() =>
      InteractiveTimelineViewState();
}

// Expose state class for GlobalKey access (public for parent widget access)
class InteractiveTimelineViewState extends State<InteractiveTimelineView>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  List<TimelineEntry> _entries = [];
  bool _isSelectionMode = false;
  final Set<String> _selectedEntryIds = {};
  late ScrollController _scrollController;
  
  // Track previous notification state to prevent unnecessary callbacks
  bool _previousSelectionMode = false;
  int _previousSelectedCount = 0;
  int _previousTotalEntries = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // Removed PageView-related methods for 2D grid layout

  /// Clean up MIRA nodes and edges when a journal entry is deleted
  Future<void> _cleanupMiraDataForEntry(String entryId) async {
    try {
      final miraService = MiraService.instance;
      final miraRepo = miraService.repo;

      // Generate the MIRA node ID for this entry
      final miraNodeId = 'je_$entryId';

      print('🧹 Cleaning up MIRA data for entry $entryId (node: $miraNodeId)');

      // Delete all edges where this node is source or target
      final allEdges = await miraRepo
          .exportAll()
          .where((record) => record['kind'] == 'edge')
          .map((record) => record)
          .toList();

      for (final edgeRecord in allEdges) {
        final src = edgeRecord['src'] as String?;
        final dst = edgeRecord['dst'] as String?;
        final edgeId = edgeRecord['id'] as String?;

        if (edgeId != null && (src == miraNodeId || dst == miraNodeId)) {
          await miraRepo.removeEdge(edgeId);
          print('🧹 Deleted edge $edgeId');
        }
      }

      // Delete the entry node itself
      await miraRepo.removeNode(miraNodeId);
      print('🧹 Deleted node $miraNodeId');

      // Note: Keyword nodes are kept for other entries that may reference them
      // They will be cleaned up by a separate orphan cleanup process if needed
    } catch (e) {
      print('⚠️ Error cleaning up MIRA data for entry $entryId: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TimelineCubit, TimelineState>(
      listener: (context, state) {
        // Removed automatic phase quiz trigger when timeline is empty
        // Users can now manually change their phase in the timeline or phase tab
      },
      child: BlocBuilder<TimelineCubit, TimelineState>(
        builder: (context, state) {
          print('DEBUG: BlocBuilder received state: ${state.runtimeType}');
          if (state is TimelineLoaded) {
            print(
                'DEBUG: TimelineLoaded with ${state.groupedEntries.length} groups');
            _entries = _getFilteredEntries(state);
            print('DEBUG: Filtered entries count: ${_entries.length}');
            
            // Only notify parent if selection state actually changed
            // This prevents infinite rebuild loops
            final currentSelectedCount = _selectedEntryIds.length;
            final currentTotalEntries = _entries.length;
            if (_previousSelectionMode != _isSelectionMode ||
                _previousSelectedCount != currentSelectedCount ||
                _previousTotalEntries != currentTotalEntries) {
              // Update previous values immediately to prevent race conditions
              _previousSelectionMode = _isSelectionMode;
              _previousSelectedCount = currentSelectedCount;
              _previousTotalEntries = currentTotalEntries;
              
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _notifySelectionChanged();
                }
              });
            }
            
            // 2D grid layout - no need to jump to specific page

            if (_entries.isEmpty) {
              return Center(
                child: Text(
                  'No entries yet',
                  style: bodyStyle(context),
                ),
              );
            }

            return SafeArea(
              child: Column(
                children: [
                  _buildTimelineHeader(),
                  Expanded(
                    child: _buildInteractiveTimeline(),
                  ),
                  _buildTimelineFooter(),
                ],
              ),
            );
          }

          if (state is TimelineLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TimelineEmpty) {
            return _buildEmptyState();
          }

          if (state is TimelineError) {
            return Center(
              child: Text(
                state.message,
                style: bodyStyle(context),
              ),
            );
          }

          // Handle TimelineInitial state - load entries automatically
          if (state is TimelineInitial) {
            // Trigger load on first build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.read<TimelineCubit>().loadEntries();
              }
            });
            return const Center(child: CircularProgressIndicator());
          }

          return Container();
        },
      ),
    );
  }

  Widget _buildTimelineHeader() {
    if (_isSelectionMode) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconButton(
              onPressed: exitSelectionMode,
              icon: const Icon(Icons.close),
              color: kcPrimaryTextColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_selectedEntryIds.length} selected',
                style: heading1Style(context).copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Select All button
            TextButton(
              onPressed: _selectedEntryIds.length == _entries.length
                  ? deselectAll
                  : selectAll,
              child: Text(
                _selectedEntryIds.length == _entries.length
                    ? 'Deselect All'
                    : 'Select All',
                style: bodyStyle(context).copyWith(
                  color: kcPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Delete selected button
            IconButton(
              onPressed:
                  _selectedEntryIds.isNotEmpty ? deleteSelectedEntries : null,
              icon: const Icon(Icons.delete),
              color: _selectedEntryIds.isNotEmpty
                  ? kcDangerColor
                  : kcSecondaryTextColor.withOpacity(0.3),
            ),
          ],
        ),
      );
    }

    // Simplified header - just the title
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Your Sacred Journey',
              style: heading1Style(context).copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
    );
  }

  Widget _buildInteractiveTimeline() {
    return RefreshIndicator(
      onRefresh: _refreshTimeline,
      child: _build2DGridTimeline(),
    );
  }

  Widget _build2DGridTimeline() {
    print('DEBUG: _build2DGridTimeline - _entries has ${_entries?.length ?? 0} entries');

    // Safety check for null or empty entries
    if (_entries == null || _entries.isEmpty) {
      print('DEBUG: _entries is null or empty, returning empty state');
      return Center(
        child: Text(
          'No timeline entries available',
          style: bodyStyle(context),
        ),
      );
    }

    // Get all entries and sort them properly by actual date (newest first)
    final sortedEntries = List<TimelineEntry>.from(_entries);

    // Sort by the original createdAt DateTime (newest first)
    try {
      sortedEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('DEBUG: Error sorting entries: $e');
    }

    print('DEBUG: _build2DGridTimeline - Building ListView with ${sortedEntries.length} entries');

    if (sortedEntries.isEmpty) {
      print('DEBUG: sortedEntries is empty after sorting');
      return Center(
        child: Text(
          'No sorted timeline entries',
          style: bodyStyle(context),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        print('DEBUG: Building timeline card for entry $index');
        final entry = sortedEntries[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _buildTimelineEntryCard(entry, 0, index),
        );
      },
    );
  }

  List<Map<String, dynamic>> _groupEntriesByTimePeriod() {
    if (_entries.isEmpty) return [];
    
    // Group entries by month
    final monthGroups = <String, List<TimelineEntry>>{};
    
    for (final entry in _entries) {
      final entryDate = DateTime.tryParse(entry.date) ?? DateTime.now();
      final monthKey = '${entryDate.year}-${entryDate.month.toString().padLeft(2, '0')}';
      
      if (!monthGroups.containsKey(monthKey)) {
        monthGroups[monthKey] = [];
      }
      monthGroups[monthKey]!.add(entry);
    }
    
    // Sort entries within each month (earliest on left, latest on right)
    for (final group in monthGroups.values) {
      group.sort((a, b) => a.date.compareTo(b.date));
    }
    
    // Convert to list with month titles, sorted newest month first
    return monthGroups.entries.map((entry) {
      final monthKey = entry.key;
      final entries = entry.value;
      
      // Create month title
      final year = int.parse(monthKey.split('-')[0]);
      final month = int.parse(monthKey.split('-')[1]);
      final title = '${_getMonthName(month)} $year';
      
      return {
        'title': title,
        'entries': entries,
      };
    }).toList()
      ..sort((a, b) {
        // Sort months by newest first (October 2025 before September 2025)
        final aEntries = a['entries'] as List<TimelineEntry>;
        final bEntries = b['entries'] as List<TimelineEntry>;
        final aNewestEntry = aEntries.last; // Last entry is newest since we sort oldest-first within groups
        final bNewestEntry = bEntries.last; // Last entry is newest since we sort oldest-first within groups
        return bNewestEntry.date.compareTo(aNewestEntry.date);
      });
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay + firstDayOfYear.weekday - 1) / 7).floor() + 1;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  Widget _buildStickyHeader(String title, int entryCount) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        border: Border(
          bottom: BorderSide(
            color: kcBorderColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
                children: [
            Expanded(
              child: Text(
                title,
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
                  Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kcPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                  color: kcPrimaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                '$entryCount entries',
                style: captionStyle(context).copyWith(
                              color: kcPrimaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
                      ],
                    ),
                  ),
    );
  }

  Widget _buildTimelineEntryCard(TimelineEntry entry, int periodIndex, int entryIndex) {
    final isSelected = _selectedEntryIds.contains(entry.id);

    return GestureDetector(
      onTap: () => _onEntryTap(entry),
      onLongPress: () => _onEntryLongPress(entry),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 100,
          maxHeight: double.infinity,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? kcPrimaryColor.withOpacity(0.1)
              : kcSurfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kcPrimaryColor : kcBorderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox or leading icon
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _onEntryTap(entry),
                  ),
                ),
              // Entry content
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Entry header with date and time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.date,
                            style: captionStyle(context).copyWith(
                              color: kcSecondaryTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (entry.hasArcform)
                          Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: kcPrimaryColor,
                          ),
                      ],
                    ),

                    // Entry title (if present)
                    if (entry.title != null && entry.title!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        entry.title!,
                        style: bodyStyle(context).copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: kcPrimaryTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Entry content preview
                    Text(
                      entry.preview.isNotEmpty
                          ? entry.preview.length > 100
                              ? '${entry.preview.substring(0, 100)}...'
                              : entry.preview
                          : 'No content',
                      style: bodyStyle(context).copyWith(
                        fontSize: 14,
                        color: kcPrimaryTextColor,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Entry metadata
                    Row(
                      children: [
                        if (entry.media.isNotEmpty) ...[
                          Icon(
                            Icons.photo,
                            size: 14,
                            color: kcSecondaryTextColor,
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (entry.keywords.isNotEmpty) ...[
                          Icon(
                            Icons.tag,
                            size: 14,
                            color: kcSecondaryTextColor,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            entry.phase ?? 'Discovery',
                            style: captionStyle(context).copyWith(
                              color: kcSecondaryTextColor,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatEntryDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(date.year, date.month, date.day);
    
    if (entryDate == today) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (entryDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  // Timeline line removed for 2D grid layout

  // Removed old _buildTimelineEntry method - using _buildTimelineEntryCard for 2D grid

  void _onEntryTap(TimelineEntry entry) async {
    if (_isSelectionMode) {
      // Toggle selection
      setState(() {
        if (_selectedEntryIds.contains(entry.id)) {
          _selectedEntryIds.remove(entry.id);
        } else {
          _selectedEntryIds.add(entry.id);
        }
        _notifySelectionChanged();
      });
    } else {
      // Fetch the full journal entry for editing
      try {
        final journalRepository = context.read<JournalRepository>();
        final fullEntry = journalRepository.getJournalEntryById(entry.id);

        if (fullEntry != null) {
          // Check for existing draft linked to this entry (3c, 3d requirement)
          final draftCache = DraftCacheService.instance;
          await draftCache.initialize();
          final hasDraft = await draftCache.hasDraftForEntry(entry.id);
          
          if (hasDraft) {
            // Found a draft - show dialog to open draft or view original
            final draft = await draftCache.getDraftByLinkedEntryId(entry.id);
            if (draft != null && mounted) {
              final shouldOpenDraft = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Unfinished Draft Found'),
                  content: Text(
                    'You have an unfinished draft for this entry from ${_formatDraftDate(draft.lastModified)}. Would you like to continue editing the draft?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('View Original'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Open Draft'),
                    ),
                  ],
                ),
              );
              
              if (shouldOpenDraft == true && mounted) {
                // Open draft in edit mode
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => JournalScreen(
                      initialContent: draft.content,
                      selectedEmotion: draft.initialEmotion,
                      selectedReason: draft.initialReason,
                      existingEntry: fullEntry, // Pass entry for linking
                      isViewOnly: false, // Open in edit mode directly
                    ),
                  ),
                );
                return;
              }
            }
          }
          
          // Navigate to journal screen with full entry for editing (not view-only)
          // Open entry directly without creating a draft initially
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => JournalScreen(
                initialContent: fullEntry.content,
                selectedEmotion: fullEntry.emotion,
                selectedReason: fullEntry.emotionReason,
                existingEntry: fullEntry, // Pass the full entry with media
                isViewOnly: false, // Open in edit mode - entry is opened directly
                openAsEdit: true, // Flag to indicate this is an edit (not creating draft initially)
              ),
            ),
          );
        } else {
          // Fallback to preview mode if entry not found
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => JournalScreen(
                initialContent: entry.preview,
                selectedEmotion: entry.phase,
                selectedReason: entry.geometry,
                isViewOnly: true, // Set to view-only mode to prevent draft creation
              ),
            ),
          );
        }
      } catch (e) {
        // Fallback to preview mode on error
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => JournalScreen(
              initialContent: entry.preview,
              selectedEmotion: entry.phase,
              selectedReason: entry.geometry,
              isViewOnly: true, // Set to view-only mode to prevent draft creation
            ),
          ),
        );
      }
    }
  }

  String _formatDraftDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _onEntryLongPress(TimelineEntry entry) {
    if (!_isSelectionMode) {
      _enterSelectionModeWithEntry(entry.id);
    }
  }


  Color _getPhaseColor(String? phase) {
    if (phase == null) return kcSecondaryTextColor;

    switch (phase.toLowerCase()) {
      case 'discovery':
        return const Color(0xFF4F46E5); // Blue
      case 'expansion':
        return const Color(0xFF7C3AED); // Purple
      case 'transition':
        return const Color(0xFF059669); // Green
      case 'consolidation':
        return const Color(0xFFD97706); // Orange
      case 'recovery':
        return const Color(0xFFDC2626); // Red
      case 'breakthrough':
        return const Color(0xFF7C2D12); // Brown
      default:
        return kcSecondaryTextColor;
    }
  }

  Widget _buildEntryDetailsWithPhaseShape(
      TimelineEntry entry, bool isCurrentEntry, bool isSelected) {
    final phaseColor = _getPhaseColor(entry.phase);

    return Column(
      children: [
        // Phase name above the entry
        if (entry.phase != null) ...[
          _buildPhaseDisplay(entry.phase!, phaseColor, isCurrentEntry),
          const SizedBox(height: 16),
        ],

        // Entry type label
        Text(
          'JOURNAL ENTRY',
          style: captionStyle(context).copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: isCurrentEntry
                ? kcPrimaryTextColor
                : kcSecondaryTextColor.withOpacity(0.7),
          ),
        ),

        const SizedBox(height: 8),

        // Date
        Text(
          entry.date,
          style: bodyStyle(context).copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isCurrentEntry
                ? kcPrimaryTextColor
                : kcSecondaryTextColor.withOpacity(0.6),
          ),
        ),

        // Entry title (if present)
        if (entry.title != null && entry.title!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            entry.title!,
            style: bodyStyle(context).copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isCurrentEntry
                  ? kcPrimaryTextColor
                  : kcPrimaryTextColor.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],

        const SizedBox(height: 12),

        // Preview text (only for current entry)
        if (isCurrentEntry) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kcSurfaceColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: kcPrimaryColor.withOpacity(0.2),
              ),
            ),
            child: EntryContentRenderer(
              content: entry.preview,
              mediaItems: entry.media,
              textStyle: bodyStyle(context).copyWith(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhaseDisplay(
      String phase, Color phaseColor, bool isCurrentEntry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: phaseColor.withOpacity(isCurrentEntry ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: phaseColor.withOpacity(isCurrentEntry ? 0.8 : 0.5),
          width: isCurrentEntry ? 2 : 1,
        ),
        boxShadow: isCurrentEntry
            ? [
                BoxShadow(
                  color: phaseColor.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getPhaseIcon(phase),
            color: phaseColor.withOpacity(isCurrentEntry ? 1.0 : 0.7),
            size: isCurrentEntry ? 16 : 14,
          ),
          const SizedBox(width: 6),
          Text(
            phase.toUpperCase(),
            style: captionStyle(context).copyWith(
              color: phaseColor.withOpacity(isCurrentEntry ? 1.0 : 0.8),
              fontSize: isCurrentEntry ? 12 : 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPhaseIcon(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return Icons.explore;
      case 'expansion':
        return Icons.local_florist;
      case 'transition':
        return Icons.trending_up;
      case 'consolidation':
        return Icons.grid_view;
      case 'recovery':
        return Icons.healing;
      case 'breakthrough':
        return Icons.auto_fix_high;
      default:
        return Icons.circle;
    }
  }

  Widget _buildTimelineFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Simplified navigation hint
          Expanded(
            child: Text(
              'Scroll to explore your journey',
              style: captionStyle(context).copyWith(
                color: kcSecondaryTextColor.withOpacity(0.6),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Entry counter
          Flexible(
            child: Text(
              '${_entries.length} entries',
              style: captionStyle(context).copyWith(
                color: kcSecondaryTextColor.withOpacity(0.6),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 80,
              color: kcSecondaryTextColor.withOpacity(0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'No Journal Entries',
              style: heading1Style(context).copyWith(
                fontSize: 24,
                color: kcPrimaryTextColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'All your journal entries have been deleted.\nTime to start fresh with a new phase!',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _restartPhaseQuestionnaire,
              style: ElevatedButton.styleFrom(
                backgroundColor: kcPrimaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh, color: Colors.white),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Start Phase Questionnaire',
                      style: buttonStyle(context).copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _restartPhaseQuestionnaire() {
    // Navigate to phase quiz prompt for elegant restart flow
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const PhaseQuizPromptView()),
    );
  }

  void _notifySelectionChanged() {
    widget.onSelectionChanged?.call(_isSelectionMode, _selectedEntryIds.length, _entries.length);
  }

  // Public methods for parent widget access
  void enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedEntryIds.clear();
      _notifySelectionChanged();
    });
  }

  void _enterSelectionModeWithEntry(String entryId) {
    setState(() {
      _isSelectionMode = true;
      _selectedEntryIds.clear();
      _selectedEntryIds.add(entryId);
      _notifySelectionChanged();
    });
  }

  void exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedEntryIds.clear();
      _notifySelectionChanged();
    });
  }

  void selectAll() {
    setState(() {
      _selectedEntryIds.clear();
      _selectedEntryIds.addAll(_entries.map((e) => e.id));
      _notifySelectionChanged();
    });
  }

  void deselectAll() {
    setState(() {
      _selectedEntryIds.clear();
      _notifySelectionChanged();
    });
  }

  void clearSelection() {
    setState(() {
      _selectedEntryIds.clear();
      _notifySelectionChanged();
    });
  }
  
  void deleteSelectedEntries() {
    _deleteSelectedEntries();
  }
  
  // Getters for parent widget
  bool get isSelectionMode => _isSelectionMode;
  int get selectedCount => _selectedEntryIds.length;
  int get totalEntries => _entries.length;

  Future<void> _refreshTimeline() async {
    print('DEBUG: Refreshing timeline...');
    final timelineCubit = context.read<TimelineCubit>();
    await timelineCubit.refreshEntries();
    print('DEBUG: Timeline refresh completed');
  }

  Future<void> _deleteSelectedEntries() async {
    print('DEBUG: _deleteSelectedEntries called');
    print('DEBUG: Selected entries count: ${_selectedEntryIds.length}');
    print('DEBUG: Selected entry IDs: $_selectedEntryIds');

    if (_selectedEntryIds.isEmpty) {
      print('DEBUG: No entries selected, returning');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcSurfaceColor,
        title: Text(
          'Delete ${_selectedEntryIds.length} Entries',
          style: heading1Style(context),
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedEntryIds.length} journal entries? This action cannot be undone.',
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
              backgroundColor: kcDangerColor,
            ),
            child: Text(
              'Delete All',
              style: buttonStyle(context),
            ),
          ),
        ],
      ),
    );

    print('DEBUG: Dialog result: $confirmed');

    if (confirmed == true && mounted) {
      try {
        print(
            'DEBUG: Starting deletion of ${_selectedEntryIds.length} entries');
        print('DEBUG: Selected entry IDs: $_selectedEntryIds');

        final journalRepository = JournalRepository();

        // Get count before deletion
        final countBefore = await journalRepository.getEntryCount();
        print('DEBUG: Total entries before deletion: $countBefore');

        // Delete all selected entries
        for (final entryId in _selectedEntryIds) {
          print('DEBUG: Deleting entry: $entryId');
          await journalRepository.deleteJournalEntry(entryId);

          // NEW: Clean up MIRA nodes and edges for this entry
          await _cleanupMiraDataForEntry(entryId);

          // Verify deletion
          final deletedEntry = journalRepository.getJournalEntryById(entryId);
          if (deletedEntry == null) {
            print('DEBUG: ✅ Entry $entryId successfully deleted');
          } else {
            print('DEBUG: ❌ Entry $entryId still exists after deletion');
          }
        }

        // Get count after deletion
        final countAfter = await journalRepository.getEntryCount();
        print('DEBUG: Total entries after deletion: $countAfter');

        // Check if all entries have been deleted
        final timelineCubit = context.read<TimelineCubit>();
        final allEntriesDeleted =
            await timelineCubit.checkIfAllEntriesDeleted();

        // Store the count before clearing selection
        final deletedCount = _selectedEntryIds.length;

        // If all entries were deleted, clear the draft cache to prevent old content from being restored
        if (allEntriesDeleted) {
          try {
            final draftCache = DraftCacheService.instance;
            await draftCache.clearAllDrafts();
            print('🧹 Cleared all drafts after deleting all entries');
          } catch (e) {
            print('⚠️ Error clearing drafts after deletion: $e');
          }
        }

        // Recalculate RIVET state after deletion
        await _recalculateRivetState();

        if (mounted) {
          if (!allEntriesDeleted) {
            // Refresh the timeline if there are still entries
            print('DEBUG: Refreshing timeline entries after deletion');
            timelineCubit.refreshEntries();
          } else {
            print('DEBUG: All entries deleted, no refresh needed');
          }

          // Exit selection mode
          setState(() {
            _isSelectionMode = false;
            _selectedEntryIds.clear();
            _notifySelectionChanged();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$deletedCount entries deleted successfully'),
              backgroundColor: kcSuccessColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete entries: $e'),
              backgroundColor: kcDangerColor,
            ),
          );
        }
      }
    }
  }

  List<TimelineEntry> _getFilteredEntries(TimelineLoaded state) {
    // Flatten all entries from grouped data
    List<TimelineEntry> allEntries = [];
    print('DEBUG: _getFilteredEntries - Processing ${state.groupedEntries.length} groups');

    for (final group in state.groupedEntries) {
      print('DEBUG: Group has ${group.entries?.length ?? 0} entries');
      if (group.entries != null) {
        allEntries.addAll(group.entries!);
      }
    }

    print('DEBUG: Total flattened entries: ${allEntries.length}');
    print('DEBUG: Current filter: ${state.filter}');

    // Apply filter with null safety
    List<TimelineEntry> filteredEntries;
    try {
      switch (state.filter) {
        case TimelineFilter.all:
          filteredEntries = allEntries;
          break;
        case TimelineFilter.textOnly:
          filteredEntries = allEntries.where((entry) => entry != null && !entry.hasArcform).toList();
          break;
        case TimelineFilter.withArcform:
          filteredEntries = allEntries.where((entry) => entry != null && entry.hasArcform).toList();
          break;
        default:
          print('DEBUG: Unknown filter type: ${state.filter}, defaulting to all entries');
          filteredEntries = allEntries;
          break;
      }
    } catch (e) {
      print('DEBUG: Error during filtering: $e, returning all entries');
      filteredEntries = allEntries;
    }

    print('DEBUG: After filtering: ${filteredEntries.length} entries');

    // Additional debugging for specific cases
    if (allEntries.isNotEmpty && filteredEntries.isEmpty) {
      print('DEBUG: WARNING - All entries filtered out!');
      print('DEBUG: First entry hasArcform: ${allEntries.first.hasArcform}');
      print('DEBUG: Filter applied: ${state.filter}');
    }

    return filteredEntries;
  }

  /// Recalculate RIVET state after entry deletion
  Future<void> _recalculateRivetState() async {
    try {
      print('DEBUG: Recalculating RIVET state after deletion');

      // Get all remaining entries
      final journalRepository = JournalRepository();
      final remainingEntries = journalRepository.getAllJournalEntriesSync();

      print('DEBUG: Remaining entries count: ${remainingEntries.length}');

      const userId = 'default_user';

      if (remainingEntries.isEmpty) {
        // No entries = reset to initial RIVET state
        print('DEBUG: No entries left - resetting RIVET to initial state');

        try {
          if (Hive.isBoxOpen('rivet_state_v1')) {
            final stateBox = Hive.box('rivet_state_v1');
            await stateBox.put(userId, {
              'align': 0.0,
              'trace': 0.0,
              'sustainCount': 0,
              'sawIndependentInWindow': false,
              'lastUpdated': DateTime.now().millisecondsSinceEpoch,
            });
            print('DEBUG: Reset RIVET state to 0% ALIGN, 0% TRACE');
          }

          if (Hive.isBoxOpen('rivet_events_v1')) {
            final eventsBox = Hive.box('rivet_events_v1');
            await eventsBox.delete(userId);
            print('DEBUG: Cleared RIVET events');
          }
        } catch (e) {
          print('DEBUG: Error resetting RIVET state: $e');
        }
      } else {
        // Rebuild RIVET state from remaining entries using proper RIVET logic
        print(
            'DEBUG: Rebuilding RIVET state from ${remainingEntries.length} remaining entries');

        // Clear existing RIVET data
        try {
          if (Hive.isBoxOpen('rivet_state_v1')) {
            final stateBox = Hive.box('rivet_state_v1');
            await stateBox.delete(userId);
          }

          if (Hive.isBoxOpen('rivet_events_v1')) {
            final eventsBox = Hive.box('rivet_events_v1');
            await eventsBox.delete(userId);
          }
        } catch (e) {
          print('DEBUG: Error clearing RIVET data: $e');
        }

        // Create fresh RIVET service and process remaining entries
        final rivetService = RivetService();
        RivetEvent? lastEvent;

        // Sort entries chronologically
        final sortedEntries = remainingEntries
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        for (final entry in sortedEntries) {
          // Get current user phase and recommended phase
          final currentPhase = await UserPhaseService.getCurrentPhase();
          final recommendedPhase = PhaseRecommender.recommend(
            emotion: entry.emotion ?? '',
            reason: entry.emotionReason ?? '',
            text: entry.content,
            selectedKeywords: entry.keywords,
          );

          // Create RIVET event
          final rivetEvent = RivetEvent(
            eventId: const Uuid().v4(),
            date: entry.createdAt,
            source: EvidenceSource.text,
            keywords: entry.keywords.toSet(),
            predPhase: recommendedPhase,
            refPhase: currentPhase,
            tolerance: const {},
          );

          // Process through RIVET service
          rivetService.ingest(rivetEvent, lastEvent: lastEvent);
          lastEvent = rivetEvent;

          print(
              'DEBUG: Processed entry ${entry.id} - ALIGN: ${(rivetService.state.align * 100).toInt()}%, TRACE: ${(rivetService.state.trace * 100).toInt()}%');
        }

        // Save the final RIVET state
        try {
          if (Hive.isBoxOpen('rivet_state_v1')) {
            final stateBox = Hive.box('rivet_state_v1');
            await stateBox.put(userId, {
              'align': rivetService.state.align,
              'trace': rivetService.state.trace,
              'sustainCount': rivetService.state.sustainCount,
              'sawIndependentInWindow':
                  rivetService.state.sawIndependentInWindow,
              'lastUpdated': DateTime.now().millisecondsSinceEpoch,
            });
            print(
                'DEBUG: Saved rebuilt RIVET state - ALIGN: ${(rivetService.state.align * 100).toInt()}%, TRACE: ${(rivetService.state.trace * 100).toInt()}%');
          }
        } catch (e) {
          print('DEBUG: Error saving rebuilt RIVET state: $e');
        }
      }

      // Reset the RIVET provider
      final rivetProvider = RivetProvider();
      rivetProvider.reset();
      await rivetProvider.initialize(userId);

      print(
          'DEBUG: RIVET state recalculated from ${remainingEntries.length} remaining entries');
    } catch (e) {
      print('ERROR: Failed to recalculate RIVET state: $e');
    }
  }

  // Removed _buildMediaAttachments - using EntryContentRenderer for inline thumbnails instead

  void _openImageInGallery(String imagePath) async {
    try {
      if (Platform.isIOS) {
        // Try multiple approaches to open the specific photo
        final success = await _tryOpenSpecificPhoto(imagePath);
        if (!success) {
          // Fallback: try to open the Photos app directly
          final photosUri = Uri.parse('photos-redirect://');
          if (await canLaunchUrl(photosUri)) {
            await launchUrl(photosUri, mode: LaunchMode.externalApplication);
          } else {
            _showPhotoInfo(imagePath);
          }
        }
      } else {
        // Android: try to open the file directly
        final uri = Uri.file(imagePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showPhotoInfo(imagePath);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open photo: $e'),
          backgroundColor: kcDangerColor,
        ),
      );
    }
  }

  Future<bool> _tryOpenSpecificPhoto(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return false;
      }

      // Method 1: Try to use native iOS Photos framework to find and open the specific photo
      if (Platform.isIOS) {
        try {
          const platform = MethodChannel('com.epi.arcmvp/photos');
          final result = await platform.invokeMethod(
              'getPhotoIdentifierAndOpen', imagePath);
          if (result == true) {
            return true;
          }
        } catch (e) {
          print('Native Photos method failed: $e');
        }
      }

      // Method 2: Try to extract photo identifier from path and use photos:// scheme
      final fileName = imagePath.split('/').last;
      final photoId = _extractPhotoIdFromFileName(fileName);

      if (photoId != null) {
        final photosUri = Uri.parse('photos://$photoId');
        if (await canLaunchUrl(photosUri)) {
          await launchUrl(photosUri, mode: LaunchMode.externalApplication);
          return true;
        }
      }

      // Method 3: Try to open with file:// scheme (might work for some photos)
      final fileUri = Uri.file(imagePath);
      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
        return true;
      }

      // Method 4: Try to use the Photos app with a search query
      final searchUri = Uri.parse(
          'photos-redirect://search?query=${Uri.encodeComponent(fileName)}');
      if (await canLaunchUrl(searchUri)) {
        await launchUrl(searchUri, mode: LaunchMode.externalApplication);
        return true;
      }

      return false;
    } catch (e) {
      print('Error trying to open specific photo: $e');
      return false;
    }
  }

  Future<bool> _tryOpenSpecificVideo(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        return false;
      }

      // Method 1: Try to use native iOS Photos framework to find and open the specific video
      if (Platform.isIOS) {
        try {
          const platform = MethodChannel('com.epi.arcmvp/photos');
          final result = await platform.invokeMethod(
              'getVideoIdentifierAndOpen', videoPath);
          if (result == true) {
            return true;
          }
        } catch (e) {
          print('Native Videos method failed: $e');
        }
      }

      // Method 2: Try to extract video identifier from path and use photos:// scheme
      final fileName = videoPath.split('/').last;
      final videoId = _extractPhotoIdFromFileName(fileName);

      if (videoId != null) {
        final photosUri = Uri.parse('photos://$videoId');
        if (await canLaunchUrl(photosUri)) {
          await launchUrl(photosUri, mode: LaunchMode.externalApplication);
          return true;
        }
      }

      // Method 3: Try to open with file:// scheme
      final fileUri = Uri.file(videoPath);
      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
        return true;
      }

      // Method 4: Try to use the Photos app with a search query
      final searchUri = Uri.parse(
          'photos-redirect://search?query=${Uri.encodeComponent(fileName)}');
      if (await canLaunchUrl(searchUri)) {
        await launchUrl(searchUri, mode: LaunchMode.externalApplication);
        return true;
      }

      return false;
    } catch (e) {
      print('Error trying to open specific video: $e');
      return false;
    }
  }

  Future<bool> _tryOpenSpecificMedia(String mediaPath) async {
    try {
      final file = File(mediaPath);
      if (!await file.exists()) {
        return false;
      }

      // Method 1: Try to use native iOS Photos framework to find and open the specific media
      if (Platform.isIOS) {
        try {
          const platform = MethodChannel('com.epi.arcmvp/photos');
          final result = await platform.invokeMethod(
              'getMediaIdentifierAndOpen', mediaPath);
          if (result == true) {
            return true;
          }
        } catch (e) {
          print('Native Media method failed: $e');
        }
      }

      // Method 2: Try to extract media identifier from path and use photos:// scheme
      final fileName = mediaPath.split('/').last;
      final mediaId = _extractPhotoIdFromFileName(fileName);

      if (mediaId != null) {
        final photosUri = Uri.parse('photos://$mediaId');
        if (await canLaunchUrl(photosUri)) {
          await launchUrl(photosUri, mode: LaunchMode.externalApplication);
          return true;
        }
      }

      // Method 3: Try to open with file:// scheme
      final fileUri = Uri.file(mediaPath);
      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
        return true;
      }

      // Method 4: Try to use the Photos app with a search query
      final searchUri = Uri.parse(
          'photos-redirect://search?query=${Uri.encodeComponent(fileName)}');
      if (await canLaunchUrl(searchUri)) {
        await launchUrl(searchUri, mode: LaunchMode.externalApplication);
        return true;
      }

      return false;
    } catch (e) {
      print('Error trying to open specific media: $e');
      return false;
    }
  }

  String? _extractPhotoIdFromFileName(String fileName) {
    // Try to extract a photo identifier from the filename
    // iOS Photos often use UUIDs or specific naming patterns
    final uuidPattern = RegExp(
        r'[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}',
        caseSensitive: false);
    final match = uuidPattern.firstMatch(fileName);
    if (match != null) {
      return match.group(0);
    }

    // Try to extract from common iOS photo naming patterns
    final iosPattern = RegExp(r'IMG_(\d{4})');
    final iosMatch = iosPattern.firstMatch(fileName);
    if (iosMatch != null) {
      return iosMatch.group(0);
    }

    return null;
  }

  void _showPhotoInfo(String imagePath) {
    final fileName = imagePath.split('/').last;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Photo: $fileName'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Open Photos',
          onPressed: () async {
            final photosUri = Uri.parse('photos-redirect://');
            if (await canLaunchUrl(photosUri)) {
              await launchUrl(photosUri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ),
    );
  }

  void _showVideoInfo(String videoPath) {
    final fileName = videoPath.split('/').last;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video: $fileName'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Open Photos',
          onPressed: () async {
            final photosUri = Uri.parse('photos-redirect://');
            if (await canLaunchUrl(photosUri)) {
              await launchUrl(photosUri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ),
    );
  }

  void _showAudioInfo(String audioPath) {
    final fileName = audioPath.split('/').last;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Audio: $fileName'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Open Files',
          onPressed: () async {
            final fileUri = Uri.file(audioPath);
            if (await canLaunchUrl(fileUri)) {
              await launchUrl(fileUri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ),
    );
  }

  void _showAnalysisDetails(Map<String, dynamic> analysisData) {
    showDialog(
      context: context,
      builder: (context) => AnalysisDetailsDialog(analysisResult: analysisData),
    );
  }

  Future<bool> _checkImageExists(String imagePath) async {
    try {
      final file = File(imagePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkMediaExists(String mediaPath) async {
    try {
      final file = File(mediaPath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  void _showBrokenImageDialog(MediaItem mediaItem) {
    showDialog(
      context: context,
      builder: (context) => BrokenImageDialog(
        mediaItem: mediaItem,
        onRelinkImage: () => _navigateToEditEntry(mediaItem),
        onPhotoRelinked: (relinkedPhoto) => _handlePhotoRelinked(mediaItem, relinkedPhoto),
      ),
    );
  }

  void _handlePhotoRelinked(MediaItem originalMedia, MediaItem relinkedPhoto) {
    // Find the entry that contains this media item and update it
    final entryIndex = _entries.indexWhere(
      (e) => e.media.any((m) => m.id == originalMedia.id),
    );
    
    if (entryIndex != -1) {
      // Update the media item in the entry
      final updatedEntry = _entries[entryIndex];
      final updatedMedia = updatedEntry.media.map((m) {
        if (m.id == originalMedia.id) {
          return relinkedPhoto;
        }
        return m;
      }).toList();
      
      // Create updated entry
      final newEntry = TimelineEntry(
        id: updatedEntry.id,
        date: updatedEntry.date,
        monthYear: updatedEntry.monthYear,
        preview: updatedEntry.preview,
        hasArcform: updatedEntry.hasArcform,
        phase: updatedEntry.phase,
        geometry: updatedEntry.geometry,
        media: updatedMedia,
        createdAt: updatedEntry.createdAt,
      );
      
      // Update the entries list
      setState(() {
        _entries[entryIndex] = newEntry;
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo relinked successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToEditEntry(MediaItem mediaItem) {
    // Find the entry that contains this media item
    final entry = _entries.firstWhere(
      (e) => e.media.any((m) => m.id == mediaItem.id),
      orElse: () => _entries.first,
    );

    // Navigate directly to the full journal screen with the entry content
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => JournalScreen(
          initialContent: entry.preview,
          selectedEmotion: entry.phase, // Use phase as emotion context
          selectedReason: entry.geometry, // Use geometry as reason context
        ),
      ),
    );
  }

  void _showBrokenMediaDialog(MediaItem mediaItem) {
    showDialog(
      context: context,
      builder: (context) => BrokenMediaDialog(
        mediaItem: mediaItem,
        onRelinkMedia: () => _navigateToEditEntry(mediaItem),
      ),
    );
  }

  void _playAudio(String audioPath) async {
    try {
      if (Platform.isIOS) {
        // Try native iOS Photos framework first (for audio files in Photos library)
        final success = await _tryOpenSpecificMedia(audioPath);
        if (!success) {
          // Fallback: try to open the audio directly
          final uri = Uri.file(audioPath);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            _showAudioInfo(audioPath);
          }
        }
      } else {
        // Android: try to open the file directly
        final uri = Uri.file(audioPath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showAudioInfo(audioPath);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to play audio: $e'),
          backgroundColor: kcDangerColor,
        ),
      );
    }
  }

  void _playVideo(String videoPath) async {
    try {
      if (Platform.isIOS) {
        // Try native iOS Photos framework first
        final success = await _tryOpenSpecificVideo(videoPath);
        if (!success) {
          // Fallback: try to open the video directly
          final uri = Uri.file(videoPath);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            _showVideoInfo(videoPath);
          }
        }
      } else {
        // Android: try to open the file directly
        final uri = Uri.file(videoPath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showVideoInfo(videoPath);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to play video: $e'),
          backgroundColor: kcDangerColor,
        ),
      );
    }
  }

  void _openFile(String filePath) async {
    try {
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open file: ${filePath.split('/').last}'),
            backgroundColor: kcDangerColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open file: $e'),
          backgroundColor: kcDangerColor,
        ),
      );
    }
  }



  /// Show phase change dialog
  void _showPhaseChangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Change Phase',
          style: heading2Style(context),
        ),
        content: Text(
          'Select your current phase of life. This will affect your arcform patterns and insights.',
          style: bodyStyle(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to phase tab for phase change
              // This will allow the user to change their phase using the existing phase change UI
              _navigateToPhaseTab();
            },
            child: const Text('Change Phase'),
          ),
        ],
      ),
    );
  }

  /// Navigate to phase tab for phase change
  void _navigateToPhaseTab() {
    // This will be handled by the parent widget (HomeView) to switch to the phase tab
    // The phase tab already has the phase change functionality
    // We can emit an event or use a callback to notify the parent
    print('DEBUG: Navigate to phase tab for phase change');
    // For now, we'll just show a message that they should go to the phase tab
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Go to the Phase tab to change your phase'),
        action: SnackBarAction(
          label: 'Go to Phase',
          onPressed: () {
            // This would need to be implemented by the parent widget
            print('DEBUG: User wants to go to phase tab');
          },
        ),
      ),
    );
  }

  /// Build MCP media widget (MCP v2)
  Widget _buildMcpMediaImage(MediaItem item) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.green.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(item.uri),
        width: 60,
        height: 60,
        fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 60,
              height: 60,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
          },
        ),
      ),
    );
  }
}

class BrokenMediaDialog extends StatelessWidget {
  final MediaItem mediaItem;
  final VoidCallback onRelinkMedia;

  const BrokenMediaDialog({
    super.key,
    required this.mediaItem,
    required this.onRelinkMedia,
  });

  @override
  Widget build(BuildContext context) {
    final mediaTypeName = _getMediaTypeName(mediaItem.type);
    final mediaIcon = _getMediaTypeIcon(mediaItem.type);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                mediaIcon,
                color: Colors.red,
                size: 32,
              ),
            ),

            const SizedBox(height: 20),

            // Title
            Text(
              'Broken $mediaTypeName Link',
              style: heading2Style(context).copyWith(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Message
            Text(
              'The $mediaTypeName\'s link appears to be broken, please insert the $mediaTypeName again into the entry to relink it.',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Media info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$mediaTypeName Details:',
                    style: bodyStyle(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${mediaItem.id}',
                    style: bodyStyle(context).copyWith(
                      fontSize: 12,
                      color: kcSecondaryTextColor,
                    ),
                  ),
                  Text(
                    'Path: ${mediaItem.uri.split('/').last}',
                    style: bodyStyle(context).copyWith(
                      fontSize: 12,
                      color: kcSecondaryTextColor,
                    ),
                  ),
                  if (mediaItem.duration != null)
                    Text(
                      'Duration: ${_formatDuration(mediaItem.duration!)}',
                      style: bodyStyle(context).copyWith(
                        fontSize: 12,
                        color: kcSecondaryTextColor,
                      ),
                    ),
                  if (mediaItem.transcript != null &&
                      mediaItem.transcript!.isNotEmpty)
                    Text(
                      'Transcript: ${mediaItem.transcript!.length > 50 ? '${mediaItem.transcript!.substring(0, 50)}...' : mediaItem.transcript!}',
                      style: bodyStyle(context).copyWith(
                        fontSize: 12,
                        color: kcSecondaryTextColor,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onRelinkMedia();
                    },
                    icon: Icon(_getAddMediaIcon(mediaItem.type), size: 18),
                    label: Text('Re-insert $mediaTypeName'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getMediaTypeName(MediaType type) {
    switch (type) {
      case MediaType.image:
        return 'Image';
      case MediaType.video:
        return 'Video';
      case MediaType.audio:
        return 'Audio';
      case MediaType.file:
        return 'File';
    }
  }

  IconData _getMediaTypeIcon(MediaType type) {
    switch (type) {
      case MediaType.image:
        return Icons.broken_image;
      case MediaType.video:
        return Icons.videocam_off;
      case MediaType.audio:
        return Icons.audiotrack;
      case MediaType.file:
        return Icons.insert_drive_file;
    }
  }

  IconData _getAddMediaIcon(MediaType type) {
    switch (type) {
      case MediaType.image:
        return Icons.add_photo_alternate;
      case MediaType.video:
        return Icons.videocam;
      case MediaType.audio:
        return Icons.mic;
      case MediaType.file:
        return Icons.attach_file;
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class ArcformTimelinePainter extends CustomPainter {
  final bool isCurrentEntry;
  final TimelineEntry entry;
  final Color phaseColor;
  final GeometryPattern phaseGeometry;

  ArcformTimelinePainter({
    required this.isCurrentEntry,
    required this.entry,
    required this.phaseColor,
    required this.phaseGeometry,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCurrentEntry ? 2.5 : 1.5
      ..color = isCurrentEntry ? phaseColor : phaseColor.withOpacity(0.6);

    // Draw phase-specific geometry pattern
    if (entry.keywords.isEmpty) {
      _drawSimpleCircle(canvas, center, radius, paint);
    } else {
      _drawPhaseGeometry(canvas, center, radius, paint);
    }
  }

  void _drawSimpleCircle(
      Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawCircle(center, radius * 0.6, paint);
  }

  void _drawPhaseGeometry(
      Canvas canvas, Offset center, double radius, Paint paint) {
    final keywordCount = entry.keywords.length;

    switch (phaseGeometry) {
      case GeometryPattern.spiral:
        _drawSpiral(canvas, center, radius, paint, keywordCount);
        break;
      case GeometryPattern.flower:
        _drawFlower(canvas, center, radius, paint, keywordCount);
        break;
      case GeometryPattern.branch:
        _drawBranch(canvas, center, radius, paint, keywordCount);
        break;
      case GeometryPattern.weave:
        _drawWeave(canvas, center, radius, paint, keywordCount);
        break;
      case GeometryPattern.glowCore:
        _drawGlowCore(canvas, center, radius, paint, keywordCount);
        break;
      case GeometryPattern.fractal:
        _drawFractal(canvas, center, radius, paint, keywordCount);
        break;
    }
  }

  void _drawSpiral(Canvas canvas, Offset center, double radius, Paint paint,
      int keywordCount) {
    final path = Path();
    const double goldenAngle = 2.39996; // Golden angle
    final spiralPoints = math.max(12, keywordCount * 2);

    for (int i = 0; i < spiralPoints; i++) {
      final angle = i * goldenAngle;
      final r = radius * math.sqrt(i / spiralPoints.toDouble()) * 0.8;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawFlower(Canvas canvas, Offset center, double radius, Paint paint,
      int keywordCount) {
    final petalCount = math.max(5, keywordCount);
    final angleStep = (2 * math.pi) / petalCount;

    for (int i = 0; i < petalCount; i++) {
      final angle = i * angleStep;
      final petalRadius = radius * 0.7;
      final x = center.dx + petalRadius * math.cos(angle);
      final y = center.dy + petalRadius * math.sin(angle);

      canvas.drawLine(center, Offset(x, y), paint);
    }
    canvas.drawCircle(center, radius * 0.15, paint);
  }

  void _drawBranch(Canvas canvas, Offset center, double radius, Paint paint,
      int keywordCount) {
    // Main trunk
    canvas.drawLine(
      Offset(center.dx, center.dy + radius * 0.4),
      Offset(center.dx, center.dy - radius * 0.6),
      paint,
    );

    // Branches
    final branchCount = math.min(keywordCount, 4);
    for (int i = 0; i < branchCount; i++) {
      final angle = -math.pi + (i * math.pi / (branchCount + 1));
      final branchLength = radius * 0.5;
      final x = center.dx + branchLength * math.cos(angle);
      final y = center.dy + branchLength * math.sin(angle);

      canvas.drawLine(center, Offset(x, y), paint);
    }
  }

  void _drawWeave(Canvas canvas, Offset center, double radius, Paint paint,
      int keywordCount) {
    final gridSize = math.max(2, math.sqrt(keywordCount).ceil());
    final spacing = radius * 0.4 / gridSize;

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final x = center.dx + (i - gridSize / 2) * spacing;
        final y = center.dy + (j - gridSize / 2) * spacing;

        if (j < gridSize - 1) {
          canvas.drawLine(Offset(x, y), Offset(x, y + spacing), paint);
        }
        if (i < gridSize - 1) {
          canvas.drawLine(Offset(x, y), Offset(x + spacing, y), paint);
        }
      }
    }
  }

  void _drawGlowCore(Canvas canvas, Offset center, double radius, Paint paint,
      int keywordCount) {
    canvas.drawCircle(center, radius * 0.2, paint);

    final rayCount = math.min(keywordCount, 8);
    for (int i = 0; i < rayCount; i++) {
      final angle = (2 * math.pi * i) / rayCount;
      final x = center.dx + radius * 0.7 * math.cos(angle);
      final y = center.dy + radius * 0.7 * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), paint);
    }
  }

  void _drawFractal(Canvas canvas, Offset center, double radius, Paint paint,
      int keywordCount) {
    _drawFractalBranch(canvas, center, -math.pi / 2, radius * 0.6, 0, paint);
  }

  void _drawFractalBranch(Canvas canvas, Offset start, double angle,
      double length, int depth, Paint paint) {
    if (depth > 2 || length < 10) return;

    final endX = start.dx + length * math.cos(angle);
    final endY = start.dy + length * math.sin(angle);
    final end = Offset(endX, endY);

    canvas.drawLine(start, end, paint);

    final newLength = length * 0.7;
    _drawFractalBranch(
        canvas, end, angle - math.pi / 4, newLength, depth + 1, paint);
    _drawFractalBranch(
        canvas, end, angle + math.pi / 4, newLength, depth + 1, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is ArcformTimelinePainter &&
        (oldDelegate.isCurrentEntry != isCurrentEntry ||
            oldDelegate.entry != entry);
  }
}

class TimelineLinePainter extends CustomPainter {
  final int currentIndex;
  final int totalEntries;

  TimelineLinePainter({
    required this.currentIndex,
    required this.totalEntries,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalEntries <= 1) return;

    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Calculate the width of each segment
    final segmentWidth = size.width / totalEntries;

    // Draw the main timeline line
    for (int i = 0; i < totalEntries - 1; i++) {
      final startX = (i + 0.5) * segmentWidth;
      final endX = (i + 1.5) * segmentWidth;
      final centerY = size.height / 2;

      // Determine line color based on position relative to current entry
      if (i < currentIndex) {
        // Past entries - lighter color
        paint.color = kcSecondaryTextColor.withOpacity(0.3);
      } else if (i == currentIndex) {
        // Current entry - primary color
        paint.color = kcPrimaryColor;
      } else {
        // Future entries - lighter color
        paint.color = kcSecondaryTextColor.withOpacity(0.3);
      }

      canvas.drawLine(
        Offset(startX, centerY),
        Offset(endX, centerY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is TimelineLinePainter &&
        (oldDelegate.currentIndex != currentIndex ||
            oldDelegate.totalEntries != totalEntries);
  }
}

class AnalysisDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> analysisResult;

  const AnalysisDetailsDialog({
    super.key,
    required this.analysisResult,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.analytics,
                  color: kcPrimaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'iOS Vision Analysis Details',
                  style: heading2Style(context),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SelectableText(
                    _formatJson(analysisResult),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _copyToClipboard(context),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy JSON'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kcPrimaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatJson(Map<String, dynamic> json) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }

  void _copyToClipboard(BuildContext context) {
    final jsonString = _formatJson(analysisResult);
    Clipboard.setData(ClipboardData(text: jsonString));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Analysis JSON copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class BrokenImageDialog extends StatefulWidget {
  final MediaItem mediaItem;
  final VoidCallback onRelinkImage;
  final Function(MediaItem)? onPhotoRelinked;

  const BrokenImageDialog({
    super.key,
    required this.mediaItem,
    required this.onRelinkImage,
    this.onPhotoRelinked,
  });

  @override
  State<BrokenImageDialog> createState() => _BrokenImageDialogState();
}

class _BrokenImageDialogState extends State<BrokenImageDialog> {
  bool _showPhotoSearch = false;

  @override
  Widget build(BuildContext context) {
    final isPhotoLibraryUri = widget.mediaItem.uri.startsWith('ph://');
    final iconColor = isPhotoLibraryUri ? Colors.orange : Colors.red;
    final title =
        isPhotoLibraryUri ? 'Photo Library Reference' : 'Broken Image Link';
    final message = isPhotoLibraryUri
        ? 'This photo is from your photo library and may no longer be accessible. The original photo may have been deleted or moved. You can search your library to find and relink the correct photo.'
        : 'The image\'s link appears to be broken, please search your photo library to find and relink the correct image.';

    if (_showPhotoSearch) {
      return PhotoSearchDialog(
        originalMedia: widget.mediaItem,
        onPhotoSelected: (selectedPhoto) {
          Navigator.of(context).pop();
          widget.onPhotoRelinked?.call(selectedPhoto);
        },
        onCancel: () {
          setState(() {
            _showPhotoSearch = false;
          });
        },
      );
    }

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                isPhotoLibraryUri
                    ? Icons.photo_library_outlined
                    : Icons.broken_image,
                color: iconColor,
                size: 32,
              ),
            ),

            const SizedBox(height: 20),

            // Title
            Text(
              title,
              style: heading2Style(context).copyWith(
                color: iconColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Message
            Text(
              message,
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Image info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Image Details:',
                    style: bodyStyle(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${widget.mediaItem.id}',
                    style: bodyStyle(context).copyWith(
                      fontSize: 12,
                      color: kcSecondaryTextColor,
                    ),
                  ),
                  Text(
                    'Path: ${widget.mediaItem.uri.split('/').last}',
                    style: bodyStyle(context).copyWith(
                      fontSize: 12,
                      color: kcSecondaryTextColor,
                    ),
                  ),
                  if (widget.mediaItem.ocrText != null &&
                      widget.mediaItem.ocrText!.isNotEmpty)
                    Text(
                      'OCR Text: ${widget.mediaItem.ocrText!.length > 50 ? '${widget.mediaItem.ocrText!.substring(0, 50)}...' : widget.mediaItem.ocrText!}',
                      style: bodyStyle(context).copyWith(
                        fontSize: 12,
                        color: kcSecondaryTextColor,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Column(
              children: [
                // Search Photo Library button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showPhotoSearch = true;
                      });
                    },
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Search Photo Library'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Bottom row buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                      child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                          widget.onRelinkImage();
                    },
                    icon: const Icon(Icons.add_photo_alternate, size: 18),
                        label: const Text('Manual Insert'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kcPrimaryColor,
                          side: BorderSide(color: kcPrimaryColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for searching and selecting photos from the photo library
class PhotoSearchDialog extends StatefulWidget {
  final MediaItem originalMedia;
  final Function(MediaItem) onPhotoSelected;
  final VoidCallback onCancel;

  const PhotoSearchDialog({
    super.key,
    required this.originalMedia,
    required this.onPhotoSelected,
    required this.onCancel,
  });

  @override
  State<PhotoSearchDialog> createState() => _PhotoSearchDialogState();
}

class _PhotoSearchDialogState extends State<PhotoSearchDialog> {
  List<MediaItem> _photos = [];
  bool _isLoading = true;
  String _searchQuery = '';
  MediaItem? _selectedPhoto;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      // For now, return empty list since PhotoLibraryService doesn't have getPhotos method
      // In a real implementation, you would need to add this method to PhotoLibraryService
      setState(() {
        _photos = [];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading photos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<MediaItem> get _filteredPhotos {
    if (_searchQuery.isEmpty) return _photos;
    
    return _photos.where((photo) {
      final query = _searchQuery.toLowerCase();
      return photo.altText?.toLowerCase().contains(query) == true ||
             photo.ocrText?.toLowerCase().contains(query) == true ||
             photo.uri.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    'Search Photo Library',
                    style: heading2Style(context),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by text, date, or filename...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Photo grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredPhotos.isEmpty
                      ? Center(
                          child: Text(
                            'No photos found',
                            style: bodyStyle(context).copyWith(
                              color: kcSecondaryTextColor,
                            ),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: _filteredPhotos.length,
                          itemBuilder: (context, index) {
                            final photo = _filteredPhotos[index];
                            final isSelected = _selectedPhoto?.id == photo.id;
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPhoto = photo;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? kcPrimaryColor : Colors.grey[300]!,
                                    width: isSelected ? 3 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: FutureBuilder<bool>(
                                    future: _checkImageExists(photo.uri),
                                    builder: (context, snapshot) {
                                      final imageExists = snapshot.data ?? false;
                                      
                                      if (!imageExists) {
                                        return Container(
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                          ),
                                        );
                                      }
                                      
                                      return Image.file(
                                        File(photo.uri),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            
            // Action buttons
            if (_selectedPhoto != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onPhotoSelected(_selectedPhoto!);
                  },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  child: const Text('Select Photo'),
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

  Future<bool> _checkImageExists(String imagePath) async {
    try {
      final file = File(imagePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyHeaderDelegate({required this.child});

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

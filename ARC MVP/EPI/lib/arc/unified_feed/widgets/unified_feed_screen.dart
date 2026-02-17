/// Unified Feed Screen
///
/// The main screen for the merged LUMARA/Conversations experience.
/// Replaces both the old LumaraAssistantScreen (chat) and UnifiedJournalView
/// (timeline) with a single, scrollable feed that shows:
/// - Contextual greeting header
/// - LUMARA observation banner (if available)
/// - Active conversation (if any)
/// - Recent journal entries, saved conversations, voice memos
/// - Date dividers between groups
/// - Input bar at the bottom
///
/// App bar actions: Timeline (calendar), Voice memo, Settings
/// Behind feature flag: FeatureFlags.USE_UNIFIED_FEED

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';
import 'package:my_app/arc/unified_feed/repositories/feed_repository.dart';
import 'package:my_app/arc/unified_feed/services/conversation_manager.dart';
import 'package:my_app/arc/unified_feed/services/auto_save_service.dart';
import 'package:my_app/arc/unified_feed/utils/feed_helpers.dart';
import 'package:my_app/arc/unified_feed/widgets/feed_entry_cards/active_conversation_card.dart';
import 'package:my_app/arc/unified_feed/widgets/feed_entry_cards/saved_conversation_card.dart';
import 'package:my_app/arc/unified_feed/widgets/feed_entry_cards/voice_memo_card.dart';
import 'package:my_app/arc/unified_feed/widgets/feed_entry_cards/reflection_card.dart';
import 'package:my_app/arc/unified_feed/widgets/feed_entry_cards/lumara_prompt_card.dart';
import 'package:my_app/arc/unified_feed/widgets/expanded_entry_view.dart';
import 'package:my_app/arc/unified_feed/widgets/timeline/timeline_modal.dart';
import 'package:my_app/arc/internal/mira/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/ui/journal/journal_screen.dart';
import 'package:my_app/services/journal_session_cache.dart';
import 'package:my_app/shared/ui/settings/settings_view.dart';
import 'package:my_app/core/models/entry_mode.dart';
import 'package:my_app/shared/ui/onboarding/phase_quiz_v2_screen.dart';
import 'package:my_app/arc/unified_feed/widgets/import_options_sheet.dart';
import 'package:my_app/arc/chat/ui/lumara_assistant_screen.dart';
import 'package:my_app/ui/phase/phase_analysis_view.dart';
import 'package:my_app/ui/phase/phase_timeline_view.dart';
import 'package:my_app/ui/phase/simplified_arcform_view_3d.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/mira/store/arcx/services/arcx_export_service_v2.dart';
import 'package:my_app/mira/store/mcp/export/mcp_pack_export_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/services/export_history_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The main unified feed screen that merges LUMARA chat and Conversations.
class UnifiedFeedScreen extends StatefulWidget {
  /// Callback to launch voice mode (passed from HomeView which owns the
  /// voice session initialization logic).
  final VoidCallback? onVoiceTap;

  /// Optional initial mode to activate on first frame (from welcome screen).
  final EntryMode? initialMode;

  /// Called when the feed transitions between empty (welcome) and non-empty.
  /// HomeView uses this to hide/show the bottom navigation bar.
  final ValueChanged<bool>? onEmptyStateChanged;

  const UnifiedFeedScreen({
    super.key,
    this.onVoiceTap,
    this.initialMode,
    this.onEmptyStateChanged,
  });

  @override
  State<UnifiedFeedScreen> createState() => _UnifiedFeedScreenState();
}

class _UnifiedFeedScreenState extends State<UnifiedFeedScreen>
    with WidgetsBindingObserver {
  late FeedRepository _feedRepo;
  late ConversationManager _conversationManager;
  late AutoSaveService _autoSaveService;

  final ScrollController _scrollController = ScrollController();

  List<FeedEntry> _entries = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  
  // Scroll-to-top/bottom button state
  bool _showScrollToBottom = false;
  bool _showScrollToTop = false;
  double _lastScrollOffset = 0;

  /// If non-null, the feed is showing entries from a specific date
  DateTime? _currentViewingDate;

  /// Batch selection: when true, user can select entries to delete.
  bool _selectionModeEnabled = false;
  final Set<String> _selectedEntryIds = {};

  /// Bumped when returning from Phase view so the phase preview reloads (user may have changed phase).
  int _phasePreviewRefreshKey = 0;

  /// When true and feed is empty, show the welcome screen. When false, show the empty timeline (Chat/Reflect/Voice).
  bool _showWelcomeWhenEmpty = true;

  StreamSubscription<List<FeedEntry>>? _feedSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _initializeServices();

    // If an initial mode was passed (e.g. from welcome screen), trigger it
    if (widget.initialMode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleInitialMode(widget.initialMode!);
      });
    }
  }

  void _handleInitialMode(EntryMode mode) {
    switch (mode) {
      case EntryMode.chat:
        _openLumaraChat();
        break;
      case EntryMode.reflect:
        _onNewEntryTap();
        break;
      case EntryMode.voice:
        _startVoiceMemo();
        break;
    }
  }

  Future<void> _initializeServices() async {
    try {
      final journalRepo = JournalRepository();
      final chatRepo = ChatRepoImpl.instance;

      _feedRepo = FeedRepository(
        journalRepo: journalRepo,
        chatRepo: chatRepo,
      );

      _conversationManager = ConversationManager(
        feedRepo: _feedRepo,
        journalRepo: journalRepo,
      );

      _autoSaveService = AutoSaveService(
        conversationManager: _conversationManager,
      );

      _autoSaveService.onAutoSaveEvent = _handleAutoSaveEvent;
      _autoSaveService.initialize();

      // Subscribe to feed updates
      _feedSubscription = _feedRepo.feedStream.listen((entries) {
        if (mounted) {
          final wasEmpty = _entries.isEmpty;
          setState(() {
            _entries = entries;
            _isLoading = false;
          });
          // Notify parent when empty state changes
          if (wasEmpty != entries.isEmpty) {
            widget.onEmptyStateChanged?.call(entries.isEmpty);
          }
        }
      });

      // Initialize and load data
      await _feedRepo.initialize();

      // Report initial empty state to parent
      if (mounted) {
        widget.onEmptyStateChanged?.call(_entries.isEmpty);
      }
    } catch (e) {
      debugPrint('UnifiedFeedScreen: Error initializing: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load feed: $e';
        });
        // On error, report as empty so welcome screen shows without nav
        widget.onEmptyStateChanged?.call(true);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _autoSaveService.handleAppLifecycleChange(state);
  }

  void _onScroll() {
    // Load more when near the bottom
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      _loadOlderEntries();
    }
    
    // Update scroll button visibility based on position and direction
    final offset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final scrollingDown = offset > _lastScrollOffset;
    final scrollingUp = offset < _lastScrollOffset;
    
    // Thresholds: only show after meaningful scroll (150px from edges)
    const threshold = 150.0;
    final nearTop = offset < threshold;
    final nearBottom = offset > maxExtent - threshold;
    
    bool newShowBottom = false;
    bool newShowTop = false;
    
    if (scrollingDown && !nearBottom && maxExtent > 400) {
      // Scrolling down and not near bottom → show "jump to bottom"
      newShowBottom = true;
    } else if (scrollingUp && !nearTop && maxExtent > 400) {
      // Scrolling up and not near top → show "jump to top"
      newShowTop = true;
    }
    
    if (newShowBottom != _showScrollToBottom || newShowTop != _showScrollToTop) {
      setState(() {
        _showScrollToBottom = newShowBottom;
        _showScrollToTop = newShowTop;
      });
    }
    
    _lastScrollOffset = offset;
  }
  
  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
    setState(() {
      _showScrollToTop = false;
    });
  }
  
  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
    setState(() {
      _showScrollToBottom = false;
    });
  }

  Future<void> _loadOlderEntries() async {
    if (_entries.isEmpty || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    final oldest = _entries.last;
    final olderEntries = await _feedRepo.getFeed(
      before: oldest.timestamp,
      limit: 20,
    );

    if (mounted) {
      setState(() {
        if (olderEntries.isNotEmpty) {
          // Add only entries not already present
          final existingIds = _entries.map((e) => e.id).toSet();
          final newEntries =
              olderEntries.where((e) => !existingIds.contains(e.id));
          _entries.addAll(newEntries);
        }
        _isLoadingMore = false;
      });
    }
  }

  void _handleAutoSaveEvent(AutoSaveEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case AutoSaveEventType.saved:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation saved'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF059669),
          ),
        );
        break;
      case AutoSaveEventType.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: ${event.errorMessage}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
        break;
      default:
        break;
    }
  }

  void _jumpToDate(DateTime date) {
    setState(() {
      _currentViewingDate = date;
      _entries.clear();
      _isLoading = true;
    });

    _feedRepo.getFeed(
      after: DateTime(date.year, date.month, date.day),
      before: DateTime(date.year, date.month, date.day, 23, 59, 59),
      limit: 50,
    ).then((entries) {
      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    });
  }

  void _clearDateFilter() {
    setState(() {
      _currentViewingDate = null;
      _isLoading = true;
    });
    _feedRepo.refresh();
  }

  void _openTimelineModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TimelineModal(
        currentDate: _currentViewingDate ?? DateTime.now(),
        onDateSelected: (date) {
          Navigator.pop(context);
          _jumpToDate(date);
        },
      ),
    );
  }

  void _onNewEntryTap() async {
    await JournalSessionCache.clearSession();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const JournalScreen()),
    );
    _feedRepo.refresh();
  }

  void _onEntryTap(FeedEntry entry) {
    // Navigate to expanded entry view
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpandedEntryView(
          entry: entry,
          onEntryDeleted: () => _feedRepo.refresh(),
        ),
      ),
    ).then((result) {
      // If a theme filter was returned, apply it
      // (Future: implement theme-based filtering)
      _feedRepo.refresh();
    });
  }

  void _onSaveActiveConversation() {
    _conversationManager.saveConversation();
  }

  void _startVoiceMemo() {
    if (widget.onVoiceTap != null) {
      widget.onVoiceTap!();
    } else {
      debugPrint('UnifiedFeedScreen: No voice callback provided');
    }
  }

  String _getViewingContextTitle() {
    if (_currentViewingDate == null) return 'Your Journey';

    final now = DateTime.now();
    final diff = now.difference(_currentViewingDate!);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return 'This Week';
    if (diff.inDays < 30) return 'This Month';

    return DateFormat('MMMM yyyy').format(_currentViewingDate!);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: kcBackgroundColor,
        body: Column(
        children: [
          // Feed content with scroll-to-top/bottom overlay
          Expanded(
            child: Stack(
              children: [
                _isLoading
                    ? _buildLoadingState()
                    : _errorMessage != null
                        ? _buildErrorState()
                        : _buildFeedContent(),
                // Scroll-to-top / scroll-to-bottom button (centered bottom, like ChatGPT/Claude)
                if (_showScrollToBottom || _showScrollToTop)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: (_showScrollToBottom || _showScrollToTop) ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: _showScrollToBottom ? _scrollToBottom : _scrollToTop,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: kcSurfaceColor,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: kcPrimaryColor.withOpacity(0.3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _showScrollToBottom
                                        ? Icons.keyboard_arrow_down
                                        : Icons.keyboard_arrow_up,
                                    color: kcPrimaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _showScrollToBottom ? 'Jump to bottom' : 'Jump to top',
                                    style: TextStyle(
                                      color: kcPrimaryColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: kcPrimaryColor, strokeWidth: 2),
          SizedBox(height: 16),
          Text(
            'Loading your feed...',
            style: TextStyle(color: kcSecondaryTextColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: kcDangerColor, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Something went wrong',
              style: const TextStyle(color: kcPrimaryTextColor, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _initializeServices();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedContent() {
    if (_entries.isEmpty) {
      if (_showWelcomeWhenEmpty) return _buildEmptyState();
      return _buildEmptyTimeline();
    }

    final grouped = FeedHelpers.groupByDate(_entries);

    return RefreshIndicator(
      onRefresh: () async {
        await _feedRepo.refresh();
        // Notify phase preview and Gantt to refresh after pull-to-refresh
        PhaseRegimeService.regimeChangeNotifier.value = DateTime.now();
        UserPhaseService.phaseChangeNotifier.value = DateTime.now();
      },
      color: kcPrimaryColor,
      backgroundColor: kcSurfaceColor,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Greeting header
          SliverToBoxAdapter(child: _buildGreetingHeader()),

          // Calendar + Settings row
          SliverToBoxAdapter(child: _buildHeaderActions()),

          // Selection mode bar (Cancel / Delete selected)
          SliverToBoxAdapter(child: _buildSelectionModeBar()),

          // Phase card: same widget as Phase page (header + 3D constellation only); tap opens full Phase page
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: ValueKey('phase_preview_$_phasePreviewRefreshKey'),
              child: SimplifiedArcformView3D(
                cardOnly: true,
                onCardTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PhaseAnalysisView(),
                    ),
                  );
                  if (mounted) setState(() => _phasePreviewRefreshKey++);
                },
              ),
            ),
          ),

          // Phase info: Gantt-style diagram (days and phases) — below phase preview, above Chat|Reflect|Voice
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: ValueKey('phase_journey_$_phasePreviewRefreshKey'),
              child: _PhaseJourneyGanttCard(),
            ),
          ),

          // Chat | Reflect | Voice — above "Today", below phase preview
          SliverToBoxAdapter(child: _buildCommunicationActions()),

          // Date context banner (when viewing a specific date)
          if (_currentViewingDate != null)
            SliverToBoxAdapter(child: _buildDateContextBanner()),

          // LUMARA observation banner
          SliverToBoxAdapter(child: _buildLumaraObservationBanner()),

          const SliverToBoxAdapter(child: SizedBox(height: 4)),

          // Feed entries grouped by date
          for (final entry in grouped.entries) ...[
            // Date divider
            SliverToBoxAdapter(
              child: FeedHelpers.buildDateDivider(
                entry.key,
                entryCount: entry.value.length,
              ),
            ),

            // Entry cards (swipe left to delete when entry has journalEntryId)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final e = entry.value[index];
                  return _buildEntryCardWithSwipe(
                    e,
                    isSelectionMode: _selectionModeEnabled,
                    isSelected: _selectedEntryIds.contains(e.id),
                    onToggleSelect: () => setState(() {
                      if (_selectedEntryIds.contains(e.id)) {
                        _selectedEntryIds.remove(e.id);
                      } else {
                        _selectedEntryIds.add(e.id);
                      }
                    }),
                  );
                },
                childCount: entry.value.length,
              ),
            ),
          ],

          // Loading more indicator
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: kcPrimaryColor,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/icon/LUMARA_Sigil.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.psychology, size: 28,
                      color: kcPrimaryTextColor);
                },
              ),
              const SizedBox(width: 10),
              const Text(
                'LUMARA',
                style: TextStyle(
                  color: kcPrimaryTextColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Share what's on your mind.",
            style: TextStyle(
              color: kcPrimaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "I build context from your entries over time — your patterns, your phases, the decisions you're working through. The longer we work together, the more relevant my responses become.",
            style: TextStyle(
              color: kcSecondaryTextColor.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Select (batch delete)
          IconButton(
            icon: Icon(
              Icons.checklist,
              color: kcSecondaryTextColor.withOpacity(0.6),
              size: 22,
            ),
            tooltip: 'Select entries',
            onPressed: () => setState(() {
              _selectionModeEnabled = true;
              _selectedEntryIds.clear();
            }),
          ),
          // Timeline (calendar)
          IconButton(
            icon: Icon(
              Icons.calendar_month,
              color: kcSecondaryTextColor.withOpacity(0.6),
              size: 22,
            ),
            tooltip: 'Timeline',
            onPressed: _openTimelineModal,
          ),
          // Settings
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: kcSecondaryTextColor.withOpacity(0.6),
              size: 20,
            ),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SettingsView()),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Bar shown when in selection mode: Cancel and Delete selected.
  Widget _buildSelectionModeBar() {
    if (!_selectionModeEnabled) return const SizedBox.shrink();
    final n = _selectedEntryIds.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kcSurfaceAltColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kcBorderColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => setState(() {
              _selectionModeEnabled = false;
              _selectedEntryIds.clear();
            }),
            icon: const Icon(Icons.close, size: 20),
            label: const Text('Cancel'),
          ),
          const Spacer(),
          if (n > 0) ...[
            TextButton.icon(
              onPressed: () => _showExportOptions(),
              icon: Icon(Icons.upload_file, size: 20, color: kcPrimaryTextColor),
              label: Text('Export ($n)', style: TextStyle(color: kcPrimaryTextColor, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _deleteSelectedEntries(),
              icon: Icon(Icons.delete_outline, size: 20, color: Colors.red[400]),
              label: Text('Delete ($n)', style: TextStyle(color: Colors.red[400], fontWeight: FontWeight.w600)),
            ),
          ] else
            Text(
              'Tap entries to select',
              style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.7), fontSize: 13),
            ),
        ],
      ),
    );
  }

  /// Collect journal entry IDs from selected feed entries (only saved journal entries can be exported).
  List<String> _getSelectedJournalEntryIds() {
    return _entries
        .where((e) => _selectedEntryIds.contains(e.id) && e.journalEntryId != null && e.journalEntryId!.isNotEmpty)
        .map((e) => e.journalEntryId!)
        .toList();
  }

  void _showExportOptions() {
    final journalIds = _getSelectedJournalEntryIds();
    if (journalIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only saved journal entries can be exported. Select entries that have been saved to the timeline.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kcSurfaceAltColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Export ${journalIds.length} ${journalIds.length == 1 ? 'entry' : 'entries'} as',
                style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.9), fontSize: 14),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.folder_special, color: kcPrimaryColor),
                title: const Text('LUMARA archive (.arcx)'),
                subtitle: const Text('Encrypted backup format, best for restore'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportSelectedAsArcx();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_zip, color: kcPrimaryColor),
                title: const Text('ZIP file (.zip)'),
                subtitle: const Text('Standard zip, portable'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportSelectedAsZip();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportSelectedAsArcx() async {
    final journalIds = _getSelectedJournalEntryIds();
    if (journalIds.isEmpty || !mounted) return;
    final journalRepo = context.read<JournalRepository>();
    ChatRepoImpl? chatRepo;
    PhaseRegimeService? phaseRegimeService;
    try {
      chatRepo = context.read<ChatRepoImpl>();
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
    } catch (_) {}
    final exportService = ARCXExportServiceV2(
      journalRepo: journalRepo,
      chatRepo: chatRepo,
      phaseRegimeService: phaseRegimeService,
    );
    final exportsDir = Directory(path.join((await getApplicationDocumentsDirectory()).path, 'exports'));
    if (!await exportsDir.exists()) await exportsDir.create(recursive: true);
    final progressNotifier = ValueNotifier<String>('Preparing export...');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<String>(
        valueListenable: progressNotifier,
        builder: (_, progress, __) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(progress, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
    try {
      final exportNumber = await ExportHistoryService.instance.getNextExportNumber();
      final result = await exportService.export(
        selection: ARCXExportSelection(entryIds: journalIds),
        options: ARCXExportOptions(strategy: ARCXExportStrategy.together, encrypt: true, compression: 'auto', dedupeMedia: true, includeChecksums: true),
        outputDir: exportsDir,
        password: null,
        onProgress: (msg) {
          if (mounted) progressNotifier.value = msg;
        },
        exportNumber: exportNumber,
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (result.success && result.arcxPath != null) {
        await Share.shareXFiles([XFile(result.arcxPath!)], text: 'Exported ${journalIds.length} entries as ARCX');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported ${journalIds.length} entries')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error ?? 'Export failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _exportSelectedAsZip() async {
    final journalIds = _getSelectedJournalEntryIds();
    if (journalIds.isEmpty || !mounted) return;
    final journalRepo = context.read<JournalRepository>();
    final entries = <JournalEntry>[];
    for (final id in journalIds) {
      final entry = await journalRepo.getJournalEntryById(id);
      if (entry != null) entries.add(entry);
    }
    if (entries.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No entries could be loaded')));
      return;
    }
    ChatRepoImpl? chatRepo;
    PhaseRegimeService? phaseRegimeService;
    try {
      chatRepo = context.read<ChatRepoImpl>();
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
    } catch (_) {}
    final appDir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final outputPath = path.join(appDir.path, 'export_$timestamp.zip');
    final progressNotifier = ValueNotifier<String>('Preparing ZIP export...');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<String>(
        valueListenable: progressNotifier,
        builder: (_, progress, __) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(progress, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
    try {
      final mcpService = McpPackExportService(
        bundleId: 'export_$timestamp',
        outputPath: outputPath,
        chatRepo: chatRepo,
        phaseRegimeService: phaseRegimeService,
      );
      if (mounted) progressNotifier.value = 'Exporting entries...';
      final result = await mcpService.exportJournal(
        entries: entries,
        includePhotos: true,
        reducePhotoSize: false,
        includeChats: false,
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (result.success && result.outputPath != null) {
        await Share.shareXFiles([XFile(result.outputPath!)], text: 'Exported ${entries.length} entries as ZIP');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported ${entries.length} entries')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error ?? 'Export failed'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteSelectedEntries() async {
    final toDelete = _entries.where((e) => _selectedEntryIds.contains(e.id)).toList();
    if (toDelete.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected entries?'),
        content: Text(
          '${toDelete.length} journal ${toDelete.length == 1 ? 'entry' : 'entries'} will be permanently deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final journalRepo = JournalRepository();
    for (final entry in toDelete) {
      final id = entry.journalEntryId;
      if (id != null && id.isNotEmpty) {
        try {
          await journalRepo.deleteJournalEntry(id);
        } catch (_) {}
      }
    }
    setState(() {
      _selectionModeEnabled = false;
      _selectedEntryIds.clear();
    });
    await _feedRepo.refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${toDelete.length} ${toDelete.length == 1 ? 'entry' : 'entries'} deleted')),
    );
  }

  /// Chat | Reflect | Voice row — above "Today", below calendar and gear.
  Widget _buildCommunicationActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildEmptyStateAction(
            icon: Icons.chat_bubble_outline,
            label: 'Chat',
            onTap: _openLumaraChat,
          ),
          const SizedBox(width: 16),
          _buildEmptyStateAction(
            icon: Icons.edit_note,
            label: 'Reflect',
            onTap: _onNewEntryTap,
          ),
          const SizedBox(width: 16),
          _buildEmptyStateAction(
            icon: Icons.mic,
            label: 'Voice',
            onTap: _startVoiceMemo,
          ),
        ],
      ),
    );
  }

  /// Open LUMARA chat to a new conversation (no auto-submit of reflection or previous message).
  void _openLumaraChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LumaraAssistantScreen(),
      ),
    );
  }

  Widget _buildDateContextBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kcPrimaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kcPrimaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 16, color: kcPrimaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Viewing: ${_getViewingContextTitle()}',
              style: TextStyle(
                color: kcPrimaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: _clearDateFilter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kcPrimaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Back to Now',
                style: TextStyle(
                  color: kcPrimaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLumaraObservationBanner() {
    // TODO: Integrate with CHRONICLE/VEIL/SENTINEL for real observations
    // For now, returns empty. When observation data is available,
    // this will display a subtle banner users can tap to engage with.
    return const SizedBox.shrink();
  }

  /// [onTapOverride] When non-null (e.g. in selection mode), used as the card's onTap
  /// so the whole entry is the selection target instead of opening the entry.
  Widget _buildEntryCard(FeedEntry entry, {VoidCallback? onTapOverride}) {
    final onTap = onTapOverride ?? () => _onEntryTap(entry);
    switch (entry.type) {
      case FeedEntryType.activeConversation:
        return ActiveConversationCard(
          entry: entry,
          onTap: onTap,
          onSave: _onSaveActiveConversation,
        );
      case FeedEntryType.savedConversation:
        return SavedConversationCard(
          entry: entry,
          onTap: onTap,
        );
      case FeedEntryType.voiceMemo:
        return VoiceMemoCard(
          entry: entry,
          onTap: onTap,
        );
      case FeedEntryType.reflection:
        return ReflectionCard(
          entry: entry,
          onTap: onTap,
        );
      case FeedEntryType.lumaraInitiative:
        return LumaraPromptCard(
          entry: entry,
          onTap: onTap,
        );
    }
  }

  /// Wraps the card in Dismissible (swipe left to delete) and/or selection overlay when applicable.
  /// In selection mode, the whole card uses [onToggleSelect] as its tap target so the full entry is selectable.
  Widget _buildEntryCardWithSwipe(
    FeedEntry entry, {
    bool isSelectionMode = false,
    bool isSelected = false,
    VoidCallback? onToggleSelect,
  }) {
    final useSelectionTap = isSelectionMode && onToggleSelect != null;
    final card = _buildEntryCard(
      entry,
      onTapOverride: useSelectionTap ? onToggleSelect : null,
    );
    final journalEntryId = entry.journalEntryId;
    final canDelete = journalEntryId != null && journalEntryId.isNotEmpty;

    Widget wrapped = card;
    if (canDelete) {
      wrapped = Dismissible(
        key: ValueKey(entry.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
        ),
        confirmDismiss: (direction) async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete entry?'),
              content: const Text(
                'This journal entry will be permanently deleted. This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          return confirmed == true;
        },
        onDismissed: (_) => _deleteFeedEntry(entry),
        child: card,
      );
    }

    if (isSelectionMode && canDelete && onToggleSelect != null) {
      wrapped = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggleSelect,
        child: Stack(
          children: [
            wrapped,
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? kcPrimaryColor : kcSurfaceColor,
                  border: Border.all(color: kcBorderColor),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected ? Icons.check : Icons.circle_outlined,
                  size: 24,
                  color: isSelected ? Colors.white : kcSecondaryTextColor,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return wrapped;
  }

  Future<void> _deleteFeedEntry(FeedEntry entry) async {
    final id = entry.journalEntryId;
    if (id == null || id.isEmpty) return;
    try {
      final journalRepo = JournalRepository();
      await journalRepo.deleteJournalEntry(id);
      await _feedRepo.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Empty timeline: same layout as the feed (greeting, phase, Chat|Reflect|Voice) with no entries.
  Widget _buildEmptyTimeline() {
    return RefreshIndicator(
      onRefresh: () async {
        await _feedRepo.refresh();
        PhaseRegimeService.regimeChangeNotifier.value = DateTime.now();
        UserPhaseService.phaseChangeNotifier.value = DateTime.now();
      },
      color: kcPrimaryColor,
      backgroundColor: kcSurfaceColor,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildGreetingHeader()),
          SliverToBoxAdapter(child: _buildHeaderActions()),
          SliverToBoxAdapter(child: _buildSelectionModeBar()),
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: ValueKey('phase_preview_$_phasePreviewRefreshKey'),
              child: SimplifiedArcformView3D(
                cardOnly: true,
                onCardTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PhaseAnalysisView(),
                    ),
                  );
                  if (mounted) setState(() => _phasePreviewRefreshKey++);
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: ValueKey('phase_journey_$_phasePreviewRefreshKey'),
              child: _PhaseJourneyGanttCard(),
            ),
          ),
          SliverToBoxAdapter(child: _buildCommunicationActions()),
          if (_currentViewingDate != null)
            SliverToBoxAdapter(child: _buildDateContextBanner()),
          SliverToBoxAdapter(child: _buildLumaraObservationBanner()),
          const SliverToBoxAdapter(child: SizedBox(height: 4)),
          SliverToBoxAdapter(
            child: FeedHelpers.buildDateDivider('Today', entryCount: 0),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Text(
                'Your entries will appear here. Use Chat, Reflect, or Voice above to get started.',
                style: TextStyle(
                  color: kcSecondaryTextColor.withOpacity(0.7),
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SafeArea(
      child: Stack(
        children: [
          // Settings gear — top right
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: Icon(
                Icons.settings_outlined,
                color: kcSecondaryTextColor.withOpacity(0.5),
                size: 24,
              ),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsView()),
                );
              },
            ),
          ),

          // Main welcome content — centered
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // LUMARA logo
                  Image.asset(
                    'assets/icon/LUMARA_Sigil.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.psychology,
                          size: 72, color: kcPrimaryColor);
                    },
                  ),
                  const SizedBox(height: 28),

                  // Title
                  const Text(
                    'Welcome to LUMARA',
                    style: TextStyle(
                      color: kcPrimaryTextColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Subtitle
                  Text(
                    'Chat with LUMARA, reflect on your journey,\nor capture your thoughts by voice.',
                    style: TextStyle(
                      color: kcSecondaryTextColor.withOpacity(0.7),
                      fontSize: 15,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Get started — go to empty timeline (Chat / Reflect / Voice)
                  _buildGetStartedButton(),
                  const SizedBox(height: 20),

                  // Phase Quiz button — prominent, centered
                  _buildPhaseQuizButton(),
                  const SizedBox(height: 48),

                  // Import section
                  Divider(
                    color: kcBorderColor.withOpacity(0.3),
                    thickness: 1,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Already have journal entries?',
                    style: TextStyle(
                      color: kcSecondaryTextColor.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => _showImportOptions(),
                    icon: const Icon(
                      Icons.upload_outlined,
                      color: kcPrimaryColor,
                      size: 20,
                    ),
                    label: const Text(
                      'Import your data',
                      style: TextStyle(
                        color: kcPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get started button — takes user to the empty timeline (Chat / Reflect / Voice).
  Widget _buildGetStartedButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _showWelcomeWhenEmpty = false);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: kcSurfaceAltColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kcPrimaryColor.withOpacity(0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, color: kcPrimaryColor, size: 22),
            SizedBox(width: 10),
            Text(
              'Get started',
              style: TextStyle(
                color: kcPrimaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Prominent Phase Quiz button for the welcome screen.
  Widget _buildPhaseQuizButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const PhaseQuizV2Screen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          gradient: kcPrimaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kcPrimaryColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              'Discover Your Phase',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show the import options bottom sheet.
  Future<void> _showImportOptions() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ImportOptionsSheet(),
    );
    // Refresh the feed after the import sheet closes so newly imported
    // entries appear and the welcome screen transitions to the feed.
    if (mounted) {
      await _feedRepo.refresh();
    }
  }

  Widget _buildEmptyStateAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: kcSurfaceAltColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kcBorderColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: kcPrimaryColor, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: kcPrimaryTextColor.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feedSubscription?.cancel();
    _scrollController.dispose();
    _conversationManager.dispose();
    _autoSaveService.dispose();
    _feedRepo.dispose();
    super.dispose();
  }
}

/// Phase info section: Gantt-style diagram of days and phases (below phase preview, above Chat|Reflect|Voice).
class _PhaseJourneyGanttCard extends StatefulWidget {
  @override
  State<_PhaseJourneyGanttCard> createState() => _PhaseJourneyGanttCardState();
}

class _PhaseJourneyGanttCardState extends State<_PhaseJourneyGanttCard> {
  List<PhaseRegime>? _regimes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRegimes();
    
    // Listen for phase/regime changes and reload
    PhaseRegimeService.regimeChangeNotifier.addListener(_onRegimeChanged);
    UserPhaseService.phaseChangeNotifier.addListener(_onRegimeChanged);
  }
  
  @override
  void dispose() {
    PhaseRegimeService.regimeChangeNotifier.removeListener(_onRegimeChanged);
    UserPhaseService.phaseChangeNotifier.removeListener(_onRegimeChanged);
    super.dispose();
  }
  
  void _onRegimeChanged() {
    if (mounted) {
      print('DEBUG: Phase Journey Gantt detected phase/regime change, reloading...');
      _loadRegimes();
    }
  }

  /// Display end for the most recent regime (last entry date in range) so the Gantt tracks to the last entries.
  DateTime? _displayEndForLastRegime;

  Future<void> _loadRegimes() async {
    try {
      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      final regimes = phaseRegimeService.phaseIndex.allRegimes;
      DateTime? displayEnd;
      if (regimes.isNotEmpty) {
        final sorted = List<PhaseRegime>.from(regimes)..sort((a, b) => a.start.compareTo(b.start));
        final last = sorted.last;
        displayEnd = phaseRegimeService.getLastEntryDateInRange(
          last.start,
          last.end ?? DateTime.now(),
        );
      }
      if (mounted) {
        setState(() {
          _regimes = regimes.isEmpty ? null : List<PhaseRegime>.from(regimes);
          _displayEndForLastRegime = displayEnd;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _regimes = null; _displayEndForLastRegime = null; _loading = false; });
    }
  }

  static String _formatShortDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _regimes == null || _regimes!.isEmpty) {
      return const SizedBox.shrink();
    }
    final regimes = List<PhaseRegime>.from(_regimes!)
      ..sort((a, b) => a.start.compareTo(b.start));
    final lastRegime = regimes.last;
    final effectiveEnd = _displayEndForLastRegime != null &&
            _displayEndForLastRegime!.isAfter(lastRegime.start)
        ? _displayEndForLastRegime!
        : (lastRegime.end ?? DateTime.now());
    final displayRegimes = regimes.length == 1
        ? [lastRegime.copyWith(end: effectiveEnd)]
        : [
            ...regimes.sublist(0, regimes.length - 1),
            lastRegime.copyWith(end: effectiveEnd),
          ];
    final visibleStart = regimes.first.start;
    final visibleEnd = effectiveEnd;
    final totalDays = visibleEnd.difference(visibleStart).inDays;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kcPrimaryColor.withOpacity(0.25)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            // Go directly to editable PhaseTimelineView (via PhaseAnalysisView's Timeline tab)
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PhaseAnalysisView(initialView: 'timeline'),
              ),
            );
            if (mounted) _loadRegimes();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timeline, size: 20, color: kcPrimaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your phase journey',
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_calendar, size: 20),
                    tooltip: 'Edit phases',
                    onPressed: () async {
                      // Edit button also goes to editable timeline
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PhaseAnalysisView(initialView: 'timeline'),
                        ),
                      );
                      if (mounted) _loadRegimes();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    style: IconButton.styleFrom(
                      foregroundColor: kcSecondaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Days and phases over time',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CustomPaint(
                    painter: PhaseTimelinePainter(
                      regimes: displayRegimes,
                      visibleStart: visibleStart,
                      visibleEnd: visibleEnd,
                      zoomLevel: 1.0,
                      theme: theme,
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatShortDate(visibleStart),
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 10,
                ),
              ),
              Text(
                '$totalDays days • ${regimes.length} phases',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 10,
                ),
              ),
              Text(
                _formatShortDate(visibleEnd),
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 10,
                ),
              ),
            ],
          ),
            ],
          ),
        ),
      ),
    );
  }
}

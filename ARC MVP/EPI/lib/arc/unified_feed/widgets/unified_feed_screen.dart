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
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';
import 'package:my_app/arc/unified_feed/repositories/feed_repository.dart';
import 'package:my_app/arc/unified_feed/services/contextual_greeting.dart';
import 'package:my_app/arc/unified_feed/services/conversation_manager.dart';
import 'package:my_app/arc/unified_feed/services/auto_save_service.dart';
import 'package:my_app/arc/unified_feed/utils/feed_helpers.dart';
import 'package:my_app/arc/unified_feed/widgets/input_bar.dart';
import 'package:my_app/arc/unified_feed/widgets/feed_entry_cards/active_conversation_card.dart';
import 'package:my_app/arc/unified_feed/widgets/feed_entry_cards/saved_conversation_card.dart';
import 'package:my_app/arc/unified_feed/widgets/feed_entry_cards/voice_memo_card.dart';
import 'package:my_app/arc/unified_feed/widgets/feed_entry_cards/reflection_card.dart';
import 'package:my_app/arc/unified_feed/widgets/feed_entry_cards/lumara_prompt_card.dart';
import 'package:my_app/arc/unified_feed/widgets/expanded_entry_view.dart';
import 'package:my_app/arc/unified_feed/widgets/timeline/timeline_modal.dart';
import 'package:my_app/arc/internal/mira/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/ui/journal/journal_screen.dart';
import 'package:my_app/services/journal_session_cache.dart';
import 'package:my_app/shared/ui/settings/settings_view.dart';
import 'package:my_app/core/models/entry_mode.dart';
import 'package:my_app/shared/ui/onboarding/phase_quiz_v2_screen.dart';
import 'package:my_app/arc/unified_feed/widgets/import_options_sheet.dart';

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
  final ContextualGreetingService _greetingService =
      ContextualGreetingService();

  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  List<FeedEntry> _entries = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  /// If non-null, the feed is showing entries from a specific date
  DateTime? _currentViewingDate;

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
        _focusInputBar();
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

  void _onMessageSubmit(String text) {
    _conversationManager.addUserMessage(text);
    debugPrint(
        'UnifiedFeedScreen: User message recorded: ${text.substring(0, text.length > 50 ? 50 : text.length)}');
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
        builder: (context) => ExpandedEntryView(entry: entry),
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

  /// Focus the input bar (triggered by the "Chat" button in the empty state).
  void _focusInputBar() {
    _inputFocusNode.requestFocus();
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
          // Feed content
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                    ? _buildErrorState()
                    : _buildFeedContent(),
          ),

          // Input bar — hidden during empty/welcome state
          if (!_isLoading && _errorMessage == null && _entries.isNotEmpty)
            FeedInputBar(
              onSubmit: _onMessageSubmit,
              onNewEntryTap: _onNewEntryTap,
              onVoiceTap: _startVoiceMemo,
              focusNode: _inputFocusNode,
              onAttachmentTap: () {
                debugPrint('UnifiedFeedScreen: Attachment tap');
              },
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
    if (_entries.isEmpty) return _buildEmptyState();

    final grouped = FeedHelpers.groupByDate(_entries);

    return RefreshIndicator(
      onRefresh: () => _feedRepo.refresh(),
      color: kcPrimaryColor,
      backgroundColor: kcSurfaceColor,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Greeting header
          SliverToBoxAdapter(child: _buildGreetingHeader()),

          // Action buttons row (Timeline, Voice, Settings)
          SliverToBoxAdapter(child: _buildHeaderActions()),

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

            // Entry cards
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildEntryCard(entry.value[index]),
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
    final now = DateTime.now();
    DateTime? lastEntryAt;
    int todayCount = 0;

    for (final entry in _entries) {
      if (lastEntryAt == null || entry.timestamp.isAfter(lastEntryAt)) {
        lastEntryAt = entry.timestamp;
      }
      if (entry.timestamp.year == now.year &&
          entry.timestamp.month == now.month &&
          entry.timestamp.day == now.day) {
        todayCount++;
      }
    }

    final greeting = _greetingService.generateGreeting(
      lastEntryAt: lastEntryAt,
      entryCount: _entries.length,
    );
    final subGreeting = _greetingService.generateSubGreeting(
      lastEntryAt: lastEntryAt,
      activeConversationCount:
          _conversationManager.hasActiveConversation ? 1 : 0,
      todayEntryCount: todayCount,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/icon/LUMARA_Sigil_White.png',
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
          Text(
            greeting,
            style: const TextStyle(
              color: kcPrimaryTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subGreeting,
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
          // Timeline
          IconButton(
            icon: Icon(
              Icons.calendar_month,
              color: kcSecondaryTextColor.withOpacity(0.6),
              size: 22,
            ),
            tooltip: 'Timeline',
            onPressed: _openTimelineModal,
          ),
          // Voice memo
          IconButton(
            icon: Icon(
              Icons.mic,
              color: kcSecondaryTextColor.withOpacity(0.6),
              size: 22,
            ),
            tooltip: 'Voice memo',
            onPressed: _startVoiceMemo,
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

  Widget _buildEntryCard(FeedEntry entry) {
    switch (entry.type) {
      case FeedEntryType.activeConversation:
        return ActiveConversationCard(
          entry: entry,
          onTap: () => _onEntryTap(entry),
          onSave: _onSaveActiveConversation,
        );
      case FeedEntryType.savedConversation:
        return SavedConversationCard(
          entry: entry,
          onTap: () => _onEntryTap(entry),
        );
      case FeedEntryType.voiceMemo:
        return VoiceMemoCard(
          entry: entry,
          onTap: () => _onEntryTap(entry),
        );
      case FeedEntryType.reflection:
        return ReflectionCard(
          entry: entry,
          onTap: () => _onEntryTap(entry),
        );
      case FeedEntryType.lumaraInitiative:
        return LumaraPromptCard(
          entry: entry,
          onTap: () => _onEntryTap(entry),
        );
    }
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
                    'assets/icon/LUMARA_Sigil_White.png',
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
                  const SizedBox(height: 32),

                  // Phase Quiz button — prominent, centered
                  _buildPhaseQuizButton(),
                  const SizedBox(height: 24),

                  // Chat | Reflect | Voice — quick-start actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildEmptyStateAction(
                        icon: Icons.chat_bubble_outline,
                        label: 'Chat',
                        onTap: _focusInputBar,
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
  void _showImportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ImportOptionsSheet(),
    );
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
    _inputFocusNode.dispose();
    _conversationManager.dispose();
    _autoSaveService.dispose();
    _feedRepo.dispose();
    super.dispose();
  }
}

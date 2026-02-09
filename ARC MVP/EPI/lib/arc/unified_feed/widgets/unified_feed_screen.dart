/// Unified Feed Screen
///
/// The main screen for the merged LUMARA/Conversations experience.
/// Replaces both the old LumaraAssistantScreen (chat) and UnifiedJournalView
/// (timeline) with a single, scrollable feed that shows:
/// - Contextual greeting header
/// - Active conversation (if any)
/// - Recent journal entries, saved conversations, voice memos
/// - Input bar at the bottom
///
/// Behind feature flag: FeatureFlags.USE_UNIFIED_FEED

import 'dart:async';
import 'package:flutter/material.dart';
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
import 'package:my_app/arc/unified_feed/widgets/feed_entry_cards/written_entry_card.dart';
import 'package:my_app/arc/internal/mira/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo_impl.dart';
import 'package:my_app/ui/journal/journal_screen.dart';
import 'package:my_app/services/journal_session_cache.dart';
import 'package:my_app/shared/ui/settings/settings_view.dart';

/// The main unified feed screen that merges LUMARA chat and Conversations.
class UnifiedFeedScreen extends StatefulWidget {
  const UnifiedFeedScreen({super.key});

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

  List<FeedEntry> _entries = [];
  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription<List<FeedEntry>>? _feedSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
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
          setState(() {
            _entries = entries;
            _isLoading = false;
          });
        }
      });

      // Initialize and load data
      await _feedRepo.initialize();
    } catch (e) {
      debugPrint('UnifiedFeedScreen: Error initializing: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load feed: $e';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _autoSaveService.handleAppLifecycleChange(state);
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

  void _onMessageSubmit(String text) {
    _conversationManager.addUserMessage(text);
    // In Phase 2, this will trigger the LLM call via EnhancedLumaraAPI.
    // For now, just record the message in the conversation tracker.
    debugPrint('UnifiedFeedScreen: User message recorded: ${text.substring(0, text.length > 50 ? 50 : text.length)}');
  }

  void _onNewEntryTap() async {
    await JournalSessionCache.clearSession();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JournalScreen(),
      ),
    );
    // Refresh feed after returning from journal
    _feedRepo.refresh();
  }

  void _onEntryTap(FeedEntry entry) {
    if (entry.journalEntryId != null) {
      _openJournalEntry(entry.journalEntryId!);
    } else if (entry.chatSessionId != null) {
      // TODO: Open chat session in conversation view
      debugPrint('UnifiedFeedScreen: Open chat session ${entry.chatSessionId}');
    } else if (entry.voiceNoteId != null) {
      // TODO: Open voice note detail
      debugPrint('UnifiedFeedScreen: Open voice note ${entry.voiceNoteId}');
    }
  }

  Future<void> _openJournalEntry(String entryId) async {
    try {
      final repo = JournalRepository();
      final entry = await repo.getJournalEntryById(entryId);
      if (!mounted) return;
      if (entry != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JournalScreen(
              existingEntry: entry,
              isViewOnly: true,
            ),
          ),
        );
        _feedRepo.refresh();
      }
    } catch (e) {
      debugPrint('UnifiedFeedScreen: Error opening journal entry: $e');
    }
  }

  void _onSaveActiveConversation() {
    _conversationManager.saveConversation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

          // Input bar
          FeedInputBar(
            onSubmit: _onMessageSubmit,
            onNewEntryTap: _onNewEntryTap,
            onVoiceTap: () {
              // TODO: Phase 2 - voice recording
              debugPrint('UnifiedFeedScreen: Voice tap');
            },
            onAttachmentTap: () {
              // TODO: Phase 2 - attachments
              debugPrint('UnifiedFeedScreen: Attachment tap');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: kcPrimaryColor,
            strokeWidth: 2,
          ),
          SizedBox(height: 16),
          Text(
            'Loading your feed...',
            style: TextStyle(
              color: kcSecondaryTextColor,
              fontSize: 14,
            ),
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
            const Icon(
              Icons.error_outline,
              color: kcDangerColor,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Something went wrong',
              style: const TextStyle(
                color: kcPrimaryTextColor,
                fontSize: 16,
              ),
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
      return _buildEmptyState();
    }

    // Group entries by date
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

          // Settings button row
          SliverToBoxAdapter(child: _buildHeaderActions()),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Feed entries grouped by date
          for (final entry in grouped.entries) ...[
            // Section header
            SliverToBoxAdapter(
              child: _buildSectionHeader(entry.key),
            ),

            // Entry cards
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildEntryCard(entry.value[index]);
                },
                childCount: entry.value.length,
              ),
            ),
          ],

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
      if (lastEntryAt == null || entry.updatedAt.isAfter(lastEntryAt)) {
        lastEntryAt = entry.updatedAt;
      }
      if (entry.createdAt.year == now.year &&
          entry.createdAt.month == now.month &&
          entry.createdAt.day == now.day) {
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
              // LUMARA sigil
              Image.asset(
                'assets/icon/LUMARA_Sigil_White.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.psychology,
                    size: 28,
                    color: kcPrimaryTextColor,
                  );
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Settings
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: kcSecondaryTextColor.withOpacity(0.6),
              size: 20,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsView(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        title,
        style: TextStyle(
          color: kcSecondaryTextColor.withOpacity(0.6),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
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
      case FeedEntryType.writtenEntry:
        return WrittenEntryCard(
          entry: entry,
          onTap: () => _onEntryTap(entry),
        );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icon/LUMARA_Sigil_White.png',
              width: 64,
              height: 64,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.psychology,
                  size: 64,
                  color: kcPrimaryColor,
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome to LUMARA',
              style: TextStyle(
                color: kcPrimaryTextColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation, write a journal entry,\nor record a voice memo.',
              style: TextStyle(
                color: kcSecondaryTextColor.withOpacity(0.7),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildEmptyStateAction(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  onTap: () {
                    // Focus the input bar
                  },
                ),
                const SizedBox(width: 16),
                _buildEmptyStateAction(
                  icon: Icons.edit_note,
                  label: 'Write',
                  onTap: _onNewEntryTap,
                ),
                const SizedBox(width: 16),
                _buildEmptyStateAction(
                  icon: Icons.mic,
                  label: 'Voice',
                  onTap: () {
                    // TODO: Voice recording
                  },
                ),
              ],
            ),
          ],
        ),
      ),
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
          border: Border.all(
            color: kcBorderColor.withOpacity(0.3),
          ),
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

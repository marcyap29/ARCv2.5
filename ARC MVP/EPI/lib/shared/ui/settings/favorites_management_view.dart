import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:my_app/arc/chat/data/models/lumara_favorite.dart';
import 'package:my_app/arc/ui/timeline/favorite_journal_entries_view.dart';
import 'package:my_app/arc/chat/chat/ui/enhanced_chats_screen.dart';

/// Screen for managing LUMARA favorites
class FavoritesManagementView extends StatefulWidget {
  const FavoritesManagementView({super.key});

  @override
  State<FavoritesManagementView> createState() => _FavoritesManagementViewState();
}

class _FavoritesManagementViewState extends State<FavoritesManagementView> with SingleTickerProviderStateMixin {
  final FavoritesService _favoritesService = FavoritesService.instance;
  List<LumaraFavorite> _answers = [];
  List<LumaraFavorite> _savedChats = [];
  List<LumaraFavorite> _favoriteEntries = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFavorites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      await _favoritesService.initialize();
      final answers = await _favoritesService.getLumaraAnswers();
      final chats = await _favoritesService.getSavedChats();
      final entries = await _favoritesService.getFavoriteJournalEntries();
      if (mounted) {
        setState(() {
          _answers = answers;
          _savedChats = chats;
          _favoriteEntries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading favorites: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteFavorite(LumaraFavorite favorite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Favorite'),
        content: const Text('Are you sure you want to remove this favorite? LUMARA will no longer use it as a style example.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _favoritesService.removeFavorite(favorite.id);
      await _loadFavorites();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Favorite removed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _clearAllFavorites() async {
    final totalCount = _answers.length + _savedChats.length + _favoriteEntries.length;
    if (totalCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Favorites'),
        content: Text('Are you sure you want to remove all $totalCount favorites? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _favoritesService.clearAll();
      await _loadFavorites();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All favorites cleared'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answersCount = _answers.length;
    final chatsCount = _savedChats.length;
    final entriesCount = _favoriteEntries.length;

    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Text(
          'LUMARA Favorites',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
        bottom: TabBar(
          controller: _tabController,
          labelColor: kcPrimaryTextColor,
          unselectedLabelColor: kcTextSecondaryColor,
          indicatorColor: kcAccentColor,
          tabs: [
            Tab(
              icon: const Icon(Icons.star, color: Color(0xFFFFB300)),
              text: 'Answers ($answersCount/25)',
            ),
            Tab(
              icon: const Icon(Icons.bookmark, color: Color(0xFF2196F3)),
              text: 'Chats ($chatsCount/20)',
            ),
            Tab(
              icon: const Icon(Icons.bookmark, color: Color(0xFF2196F3)),
              text: 'Entries ($entriesCount/20)',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAnswersTab(theme, answersCount),
                _buildSavedChatsTab(chatsCount),
                _buildFavoriteEntriesTab(entriesCount),
              ],
            ),
    );
  }

  Widget _buildAnswersTab(ThemeData theme, int count) {
    if (count == 0) {
      return _buildEmptyState(theme, 'answer');
    }
    return Column(
      children: [
        // Explainer text
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'With favorites, LUMARA can learn how to answer in a way that suits you.',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 14,
            ),
          ),
        ),
        // Header with count and add button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFFB300), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$count of 25 favorites',
                  style: heading3Style(context).copyWith(
                    color: kcPrimaryTextColor,
                  ),
                ),
              ),
              if (count >= 25)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: Text(
                    'Full',
                    style: bodyStyle(context).copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (count < 25) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: const Color(0xFFFFB300),
                  onPressed: () => _showAddFavoriteDialog(),
                  tooltip: 'Add Favorite',
                ),
              ],
            ],
          ),
        ),
        // Favorites list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _answers.length,
            itemBuilder: (context, index) {
              return _buildFavoriteCard(theme, _answers[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSavedChatsTab(int count) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Saved chats appear in your chat history with a bookmark icon. Tap below to view them there.',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (count > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'You have $count saved chats',
              style: heading3Style(context).copyWith(
                color: const Color(0xFF2196F3),
              ),
            ),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () {
              // Navigate to chat history - saved chats will be shown there
              Navigator.pop(context);
              // Note: User will need to navigate to chat history manually
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Navigate to Chat History to view saved chats'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.chat, color: Color(0xFF2196F3)),
            label: const Text('View in Chat History'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
              foregroundColor: const Color(0xFF2196F3),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFavoriteEntriesTab(int count) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Favorite journal entries appear in your timeline with a bookmark icon. Tap below to view them.',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (count > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'You have $count favorite entries',
              style: heading3Style(context).copyWith(
                color: const Color(0xFF2196F3),
              ),
            ),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoriteJournalEntriesView(),
                ),
              );
            },
            icon: const Icon(Icons.bookmark, color: Color(0xFF2196F3)),
            label: const Text('View Favorite Entries'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
              foregroundColor: const Color(0xFF2196F3),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, String category) {
    final icon = category == 'answer' ? Icons.star_outline : Icons.bookmark_border;
    final title = category == 'answer' 
        ? 'No Favorites Yet'
        : category == 'chat'
            ? 'No Saved Chats Yet'
            : 'No Favorite Entries Yet';
    final description = category == 'answer'
        ? 'Add LUMARA answers you like to help LUMARA learn your preferred style.'
        : category == 'chat'
            ? 'Save chat sessions you want to reference later.'
            : 'Favorite journal entries you want to reference later.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: kcSecondaryTextColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: heading2Style(context).copyWith(
                color: kcPrimaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (category == 'answer') ...[
              const SizedBox(height: 24),
              Text(
                'How to add favorites:',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                ),
              ),
              const SizedBox(height: 12),
              _buildInstructionItem(
                Icons.star_border,
                'Tap the star icon on any LUMARA answer',
              ),
              const SizedBox(height: 8),
              _buildInstructionItem(
                Icons.add_circle_outline,
                'Use the + button to manually add a favorite',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: kcAccentColor,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteCard(ThemeData theme, LumaraFavorite favorite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with timestamp and delete button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.star,
                  color: kcAccentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatTimestamp(favorite.timestamp),
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: kcSecondaryTextColor,
                  onPressed: () => _deleteFavorite(favorite),
                  tooltip: 'Remove',
                ),
              ],
            ),
          ),
          // Content preview
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              favorite.content,
              style: bodyStyle(context).copyWith(
                color: kcPrimaryTextColor,
                height: 1.5,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Expandable full content
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
              'View full text',
              style: bodyStyle(context).copyWith(
                color: kcAccentColor,
                fontSize: 12,
              ),
            ),
            children: [
              SelectableText(
                favorite.content,
                style: bodyStyle(context).copyWith(
                  color: kcPrimaryTextColor,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAddFavoriteDialog() async {
    final textController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Favorite'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste or type an answer style you want LUMARA to learn from:',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Paste your answer here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && textController.text.trim().isNotEmpty) {
      try {
        final favorite = LumaraFavorite(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: textController.text.trim(),
          timestamp: DateTime.now(),
          sourceId: null,
          sourceType: 'manual',
          metadata: {},
          category: 'answer', // Manual favorites are always answers
        );
        
        final added = await _favoritesService.addFavorite(favorite);
        if (added) {
          await _loadFavorites();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Favorite added'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            final isAtCapacity = await _favoritesService.isCategoryAtCapacity('answer');
            final limit = _favoritesService.getCategoryLimit('answer');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cannot add favorite - at capacity ($limit/$limit)'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding favorite: $e'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}


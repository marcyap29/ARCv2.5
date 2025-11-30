import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:my_app/arc/chat/data/models/lumara_favorite.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/ui/journal/journal_screen.dart';

/// Screen for viewing favorite journal entries
class FavoriteJournalEntriesView extends StatefulWidget {
  const FavoriteJournalEntriesView({super.key});

  @override
  State<FavoriteJournalEntriesView> createState() => _FavoriteJournalEntriesViewState();
}

class _FavoriteJournalEntriesViewState extends State<FavoriteJournalEntriesView> {
  final FavoritesService _favoritesService = FavoritesService.instance;
  final JournalRepository _journalRepo = JournalRepository();
  List<LumaraFavorite> _favoriteEntries = [];
  Map<String, JournalEntry> _entryMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavoriteEntries();
  }

  Future<void> _loadFavoriteEntries() async {
    setState(() => _isLoading = true);
    try {
      await _favoritesService.initialize();
      final favorites = await _favoritesService.getFavoriteJournalEntries();
      
      // Load actual journal entries
      final entryMap = <String, JournalEntry>{};
      for (final favorite in favorites) {
        if (favorite.entryId != null) {
          final entry = await _journalRepo.getJournalEntryById(favorite.entryId!);
          if (entry != null) {
            entryMap[favorite.entryId!] = entry;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _favoriteEntries = favorites;
          _entryMap = entryMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading favorite journal entries: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _unfavoriteEntry(LumaraFavorite favorite) async {
    await _favoritesService.removeFavorite(favorite.id);
    await _loadFavoriteEntries();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry unfavorited')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _favoriteEntries.length;
    final maxCount = 20;

    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.bookmark, color: Color(0xFF2196F3), size: 24),
            const SizedBox(width: 8),
            Text(
              'Favorite Journal Entries',
              style: heading1Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteEntries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bookmark_border, color: kcTextSecondaryColor, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'No favorite entries yet',
                        style: heading2Style(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the bookmark icon on any journal entry to save it here',
                        style: bodyStyle(context).copyWith(color: kcTextSecondaryColor),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Favorite Entries ($count/$maxCount)',
                        style: bodyStyle(context).copyWith(
                          color: const Color(0xFF2196F3),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _favoriteEntries.length,
                        itemBuilder: (context, index) {
                          final favorite = _favoriteEntries[index];
                          final entry = favorite.entryId != null
                              ? _entryMap[favorite.entryId!]
                              : null;
                          
                          return _FavoriteEntryCard(
                            favorite: favorite,
                            entry: entry,
                            onTap: entry != null
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => JournalScreen(
                                          existingEntry: entry,
                                          isViewOnly: true,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            onUnfavorite: () => _unfavoriteEntry(favorite),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _FavoriteEntryCard extends StatelessWidget {
  final LumaraFavorite favorite;
  final JournalEntry? entry;
  final VoidCallback? onTap;
  final VoidCallback onUnfavorite;

  const _FavoriteEntryCard({
    required this.favorite,
    this.entry,
    this.onTap,
    required this.onUnfavorite,
  });

  @override
  Widget build(BuildContext context) {
    final title = entry?.title ?? 'Favorite Entry';
    final content = entry?.content ?? favorite.content;
    final date = entry?.createdAt ?? favorite.timestamp;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF2196F3).withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2196F3), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const Icon(Icons.bookmark, color: Color(0xFF2196F3), size: 24),
        title: Text(
          title,
          style: heading2Style(context).copyWith(
            fontSize: 16,
            color: const Color(0xFF2196F3),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatDate(date),
              style: captionStyle(context),
            ),
            const SizedBox(height: 8),
            Text(
              content.length > 150
                  ? '${content.substring(0, 150)}...'
                  : content,
              style: bodyStyle(context).copyWith(
                fontSize: 12,
                color: kcTextSecondaryColor,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.bookmark, color: Color(0xFF2196F3)),
          onPressed: onUnfavorite,
          tooltip: 'Unfavorite entry',
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}


import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:my_app/arc/chat/data/models/lumara_favorite.dart';

/// Screen for managing LUMARA favorites
class FavoritesManagementView extends StatefulWidget {
  const FavoritesManagementView({super.key});

  @override
  State<FavoritesManagementView> createState() => _FavoritesManagementViewState();
}

class _FavoritesManagementViewState extends State<FavoritesManagementView> {
  final FavoritesService _favoritesService = FavoritesService.instance;
  List<LumaraFavorite> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      await _favoritesService.initialize();
      final favorites = await _favoritesService.getAllFavorites();
      if (mounted) {
        setState(() {
          _favorites = favorites;
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
    if (_favorites.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Favorites'),
        content: Text('Are you sure you want to remove all ${_favorites.length} favorites? This cannot be undone.'),
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
    final count = _favorites.length;
    final maxCount = 25;

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
        actions: [
          if (count > 0)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear All',
              onPressed: _clearAllFavorites,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : count == 0
              ? _buildEmptyState(theme)
              : Column(
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
                          Icon(
                            Icons.star,
                            color: kcAccentColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '$count of $maxCount favorites',
                              style: heading3Style(context).copyWith(
                                color: kcPrimaryTextColor,
                              ),
                            ),
                          ),
                          if (count >= maxCount)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Full',
                                style: bodyStyle(context).copyWith(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (count < maxCount) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              color: kcAccentColor,
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
                        itemCount: _favorites.length,
                        itemBuilder: (context, index) {
                          final favorite = _favorites[index];
                          return _buildFavoriteCard(theme, favorite);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star_outline,
              size: 64,
              color: kcSecondaryTextColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Favorites Yet',
              style: heading2Style(context).copyWith(
                color: kcPrimaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add LUMARA answers you like to help LUMARA learn your preferred style.',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot add favorite - at capacity (25/25)'),
                duration: Duration(seconds: 2),
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


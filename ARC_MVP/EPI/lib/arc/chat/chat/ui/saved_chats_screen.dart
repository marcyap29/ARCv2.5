import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import '../chat_models.dart';
import '../enhanced_chat_repo.dart';
import '../chat_repo_impl.dart';
import '../../bloc/lumara_assistant_cubit.dart';
import '../../ui/lumara_chat_redesign_screen.dart';
import '../../services/favorites_service.dart';
import '../../data/models/lumara_favorite.dart';

class SavedChatsScreen extends StatefulWidget {
  final EnhancedChatRepo chatRepo;

  const SavedChatsScreen({
    super.key,
    required this.chatRepo,
  });

  @override
  State<SavedChatsScreen> createState() => _SavedChatsScreenState();
}

class _SavedChatsScreenState extends State<SavedChatsScreen> {
  List<LumaraFavorite> _savedChats = [];
  List<ChatSession> _sessions = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  Set<String> _selectedFavoriteIds = {};
  final FavoritesService _favoritesService = FavoritesService.instance;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await _favoritesService.initialize();
      final savedChats = await _favoritesService.getSavedChats();
      // Get all sessions (including archived) to match saved chats
      final allSessions = await widget.chatRepo.listAll(includeArchived: true);

      if (mounted) {
        setState(() {
          _sessions = allSessions;
          // Show all saved chats - we'll handle missing sessions in the UI
          _savedChats = savedChats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedFavoriteIds.clear();
    });
  }

  void _toggleFavoriteSelection(String favoriteId) {
    setState(() {
      if (_selectedFavoriteIds.contains(favoriteId)) {
        _selectedFavoriteIds.remove(favoriteId);
      } else {
        _selectedFavoriteIds.add(favoriteId);
      }
    });
  }

  void _selectAllFavorites() {
    setState(() {
      _selectedFavoriteIds = _savedChats.map((f) => f.id).toSet();
    });
  }

  void _clearSelection() {
    setState(() => _selectedFavoriteIds.clear());
  }

  Future<void> _batchRemoveSavedChats() async {
    if (_selectedFavoriteIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Saved'),
        content: Text(
          'Remove ${_selectedFavoriteIds.length} saved chat${_selectedFavoriteIds.length > 1 ? 's' : ''}? They will no longer appear in Saved Chats.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: kcDangerColor),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final count = _selectedFavoriteIds.length;
        for (final id in _selectedFavoriteIds) {
          await _favoritesService.removeFavorite(id);
        }
        await _loadData();
        setState(() {
          _isSelectionMode = false;
          _selectedFavoriteIds.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed $count saved chat${count > 1 ? 's' : ''}'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove: $e')),
          );
        }
      }
    }
  }

  Future<void> _removeSavedChat(LumaraFavorite favorite) async {
    try {
      await _favoritesService.removeFavorite(favorite.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from saved chats')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            _isSelectionMode ? Icons.close : Icons.arrow_back,
            color: kcPrimaryColor,
          ),
          onPressed: () {
            if (_isSelectionMode) {
              _toggleSelectionMode();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _isSelectionMode
              ? '${_selectedFavoriteIds.length} selected'
              : 'Saved Chats',
          style: heading1Style(context),
        ),
        actions: _isSelectionMode
            ? [
                if (_selectedFavoriteIds.length < _savedChats.length)
                  IconButton(
                    icon: const Icon(Icons.select_all, color: kcPrimaryColor),
                    onPressed: _selectAllFavorites,
                    tooltip: 'Select All',
                  ),
                if (_selectedFavoriteIds.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.clear, color: kcPrimaryColor),
                    onPressed: _clearSelection,
                    tooltip: 'Clear Selection',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: kcDangerColor),
                    onPressed: _batchRemoveSavedChats,
                    tooltip: 'Remove Selected',
                  ),
                ],
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.checklist, color: kcPrimaryColor),
                  onPressed: _savedChats.isEmpty ? null : _toggleSelectionMode,
                  tooltip: 'Select Multiple',
                ),
              ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedChats.isEmpty
              ? Center(
                  child: Text(
                    'No saved chats yet',
                    style: bodyStyle(context).copyWith(color: kcTextSecondaryColor),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _savedChats.length,
                  itemBuilder: (context, index) {
                    final favorite = _savedChats[index];
                    final session = _sessions.firstWhere(
                      (s) => s.id == favorite.sessionId,
                      orElse: () => ChatSession(
                        id: favorite.sessionId ?? '',
                        subject: 'Saved Chat',
                        createdAt: favorite.timestamp,
                        updatedAt: favorite.timestamp,
                        tags: [],
                        metadata: {},
                      ),
                    );

                    // Check if session exists (active or archived)
                    final sessionExists = _sessions.any((s) => s.id == session.id);
                    final actualSession = sessionExists 
                        ? _sessions.firstWhere((s) => s.id == session.id)
                        : session;

                    Widget card = SavedChatCard(
                      favorite: favorite,
                      session: actualSession,
                      isSessionAvailable: sessionExists,
                      isSelectionMode: _isSelectionMode,
                      isSelected: _selectedFavoriteIds.contains(favorite.id),
                      onTap: () async {
                        if (_isSelectionMode) {
                          _toggleFavoriteSelection(favorite.id);
                          return;
                        }
                        if (actualSession.id.isNotEmpty) {
                          if (sessionExists && actualSession.isArchived) {
                            try {
                              await widget.chatRepo.archiveSession(actualSession.id, false);
                              await _loadData();
                            } catch (e) {
                              print('Error restoring archived session: $e');
                            }
                          }
                          try {
                            await context.read<LumaraAssistantCubit>().switchToSession(actualSession.id);
                          } catch (_) {}
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LumaraChatRedesignScreen(),
                            ),
                          ).then((_) => _loadData());
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Unable to open chat - session ID missing'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      onUnsave: () async {
                        await _removeSavedChat(favorite);
                      },
                    );

                    if (!_isSelectionMode) {
                      card = Dismissible(
                        key: ValueKey(favorite.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: kcDangerColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Remove',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 12),
                              Icon(Icons.delete, color: Colors.white, size: 28),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Remove from Saved'),
                              content: const Text(
                                'Remove this chat from Saved Chats? The chat will still exist in your history.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(foregroundColor: kcDangerColor),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) => _removeSavedChat(favorite),
                        child: card,
                      );
                    }

                    return card;
                  },
                ),
    );
  }
}

class SavedChatCard extends StatelessWidget {
  final LumaraFavorite favorite;
  final ChatSession session;
  final bool isSessionAvailable;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onUnsave;

  const SavedChatCard({
    super.key,
    required this.favorite,
    required this.session,
    this.isSessionAvailable = true,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onTap,
    required this.onUnsave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected
          ? kcPrimaryColor.withOpacity(0.1)
          : isSessionAvailable 
              ? const Color(0xFF2196F3).withOpacity(0.05)
              : Colors.grey.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? kcPrimaryColor
              : isSessionAvailable 
                  ? const Color(0xFF2196F3)
                  : Colors.grey.withOpacity(0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: isSelectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
                activeColor: kcPrimaryColor,
              )
            : Icon(
                Icons.bookmark,
                color: isSessionAvailable 
                    ? const Color(0xFF2196F3)
                    : Colors.grey,
                size: 24,
              ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                session.subject,
                style: heading2Style(context).copyWith(
                  fontSize: 16,
                  color: isSessionAvailable 
                      ? const Color(0xFF2196F3)
                      : Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isSessionAvailable)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '(Unavailable)',
                  style: captionStyle(context).copyWith(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Saved ${_formatDate(favorite.timestamp)}',
              style: captionStyle(context),
            ),
            const SizedBox(height: 8),
            Text(
              favorite.content.length > 100
                  ? '${favorite.content.substring(0, 100)}...'
                  : favorite.content,
              style: bodyStyle(context).copyWith(
                fontSize: 12,
                color: kcTextSecondaryColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: isSelectionMode
            ? null
            : IconButton(
                icon: const Icon(Icons.bookmark, color: Color(0xFF2196F3)),
                onPressed: onUnsave,
                tooltip: 'Unsave chat',
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

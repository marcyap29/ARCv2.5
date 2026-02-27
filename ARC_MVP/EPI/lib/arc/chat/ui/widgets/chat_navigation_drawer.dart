import 'package:flutter/material.dart';
import 'package:my_app/arc/chat/chat/enhanced_chat_repo.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:my_app/arc/chat/data/models/lumara_favorite.dart';
import 'package:my_app/shared/ui/settings/favorites_management_view.dart';

/// Left-side expanding navigation drawer for chat history
class ChatNavigationDrawer extends StatefulWidget {
  final EnhancedChatRepo chatRepo;
  final String? currentSessionId;
  final Function(String sessionId) onSessionSelected;
  final Function() onNewChat;
  final Function() onScratchpad;
  final Function() onSandbox;

  const ChatNavigationDrawer({
    super.key,
    required this.chatRepo,
    this.currentSessionId,
    required this.onSessionSelected,
    required this.onNewChat,
    required this.onScratchpad,
    required this.onSandbox,
  });

  @override
  State<ChatNavigationDrawer> createState() => _ChatNavigationDrawerState();
}

class _ChatNavigationDrawerState extends State<ChatNavigationDrawer>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<ChatSession> _recentSessions = [];
  List<LumaraFavorite> _savedChats = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load all sessions (including archived) so full chat history is visible
      final sessions = await widget.chatRepo.listAll(includeArchived: true);
      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      // Load saved chats from favorites
      await FavoritesService.instance.initialize();
      final favorites = await FavoritesService.instance.getAllFavorites();
      final savedChats = favorites
          .where((f) => f.sourceType == 'chat')
          .toList();

      if (mounted) {
        setState(() {
          _recentSessions = sessions;
          _savedChats = savedChats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<ChatSession> get _filteredRecentSessions {
    if (_searchQuery.isEmpty) return _recentSessions;
    return _recentSessions.where((session) {
      return session.subject.toLowerCase().contains(_searchQuery) ||
          session.tags.any((tag) => tag.toLowerCase().contains(_searchQuery));
    }).toList();
  }

  List<LumaraFavorite> get _filteredSavedChats {
    if (_searchQuery.isEmpty) return _savedChats;
    return _savedChats.where((chat) {
      return chat.content.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _handlePinSession(ChatSession session) async {
    try {
      await widget.chatRepo.pinSession(session.id, !session.isPinned);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${session.isPinned ? 'unpin' : 'pin'} chat')),
        );
      }
    }
  }

  Future<void> _handleRenameSession(ChatSession session) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(initialName: session.subject),
    );

    if (newName != null && newName.isNotEmpty && newName != session.subject) {
      try {
        await widget.chatRepo.renameSession(session.id, newName);
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to rename chat')),
          );
        }
      }
    }
  }

  Future<void> _handleDeleteSession(ChatSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text('Are you sure you want to delete "${session.subject}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.chatRepo.deleteSession(session.id);
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete chat')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final drawerWidth = isMobile 
        ? MediaQuery.of(context).size.width * 0.75 
        : 320.0;

    return Container(
      width: drawerWidth,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with search
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search chats...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        // Generic Chats Section
                        _buildSectionHeader('Quick Access'),
                        _buildGenericChatItem(
                          icon: Icons.edit,
                          label: 'New Chat',
                          onTap: widget.onNewChat,
                        ),
                        _buildGenericChatItem(
                          icon: Icons.note,
                          label: 'Scratchpad',
                          onTap: widget.onScratchpad,
                        ),
                        _buildGenericChatItem(
                          icon: Icons.science,
                          label: 'Sandbox',
                          onTap: widget.onSandbox,
                        ),
                        const Divider(height: 32),

                        // Saved/Starred Chats
                        if (_filteredSavedChats.isNotEmpty) ...[
                          _buildSectionHeader('Saved Chats'),
                          ..._filteredSavedChats.map((chat) => _buildSavedChatItem(chat)),
                          const Divider(height: 32),
                        ],

                        // Recent Chats
                        _buildSectionHeader('Recent Chats'),
                        if (_filteredRecentSessions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _searchQuery.isNotEmpty
                                  ? 'No chats found'
                                  : 'No chat history yet',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ..._filteredRecentSessions.map((session) => _buildSessionItem(session)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGenericChatItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label),
      onTap: onTap,
      dense: true,
    );
  }

  Widget _buildSavedChatItem(LumaraFavorite favorite) {
    const isSelected = false; // Saved chats don't have session IDs to match
    return ListTile(
      leading: const Icon(Icons.star, size: 20, color: Colors.amber),
      title: Text(
        favorite.content.split('\n').first,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        'Saved chat',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      selected: isSelected,
      onTap: () {
        // Navigate to saved chat - would need to load from favorites
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FavoritesManagementView(),
          ),
        );
      },
      dense: true,
    );
  }

  Widget _buildSessionItem(ChatSession session) {
    final isSelected = widget.currentSessionId == session.id;
    final theme = Theme.of(context);

    return ListTile(
      leading: session.isPinned
          ? const Icon(Icons.push_pin, size: 16, color: Colors.amber)
          : const Icon(Icons.chat_bubble_outline, size: 20),
      title: Text(
        session.subject,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        '${session.messageCount} messages • ${_formatDate(session.updatedAt)}',
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
      onTap: () => widget.onSessionSelected(session.id),
      onLongPress: () => _showSessionContextMenu(session),
      dense: true,
    );
  }

  void _showSessionContextMenu(ChatSession session) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _handleRenameSession(session);
              },
            ),
            ListTile(
              leading: Icon(session.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(session.isPinned ? 'Unpin' : 'Pin'),
              onTap: () {
                Navigator.pop(context);
                _handlePinSession(session);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _handleDeleteSession(session);
              },
            ),
          ],
        ),
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
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _RenameDialog extends StatefulWidget {
  final String initialName;

  const _RenameDialog({required this.initialName});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Chat'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Enter new name...',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.pop(context, value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final newName = _controller.text.trim();
            if (newName.isNotEmpty) {
              Navigator.pop(context, newName);
            }
          },
          child: const Text('Rename'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import '../chat_models.dart';
import '../enhanced_chat_repo.dart';
import '../chat_repo_impl.dart';
import 'archive_screen.dart';
import '../../bloc/lumara_assistant_cubit.dart';
import '../../ui/lumara_chat_redesign_screen.dart';
import 'chat_export_import_screen.dart';
import '../../services/favorites_service.dart';
import '../../data/models/lumara_favorite.dart';
import 'saved_chats_screen.dart';

/// Enhanced screen showing chat sessions with category support
class EnhancedChatsScreen extends StatefulWidget {
  final EnhancedChatRepo chatRepo;

  const EnhancedChatsScreen({
    super.key,
    required this.chatRepo,
  });

  @override
  State<EnhancedChatsScreen> createState() => _EnhancedChatsScreenState();
}

class _EnhancedChatsScreenState extends State<EnhancedChatsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<ChatSession> _sessions = [];
  List<ChatSession> _filteredSessions = [];
  List<LumaraFavorite> _allSavedChats = []; // Keep track of all saved chats for display
  bool _isLoading = true;
  String? _error;
  
  // Batch selection state
  bool _isSelectionMode = false;
  Set<String> _selectedSessionIds = {};
  
  final FavoritesService _favoritesService = FavoritesService.instance;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterSessions);
    _initializeAndLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeAndLoad() async {
    try {
      await widget.chatRepo.initialize();
      await _loadData();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      // Include archived so all chats (400+) are visible in Chat History, not just recent/active
      final sessions = await widget.chatRepo.listAll(includeArchived: true);
      
      // Load saved chats
      await _favoritesService.initialize();
      final savedChats = await _favoritesService.getSavedChats();
      
      setState(() {
        _sessions = sessions;
        _filteredSessions = sessions;
        _allSavedChats = savedChats; // Keep all saved chats for display count
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterSessions() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSessions = _sessions;
      } else {
        _filteredSessions = _sessions.where((session) =>
            session.subject.toLowerCase().contains(query) ||
            session.tags.any((tag) => tag.toLowerCase().contains(query))).toList();
      }
    });
  }

  Future<void> _createNewChat() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _NewChatDialog(),
    );

    if (result != null) {
      try {
        final sessionId = await widget.chatRepo.createSession(
          subject: result['subject']!,
          tags: result['tags'],
        );
        
        if (mounted) {
          try {
            await context.read<LumaraAssistantCubit>().switchToSession(sessionId);
          } catch (_) {}
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const LumaraChatRedesignScreen(),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create chat: $e')),
          );
        }
      }
    }
  }

  Future<void> _pinSession(ChatSession session) async {
    try {
      await widget.chatRepo.pinSession(session.id, !session.isPinned);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${session.isPinned ? 'unpin' : 'pin'} chat: $e')),
        );
      }
    }
  }

  Future<void> _archiveSession(ChatSession session) async {
    try {
      await widget.chatRepo.archiveSession(session.id, true);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Chat archived'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => _restoreSession(session.id),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to archive chat: $e')),
        );
      }
    }
  }

  Future<void> _restoreSession(String sessionId) async {
    try {
      await widget.chatRepo.archiveSession(sessionId, false);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore chat: $e')),
        );
      }
    }
  }

  Future<void> _deleteSession(ChatSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text(
          'This chat will be permanently deleted. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: kcDangerColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await widget.chatRepo.deleteSession(session.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete chat: $e')),
          );
        }
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedSessionIds.clear();
      }
    });
  }

  void _toggleSessionSelection(String sessionId) {
    setState(() {
      if (_selectedSessionIds.contains(sessionId)) {
        _selectedSessionIds.remove(sessionId);
      } else {
        _selectedSessionIds.add(sessionId);
      }
    });
  }

  void _selectAllSessions() {
    setState(() {
      _selectedSessionIds = _filteredSessions.map((s) => s.id).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedSessionIds.clear();
    });
  }

  Future<void> _batchDeleteSessions() async {
    if (_selectedSessionIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Chats'),
        content: Text(
          'Are you sure you want to delete ${_selectedSessionIds.length} chat${_selectedSessionIds.length > 1 ? 's' : ''}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: kcDangerColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.chatRepo.deleteSessions(_selectedSessionIds.toList());
        await _loadData();
        setState(() {
          _isSelectionMode = false;
          _selectedSessionIds.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted ${_selectedSessionIds.length} chat${_selectedSessionIds.length > 1 ? 's' : ''}'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete chats: $e')),
          );
        }
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
        title: Text(
          _isSelectionMode 
            ? '${_selectedSessionIds.length} selected'
            : 'Chat History',
          style: heading1Style(context),
        ),
        leading: _isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close, color: kcPrimaryColor),
              onPressed: _toggleSelectionMode,
            )
          : null,
        actions: _isSelectionMode
          ? [
              if (_selectedSessionIds.length < _filteredSessions.length)
                IconButton(
                  icon: const Icon(Icons.select_all, color: kcPrimaryColor),
                  onPressed: _selectAllSessions,
                  tooltip: 'Select All',
                ),
              if (_selectedSessionIds.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: kcPrimaryColor),
                  onPressed: _clearSelection,
                  tooltip: 'Clear Selection',
                ),
              if (_selectedSessionIds.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete, color: kcDangerColor),
                  onPressed: _batchDeleteSessions,
                  tooltip: 'Delete Selected',
                ),
            ]
          : [
              IconButton(
                icon: const Icon(Icons.checklist, color: kcPrimaryColor),
                onPressed: _toggleSelectionMode,
                tooltip: 'Select Multiple',
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'export':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatExportImportScreen(
                            chatRepo: widget.chatRepo,
                          ),
                        ),
                      );
                      break;
                    case 'archive':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ArchiveScreen(chatRepo: ChatRepoImpl.instance),
                        ),
                      );
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.file_download, size: 16),
                        SizedBox(width: 8),
                        Text('Export/Import'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(Icons.archive, size: 16),
                        SizedBox(width: 8),
                        Text('Archive'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
        ),
      body: _buildAllChatsTabContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewChat,
        backgroundColor: kcPrimaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAllChatsTabContent() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            style: bodyStyle(context),
            decoration: InputDecoration(
              hintText: 'Search chats...',
              hintStyle: bodyStyle(context).copyWith(color: kcTextSecondaryColor),
              prefixIcon: const Icon(Icons.search, color: kcPrimaryColor),
              filled: true,
              fillColor: kcSurfaceColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Content
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildSavedChatsSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF2196F3).withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2196F3), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bookmark, color: Color(0xFF2196F3), size: 24),
        ),
        title: Text(
          'Saved Chats',
          style: heading2Style(context).copyWith(
            color: const Color(0xFF2196F3),
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${_allSavedChats.length} saved items',
          style: captionStyle(context).copyWith(
            color: const Color(0xFF2196F3).withOpacity(0.8),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF2196F3), size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SavedChatsScreen(
                chatRepo: widget.chatRepo,
              ),
            ),
          ).then((_) => _loadData()); // Reload when returning
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: kcDangerColor, size: 48),
            const SizedBox(height: 16),
            Text('Error: $_error', style: bodyStyle(context)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, color: kcTextSecondaryColor, size: 48),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                ? 'No chats found'
                : 'No chat history yet',
              style: heading2Style(context),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                ? 'Try a different search term'
                : 'Start a new conversation with LUMARA',
              style: bodyStyle(context).copyWith(color: kcTextSecondaryColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Saved Chats Section - Always show if there are any saved chats
          if (_allSavedChats.isNotEmpty) ...[
            _buildSavedChatsSection(),
            const SizedBox(height: 16),
          ],
          // Regular Chat Sessions
          ..._filteredSessions.map((session) {
          return _ChatSessionCard(
            session: session,
            isSelectionMode: _isSelectionMode,
            isSelected: _selectedSessionIds.contains(session.id),
            onTap: _isSelectionMode
              ? () => _toggleSessionSelection(session.id)
              : () async {
                  try {
                    await context.read<LumaraAssistantCubit>().switchToSession(session.id);
                  } catch (_) {}
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LumaraChatRedesignScreen(),
                    ),
                  );
                },
            onPin: () => _pinSession(session),
            onArchive: () => _archiveSession(session),
            onDelete: () => _deleteSession(session),
          );
          }),
        ],
      ),
    );
  }
}

class _ChatSessionCard extends StatelessWidget {
  final ChatSession session;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final bool isSelectionMode;
  final bool isSelected;

  const _ChatSessionCard({
    required this.session,
    required this.onTap,
    required this.onPin,
    required this.onArchive,
    required this.onDelete,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? kcPrimaryColor.withOpacity(0.1) : kcSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
          ? const BorderSide(color: kcPrimaryColor, width: 2)
          : BorderSide.none,
      ),
      child: isSelectionMode
        ? ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Checkbox(
              value: isSelected,
              onChanged: (_) => onTap(),
              activeColor: kcPrimaryColor,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    session.subject,
                    style: heading2Style(context).copyWith(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (session.isPinned)
                  const Icon(Icons.push_pin, color: kcPrimaryColor, size: 16),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${session.messageCount} messages • ${_formatDate(session.updatedAt)}${session.isArchived ? ' • Archived' : ''}',
                        style: captionStyle(context),
                      ),
                    ),
                  ],
                ),
                if (session.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: session.tags.map((tag) => Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 10)),
                      backgroundColor: kcPrimaryColor.withOpacity(0.1),
                      side: BorderSide(color: kcPrimaryColor.withOpacity(0.3)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                ],
              ],
            ),
            onTap: onTap,
          )
        : Dismissible(
            key: ValueKey(session.id),
            direction: DismissDirection.horizontal,
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: kcPrimaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              child: const Row(
                children: [
                  Icon(Icons.push_pin, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text('Pin', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            secondaryBackground: Container(
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
                  Text('Delete', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(width: 12),
                  Icon(Icons.delete, color: Colors.white, size: 28),
                ],
              ),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                onPin();
                return false;
              } else {
                return await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Chat'),
                    content: const Text(
                      'This chat will be permanently deleted. This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: kcDangerColor),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              }
            },
            onDismissed: (direction) {
              if (direction == DismissDirection.endToStart) {
                onDelete();
              }
            },
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      session.subject,
                      style: heading2Style(context).copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (session.isPinned)
                    const Icon(Icons.push_pin, color: kcPrimaryColor, size: 16),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${session.messageCount} messages • ${_formatDate(session.updatedAt)}${session.isArchived ? ' • Archived' : ''}',
                          style: captionStyle(context),
                        ),
                      ),
                    ],
                  ),
                  if (session.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: session.tags.map((tag) => Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 10)),
                        backgroundColor: kcPrimaryColor.withOpacity(0.1),
                        side: BorderSide(color: kcPrimaryColor.withOpacity(0.3)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )).toList(),
                    ),
                  ],
                ],
              ),
              onTap: onTap,
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
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}



class _NewChatDialog extends StatefulWidget {
  const _NewChatDialog();

  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  @override
  void dispose() {
    _subjectController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Chat'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _subjectController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'Enter chat subject...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (optional)',
                hintText: 'Enter tags separated by commas...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final subject = _subjectController.text.trim();
            if (subject.isNotEmpty) {
              final tags = _tagsController.text
                  .split(',')
                  .map((tag) => tag.trim())
                  .where((tag) => tag.isNotEmpty)
                  .toList();
              
              Navigator.pop(context, {
                'subject': subject,
                'tags': tags,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

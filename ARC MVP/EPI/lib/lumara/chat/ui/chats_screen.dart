import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import '../chat_models.dart';
import '../chat_repo.dart';
import '../chat_repo_impl.dart';
import 'archive_screen.dart';
import 'session_view.dart';

/// Screen showing active chat sessions
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late final ChatRepo _chatRepo;
  final TextEditingController _searchController = TextEditingController();

  List<ChatSession> _sessions = [];
  List<ChatSession> _filteredSessions = [];
  bool _isLoading = true;
  String? _error;
  
  // Batch selection state
  bool _isSelectionMode = false;
  Set<String> _selectedSessionIds = {};

  @override
  void initState() {
    super.initState();
    _chatRepo = ChatRepoImpl.instance;
    _searchController.addListener(_filterSessions);
    _initializeAndLoad();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh sessions when returning to this screen
    _loadSessions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _chatRepo.close();
    super.dispose();
  }

  Future<void> _initializeAndLoad() async {
    try {
      await _chatRepo.initialize();
      await _loadSessions();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await _chatRepo.listActive();
      setState(() {
        _sessions = sessions;
        _filteredSessions = sessions;
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
          session.tags.any((tag) => tag.toLowerCase().contains(query))
        ).toList();
      }
    });
  }

  Future<void> _createNewChat() async {
    final subject = await showDialog<String>(
      context: context,
      builder: (context) => _NewChatDialog(),
    );

    if (subject != null && subject.isNotEmpty) {
      try {
        final sessionId = await _chatRepo.createSession(subject: subject);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionView(
                sessionId: sessionId,
                chatRepo: _chatRepo,
              ),
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
      await _chatRepo.pinSession(session.id, !session.isPinned);
      await _loadSessions();
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
      await _chatRepo.archiveSession(session.id, true);
      await _loadSessions();
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
      await _chatRepo.archiveSession(sessionId, false);
      await _loadSessions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore chat: $e')),
        );
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
        await _chatRepo.deleteSessions(_selectedSessionIds.toList());
        await _loadSessions();
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
              IconButton(
                icon: const Icon(Icons.archive, color: kcPrimaryColor),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArchiveScreen(chatRepo: _chatRepo),
                  ),
                ),
                tooltip: 'Archive',
              ),
            ],
      ),
      body: Column(
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewChat,
        backgroundColor: kcPrimaryColor,
        child: const Icon(Icons.add, color: Colors.white),
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
              onPressed: _loadSessions,
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
      onRefresh: _loadSessions,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredSessions.length,
        itemBuilder: (context, index) {
          final session = _filteredSessions[index];
          return _ChatSessionCard(
            session: session,
            isSelectionMode: _isSelectionMode,
            isSelected: _selectedSessionIds.contains(session.id),
            onTap: _isSelectionMode
              ? () => _toggleSessionSelection(session.id)
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SessionView(
                      sessionId: session.id,
                      chatRepo: _chatRepo,
                    ),
                  ),
                ),
            onPin: () => _pinSession(session),
            onArchive: () => _archiveSession(session),
          );
        },
      ),
    );
  }
}

class _ChatSessionCard extends StatelessWidget {
  final ChatSession session;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onArchive;
  final bool isSelectionMode;
  final bool isSelected;

  const _ChatSessionCard({
    required this.session,
    required this.onTap,
    required this.onPin,
    required this.onArchive,
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
          ? BorderSide(color: kcPrimaryColor, width: 2)
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
                Text(
                  '${session.messageCount} messages • ${_formatDate(session.updatedAt)}',
                  style: captionStyle(context),
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
            background: Container(
              decoration: BoxDecoration(
                color: kcPrimaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              child: const Icon(Icons.push_pin, color: Colors.white),
            ),
            secondaryBackground: Container(
              decoration: BoxDecoration(
                color: kcDangerColor,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.archive, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                onPin();
                return false;
              } else {
                return await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Archive Chat'),
                    content: const Text('This will move the chat to your archive.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Archive'),
                      ),
                    ],
                  ),
                );
              }
            },
            onDismissed: (direction) {
              if (direction == DismissDirection.endToStart) {
                onArchive();
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
                  Text(
                    '${session.messageCount} messages • ${_formatDate(session.updatedAt)}',
                    style: captionStyle(context),
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
  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Chat'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Enter chat subject...',
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
            final subject = _controller.text.trim();
            if (subject.isNotEmpty) {
              Navigator.pop(context, subject);
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
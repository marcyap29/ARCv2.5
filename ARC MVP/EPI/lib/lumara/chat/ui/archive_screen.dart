import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import '../chat_models.dart';
import '../chat_repo.dart';
import 'session_view.dart';

/// Screen showing archived chat sessions
class ArchiveScreen extends StatefulWidget {
  final ChatRepo chatRepo;

  const ArchiveScreen({
    super.key,
    required this.chatRepo,
  });

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
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
    _searchController.addListener(_filterSessions);
    _loadSessions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sessions = await widget.chatRepo.listArchived();
      setState(() {
        _sessions = sessions;
        _filteredSessions = sessions;
        _isLoading = false;
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

  Future<void> _restoreSession(ChatSession session) async {
    try {
      await widget.chatRepo.archiveSession(session.id, false);
      await _loadSessions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Chat restored'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SessionView(
                    sessionId: session.id,
                    chatRepo: widget.chatRepo,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore chat: $e')),
        );
      }
    }
  }

  Future<void> _pinSession(ChatSession session) async {
    try {
      await widget.chatRepo.pinSession(session.id, !session.isPinned);
      await _loadSessions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${session.isPinned ? 'unpin' : 'pin'} chat: $e')),
        );
      }
    }
  }

  Future<void> _deleteSession(ChatSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('This action cannot be undone. All messages will be permanently deleted.'),
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
        await _loadSessions();
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
          'Are you sure you want to delete ${_selectedSessionIds.length} archived chat${_selectedSessionIds.length > 1 ? 's' : ''}? This action cannot be undone.',
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
        await _loadSessions();
        setState(() {
          _isSelectionMode = false;
          _selectedSessionIds.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted ${_selectedSessionIds.length} archived chat${_selectedSessionIds.length > 1 ? 's' : ''}'),
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
            : 'Archive',
          style: heading1Style(context),
        ),
        leading: _isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close, color: kcPrimaryColor),
              onPressed: _toggleSelectionMode,
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back, color: kcPrimaryColor),
              onPressed: () => Navigator.pop(context),
            ),
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
                hintText: 'Search archived chats...',
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
            const Icon(Icons.archive_outlined, color: kcTextSecondaryColor, size: 48),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                ? 'No archived chats found'
                : 'Archive is empty',
              style: heading2Style(context),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                ? 'Try a different search term'
                : 'Chats are automatically archived after 30 days',
              style: bodyStyle(context).copyWith(color: kcTextSecondaryColor),
              textAlign: TextAlign.center,
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
          return _ArchivedChatCard(
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
                      chatRepo: widget.chatRepo,
                    ),
                  ),
                ),
            onRestore: () => _restoreSession(session),
            onPin: () => _pinSession(session),
            onDelete: () => _deleteSession(session),
          );
        },
      ),
    );
  }
}

class _ArchivedChatCard extends StatelessWidget {
  final ChatSession session;
  final VoidCallback onTap;
  final VoidCallback onRestore;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final bool isSelectionMode;
  final bool isSelected;

  const _ArchivedChatCard({
    required this.session,
    required this.onTap,
    required this.onRestore,
    required this.onPin,
    required this.onDelete,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? kcPrimaryColor.withOpacity(0.1) : kcSurfaceColor.withOpacity(0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
          ? BorderSide(color: kcPrimaryColor, width: 2)
          : BorderSide.none,
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: isSelectionMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  activeColor: kcPrimaryColor,
                )
              : const Icon(
                  Icons.archive,
                  color: kcTextSecondaryColor,
                  size: 20,
                ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    session.subject,
                    style: heading2Style(context).copyWith(
                      fontSize: 16,
                      color: kcTextSecondaryColor,
                    ),
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
                  '${session.messageCount} messages',
                  style: captionStyle(context),
                ),
                const SizedBox(height: 2),
                Text(
                  'Archived ${_formatDate(session.archivedAt ?? session.updatedAt)}',
                  style: captionStyle(context).copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (session.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: session.tags.map((tag) => Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 10)),
                      backgroundColor: kcTextSecondaryColor.withOpacity(0.1),
                      side: BorderSide(color: kcTextSecondaryColor.withOpacity(0.3)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                ],
              ],
            ),
            onTap: onTap,
          ),

          // Action buttons (hidden in selection mode)
          if (!isSelectionMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: kcBackgroundColor.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onRestore,
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Restore'),
                      style: TextButton.styleFrom(
                        foregroundColor: kcPrimaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onPin,
                    icon: Icon(
                      session.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 16,
                    ),
                    label: Text(session.isPinned ? 'Unpin' : 'Pin'),
                    style: TextButton.styleFrom(
                      foregroundColor: session.isPinned ? kcPrimaryColor : kcTextSecondaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: kcDangerColor,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import '../chat_models.dart';
import '../chat_category_models.dart';
import '../enhanced_chat_repo.dart';
import '../enhanced_chat_repo_impl.dart';
import '../chat_repo_impl.dart';
import 'archive_screen.dart';
import 'session_view.dart';
import 'category_management_screen.dart';
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

class _EnhancedChatsScreenState extends State<EnhancedChatsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  List<ChatSession> _sessions = [];
  List<ChatCategory> _categories = [];
  List<ChatSession> _filteredSessions = [];
  List<LumaraFavorite> _savedChats = [];
  List<LumaraFavorite> _allSavedChats = []; // Keep track of all saved chats for display
  bool _isLoading = true;
  String? _error;
  
  // Category filtering
  String? _selectedCategoryId;
  
  // Batch selection state
  bool _isSelectionMode = false;
  Set<String> _selectedSessionIds = {};
  
  final FavoritesService _favoritesService = FavoritesService.instance;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    _tabController.dispose();
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
      final categories = await widget.chatRepo.getCategories();
      final sessions = await widget.chatRepo.listActive();
      
      // Load saved chats
      await _favoritesService.initialize();
      final savedChats = await _favoritesService.getSavedChats();
      
      setState(() {
        _categories = categories;
        _sessions = sessions;
        _filteredSessions = sessions;
        _savedChats = savedChats; // Keep all saved chats (SavedChatsScreen will handle filtering)
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
      if (query.isEmpty && _selectedCategoryId == null) {
        _filteredSessions = _sessions;
      } else {
        _filteredSessions = _sessions.where((session) {
          final matchesQuery = query.isEmpty || 
              session.subject.toLowerCase().contains(query) ||
              session.tags.any((tag) => tag.toLowerCase().contains(query));
          
          // TODO: Add category filtering when category assignment is implemented
          return matchesQuery;
        }).toList();
      }
    });
  }

  void _selectCategory(String? categoryId, String categoryName) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
    _filterSessions();
  }

  Future<void> _createNewChat() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _NewChatDialog(categories: _categories),
    );

    if (result != null) {
      try {
        final sessionId = await widget.chatRepo.createSession(
          subject: result['subject']!,
          tags: result['tags'],
        );
        
        // Assign to category if selected
        if (result['categoryId'] != null) {
          await widget.chatRepo.assignSessionToCategory(
            sessionId, 
            result['categoryId']!,
          );
        }
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionView(
                sessionId: sessionId,
                chatRepo: ChatRepoImpl.instance,
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
                    case 'categories':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryManagementScreen(
                            chatRepo: widget.chatRepo,
                          ),
                        ),
                      );
                      break;
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
                    value: 'categories',
                    child: Row(
                      children: [
                        Icon(Icons.category, size: 16),
                        SizedBox(width: 8),
                        Text('Manage Categories'),
                      ],
                    ),
                  ),
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
        bottom: TabBar(
          controller: _tabController,
          labelPadding: const EdgeInsets.symmetric(vertical: 8),
          tabs: const [
            Tab(
              child: Text(
                'All Chats',
                style: TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Tab(
              child: Text(
                'Categories',
                style: TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllChatsTab(),
          _buildCategoriesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewChat,
        backgroundColor: kcPrimaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAllChatsTab() {
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

  Widget _buildCategoriesTab() {
    return Column(
      children: [
        // Category filter chips
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildCategoryChip('All Chats', null),
              const SizedBox(width: 8),
              ..._categories.map((category) => 
                _buildCategoryChip(category.name, category.id)),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String name, String? categoryId) {
    final isSelected = _selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(name),
        selected: isSelected,
        onSelected: (selected) {
          _selectCategory(categoryId, name);
        },
        selectedColor: kcPrimaryColor.withOpacity(0.2),
        checkmarkColor: kcPrimaryColor,
        side: BorderSide(
          color: isSelected ? kcPrimaryColor : kcTextSecondaryColor.withOpacity(0.3),
        ),
      ),
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
              _searchController.text.isNotEmpty || _selectedCategoryId != null
                ? 'No chats found'
                : 'No chat history yet',
              style: heading2Style(context),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty || _selectedCategoryId != null
                ? 'Try a different search term or category'
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
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SessionView(
                      sessionId: session.id,
                      chatRepo: ChatRepoImpl.instance,
                    ),
                  ),
                ),
            onPin: () => _pinSession(session),
            onArchive: () => _archiveSession(session),
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
  final List<ChatCategory> categories;

  const _NewChatDialog({required this.categories});

  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  String? _selectedCategoryId;

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
            const SizedBox(height: 16),
            Text(
              'Category',
              style: bodyStyle(context).copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select category (optional)',
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('No category'),
                ),
                ...widget.categories.map((category) => DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategoryId = value;
                });
              },
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
                'categoryId': _selectedCategoryId,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

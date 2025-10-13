import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/draft_cache_service.dart';
import 'journal_screen.dart';

/// Screen for managing journal drafts with multi-select and multi-delete functionality
class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  final DraftCacheService _draftService = DraftCacheService.instance;
  List<JournalDraft> _drafts = [];
  Set<String> _selectedDrafts = {};
  bool _isLoading = true;
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final drafts = await _draftService.getAllDrafts();
      setState(() {
        _drafts = drafts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load drafts: $e');
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedDrafts.clear();
      }
    });
  }

  void _toggleDraftSelection(String draftId) {
    setState(() {
      if (_selectedDrafts.contains(draftId)) {
        _selectedDrafts.remove(draftId);
      } else {
        _selectedDrafts.add(draftId);
      }
    });
  }

  void _selectAllDrafts() {
    setState(() {
      _selectedDrafts = _drafts.map((draft) => draft.id).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedDrafts.clear();
    });
  }

  Future<void> _deleteSelectedDrafts() async {
    if (_selectedDrafts.isEmpty) return;

    final confirmed = await _showDeleteConfirmationDialog();
    if (!confirmed) return;

    try {
      await _draftService.deleteDrafts(_selectedDrafts.toList());
      await _loadDrafts();
      setState(() {
        _selectedDrafts.clear();
        _isSelectionMode = false;
      });
      _showSuccessSnackBar('Deleted ${_selectedDrafts.length} draft(s)');
    } catch (e) {
      _showErrorSnackBar('Failed to delete drafts: $e');
    }
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Drafts'),
        content: Text(
          'Are you sure you want to delete ${_selectedDrafts.length} draft(s)? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _openDraftInJournal(JournalDraft draft) async {
    try {
      // Navigate to journal screen with draft content
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => JournalScreen(
            initialContent: draft.content,
            selectedEmotion: draft.initialEmotion,
            selectedReason: draft.initialReason,
          ),
        ),
      );

      // Reload drafts after returning from journal screen
      if (result == true) {
        await _loadDrafts();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to open draft: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? 'Select Drafts' : 'Drafts'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _selectAllDrafts,
              tooltip: 'Select All',
            ),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSelection,
              tooltip: 'Clear Selection',
            ),
            if (_selectedDrafts.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _deleteSelectedDrafts,
                tooltip: 'Delete Selected',
              ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: _toggleSelectionMode,
              tooltip: 'Select Mode',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadDrafts,
              tooltip: 'Refresh',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
              ? _buildEmptyState()
              : _buildDraftsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.drafts_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Drafts',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your journal drafts will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _drafts.length,
      itemBuilder: (context, index) {
        final draft = _drafts[index];
        final isSelected = _selectedDrafts.contains(draft.id);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleDraftSelection(draft.id),
                  )
                : CircleAvatar(
                    backgroundColor: draft.isRecent ? Colors.blue : Colors.grey,
                    child: Icon(
                      Icons.drafts,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
            title: Text(
              draft.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  _formatDate(draft.lastModified),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                if (draft.mediaItems.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.attach_file,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${draft.mediaItems.length} attachment(s)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ],
                if (draft.initialEmotion != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.mood,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        draft.initialEmotion!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: _isSelectionMode
                ? null
                : Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
            onTap: _isSelectionMode
                ? () => _toggleDraftSelection(draft.id)
                : () => _openDraftInJournal(draft),
            onLongPress: _isSelectionMode
                ? null
                : () {
                    _toggleSelectionMode();
                    _toggleDraftSelection(draft.id);
                  },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${_formatTime(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${_formatTime(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

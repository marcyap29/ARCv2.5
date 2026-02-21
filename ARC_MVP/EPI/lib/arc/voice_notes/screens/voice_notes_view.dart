import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:my_app/arc/internal/mira/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';
import '../models/voice_note.dart';
import '../repositories/voice_note_repository.dart';
import '../widgets/voice_note_detail_sheet.dart';

/// View for displaying voice notes in the Voice Notes tab.
/// Shows a chronological list of captured voice notes with actions
/// to convert to journal entries or delete.
/// 
/// When showBackNavigation is true, shows an AppBar with back arrow
/// (used when navigating here directly from voice capture).
class VoiceNotesView extends StatefulWidget {
  final VoiceNoteRepository repository;
  final bool showBackNavigation;
  final VoidCallback? onBackPressed;

  const VoiceNotesView({
    super.key,
    required this.repository,
    this.showBackNavigation = false,
    this.onBackPressed,
  });

  @override
  State<VoiceNotesView> createState() => _VoiceNotesViewState();
}

class _VoiceNotesViewState extends State<VoiceNotesView> {
  List<VoiceNote> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    // Listen for changes
    widget.repository.watch().listen((_) {
      if (mounted) _loadNotes();
    });
  }

  void _loadNotes() {
    setState(() {
      _notes = widget.repository.getAll();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _notes.isEmpty
            ? _buildEmptyState(context)
            : RefreshIndicator(
                onRefresh: () async => _loadNotes(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return _buildVoiceNoteCard(context, note);
                  },
                ),
              );

    // If showing back navigation, wrap in a Column with AppBar
    if (widget.showBackNavigation) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      
      return Column(
        children: [
          // Custom AppBar with back arrow
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 16,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBackPressed ?? () => Navigator.of(context).pop(),
                  tooltip: 'Back to Conversations',
                ),
                const SizedBox(width: 8),
                Text(
                  'Voice Notes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_notes.length} note${_notes.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      );
    }

    return content;
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 80,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No voice notes yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hold the + button to record a voice note.\nYour ideas will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // How it works section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  _buildHowItWorksStep(
                    icon: Icons.touch_app,
                    text: 'Hold + button to enter voice mode',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildHowItWorksStep(
                    icon: Icons.mic,
                    text: 'Tap the orb and speak your idea',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildHowItWorksStep(
                    icon: Icons.lightbulb,
                    text: 'Choose "Save as Voice Note"',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksStep({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceNoteCard(BuildContext context, VoiceNote note) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.withOpacity(isDark ? 0.2 : 0.1),
        ),
      ),
      child: InkWell(
        onTap: () => _showNoteDetails(context, note),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.mic,
                    size: 16,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTimestamp(note.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                  if (note.wordCount > 0) ...[
                    const SizedBox(width: 12),
                    Text(
                      '${note.wordCount} words',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                      ),
                    ),
                  ],
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (value) =>
                        _handleMenuAction(context, note, value),
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'convert',
                        child: Row(
                          children: [
                            Icon(Icons.article_outlined, size: 18),
                            SizedBox(width: 12),
                            Text('Convert to Journal'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                note.transcription,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: note.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.primaryColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays == 0) {
      return 'Today ${DateFormat.jm().format(timestamp)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat.jm().format(timestamp)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(timestamp);
    }
  }

  void _showNoteDetails(BuildContext context, VoiceNote note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VoiceNoteDetailSheet(
        note: note,
        repository: widget.repository,
        onConvert: () => _convertToJournal(context, note),
        onDelete: () => _deleteNote(context, note),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, VoiceNote note, String action) {
    switch (action) {
      case 'convert':
        _convertToJournal(context, note);
        break;
      case 'delete':
        _deleteNote(context, note);
        break;
    }
  }

  Future<void> _convertToJournal(BuildContext context, VoiceNote note) async {
    try {
      final journalRepository = JournalRepository();
      final entryId = const Uuid().v4();
      final title = note.transcription.length > 50
          ? '${note.transcription.substring(0, 47).trim()}...'
          : note.transcription.trim();
      final entry = JournalEntry(
        id: entryId,
        title: title.isEmpty ? 'Voice note' : title,
        content: note.transcription,
        createdAt: note.timestamp,
        updatedAt: DateTime.now(),
        tags: ['voice', 'timeline'],
        mood: '',
        metadata: {'fromVoiceNote': true, 'voiceNoteId': note.id},
      );
      await journalRepository.createJournalEntry(entry);
      await widget.repository.markConverted(note.id, entryId);
      if (mounted) {
        _loadNotes();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Moved to Conversations timeline'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to move to timeline: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNote(BuildContext context, VoiceNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete voice note?'),
        content: const Text('This cannot be undone.'),
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
      await widget.repository.delete(note.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice note deleted')),
        );
      }
    }
  }
}

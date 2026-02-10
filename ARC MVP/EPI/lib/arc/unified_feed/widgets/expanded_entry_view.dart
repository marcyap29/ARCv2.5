/// Expanded Entry View
///
/// Full-screen detail view for any feed entry. Shows phase indicator,
/// full content, themes, related entries (from CHRONICLE), and LUMARA notes.
/// Navigated to when user taps a card in the feed.

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/core/constants/phase_colors.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';
import 'package:my_app/arc/unified_feed/utils/feed_helpers.dart';
import 'package:my_app/arc/unified_feed/widgets/feed_media_thumbnails.dart';
import 'package:my_app/arc/internal/mira/journal_repository.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/ui/journal/journal_screen.dart';
import 'package:my_app/ui/widgets/full_image_viewer.dart';

class ExpandedEntryView extends StatelessWidget {
  final FeedEntry entry;
  /// Called after the entry is deleted so the feed can refresh.
  final VoidCallback? onEntryDeleted;

  const ExpandedEntryView({
    super.key,
    required this.entry,
    this.onEntryDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        foregroundColor: kcPrimaryTextColor,
        elevation: 0,
        title: Text(
          entry.title ?? 'Entry',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 22),
            onPressed: () => _editEntry(context),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 22),
            onPressed: () => _showOptions(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Phase indicator card (prominent)
          if (entry.phase != null) _buildPhaseCard(context),
          if (entry.phase != null) const SizedBox(height: 16),

          // Date + type header
          _buildDateHeader(context),
          const SizedBox(height: 16),

          // Full content
          _buildContent(context),
          const SizedBox(height: 24),

          // Media (photos, videos, files) — load from journal when possible for correct URIs
          if (entry.mediaItems.isNotEmpty) ...[
            Text(
              'Media',
              style: TextStyle(
                color: kcPrimaryTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildMediaSection(context),
            const SizedBox(height: 24),
          ],

          // Themes section
          if (entry.themes.isNotEmpty) _buildThemesSection(context),
          if (entry.themes.isNotEmpty) const SizedBox(height: 24),

          // Related entries section (CHRONICLE integration)
          _buildRelatedEntries(context),
          const SizedBox(height: 24),

          // LUMARA's note
          _buildLumaraNote(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Load media from journal entry when available so thumbnails resolve (same source as journal).
  Widget _buildMediaSection(BuildContext context) {
    final journalEntryId = entry.journalEntryId;
    if (journalEntryId == null || journalEntryId.isEmpty) {
      return _buildMediaGrid(context, entry.mediaItems);
    }
    return FutureBuilder<JournalEntry?>(
      future: JournalRepository().getJournalEntryById(journalEntryId),
      builder: (context, snapshot) {
        final items = snapshot.hasData && snapshot.data!.media.isNotEmpty
            ? snapshot.data!.media
            : entry.mediaItems;
        if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty) {
          return SizedBox(
            height: 100,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kcPrimaryTextColor.withOpacity(0.5),
                ),
              ),
            ),
          );
        }
        return _buildMediaGrid(context, items);
      },
    );
  }

  /// Media grid using same thumbnail resolution as timeline/journal (ph://, file://, MCP, raw path).
  Widget _buildMediaGrid(BuildContext context, List<MediaItem> mediaItems) {
    const double tileSize = 100.0;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: mediaItems.map((item) {
        return FeedMediaThumbnailTile(
          mediaItem: item,
          size: tileSize,
          onTap: () {
            if (item.type == MediaType.image) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => FullImageViewer(mediaItem: item),
                ),
              );
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildPhaseCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (entry.phaseColor ?? Colors.grey).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (entry.phaseColor ?? Colors.grey).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up, color: entry.phaseColor ?? kcSecondaryTextColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phase: ${entry.phase}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: entry.phaseColor ?? kcSecondaryTextColor,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  PhaseColors.getPhaseDescription(entry.phase!),
                  style: TextStyle(
                    fontSize: 12,
                    color: kcSecondaryTextColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.info_outline,
              size: 20,
              color: kcSecondaryTextColor.withOpacity(0.5),
            ),
            onPressed: () => _showPhaseInfo(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          _getTypeIcon(),
          size: 16,
          color: kcSecondaryTextColor.withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Text(
          entry.typeLabel,
          style: TextStyle(
            color: kcSecondaryTextColor.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Text('·', style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.4))),
        const SizedBox(width: 8),
        Text(
          entry.ageLabel,
          style: TextStyle(
            color: kcSecondaryTextColor.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
        if (entry.exchangeCount != null) ...[
          const SizedBox(width: 8),
          Text('·', style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.4))),
          const SizedBox(width: 8),
          Text(
            '${entry.exchangeCount} exchanges',
            style: TextStyle(
              color: kcSecondaryTextColor.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (entry.type) {
      case FeedEntryType.activeConversation:
      case FeedEntryType.savedConversation:
        return _buildConversationContent(context);
      case FeedEntryType.voiceMemo:
        return _buildVoiceContent(context);
      case FeedEntryType.reflection:
        return _buildWrittenContent(context);
      case FeedEntryType.lumaraInitiative:
        return _buildLumaraInitiativeContent(context);
    }
  }

  /// Build paragraph widgets from text (double newlines = paragraph break; single = line break).
  List<Widget> _buildParagraphWidgets(BuildContext context, String text, TextStyle baseStyle) {
    final displayContent = FeedHelpers.contentWithoutPhaseHashtags(text);
    if (displayContent.trim().isEmpty) return [];
    List<String> paragraphs = displayContent.split('\n\n');
    paragraphs = paragraphs.map((p) => p.replaceAll('\n', ' ').trim()).where((p) => p.isNotEmpty).toList();
    if (paragraphs.length == 1 && displayContent.contains('\n')) {
      paragraphs = displayContent.split('\n').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    }
    final result = <Widget>[];
    for (int i = 0; i < paragraphs.length; i++) {
      result.add(Padding(
        padding: EdgeInsets.only(bottom: i < paragraphs.length - 1 ? 12 : 0),
        child: Text(paragraphs[i], style: baseStyle.copyWith(height: 1.5)),
      ));
    }
    return result.isEmpty ? [Text(displayContent, style: baseStyle)] : result;
  }

  Widget _buildConversationContent(BuildContext context) {
    final baseStyle = TextStyle(
      color: kcPrimaryTextColor.withOpacity(0.85),
      fontSize: 15,
      height: 1.6,
    );
    if (entry.messages == null || entry.messages!.isEmpty) {
      final raw = entry.content?.toString() ?? entry.preview;
      final widgets = _buildParagraphWidgets(context, raw, baseStyle);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
    }

    return Column(
      children: entry.messages!.map((msg) {
        final isUser = msg.role == 'user';
        final msgStyle = TextStyle(
          color: kcPrimaryTextColor.withOpacity(0.85),
          fontSize: 14,
          height: 1.5,
        );
        final paragraphWidgets = _buildParagraphWidgets(context, msg.content, msgStyle);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: kcPrimaryGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                  ),
                ),
              if (isUser) const SizedBox(width: 32),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? kcPrimaryColor.withOpacity(0.08)
                        : kcSurfaceAltColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: paragraphWidgets,
                  ),
                ),
              ),
              if (!isUser) const SizedBox(width: 32),
              if (isUser) const SizedBox(width: 8),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVoiceContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Audio player placeholder
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kcSurfaceAltColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Color(0xFF059669)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: 0.0,
                      backgroundColor: kcBorderColor.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                    ),
                    const SizedBox(height: 6),
                    if (entry.duration != null)
                      Text(
                        '0:00 / ${_formatDuration(entry.duration!)}',
                        style: TextStyle(
                          color: kcSecondaryTextColor.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Transcript
        Text(
          'Transcript',
          style: TextStyle(
            color: kcPrimaryTextColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildParagraphWidgets(
            context,
            entry.content?.toString() ?? entry.preview,
            TextStyle(
              color: kcPrimaryTextColor.withOpacity(0.85),
              fontSize: 15,
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWrittenContent(BuildContext context) {
    final raw = entry.content?.toString() ?? entry.preview;
    final summary = FeedHelpers.extractSummary(raw);
    final body = FeedHelpers.bodyWithoutSummary(raw);
    final baseStyle = TextStyle(
      color: kcPrimaryTextColor.withOpacity(0.85),
      fontSize: 15,
      height: 1.6,
    );
    final children = <Widget>[];
    if (summary != null && summary.isNotEmpty) {
      children.addAll([
        Text(
          'Summary',
          style: TextStyle(
            color: kcPrimaryTextColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        ..._buildParagraphWidgets(context, summary, baseStyle.copyWith(fontStyle: FontStyle.italic)),
        const SizedBox(height: 16),
      ]);
    }
    children.addAll(_buildParagraphWidgets(context, body, baseStyle));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _buildLumaraInitiativeContent(BuildContext context) {
    final raw = entry.content?.toString() ?? entry.preview;
    final baseStyle = TextStyle(
      color: kcPrimaryTextColor.withOpacity(0.85),
      fontSize: 15,
      height: 1.6,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kcPrimaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kcPrimaryColor.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildParagraphWidgets(context, raw, baseStyle),
      ),
    );
  }

  Widget _buildThemesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Themes',
          style: TextStyle(
            color: kcPrimaryTextColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entry.themes.map((theme) {
            return ActionChip(
              label: Text(
                theme,
                style: const TextStyle(
                  color: kcPrimaryTextColor,
                  fontSize: 12,
                ),
              ),
              backgroundColor: kcSurfaceAltColor,
              side: BorderSide(color: kcBorderColor.withOpacity(0.3)),
              onPressed: () => _filterByTheme(context, theme),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRelatedEntries(BuildContext context) {
    // CHRONICLE integration - placeholder for related entries
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Related Entries',
          style: TextStyle(
            color: kcPrimaryTextColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kcSurfaceAltColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.link, size: 20, color: kcSecondaryTextColor.withOpacity(0.4)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Related entries from CHRONICLE will appear here',
                  style: TextStyle(
                    color: kcSecondaryTextColor.withOpacity(0.5),
                    fontSize: 13,
                  ),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLumaraNote(BuildContext context) {
    if (!entry.hasLumaraReflections) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: kcPrimaryGradient,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text(
              'LUMARA\'s Note',
              style: TextStyle(
                color: kcPrimaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kcPrimaryColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kcPrimaryColor.withOpacity(0.12)),
          ),
          child: Text(
            'LUMARA reflection content will appear here when available.',
            style: TextStyle(
              color: kcPrimaryTextColor.withOpacity(0.7),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getTypeIcon() {
    switch (entry.type) {
      case FeedEntryType.activeConversation:
        return Icons.chat_bubble;
      case FeedEntryType.savedConversation:
        return Icons.chat_bubble_outline;
      case FeedEntryType.voiceMemo:
        return Icons.mic;
      case FeedEntryType.reflection:
        return Icons.edit_note;
      case FeedEntryType.lumaraInitiative:
        return Icons.auto_awesome;
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _editEntry(BuildContext context) async {
    final journalEntryId = entry.journalEntryId;
    if (journalEntryId == null || journalEntryId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This entry cannot be edited from here.'),
          ),
        );
      }
      return;
    }
    final journalRepo = JournalRepository();
    final JournalEntry? fullEntry = await journalRepo.getJournalEntryById(journalEntryId);
    if (!context.mounted) return;
    if (fullEntry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry could not be loaded.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => JournalScreen(
          existingEntry: fullEntry,
          isViewOnly: false,
          openAsEdit: true,
        ),
      ),
    );
  }

  Future<void> _onDeleteTapped(BuildContext context) async {
    Navigator.pop(context); // close the bottom sheet
    final journalEntryId = entry.journalEntryId;
    if (journalEntryId == null || journalEntryId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This entry cannot be deleted from here.')),
        );
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kcSurfaceColor,
        title: const Text('Delete entry?'),
        content: const Text(
          'This journal entry will be permanently deleted. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    try {
      final journalRepo = JournalRepository();
      await journalRepo.deleteJournalEntry(journalEntryId);
      if (!context.mounted) return;
      onEntryDeleted?.call();
      Navigator.pop(context); // close expanded view and return to feed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kcSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin_outlined, color: kcPrimaryTextColor),
              title: const Text('Pin Entry', style: TextStyle(color: kcPrimaryTextColor)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: kcPrimaryTextColor),
              title: const Text('Share', style: TextStyle(color: kcPrimaryTextColor)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined, color: kcPrimaryTextColor),
              title: const Text('Archive', style: TextStyle(color: kcPrimaryTextColor)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red[400]),
              title: Text('Delete', style: TextStyle(color: Colors.red[400])),
              onTap: () => _onDeleteTapped(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhaseInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcSurfaceColor,
        title: Text(
          'About "${entry.phase}" Phase',
          style: const TextStyle(color: kcPrimaryTextColor),
        ),
        content: Text(
          PhaseColors.getPhaseDescription(entry.phase!),
          style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _filterByTheme(BuildContext context, String theme) {
    // Navigate back to feed filtered by this theme
    Navigator.pop(context, theme);
  }
}

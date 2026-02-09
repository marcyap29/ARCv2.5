/// Expanded Entry View
///
/// Full-screen detail view for any feed entry. Shows phase indicator,
/// full content, themes, related entries (from CHRONICLE), and LUMARA notes.
/// Navigated to when user taps a card in the feed.

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/core/constants/phase_colors.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';

class ExpandedEntryView extends StatelessWidget {
  final FeedEntry entry;

  const ExpandedEntryView({
    super.key,
    required this.entry,
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

  Widget _buildConversationContent(BuildContext context) {
    if (entry.messages == null || entry.messages!.isEmpty) {
      return Text(
        entry.content?.toString() ?? entry.preview,
        style: TextStyle(
          color: kcPrimaryTextColor.withOpacity(0.85),
          fontSize: 15,
          height: 1.6,
        ),
      );
    }

    return Column(
      children: entry.messages!.map((msg) {
        final isUser = msg.role == 'user';
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
                  child: Text(
                    msg.content,
                    style: TextStyle(
                      color: kcPrimaryTextColor.withOpacity(0.85),
                      fontSize: 14,
                      height: 1.5,
                    ),
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
        Text(
          entry.content?.toString() ?? entry.preview,
          style: TextStyle(
            color: kcPrimaryTextColor.withOpacity(0.85),
            fontSize: 15,
            height: 1.6,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildWrittenContent(BuildContext context) {
    return Text(
      entry.content?.toString() ?? entry.preview,
      style: TextStyle(
        color: kcPrimaryTextColor.withOpacity(0.85),
        fontSize: 15,
        height: 1.6,
      ),
    );
  }

  Widget _buildLumaraInitiativeContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kcPrimaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kcPrimaryColor.withOpacity(0.12)),
      ),
      child: Text(
        entry.content?.toString() ?? entry.preview,
        style: TextStyle(
          color: kcPrimaryTextColor.withOpacity(0.85),
          fontSize: 15,
          height: 1.6,
        ),
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kcSurfaceAltColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.link, size: 20, color: kcSecondaryTextColor.withOpacity(0.4)),
              const SizedBox(width: 12),
              Text(
                'Related entries from CHRONICLE will appear here',
                style: TextStyle(
                  color: kcSecondaryTextColor.withOpacity(0.5),
                  fontSize: 13,
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

  void _editEntry(BuildContext context) {
    // TODO: Navigate to edit view
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
              onTap: () => Navigator.pop(context),
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

/// Draft Recovery Dialog
///
/// Shows users options to recover unsaved drafts when they return to journaling

import 'package:flutter/material.dart';
import 'package:my_app/core/services/draft_cache_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class DraftRecoveryDialog extends StatelessWidget {
  final JournalDraft recoverableDraft;
  final VoidCallback onRestore;
  final VoidCallback onDiscard;
  final VoidCallback? onViewHistory;

  const DraftRecoveryDialog({
    super.key,
    required this.recoverableDraft,
    required this.onRestore,
    required this.onDiscard,
    this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: kcBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.restore,
                  color: kcPrimaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Recover Your Writing',
                    style: heading1Style(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Draft preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kcSurfaceAltColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: kcPrimaryColor.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.drafts,
                        size: 16,
                        color: kcSecondaryTextColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDraftAge(recoverableDraft.age),
                        style: captionStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                        ),
                      ),
                      const Spacer(),
                      if (recoverableDraft.mediaItems.isNotEmpty) ...[
                        Icon(
                          Icons.attachment,
                          size: 16,
                          color: kcSecondaryTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${recoverableDraft.mediaItems.length}',
                          style: captionStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Draft content preview
                  Text(
                    recoverableDraft.summary,
                    style: bodyStyle(context),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Context chips if available
                  if (recoverableDraft.initialEmotion != null ||
                      recoverableDraft.initialReason != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (recoverableDraft.initialEmotion != null)
                          _buildContextChip(
                            recoverableDraft.initialEmotion!,
                            Icons.sentiment_satisfied,
                          ),
                        if (recoverableDraft.initialReason != null)
                          _buildContextChip(
                            recoverableDraft.initialReason!,
                            Icons.lightbulb_outline,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Column(
              children: [
                // Restore button (primary)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onRestore();
                    },
                    icon: const Icon(Icons.restore, color: Colors.white),
                    label: Text(
                      'Continue Writing',
                      style: buttonStyle(context),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Secondary actions row
                Row(
                  children: [
                    // View history button
                    if (onViewHistory != null)
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onViewHistory!();
                          },
                          icon: Icon(
                            Icons.history,
                            size: 18,
                            color: kcSecondaryTextColor,
                          ),
                          label: Text(
                            'History',
                            style: captionStyle(context).copyWith(
                              color: kcSecondaryTextColor,
                            ),
                          ),
                        ),
                      ),

                    if (onViewHistory != null) const SizedBox(width: 12),

                    // Discard button
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showDiscardConfirmation(context);
                        },
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: kcDangerColor,
                        ),
                        label: Text(
                          'Discard',
                          style: captionStyle(context).copyWith(
                            color: kcDangerColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Start fresh button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Start Fresh',
                      style: linkStyle(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kcPrimaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kcPrimaryColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: kcPrimaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: kcPrimaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showDiscardConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          'Discard Draft?',
          style: heading1Style(context),
        ),
        content: Text(
          'This will permanently delete your unsaved writing. This action cannot be undone.',
          style: bodyStyle(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: linkStyle(context),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDiscard();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kcDangerColor,
            ),
            child: Text(
              'Discard',
              style: buttonStyle(context),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDraftAge(Duration age) {
    if (age.inMinutes < 1) {
      return 'Just now';
    } else if (age.inMinutes < 60) {
      return '${age.inMinutes}m ago';
    } else if (age.inHours < 24) {
      return '${age.inHours}h ago';
    } else {
      return '${age.inDays}d ago';
    }
  }

  /// Show the draft recovery dialog
  static Future<void> show(
    BuildContext context,
    JournalDraft recoverableDraft, {
    required VoidCallback onRestore,
    required VoidCallback onDiscard,
    VoidCallback? onViewHistory,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DraftRecoveryDialog(
        recoverableDraft: recoverableDraft,
        onRestore: onRestore,
        onDiscard: onDiscard,
        onViewHistory: onViewHistory,
      ),
    );
  }
}

/// Draft History Sheet for viewing and recovering older drafts
class DraftHistorySheet extends StatefulWidget {
  final List<JournalDraft> draftHistory;
  final Function(JournalDraft) onRestoreDraft;

  const DraftHistorySheet({
    super.key,
    required this.draftHistory,
    required this.onRestoreDraft,
  });

  @override
  State<DraftHistorySheet> createState() => _DraftHistorySheetState();
}

class _DraftHistorySheetState extends State<DraftHistorySheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kcBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: kcSecondaryTextColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  color: kcPrimaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  'Draft History',
                  style: heading1Style(context),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Draft list
          Flexible(
            child: widget.draftHistory.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        Icon(
                          Icons.drafts_outlined,
                          size: 64,
                          color: kcSecondaryTextColor.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No draft history',
                          style: bodyStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: widget.draftHistory.length,
                    itemBuilder: (context, index) {
                      final draft = widget.draftHistory[index];
                      return _buildDraftHistoryItem(draft);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftHistoryItem(JournalDraft draft) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Card(
        color: kcSurfaceAltColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          title: Text(
            draft.summary,
            style: bodyStyle(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: kcSecondaryTextColor,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDraftAge(draft.age),
                  style: captionStyle(context).copyWith(
                    color: kcSecondaryTextColor,
                  ),
                ),
                if (draft.mediaItems.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.attachment,
                    size: 14,
                    color: kcSecondaryTextColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${draft.mediaItems.length}',
                    style: captionStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing: IconButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onRestoreDraft(draft);
            },
            icon: Icon(
              Icons.restore,
              color: kcPrimaryColor,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDraftAge(Duration age) {
    if (age.inMinutes < 1) {
      return 'Just now';
    } else if (age.inMinutes < 60) {
      return '${age.inMinutes}m ago';
    } else if (age.inHours < 24) {
      return '${age.inHours}h ago';
    } else {
      return '${age.inDays}d ago';
    }
  }

  /// Show the draft history sheet
  static Future<void> show(
    BuildContext context,
    List<JournalDraft> draftHistory, {
    required Function(JournalDraft) onRestoreDraft,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraftHistorySheet(
        draftHistory: draftHistory,
        onRestoreDraft: onRestoreDraft,
      ),
    );
  }
}
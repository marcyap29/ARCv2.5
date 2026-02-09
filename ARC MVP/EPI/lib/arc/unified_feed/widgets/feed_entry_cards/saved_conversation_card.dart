/// Saved Conversation Card
///
/// Displays a saved conversation (auto-saved or manually saved) in the feed.
/// Shows message count, LUMARA reflection indicator, and preview text.

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';
import 'package:my_app/arc/unified_feed/utils/feed_helpers.dart';

class SavedConversationCard extends StatelessWidget {
  final FeedEntry entry;
  final VoidCallback? onTap;

  const SavedConversationCard({
    super.key,
    required this.entry,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kcSurfaceAltColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: kcBorderColor.withOpacity(0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: icon + title + timestamp
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: FeedHelpers.getEntryTypeColor(entry.type)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: FeedHelpers.getEntryTypeColor(entry.type),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.title,
                    style: const TextStyle(
                      color: kcPrimaryTextColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  FeedHelpers.formatFeedDate(entry.updatedAt),
                  style: TextStyle(
                    color: kcSecondaryTextColor.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Preview text
            if (entry.preview.isNotEmpty)
              Text(
                entry.preview,
                style: TextStyle(
                  color: kcPrimaryTextColor.withOpacity(0.65),
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),

            // Footer: metadata chips
            Row(
              children: [
                if (entry.messageCount > 0) ...[
                  _buildChip(
                    icon: Icons.chat_bubble_outline,
                    label: '${entry.messageCount}',
                  ),
                  const SizedBox(width: 8),
                ],
                if (entry.hasLumaraReflections) ...[
                  _buildChip(
                    icon: Icons.auto_awesome,
                    label: 'LUMARA',
                    color: kcPrimaryColor,
                  ),
                  const SizedBox(width: 8),
                ],
                if (entry.mood != null && entry.mood!.isNotEmpty)
                  _buildChip(
                    icon: Icons.mood,
                    label: entry.mood!,
                  ),
                if (entry.isPinned) ...[
                  const Spacer(),
                  Icon(
                    Icons.push_pin,
                    size: 14,
                    color: kcWarningColor.withOpacity(0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final chipColor = color ?? kcSecondaryTextColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: chipColor.withOpacity(0.7)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: chipColor.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

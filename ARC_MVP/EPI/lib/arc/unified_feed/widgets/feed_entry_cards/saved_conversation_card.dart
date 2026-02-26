/// Saved Conversation Card
///
/// Displays a saved conversation in the feed using BaseFeedCard.
/// Shows first exchange preview, exchange count, and expand chevron.
/// Phase display removed (reposition: phases not shown to user.)

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';
import 'package:my_app/arc/unified_feed/utils/feed_helpers.dart';
import 'base_feed_card.dart';

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
    return BaseFeedCard(
      entry: entry,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: icon + title + expand chevron
          Row(
            children: [
              const Icon(Icons.chat_bubble, size: 20, color: kcSecondaryTextColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.title ?? 'Conversation',
                  style: const TextStyle(
                    color: kcPrimaryTextColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.expand_more, size: 20, color: kcSecondaryTextColor.withOpacity(0.5)),
            ],
          ),
          const SizedBox(height: 10),

          // Preview of first exchange
          if (entry.preview.isNotEmpty)
            Text(
              entry.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: kcPrimaryTextColor.withOpacity(0.65),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          const SizedBox(height: 10),

          // Metadata row: creation date · exchanges (phase hidden for reposition)
          Row(
            children: [
              Text(
                FeedHelpers.formatEntryCreationDate(entry.timestamp),
                style: TextStyle(
                  color: kcSecondaryTextColor.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Text('·', style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.4))),
              const SizedBox(width: 8),
              Text(
                '${entry.exchangeCount ?? 0} exchanges',
                style: TextStyle(
                  color: kcSecondaryTextColor.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (entry.isPinned) ...[
                const SizedBox(width: 6),
                Icon(Icons.push_pin, size: 14, color: kcWarningColor.withOpacity(0.7)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Active Conversation Card
///
/// Displays an ongoing (unsaved) conversation in the unified feed.
/// Shows a pulsing indicator, message count, and the latest exchange.
/// Tapping resumes the conversation in the chat view.

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';
import 'package:my_app/arc/unified_feed/utils/feed_helpers.dart';

class ActiveConversationCard extends StatelessWidget {
  final FeedEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onSave;

  const ActiveConversationCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kcSurfaceAltColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: kcPrimaryColor.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: kcPrimaryColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: type badge + timestamp
            Row(
              children: [
                _buildActiveIndicator(),
                const SizedBox(width: 8),
                Text(
                  'Active Conversation',
                  style: TextStyle(
                    color: kcPrimaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  FeedHelpers.formatFeedDate(entry.updatedAt),
                  style: TextStyle(
                    color: kcSecondaryTextColor.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              entry.title,
              style: const TextStyle(
                color: kcPrimaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // Preview
            if (entry.preview.isNotEmpty)
              Text(
                entry.preview,
                style: TextStyle(
                  color: kcPrimaryTextColor.withOpacity(0.7),
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 10),

            // Footer: message count + save button
            Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 14,
                  color: kcSecondaryTextColor.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  '${entry.messageCount} messages',
                  style: TextStyle(
                    color: kcSecondaryTextColor.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (onSave != null)
                  GestureDetector(
                    onTap: onSave,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: kcPrimaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.save_outlined,
                            size: 14,
                            color: kcPrimaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Save',
                            style: TextStyle(
                              color: kcPrimaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

  Widget _buildActiveIndicator() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: kcSuccessColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: kcSuccessColor.withOpacity(0.4),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

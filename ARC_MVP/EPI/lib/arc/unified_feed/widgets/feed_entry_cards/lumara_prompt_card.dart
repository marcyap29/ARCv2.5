/// LUMARA Prompt Card
///
/// Displays a LUMARA-initiated observation, check-in, or prompt in the feed.
/// These are proactive entries where LUMARA reaches out based on patterns
/// detected by CHRONICLE/VEIL/SENTINEL systems.

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';
import 'package:my_app/arc/unified_feed/utils/feed_helpers.dart';
import 'base_feed_card.dart';

class LumaraPromptCard extends StatelessWidget {
  final FeedEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const LumaraPromptCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return BaseFeedCard(
      entry: entry,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: LUMARA icon + label + dismiss
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: kcPrimaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.title ?? 'LUMARA noticed something',
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
                FeedHelpers.formatEntryCreationDate(entry.timestamp),
                style: TextStyle(
                  color: kcSecondaryTextColor.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
              if (onDismiss != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: kcSecondaryTextColor.withOpacity(0.4),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Observation content
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kcPrimaryColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: kcPrimaryColor.withOpacity(0.12),
              ),
            ),
            child: Text(
              entry.preview,
              style: TextStyle(
                color: kcPrimaryTextColor.withOpacity(0.8),
                fontSize: 14,
                height: 1.5,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),

          // Action row
          Row(
            children: [
              _buildAction(
                icon: Icons.chat_bubble_outline,
                label: 'Respond',
                onTap: onTap,
              ),
              const SizedBox(width: 12),
              _buildAction(
                icon: Icons.bookmark_border,
                label: 'Save',
                onTap: () {
                  // TODO: Save observation to journal
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: kcPrimaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: kcPrimaryColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: kcPrimaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

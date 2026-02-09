/// Reflection Card
///
/// Displays a text-based reflection in the unified feed using BaseFeedCard.
/// Shows content preview, phase indicator (via left border), mood, media, themes on expand.

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';
import 'package:my_app/arc/unified_feed/utils/feed_helpers.dart';
import 'base_feed_card.dart';

class ReflectionCard extends StatelessWidget {
  final FeedEntry entry;
  final VoidCallback? onTap;

  const ReflectionCard({
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
          // Header: icon + title + expand chevron
          Row(
            children: [
              const Icon(Icons.edit_note, size: 20, color: kcSecondaryTextColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.title ?? 'Reflection',
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
          const SizedBox(height: 8),

          // Content preview
          if (entry.preview.isNotEmpty)
            Text(
              entry.preview,
              style: TextStyle(
                color: kcPrimaryTextColor.withOpacity(0.65),
                fontSize: 13,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),

          // Metadata row: phase · mood · media · timestamp
          Row(
            children: [
              if (entry.phase != null) ...[
                Text(
                  entry.phase!,
                  style: TextStyle(
                    color: entry.phaseColor ?? kcSecondaryTextColor,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Text('·', style: TextStyle(color: kcSecondaryTextColor.withOpacity(0.4))),
                const SizedBox(width: 8),
              ],
              if (entry.mood != null && entry.mood!.isNotEmpty) ...[
                Text(
                  entry.mood!,
                  style: TextStyle(
                    color: kcSecondaryTextColor.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (entry.hasMedia) ...[
                Icon(Icons.photo_library, size: 14, color: kcSecondaryTextColor.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text(
                  '${entry.mediaCount}',
                  style: TextStyle(
                    color: kcSecondaryTextColor.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (entry.hasLumaraReflections)
                Icon(Icons.auto_awesome, size: 14, color: kcPrimaryColor.withOpacity(0.6)),
              const Spacer(),
              Text(
                FeedHelpers.formatFeedDate(entry.timestamp),
                style: TextStyle(
                  color: kcSecondaryTextColor.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
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

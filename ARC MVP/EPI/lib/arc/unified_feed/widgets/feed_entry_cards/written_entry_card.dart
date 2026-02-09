/// Written Entry Card
///
/// Displays a text-based journal entry in the unified feed.
/// Shows content preview, mood/emotion, media indicator, and metadata.

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';
import 'package:my_app/arc/unified_feed/utils/feed_helpers.dart';

class WrittenEntryCard extends StatelessWidget {
  final FeedEntry entry;
  final VoidCallback? onTap;

  const WrittenEntryCard({
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
                    Icons.edit_note,
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

            // Footer: metadata chips
            Row(
              children: [
                // Mood/emotion
                if (entry.mood != null && entry.mood!.isNotEmpty) ...[
                  _buildChip(
                    icon: Icons.mood,
                    label: entry.mood!,
                  ),
                  const SizedBox(width: 8),
                ],

                // Phase
                if (entry.phase != null && entry.phase!.isNotEmpty) ...[
                  _buildChip(
                    icon: Icons.lens,
                    label: _capitalize(entry.phase!),
                    color: _phaseColor(entry.phase!),
                  ),
                  const SizedBox(width: 8),
                ],

                // Media count
                if (entry.hasMedia) ...[
                  _buildChip(
                    icon: Icons.photo_library,
                    label: '${entry.mediaCount}',
                  ),
                  const SizedBox(width: 8),
                ],

                // LUMARA reflections
                if (entry.hasLumaraReflections)
                  _buildChip(
                    icon: Icons.auto_awesome,
                    label: 'LUMARA',
                    color: kcPrimaryColor,
                  ),

                // Reading time (for longer entries)
                if (entry.preview.length > 300) ...[
                  const Spacer(),
                  Text(
                    FeedHelpers.readingTimeEstimate(entry.preview),
                    style: TextStyle(
                      color: kcSecondaryTextColor.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                ],

                // Pin indicator
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

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  Color _phaseColor(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return const Color(0xFF3B82F6);
      case 'expansion':
        return const Color(0xFF10B981);
      case 'transition':
        return const Color(0xFFF59E0B);
      case 'consolidation':
        return const Color(0xFF8B5CF6);
      case 'recovery':
        return const Color(0xFFEF4444);
      case 'breakthrough':
        return const Color(0xFFEC4899);
      default:
        return kcSecondaryTextColor;
    }
  }
}

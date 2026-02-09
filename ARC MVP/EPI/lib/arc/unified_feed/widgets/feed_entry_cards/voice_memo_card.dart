/// Voice Memo Card
///
/// Displays a voice memo/recording in the unified feed.
/// Shows duration, transcription preview (if available), and playback indicator.

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';
import 'package:my_app/arc/unified_feed/utils/feed_helpers.dart';

class VoiceMemoCard extends StatelessWidget {
  final FeedEntry entry;
  final VoidCallback? onTap;

  const VoiceMemoCard({
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
                    Icons.mic,
                    size: 16,
                    color: FeedHelpers.getEntryTypeColor(entry.type),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                          color: kcPrimaryTextColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (entry.audioDuration != null)
                        Text(
                          FeedHelpers.formatDuration(entry.audioDuration!),
                          style: TextStyle(
                            color: kcSecondaryTextColor.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                    ],
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

            // Transcription preview (if the voice memo was transcribed)
            if (entry.preview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.preview,
                style: TextStyle(
                  color: kcPrimaryTextColor.withOpacity(0.65),
                  fontSize: 13,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Waveform placeholder
            const SizedBox(height: 8),
            _buildWaveformPlaceholder(),

            // Footer metadata
            if (entry.hasLumaraReflections || entry.hasMedia)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    if (entry.hasLumaraReflections)
                      _buildChip(
                        icon: Icons.auto_awesome,
                        label: 'LUMARA',
                        color: kcPrimaryColor,
                      ),
                    if (entry.hasMedia) ...[
                      if (entry.hasLumaraReflections)
                        const SizedBox(width: 8),
                      _buildChip(
                        icon: Icons.attach_file,
                        label: '${entry.mediaCount}',
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveformPlaceholder() {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: FeedHelpers.getEntryTypeColor(entry.type).withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(
            Icons.play_arrow,
            size: 16,
            color: FeedHelpers.getEntryTypeColor(entry.type),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: 0.0,
                backgroundColor: FeedHelpers.getEntryTypeColor(entry.type)
                    .withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  FeedHelpers.getEntryTypeColor(entry.type),
                ),
                minHeight: 3,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
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

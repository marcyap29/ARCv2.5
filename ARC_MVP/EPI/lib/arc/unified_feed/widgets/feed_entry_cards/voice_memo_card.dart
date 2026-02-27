/// Voice Memo Card
///
/// Displays a voice memo/recording in the unified feed using BaseFeedCard.
/// Shows waveform placeholder, duration, transcript preview.
library;

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/arc/unified_feed/models/feed_entry.dart';
import 'package:my_app/arc/unified_feed/utils/feed_helpers.dart';
import 'base_feed_card.dart';

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
    return BaseFeedCard(
      entry: entry,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: mic icon + title + duration + timestamp
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mic, size: 16, color: Color(0xFF059669)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title ?? 'Voice Memo',
                      style: const TextStyle(
                        color: kcPrimaryTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.duration != null)
                      Text(
                        FeedHelpers.formatDuration(entry.duration!),
                        style: TextStyle(
                          color: kcSecondaryTextColor.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                FeedHelpers.formatEntryCreationDate(entry.timestamp),
                style: TextStyle(
                  color: kcSecondaryTextColor.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),

          // Transcript preview
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
        ],
      ),
    );
  }

  Widget _buildWaveformPlaceholder() {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF059669).withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.play_arrow, size: 16, color: Color(0xFF059669)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: 0.0,
                backgroundColor: const Color(0xFF059669).withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                minHeight: 3,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

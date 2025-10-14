import 'package:flutter/material.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/text_style.dart';
import '../../../models/journal_entry_model.dart';
import '../../../features/timeline/timeline_view.dart';

/// Bottom sheet showing entries linked to a keyword or edge
class MiraNodeSheet extends StatelessWidget {
  final String keyword;
  final int frequency;
  final List<JournalEntry> entries;
  final bool isEdge;

  const MiraNodeSheet({
    super.key,
    required this.keyword,
    required this.frequency,
    required this.entries,
    this.isEdge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: kcSecondaryTextColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  isEdge ? Icons.link : Icons.topic,
                  color: kcPrimaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        keyword,
                        style: heading3Style(context).copyWith(
                          color: kcPrimaryTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isEdge 
                            ? '$frequency co-occurrences'
                            : '$frequency entries',
                        style: bodyStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Entries list
          if (entries.isEmpty)
            _buildEmptyState(context)
          else
            _buildEntriesList(context),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 48,
            color: kcSecondaryTextColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No entries found',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(BuildContext context) {
    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return _buildEntryItem(context, entry);
        },
      ),
    );
  }

  Widget _buildEntryItem(BuildContext context, JournalEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kcSecondaryTextColor.withOpacity(0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pop(context); // Close the sheet
            _navigateToEntryDetail(context, entry);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and phase
                Row(
                  children: [
                    Text(
                      _formatDate(entry.createdAt),
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (entry.emotion != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: kcPrimaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          entry.emotion!,
                          style: bodyStyle(context).copyWith(
                            color: kcPrimaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Content preview
                Text(
                  entry.content,
                  style: bodyStyle(context).copyWith(
                    color: kcPrimaryTextColor,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                
                if (entry.keywords.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  
                  // Keywords
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: entry.keywords.take(5).map((keyword) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: kcAccentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          keyword,
                          style: bodyStyle(context).copyWith(
                            color: kcAccentColor,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _navigateToEntryDetail(BuildContext context, JournalEntry entry) {
    // Navigate to timeline detail view
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TimelineView(),
      ),
    );
  }
}

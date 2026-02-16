import 'package:flutter/material.dart';
import 'package:my_app/lumara/agents/models/content_draft.dart';
import 'package:my_app/shared/app_colors.dart';

class ContentDraftCard extends StatelessWidget {
  final ContentDraft draft;
  final VoidCallback? onTap;

  const ContentDraftCard({
    super.key,
    required this.draft,
    this.onTap,
  });

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[time.month - 1]} ${time.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: kcSurfaceAltColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kcPrimaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_note,
                      size: 20,
                      color: kcPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          draft.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: kcPrimaryTextColor,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 14, color: kcSecondaryColor),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(draft.updatedAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: kcSecondaryColor),
                            ),
                            if (draft.contentType != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: kcPrimaryColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  draft.contentType!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: kcPrimaryColor),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: kcSecondaryColor),
                ],
              ),
              if (draft.preview.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  draft.preview,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: kcPrimaryTextColor,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

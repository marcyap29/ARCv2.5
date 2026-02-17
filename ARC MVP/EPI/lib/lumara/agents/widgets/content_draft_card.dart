import 'package:flutter/material.dart';
import 'package:my_app/lumara/agents/models/content_draft.dart';
import 'package:my_app/shared/app_colors.dart';

class ContentDraftCard extends StatelessWidget {
  final ContentDraft draft;
  final VoidCallback? onTap;
  final VoidCallback? onMarkFinished;
  final VoidCallback? onArchive;
  final VoidCallback? onUnarchive;
  final VoidCallback? onDelete;
  final VoidCallback? onChanged;

  const ContentDraftCard({
    super.key,
    required this.draft,
    this.onTap,
    this.onMarkFinished,
    this.onArchive,
    this.onUnarchive,
    this.onDelete,
    this.onChanged,
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
                            const Icon(Icons.schedule,
                                size: 14, color: kcSecondaryColor),
                            const SizedBox(width: 4),
                            Text(
                              draft.createdAt != null
                                  ? 'Created ${_formatTime(draft.createdAt!)}'
                                  : _formatTime(draft.updatedAt),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: kcSecondaryColor),
                            ),
                            if (draft.status == ContentDraftStatus.finished) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Finished',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: Colors.green[700]),
                                ),
                              ),
                            ],
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
                            if (draft.wordCount > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${draft.wordCount} words',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: kcSecondaryColor),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: kcSecondaryColor),
                    onSelected: (value) {
                      switch (value) {
                        case 'finished':
                          onMarkFinished?.call();
                          break;
                        case 'archive':
                          onArchive?.call();
                          break;
                        case 'unarchive':
                          onUnarchive?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                      onChanged?.call();
                    },
                    itemBuilder: (context) => [
                      if (draft.status != ContentDraftStatus.finished)
                        const PopupMenuItem(
                          value: 'finished',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 20),
                              SizedBox(width: 12),
                              Text('Mark finished'),
                            ],
                          ),
                        ),
                      if (!draft.archived)
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive_outlined, size: 20),
                              SizedBox(width: 12),
                              Text('Archive'),
                            ],
                          ),
                        ),
                      if (draft.archived)
                        const PopupMenuItem(
                          value: 'unarchive',
                          child: Row(
                            children: [
                              Icon(Icons.unarchive_outlined, size: 20),
                              SizedBox(width: 12),
                              Text('Unarchive'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
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

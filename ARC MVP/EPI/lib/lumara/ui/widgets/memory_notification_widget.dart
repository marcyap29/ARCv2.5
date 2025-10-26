// lib/lumara/ui/widgets/memory_notification_widget.dart
// UI widget for displaying memory notifications

import 'package:flutter/material.dart';
import 'package:my_app/models/journal_entry_model.dart';
import '../services/memory_notification_service.dart';

class MemoryNotificationWidget extends StatelessWidget {
  final MemoryNotification memory;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const MemoryNotificationWidget({
    Key? key,
    required this.memory,
    this.onTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Dismissible(
      key: Key('memory_${memory.entry.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => onDismiss?.call(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: memory.isExactMatch 
                ? colorScheme.primary.withOpacity(0.3)
                : colorScheme.outline.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with years ago badge
                Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: memory.isExactMatch
                          ? colorScheme.primary.withOpacity(0.1)
                          : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: memory.isExactMatch
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Time badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: memory.isExactMatch
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: memory.isExactMatch
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${memory.yearsAgo} year${memory.yearsAgo > 1 ? 's' : ''} ago',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: memory.isExactMatch
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Dismiss button
                    if (onDismiss != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: onDismiss,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 20,
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Notification text
                Text(
                  memory.notificationText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Phase connection badge (if available)
                if (memory.getPhaseConnectionText() != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.secondaryContainer,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cycle,
                          size: 12,
                          color: colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          memory.getPhaseConnectionText()!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                
                // Entry preview
                Text(
                  _truncateContent(memory.entry.content),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Date
                Text(
                  _formatDate(memory.memoryDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  String _truncateContent(String content) {
    if (content.length <= 120) return content;
    return '${content.substring(0, 120)}...';
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
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} week${(difference.inDays / 7).floor() > 1 ? 's' : ''} ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}

/// Container for multiple memory notifications
class MemoryNotificationsContainer extends StatelessWidget {
  final List<MemoryNotification> memories;
  final Function(MemoryNotification)? onMemoryTap;
  final Function(MemoryNotification)? onMemoryDismiss;

  const MemoryNotificationsContainer({
    Key? key,
    required this.memories,
    this.onMemoryTap,
    this.onMemoryDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (memories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: memories.map((memory) {
        return MemoryNotificationWidget(
          memory: memory,
          onTap: () => onMemoryTap?.call(memory),
          onDismiss: () => onMemoryDismiss?.call(memory),
        );
      }).toList(),
    );
  }
}


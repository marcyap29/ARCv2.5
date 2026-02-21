/// Conflict Resolution Dialog
///
/// Shows a dialog when conflicts are detected between local and remote drafts

import 'package:flutter/material.dart';
import 'package:my_app/core/services/journal_version_service.dart';

class ConflictResolutionDialog extends StatelessWidget {
  final ConflictInfo conflict;
  final String entryId;

  const ConflictResolutionDialog({
    super.key,
    required this.conflict,
    required this.entryId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Changes found from another device'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This entry was modified on another device. Choose how to resolve the conflict:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _buildConflictInfo(context),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _resolveAndPop(context, ConflictResolution.keepLocal),
          child: const Text('Keep Local'),
        ),
        TextButton(
          onPressed: () => _resolveAndPop(context, ConflictResolution.keepRemote),
          child: const Text('Keep Remote'),
        ),
        TextButton(
          onPressed: () => _resolveAndPop(context, ConflictResolution.merge),
          child: const Text('Merge'),
        ),
      ],
    );
  }

  Widget _buildConflictInfo(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_android, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Local',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Updated: ${_formatTime(conflict.localUpdatedAt)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.cloud, size: 16, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                'Remote',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Updated: ${_formatTime(conflict.remoteUpdatedAt)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _resolveAndPop(BuildContext context, ConflictResolution resolution) async {
    try {
      final versionService = JournalVersionService.instance;
      await versionService.resolveConflict(
        entryId: entryId,
        conflict: conflict,
        resolution: resolution,
      );
      
      if (context.mounted) {
        Navigator.of(context).pop(resolution);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getResolutionMessage(resolution)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resolve conflict: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _getResolutionMessage(ConflictResolution resolution) {
    switch (resolution) {
      case ConflictResolution.keepLocal:
        return 'Kept local changes';
      case ConflictResolution.keepRemote:
        return 'Applied remote changes';
      case ConflictResolution.merge:
        return 'Merged changes (media deduplicated by SHA256)';
    }
  }
}


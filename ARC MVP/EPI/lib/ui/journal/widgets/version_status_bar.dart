/// Version Status Bar Widget
///
/// Displays draft state, version info, and action buttons for versioning system

import 'package:flutter/material.dart';
import 'package:my_app/core/services/journal_version_service.dart';
import 'package:my_app/core/services/draft_cache_service.dart';

class VersionStatusBar extends StatelessWidget {
  final String? entryId;
  final VoidCallback? onSaveVersion;
  final VoidCallback? onPublish;
  final VoidCallback? onDiscard;

  const VersionStatusBar({
    super.key,
    this.entryId,
    this.onSaveVersion,
    this.onPublish,
    this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    if (entryId == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<VersionStatus>(
      future: _loadVersionStatus(entryId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final status = snapshot.data!;
        final theme = Theme.of(context);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Status indicator
              Icon(
                status.hasDraft ? Icons.edit : Icons.check_circle,
                size: 16,
                color: status.hasDraft 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              
              // Status text
              Expanded(
                child: Text(
                  _getStatusText(status),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              // Action buttons
              if (status.hasDraft) ...[
                TextButton.icon(
                  onPressed: onSaveVersion,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save Version'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 32),
                    textStyle: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onPublish,
                  icon: const Icon(Icons.publish, size: 16),
                  label: const Text('Publish'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 32),
                    textStyle: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onDiscard,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Discard'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 32),
                    textStyle: theme.textTheme.bodySmall,
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<VersionStatus> _loadVersionStatus(String entryId) async {
    final versionService = JournalVersionService.instance;
    final draft = await versionService.getDraft(entryId);
    final latest = await versionService.getLatestVersion(entryId);

    // Get base revision if editing old version
    int? baseRev;
    if (draft?.baseVersionId != null) {
      final allVersions = await versionService.getAllVersions(entryId);
      try {
        final baseVersion = allVersions.firstWhere(
          (v) => v.versionId == draft!.baseVersionId,
        );
        baseRev = baseVersion.rev;
      } catch (e) {
        // Base version not found
      }
    }

    // Count words in content
    final wordCount = draft?.content
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length ?? 0;

    return VersionStatus(
      hasDraft: draft != null,
      latestRev: latest?.rev ?? 0,
      baseRev: baseRev,
      lastSaved: draft?.updatedAt,
      mediaCount: draft?.media.length ?? 0,
      aiCount: draft?.ai.length ?? 0,
      wordCount: wordCount,
    );
  }

  String _getStatusText(VersionStatus status) {
    if (status.hasDraft) {
      final baseText = status.baseRev != null 
          ? 'Based on v${status.baseRev}' 
          : 'Working draft';
      
      final parts = <String>[];
      
      // Word count
      if (status.wordCount > 0) {
        parts.add('${status.wordCount} words');
      }
      
      // Media count
      if (status.mediaCount > 0) {
        parts.add('${status.mediaCount} media');
      }
      
      // AI count
      if (status.aiCount > 0) {
        parts.add('${status.aiCount} AI');
      }
      
      final details = parts.isNotEmpty ? ' • ${parts.join(' • ')}' : '';
      final savedText = status.lastSaved != null
          ? ' • last saved ${_formatRelativeTime(status.lastSaved!)}'
          : '';
      
      return '$baseText$details$savedText';
    } else if (status.latestRev > 0) {
      return 'Latest v${status.latestRev}';
    } else {
      return 'No versions';
    }
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class VersionStatus {
  final bool hasDraft;
  final int latestRev;
  final int? baseRev;
  final DateTime? lastSaved;
  final int mediaCount;
  final int aiCount;
  final int wordCount;

  VersionStatus({
    required this.hasDraft,
    required this.latestRev,
    this.baseRev,
    this.lastSaved,
    this.mediaCount = 0,
    this.aiCount = 0,
    this.wordCount = 0,
  });
}


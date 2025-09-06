import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import '../../core/sync/sync_toggle_cubit.dart';

class SyncSettingsSection extends StatelessWidget {
  const SyncSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SyncToggleCubit(),
      child: const _SyncSettingsContent(),
    );
  }
}

class _SyncSettingsContent extends StatelessWidget {
  const _SyncSettingsContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncToggleCubit, SyncToggleState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Cloud Sync',
              style: heading2Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            
            // Toggle Row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  // Toggle Switch
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cloud Sync (coming soon)',
                              style: heading3Style(context).copyWith(
                                color: kcPrimaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sync your data across devices',
                              style: bodyStyle(context).copyWith(
                                color: kcSecondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        label: 'Toggle cloud sync',
                        child: Switch(
                          value: state.enabled,
                          onChanged: state.isLoading 
                              ? null 
                              : (value) {
                                  context.read<SyncToggleCubit>().toggleSync(value);
                                },
                          activeColor: kcAccentColor,
                          inactiveThumbColor: kcSecondaryTextColor,
                          inactiveTrackColor: kcSecondaryTextColor.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(state.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getStatusColor(state.status).withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getStatusColor(state.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.status,
                          style: captionStyle(context).copyWith(
                            color: _getStatusColor(state.status),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Disclosure Text
                  Text(
                    'App is offline-first; cloud sync disabled until accounts launch.',
                    style: captionStyle(context).copyWith(
                      color: kcSecondaryTextColor.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  
                  // Queue Actions (if enabled and has items)
                  if (state.enabled && state.queuedCount > 0) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              context.read<SyncToggleCubit>().clearCompleted();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kcSecondaryTextColor,
                              side: BorderSide(
                                color: kcSecondaryTextColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              'Clear Completed',
                              style: captionStyle(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _showClearQueueDialog(context);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.withOpacity(0.8),
                              side: BorderSide(
                                color: Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              'Clear All',
                              style: captionStyle(context).copyWith(
                                color: Colors.red.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Sync off':
        return kcSecondaryTextColor;
      case 'Idle':
        return Colors.green;
      case 'Syncing...':
        return Colors.orange;
      default:
        if (status.startsWith('Queued')) {
          return Colors.blue;
        }
        return kcSecondaryTextColor;
    }
  }

  void _showClearQueueDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcSurfaceColor,
        title: Text(
          'Clear Sync Queue',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
          ),
        ),
        content: Text(
          'This will remove all queued items from the sync queue. This action cannot be undone.',
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<SyncToggleCubit>().clearQueue();
              Navigator.of(context).pop();
            },
            child: Text(
              'Clear All',
              style: bodyStyle(context).copyWith(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

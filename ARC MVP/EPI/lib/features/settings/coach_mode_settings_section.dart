import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../mode/coach/coach_mode_cubit.dart';
import '../../mode/coach/coach_mode_state.dart';
import '../../mode/coach/ui/coach_mode_drawer.dart';
import '../../mode/coach/widgets/coach_what_changes_sheet.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';

class CoachModeSettingsSection extends StatelessWidget {
  const CoachModeSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CoachModeCubit, CoachModeState>(
      builder: (context, state) {
        if (state is CoachModeLoading) {
          return const ListTile(
            leading: CircularProgressIndicator(),
            title: Text('Loading Coach Mode...'),
          );
        }

        if (state is CoachModeError) {
          return ListTile(
            leading: const Icon(Icons.error, color: Colors.red),
            title: const Text('Coach Mode Error'),
            subtitle: Text(state.message),
            trailing: TextButton(
              onPressed: () => context.read<CoachModeCubit>().refreshState(),
              child: const Text('Retry'),
            ),
          );
        }

        if (state is! CoachModeEnabled) {
          return const ListTile(
            leading: Icon(Icons.psychology),
            title: Text('Coach Mode'),
            subtitle: Text('Not available'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Coach Mode',
              style: heading2Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            // Master toggle
            _buildToggleTile(
              context,
              title: 'Enable Coach Mode',
              subtitle: state.enabled
                  ? 'Active - Access coaching tools and share data'
                  : 'Inactive - Enable to access coaching features',
              icon: Icons.psychology,
              value: state.enabled,
              onChanged: (value) {
                if (value) {
                  context.read<CoachModeCubit>().enable();
                  _showCoachWhatChangesSheet(context);
                } else {
                  context.read<CoachModeCubit>().disable();
                }
              },
            ),
            
            if (state.enabled) ...[
              const SizedBox(height: 16),
              
              // Coaching Tools
              _buildActionTile(
                context,
                title: 'Coaching Tools',
                subtitle: 'Open coaching tools drawer',
                icon: Icons.tune,
                onTap: () => _showCoachModeDrawer(context),
              ),
              
              _buildActionTile(
                context,
                title: 'Share with Coach',
                subtitle: state.pendingShareCount > 0
                    ? '${state.pendingShareCount} items ready to share'
                    : 'No items ready to share',
                icon: Icons.share,
                onTap: state.pendingShareCount > 0
                    ? () => _showShareReview(context)
                    : null,
              ),
              
              _buildActionTile(
                context,
                title: 'Import from Coach',
                subtitle: 'Add coach recommendations',
                icon: Icons.download,
                onTap: () => _importCoachReply(context),
              ),
              
              _buildActionTile(
                context,
                title: 'Customize Droplets',
                subtitle: 'Choose which tools to show',
                icon: Icons.settings,
                onTap: () => _showCustomization(context),
              ),
              
              _buildActionTile(
                context,
                title: 'Privacy & Consent',
                subtitle: 'Control what gets shared',
                icon: Icons.privacy_tip,
                onTap: () => _showPrivacySettings(context),
              ),
              
              if (state.recentResponses.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildActionTile(
                  context,
                  title: 'Recent Activity',
                  subtitle: '${state.recentResponses.length} recent responses',
                  icon: Icons.history,
                  onTap: () => _showRecentActivity(context, state),
                ),
              ],
            ],
            
            if (state.enabled)
              const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildToggleTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: SwitchListTile(
        secondary: Icon(
          icon,
          color: value ? kcAccentColor : kcSecondaryTextColor,
          size: 24,
        ),
        title: Text(
          title,
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeTrackColor: kcAccentColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: onTap != null ? kcAccentColor : kcSecondaryTextColor,
          size: 24,
        ),
        title: Text(
          title,
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
          ),
        ),
        trailing: onTap != null
            ? const Icon(
                Icons.arrow_forward_ios,
                color: kcSecondaryTextColor,
                size: 16,
              )
            : null,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
      ),
    );
  }

  void _showCoachWhatChangesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<CoachModeCubit>(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: const CoachWhatChangesSheet(),
        ),
      ),
    );
  }

  void _showCoachModeDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: const CoachModeDrawer(),
      ),
    );
  }

  void _showShareReview(BuildContext context) {
    // This would be implemented in the share review sheet
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share review coming soon!')),
    );
  }

  void _importCoachReply(BuildContext context) {
    // This would implement file picker for CRB import
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import from Coach coming soon!')),
    );
  }

  void _showCustomization(BuildContext context) {
    // This would show customization UI
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Customize Droplets coming soon!')),
    );
  }

  void _showPrivacySettings(BuildContext context) {
    // This would show privacy settings UI
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy & Consent settings coming soon!')),
    );
  }

  void _showRecentActivity(BuildContext context, CoachModeEnabled state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recent Activity'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: state.recentResponses.length,
            itemBuilder: (context, index) {
              final response = state.recentResponses[index];
              return ListTile(
                leading: const Icon(Icons.assignment_turned_in),
                title: Text('Response from ${_formatDate(response.createdAt)}'),
                subtitle: Text('${response.values.length} fields'),
                trailing: response.includeInShare
                    ? const Icon(Icons.share, color: Colors.blue)
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
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
      return '${date.month}/${date.day}';
    }
  }
}

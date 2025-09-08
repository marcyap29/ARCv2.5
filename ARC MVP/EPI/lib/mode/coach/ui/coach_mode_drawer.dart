import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../coach_mode_cubit.dart';
import '../coach_mode_state.dart';
import '../models/coach_models.dart';
import 'droplet_runner_view.dart';
import 'share_review_sheet.dart';

class CoachModeDrawer extends StatelessWidget {
  const CoachModeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CoachModeCubit, CoachModeState>(
      builder: (context, state) {
        if (state is CoachModeLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is CoachModeError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error: ${state.message}',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.read<CoachModeCubit>().refreshState(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (state is! CoachModeEnabled) {
          return const Center(child: Text('Coach Mode not available'));
        }

        return _buildDrawerContent(context, state);
      },
    );
  }

  Widget _buildDrawerContent(BuildContext context, CoachModeEnabled state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, state),
          const SizedBox(height: 24),
          _buildQuickLogRow(context, state),
          const SizedBox(height: 24),
          _buildPrimaryTools(context, state),
          const SizedBox(height: 24),
          _buildSecondaryTools(context, state),
          const SizedBox(height: 24),
          _buildRecentActivity(context, state),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CoachModeEnabled state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.psychology,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coach Mode',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Private by default. You choose what to share.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: state.enabled,
            onChanged: (value) {
              if (value) {
                context.read<CoachModeCubit>().enable();
              } else {
                context.read<CoachModeCubit>().disable();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLogRow(BuildContext context, CoachModeEnabled state) {
    final quickLogItems = [
      _QuickLogItem(
        icon: Icons.restaurant,
        title: 'Diet',
        templateId: 'coach.diet_intake.v1',
        color: Colors.orange,
      ),
      _QuickLogItem(
        icon: Icons.check_circle,
        title: 'Habits',
        templateId: 'coach.habits_daily.v1',
        color: Colors.green,
      ),
      _QuickLogItem(
        icon: Icons.checklist,
        title: 'Checklist',
        templateId: 'coach.checklist_done.v1',
        color: Colors.blue,
      ),
      _QuickLogItem(
        icon: Icons.bedtime,
        title: 'Sleep',
        templateId: 'coach.sleep_recovery.v1',
        color: Colors.purple,
      ),
      _QuickLogItem(
        icon: Icons.directions_run,
        title: 'Exercise',
        templateId: 'coach.exercise_session.v1',
        color: Colors.red,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Log',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: quickLogItems.length,
            itemBuilder: (context, index) {
              final item = quickLogItems[index];
              return _buildQuickLogCard(context, item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickLogCard(BuildContext context, _QuickLogItem item) {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => _startDroplet(context, item.templateId),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: item.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                color: item.color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                item.title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: item.color,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryTools(BuildContext context, CoachModeEnabled state) {
    final primaryTools = [
      _ToolItem(
        title: 'Pre-Session Check-in',
        subtitle: '2 min',
        icon: Icons.play_arrow,
        templateId: 'coach.pre_session.v1',
        color: Colors.blue,
      ),
      _ToolItem(
        title: 'Post-Session Debrief',
        subtitle: '3 min',
        icon: Icons.refresh,
        templateId: 'coach.post_session.v1',
        color: Colors.green,
      ),
      _ToolItem(
        title: 'Weekly Goals & Friction Map',
        subtitle: '3 min',
        icon: Icons.flag,
        templateId: 'coach.weekly_goals.v1',
        color: Colors.orange,
      ),
      _ToolItem(
        title: 'Stress Pulse (1-min)',
        subtitle: '1 min',
        icon: Icons.favorite,
        templateId: 'coach.stress_pulse.v1',
        color: Colors.red,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coaching Tools',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...primaryTools.map((tool) => _buildToolCard(context, tool)),
      ],
    );
  }

  Widget _buildSecondaryTools(BuildContext context, CoachModeEnabled state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More Tools',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildSecondaryToolCard(
          context,
          'Share with Coach',
          'Review & export your data',
          Icons.share,
          () => _showShareReview(context),
        ),
        const SizedBox(height: 8),
        _buildSecondaryToolCard(
          context,
          'Import from Coach',
          'Add coach recommendations',
          Icons.download,
          () => _importCoachReply(context),
        ),
        const SizedBox(height: 8),
        _buildSecondaryToolCard(
          context,
          'Customize Droplets',
          'Choose which tools to show',
          Icons.settings,
          () => _showCustomization(context),
        ),
        const SizedBox(height: 8),
        _buildSecondaryToolCard(
          context,
          'Privacy & Consent',
          'Control what gets shared',
          Icons.privacy_tip,
          () => _showPrivacySettings(context),
        ),
      ],
    );
  }

  Widget _buildToolCard(BuildContext context, _ToolItem tool) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _startDroplet(context, tool.templateId),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tool.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  tool.icon,
                  color: tool.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      tool.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryToolCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, CoachModeEnabled state) {
    if (state.recentResponses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...state.recentResponses.take(3).map((response) => _buildRecentItem(context, response)),
      ],
    );
  }

  Widget _buildRecentItem(BuildContext context, CoachDropletResponse response) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.assignment_turned_in,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Response from ${_formatDate(response.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (response.includeInShare)
            Icon(
              Icons.share,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }

  void _startDroplet(BuildContext context, String templateId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DropletRunnerView(templateId: templateId),
      ),
    );
  }

  void _showShareReview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ShareReviewSheet(),
    );
  }

  void _importCoachReply(BuildContext context) {
    // TODO: Implement file picker for CRB import
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import from Coach coming soon!')),
    );
  }

  void _showCustomization(BuildContext context) {
    // TODO: Implement customization UI
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Customize Droplets coming soon!')),
    );
  }

  void _showPrivacySettings(BuildContext context) {
    // TODO: Implement privacy settings UI
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy & Consent settings coming soon!')),
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

class _QuickLogItem {
  final IconData icon;
  final String title;
  final String templateId;
  final Color color;

  const _QuickLogItem({
    required this.icon,
    required this.title,
    required this.templateId,
    required this.color,
  });
}

class _ToolItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String templateId;
  final Color color;

  const _ToolItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.templateId,
    required this.color,
  });
}

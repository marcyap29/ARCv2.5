import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import '../bloc/lumara_assistant_cubit.dart';

/// Quick palette for common LUMARA queries
class LumaraQuickPalette extends StatelessWidget {
  const LumaraQuickPalette({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(24),
          
          // Title
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(16),
          
          // Quick actions
          _buildQuickAction(
            context,
            icon: Icons.timeline,
            title: 'Weekly Summary',
            subtitle: 'Get insights about your last 7 days',
            onTap: () => _sendQuery(context, 'Summarize my last 7 days'),
          ),
          
          _buildQuickAction(
            context,
            icon: Icons.trending_up,
            title: 'Rising Patterns',
            subtitle: 'Discover emerging themes and patterns',
            onTap: () => _sendQuery(context, 'What patterns do you see rising?'),
          ),
          
          _buildQuickAction(
            context,
            icon: Icons.psychology,
            title: 'Phase Analysis',
            subtitle: 'Understand your current developmental phase',
            onTap: () => _sendQuery(context, 'Why am I in this phase?'),
          ),
          
          _buildQuickAction(
            context,
            icon: Icons.compare_arrows,
            title: 'Compare Periods',
            subtitle: 'Compare this week to previous weeks',
            onTap: () => _sendQuery(context, 'Compare this week to last week'),
          ),
          
          _buildQuickAction(
            context,
            icon: Icons.lightbulb_outline,
            title: 'Prompt Suggestion',
            subtitle: 'Get personalized journal prompts',
            onTap: () => _sendQuery(context, 'Suggest a prompt for tonight'),
          ),
          
          _buildQuickAction(
            context,
            icon: Icons.insights,
            title: 'Deep Dive',
            subtitle: 'Explore a specific aspect of your data',
            onTap: () => _sendQuery(context, 'What should I focus on right now?'),
          ),
          
          const Gap(24),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.blue[700],
                size: 24,
              ),
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void _sendQuery(BuildContext context, String query) {
    Navigator.pop(context);
    // Send the query to the LUMARA assistant
    context.read<LumaraAssistantCubit>().sendMessage(query);
  }
}

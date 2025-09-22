import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'fr_settings_cubit.dart';
import 'fr_settings.dart';
import 'debrief/debrief_flow_screen.dart';
import 'incident_template/incident_template_flow_screen.dart';

/// First Responder Dashboard
/// Main hub for all FR features and quick access
class FRDashboard extends StatefulWidget {
  const FRDashboard({super.key});

  @override
  State<FRDashboard> createState() => _FRDashboardState();
}

class _FRDashboardState extends State<FRDashboard> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FRSettingsCubit, FRSettings>(
      builder: (context, settings) {
        return Scaffold(
          backgroundColor: kcBackgroundColor,
          appBar: AppBar(
            backgroundColor: kcBackgroundColor,
            elevation: 0,
            title: Text(
              'First Responder Hub',
              style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: kcAccentColor),
                onPressed: () => _navigateToSettings(context),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile status
                _buildProfileStatus(settings),
                
                const SizedBox(height: 24),
                
                // Quick actions
                _buildQuickActions(),
                
                const SizedBox(height: 24),
                
                // Recent activity
                _buildRecentActivity(),
                
                const SizedBox(height: 24),
                
                // Recovery recommendations
                _buildRecoveryRecommendations(),
                
                const SizedBox(height: 24),
                
                // All features grid
                _buildFeaturesGrid(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileStatus(FRSettings settings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person,
                color: kcAccentColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Profile Status',
                style: heading3Style(context).copyWith(color: kcPrimaryTextColor),
              ),
              const Spacer(),
              if (settings.hasCompleteProfile)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Complete',
                    style: bodyStyle(context).copyWith(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Incomplete',
                    style: bodyStyle(context).copyWith(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          
          if (settings.hasCompleteProfile) ...[
            const SizedBox(height: 12),
            Text(
              '${settings.displayRole} • ${settings.department ?? 'Department'}',
              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
            if (settings.shiftPattern != null)
              Text(
                'Shift: ${settings.displayShiftPattern}',
                style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'Complete your profile to unlock personalized features',
              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _navigateToProfileSetup(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: kcAccentColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                'Set Up Profile',
                style: bodyStyle(context).copyWith(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.mic,
                title: 'Voice Debrief',
                subtitle: '60s or 5min',
                color: kcAccentColor,
                onTap: () => _navigateToDebrief(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.assignment,
                title: 'Incident Report',
                subtitle: 'AAR-SAGE',
                color: Colors.blue,
                onTap: () => _navigateToIncidentTemplate(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.assessment,
                title: 'Check In',
                subtitle: 'How are you?',
                color: Colors.green,
                onTap: () => _navigateToCheckIn(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.psychology,
                title: 'Grounding',
                subtitle: '30-90s',
                color: Colors.purple,
                onTap: () => _navigateToGrounding(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: heading3Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontSize: 14,
              ),
            ),
            Text(
              subtitle,
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              _buildActivityItem('Check-ins today', '3', Icons.assessment),
              _buildActivityItem('Debriefs this week', '2', Icons.mic),
              _buildActivityItem('Incidents reported', '1', Icons.assignment),
              _buildActivityItem('Grounding sessions', '5', Icons.psychology),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: kcAccentColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
          ),
          Text(
            value,
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recovery Recommendations',
          style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'High Stress Detected',
                    style: bodyStyle(context).copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Consider taking extra recovery time and practicing grounding exercises.',
                style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _navigateToGrounding(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  'Start Grounding',
                  style: bodyStyle(context).copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Features',
          style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildFeatureCard(
              icon: Icons.mic,
              title: 'Voice Debrief',
              description: '60s or 5min guided debrief',
              color: kcAccentColor,
              onTap: () => _navigateToDebrief(context),
            ),
            _buildFeatureCard(
              icon: Icons.assignment,
              title: 'Incident Reports',
              description: 'AAR-SAGE templates',
              color: Colors.blue,
              onTap: () => _navigateToIncidentTemplate(context),
            ),
            _buildFeatureCard(
              icon: Icons.assessment,
              title: 'Check-ins',
              description: 'Wellness tracking',
              color: Colors.green,
              onTap: () => _navigateToCheckIn(context),
            ),
            _buildFeatureCard(
              icon: Icons.psychology,
              title: 'Grounding',
              description: '30-90s exercises',
              color: Colors.purple,
              onTap: () => _navigateToGrounding(context),
            ),
            _buildFeatureCard(
              icon: Icons.schedule,
              title: 'Shift Rhythm',
              description: 'AURORA-Lite prompts',
              color: Colors.orange,
              onTap: () => _navigateToShiftRhythm(context),
            ),
            _buildFeatureCard(
              icon: Icons.share,
              title: 'Clean Share',
              description: 'Export & redaction',
              color: Colors.teal,
              onTap: () => _navigateToCleanShare(context),
            ),
            _buildFeatureCard(
              icon: Icons.help,
              title: 'Help Now',
              description: 'Emergency contacts',
              color: Colors.red,
              onTap: () => _navigateToHelpNow(context),
            ),
            _buildFeatureCard(
              icon: Icons.settings,
              title: 'Settings',
              description: 'Profile & preferences',
              color: Colors.grey,
              onTap: () => _navigateToSettings(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: heading3Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Navigation methods
  void _navigateToDebrief(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DebriefFlowScreen(),
      ),
    );
  }

  void _navigateToIncidentTemplate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const IncidentTemplateFlowScreen(),
      ),
    );
  }

  void _navigateToCheckIn(BuildContext context) {
    // TODO: Navigate to check-in screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Check-in feature coming soon')),
    );
  }

  void _navigateToGrounding(BuildContext context) {
    // TODO: Navigate to grounding exercises screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Grounding exercises coming soon')),
    );
  }

  void _navigateToShiftRhythm(BuildContext context) {
    // TODO: Navigate to shift rhythm screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shift rhythm feature coming soon')),
    );
  }

  void _navigateToCleanShare(BuildContext context) {
    // TODO: Navigate to clean share screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clean share feature coming soon')),
    );
  }

  void _navigateToHelpNow(BuildContext context) {
    // TODO: Navigate to help now screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Help now feature coming soon')),
    );
  }

  void _navigateToSettings(BuildContext context) {
    // TODO: Navigate to FR settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings coming soon')),
    );
  }

  void _navigateToProfileSetup(BuildContext context) {
    // TODO: Navigate to profile setup screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile setup coming soon')),
    );
  }
}

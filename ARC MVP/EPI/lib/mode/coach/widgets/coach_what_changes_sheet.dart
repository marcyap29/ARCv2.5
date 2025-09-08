import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import '../coach_mode_cubit.dart';
import '../coach_mode_state.dart';

class CoachWhatChangesSheet extends StatelessWidget {
  const CoachWhatChangesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: BlocBuilder<CoachModeCubit, CoachModeState>(
          builder: (context, state) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: kcSecondaryColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Header
                Text(
                  'Coaching tools',
                  style: heading2Style(context).copyWith(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quick droplets for self-reflection and coach sharing. Private by default.',
                  style: bodyStyle(context).copyWith(
                    color: kcSecondaryColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                // Feature explanations
                _buildFeatureRow(
                  context,
                  title: 'Pre-Session Check-in',
                  subtitle: '2-minute mood, energy, and focus assessment',
                  icon: Icons.psychology,
                ),
                
                _buildFeatureRow(
                  context,
                  title: 'Post-Session Debrief',
                  subtitle: 'Capture insights and commitments while fresh',
                  icon: Icons.assignment_turned_in,
                ),
                
                _buildFeatureRow(
                  context,
                  title: 'Weekly Goals & Friction',
                  subtitle: 'Map goals and identify potential blockers',
                  icon: Icons.flag,
                ),
                
                _buildFeatureRow(
                  context,
                  title: 'Stress Pulse',
                  subtitle: '1-minute mood and stress level check',
                  icon: Icons.favorite,
                ),
                
                _buildFeatureRow(
                  context,
                  title: 'Coach Share Bundle',
                  subtitle: 'Export selected responses to share with your coach',
                  icon: Icons.share,
                ),
                
                _buildFeatureRow(
                  context,
                  title: 'Import Coach Replies',
                  subtitle: 'Add coach recommendations as insight cards',
                  icon: Icons.download,
                ),

                const SizedBox(height: 24),
                
                // Action button with extra padding
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: kcPrimaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Done',
                        style: buttonStyle(context).copyWith(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kcSurfaceAltColor,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kcPrimaryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: kcPrimaryColor,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: heading3Style(context).copyWith(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryColor,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import '../fr_settings_cubit.dart';
import '../fr_settings.dart';

class WhatChangesSheet extends StatelessWidget {
  const WhatChangesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: BlocBuilder<FRSettingsCubit, FRSettings>(
          builder: (context, settings) {
            final cubit = context.read<FRSettingsCubit>();
            return Column(
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
                      color: kcSecondaryColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Header
                Text(
                  'First Responder tools',
                  style: heading2Style(context).copyWith(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can tailor these anytime. Short and calm by default.',
                  style: bodyStyle(context).copyWith(
                    color: kcSecondaryColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),

                // Settings toggles
                _buildSettingRow(
                  context,
                  title: 'Rapid Debrief',
                  subtitle: '2–3 minute guided post-call recap',
                  value: settings.rapidDebrief,
                  onChanged: cubit.toggleRapidDebrief,
                  icon: Icons.timer,
                ),
                
                _buildSettingRow(
                  context,
                  title: 'Redaction',
                  subtitle: 'One-tap anonymize on share/export',
                  value: settings.redactionEnabled,
                  onChanged: cubit.toggleRedaction,
                  icon: Icons.visibility_off,
                ),
                
                _buildSettingRow(
                  context,
                  title: 'Shift-aware cadence',
                  subtitle: 'Softer nights, gentle recovery check-ins',
                  value: settings.shiftAwareCadence,
                  onChanged: cubit.toggleShiftAware,
                  icon: Icons.schedule,
                ),
                
                _buildSettingRow(
                  context,
                  title: 'Check-in after heavy entry',
                  subtitle: 'Offer a quick debrief when entries are intense',
                  value: settings.postHeavyEntryCheckIn,
                  onChanged: cubit.togglePostHeavyCheckIn,
                  icon: Icons.favorite,
                ),
                
                _buildSettingRow(
                  context,
                  title: 'Soft visuals',
                  subtitle: 'Calmer Arcform animations during recovery',
                  value: settings.softVisuals,
                  onChanged: cubit.toggleSoftVisuals,
                  icon: Icons.palette,
                ),

                const SizedBox(height: 24),
                
                // Action button
                SizedBox(
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
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            color: value ? kcPrimaryColor.withOpacity(0.2) : kcSurfaceAltColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: value ? kcPrimaryColor : kcSecondaryColor,
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
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: kcPrimaryColor,
          activeTrackColor: kcPrimaryColor.withOpacity(0.3),
          inactiveTrackColor: kcSurfaceAltColor,
          inactiveThumbColor: kcSecondaryColor,
        ),
      ),
    );
  }
}
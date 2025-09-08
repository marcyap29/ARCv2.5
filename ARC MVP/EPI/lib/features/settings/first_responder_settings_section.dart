import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../mode/first_responder/fr_settings.dart';
import '../../mode/first_responder/fr_settings_cubit.dart';
import '../../mode/first_responder/widgets/what_changes_sheet.dart';
import '../../mode/first_responder/widgets/fr_profile_setup.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';

class FirstResponderSettingsSection extends StatelessWidget {
  const FirstResponderSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FRSettingsCubit, FRSettings>(
      builder: (context, settings) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'First Responder Mode',
              style: heading2Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            // Master toggle
            _buildToggleTile(
              context,
              title: 'Enable First Responder Mode',
              subtitle: settings.isEnabled 
                ? 'Active - Specialized tools for first responders'
                : 'Inactive - Standard mode',
              icon: Icons.local_hospital_outlined,
              value: settings.isEnabled,
              onChanged: (value) {
                if (value) {
                  context.read<FRSettingsCubit>().toggleMasterSwitch(true);
                  _showWhatChangesSheet(context);
                } else {
                  context.read<FRSettingsCubit>().toggleMasterSwitch(false);
                }
              },
            ),
            
            if (settings.isEnabled) ...[
              const SizedBox(height: 16),
              
              // Profile section
              _buildProfileSection(context, settings),
              
              const SizedBox(height: 16),
              
              // Individual feature toggles
              _buildToggleTile(
                context,
                title: 'Rapid Debrief',
                subtitle: 'Quick 2-3 minute structured debrief after calls',
                icon: Icons.timer_outlined,
                value: settings.rapidDebrief,
                onChanged: (value) => context.read<FRSettingsCubit>().updateSettings(
                  settings.copyWith(rapidDebrief: value),
                ),
              ),
              
              _buildToggleTile(
                context,
                title: 'Text Redaction',
                subtitle: 'Auto-redact sensitive info when sharing entries',
                icon: Icons.visibility_off_outlined,
                value: settings.redactionEnabled,
                onChanged: (value) => context.read<FRSettingsCubit>().updateSettings(
                  settings.copyWith(redactionEnabled: value),
                ),
              ),
              
              _buildToggleTile(
                context,
                title: 'Post-Call Check-in',
                subtitle: 'Smart suggestions for debrief after heavy entries',
                icon: Icons.psychology_outlined,
                value: settings.postHeavyEntryCheckIn,
                onChanged: (value) => context.read<FRSettingsCubit>().updateSettings(
                  settings.copyWith(postHeavyEntryCheckIn: value),
                ),
              ),
              
              _buildToggleTile(
                context,
                title: 'Shift-Aware Cadence',
                subtitle: 'Adjust prompts based on shift patterns',
                icon: Icons.schedule_outlined,
                value: settings.shiftAwareCadence,
                onChanged: (value) => context.read<FRSettingsCubit>().updateSettings(
                  settings.copyWith(shiftAwareCadence: value),
                ),
              ),
              
              _buildToggleTile(
                context,
                title: 'Soft Visuals',
                subtitle: 'Calmer, less stimulating interface colors',
                icon: Icons.palette_outlined,
                value: settings.softVisuals,
                onChanged: (value) => context.read<FRSettingsCubit>().updateSettings(
                  settings.copyWith(softVisuals: value),
                ),
              ),
            ],
            
            if (settings.isEnabled)
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

  void _showWhatChangesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<FRSettingsCubit>(),
        child: const WhatChangesSheet(),
      ),
    );
  }
  
  Widget _buildProfileSection(BuildContext context, FRSettings settings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                color: kcAccentColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Profile',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _navigateToProfileSetup(context),
                child: Text(
                  settings.hasCompleteProfile ? 'Edit' : 'Set up',
                  style: bodyStyle(context).copyWith(
                    color: kcAccentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
            if (settings.hasCompleteProfile) ...[
              _buildProfileInfo(context, 'Role', settings.displayRole),
              if (settings.department != null)
                _buildProfileInfo(context, 'Department', settings.department!),
              if (settings.shiftPattern != null)
                _buildProfileInfo(context, 'Shift', settings.displayShiftPattern),
              if (settings.yearsOfService != null && settings.yearsOfService! > 0)
                _buildProfileInfo(context, 'Experience', '${settings.yearsOfService} years'),
              if (settings.specialties.isNotEmpty)
                _buildProfileInfo(context, 'Specialties', settings.specialties.join(', ')),
            ] else ...[
              Text(
                'Complete your profile to unlock personalized features like shift-aware prompts and role-specific templates.',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 14,
                ),
              ),
            ],
        ],
      ),
    );
  }
  
  Widget _buildProfileInfo(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: bodyStyle(context).copyWith(
                color: kcPrimaryTextColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _navigateToProfileSetup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: context.read<FRSettingsCubit>(),
          child: const FRProfileSetup(),
        ),
      ),
    );
  }
}
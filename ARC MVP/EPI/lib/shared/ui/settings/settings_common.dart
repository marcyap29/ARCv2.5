// lib/shared/ui/settings/settings_common.dart
// Shared app bar, section title, and primary button styles for settings/management views.
// Use these to keep settings UI consistent across chronicle_management, privacy, phase, backup, etc.

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

/// Standard app bar for settings and management views.
/// Background: [kcBackgroundColor], title: [heading1Style], back button: [kcPrimaryTextColor].
PreferredSizeWidget settingsAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
  Widget? leading,
  bool centerTitle = true,
}) {
  return AppBar(
    backgroundColor: kcBackgroundColor,
    elevation: 0,
    leading: leading ?? const BackButton(color: kcPrimaryTextColor),
    title: Text(
      title,
      style: heading1Style(context).copyWith(
        color: kcPrimaryTextColor,
        fontWeight: FontWeight.bold,
      ),
    ),
    centerTitle: centerTitle,
    actions: actions,
  );
}

/// Section title only (e.g. "Aggregation Status", "Import & Export").
/// Use for grouping blocks of content; style: [heading2Style], bold.
class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: heading2Style(context).copyWith(
        color: kcPrimaryTextColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// Section wrapper: title + [SizedBox(height: 12)] + children.
/// Use when a section has a single title and a list of widgets below it.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionTitle(title: title),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

/// Card-style header: optional icon + title (e.g. "Phase Analysis", "Connection").
/// Style: [heading3Style], bold. Use for the top of a card or block.
class SettingsCardTitle extends StatelessWidget {
  const SettingsCardTitle({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? kcAccentColor;
    if (icon != null) {
      return Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: heading3Style(context).copyWith(
                color: kcPrimaryTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }
    return Text(
      title,
      style: heading3Style(context).copyWith(
        color: kcPrimaryTextColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// Primary action button style for settings (e.g. "Connect", "Save").
/// Use with [FilledButton], [ElevatedButton], or [FilledButton.icon].
ButtonStyle get settingsPrimaryButtonStyle => FilledButton.styleFrom(
      backgroundColor: kcAccentColor,
      foregroundColor: Colors.white,
    );

/// Outlined secondary action (e.g. "Disconnect", "Cancel").
ButtonStyle settingsOutlinedButtonStyle({Color? foregroundColor}) =>
    OutlinedButton.styleFrom(
      foregroundColor: foregroundColor ?? kcSecondaryTextColor,
    );

/// Full-width action row button: icon, title, subtitle, chevron.
/// Matches the pattern used in CHRONICLE Management and similar screens.
class SettingsActionButton extends StatelessWidget {
  const SettingsActionButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: kcBackgroundColor.withOpacity(0.5),
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: kcPrimaryTextColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: bodyStyle(context).copyWith(
                      color: kcPrimaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: captionStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kcPrimaryTextColor),
          ],
        ),
      ),
    );
  }
}

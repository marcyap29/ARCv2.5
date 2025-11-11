import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';

// Heading Styles
TextStyle heading1Style(BuildContext context) => const TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: kcPrimaryTextColor,
    );

TextStyle heading2Style(BuildContext context) => const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: kcPrimaryTextColor,
    );

TextStyle heading3Style(BuildContext context) => const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: kcPrimaryTextColor,
    );

TextStyle heading4Style(BuildContext context) => const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: kcPrimaryTextColor,
    );

// Body Styles
TextStyle bodyStyle(BuildContext context) => const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: kcPrimaryTextColor,
    );

TextStyle captionStyle(BuildContext context) => const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: kcPrimaryTextColor,
    );

// Button Style
TextStyle buttonStyle(BuildContext context) => const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: kcPrimaryTextColor,
    );

// Special Styles
TextStyle linkStyle(BuildContext context) => TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: kcPrimaryGradient.colors.first,
      decoration: TextDecoration.underline,
    );

TextStyle errorStyle(BuildContext context) => const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: kcDangerColor,
    );

TextStyle successStyle(BuildContext context) => const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: kcSuccessColor,
    );

// Enhanced Text Hierarchy Styles

// Primary Actions (most prominent - buttons, CTAs)
TextStyle primaryActionStyle(BuildContext context) => const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: kcPrimaryColor,
      letterSpacing: 0.5,
    );

// Secondary Actions (less prominent actions)
TextStyle secondaryActionStyle(BuildContext context) => TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: kcAccentColor,
    );

// Critical Information (important but not action)
TextStyle criticalInfoStyle(BuildContext context) => const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: kcPrimaryTextColor,
    );

// Section Headers (card titles, section titles)
TextStyle sectionHeaderStyle(BuildContext context) => const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: kcPrimaryTextColor,
    );

// Body Text (standard information)
TextStyle bodyTextStyle(BuildContext context) => TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: kcPrimaryTextColor.withOpacity(0.9),
    );

// Supporting Text (less important info, descriptions)
TextStyle supportingTextStyle(BuildContext context) => TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: kcPrimaryTextColor.withOpacity(0.6),
    );

// Labels/Captions (metadata, timestamps, tags)
TextStyle labelStyle(BuildContext context) => TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: kcPrimaryTextColor.withOpacity(0.7),
    );

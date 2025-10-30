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

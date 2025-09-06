import 'package:flutter/material.dart';
import '../../../shared/app_colors.dart';
import 'micro_tip.dart';
import '../strings/insight_tips_strings.dart';

/// Small info icon for micro-tips
class InfoIcon extends StatelessWidget {
  final String title;
  final List<String> bullets;
  final String? ctaText;
  final VoidCallback? onCta;

  const InfoIcon({
    Key? key,
    required this.title,
    required this.bullets,
    this.ctaText,
    this.onCta,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        MicroTip.show(
          context,
          title: title,
          bullets: bullets,
          ctaText: ctaText,
          onCta: onCta,
        );
      },
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: kcPrimaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: kcPrimaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.info_outline,
          size: 12,
          color: kcPrimaryColor,
        ),
      ),
    );
  }
}

/// Predefined info icons for common use cases
class InfoIcons {
  static Widget patterns() => const InfoIcon(
    title: InsightTipsStrings.patterns_title,
    bullets: InsightTipsStrings.patterns_points,
  );

  static Widget patternsScreen() => const InfoIcon(
    title: InsightTipsStrings.patterns_screen_title,
    bullets: InsightTipsStrings.patterns_screen_points,
  );

  static Widget safety() => const InfoIcon(
    title: InsightTipsStrings.safety_title,
    bullets: InsightTipsStrings.safety_points,
  );

  static Widget aurora() => const InfoIcon(
    title: InsightTipsStrings.aurora_title,
    bullets: InsightTipsStrings.aurora_points,
  );

  static Widget veil() => const InfoIcon(
    title: InsightTipsStrings.veil_title,
    bullets: InsightTipsStrings.veil_points,
  );
}

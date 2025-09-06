import 'package:flutter/material.dart';
import '../../../shared/app_colors.dart';
import 'about_insights_sheet.dart';

/// Info icon for Insights AppBar
class InsightsInfoIcon extends StatelessWidget {
  const InsightsInfoIcon({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(
        Icons.info_outline,
        color: kcPrimaryTextColor,
        size: 24,
      ),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const AboutInsightsSheet(),
        );
      },
      tooltip: 'About Insights',
    );
  }
}

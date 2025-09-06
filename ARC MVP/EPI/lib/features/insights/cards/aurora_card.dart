import 'package:flutter/material.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/text_style.dart';
import '../info/info_icon.dart';

/// AURORA card for rhythm and restoration insights
/// Currently shows as placeholder "not yet active"
class AuroraCard extends StatelessWidget {
  const AuroraCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.wb_sunny_outlined,
                  size: 20,
                  color: kcPrimaryTextColor,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'AURORA',
                        style: heading2Style(context),
                      ),
                      const SizedBox(width: 8),
                      InfoIcons.aurora(),
                    ],
                  ),
                  Text(
                    'Rhythm & Restoration',
                    style: bodyStyle(context).copyWith(
                      color: kcPrimaryTextColor.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 48,
                  color: kcPrimaryTextColor.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Not Yet Active',
                  style: heading3Style(context).copyWith(
                    color: kcPrimaryTextColor.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AURORA will help you discover your natural rhythms and restoration patterns.',
                  style: bodyStyle(context).copyWith(
                    color: kcPrimaryTextColor.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    'Coming Soon',
                    style: captionStyle(context).copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

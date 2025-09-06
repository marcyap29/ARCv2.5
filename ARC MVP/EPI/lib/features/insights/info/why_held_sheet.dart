import 'package:flutter/material.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/text_style.dart';
import '../strings/insight_tips_strings.dart';

/// "Why held?" bottom sheet for phase change explanation
class WhyHeldSheet extends StatelessWidget {
  const WhyHeldSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    color: kcPrimaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      InsightTipsStrings.whyHeld_title,
                      style: heading2Style(context).copyWith(
                        color: kcPrimaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Intro text
              Text(
                InsightTipsStrings.whyHeld_intro,
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Unlock steps
              ...InsightTipsStrings.whyHeld_unlockers.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6, right: 12),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: kcPrimaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: kcPrimaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: captionStyle(context).copyWith(
                              color: kcPrimaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          step,
                          style: bodyStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),

              // Footer note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kcSurfaceAltColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: kcSecondaryTextColor.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: kcSecondaryTextColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        InsightTipsStrings.whyHeld_footer,
                        style: captionStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kcPrimaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Got it',
                    style: bodyStyle(context).copyWith(
                      color: kcSurfaceColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

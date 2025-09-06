import 'package:flutter/material.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/text_style.dart';
import '../strings/insights_strings.dart';

/// About Insights bottom sheet with collapsible sections
class AboutInsightsSheet extends StatefulWidget {
  const AboutInsightsSheet({Key? key}) : super(key: key);

  @override
  State<AboutInsightsSheet> createState() => _AboutInsightsSheetState();
}

class _AboutInsightsSheetState extends State<AboutInsightsSheet> {

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                    Icons.insights_outlined,
                    color: kcPrimaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          InsightsStrings.title,
                          style: heading2Style(context).copyWith(
                            color: kcPrimaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          InsightsStrings.subtitle,
                          style: bodyStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Compact sections
              _buildCompactSection(
                InsightsStrings.patternsTitle,
                InsightsStrings.patternsBody,
                Icons.account_tree,
              ),
              const SizedBox(height: 16),

              _buildCompactSection(
                InsightsStrings.safetyTitle,
                InsightsStrings.safetyBody,
                Icons.security,
              ),
              const SizedBox(height: 16),

              _buildCompactSection(
                InsightsStrings.auroraTitle,
                InsightsStrings.auroraBody,
                Icons.wb_sunny,
              ),
              const SizedBox(height: 16),

              _buildCompactSection(
                InsightsStrings.veilTitle,
                InsightsStrings.veilBody,
                Icons.nightlight_round,
              ),
              const SizedBox(height: 24),

              // Privacy note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kcSurfaceAltColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: kcSecondaryTextColor.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.privacy_tip_outlined,
                      color: kcSecondaryTextColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        InsightsStrings.privacyNote,
                        style: captionStyle(context).copyWith(
                          color: kcSecondaryTextColor,
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
                    InsightsStrings.gotIt,
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

  Widget _buildCompactSection(String title, String body, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kcSurfaceAltColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kcSecondaryTextColor.withOpacity(0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: kcPrimaryColor,
            size: 20,
          ),
          const SizedBox(width: 12),
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
                  body,
                  style: bodyStyle(context).copyWith(
                    color: kcSecondaryTextColor,
                    height: 1.4,
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

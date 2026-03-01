import 'package:flutter/material.dart';
import 'package:my_app/chronicle/reviews/models/yearly_review.dart';
import 'package:my_app/chronicle/reviews/widgets/review_word_cloud.dart';
import 'package:my_app/shared/app_colors.dart';

/// "January You" vs "December You" word clouds with evolution narrative.
class IdentityEvolutionWidget extends StatelessWidget {
  final IdentityEvolution identityEvolution;
  final int year;

  const IdentityEvolutionWidget({
    super.key,
    required this.identityEvolution,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    final hasJan = identityEvolution.januaryWordCloud.isNotEmpty;
    final hasDec = identityEvolution.decemberWordCloud.isNotEmpty;

    if (!hasJan && !hasDec) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kcSurfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kcBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Identity Evolution',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: kcPrimaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Need January and December entries for comparison.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: kcSecondaryTextColor,
                  ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kcBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Identity Evolution',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '"January You" vs "December You"',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: kcSecondaryTextColor,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'January $year',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: kcPrimaryColor,
                          ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 160,
                      child: ReviewWordCloud(
                        wordCloudData: identityEvolution.januaryWordCloud,
                        title: 'January',
                        height: 140,
                        showTitle: false,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.arrow_forward, color: kcAccentColor, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'December $year',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: kcPrimaryColor,
                          ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 160,
                      child: ReviewWordCloud(
                        wordCloudData: identityEvolution.decemberWordCloud,
                        title: 'December',
                        height: 140,
                        showTitle: false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kcSurfaceAltColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kcBorderColor),
            ),
            child: Text(
              identityEvolution.evolutionNarrative,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: kcPrimaryTextColor,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

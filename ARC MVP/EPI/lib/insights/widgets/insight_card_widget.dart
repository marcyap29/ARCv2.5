import 'package:flutter/material.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import '../models/insight_card.dart';
import '../../ui/insights/widgets/insight_card_shell.dart';

/// Widget to display an insight card
class InsightCardWidget extends StatelessWidget {
  final InsightCard card;
  final VoidCallback? onTap;

  const InsightCardWidget({
    super.key,
    required this.card,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InsightCardShell(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and badges
              Row(
                children: [
                  Expanded(
                    child: Text(
                      card.title,
                      style: heading3Style(context).copyWith(
                        color: kcPrimaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (card.badges.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Wrap(
                        spacing: 4,
                        children: card.badges.map((badge) => Chip(
                          label: Text(
                            badge,
                            style: captionStyle(context).copyWith(
                              color: kcSecondaryTextColor,
                              fontSize: 10,
                            ),
                          ),
                          backgroundColor: kcSurfaceAltColor,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              
              // Body text
              Text(
                card.body,
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  height: 1.4,
                ),
              ),
              
              // Footer with period info
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: kcSecondaryTextColor.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatPeriod(card.periodStart, card.periodEnd),
                    style: captionStyle(context).copyWith(
                      color: kcSecondaryTextColor.withOpacity(0.7),
                    ),
                  ),
                  const Spacer(),
                  if (card.deeplink != null)
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: kcAccentColor,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPeriod(DateTime start, DateTime end) {
    final now = DateTime.now();
    final daysDiff = now.difference(start).inDays;
    
    if (daysDiff == 0) {
      return 'Today';
    } else if (daysDiff == 1) {
      return 'Yesterday';
    } else if (daysDiff < 7) {
      return '$daysDiff days ago';
    } else if (daysDiff < 30) {
      final weeks = (daysDiff / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else {
      final months = (daysDiff / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    }
  }
}

/// Widget to display a list of insight cards
class InsightCardsList extends StatelessWidget {
  final List<InsightCard> cards;
  final Function(InsightCard)? onCardTap;
  final bool isLoading;

  const InsightCardsList({
    super.key,
    required this.cards,
    this.onCardTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (cards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.insights_outlined,
                size: 64,
                color: kcSecondaryTextColor.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No insights yet',
                style: heading3Style(context).copyWith(
                  color: kcSecondaryTextColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Write a few journal entries to see personalized insights',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: cards.length,
      addRepaintBoundaries: true,
      addAutomaticKeepAlives: false,
      addSemanticIndexes: true,
      semanticChildCount: cards.length,
      shrinkWrap: true,  // ← Fix unbounded height
      physics: const NeverScrollableScrollPhysics(),  // ← Let parent handle scrolling
      itemBuilder: (context, index) {
        final card = cards[index];
        return InsightCardWidget(
          card: card,
          onTap: onCardTap != null ? () => onCardTap!(card) : null,
        );
      },
    );
  }
}

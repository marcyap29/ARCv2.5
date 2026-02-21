import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../data/models/pushback_evidence.dart';

/// Shows "What I'm seeing" — the CHRONICLE evidence LUMARA used to gently push back.
/// Expandable so users can review entry excerpts before or after reading the response.
class EvidenceReviewWidget extends StatefulWidget {
  final PushbackEvidence evidence;

  const EvidenceReviewWidget({
    super.key,
    required this.evidence,
  });

  @override
  State<EvidenceReviewWidget> createState() => _EvidenceReviewWidgetState();
}

class _EvidenceReviewWidgetState extends State<EvidenceReviewWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = widget.evidence.aggregationSummary;
    final excerpts = widget.evidence.entryExcerpts;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const Gap(6),
                Icon(
                  Icons.menu_book_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const Gap(8),
                Expanded(
                  child: Text(
                    "What I'm seeing",
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(6),
          Text(
            summary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (_expanded && excerpts.isNotEmpty) ...[
            const Gap(10),
            ...excerpts.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.format_quote,
                        size: 14,
                        color: theme.colorScheme.primary.withOpacity(0.6),
                      ),
                      const Gap(6),
                      Expanded(
                        child: Text(
                          e,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/text_style.dart';

/// Micro-tip widget for small help dialogs
class MicroTip {
  /// Show a micro-tip with title and bullet points
  static void show(
    BuildContext context, {
    required String title,
    required List<String> bullets,
    String? ctaText,
    VoidCallback? onCta,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _MicroTipDialog(
        title: title,
        bullets: bullets,
        ctaText: ctaText,
        onCta: onCta,
      ),
    );
  }
}

/// Micro-tip dialog widget
class _MicroTipDialog extends StatelessWidget {
  final String title;
  final List<String> bullets;
  final String? ctaText;
  final VoidCallback? onCta;

  const _MicroTipDialog({
    required this.title,
    required this.bullets,
    this.ctaText,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kcSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              style: heading3Style(context).copyWith(
                color: kcPrimaryTextColor,
              ),
            ),
            const SizedBox(height: 16),

            // Bullet points
            ...bullets.map((bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 12),
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: kcPrimaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      bullet,
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (ctaText != null && onCta != null) ...[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onCta?.call();
                    },
                    child: Text(
                      ctaText!,
                      style: bodyStyle(context).copyWith(
                        color: kcPrimaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Got it',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

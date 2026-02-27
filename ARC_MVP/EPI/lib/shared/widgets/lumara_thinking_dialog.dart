import 'package:flutter/material.dart';

/// Inline indicator used when LUMARA is thinking (Reflect sessions, chat, etc.).
/// Use this for inline placement; use [LumaraThinkingDialog] for an overlay dialog.
/// When [processingSteps] is provided, shows step-by-step status (completed + current).
class LumaraThinkingIndicator extends StatelessWidget {
  final String? customMessage;
  final bool showProgressBar;
  /// When set, displays step-by-step progress like the chat thinking bubble.
  final List<String>? processingSteps;

  const LumaraThinkingIndicator({
    super.key,
    this.customMessage,
    this.showProgressBar = true,
    this.processingSteps,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = processingSteps ?? [];
    final useStepDisplay = steps.isNotEmpty;

    if (useStepDisplay) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Completed steps (faded)
            for (int i = 0; i < (steps.length > 1 ? steps.length - 1 : 0); i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Current step (prominent, with spinner)
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    steps.isNotEmpty ? steps.last : (customMessage ?? 'LUMARA is thinking…'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: theme.colorScheme.secondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  customMessage ?? 'LUMARA is thinking...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          if (showProgressBar) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ],
        ],
      ),
    );
  }
}

/// A dialog that shows LUMARA is thinking, matching the style from the chat interface
class LumaraThinkingDialog extends StatelessWidget {
  final String? customMessage;

  const LumaraThinkingDialog({
    super.key,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: LumaraThinkingIndicator(
          customMessage: customMessage,
          showProgressBar: true,
        ),
      ),
    );
  }
}

/// Helper function to show the LUMARA thinking dialog
void showLumaraThinkingDialog(
  BuildContext context, {
  String? message,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => LumaraThinkingDialog(
      customMessage: message,
    ),
  );
}

/// Helper function to hide the LUMARA thinking dialog
void hideLumaraThinkingDialog(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}
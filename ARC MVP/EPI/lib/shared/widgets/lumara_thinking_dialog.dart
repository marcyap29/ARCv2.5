import 'package:flutter/material.dart';

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
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    customMessage ?? 'LUMARA is thinking...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress meter
            LinearProgressIndicator(
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ],
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
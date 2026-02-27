/// Pending Input Banner
/// 
/// Shows a banner when there's a pending input that didn't receive a response,
/// allowing the user to resubmit it.
library;

import 'package:flutter/material.dart';
import '../../../services/pending_conversation_service.dart';

class PendingInputBanner extends StatefulWidget {
  final VoidCallback? onResubmit;
  final String mode; // 'voice' or 'chat'

  const PendingInputBanner({
    super.key,
    this.onResubmit,
    required this.mode,
  });

  @override
  State<PendingInputBanner> createState() => _PendingInputBannerState();
}

class _PendingInputBannerState extends State<PendingInputBanner> {
  PendingInput? _pendingInput;
  bool _isChecking = true;
  bool _crashDetected = false;

  @override
  void initState() {
    super.initState();
    _checkForCrashAndPendingInput();
  }

  Future<void> _checkForCrashAndPendingInput() async {
    // Check if app crashed (had pending input but didn't shut down cleanly)
    final crashed = await PendingConversationService.checkForCrash();
    
    if (crashed) {
      // Only show banner if crash was detected
      final input = await PendingConversationService.getPendingInput();
      setState(() {
        _pendingInput = input;
        _crashDetected = true;
        _isChecking = false;
      });
    } else {
      setState(() {
        _pendingInput = null;
        _crashDetected = false;
        _isChecking = false;
      });
    }
  }

  Future<void> _handleResubmit() async {
    if (widget.onResubmit != null) {
      widget.onResubmit!();
    }
    // Clear crash detection flag after resubmit
    await PendingConversationService.clearCrashDetection();
    // Re-check after resubmit (should be cleared)
    await Future.delayed(const Duration(milliseconds: 500));
    await _checkForCrashAndPendingInput();
  }

  Future<void> _handleDismiss() async {
    // Clear crash detection flag when user dismisses
    await PendingConversationService.clearCrashDetection();
    setState(() {
      _pendingInput = null;
      _crashDetected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const SizedBox.shrink();
    }

    // Only show if crash was detected and pending input matches mode
    if (!_crashDetected || _pendingInput == null || _pendingInput!.mode != widget.mode) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final preview = _pendingInput!.userText.length > 60
        ? '${_pendingInput!.userText.substring(0, 60)}...'
        : _pendingInput!.userText;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your message didn\'t receive a response',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  preview,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer.withOpacity(0.8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _handleDismiss,
            icon: Icon(
              Icons.close,
              size: 18,
              color: theme.colorScheme.onErrorContainer.withOpacity(0.7),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Dismiss',
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: _handleResubmit,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Resubmit',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

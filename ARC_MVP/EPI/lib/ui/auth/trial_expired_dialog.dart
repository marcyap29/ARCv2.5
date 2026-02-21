// Trial Expired Dialog - Shown when anonymous trial limit is reached
import 'package:flutter/material.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

/// Dialog shown when an anonymous user's trial has expired
/// Prompts them to sign in with Google or Email to continue
class TrialExpiredDialog extends StatefulWidget {
  final int trialLimit;
  final VoidCallback? onSignedIn;
  final VoidCallback? onDismissed;

  const TrialExpiredDialog({
    super.key,
    this.trialLimit = 5,
    this.onSignedIn,
    this.onDismissed,
  });

  /// Show the trial expired dialog
  static Future<bool?> show(
    BuildContext context, {
    int trialLimit = 5,
    VoidCallback? onSignedIn,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TrialExpiredDialog(
        trialLimit: trialLimit,
        onSignedIn: onSignedIn,
      ),
    );
  }

  @override
  State<TrialExpiredDialog> createState() => _TrialExpiredDialogState();
}

class _TrialExpiredDialogState extends State<TrialExpiredDialog> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await FirebaseAuthService.instance.signInWithGoogle();

      if (userCredential != null && mounted) {
        widget.onSignedIn?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Sign-in failed. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToEmailSignIn() {
    Navigator.of(context).pop(false);
    Navigator.of(context).pushNamed('/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kcBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.stars, color: kcAccentColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Free Trial Complete',
              style: heading2Style(context),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You\'ve used your ${widget.trialLimit} free trial requests. Sign in to continue using the app with all features.',
            style: bodyStyle(context),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kcAccentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kcAccentColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: kcAccentColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your data will be preserved when you sign in.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kcAccentColor),
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kcDangerColor),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _navigateToEmailSignIn,
          child: Text(
            'Sign in with Email',
            style: TextStyle(color: kcSecondaryTextColor),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _signInWithGoogle,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.account_circle, size: 20),
          label: Text(_isLoading ? 'Signing in...' : 'Continue with Google'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kcAccentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

/// Helper mixin for handling trial expiry errors from Cloud Functions
mixin TrialExpiryHandler {
  /// Check if an error is a trial expiry error and show dialog if so
  /// Returns true if the error was handled
  Future<bool> handleTrialExpiry(
    BuildContext context,
    dynamic error, {
    VoidCallback? onSignedIn,
  }) async {
    // Check if this is a trial expiry error from Cloud Functions
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('anonymous_trial_expired') ||
        errorString.contains('free trial') ||
        errorString.contains('trial of 5 requests')) {
      // Extract trial limit if possible (default to 5)
      int trialLimit = 5;
      final match = RegExp(r'trial of (\d+) requests').firstMatch(errorString);
      if (match != null) {
        trialLimit = int.tryParse(match.group(1) ?? '5') ?? 5;
      }

      await TrialExpiredDialog.show(
        context,
        trialLimit: trialLimit,
        onSignedIn: onSignedIn,
      );
      return true;
    }
    
    return false;
  }
}


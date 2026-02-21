import 'package:flutter/material.dart';
import '../models/voice_note.dart';

/// Modal that appears after voice transcription completes.
/// Gives user the choice to:
/// 1. Save as Voice Note
/// 2. Talk with LUMARA (continue to full conversation)
/// 
/// NOTE: No auto-select timer - user must explicitly choose
class VoiceProcessingModal extends StatelessWidget {
  final String transcription;
  final Duration autoSelectDelay; // Kept for API compatibility but not used

  const VoiceProcessingModal({
    super.key,
    required this.transcription,
    this.autoSelectDelay = const Duration(seconds: 2), // Not used
  });

  /// Show the modal and return the user's choice.
  /// User can cancel by tapping outside or sliding the sheet down.
  static Future<VoiceProcessingChoice?> show(
    BuildContext context, {
    required String transcription,
    Duration autoSelectDelay = const Duration(seconds: 2), // Not used
  }) {
    return showModalBottomSheet<VoiceProcessingChoice>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VoiceProcessingModal(
        transcription: transcription,
      ),
    );
  }

  void _selectOption(BuildContext context, VoiceProcessingChoice choice) {
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 20),
            
            // Title
            Text(
              'What would you like to do?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Transcription preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                ),
              ),
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Text(
                  transcription,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Option 1 - Save as Voice Note
            _buildOption(
              context: context,
              icon: Icons.mic,
              label: 'Save as Voice Note',
              subtitle: 'Save to Voice Notes',
              primaryColor: primaryColor,
              isDark: isDark,
              isPrimary: true,
              onTap: () => _selectOption(context, VoiceProcessingChoice.saveAsVoiceNote),
            ),

            const SizedBox(height: 12),

            // Option 2 - Talk with LUMARA
            _buildOption(
              context: context,
              icon: Icons.record_voice_over,
              label: 'Talk with LUMARA',
              subtitle: 'Start voice conversation',
              primaryColor: primaryColor,
              isDark: isDark,
              isPrimary: false,
              onTap: () => _selectOption(context, VoiceProcessingChoice.talkWithLumara),
            ),

            const SizedBox(height: 12),

            // Option 3 - Add to Timeline
            _buildOption(
              context: context,
              icon: Icons.timeline,
              label: 'Add to Timeline',
              subtitle: 'Add to Conversations timeline',
              primaryColor: primaryColor,
              isDark: isDark,
              isPrimary: false,
              onTap: () => _selectOption(context, VoiceProcessingChoice.addToTimeline),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color primaryColor,
    required bool isDark,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isPrimary ? primaryColor : Colors.grey.withOpacity(isDark ? 0.3 : 0.2),
            width: isPrimary ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isPrimary ? primaryColor.withOpacity(0.1) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isPrimary ? primaryColor : (isDark ? Colors.grey[400] : Colors.grey[700]),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
                      color: isPrimary ? primaryColor : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isPrimary ? primaryColor.withOpacity(0.7) : Colors.grey.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}

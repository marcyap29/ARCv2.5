// lib/arc/phase/share/phase_share_prompt_widget.dart
// Non-intrusive prompt widget for phase transition sharing

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import '../../../models/phase_models.dart';
import 'phase_share_composition_screen.dart';
import 'phase_share_service.dart';

/// Non-intrusive prompt card for sharing phase transitions
class PhaseSharePromptWidget extends StatelessWidget {
  final PhaseLabel phaseName;
  final DateTime transitionDate;
  final VoidCallback? onDismiss;

  const PhaseSharePromptWidget({
    super.key,
    required this.phaseName,
    required this.transitionDate,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getPhaseColor(phaseName).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.celebration,
                color: _getPhaseColor(phaseName),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Share this milestone',
                  style: heading3Style(context).copyWith(
                    color: kcPrimaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: kcSecondaryTextColor,
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Celebrate entering ${_getPhaseDisplayName(phaseName)} phase with a beautiful shareable image',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openShareComposition(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _getPhaseColor(phaseName),
                    side: BorderSide(color: _getPhaseColor(phaseName)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Share'),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: onDismiss,
                child: Text(
                  'Maybe later',
                  style: bodyStyle(context).copyWith(
                    color: kcSecondaryTextColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openShareComposition(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhaseShareCompositionScreen(
          phaseName: phaseName,
          transitionDate: transitionDate,
        ),
      ),
    );
  }

  Color _getPhaseColor(PhaseLabel label) {
    switch (label) {
      case PhaseLabel.discovery:
        return const Color(0xFF7C3AED);
      case PhaseLabel.expansion:
        return const Color(0xFF059669);
      case PhaseLabel.transition:
        return const Color(0xFFD97706);
      case PhaseLabel.consolidation:
        return const Color(0xFF2563EB);
      case PhaseLabel.recovery:
        return const Color(0xFFDC2626);
      case PhaseLabel.breakthrough:
        return const Color(0xFFFBBF24);
    }
  }

  String _getPhaseDisplayName(PhaseLabel label) {
    switch (label) {
      case PhaseLabel.discovery:
        return 'Discovery';
      case PhaseLabel.expansion:
        return 'Expansion';
      case PhaseLabel.transition:
        return 'Transition';
      case PhaseLabel.consolidation:
        return 'Consolidation';
      case PhaseLabel.recovery:
        return 'Recovery';
      case PhaseLabel.breakthrough:
        return 'Breakthrough';
    }
  }
}

/// Show phase share prompt if enabled and user hasn't dismissed it
class PhaseSharePromptController {
  static Future<void> showPromptIfEnabled({
    required BuildContext context,
    required PhaseLabel phaseName,
    required DateTime transitionDate,
    bool forceShow = false,
  }) async {
    final shareService = PhaseShareService.instance;
    
    // Check if prompts are enabled
    if (!forceShow && !await shareService.areSharePromptsEnabled()) {
      return;
    }

    // Show privacy consent dialog if first time
    if (!await shareService.hasGivenConsent()) {
      final consented = await _showPrivacyConsentDialog(context);
      if (!consented) {
        return;
      }
      await shareService.recordConsent();
    }

    // Show the prompt
    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: kcBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: PhaseSharePromptWidget(
              phaseName: phaseName,
              transitionDate: transitionDate,
              onDismiss: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      );
    }
  }

  static Future<bool> _showPrivacyConsentDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcSurfaceColor,
        title: Text(
          'Share Your Journey',
          style: heading2Style(context),
        ),
        content: Text(
          'You control what\'s shared. ARC will never post automatically or include your journal content. Only phase names, dates, and your own caption will be visible.',
          style: bodyStyle(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kcAccentColor,
            ),
            child: const Text('I understand'),
          ),
        ],
      ),
    ) ?? false;
  }
}


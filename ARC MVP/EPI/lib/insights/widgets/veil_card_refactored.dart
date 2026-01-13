import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'generic_system_card.dart';

/// VEIL card - AI Prompt Intelligence (Refactored)
/// Uses GenericSystemCard for consistent UI and reduced code duplication
class VeilCardRefactored extends StatefulWidget {
  const VeilCardRefactored({super.key});

  @override
  State<VeilCardRefactored> createState() => _VeilCardRefactoredState();
}

class _VeilCardRefactoredState extends State<VeilCardRefactored> with WidgetsBindingObserver {
  String? _currentPhase;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPhaseInfo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPhaseInfo();
    }
  }

  @override
  void didUpdateWidget(VeilCardRefactored oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadPhaseInfo();
  }

  Future<void> _loadPhaseInfo() async {
    try {
      String? phase;

      // Try phase regimes first
      try {
        final analyticsService = AnalyticsService();
        final rivetSweepService = RivetSweepService(analyticsService);
        final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
        await phaseRegimeService.initialize();

        final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
        if (currentRegime != null) {
          phase = currentRegime.label.toString().split('.').last.toLowerCase();
          phase = phase[0].toUpperCase() + phase.substring(1);
        }
      } catch (e) {
        // Fallback to UserPhaseService
        phase = await UserPhaseService.getCurrentPhase();
      }

      setState(() {
        _currentPhase = phase;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _getPhaseFamily(String? phase) {
    if (phase == null) return 'Exploration';
    switch (phase.toLowerCase()) {
      case 'discovery':
      case 'breakthrough': return 'Exploration';
      case 'transition': return 'Bridge';
      case 'recovery': return 'Restore';
      case 'consolidation': return 'Stabilize';
      case 'expansion': return 'Growth';
      default: return 'Exploration';
    }
  }

  String _getPhasePair(String? phase) {
    if (phase == null) return 'Discovery ↔ Breakthrough';
    switch (phase.toLowerCase()) {
      case 'discovery':
      case 'breakthrough': return 'Discovery ↔ Breakthrough';
      case 'transition': return 'Transition ↔ Discovery';
      case 'recovery': return 'Recovery ↔ Transition';
      case 'consolidation': return 'Consolidation ↔ Recovery';
      case 'expansion': return 'Expansion ↔ Consolidation';
      default: return 'Discovery ↔ Breakthrough';
    }
  }

  String _getResponseStyle(String? phase) {
    if (phase == null) return 'Upbeat & time-boxed';
    switch (phase.toLowerCase()) {
      case 'discovery':
      case 'breakthrough': return 'Upbeat & concrete';
      case 'transition': return 'Gentle & exploratory';
      case 'recovery': return 'Compassionate & grounding';
      case 'consolidation': return 'Structured & reassuring';
      case 'expansion': return 'Energetic & supportive';
      default: return 'Supportive & balanced';
    }
  }

  String _getResponseFocus(String? phase) {
    if (phase == null) return 'Expand options, then converge';
    switch (phase.toLowerCase()) {
      case 'discovery':
      case 'breakthrough': return 'Expand options, then converge';
      case 'transition': return 'Normalize uncertainty, preserve options';
      case 'recovery': return 'Body-first restoration & pacing';
      case 'consolidation': return 'Strengthen foundations & refine';
      case 'expansion': return 'Build momentum & capacity';
      default: return 'Support your growth journey';
    }
  }

  @override
  Widget build(BuildContext context) {
    final phaseFamily = _getPhaseFamily(_currentPhase);
    final phasePair = _getPhasePair(_currentPhase);
    final responseStyle = _getResponseStyle(_currentPhase);
    final responseFocus = _getResponseFocus(_currentPhase);

    final config = SystemCardConfig(
      title: 'VEIL',
      subtitle: 'AI Prompt Intelligence',
      icon: Icons.psychology_outlined,
      accentColor: Colors.purple,
      sections: [
        // Strategy Section
        SystemCardSection(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current Strategy: $phaseFamily Mode',
                      style: bodyStyle(context).copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Phase Pair: $phasePair',
                style: bodyStyle(context).copyWith(
                  fontSize: 13,
                  color: kcPrimaryTextColor.withOpacity(0.8),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue.withOpacity(0.1),
          borderColor: Colors.blue.withOpacity(0.3),
        ),
        // Response Style
        SystemCardSection(
          content: InfoRow(
            icon: Icons.chat_bubble_outline,
            label: 'Response Style',
            value: responseStyle,
          ),
        ),
        // Focus
        SystemCardSection(
          content: InfoRow(
            icon: Icons.track_changes,
            label: 'Focus',
            value: responseFocus,
          ),
        ),
      ],
      footer: Row(
        children: [
          const Icon(Icons.offline_bolt_outlined, size: 16, color: kcAccentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI runs privately on your device',
              style: bodyStyle(context).copyWith(
                fontSize: 12,
                color: kcPrimaryTextColor.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );

    return GenericSystemCard(
      config: config,
      isLoading: _isLoading,
      expandableSections: ['Available Strategies', 'Available Blocks', 'Available Variants'],
      expandableContent: {
        'Available Strategies': [
          'Exploration (Discovery ↔ Breakthrough)',
          'Bridge (Transition ↔ Discovery)',
          'Restore (Recovery ↔ Transition)',
          'Stabilize (Consolidation ↔ Recovery)',
          'Growth (Expansion ↔ Consolidation)',
        ],
        'Available Blocks': [
          'Mirror - Reflect understanding',
          'Orient - Provide direction',
          'Nudge - Gentle encouragement',
          'Commit - Action commitment',
          'Safeguard - Safety first',
          'Log - Record outcomes',
        ],
        'Available Variants': [
          'Standard - Normal operation',
          ':safe - Reduced activation, increased containment',
          ':alert - Maximum safety, grounding focus',
        ],
      },
    );
  }
}

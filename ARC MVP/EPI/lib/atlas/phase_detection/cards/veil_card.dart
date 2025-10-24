import 'package:flutter/material.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/text_style.dart';
import '../info/info_icon.dart';
import '../../../services/user_phase_service.dart';

/// VEIL card - AI Prompt Intelligence
/// Shows which AI response strategy is being used based on the user's current phase
class VeilCard extends StatefulWidget {
  const VeilCard({super.key});

  @override
  State<VeilCard> createState() => _VeilCardState();
}

class _VeilCardState extends State<VeilCard> {
  String? _currentPhase;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhaseInfo();
  }

  Future<void> _loadPhaseInfo() async {
    try {
      final phase = await UserPhaseService.getCurrentPhase();
      setState(() {
        _currentPhase = phase;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getPhaseFamily(String? phase) {
    if (phase == null) return 'Exploration';

    switch (phase.toLowerCase()) {
      case 'discovery':
      case 'breakthrough':
        return 'Exploration';
      case 'transition':
        return 'Bridge';
      case 'recovery':
        return 'Restore';
      case 'consolidation':
        return 'Stabilize';
      case 'expansion':
        return 'Growth';
      default:
        return 'Exploration';
    }
  }

  String _getPhasePair(String? phase) {
    if (phase == null) return 'Discovery ↔ Breakthrough';

    switch (phase.toLowerCase()) {
      case 'discovery':
      case 'breakthrough':
        return 'Discovery ↔ Breakthrough';
      case 'transition':
        return 'Transition ↔ Discovery';
      case 'recovery':
        return 'Recovery ↔ Transition';
      case 'consolidation':
        return 'Consolidation ↔ Recovery';
      case 'expansion':
        return 'Expansion ↔ Consolidation';
      default:
        return 'Discovery ↔ Breakthrough';
    }
  }

  String _getResponseStyle(String? phase) {
    if (phase == null) return 'Upbeat & time-boxed';

    switch (phase.toLowerCase()) {
      case 'discovery':
      case 'breakthrough':
        return 'Upbeat & concrete';
      case 'transition':
        return 'Gentle & exploratory';
      case 'recovery':
        return 'Compassionate & grounding';
      case 'consolidation':
        return 'Structured & reassuring';
      case 'expansion':
        return 'Energetic & supportive';
      default:
        return 'Supportive & balanced';
    }
  }

  String _getResponseFocus(String? phase) {
    if (phase == null) return 'Expand options, then converge';

    switch (phase.toLowerCase()) {
      case 'discovery':
      case 'breakthrough':
        return 'Expand options, then converge';
      case 'transition':
        return 'Normalize uncertainty, preserve options';
      case 'recovery':
        return 'Body-first restoration & pacing';
      case 'consolidation':
        return 'Strengthen foundations & refine';
      case 'expansion':
        return 'Build momentum & capacity';
      default:
        return 'Support your growth journey';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kcPrimaryTextColor),
          ),
        ),
      );
    }

    final phaseFamily = _getPhaseFamily(_currentPhase);
    final phasePair = _getPhasePair(_currentPhase);
    final responseStyle = _getResponseStyle(_currentPhase);
    final responseFocus = _getResponseFocus(_currentPhase);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  size: 20,
                  color: kcPrimaryTextColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'VEIL',
                          style: heading2Style(context),
                        ),
                        const SizedBox(width: 8),
                        InfoIcons.veil(),
                      ],
                    ),
                    Text(
                      'AI Prompt Intelligence',
                      style: bodyStyle(context).copyWith(
                        color: kcPrimaryTextColor.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Strategy Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Colors.blue,
                    ),
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
          ),

          const SizedBox(height: 16),

          // Response Style Section
          _buildInfoRow(
            icon: Icons.chat_bubble_outline,
            label: 'Response Style',
            value: responseStyle,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.track_changes,
            label: 'Focus',
            value: responseFocus,
          ),

          const SizedBox(height: 16),

          // Divider
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.2),
          ),

          const SizedBox(height: 16),

          // Model Info
          Row(
            children: [
              const Icon(
                Icons.offline_bolt_outlined,
                size: 16,
                color: kcAccentColor,
              ),
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
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: kcPrimaryTextColor.withOpacity(0.7),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: bodyStyle(context).copyWith(
                  fontSize: 11,
                  color: kcPrimaryTextColor.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: bodyStyle(context).copyWith(
                  fontSize: 13,
                  color: kcPrimaryTextColor.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

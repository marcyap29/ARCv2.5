import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/services/user_phase_service.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/analytics_service.dart';

/// VEIL card - AI Prompt Intelligence
/// Shows which AI response strategy is being used based on the user's current phase
class VeilCard extends StatefulWidget {
  const VeilCard({super.key});

  @override
  State<VeilCard> createState() => _VeilCardState();
}

class _VeilCardState extends State<VeilCard> with WidgetsBindingObserver {
  String? _currentPhase;
  bool _isLoading = true;
  bool _showMoreInfo = false;

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
      // Refresh phase when app comes to foreground
      _loadPhaseInfo();
    }
  }

  @override
  void didUpdateWidget(VeilCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh phase when widget is updated (e.g., when navigating back to Insights tab)
    _loadPhaseInfo();
  }

  Future<void> _loadPhaseInfo() async {
    try {
      String? phase;
      
      // First, try to get phase from phase regimes (newer system)
      try {
        final analyticsService = AnalyticsService();
        final rivetSweepService = RivetSweepService(analyticsService);
        final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
        await phaseRegimeService.initialize();
        
        final currentRegime = phaseRegimeService.phaseIndex.currentRegime;
        if (currentRegime != null) {
          // Convert PhaseLabel enum to string (e.g., PhaseLabel.transition -> "transition")
          phase = currentRegime.label.toString().split('.').last.toLowerCase();
          // Capitalize first letter
          phase = phase[0].toUpperCase() + phase.substring(1);
          print('DEBUG: VEIL Card - Using phase from regime: $phase');
        }
      } catch (e) {
        print('DEBUG: VEIL Card - Error getting phase from regime: $e');
      }
      
      // Fallback to UserPhaseService if no regime found
      if (phase == null) {
        phase = await UserPhaseService.getCurrentPhase();
        print('DEBUG: VEIL Card - Using phase from UserPhaseService: $phase');
      }
      
      setState(() {
        _currentPhase = phase;
        _isLoading = false;
      });
    } catch (e) {
      print('DEBUG: VEIL Card - Error loading phase: $e');
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

  List<String> _getAvailableStrategies() {
    return [
      'Exploration (Discovery ↔ Breakthrough)',
      'Bridge (Transition ↔ Discovery)',
      'Restore (Recovery ↔ Transition)',
      'Stabilize (Consolidation ↔ Recovery)',
      'Growth (Expansion ↔ Consolidation)',
    ];
  }

  List<String> _getAvailableBlocks() {
    return [
      'Mirror - Reflect understanding',
      'Orient - Provide direction',
      'Nudge - Gentle encouragement',
      'Commit - Action commitment',
      'Safeguard - Safety first',
      'Log - Record outcomes',
    ];
  }

  List<String> _getAvailableVariants() {
    return [
      'Standard - Normal operation',
      ':safe - Reduced activation, increased containment',
      ':alert - Maximum safety, grounding focus',
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kcSurfaceAltColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: kcBorderColor,
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
        color: kcSurfaceAltColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: kcBorderColor,
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
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  size: 20,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VEIL',
                      style: heading2Style(context),
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

          // More Info Toggle
          GestureDetector(
            onTap: () {
              setState(() {
                _showMoreInfo = !_showMoreInfo;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kcSurfaceColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _showMoreInfo ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: kcPrimaryTextColor.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _showMoreInfo ? 'Hide Details' : 'Show Available Options',
                    style: bodyStyle(context).copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: kcPrimaryTextColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_showMoreInfo) ...[
            const SizedBox(height: 12),
            _buildAvailableStrategiesSection(),
            const SizedBox(height: 12),
            _buildAvailableBlocksSection(),
            const SizedBox(height: 12),
            _buildAvailableVariantsSection(),
          ],

          const SizedBox(height: 16),

          // Divider
          Container(
            height: 1,
            color: kcBorderColor.withOpacity(0.5),
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

  Widget _buildAvailableStrategiesSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Strategies',
            style: bodyStyle(context).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: kcPrimaryTextColor.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          ..._getAvailableStrategies().map((strategy) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      strategy.startsWith(_getPhaseFamily(_currentPhase))
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 12,
                      color: strategy.startsWith(_getPhaseFamily(_currentPhase))
                          ? Colors.green
                          : kcPrimaryTextColor.withOpacity(0.5),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strategy,
                        style: bodyStyle(context).copyWith(
                          fontSize: 11,
                          color: strategy.startsWith(_getPhaseFamily(_currentPhase))
                              ? Colors.green
                              : kcPrimaryTextColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAvailableBlocksSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Response Blocks',
            style: bodyStyle(context).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: kcPrimaryTextColor.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _getAvailableBlocks().map((block) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    block,
                    style: bodyStyle(context).copyWith(
                      fontSize: 10,
                      color: Colors.blue.withOpacity(0.9),
                    ),
                  ),
                )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableVariantsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Variants',
            style: bodyStyle(context).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: kcPrimaryTextColor.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          ..._getAvailableVariants().map((variant) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 12,
                      color: kcPrimaryTextColor.withOpacity(0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        variant,
                        style: bodyStyle(context).copyWith(
                          fontSize: 11,
                          color: kcPrimaryTextColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

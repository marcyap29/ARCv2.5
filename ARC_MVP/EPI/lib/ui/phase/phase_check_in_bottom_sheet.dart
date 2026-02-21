// Phase Check-in bottom sheet: monthly confirmation or recalibration flow.

import 'package:flutter/material.dart';
import 'package:my_app/core/constants/phase_colors.dart';
import 'package:my_app/services/phase_check_in_service.dart';
import 'package:my_app/services/phase_check_in_copy.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/models/phase_models.dart';

/// Shows the Phase Check-in flow as a modal bottom sheet.
/// Call from HomeView (when due) or Settings > Phase Analysis.
/// Pops with `true` when user completes the flow, `false`/null when dismissed (remind in 7 days).
Future<void> showPhaseCheckInBottomSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: true,
    backgroundColor: kcSurfaceColor,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => _PhaseCheckInContent(
        scrollController: scrollController,
        onDismiss: () => Navigator.of(context).pop(false),
      ),
    ),
  );
  if (result != true) {
    await PhaseCheckInService.instance.recordDismissed();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('We\'ll remind you in a week'),
        backgroundColor: kcSecondaryTextColor,
      ),
    );
  }
}

class _PhaseCheckInContent extends StatefulWidget {
  final ScrollController scrollController;
  /// Called when user taps close (pop false so caller records dismiss + snackbar).
  final VoidCallback onDismiss;

  const _PhaseCheckInContent({
    required this.scrollController,
    required this.onDismiss,
  });

  @override
  State<_PhaseCheckInContent> createState() => _PhaseCheckInContentState();
}

class _PhaseCheckInContentState extends State<_PhaseCheckInContent> {
  int _step = 1;
  String _currentPhase = 'Discovery';
  String? _suggestedPhase;
  Map<String, String> _diagnosticAnswers = {};
  String? _manualPhase;
  String _manualReason = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentPhase();
  }

  Future<void> _loadCurrentPhase() async {
    final name = await PhaseCheckInService.instance.getCurrentPhaseName();
    if (mounted) setState(() => _currentPhase = name);
  }

  void _nextStep() {
    setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) widget.onDismiss();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: kcSecondaryTextColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Text(
                  'Step $_step of ${_totalSteps()}',
                  style: TextStyle(
                    color: kcSecondaryTextColor,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: kcPrimaryTextColor,
                  onPressed: () => widget.onDismiss(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _buildStepContent(),
            ),
          ),
        ],
      ),
    );
  }

  int _totalSteps() {
    if (_step <= 2) return 3;
    if (_step == 3 && _manualPhase == null) return 3;
    return 4;
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 1:
        return _buildConfirmationStep();
      case 2:
        return _buildDiagnosticStep();
      case 3:
        if (_manualPhase != null) return _buildManualPickerStep();
        return _buildResultStep();
      case 4:
        return _buildDoneStep();
      default:
        return _buildConfirmationStep();
    }
  }

  Widget _buildConfirmationStep() {
    final blurb = PhaseCheckInCopy.confirmationBlurb(_currentPhase);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Current Phase: $_currentPhase',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kcPrimaryTextColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PhaseColors.getPhaseColor(_currentPhase).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: PhaseColors.getPhaseColor(_currentPhase).withOpacity(0.5),
            ),
          ),
          child: Text(
            blurb,
            style: const TextStyle(
              fontSize: 16,
              color: kcPrimaryTextColor,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Does this still feel accurate?',
          style: TextStyle(
            fontSize: 16,
            color: kcPrimaryTextColor,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loading
                    ? null
                    : () async {
                        setState(() => _loading = true);
                        await PhaseCheckInService.instance.confirmPhase(_currentPhase);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Phase confirmed. LUMARA will continue tracking your trajectory.',
                            ),
                            backgroundColor: kcSuccessColor,
                          ),
                        );
                        if (context.mounted) Navigator.of(context).pop(true);
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: kcPrimaryTextColor,
                  side: const BorderSide(color: kcBorderColor),
                ),
                child: const Text('Yes, this fits'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _loading ? null : () => _nextStep(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kcAccentColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('No, something\'s shifted'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDiagnosticStep() {
    final q1Keys = PhaseCheckInCopy.q1Options.keys.toList();
    final q2Keys = PhaseCheckInCopy.q2Options.keys.toList();
    final q3Keys = PhaseCheckInCopy.q3Options.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quick diagnostic (3 questions)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kcWarningColor,
          ),
        ),
        const SizedBox(height: 20),
        _buildQuestion(
          'In the past month, your primary focus has been...',
          'q1',
          q1Keys,
          PhaseCheckInCopy.q1Options,
        ),
        const SizedBox(height: 20),
        _buildQuestion(
          'The work you\'re doing right now feels...',
          'q2',
          q2Keys,
          PhaseCheckInCopy.q2Options,
        ),
        const SizedBox(height: 20),
        _buildQuestion(
          'Your energy and ambition are...',
          'q3',
          q3Keys,
          PhaseCheckInCopy.q3Options,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () async {
            if (_diagnosticAnswers.length != 3) return;
            setState(() => _loading = true);
            final suggested = await PhaseCheckInService.instance
                .processDiagnostic(_diagnosticAnswers);
            if (!mounted) return;
            setState(() {
              _suggestedPhase = suggested;
              _loading = false;
              _nextStep();
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kcAccentColor,
            foregroundColor: Colors.white,
          ),
          child: Text(
            _diagnosticAnswers.length == 3 ? 'See result' : 'Answer all 3 to continue',
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion(
    String question,
    String key,
    List<String> optionKeys,
    Map<String, String> options,
  ) {
    final selected = _diagnosticAnswers[key];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: kcPrimaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: optionKeys.map((k) {
            final label = options[k]!;
            final isSelected = selected == k;
            return ChoiceChip(
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.white : kcPrimaryTextColor,
                ),
              ),
              selected: isSelected,
              onSelected: (v) {
                setState(() {
                  _diagnosticAnswers = Map.from(_diagnosticAnswers);
                  _diagnosticAnswers[key] = k;
                });
              },
              selectedColor: PhaseColors.getPhaseColor(_currentPhase),
              backgroundColor: kcSurfaceAltColor,
              side: BorderSide(
                color: isSelected
                    ? PhaseColors.getPhaseColor(_currentPhase)
                    : kcBorderColor,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResultStep() {
    final suggested = _suggestedPhase ?? _currentPhase;
    final changed = suggested != _currentPhase;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Based on your responses, you\'re likely in: $suggested',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kcPrimaryTextColor,
          ),
        ),
        if (changed) ...[
          const SizedBox(height: 12),
          Text(
            'Previous phase: $_currentPhase',
            style: TextStyle(color: kcSecondaryTextColor, fontSize: 14),
          ),
          Text(
            'New phase: $suggested',
            style: TextStyle(
              color: PhaseColors.getPhaseColor(suggested),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Text('Sound right?', style: TextStyle(fontSize: 16, color: kcPrimaryTextColor)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : () async {
                        setState(() => _loading = true);
                        await PhaseCheckInService.instance.updatePhaseFromCheckIn(
                          newPhaseName: suggested,
                          previousPhaseName: _currentPhase,
                          wasManualOverride: false,
                          diagnosticAnswers: _diagnosticAnswers,
                        );
                        if (!mounted) return;
                        setState(() {
                          _currentPhase = suggested;
                          _loading = false;
                          _step = 4;
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kcSuccessColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Yes, update my phase'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : () => setState(() => _manualPhase = ''),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kcPrimaryTextColor,
                  side: const BorderSide(color: kcBorderColor),
                ),
                child: const Text('Actually, let me choose'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildManualPickerStep() {
    final phases = PhaseLabel.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choose your phase',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kcPrimaryTextColor,
          ),
        ),
        const SizedBox(height: 12),
        ...phases.map((p) {
          final name = _phaseLabelToName(p);
          final isSelected = _manualPhase == name;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected
                      ? PhaseColors.getPhaseColor(name)
                      : kcBorderColor,
                ),
              ),
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: PhaseColors.getPhaseColor(name),
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(name, style: const TextStyle(color: kcPrimaryTextColor)),
              subtitle: Text(
                PhaseCheckInCopy.confirmationBlurb(name),
                style: const TextStyle(
                  color: kcSecondaryTextColor,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => setState(() => _manualPhase = name),
            ),
          );
        }),
        const SizedBox(height: 16),
        const Text(
          'What made you choose this phase? (optional)',
          style: TextStyle(fontSize: 14, color: kcSecondaryTextColor),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => _manualReason = v,
          decoration: InputDecoration(
            hintText: 'Brief reason...',
            hintStyle: TextStyle(color: kcSecondaryTextColor.withOpacity(0.7)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: kcSurfaceAltColor,
          ),
          style: const TextStyle(color: kcPrimaryTextColor),
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _manualPhase == null || _manualPhase!.isEmpty
              ? null
              : () async {
                  final phase = _manualPhase!;
                  setState(() => _loading = true);
                  await PhaseCheckInService.instance.updatePhaseFromCheckIn(
                    newPhaseName: phase,
                    previousPhaseName: _currentPhase,
                    wasManualOverride: true,
                    reason: _manualReason.isEmpty ? null : _manualReason,
                  );
                  if (!mounted) return;
                  setState(() {
                    _currentPhase = phase;
                    _loading = false;
                    _step = 4;
                  });
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: kcAccentColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Update my phase'),
        ),
      ],
    );
  }

  Widget _buildDoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle, size: 64, color: kcSuccessColor),
        const SizedBox(height: 16),
        Text(
          'Phase updated to $_currentPhase',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: kcPrimaryTextColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'LUMARA will adjust its understanding of your trajectory. '
          'You can always update this in Settings > Phase Analysis > Phase Check-in.',
          style: TextStyle(fontSize: 14, color: kcSecondaryTextColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kcSuccessColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  static String _phaseLabelToName(PhaseLabel p) {
    switch (p) {
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

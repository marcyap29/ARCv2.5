// lib/shared/ui/settings/phase_analysis_settings_view.dart
// Phase Analysis and Phase Statistics cards for main Settings menu (purple accent, compact stats).

import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/services/phase_index.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';

/// Settings screen: Phase Analysis card + Phase Statistics card. Uses purple accent to match main menu.
class PhaseAnalysisSettingsView extends StatefulWidget {
  const PhaseAnalysisSettingsView({super.key});

  @override
  State<PhaseAnalysisSettingsView> createState() => _PhaseAnalysisSettingsViewState();
}

class _PhaseAnalysisSettingsViewState extends State<PhaseAnalysisSettingsView> {
  PhaseRegimeService? _phaseRegimeService;
  PhaseIndex? _phaseIndex;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final analyticsService = AnalyticsService();
    final rivetSweepService = RivetSweepService(analyticsService);
    _phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
    await _phaseRegimeService!.initialize();
    if (mounted) {
      setState(() {
        _phaseIndex = _phaseRegimeService!.phaseIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: const BackButton(color: kcPrimaryTextColor),
        title: Text(
          'Phase Analysis',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPhaseAnalysisCard(),
            const SizedBox(height: 16),
            _buildPhaseStatisticsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseAnalysisCard() {
    return Card(
      color: kcSurfaceAltColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: kcAccentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Phase Analysis',
                    style: heading3Style(context).copyWith(
                      color: kcPrimaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Detect phase transitions in your entries using pattern recognition. '
              'Results are applied automatically.',
              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
            const SizedBox(height: 12),
            FutureBuilder<DateTime?>(
              future: _getLastAnalysisDate(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: kcSecondaryTextColor),
                        const SizedBox(width: 6),
                        Text(
                          'Last analysis: ${_formatDateTime(snapshot.data!)}',
                          style: bodyStyle(context).copyWith(
                            fontSize: 12,
                            color: kcSecondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _runRivetSweep,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_isLoading ? 'Analyzing...' : 'Run Phase Analysis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kcAccentColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: kcAccentColor.withOpacity(0.6),
                  disabledForegroundColor: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseStatisticsCard() {
    final regimes = _phaseIndex?.allRegimes ?? [];
    final totalDays = regimes.fold<int>(0, (sum, r) => sum + r.duration.inDays);

    return Card(
      color: kcSurfaceAltColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: kcAccentColor),
                const SizedBox(width: 8),
                Text(
                  'Phase Statistics',
                  style: heading3Style(context).copyWith(
                    color: kcPrimaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Phases', '${regimes.length}', Icons.layers),
                _buildStatItem('Days', '$totalDays', Icons.calendar_today),
                _buildStatItem('Current', _getCurrentPhaseName(), Icons.flag),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Compact stat: smaller number font so phase name fits inside card; purple accent.
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: kcAccentColor, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentPhaseName() {
    if (_phaseIndex?.currentRegime != null) {
      return _getPhaseLabelName(_phaseIndex!.currentRegime!.label);
    } else if (_phaseIndex?.allRegimes.isNotEmpty == true) {
      final sortedRegimes = List.from(_phaseIndex!.allRegimes)
        ..sort((a, b) => b.start.compareTo(a.start));
      return _getPhaseLabelName(sortedRegimes.first.label);
    }
    return 'Discovery';
  }

  String _getPhaseLabelName(PhaseLabel label) {
    switch (label) {
      case PhaseLabel.discovery:
        return 'Discovery';
      case PhaseLabel.expansion:
        return 'Expansion';
      case PhaseLabel.consolidation:
        return 'Consolidation';
      case PhaseLabel.recovery:
        return 'Recovery';
      case PhaseLabel.transition:
        return 'Transition';
      case PhaseLabel.breakthrough:
        return 'Breakthrough';
    }
  }

  Future<DateTime?> _getLastAnalysisDate() async {
    return _phaseRegimeService?.getLastAnalysisDate();
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }

  Future<void> _runRivetSweep() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final journalRepo = JournalRepository();
      final journalEntries = journalRepo.getAllJournalEntriesSync();

      if (journalEntries.length < 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Need at least 5 entries to run phase analysis'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final result = await rivetSweepService.analyzeEntries(journalEntries);
      final proposals = result.approvableProposals;

      if (proposals.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Analysis complete — no distinct phases detected yet. Keep journaling!'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        return;
      }

      final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
      await phaseRegimeService.initialize();
      await phaseRegimeService.clearAllRegimes();
      await phaseRegimeService.initialize();

      int created = 0;
      for (int i = 0; i < proposals.length; i++) {
        final proposal = proposals[i];
        final isLast = i == proposals.length - 1;
        DateTime? regimeEnd = proposal.end;
        if (isLast) {
          final daysSinceEnd = DateTime.now().difference(proposal.end).inDays;
          if (daysSinceEnd <= 2) regimeEnd = null;
        }
        await phaseRegimeService.createRegime(
          label: proposal.proposedLabel,
          start: proposal.start,
          end: regimeEnd,
          source: PhaseSource.rivet,
          confidence: proposal.confidence,
          anchors: proposal.entryIds,
        );
        created++;
      }

      await phaseRegimeService.setLastAnalysisDate(DateTime.now());
      await _initializeServices();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$created phase${created == 1 ? '' : 's'} detected and applied'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phase Analysis failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// lib/shared/ui/settings/combined_analysis_view.dart
// Combined Analysis View - merges Phase Analysis with Advanced Analytics tabs

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

// Phase Analysis imports
import 'package:my_app/models/phase_models.dart';
import 'package:my_app/services/phase_index.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/ui/phase/rivet_sweep_wizard.dart';
import 'package:my_app/ui/phase/phase_change_readiness_card.dart';

// Advanced Analytics imports
import 'package:my_app/prism/atlas/phase/your_patterns_view.dart';
import 'package:my_app/insights/widgets/aurora_card.dart';
import 'package:my_app/insights/widgets/veil_card.dart';
import 'package:my_app/ui/veil/veil_policy_card.dart';
import 'package:my_app/ui/phase/sentinel_analysis_view.dart';
import 'dart:math' as math;

class CombinedAnalysisView extends StatefulWidget {
  const CombinedAnalysisView({super.key});

  @override
  State<CombinedAnalysisView> createState() => _CombinedAnalysisViewState();
}

class _CombinedAnalysisViewState extends State<CombinedAnalysisView> {
  int _selectedTab = 0;
  final PageController _pageController = PageController();

  // Phase Analysis state
  PhaseRegimeService? _phaseRegimeService;
  PhaseIndex? _phaseIndex;
  bool _isLoading = false;
  RivetSweepResult? _lastSweepResult;
  bool _hasUnapprovedAnalysis = false;

  final List<_AnalysisTab> _tabs = const [
    _AnalysisTab(
      title: 'Phase',
      icon: Icons.auto_awesome,
      subtitle: 'Phase detection & statistics',
    ),
    _AnalysisTab(
      title: 'Patterns',
      icon: Icons.hub,
      subtitle: 'Keyword & emotion visualization',
    ),
    _AnalysisTab(
      title: 'AURORA',
      icon: Icons.brightness_auto,
      subtitle: 'Circadian Intelligence',
    ),
    _AnalysisTab(
      title: 'VEIL',
      icon: Icons.visibility_off,
      subtitle: 'AI Prompt Intelligence',
    ),
    _AnalysisTab(
      title: 'SENTINEL',
      icon: Icons.shield,
      subtitle: 'Emotional risk detection',
    ),
  ];

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
    
    await _checkPendingAnalysis();
  }

  Future<void> _checkPendingAnalysis() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPendingAnalysis = prefs.getBool('phase_analysis_pending') ?? false;
      
      if (hasPendingAnalysis && mounted) {
        setState(() {
          _hasUnapprovedAnalysis = true;
        });
      }
    } catch (e) {
      print('Error checking pending analysis: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
          'Analysis',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Horizontally scrollable tab bar
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = _selectedTab == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTab = index;
                    });
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? kcAccentColor : kcSurfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? kcAccentColor : kcBorderColor,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.icon,
                          size: 18,
                          color: isSelected ? Colors.white : kcPrimaryTextColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tab.title,
                          style: bodyStyle(context).copyWith(
                            color: isSelected ? Colors.white : kcPrimaryTextColor,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: kcBorderColor),
          // Page view for tab content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedTab = index;
                });
              },
              children: [
                _buildPhaseAnalysisTab(),
                _buildPatternsTab(),
                _buildAuroraTab(),
                _buildVeilTab(),
                _buildSentinelTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Phase Analysis Tab (from phase_analysis_view.dart)
  // ============================================================
  Widget _buildPhaseAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase Analysis Card
          _buildPhaseAnalysisCard(),
          const SizedBox(height: 16),
          
          // Phase Statistics Card
          _buildPhaseStatsCard(),
          const SizedBox(height: 16),
          
          // Current Phase Detection Card
          _buildCurrentPhaseCard(),
          const SizedBox(height: 16),
          
          // Phase Change Readiness
          const PhaseChangeReadinessCard(),
          const SizedBox(height: 16),
          
          // Phase Self-Assessment Card
          _buildSelfAssessmentCard(),
        ],
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
                // Refresh button
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kcSurfaceColor,
                  ),
                  child: IconButton(
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(kcAccentColor),
                            ),
                          )
                        : Icon(Icons.refresh, size: 20, color: kcPrimaryTextColor),
                    onPressed: _isLoading ? null : _runRivetSweep,
                    tooltip: 'Run Phase Analysis',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Automatically detect phase transitions in your journal entries using advanced pattern recognition.',
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
            // Run Analysis Button
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
                ),
              ),
            ),
            if (_hasUnapprovedAnalysis && _lastSweepResult != null)
              _buildAnalysisCompletePlacard(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCompletePlacard() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Analysis complete! Review results in the wizard.',
              style: bodyStyle(context).copyWith(color: Colors.green[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseStatsCard() {
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
                Icon(Icons.timeline, color: Colors.green),
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
                _buildStatItem('Total Phases', '${regimes.length}', Icons.layers),
                _buildStatItem('Total Days', '$totalDays', Icons.calendar_today),
                _buildStatItem('Current', _getCurrentPhaseName(), Icons.flag),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: kcAccentColor, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: heading2Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentPhaseCard() {
    final currentPhaseName = _getCurrentPhaseName();
    final phaseColor = _getPhaseColor(currentPhaseName);

    return Card(
      color: kcSurfaceAltColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: phaseColor),
                const SizedBox(width: 8),
                Text(
                  'Current Phase',
                  style: heading3Style(context).copyWith(
                    color: kcPrimaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: phaseColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: phaseColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: phaseColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    currentPhaseName,
                    style: heading2Style(context).copyWith(
                      color: phaseColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelfAssessmentCard() {
    return Card(
      color: kcSurfaceAltColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.quiz, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Phase Self-Assessment',
                  style: heading3Style(context).copyWith(
                    color: kcPrimaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Take a quick self-assessment to help identify your current developmental phase.',
              style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startPhaseQuiz,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Self-Assessment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Patterns Tab (from Advanced Analytics)
  // ============================================================
  Widget _buildPatternsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPatternsCard(),
        ],
      ),
    );
  }

  Widget _buildPatternsCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const YourPatternsView()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kcSurfaceAltColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kcBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildMiniRadialIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Patterns',
                        style: heading3Style(context).copyWith(
                          color: kcPrimaryTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Keyword & emotion visualization',
                        style: bodyStyle(context).copyWith(
                          fontSize: 12,
                          color: kcSecondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: kcSecondaryTextColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kcSurfaceColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How it works',
                    style: bodyStyle(context).copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: kcPrimaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Analyzes your journal entries to identify recurring keywords, emotions, and their connections.',
                    style: bodyStyle(context).copyWith(
                      fontSize: 11,
                      color: kcSecondaryTextColor,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniRadialIcon() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: CustomPaint(
        painter: _MiniRadialPainter(),
      ),
    );
  }

  // ============================================================
  // AURORA Tab
  // ============================================================
  Widget _buildAuroraTab() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraCard(),
        ],
      ),
    );
  }

  // ============================================================
  // VEIL Tab
  // ============================================================
  Widget _buildVeilTab() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VeilCard(),
          SizedBox(height: 16),
          VeilPolicyCard(),
        ],
      ),
    );
  }

  // ============================================================
  // SENTINEL Tab
  // ============================================================
  Widget _buildSentinelTab() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SentinelAnalysisView(),
        ],
      ),
    );
  }

  // ============================================================
  // Helper Methods
  // ============================================================
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

  Color _getPhaseColor(String phaseName) {
    switch (phaseName.toLowerCase()) {
      case 'discovery':
        return Colors.blue;
      case 'expansion':
        return Colors.green;
      case 'consolidation':
        return Colors.orange;
      case 'recovery':
        return Colors.teal;
      case 'disruption':
        return Colors.red;
      case 'transcendence':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<DateTime?> _getLastAnalysisDate() async {
    return _phaseRegimeService?.getLastAnalysisDate();
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  Future<void> _runRivetSweep() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Get journal entries for analysis
      final journalRepo = JournalRepository();
      final journalEntries = journalRepo.getAllJournalEntriesSync();
      
      if (journalEntries.length < 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Need at least 3 journal entries for analysis'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final analyticsService = AnalyticsService();
      final rivetSweepService = RivetSweepService(analyticsService);
      final result = await rivetSweepService.analyzeEntries(journalEntries);
      
      final hasProposals = result.autoAssign.isNotEmpty || result.review.isNotEmpty;
      if (hasProposals && mounted) {
        setState(() {
          _lastSweepResult = result;
          _hasUnapprovedAnalysis = true;
        });
        
        // Show RIVET Sweep wizard
        await _showRivetSweepWizard(result);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No new phase transitions detected'),
            duration: Duration(seconds: 3),
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showRivetSweepWizard(RivetSweepResult result) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RivetSweepWizard(
          sweepResult: result,
          onApprove: (approved, overrides) async {
            Navigator.of(context).pop();
            if (mounted) {
              setState(() {
                _hasUnapprovedAnalysis = false;
                _lastSweepResult = null;
              });
              // Reload phase data
              await _initializeServices();
            }
          },
          onSkip: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _startPhaseQuiz() {
    // Show a simple dialog with phase selection
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcSurfaceAltColor,
        title: Text(
          'Select Your Phase',
          style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
        ),
        content: Text(
          'Based on your current state, which phase best describes you?',
          style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _AnalysisTab {
  final String title;
  final IconData icon;
  final String subtitle;

  const _AnalysisTab({
    required this.title,
    required this.icon,
    required this.subtitle,
  });
}

class _MiniRadialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = kcPrimaryTextColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, 2, Paint()..color = kcPrimaryTextColor..style = PaintingStyle.fill);

    final angles = [0, 60, 120, 180, 240, 300];
    for (final angle in angles) {
      final radians = angle * 3.14159 / 180;
      final startPoint = Offset(
        center.dx + 3 * math.cos(radians),
        center.dy + 3 * math.sin(radians),
      );
      final endPoint = Offset(
        center.dx + radius * math.cos(radians),
        center.dy + radius * math.sin(radians),
      );
      canvas.drawLine(startPoint, endPoint, paint);
      canvas.drawCircle(endPoint, 1.5, Paint()..color = kcPrimaryTextColor.withOpacity(0.7)..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}


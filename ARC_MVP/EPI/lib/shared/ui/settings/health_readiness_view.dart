// lib/shared/ui/settings/health_readiness_view.dart
// Full-page view for Health & Readiness dashboard

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/services/phase_aware_analysis_service.dart';
import 'package:my_app/services/phase_rating_service.dart';
import 'package:my_app/services/phase_rating_ranges.dart';
import 'package:my_app/services/health_data_service.dart';
import 'package:my_app/prism/atlas/phase/phase_history_repository.dart';
import 'package:my_app/arc/internal/mira/journal_repository.dart';

class HealthReadinessView extends StatefulWidget {
  const HealthReadinessView({super.key});

  @override
  State<HealthReadinessView> createState() => _HealthReadinessViewState();
}

class _HealthReadinessViewState extends State<HealthReadinessView> {
  bool _loading = true;
  PhaseContext? _currentContext;
  HealthData? _currentHealth;
  List<PhaseHistoryEntry> _recentHistory = [];
  int? _currentReadinessScore;
  bool _isHealthAutoDetected = false;

  @override
  void initState() {
    super.initState();
    _loadReadinessData();
  }

  Future<void> _loadReadinessData() async {
    setState(() => _loading = true);
    try {
      // Get current health data
      final healthData = await HealthDataService.instance.getEffectiveHealthData();
      
      // Check if health data is auto-detected
      final autoHealthData = await HealthDataService.instance.getAutoDetectedHealthData();
      final isAutoDetected = !healthData.isStale && 
        ((autoHealthData.sleepQuality != 0.7 || autoHealthData.energyLevel != 0.7) &&
         (autoHealthData.sleepQuality == healthData.sleepQuality && 
          autoHealthData.energyLevel == healthData.energyLevel));
      
      // Get latest journal entry for real phase analysis
      final journalRepo = JournalRepository();
      final allEntries = await journalRepo.getAllJournalEntries();
      
      String journalText = "Current state analysis"; // Default fallback
      if (allEntries.isNotEmpty) {
        // Sort by date, get most recent
        allEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final latestEntry = allEntries.first;
        journalText = latestEntry.content.isNotEmpty 
            ? latestEntry.content 
            : journalText;
      }
      
      // Analyze phase with real journal entry and health data
      final phaseService = PhaseAwareAnalysisService();
      final context = await phaseService.analyzePhase(
        journalText,
        healthData: healthData,
      );
      
      // Load all history entries (not just recent 7)
      final history = await PhaseHistoryRepository.getAllEntries();
      
      if (mounted) {
        setState(() {
          _currentContext = context;
          _currentHealth = healthData;
          _recentHistory = history;
          _currentReadinessScore = context.operationalReadinessScore;
          _isHealthAutoDetected = isAutoDetected;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading readiness data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
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
          'Health & Readiness',
          style: heading1Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: kcPrimaryTextColor),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReadinessData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentReadinessScore != null) ...[
                      _buildReadinessScoreCard(),
                      const SizedBox(height: 20),
                    ],
                    _buildHealthStatusCard(),
                    const SizedBox(height: 20),
                    _buildRatingHistoryCard(),
                    const SizedBox(height: 20),
                    _buildPhaseTransitionsCard(),
                    const SizedBox(height: 20),
                    _buildHealthCorrelationCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReadinessScoreCard() {
    final score = _currentReadinessScore!;
    final interpretation = PhaseRatingService.getReadinessInterpretation(score);
    final phase = _currentContext?.primaryPhase;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kcBorderColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Operational Readiness Score',
                  style: heading2Style(context).copyWith(
                    color: kcPrimaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                color: kcSecondaryTextColor,
                onPressed: () => _showReadinessInfoDialog(context),
                tooltip: 'Learn more about readiness score',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Combines your mental state (phase) with physical health metrics. Lower scores indicate need for rest/recovery; higher scores indicate readiness for duty.',
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          
          // Large Score Display
          Center(
            child: Column(
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: _getReadinessColor(score),
                  ),
                ),
                const Text(
                  '/ 100',
                  style: TextStyle(
                    fontSize: 24,
                    color: kcSecondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 12,
              backgroundColor: kcSurfaceAltColor,
              valueColor: AlwaysStoppedAnimation<Color>(_getReadinessColor(score)),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Status Badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getReadinessColor(score).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getReadinessColor(score).withOpacity(0.5),
                ),
              ),
              child: Text(
                interpretation,
                style: TextStyle(
                  color: _getReadinessColor(score),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Phase Info
          if (phase != null) ...[
            Text(
              'Phase: ${phase.name.toUpperCase()}',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Range: ${PhaseRatingRanges.getMin(phase.name)}-${PhaseRatingRanges.getMax(phase.name)}',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
                fontSize: 12,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Breakdown Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kcSurfaceAltColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kcBorderColor),
            ),
            child: Column(
              children: [
                if (_currentContext != null) ...[
                  _buildBreakdownRow('Base Rating', _calculateBaseRating()),
                  const SizedBox(height: 8),
                  _buildBreakdownRow(
                    'Health Adjustment',
                    _calculateHealthAdjustment(),
                    isAdjustment: true,
                  ),
                  const SizedBox(height: 8),
                  _buildBreakdownRow('Final Score', score, isFinal: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, int value, {bool isAdjustment = false, bool isFinal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
            fontSize: 14,
          ),
        ),
        Text(
          isAdjustment && value != 0
              ? '${value > 0 ? '+' : ''}$value'
              : '$value',
          style: bodyStyle(context).copyWith(
            color: isFinal ? _getReadinessColor(value) : kcPrimaryTextColor,
            fontWeight: isFinal ? FontWeight.bold : FontWeight.normal,
            fontSize: isFinal ? 16 : 14,
          ),
        ),
      ],
    );
  }

  int _calculateBaseRating() {
    if (_currentContext == null) return 0;
    return PhaseRatingRanges.getRating(
      _currentContext!.primaryPhase.name,
      _currentContext!.confidence / 100.0,
    );
  }

  int _calculateHealthAdjustment() {
    if (_currentReadinessScore == null || _currentContext == null) return 0;
    final baseRating = _calculateBaseRating();
    return _currentReadinessScore! - baseRating;
  }

  Widget _buildHealthStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kcBorderColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Health Status',
            style: heading3Style(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (_currentHealth != null) ...[
            _buildHealthMetricRow('Sleep Quality', _currentHealth!.sleepQuality, Icons.bedtime),
            const SizedBox(height: 12),
            _buildHealthMetricRow('Energy Level', _currentHealth!.energyLevel, Icons.bolt),
            if (_currentHealth!.fitnessScore != null) ...[
              const SizedBox(height: 12),
              _buildHealthMetricRow('Fitness (VO2 Max)', _currentHealth!.fitnessScore!, Icons.fitness_center, 
                description: 'Cardiovascular fitness level'),
            ],
            if (_currentHealth!.recoveryScore != null) ...[
              const SizedBox(height: 12),
              _buildHealthMetricRow('Heart Rate Recovery', _currentHealth!.recoveryScore!, Icons.favorite, 
                description: 'Post-exercise recovery rate'),
            ],
            if (_currentHealth!.weightTrendScore != null) ...[
              const SizedBox(height: 12),
              _buildHealthMetricRow('Weight Trend', _currentHealth!.weightTrendScore!, Icons.monitor_weight, 
                description: 'Weight stability indicator'),
            ],
            const SizedBox(height: 12),
            // Data source indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isHealthAutoDetected 
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isHealthAutoDetected 
                      ? Colors.blue.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isHealthAutoDetected ? Icons.auto_awesome : Icons.edit,
                    size: 16,
                    color: _isHealthAutoDetected ? Colors.blue : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isHealthAutoDetected
                          ? 'Auto-detected from Apple Health'
                          : 'Manually set',
                      style: bodyStyle(context).copyWith(
                        color: _isHealthAutoDetected ? Colors.blue : Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_currentHealth!.lastUpdated != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last updated: ${_formatLastUpdated(_currentHealth!.lastUpdated!)}',
                style: bodyStyle(context).copyWith(
                  color: kcSecondaryTextColor,
                  fontSize: 12,
                ),
              ),
            ],
          ] else ...[
            Text(
              'No health data available',
              style: bodyStyle(context).copyWith(
                color: kcSecondaryTextColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthMetricRow(String label, double value, IconData icon, {String? description}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: kcSecondaryTextColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: bodyStyle(context).copyWith(
                      color: kcPrimaryTextColor,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: bodyStyle(context).copyWith(
                color: _getValueColor(value),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: kcSurfaceAltColor,
                  valueColor: AlwaysStoppedAnimation<Color>(_getValueColor(value)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kcBorderColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rating History',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to full history view
                },
                child: const Text('View Full History →'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              // Filter entries with readiness scores
              final entriesWithScores = _recentHistory.where((e) => e.operationalReadinessScore != null).toList();
              if (entriesWithScores.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Text(
                          _recentHistory.isEmpty
                              ? 'No rating history available yet.\nStart journaling to generate ratings.'
                              : 'No readiness scores found in ${_recentHistory.length} history entries.\nScores are generated when journal entries are analyzed.',
                          textAlign: TextAlign.center,
                          style: bodyStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                          ),
                        ),
                        if (_recentHistory.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Total entries: ${_recentHistory.length}',
                            textAlign: TextAlign.center,
                            style: bodyStyle(context).copyWith(
                              color: kcSecondaryTextColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }
              
              return Column(
                children: [
                  // Chart visualization
                  SizedBox(
                    height: 200,
                    child: _buildRatingHistoryChart(entriesWithScores),
                  ),
                  const SizedBox(height: 16),
                  // Show count
                  Text(
                    'Showing ${entriesWithScores.length} of ${_recentHistory.length} entries with scores',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // List view below chart (show recent 10)
                  ...entriesWithScores.reversed.take(10).map((entry) {
                    final score = entry.operationalReadinessScore;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatDate(entry.timestamp),
                              style: bodyStyle(context).copyWith(
                                color: kcSecondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (score != null) ...[
                            SizedBox(
                              width: 60,
                              child: Text(
                                '$score',
                                textAlign: TextAlign.right,
                                style: bodyStyle(context).copyWith(
                                  color: _getReadinessColor(score),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 100,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: score / 100,
                                  minHeight: 6,
                                  backgroundColor: kcSurfaceAltColor,
                                  valueColor: AlwaysStoppedAnimation<Color>(_getReadinessColor(score)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getReadinessColor(int score) {
    if (score >= 85) return kcSuccessColor;
    if (score >= 70) return const Color(0xFF8BC34A);
    if (score >= 50) return kcWarningColor;
    if (score >= 30) return const Color(0xFFFF9800);
    return kcDangerColor;
  }

  Color _getValueColor(double value) {
    if (value < 0.4) return kcDangerColor;
    if (value < 0.6) return kcWarningColor;
    return kcSuccessColor;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  String _formatLastUpdated(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcBackgroundColor,
        title: Text(
          'Health & Readiness',
          style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Operational Readiness Score',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The readiness score (10-100) combines your mental state (phase) with physical health metrics. Lower scores indicate need for rest/recovery; higher scores indicate readiness for duty.',
                style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
              const SizedBox(height: 16),
              Text(
                'Rating Ranges',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Recovery: 10-25\n• Transition: 35-50\n• Discovery: 50-65\n• Reflection: 55-70\n• Consolidation: 70-85\n• Breakthrough: 85-100',
                style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showReadinessInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kcBackgroundColor,
        title: Text(
          'Operational Readiness Score',
          style: heading2Style(context).copyWith(color: kcPrimaryTextColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What Goes Into the Score?',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The readiness score combines multiple factors:',
                style: bodyStyle(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoItem('1. Base Phase Rating', 'Determined by your current mental phase (recovery, discovery, transition, etc.) and confidence level. Each phase has a specific range (e.g., breakthrough: 85-100).'),
              const SizedBox(height: 8),
              _buildInfoItem('2. Health Adjustment', 'Your physical health factors can adjust the score:\n• Sleep Quality: Based on sleep duration, HRV, and resting heart rate\n• Energy Level: Based on steps, exercise, and active calories\n• Fitness Score: Based on VO2 Max (cardiovascular fitness)\n• Recovery Score: Based on heart rate recovery post-exercise\n• Weight Trend: Based on weight stability over time\n\nAdjustments:\n• Poor health (<40%): -20 points\n• Moderate health (40-60%): -10 points\n• Excellent health (>80%): +10 points'),
              const SizedBox(height: 8),
              _buildInfoItem('3. Final Score', 'The base rating plus health adjustment, clamped to 10-100 range.'),
              const SizedBox(height: 16),
              Text(
                'Rating Ranges by Phase',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Recovery: 10-25\n• Transition: 35-50\n• Discovery: 50-65\n• Reflection: 55-70\n• Consolidation: 70-85\n• Breakthrough: 85-100',
                style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
              const SizedBox(height: 16),
              Text(
                'Phase Hierarchy (Readiness Comparison)',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildPhaseHierarchyComparison(),
              const SizedBox(height: 16),
              Text(
                'Interpretation',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• 85-100: Excellent Readiness - Ready for high-intensity work\n• 70-84: Good Readiness - Ready for normal operations\n• 50-69: Moderate Readiness - May need lighter workload\n• 30-49: Low Readiness - Consider rest and recovery\n• 10-29: Critical Readiness - Rest required',
                style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: bodyStyle(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseHierarchyComparison() {
    final phases = [
      {
        'name': 'Breakthrough',
        'range': '85-100',
        'desc': 'Peak performance, high-intensity readiness',
        'color': kcSuccessColor
      },
      {
        'name': 'Consolidation',
        'range': '70-85',
        'desc': 'Stable, organized, ready for normal operations',
        'color': const Color(0xFF8BC34A)
      },
      {
        'name': 'Reflection',
        'range': '55-70',
        'desc': 'Contemplative, moderate-high readiness',
        'color': kcWarningColor
      },
      {
        'name': 'Discovery',
        'range': '50-65',
        'desc': 'Active exploration, learning, seeking new things',
        'color': const Color(0xFF2196F3)
      },
      {
        'name': 'Transition',
        'range': '35-50',
        'desc': 'In-between state, navigating change, uncertain',
        'color': kcAccentColor
      },
      {
        'name': 'Recovery',
        'range': '10-25',
        'desc': 'Critical, needs rest and recovery',
        'color': kcDangerColor
      },
    ];

    return Column(
      children: phases.map((phase) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: phase['color'] as Color,
                  borderRadius: BorderRadius.circular(2),
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
                          phase['name'] as String,
                          style: bodyStyle(context).copyWith(
                            color: kcPrimaryTextColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${phase['range']})',
                          style: bodyStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phase['desc'] as String,
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRatingHistoryChart(List<PhaseHistoryEntry> validEntries) {
    if (validEntries.isEmpty) {
      return Center(
        child: Text(
          'No rating data available',
          style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
        ),
      );
    }

    // Prepare data points
    final spots = <FlSpot>[];
    
    // Sort by timestamp (oldest first for chart)
    validEntries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (int i = 0; i < validEntries.length; i++) {
      final score = validEntries[i].operationalReadinessScore!;
      spots.add(FlSpot(i.toDouble(), score.toDouble()));
    }

    final maxY = validEntries.map((e) => e.operationalReadinessScore ?? 0).reduce((a, b) => a > b ? a : b);
    final minY = validEntries.map((e) => e.operationalReadinessScore ?? 0).reduce((a, b) => a < b ? a : b);
    final yRange = maxY - minY;
    final chartMinY = (minY - (yRange * 0.1)).clamp(0.0, 100.0);
    final chartMaxY = (maxY + (yRange * 0.1)).clamp(0.0, 100.0);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (validEntries.length - 1).toDouble(),
        minY: chartMinY,
        maxY: chartMaxY,
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: validEntries.length > 7 ? validEntries.length / 5 : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= validEntries.length) return const SizedBox.shrink();
                final date = validEntries[index].timestamp;
                final dayLabel = _getDayLabel(date);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    dayLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      color: kcSecondaryTextColor,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 20,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: kcSecondaryTextColor,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: kcBorderColor.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: kcBorderColor.withOpacity(0.3)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: kcAccentColor,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 4,
                color: kcAccentColor,
                strokeWidth: 2,
                strokeColor: kcBackgroundColor,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: kcAccentColor.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => kcSurfaceColor,
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= validEntries.length) return null;
                final entry = validEntries[index];
                return LineTooltipItem(
                  '${entry.operationalReadinessScore}\n${_formatDate(entry.timestamp)}',
                  const TextStyle(
                    color: kcPrimaryTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  String _getDayLabel(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[date.weekday - 1];
    }
    return '${date.month}/${date.day}';
  }

  Widget _buildPhaseTransitionsCard() {
    // Get unique phases from history
    final phaseEntries = <String, PhaseHistoryEntry>{};
    for (final entry in _recentHistory) {
      // Find the phase with highest score
      if (entry.phaseScores.isNotEmpty) {
        final dayKey = '${entry.timestamp.year}-${entry.timestamp.month}-${entry.timestamp.day}';
        if (!phaseEntries.containsKey(dayKey)) {
          phaseEntries[dayKey] = entry;
        }
      }
    }

    final sortedEntries = phaseEntries.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kcBorderColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Phase Transitions',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to phase details view
                },
                child: const Text('View Details →'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              // Filter entries with phase scores
              final entriesWithPhases = sortedEntries.where((e) => e.phaseScores.isNotEmpty).toList();
              if (entriesWithPhases.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Text(
                          _recentHistory.isEmpty
                              ? 'No phase transition data available.\nStart journaling to track phase changes.'
                              : 'No phase scores found in ${_recentHistory.length} history entries.\nPhases are detected when journal entries are analyzed.',
                          textAlign: TextAlign.center,
                          style: bodyStyle(context).copyWith(
                            color: kcSecondaryTextColor,
                          ),
                        ),
                        if (_recentHistory.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Total entries: ${_recentHistory.length}',
                            textAlign: TextAlign.center,
                            style: bodyStyle(context).copyWith(
                              color: kcSecondaryTextColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show count
                  Text(
                    'Showing ${entriesWithPhases.length} phase transitions from ${_recentHistory.length} total entries',
                    style: bodyStyle(context).copyWith(
                      color: kcSecondaryTextColor,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Timeline view
                  ...entriesWithPhases.asMap().entries.map((entry) {
                    final index = entry.key;
                    final historyEntry = entry.value;
                    final topPhaseEntry = historyEntry.phaseScores.entries
                        .reduce((a, b) => a.value > b.value ? a : b);
                    final topPhase = topPhaseEntry.key;
                    final score = historyEntry.operationalReadinessScore;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          // Timeline dot
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getPhaseColor(topPhase),
                              border: Border.all(color: kcBackgroundColor, width: 2),
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
                                      topPhase,
                                      style: bodyStyle(context).copyWith(
                                        color: kcPrimaryTextColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (score != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '($score)',
                                        style: bodyStyle(context).copyWith(
                                          color: _getReadinessColor(score),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(historyEntry.timestamp),
                                  style: bodyStyle(context).copyWith(
                                    color: kcSecondaryTextColor,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (index < entriesWithPhases.length - 1)
                            const Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: kcSecondaryTextColor,
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getPhaseColor(String phaseName) {
    final phase = phaseName.toLowerCase();
    if (phase.contains('recovery')) return kcDangerColor;
    if (phase.contains('discovery')) return const Color(0xFF2196F3);
    if (phase.contains('transition')) return kcAccentColor;
    if (phase.contains('reflection')) return kcWarningColor;
    if (phase.contains('consolidation')) return kcSuccessColor;
    if (phase.contains('breakthrough')) return const Color(0xFFFFD700);
    return kcSecondaryTextColor;
  }

  Widget _buildHealthCorrelationCard() {
    // Calculate correlation between health and ratings
    final healthRatings = <Map<String, dynamic>>[];
    for (final entry in _recentHistory) {
      if (entry.operationalReadinessScore != null && entry.healthData != null) {
        final healthData = entry.healthData!;
        final sleepQuality = healthData['sleepQuality'] as num?;
        final energyLevel = healthData['energyLevel'] as num?;
        if (sleepQuality != null && energyLevel != null) {
          healthRatings.add({
            'score': entry.operationalReadinessScore,
            'sleepQuality': sleepQuality.toDouble(),
            'energyLevel': energyLevel.toDouble(),
            'date': entry.timestamp,
          });
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kcSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kcBorderColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Health Correlation',
                style: heading3Style(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to detailed correlation analysis
                },
                child: const Text('View Analysis →'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (healthRatings.isEmpty) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Text(
                      _recentHistory.isEmpty
                          ? 'No health correlation data available.\nHealth data is needed to show correlations.'
                          : 'No health correlation data found.\n${_recentHistory.length} entries found, but none have both readiness scores and health data.',
                      textAlign: TextAlign.center,
                      style: bodyStyle(context).copyWith(
                        color: kcSecondaryTextColor,
                      ),
                    ),
                    if (_recentHistory.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Entries with scores: ${_recentHistory.where((e) => e.operationalReadinessScore != null).length}\nEntries with health data: ${_recentHistory.where((e) => e.healthData != null).length}',
                        textAlign: TextAlign.center,
                        style: bodyStyle(context).copyWith(
                          color: kcSecondaryTextColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else ...[
            // Correlation insights
            _buildCorrelationInsight(
              'Average Readiness',
              '${(healthRatings.map((r) => r['score'] as int).reduce((a, b) => a + b) / healthRatings.length).toStringAsFixed(0)}/100',
            ),
            const SizedBox(height: 12),
            _buildCorrelationInsight(
              'Average Sleep Quality',
              '${(healthRatings.map((r) => r['sleepQuality'] as double).reduce((a, b) => a + b) / healthRatings.length * 100).toStringAsFixed(0)}%',
            ),
            const SizedBox(height: 12),
            _buildCorrelationInsight(
              'Average Energy Level',
              '${(healthRatings.map((r) => r['energyLevel'] as double).reduce((a, b) => a + b) / healthRatings.length * 100).toStringAsFixed(0)}%',
            ),
            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Readiness', kcAccentColor),
                const SizedBox(width: 24),
                _buildLegendItem('Health Factor', kcSuccessColor.withOpacity(0.6)),
              ],
            ),
            const SizedBox(height: 12),
            // Simple correlation chart
            SizedBox(
              height: 150,
              child: _buildHealthCorrelationChart(healthRatings),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCorrelationInsight(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: bodyStyle(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: bodyStyle(context).copyWith(
            color: kcSecondaryTextColor,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildHealthCorrelationChart(List<Map<String, dynamic>> healthRatings) {
    if (healthRatings.isEmpty) return const SizedBox.shrink();

    // Sort by date
    healthRatings.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // Create spots for readiness score
    final readinessSpots = healthRatings.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), (entry.value['score'] as int).toDouble());
    }).toList();

    // Create spots for health factor (average of sleep and energy)
    final healthSpots = healthRatings.asMap().entries.map((entry) {
      final healthFactor = ((entry.value['sleepQuality'] as double) + 
                           (entry.value['energyLevel'] as double)) / 2.0 * 100;
      return FlSpot(entry.key.toDouble(), healthFactor);
    }).toList();

    const maxY = 100.0;
    final maxX = (healthRatings.length - 1).toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: maxY,
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 25,
              interval: healthRatings.length > 7 ? healthRatings.length / 5 : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= healthRatings.length) return const SizedBox.shrink();
                final date = healthRatings[index]['date'] as DateTime;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${date.month}/${date.day}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: kcSecondaryTextColor,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: 25,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 9,
                    color: kcSecondaryTextColor,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: kcBorderColor.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: kcBorderColor.withOpacity(0.3)),
        ),
        lineBarsData: [
          // Readiness score line
          LineChartBarData(
            spots: readinessSpots,
            isCurved: true,
            color: kcAccentColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          // Health factor line
          LineChartBarData(
            spots: healthSpots,
            isCurved: true,
            color: kcSuccessColor.withOpacity(0.6),
            barWidth: 2,
            dotData: const FlDotData(show: false),
            dashArray: [5, 5],
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => kcSurfaceColor,
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.all(8),
          ),
        ),
      ),
    );
  }
}


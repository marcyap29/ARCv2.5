// lib/ui/phase/sentinel_analysis_view.dart
// SENTINEL Analysis UI - Emotional risk detection and pattern analysis

import 'package:flutter/material.dart';
import '../../prism/extractors/sentinel_risk_detector.dart';
import '../../core/models/reflective_entry_data.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'sentinel_pattern_card.dart';
import 'phase_help_screen.dart';

class SentinelAnalysisView extends StatefulWidget {
  const SentinelAnalysisView({super.key});

  @override
  State<SentinelAnalysisView> createState() => _SentinelAnalysisViewState();
}

class _SentinelAnalysisViewState extends State<SentinelAnalysisView> {
  TimeWindow _selectedTimeWindow = TimeWindow.week;
  SentinelAnalysis? _currentAnalysis;
  bool _isLoading = false;
  DateTime? _lastAnalysisDate;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get journal entries for analysis
      final journalRepo = JournalRepository();
      final journalEntries = journalRepo.getAllJournalEntriesSync();

      if (journalEntries.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Convert journal entries to ReflectiveEntryData
      final reflectiveEntries = journalEntries.map((entry) {
        return ReflectiveEntryData(
          timestamp: entry.createdAt,
          keywords: entry.keywords,
          phase: entry.phase ?? 'unknown',
          mood: entry.mood,
          source: EvidenceSource.journal,
          confidence: 1.0,
        );
      }).toList();

      // Run SENTINEL analysis
      final analysis = SentinelRiskDetector.analyzeRisk(
        entries: reflectiveEntries,
        timeWindow: _selectedTimeWindow,
      );

      setState(() {
        _currentAnalysis = analysis;
        _lastAnalysisDate = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Show error in UI instead of storing in state
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing emotional patterns...'),
          ],
        ),
      );
    }

    if (_currentAnalysis == null) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildTimeWindowSelector(),
          const SizedBox(height: 16),
          _buildRiskLevelCard(),
          const SizedBox(height: 16),
          _buildPatternsSection(),
          const SizedBox(height: 16),
          _buildRecommendationsSection(),
          const SizedBox(height: 16),
          _buildSummarySection(),
          const SizedBox(height: 16),
          _buildSafetyDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'SENTINEL Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _runAnalysis,
                  tooltip: 'Refresh Analysis',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'SENTINEL (Severity Evaluation and Negative Trend Identification for Emotional Longitudinal tracking) analyzes your emotional patterns to detect when distress patterns may warrant attention.',
            ),
            if (_lastAnalysisDate != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Last analysis: ${_formatDateTime(_lastAnalysisDate!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeWindowSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analysis Time Window',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButton<TimeWindow>(
              value: _selectedTimeWindow,
              isExpanded: true,
              onChanged: (TimeWindow? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedTimeWindow = newValue;
                  });
                  _runAnalysis();
                }
              },
              items: TimeWindow.values.map<DropdownMenuItem<TimeWindow>>((TimeWindow value) {
                return DropdownMenuItem<TimeWindow>(
                  value: value,
                  child: Text(_getTimeWindowLabel(value)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskLevelCard() {
    final analysis = _currentAnalysis!;
    final riskColor = _getRiskLevelColor(analysis.riskLevel);
    final riskScore = (analysis.riskScore * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assessment, color: riskColor),
                const SizedBox(width: 8),
                Text(
                  'Risk Assessment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Circular progress indicator
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    children: [
                      CircularProgressIndicator(
                        value: analysis.riskScore,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                      ),
                      Center(
                        child: Text(
                          '$riskScore%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: riskColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getRiskLevelLabel(analysis.riskLevel),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: riskColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getRiskLevelDescription(analysis.riskLevel),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternsSection() {
    final analysis = _currentAnalysis!;
    
    if (analysis.patterns.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 48),
              SizedBox(height: 12),
              Text(
                'No concerning patterns detected',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your emotional patterns appear stable within the selected time window.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.psychology, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Detected Patterns',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...analysis.patterns.map((pattern) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: SentinelPatternCard(pattern: pattern),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    final analysis = _currentAnalysis!;
    
    if (analysis.recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...analysis.recommendations.asMap().entries.map((entry) {
              final index = entry.key;
              final recommendation = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        recommendation,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final analysis = _currentAnalysis!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.summarize, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Analysis Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              analysis.summary,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyDisclaimer() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Important Notice',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'SENTINEL analysis is designed to help you understand your emotional patterns and is not a substitute for professional medical or mental health advice. If you are experiencing significant distress or have concerns about your mental health, please consult with a qualified healthcare professional.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeWindowLabel(TimeWindow window) {
    switch (window) {
      case TimeWindow.day:
        return 'Last 24 hours';
      case TimeWindow.threeDay:
        return 'Last 3 days';
      case TimeWindow.week:
        return 'Last 7 days';
      case TimeWindow.twoWeek:
        return 'Last 14 days';
      case TimeWindow.month:
        return 'Last 30 days';
    }
  }

  Color _getRiskLevelColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.minimal:
        return Colors.green;
      case RiskLevel.low:
        return Colors.lightGreen;
      case RiskLevel.moderate:
        return Colors.orange;
      case RiskLevel.elevated:
        return Colors.red;
      case RiskLevel.high:
        return Colors.red[800]!;
      case RiskLevel.severe:
        return Colors.red[900]!;
    }
  }

  String _getRiskLevelLabel(RiskLevel level) {
    switch (level) {
      case RiskLevel.minimal:
        return 'Minimal Risk';
      case RiskLevel.low:
        return 'Low Risk';
      case RiskLevel.moderate:
        return 'Moderate Risk';
      case RiskLevel.elevated:
        return 'Elevated Risk';
      case RiskLevel.high:
        return 'High Risk';
      case RiskLevel.severe:
        return 'Severe Risk';
    }
  }

  String _getRiskLevelDescription(RiskLevel level) {
    switch (level) {
      case RiskLevel.minimal:
        return 'Your emotional patterns appear stable and healthy.';
      case RiskLevel.low:
        return 'Minor fluctuations detected, but overall patterns are stable.';
      case RiskLevel.moderate:
        return 'Some concerning patterns detected. Consider reviewing recommendations.';
      case RiskLevel.elevated:
        return 'Elevated patterns detected. Please review recommendations carefully.';
      case RiskLevel.high:
        return 'Significant concerning patterns detected. Consider seeking support.';
      case RiskLevel.severe:
        return 'Severe patterns detected. Consider seeking professional support.';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'SENTINEL Analysis',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'SENTINEL analyzes your emotional patterns over time to detect concerning trends and provide early warnings.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Getting Started:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('• Journal regularly to build your emotional baseline'),
                const Text('• Import an MCP bundle with your past entries'),
                const Text('• Watch patterns emerge naturally over time'),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    // Open help screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PhaseHelpScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Learn More'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

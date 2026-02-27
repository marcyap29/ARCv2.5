import 'package:flutter/material.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';
import 'package:my_app/aurora/services/circadian_profile_service.dart';
import 'package:my_app/aurora/models/circadian_context.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'generic_system_card.dart';

/// AURORA card - Circadian Intelligence Dashboard (Refactored)
/// Uses GenericSystemCard for consistent UI and reduced code duplication
class AuroraCardRefactored extends StatefulWidget {
  const AuroraCardRefactored({super.key});

  @override
  State<AuroraCardRefactored> createState() => _AuroraCardRefactoredState();
}

class _AuroraCardRefactoredState extends State<AuroraCardRefactored> {
  CircadianContext? _circadianContext;
  bool _isLoading = true;
  bool _hasSufficientData = false;

  @override
  void initState() {
    super.initState();
    _loadCircadianContext();
  }

  Future<void> _loadCircadianContext() async {
    try {
      final journalRepo = JournalRepository();
      final aurora = CircadianProfileService();
      final entries = await journalRepo.getAllJournalEntries();

      _hasSufficientData = aurora.hasSufficientData(entries);
      final circadianContext = await aurora.compute(entries);

      setState(() {
        _circadianContext = circadianContext;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _getChronotypeDescription(String chronotype) {
    switch (chronotype) {
      case 'morning': return 'Morning person - most active before 11 AM';
      case 'evening': return 'Evening person - most active after 5 PM';
      case 'balanced': return 'Balanced rhythm - consistent activity throughout day';
      default: return 'Unknown';
    }
  }

  String _getWindowDescription(String window) {
    switch (window) {
      case 'morning': return '6 AM - 11 AM';
      case 'afternoon': return '11 AM - 5 PM';
      case 'evening': return '5 PM - 6 AM';
      default: return 'Unknown';
    }
  }

  String _getRhythmScoreDescription(double score) {
    if (score >= 0.55) return 'Coherent - consistent daily patterns';
    if (score >= 0.45) return 'Moderate - some variation in patterns';
    return 'Fragmented - varied daily activity';
  }

  Color _getRhythmScoreColor(double score) {
    if (score >= 0.55) return Colors.green;
    if (score >= 0.45) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final circadianContext = _circadianContext ?? const CircadianContext(
      window: 'afternoon',
      chronotype: 'balanced',
      rhythmScore: 0.5,
    );

    final config = SystemCardConfig(
      title: 'AURORA',
      subtitle: 'Circadian Intelligence',
      icon: Icons.wb_twilight,
      accentColor: Colors.purple,
      sections: [
        // Current Window
        SystemCardSection(
          content: InfoRow(
            icon: Icons.access_time,
            label: 'Current Window',
            value: circadianContext.window.toUpperCase(),
            description: _getWindowDescription(circadianContext.window),
            iconColor: Colors.purple,
          ),
          backgroundColor: Colors.purple.withOpacity(0.1),
          borderColor: Colors.purple.withOpacity(0.3),
        ),
        // Chronotype
        SystemCardSection(
          content: InfoRow(
            icon: Icons.person_outline,
            label: 'Chronotype',
            value: circadianContext.chronotype,
            description: _getChronotypeDescription(circadianContext.chronotype),
          ),
        ),
        // Rhythm Score
        SystemCardSection(
          content: _buildRhythmScore(circadianContext.rhythmScore),
        ),
      ],
      footer: _buildFooter(circadianContext),
    );

    return GenericSystemCard(
      config: config,
      isLoading: _isLoading,
      expandableSections: const ['Available Chronotypes', 'Available Time Windows'],
      expandableContent: const {
        'Available Chronotypes': [
          'Morning - Peak activity before 11 AM',
          'Balanced - Peak activity 11 AM - 5 PM',
          'Evening - Peak activity after 5 PM',
        ],
        'Available Time Windows': [
          'Morning - 6 AM to 11 AM',
          'Afternoon - 11 AM to 5 PM',
          'Evening - 5 PM to 6 AM',
        ],
      },
    );
  }

  Widget _buildRhythmScore(double score) {
    final color = _getRhythmScoreColor(score);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.show_chart, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              'Rhythm Coherence',
              style: bodyStyle(context).copyWith(
                fontSize: 11,
                color: kcPrimaryTextColor.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(score * 100).toInt()}%',
                style: bodyStyle(context).copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score,
            backgroundColor: kcSurfaceColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _getRhythmScoreDescription(score),
          style: bodyStyle(context).copyWith(
            fontSize: 10,
            color: color.withOpacity(0.9),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(CircadianContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kcSurfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: Colors.purple),
                  const SizedBox(width: 8),
                  Text(
                    'How AURORA Works',
                    style: bodyStyle(this.context).copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: kcPrimaryTextColor.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'AURORA analyzes your journal entry timestamps to detect your natural daily rhythm. It then adjusts LUMARA\'s response style and policy weights based on your chronotype and current time window.',
                style: bodyStyle(this.context).copyWith(
                  fontSize: 11,
                  color: kcPrimaryTextColor.withOpacity(0.7),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (!_hasSufficientData) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Need 8+ journal entries for reliable analysis',
                    style: bodyStyle(this.context).copyWith(
                      fontSize: 10,
                      color: Colors.orange.withOpacity(0.9),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

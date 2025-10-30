import 'package:flutter/material.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/text_style.dart';
import '../../../services/user_phase_service.dart';
import '../../../aurora/services/circadian_profile_service.dart';
import '../../../aurora/models/circadian_context.dart';
import '../../../arc/core/journal_repository.dart';

/// AURORA card - Circadian Intelligence Dashboard
/// Shows circadian rhythm analysis and how it affects LUMARA's behavior
class AuroraCard extends StatefulWidget {
  const AuroraCard({super.key});

  @override
  State<AuroraCard> createState() => _AuroraCardState();
}

class _AuroraCardState extends State<AuroraCard> {
  CircadianContext? _circadianContext;
  bool _isLoading = true;
  bool _hasSufficientData = false;
  bool _showMoreInfo = false;

  @override
  void initState() {
    super.initState();
    _loadCircadianContext();
  }

  Future<void> _loadCircadianContext() async {
    try {
      final journalRepo = JournalRepository();
      final aurora = CircadianProfileService();
      final entries = journalRepo.getAllJournalEntries();
      
      _hasSufficientData = aurora.hasSufficientData(entries);
      final circadianContext = await aurora.compute(entries);
      
      setState(() {
        _circadianContext = circadianContext;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getChronotypeDescription(String chronotype) {
    switch (chronotype) {
      case 'morning':
        return 'Morning person - most active before 11 AM';
      case 'evening':
        return 'Evening person - most active after 5 PM';
      case 'balanced':
        return 'Balanced rhythm - consistent activity throughout day';
      default:
        return 'Unknown';
    }
  }

  String _getWindowDescription(String window) {
    switch (window) {
      case 'morning':
        return '6 AM - 11 AM';
      case 'afternoon':
        return '11 AM - 5 PM';
      case 'evening':
        return '5 PM - 6 AM';
      default:
        return 'Unknown';
    }
  }

  String _getRhythmScoreDescription(double score) {
    if (score >= 0.55) {
      return 'Coherent - consistent daily patterns';
    } else if (score >= 0.45) {
      return 'Moderate - some variation in patterns';
    } else {
      return 'Fragmented - varied daily activity';
    }
  }

  List<String> _getAvailableChronotypes() {
    return [
      'Morning - Peak activity before 11 AM',
      'Balanced - Peak activity 11 AM - 5 PM',
      'Evening - Peak activity after 5 PM',
    ];
  }

  List<String> _getAvailableTimeWindows() {
    return [
      'Morning - 6 AM to 11 AM',
      'Afternoon - 11 AM to 5 PM',
      'Evening - 5 PM to 6 AM',
    ];
  }

  Color _getRhythmScoreColor(double score) {
    if (score >= 0.55) {
      return Colors.green;
    } else if (score >= 0.45) {
      return Colors.orange;
    } else {
      return Colors.red;
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

    final circadianContext = _circadianContext ?? CircadianContext(
      window: 'afternoon',
      chronotype: 'balanced',
      rhythmScore: 0.5,
    );

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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.wb_twilight,
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
                        'AURORA',
                        style: heading2Style(context),
                  ),
                  Text(
                      'Circadian Intelligence',
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

          // Current Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.purple.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Current Window: ${circadianContext.window.toUpperCase()}',
                        style: bodyStyle(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getWindowDescription(circadianContext.window),
                  style: bodyStyle(context).copyWith(
                    fontSize: 13,
                    color: kcPrimaryTextColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Chronotype
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Chronotype',
            value: circadianContext.chronotype,
            description: _getChronotypeDescription(circadianContext.chronotype),
          ),
          const SizedBox(height: 12),

          // Rhythm Score
          _buildRhythmScoreRow(circadianContext.rhythmScore),
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
                color: Colors.white.withOpacity(0.05),
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
            _buildAvailableChronotypesSection(circadianContext),
            const SizedBox(height: 12),
            _buildAvailableTimeWindowsSection(circadianContext),
          ],

          const SizedBox(height: 16),

          // Divider
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),

          // How it works
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'How AURORA Works',
                      style: bodyStyle(context).copyWith(
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
                  style: bodyStyle(context).copyWith(
                    fontSize: 11,
                    color: kcPrimaryTextColor.withOpacity(0.7),
                    height: 1.4,
                  ),
                  ),
                const SizedBox(height: 8),
                _buildActivationInfo(circadianContext),
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
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Need 8+ journal entries for reliable analysis',
                      style: bodyStyle(context).copyWith(
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
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    String? description,
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
              Row(
                children: [
                  Text(
                    label,
                    style: bodyStyle(context).copyWith(
                      fontSize: 11,
                      color: kcPrimaryTextColor.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      value.toUpperCase(),
                      style: bodyStyle(context).copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                ),
              ],
              ),
              if (description != null) ...[
                const SizedBox(height: 2),
                Text(
                  description,
                  style: bodyStyle(context).copyWith(
                    fontSize: 11,
                    color: kcPrimaryTextColor.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRhythmScoreRow(double score) {
    final color = _getRhythmScoreColor(score);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.show_chart,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                  backgroundColor: Colors.white.withOpacity(0.1),
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
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableChronotypesSection(CircadianContext circadianContext) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Chronotypes',
            style: bodyStyle(context).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: kcPrimaryTextColor.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          ..._getAvailableChronotypes().map((chronotype) {
            final isActive = chronotype.toLowerCase().startsWith(circadianContext.chronotype.toLowerCase());
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    isActive ? Icons.check_circle : Icons.circle_outlined,
                    size: 12,
                    color: isActive ? Colors.purple : kcPrimaryTextColor.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chronotype,
                      style: bodyStyle(context).copyWith(
                        fontSize: 11,
                        color: isActive ? Colors.purple : kcPrimaryTextColor.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAvailableTimeWindowsSection(CircadianContext circadianContext) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Time Windows',
            style: bodyStyle(context).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: kcPrimaryTextColor.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          ..._getAvailableTimeWindows().map((window) {
            final isActive = window.toLowerCase().startsWith(circadianContext.window.toLowerCase());
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    isActive ? Icons.check_circle : Icons.circle_outlined,
                    size: 12,
                    color: isActive ? Colors.purple : kcPrimaryTextColor.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      window,
                      style: bodyStyle(context).copyWith(
                        fontSize: 11,
                        color: isActive ? Colors.purple : kcPrimaryTextColor.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActivationInfo(CircadianContext circadianContext) {
    final isFragmented = circadianContext.isFragmented;
    final isEvening = circadianContext.isEvening;
    
    String activationText;
    Color activationColor;
    
    if (isFragmented && isEvening) {
      activationText = 'Evening + Fragmented: Commit blocks restricted, focus on Safeguard & Mirror';
      activationColor = Colors.orange;
    } else if (circadianContext.isMorning && circadianContext.isMorningPerson) {
      activationText = 'Morning + Morning Person: Enhanced alignment, clarity-focused prompts';
      activationColor = Colors.green;
    } else if (circadianContext.isEvening && circadianContext.isEveningPerson) {
      activationText = 'Evening + Evening Person: Enhanced alignment, reflection-focused prompts';
      activationColor = Colors.green;
    } else {
      activationText = 'Standard policy weights applied based on time window';
      activationColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: activationColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.tune,
            size: 14,
            color: activationColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              activationText,
              style: bodyStyle(context).copyWith(
                fontSize: 10,
                color: activationColor.withOpacity(0.9),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

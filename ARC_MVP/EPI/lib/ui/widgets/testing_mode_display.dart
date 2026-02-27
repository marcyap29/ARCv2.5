import 'package:flutter/material.dart';

/// Testing Mode Display Widget
/// 
/// Displays comprehensive analysis information for testing accounts:
/// - SENTINEL (crisis detection)
/// - RIVET (phase consistency)
/// - RESOLVE (recovery tracking)
/// - Intervention levels
/// - Processing paths
class TestingModeDisplay extends StatelessWidget {
  final Map<String, dynamic> analysisResult;
  
  const TestingModeDisplay({
    super.key,
    required this.analysisResult,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header
          Row(
            children: [
              const Icon(Icons.bug_report, color: Colors.orange),
              const SizedBox(width: 8),
              const Text(
                '🧪 TESTING MODE', 
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (analysisResult['detection_time_ms'] != null)
                Text(
                  'Detection: ${analysisResult['detection_time_ms']}ms',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
            ],
          ),
          
          const Divider(),
          
          // SENTINEL Section
          _buildSection(
            'SENTINEL (Internal Crisis Detection)',
            [
              _buildMetric(
                'Crisis Detected', 
                _getSentinelValue('crisis_detected') ? '🚨 YES' : '✓ No',
                color: _getSentinelValue('crisis_detected') ? Colors.red : Colors.green,
              ),
              _buildMetric(
                'Crisis Score', 
                '${_getSentinelValue('crisis_score') ?? 0}/100',
              ),
              _buildMetric(
                'Crisis Level', 
                _getSentinelValue('crisis_level') ?? 'NONE',
              ),
              _buildMetric(
                'Confidence', 
                '${_getSentinelValue('confidence') ?? 0}%',
              ),
              if (_getSentinelValue('detected_patterns') != null &&
                  (_getSentinelValue('detected_patterns') as List).isNotEmpty)
                _buildMetric(
                  'Patterns', 
                  (_getSentinelValue('detected_patterns') as List).join(', '),
                  fontSize: 10,
                ),
            ],
          ),
          
          // Intervention Level (NEW)
          if (_getInterventionLevel() > 0) ...[
            const Divider(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getInterventionColor(_getInterventionLevel()).shade100,
                border: Border.all(
                  color: _getInterventionColor(_getInterventionLevel()),
                  width: 2
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getInterventionIcon(_getInterventionLevel()),
                        color: _getInterventionColor(_getInterventionLevel()),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'INTERVENTION LEVEL ${_getInterventionLevel()}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getInterventionColor(_getInterventionLevel()).shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_getInterventionDescription(_getInterventionLevel())),
                  if (_isLimitedMode())
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '⚠️ Limited Mode Active - No AI reflections for 24 hours',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          
          const Divider(),
          
          // RIVET Section (if available)
          if (analysisResult['rivet'] != null) ...[
            _buildSection(
              'RIVET (Phase Consistency)',
              [
                if (analysisResult['phase'] != null)
                  _buildMetric(
                    'Current Phase', 
                    analysisResult['phase'],
                    color: _getPhaseColor(analysisResult['phase']),
                  ),
                if (analysisResult['rivet']?['align_score'] != null)
                  _buildMetric(
                    'ALIGN Score', 
                    '${analysisResult['rivet']['align_score']}/100',
                  ),
                if (analysisResult['rivet']?['trace_score'] != null)
                  _buildMetric(
                    'TRACE Score', 
                    '${analysisResult['rivet']['trace_score']}/100',
                  ),
              ],
            ),
            const Divider(),
          ],
          
          // RESOLVE Section
          if (analysisResult['resolve'] != null) ...[
            _buildSection(
              'RESOLVE (Recovery Tracking)',
              [
                _buildMetric(
                  'RESOLVE Score', 
                  '${analysisResult['resolve']?['resolve_score'] ?? 0}/100',
                ),
                _buildMetric(
                  'Recovery Phase', 
                  analysisResult['resolve']?['recovery_phase'] ?? 'N/A',
                  color: _getRecoveryPhaseColor(
                    analysisResult['resolve']?['recovery_phase'] ?? '',
                  ),
                ),
                _buildMetric(
                  'Days Stable', 
                  '${analysisResult['resolve']?['days_stable'] ?? 0}',
                ),
                _buildMetric(
                  'Cooldown Active', 
                  (analysisResult['resolve']?['cooldown_active'] ?? false) 
                      ? 'YES ✓' 
                      : 'No',
                ),
                _buildMetric(
                  'Trajectory', 
                  analysisResult['resolve']?['trajectory'] ?? 'N/A',
                ),
              ],
            ),
            const Divider(),
          ],
          
          // Processing Path
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.route, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Processing: ${analysisResult['processing_path'] ?? 'unknown'}'),
                const Spacer(),
                Text(
                  'Gemini: ${(analysisResult['used_gemini'] ?? false) ? "YES" : "NO"}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
  
  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
  
  Widget _buildMetric(String label, String value, {Color? color, double? fontSize}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: fontSize ?? 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: fontSize ?? 12,
                fontWeight: FontWeight.w500,
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  dynamic _getSentinelValue(String key) {
    final sentinel = analysisResult['sentinel'];
    if (sentinel is Map) {
      return sentinel[key];
    }
    return analysisResult[key]; // Fallback to top-level
  }
  
  int _getInterventionLevel() {
    return analysisResult['intervention_level'] ?? 0;
  }
  
  bool _isLimitedMode() {
    return analysisResult['limited_mode'] ?? false;
  }
  
  Color _getRecoveryPhaseColor(String phase) {
    switch (phase) {
      case 'acute': return Colors.red;
      case 'stabilizing': return Colors.orange;
      case 'recovering': return Colors.yellow.shade700;
      case 'resolved': return Colors.green;
      default: return Colors.grey;
    }
  }
  
  Color _getInterventionColor(int level) {
    switch (level) {
      case 1: return Colors.orange;
      case 2: return Colors.deepOrange;
      case 3: return Colors.red;
      default: return Colors.grey;
    }
  }
  
  IconData _getInterventionIcon(int level) {
    switch (level) {
      case 1: return Icons.warning;
      case 2: return Icons.error_outline;
      case 3: return Icons.block;
      default: return Icons.info;
    }
  }
  
  String _getInterventionDescription(int level) {
    switch (level) {
      case 1: return 'Alert sent + Crisis resources provided';
      case 2: return 'Resource acknowledgment required before continuing';
      case 3: return 'Limited mode - Journaling allowed, AI reflections paused for 24hrs';
      default: return '';
    }
  }
  
  Color _getPhaseColor(String? phase) {
    if (phase == null) return Colors.grey;
    // Add phase color mapping based on your phase system
    switch (phase.toLowerCase()) {
      case 'discovery': return Colors.blue;
      case 'recovery': return Colors.orange;
      case 'consolidation': return Colors.purple;
      case 'expansion': return Colors.green;
      case 'breakthrough': return Colors.teal;
      default: return Colors.grey;
    }
  }
}

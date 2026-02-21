// lib/ui/phase/sentinel_pattern_card.dart
// Individual pattern display widget for SENTINEL analysis

import 'package:flutter/material.dart';
import '../../prism/extractors/sentinel_risk_detector.dart';

class SentinelPatternCard extends StatefulWidget {
  final RiskPattern pattern;

  const SentinelPatternCard({
    super.key,
    required this.pattern,
  });

  @override
  State<SentinelPatternCard> createState() => _SentinelPatternCardState();
}

class _SentinelPatternCardState extends State<SentinelPatternCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Column(
        children: [
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _buildPatternIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getPatternTitle(widget.pattern.type),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getPatternDescription(widget.pattern.type),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildSeverityChip(),
                            const SizedBox(width: 8),
                            _buildConfidenceChip(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildPatternDetails(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternIcon() {
    final color = _getPatternColor(widget.pattern.type);
    final icon = _getPatternIcon(widget.pattern.type);
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }

  Widget _buildSeverityChip() {
    final severity = widget.pattern.severity;
    final color = _getSeverityColor(severity);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        'Severity: ${(severity * 100).round()}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildConfidenceChip() {
    // RiskPattern doesn't have confidence, use severity instead
    final severity = widget.pattern.severity;
    final color = _getSeverityColor(severity);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        'Severity: ${(severity * 100).round()}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPatternDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.pattern.description.isNotEmpty) ...[
          const Text(
            'Description:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.pattern.description,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.pattern.triggerKeywords.isNotEmpty) ...[
          const Text(
            'Trigger Keywords:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: widget.pattern.triggerKeywords.map((keyword) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                keyword,
                style: const TextStyle(fontSize: 12),
              ),
            )).toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.pattern.affectedDates.isNotEmpty) ...[
          const Text(
            'Affected Dates:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.pattern.affectedDates.length} entries between ${widget.pattern.affectedDates.first.toLocal().toString().split(' ')[0]} and ${widget.pattern.affectedDates.last.toLocal().toString().split(' ')[0]}',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ],
    );
  }

  Color _getPatternColor(String type) {
    switch (type.toLowerCase()) {
      case 'cluster':
        return Colors.blue;
      case 'persistent':
        return Colors.red;
      case 'escalating':
        return Colors.orange;
      case 'isolation':
        return Colors.purple;
      case 'hopelessness':
        return Colors.grey[700]!;
      case 'phase-mismatch':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getPatternIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cluster':
        return Icons.group_work;
      case 'persistent':
        return Icons.sentiment_very_dissatisfied;
      case 'escalating':
        return Icons.trending_up;
      case 'isolation':
        return Icons.person_off;
      case 'hopelessness':
        return Icons.help_outline;
      case 'phase-mismatch':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  String _getPatternTitle(String type) {
    switch (type.toLowerCase()) {
      case 'cluster':
        return 'Clustering Pattern';
      case 'persistent':
        return 'Persistent Distress';
      case 'escalating':
        return 'Escalating Pattern';
      case 'isolation':
        return 'Isolation Indicators';
      case 'hopelessness':
        return 'Hopelessness Signals';
      case 'phase-mismatch':
        return 'Phase Mismatch';
      default:
        return 'Risk Pattern';
    }
  }

  String _getPatternDescription(String type) {
    switch (type.toLowerCase()) {
      case 'cluster':
        return 'Similar emotional patterns occurring in clusters over time';
      case 'persistent':
        return 'Sustained negative emotional states across multiple entries';
      case 'escalating':
        return 'Increasing intensity of negative patterns over time';
      case 'isolation':
        return 'Signs of social withdrawal or isolation in your entries';
      case 'hopelessness':
        return 'Indicators of hopelessness or lack of future orientation';
      case 'phase-mismatch':
        return 'Emotional patterns that don\'t align with current phase';
      default:
        return 'Concerning pattern detected in your emotional data';
    }
  }

  Color _getSeverityColor(double severity) {
    if (severity < 0.3) return Colors.green;
    if (severity < 0.6) return Colors.orange;
    return Colors.red;
  }

}

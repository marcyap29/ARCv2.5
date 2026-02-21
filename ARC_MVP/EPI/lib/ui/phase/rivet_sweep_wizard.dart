// lib/ui/phase/rivet_sweep_wizard.dart
// RIVET Sweep Wizard UI for segmented phase backfill

import 'package:flutter/material.dart';
import 'package:my_app/models/phase_models.dart';
import '../../services/rivet_sweep_service.dart';

class RivetSweepWizard extends StatefulWidget {
  final RivetSweepResult sweepResult;
  final Function(List<PhaseSegmentProposal> approved, Map<String, PhaseLabel> overrides)? onApprove;
  final VoidCallback? onSkip;

  const RivetSweepWizard({
    super.key,
    required this.sweepResult,
    this.onApprove,
    this.onSkip,
  });

  @override
  State<RivetSweepWizard> createState() => _RivetSweepWizardState();
}

class _RivetSweepWizardState extends State<RivetSweepWizard> {
  final Set<String> _approvedSegments = {};
  final Map<String, PhaseLabel> _manualOverrides = {};

  @override
  void initState() {
    super.initState();
    
    // Debug: Log segment counts
    print('DEBUG: RIVET Sweep Wizard - Auto-assign: ${widget.sweepResult.autoAssign.length}');
    print('DEBUG: RIVET Sweep Wizard - Review: ${widget.sweepResult.review.length}');
    print('DEBUG: RIVET Sweep Wizard - Low confidence: ${widget.sweepResult.lowConfidence.length}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phase Analysis'),
        actions: [
          TextButton(
            onPressed: widget.onSkip,
            child: const Text('Skip for now'),
          ),
        ],
      ),
      body: _buildReviewTab(theme),
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }


  Widget _buildPhaseChip(PhaseLabel label, ThemeData theme) {
    final colors = {
      PhaseLabel.discovery: Colors.blue,
      PhaseLabel.expansion: Colors.green,
      PhaseLabel.transition: Colors.orange,
      PhaseLabel.consolidation: Colors.purple,
      PhaseLabel.recovery: Colors.red,
      PhaseLabel.breakthrough: Colors.amber,
    };
    
    return Chip(
      label: Text(
        label.name.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      backgroundColor: colors[label]?.withOpacity(0.2),
      side: BorderSide(color: colors[label] ?? Colors.grey),
    );
  }

  Widget _buildReviewTab(ThemeData theme) {
    // Include all segments that need review OR all segments if review is empty (for manual review)
    final reviewSegments = [
      ...widget.sweepResult.review,
      ...widget.sweepResult.lowConfidence,
    ];
    
    // If no segments need review, show all segments for manual review
    final allSegments = reviewSegments.isEmpty
        ? [
            ...widget.sweepResult.autoAssign,
            ...widget.sweepResult.review,
            ...widget.sweepResult.lowConfidence,
          ]
        : reviewSegments;
    
    if (allSegments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No Segments Found',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'No phase segments were detected in your journal entries.\n\n'
                'Make sure you have enough entries (minimum 5) and run Phase Analysis again.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Calculate average confidence for header
    final avgConfidence = allSegments.isEmpty
        ? 0.0
        : allSegments.map((s) => s.confidence).reduce((a, b) => a + b) / allSegments.length;
    
    // Show header message based on whether review was empty
    final showAllSegmentsHeader = reviewSegments.isEmpty && widget.sweepResult.autoAssign.isNotEmpty;
    final headerMessage = showAllSegmentsHeader
        ? 'All Review Segments Have High Confidence (${(avgConfidence * 100).toStringAsFixed(0)}%). Review them before approving.'
        : 'Review the segments below and approve them.';
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Colors.blue[50],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      headerMessage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Auto-Assign button
              if (widget.sweepResult.autoAssign.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _autoFinalize(widget.sweepResult.autoAssign),
                    icon: const Icon(Icons.flash_on, size: 24),
                    label: Text(
                      'Auto-Assign & Apply (${widget.sweepResult.autoAssign.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 4.0),
                child: ElevatedButton.icon(
                  onPressed: () => _autoFinalize(allSegments),
                  icon: const Icon(Icons.approval, size: 24),
                  label: const Text(
                    'Approve All & Apply',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Prefer to inspect each phase segment? Scroll down and review them manually before tapping Apply Changes.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.blueGrey),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: allSegments.length,
            itemBuilder: (context, index) {
              final segment = allSegments[index];
              return _buildDetailedSegmentCard(segment, theme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedSegmentCard(PhaseSegmentProposal segment, ThemeData theme) {
    final isApproved = _approvedSegments.contains(_getSegmentId(segment));
    final manualOverride = _manualOverrides[_getSegmentId(segment)];
    final displayLabel = manualOverride ?? segment.proposedLabel;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildPhaseChip(displayLabel, theme),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_formatDate(segment.start)} - ${_formatDate(segment.end)}',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(segment.confidence * 100).toInt()}% confidence',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: segment.confidence >= 0.7 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Phase selection
            Text(
              'Phase Label:',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: PhaseLabel.values.map((label) {
                final isSelected = displayLabel == label;
                return FilterChip(
                  label: Text(label.name.toUpperCase()),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _manualOverrides[_getSegmentId(segment)] = label;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Summary and keywords
            if (segment.summary != null) ...[
              Text(
                'Summary:',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(segment.summary!),
              const SizedBox(height: 16),
            ],
            
            if (segment.topKeywords.isNotEmpty) ...[
              Text(
                'Keywords:',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: segment.topKeywords.map((keyword) =>
                  Chip(
                    label: Text(keyword),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ).toList(),
              ),
              const SizedBox(height: 16),
            ],
            
            // Approval checkbox
            Row(
              children: [
                Checkbox(
                  value: isApproved,
                  onChanged: (value) => _toggleSegmentApproval(segment),
                ),
                const Text('Approve this segment'),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildBottomBar(ThemeData theme) {
    final totalApproved = _approvedSegments.length;
    final totalSegments = widget.sweepResult.autoAssign.length + 
                         widget.sweepResult.review.length + 
                         widget.sweepResult.lowConfidence.length;
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Text('$totalApproved of $totalSegments approved'),
          const Spacer(),
          if (totalApproved > 0)
            ElevatedButton(
              onPressed: _applyApprovals,
              child: const Text('Apply Changes'),
            ),
        ],
      ),
    );
  }

  String _getSegmentId(PhaseSegmentProposal segment) {
    return '${segment.start.millisecondsSinceEpoch}_${segment.end.millisecondsSinceEpoch}';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _toggleSegmentApproval(PhaseSegmentProposal segment) {
    setState(() {
      final segmentId = _getSegmentId(segment);
      if (_approvedSegments.contains(segmentId)) {
        _approvedSegments.remove(segmentId);
      } else {
        _approvedSegments.add(segmentId);
      }
    });
  }

  void _applyApprovals() {
    // Collect all approved segment proposals
    final allSegments = [
      ...widget.sweepResult.autoAssign,
      ...widget.sweepResult.review,
      ...widget.sweepResult.lowConfidence,
    ];

    // Filter to only approved segments
    final approvedProposals = allSegments.where((segment) {
      return _approvedSegments.contains(_getSegmentId(segment));
    }).toList();

    // Call the onApprove callback with approved segments and manual overrides
    widget.onApprove?.call(approvedProposals, _manualOverrides);
  }
  void _autoFinalize(List<PhaseSegmentProposal> segments) {
    setState(() {
      for (final segment in segments) {
        _approvedSegments.add(_getSegmentId(segment));
      }
    });
    _applyApprovals();
  }
}

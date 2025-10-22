// lib/ui/phase/rivet_sweep_wizard.dart
// RIVET Sweep Wizard UI for segmented phase backfill

import 'package:flutter/material.dart';
import '../../models/phase_models.dart';
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

class _RivetSweepWizardState extends State<RivetSweepWizard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _approvedSegments = {};
  final Map<String, PhaseLabel> _manualOverrides = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phase Analysis'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Review', icon: Icon(Icons.edit)),
            Tab(text: 'Timeline', icon: Icon(Icons.timeline)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: widget.onSkip,
            child: const Text('Skip for now'),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(theme),
          _buildReviewTab(theme),
          _buildTimelineTab(theme),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }

  Widget _buildOverviewTab(ThemeData theme) {
    final totalSegments = widget.sweepResult.autoAssign.length + 
                         widget.sweepResult.review.length + 
                         widget.sweepResult.lowConfidence.length;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Phase Analysis Complete',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Rivet found $totalSegments segments in your journal timeline. '
                    'You can approve them in bulk or review specific segments.',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Auto-assign section
          if (widget.sweepResult.autoAssign.isNotEmpty) ...[
            _buildSegmentSection(
              'Auto-Assign (${widget.sweepResult.autoAssign.length})',
              widget.sweepResult.autoAssign,
              theme,
              isAutoAssign: true,
            ),
            const SizedBox(height: 16),
          ],
          
          // Review section
          if (widget.sweepResult.review.isNotEmpty) ...[
            _buildSegmentSection(
              'Review Needed (${widget.sweepResult.review.length})',
              widget.sweepResult.review,
              theme,
              isAutoAssign: false,
            ),
            const SizedBox(height: 16),
          ],
          
          // Low confidence section
          if (widget.sweepResult.lowConfidence.isNotEmpty) ...[
            _buildSegmentSection(
              'Low Confidence (${widget.sweepResult.lowConfidence.length})',
              widget.sweepResult.lowConfidence,
              theme,
              isAutoAssign: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentSection(
    String title,
    List<PhaseSegmentProposal> segments,
    ThemeData theme, {
    required bool isAutoAssign,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAutoAssign ? Icons.check_circle : Icons.help_outline,
                  color: isAutoAssign ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (isAutoAssign)
                  ElevatedButton(
                    onPressed: () => _approveAllSegments(segments),
                    child: const Text('Approve All'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...segments.take(3).map((segment) => _buildSegmentCard(segment, theme)),
            if (segments.length > 3)
              TextButton(
                onPressed: () => _tabController.animateTo(1), // Switch to review tab
                child: Text('View all ${segments.length} segments'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentCard(PhaseSegmentProposal segment, ThemeData theme) {
    final isApproved = _approvedSegments.contains(_getSegmentId(segment));
    final manualOverride = _manualOverrides[_getSegmentId(segment)];
    final displayLabel = manualOverride ?? segment.proposedLabel;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildPhaseChip(displayLabel, theme),
                const SizedBox(width: 8),
                Text(
                  '${_formatDate(segment.start)} - ${_formatDate(segment.end)}',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  '${(segment.confidence * 100).toInt()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: segment.confidence >= 0.7 ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Checkbox(
                  value: isApproved,
                  onChanged: (value) => _toggleSegmentApproval(segment),
                ),
              ],
            ),
            if (segment.summary != null) ...[
              const SizedBox(height: 8),
              Text(
                segment.summary!,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (segment.topKeywords.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: segment.topKeywords.take(3).map((keyword) =>
                  Chip(
                    label: Text(keyword),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ).toList(),
              ),
            ],
          ],
        ),
      ),
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
    final reviewSegments = [
      ...widget.sweepResult.review,
      ...widget.sweepResult.lowConfidence,
    ];
    
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: reviewSegments.length,
      itemBuilder: (context, index) {
        final segment = reviewSegments[index];
        return _buildDetailedSegmentCard(segment, theme);
      },
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
                Text(
                  '${_formatDate(segment.start)} - ${_formatDate(segment.end)}',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
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

  Widget _buildTimelineTab(ThemeData theme) {
    // This would show a visual timeline with phase bands
    return const Center(
      child: Text('Timeline visualization coming soon'),
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

  void _approveAllSegments(List<PhaseSegmentProposal> segments) {
    setState(() {
      for (final segment in segments) {
        _approvedSegments.add(_getSegmentId(segment));
      }
    });
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
}

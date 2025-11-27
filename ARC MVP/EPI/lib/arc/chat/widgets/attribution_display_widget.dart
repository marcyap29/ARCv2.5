// lib/lumara/widgets/attribution_display_widget.dart
// Widget for displaying memory attribution traces in chat responses

import 'package:flutter/material.dart';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';

/// Widget that displays memory attribution traces for a response
class AttributionDisplayWidget extends StatefulWidget {
  final List<AttributionTrace> traces;
  final String responseId;
  final bool showDetailedView;
  final VoidCallback? onToggleDetailed;
  final Function(AttributionTrace, double)? onWeightChanged;
  final Function(AttributionTrace)? onExcludeMemory;

  const AttributionDisplayWidget({
    super.key,
    required this.traces,
    required this.responseId,
    this.showDetailedView = true, // Default to expanded to show all references
    this.onToggleDetailed,
    this.onWeightChanged,
    this.onExcludeMemory,
  });

  @override
  State<AttributionDisplayWidget> createState() => _AttributionDisplayWidgetState();
}

class _AttributionDisplayWidgetState extends State<AttributionDisplayWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    // Initialize expanded state from widget parameter, default to true to show all references
    _isExpanded = widget.showDetailedView;
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Log trace count
    print('AttributionDisplayWidget: Building with ${widget.traces.length} traces');
    if (widget.traces.isEmpty) {
      print('AttributionDisplayWidget: No traces, returning empty widget');
      return const SizedBox.shrink();
    }
    
    // Debug: Log first trace details
    if (widget.traces.isNotEmpty) {
      final firstTrace = widget.traces.first;
      print('AttributionDisplayWidget: First trace - nodeRef: ${firstTrace.nodeRef}, excerpt: ${firstTrace.excerpt?.substring(0, firstTrace.excerpt!.length > 50 ? 50 : firstTrace.excerpt!.length)}...');
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: Card(
        elevation: 1,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with summary
            _buildHeader(),
            
            // Expanded details
            if (_isExpanded) _buildDetailedView(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final totalTraces = widget.traces.length;
    final avgConfidence = widget.traces.isNotEmpty
        ? widget.traces.map((t) => t.confidence).reduce((a, b) => a + b) / widget.traces.length
        : 0.0;

    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
        widget.onToggleDetailed?.call();
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.psychology,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Memory Attribution ($totalTraces memories, ${(avgConfidence * 100).toStringAsFixed(0)}% confidence)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Memory traces list with height constraint to prevent overflow
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 300, // Limit height to prevent RenderFlex overflow
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: widget.traces.length,
              itemBuilder: (context, index) => _buildTraceItem(widget.traces[index]),
            ),
          ),

          const SizedBox(height: 8),

          // Summary statistics
          _buildSummaryStats(),
        ],
      ),
    );
  }

  Widget _buildTraceItem(AttributionTrace trace) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Memory reference and relation
          Row(
            children: [
              Icon(
                _getRelationIcon(trace.relation),
                size: 16,
                color: _getRelationColor(trace.relation),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Memory: ${trace.nodeRef}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(trace.confidence * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getConfidenceColor(trace.confidence),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 4),
          
          // Relation type
          Text(
            'Relation: ${_formatRelation(trace.relation)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          
          // Excerpt (specific text/entry) - NEW: Direct attribution
          if (trace.excerpt != null && trace.excerpt!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Source:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trace.excerpt!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Phase context (if available)
          if (trace.phaseContext != null && trace.phaseContext!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 12,
                  color: _getPhaseColor(trace.phaseContext!),
                ),
                const SizedBox(width: 4),
                Text(
                  'Phase: ${trace.phaseContext}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _getPhaseColor(trace.phaseContext!),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          
          // Reasoning (if available)
          if (trace.reasoning != null) ...[
            const SizedBox(height: 4),
            Text(
              'Reasoning: ${trace.reasoning}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          
          const SizedBox(height: 8),
          
          // Controls
          Row(
            children: [
              // Weight adjustment slider
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weight: ${(trace.confidence * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Slider(
                      value: trace.confidence,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: widget.onWeightChanged != null
                          ? (value) => widget.onWeightChanged!(trace, value)
                          : null,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Exclude button
              IconButton(
                onPressed: widget.onExcludeMemory != null
                    ? () => widget.onExcludeMemory!(trace)
                    : null,
                icon: const Icon(Icons.block, size: 16),
                tooltip: 'Exclude this memory',
                style: IconButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats() {
    final relationCounts = <String, int>{};
    final phaseCounts = <String, int>{};
    for (final trace in widget.traces) {
      relationCounts[trace.relation] = (relationCounts[trace.relation] ?? 0) + 1;
      if (trace.phaseContext != null && trace.phaseContext!.isNotEmpty) {
        phaseCounts[trace.phaseContext!] = (phaseCounts[trace.phaseContext!] ?? 0) + 1;
      }
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          // Relation counts
          ...relationCounts.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Icon(
                  _getRelationIcon(entry.key),
                  size: 12,
                  color: _getRelationColor(entry.key),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_formatRelation(entry.key)}: ${entry.value}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          )),
          // Phase counts (if any)
          if (phaseCounts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Phases',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            ...phaseCounts.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 12,
                    color: _getPhaseColor(entry.key),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.key}: ${entry.value}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _getPhaseColor(entry.key),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  IconData _getRelationIcon(String relation) {
    switch (relation.toLowerCase()) {
      case 'supports':
        return Icons.thumb_up;
      case 'contradicts':
        return Icons.thumb_down;
      case 'references':
        return Icons.link;
      case 'builds_on':
        return Icons.trending_up;
      case 'contextualizes':
        return Icons.lightbulb;
      default:
        return Icons.psychology;
    }
  }

  Color _getRelationColor(String relation) {
    switch (relation.toLowerCase()) {
      case 'supports':
        return Colors.green;
      case 'contradicts':
        return Colors.red;
      case 'references':
        return Colors.blue;
      case 'builds_on':
        return Colors.orange;
      case 'contextualizes':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  String _formatRelation(String relation) {
    return relation.replaceAll('_', ' ').split(' ').map((word) => 
      word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : word
    ).join(' ');
  }

  Color _getPhaseColor(String phase) {
    switch (phase.toLowerCase()) {
      case 'discovery':
        return Colors.blue;
      case 'expansion':
        return Colors.green;
      case 'transition':
        return Colors.orange;
      case 'consolidation':
        return Colors.purple;
      case 'recovery':
        return Colors.teal;
      case 'breakthrough':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}

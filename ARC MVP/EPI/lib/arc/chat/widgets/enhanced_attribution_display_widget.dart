// lib/arc/chat/widgets/enhanced_attribution_display_widget.dart
// Enhanced attribution display widget supporting multiple source types and filtering

import 'package:flutter/material.dart';
import 'package:my_app/shared/widgets/lumara_icon.dart';
import '../../../mira/memory/enhanced_attribution_schema.dart';

/// Enhanced widget for displaying multi-source memory attributions
class EnhancedAttributionDisplayWidget extends StatefulWidget {
  final EnhancedResponseTrace responseTrace;
  final String responseId;
  final bool showDetailedView;
  final VoidCallback? onToggleDetailed;
  final Function(EnhancedAttributionTrace, double)? onWeightChanged;
  final Function(EnhancedAttributionTrace)? onExcludeMemory;
  final VoidCallback? onRequestExplanation;

  const EnhancedAttributionDisplayWidget({
    super.key,
    required this.responseTrace,
    required this.responseId,
    this.showDetailedView = true, // Default to expanded to show all references
    this.onToggleDetailed,
    this.onWeightChanged,
    this.onExcludeMemory,
    this.onRequestExplanation,
  });

  @override
  State<EnhancedAttributionDisplayWidget> createState() =>
      _EnhancedAttributionDisplayWidgetState();
}

class _EnhancedAttributionDisplayWidgetState
    extends State<EnhancedAttributionDisplayWidget> {
  late bool _isExpanded;
  SourceType? _selectedSourceFilter;
  bool _showCrossReferences = true;
  bool _showConfidenceScores = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.showDetailedView;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.responseTrace.traces.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: Card(
        elevation: 1,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Enhanced header with summary
            _buildEnhancedHeader(),

            // Expanded details with filtering
            if (_isExpanded) _buildEnhancedDetailedView(),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedHeader() {
    final summary = widget.responseTrace.summary;
    final totalTraces = summary.totalAttributions;
    final sourceTypes = summary.sourceTypeBreakdown.keys.length;

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
            // LUMARA icon for attribution
            LumaraIcon(
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),

            // Enhanced summary text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Memory Sources ($totalTraces from $sourceTypes types)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Source type indicators
                  _buildSourceTypeIndicators(summary),
                ],
              ),
            ),

            // Explanation button
            if (widget.onRequestExplanation != null)
              IconButton(
                icon: const Icon(Icons.help_outline, size: 16),
                tooltip: 'Explain attribution sources',
                onPressed: widget.onRequestExplanation,
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(24, 24),
                ),
              ),

            // Expand/collapse icon
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

  Widget _buildSourceTypeIndicators(AttributionSummary summary) {
    return Wrap(
      spacing: 6,
      children: summary.sourceTypeBreakdown.entries.map((entry) {
        final sourceType = entry.key;
        final count = entry.value;
        final icon = _getSourceTypeIcon(sourceType);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _getSourceTypeColor(sourceType).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _getSourceTypeColor(sourceType).withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 10)),
              const SizedBox(width: 2),
              Text(
                count.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _getSourceTypeColor(sourceType),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEnhancedDetailedView() {
    final filteredTraces = _getFilteredTraces();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Controls row
          _buildControlsRow(),

          const SizedBox(height: 8),

          // Filtered traces list with height constraint
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 400, // Increased height for enhanced content
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: filteredTraces.length,
              itemBuilder: (context, index) => _buildEnhancedTraceItem(filteredTraces[index]),
            ),
          ),

          const SizedBox(height: 12),

          // Cross-references section
          if (_showCrossReferences && widget.responseTrace.summary.crossReferences.isNotEmpty)
            _buildCrossReferencesSection(),

          // Enhanced summary statistics
          _buildEnhancedSummaryStats(),
        ],
      ),
    );
  }

  Widget _buildControlsRow() {
    return Row(
      children: [
        // Source type filter
        Expanded(
          child: DropdownButton<SourceType?>(
            value: _selectedSourceFilter,
            hint: const Text('All Sources'),
            isExpanded: true,
            onChanged: (SourceType? newFilter) {
              setState(() {
                _selectedSourceFilter = newFilter;
              });
            },
            items: [
              const DropdownMenuItem<SourceType?>(
                value: null,
                child: Text('All Sources'),
              ),
              ...widget.responseTrace.summary.sourceTypeBreakdown.keys.map(
                (sourceType) => DropdownMenuItem<SourceType?>(
                  value: sourceType,
                  child: Row(
                    children: [
                      Text(_getSourceTypeIcon(sourceType)),
                      const SizedBox(width: 8),
                      Text(_getSourceTypeDescription(sourceType)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Toggle confidence scores
        IconButton(
          icon: Icon(
            _showConfidenceScores ? Icons.analytics : Icons.analytics_outlined,
            size: 20,
          ),
          tooltip: _showConfidenceScores ? 'Hide confidence scores' : 'Show confidence scores',
          onPressed: () {
            setState(() {
              _showConfidenceScores = !_showConfidenceScores;
            });
          },
        ),

        // Toggle cross-references
        IconButton(
          icon: Icon(
            _showCrossReferences ? Icons.link : Icons.link_off,
            size: 20,
          ),
          tooltip: _showCrossReferences ? 'Hide cross-references' : 'Show cross-references',
          onPressed: () {
            setState(() {
              _showCrossReferences = !_showCrossReferences;
            });
          },
        ),
      ],
    );
  }

  Widget _buildEnhancedTraceItem(EnhancedAttributionTrace trace) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getSourceTypeColor(trace.sourceType).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced header with source type and confidence
          _buildTraceHeader(trace),

          const SizedBox(height: 8),

          // Source-specific metadata
          _buildSourceMetadata(trace),

          // Excerpt section
          if (trace.excerpt != null && trace.excerpt!.isNotEmpty)
            _buildExcerptSection(trace),

          // Cross-references for this trace
          if (_showCrossReferences && trace.crossReferences.isNotEmpty)
            _buildTraceCrossReferences(trace),

          // Controls (weight adjustment, exclude)
          _buildTraceControls(trace),
        ],
      ),
    );
  }

  Widget _buildTraceHeader(EnhancedAttributionTrace trace) {
    return Row(
      children: [
        // Source type icon
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _getSourceTypeColor(trace.sourceType).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _getSourceTypeIcon(trace.sourceType),
            style: const TextStyle(fontSize: 14),
          ),
        ),

        const SizedBox(width: 8),

        // Source type and node reference
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getSourceTypeDescription(trace.sourceType),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _getSourceTypeColor(trace.sourceType),
                ),
              ),
              Text(
                'Ref: ${_formatNodeRef(trace.nodeRef)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),

        // Confidence badge
        if (_showConfidenceScores)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getConfidenceColor(trace.confidence).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getConfidenceColor(trace.confidence).withOpacity(0.3),
              ),
            ),
            child: Text(
              '${(trace.confidence * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: _getConfidenceColor(trace.confidence),
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSourceMetadata(EnhancedAttributionTrace trace) {
    if (trace.sourceMetadata.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Context',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          ...trace.sourceMetadata.entries.take(3).map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Text(
                  '${_capitalizeFirst(entry.key)}:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    entry.value.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildExcerptSection(EnhancedAttributionTrace trace) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote,
                size: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Source Content',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            trace.excerpt!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTraceCrossReferences(EnhancedAttributionTrace trace) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Related Content',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          ...trace.crossReferences.take(2).map((ref) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Text(_getSourceTypeIcon(ref.targetType), style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ref.description ?? 'Related ${_getSourceTypeDescription(ref.targetType)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTraceControls(EnhancedAttributionTrace trace) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          // Weight adjustment slider
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Influence: ${(trace.contributionWeight * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                  ),
                ),
                SizedBox(
                  height: 20,
                  child: Slider(
                    value: trace.contributionWeight,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    onChanged: widget.onWeightChanged != null
                        ? (value) => widget.onWeightChanged!(trace, value)
                        : null,
                  ),
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
            icon: const Icon(Icons.block, size: 14),
            tooltip: 'Exclude from future responses',
            style: IconButton.styleFrom(
              foregroundColor: Colors.red,
              padding: EdgeInsets.zero,
              minimumSize: const Size(24, 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrossReferencesSection() {
    final crossRefs = widget.responseTrace.summary.crossReferences;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.link,
                size: 14,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 4),
              Text(
                'Cross-References (${crossRefs.length})',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...crossRefs.take(3).map((ref) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                Text(_getSourceTypeIcon(ref.targetType), style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ref.description ?? 'Related ${_getSourceTypeDescription(ref.targetType)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(ref.strength * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )),
          if (crossRefs.length > 3)
            Text(
              '... and ${crossRefs.length - 3} more',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnhancedSummaryStats() {
    final summary = widget.responseTrace.summary;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Response Summary',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),

          // Confidence level
          Row(
            children: [
              Icon(
                Icons.analytics,
                size: 12,
                color: _getConfidenceColor(summary.overallConfidence),
              ),
              const SizedBox(width: 4),
              Text(
                'Overall Confidence: ${ConfidenceLevel.fromScore(summary.overallConfidence).label}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Source diversity
          Row(
            children: [
              const Icon(Icons.diversity_3, size: 12),
              const SizedBox(width: 4),
              Text(
                'Source Diversity: ${summary.sourceTypeBreakdown.length} types',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Primary sources
          if (summary.primarySources.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.star, size: 12),
                const SizedBox(width: 4),
                Text(
                  'High-confidence sources: ${summary.primarySources.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Helper methods
  List<EnhancedAttributionTrace> _getFilteredTraces() {
    var traces = widget.responseTrace.traces;

    if (_selectedSourceFilter != null) {
      traces = traces.where((trace) => trace.sourceType == _selectedSourceFilter).toList();
    }

    // Sort by confidence (highest first)
    traces.sort((a, b) => b.confidence.compareTo(a.confidence));

    return traces;
  }

  String _getSourceTypeIcon(SourceType sourceType) {
    switch (sourceType) {
      case SourceType.journalEntry: return '📝';
      case SourceType.chatMessage:
      case SourceType.chatSession: return '💬';
      case SourceType.photo:
      case SourceType.photoOcr: return '📷';
      case SourceType.audio:
      case SourceType.audioTranscript: return '🎵';
      case SourceType.video:
      case SourceType.videoTranscript: return '🎥';
      case SourceType.phaseRegime: return '📊';
      case SourceType.emotionTracking: return '😊';
      case SourceType.keywordSubmission: return '🏷️';
      case SourceType.lumaraResponse: return '🤖';
      case SourceType.insight: return '💡';
      case SourceType.summary: return '📋';
      case SourceType.relatedContent: return '🔗';
      case SourceType.previousMention: return '👁️';
      case SourceType.webReference: return '🌐';
      case SourceType.bookReference: return '📚';
      case SourceType.documentUpload: return '📄';
    }
  }

  String _getSourceTypeDescription(SourceType sourceType) {
    return EnhancedAttributionTrace(
      nodeRef: '',
      sourceType: sourceType,
      relation: '',
      confidence: 0.0,
      timestamp: DateTime.now(),
    ).getSourceTypeDescription();
  }

  Color _getSourceTypeColor(SourceType sourceType) {
    switch (sourceType) {
      case SourceType.journalEntry: return Colors.blue;
      case SourceType.chatMessage:
      case SourceType.chatSession: return Colors.green;
      case SourceType.photo:
      case SourceType.photoOcr: return Colors.purple;
      case SourceType.audio:
      case SourceType.audioTranscript: return Colors.orange;
      case SourceType.video:
      case SourceType.videoTranscript: return Colors.red;
      case SourceType.phaseRegime: return Colors.teal;
      case SourceType.emotionTracking: return Colors.pink;
      case SourceType.lumaraResponse: return Colors.indigo;
      case SourceType.insight: return Colors.amber;
      case SourceType.webReference: return Colors.blue;
      case SourceType.bookReference: return Colors.brown;
      case SourceType.documentUpload: return Colors.grey[700]!;
      default: return Colors.grey;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    if (confidence >= 0.4) return Colors.yellow[800]!;
    return Colors.red;
  }

  String _formatNodeRef(String nodeRef) {
    if (nodeRef.length > 20) {
      return '${nodeRef.substring(0, 8)}...${nodeRef.substring(nodeRef.length - 8)}';
    }
    return nodeRef;
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
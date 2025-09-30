// lib/lumara/widgets/memory_influence_controls.dart
// Widget for adjusting memory influence and weights in real-time

import 'package:flutter/material.dart';
import '../../mira/memory/enhanced_memory_schema.dart';

/// Widget for controlling memory influence in real-time
class MemoryInfluenceControls extends StatefulWidget {
  final List<AttributionTrace> traces;
  final Function(AttributionTrace, double)? onWeightChanged;
  final Function(AttributionTrace)? onExcludeMemory;
  final Function(AttributionTrace)? onIncludeMemory;
  final VoidCallback? onResetWeights;
  final bool showAdvancedControls;

  const MemoryInfluenceControls({
    super.key,
    required this.traces,
    this.onWeightChanged,
    this.onExcludeMemory,
    this.onIncludeMemory,
    this.onResetWeights,
    this.showAdvancedControls = false,
  });

  @override
  State<MemoryInfluenceControls> createState() => _MemoryInfluenceControlsState();
}

class _MemoryInfluenceControlsState extends State<MemoryInfluenceControls> {
  final Map<String, double> _weightOverrides = {};
  final Set<String> _excludedMemories = {};

  @override
  void initState() {
    super.initState();
    // Initialize with current weights
    for (final trace in widget.traces) {
      _weightOverrides[trace.nodeRef] = trace.confidence;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.traces.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            
            if (widget.showAdvancedControls) ...[
              _buildAdvancedControls(),
              const SizedBox(height: 16),
            ],
            
            _buildMemoryControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final activeMemories = widget.traces.where((t) => !_excludedMemories.contains(t.nodeRef)).length;
    final totalMemories = widget.traces.length;
    final avgWeight = _calculateAverageWeight();

    return Row(
      children: [
        Icon(
          Icons.tune,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Memory Influence Controls',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '$activeMemories of $totalMemories memories active (${(avgWeight * 100).toStringAsFixed(0)}% avg weight)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (widget.onResetWeights != null)
          IconButton(
            onPressed: _resetWeights,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to original weights',
          ),
      ],
    );
  }

  Widget _buildAdvancedControls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickActionButton(
                'Exclude All',
                Icons.block,
                Colors.red,
                _excludeAllMemories,
              ),
              _buildQuickActionButton(
                'Include All',
                Icons.check_circle,
                Colors.green,
                _includeAllMemories,
              ),
              _buildQuickActionButton(
                'Boost All',
                Icons.trending_up,
                Colors.blue,
                _boostAllMemories,
              ),
              _buildQuickActionButton(
                'Reduce All',
                Icons.trending_down,
                Colors.orange,
                _reduceAllMemories,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildMemoryControls() {
    return Column(
      children: widget.traces.map((trace) => _buildMemoryControl(trace)).toList(),
    );
  }

  Widget _buildMemoryControl(AttributionTrace trace) {
    final isExcluded = _excludedMemories.contains(trace.nodeRef);
    final currentWeight = _weightOverrides[trace.nodeRef] ?? trace.confidence;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExcluded 
            ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.3)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isExcluded 
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Memory header
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isExcluded 
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : null,
                  ),
                ),
              ),
              // Exclude/Include toggle
              IconButton(
                onPressed: () => _toggleMemoryExclusion(trace),
                icon: Icon(
                  isExcluded ? Icons.check_circle : Icons.block,
                  size: 20,
                ),
                tooltip: isExcluded ? 'Include memory' : 'Exclude memory',
                style: IconButton.styleFrom(
                  foregroundColor: isExcluded ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          
          // Relation and reasoning
          Text(
            'Relation: ${_formatRelation(trace.relation)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          
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
          
          if (!isExcluded) ...[
            const SizedBox(height: 12),
            
            // Weight control
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weight: ${(currentWeight * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Slider(
                        value: currentWeight,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        onChanged: (value) => _updateWeight(trace, value),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Quick weight buttons
                Column(
                  children: [
                    IconButton(
                      onPressed: () => _updateWeight(trace, (currentWeight + 0.1).clamp(0.0, 1.0)),
                      icon: const Icon(Icons.add, size: 16),
                      tooltip: 'Increase weight',
                    ),
                    IconButton(
                      onPressed: () => _updateWeight(trace, (currentWeight - 0.1).clamp(0.0, 1.0)),
                      icon: const Icon(Icons.remove, size: 16),
                      tooltip: 'Decrease weight',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _updateWeight(AttributionTrace trace, double newWeight) {
    setState(() {
      _weightOverrides[trace.nodeRef] = newWeight;
    });
    widget.onWeightChanged?.call(trace, newWeight);
  }

  void _toggleMemoryExclusion(AttributionTrace trace) {
    setState(() {
      if (_excludedMemories.contains(trace.nodeRef)) {
        _excludedMemories.remove(trace.nodeRef);
        widget.onIncludeMemory?.call(trace);
      } else {
        _excludedMemories.add(trace.nodeRef);
        widget.onExcludeMemory?.call(trace);
      }
    });
  }

  void _excludeAllMemories() {
    setState(() {
      for (final trace in widget.traces) {
        _excludedMemories.add(trace.nodeRef);
        widget.onExcludeMemory?.call(trace);
      }
    });
  }

  void _includeAllMemories() {
    setState(() {
      for (final trace in widget.traces) {
        _excludedMemories.remove(trace.nodeRef);
        widget.onIncludeMemory?.call(trace);
      }
    });
  }

  void _boostAllMemories() {
    for (final trace in widget.traces) {
      if (!_excludedMemories.contains(trace.nodeRef)) {
        final newWeight = (trace.confidence + 0.2).clamp(0.0, 1.0);
        _updateWeight(trace, newWeight);
      }
    }
  }

  void _reduceAllMemories() {
    for (final trace in widget.traces) {
      if (!_excludedMemories.contains(trace.nodeRef)) {
        final newWeight = (trace.confidence - 0.2).clamp(0.0, 1.0);
        _updateWeight(trace, newWeight);
      }
    }
  }

  void _resetWeights() {
    setState(() {
      _weightOverrides.clear();
      _excludedMemories.clear();
      for (final trace in widget.traces) {
        _weightOverrides[trace.nodeRef] = trace.confidence;
      }
    });
    widget.onResetWeights?.call();
  }

  double _calculateAverageWeight() {
    if (widget.traces.isEmpty) return 0.0;
    
    final activeTraces = widget.traces.where((t) => !_excludedMemories.contains(t.nodeRef));
    if (activeTraces.isEmpty) return 0.0;
    
    final totalWeight = activeTraces.fold<double>(0.0, (sum, trace) {
      return sum + (_weightOverrides[trace.nodeRef] ?? trace.confidence);
    });
    
    return totalWeight / activeTraces.length;
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

  String _formatRelation(String relation) {
    return relation.replaceAll('_', ' ').split(' ').map((word) => 
      word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : word
    ).join(' ');
  }
}

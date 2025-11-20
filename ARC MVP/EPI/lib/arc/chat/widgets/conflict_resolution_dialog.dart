// lib/lumara/widgets/conflict_resolution_dialog.dart
// Dialog for resolving memory conflicts with user dignity

import 'package:flutter/material.dart';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';
import 'package:my_app/mira/memory/conflict_resolution_service.dart';

/// Response from conflict resolution dialog
class ConflictResolutionResponse {
  final UserResolution resolution;
  final String? userExplanation;
  final bool rememberChoice;

  const ConflictResolutionResponse({
    required this.resolution,
    this.userExplanation,
    this.rememberChoice = false,
  });
}

/// Dialog for resolving memory conflicts with dignity
class ConflictResolutionDialog extends StatefulWidget {
  final MemoryConflict conflict;
  final EnhancedMiraNode nodeA;
  final EnhancedMiraNode nodeB;
  final String resolutionPrompt;
  final ConflictType conflictType;

  const ConflictResolutionDialog({
    super.key,
    required this.conflict,
    required this.nodeA,
    required this.nodeB,
    required this.resolutionPrompt,
    required this.conflictType,
  });

  /// Show dialog and return user's resolution choice
  static Future<ConflictResolutionResponse?> show({
    required BuildContext context,
    required MemoryConflict conflict,
    required EnhancedMiraNode nodeA,
    required EnhancedMiraNode nodeB,
    required String resolutionPrompt,
    required ConflictType conflictType,
  }) {
    return showDialog<ConflictResolutionResponse>(
      context: context,
      barrierDismissible: false, // Must resolve conflict
      builder: (context) => ConflictResolutionDialog(
        conflict: conflict,
        nodeA: nodeA,
        nodeB: nodeB,
        resolutionPrompt: resolutionPrompt,
        conflictType: conflictType,
      ),
    );
  }

  @override
  State<ConflictResolutionDialog> createState() => _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  UserResolution? _selectedResolution;
  final TextEditingController _explanationController = TextEditingController();
  bool _rememberChoice = false;

  @override
  void dispose() {
    _explanationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      icon: Icon(
        _getConflictIcon(),
        size: 32,
        color: _getConflictColor(),
      ),
      title: Text(_getConflictTitle()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Conflict description
            Text(
              widget.resolutionPrompt,
              style: theme.textTheme.bodyLarge,
            ),
            
            const SizedBox(height: 16),
            
            // Conflict type chip
            Chip(
              avatar: Icon(_getConflictIcon(), size: 18),
              label: Text(_getConflictTypeDisplay()),
              backgroundColor: _getConflictColor().withOpacity(0.1),
            ),
            
            const SizedBox(height: 16),
            
            // Memory comparison
            _buildMemoryComparison(),
            
            const SizedBox(height: 16),
            
            // Resolution options
            Text(
              'How would you like to resolve this?',
              style: theme.textTheme.titleSmall,
            ),
            
            const SizedBox(height: 8),
            
            ..._buildResolutionOptions(),
            
            const SizedBox(height: 16),
            
            // Custom explanation (if needed)
            if (_selectedResolution == UserResolution.custom_explanation) ...[
              TextField(
                controller: _explanationController,
                decoration: const InputDecoration(
                  labelText: 'Your explanation',
                  hintText: 'Please explain how these memories relate to each other...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
            ],
            
            // Remember choice option
            CheckboxListTile(
              value: _rememberChoice,
              onChanged: (value) {
                setState(() {
                  _rememberChoice = value ?? false;
                });
              },
              title: Text(
                'Remember my choice for similar conflicts',
                style: theme.textTheme.bodySmall,
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedResolution != null ? _handleResolution : null,
          child: const Text('Resolve'),
        ),
      ],
    );
  }

  Widget _buildMemoryComparison() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Memory Comparison',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            
            // Memory A
            _buildMemoryNode('Earlier Memory', widget.nodeA, Colors.blue),
            
            const SizedBox(height: 8),
            
            // Memory B
            _buildMemoryNode('New Memory', widget.nodeB, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryNode(String label, EnhancedMiraNode node, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            node.narrative.length > 100 
                ? '${node.narrative.substring(0, 100)}...'
                : node.narrative,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.schedule, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                '${node.createdAt.day}/${node.createdAt.month}/${node.createdAt.year}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.category, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                node.domain.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildResolutionOptions() {
    final options = _getResolutionOptions();
    
    return options.map((option) => RadioListTile<UserResolution>(
      value: option.value,
      groupValue: _selectedResolution,
      onChanged: (value) {
        setState(() {
          _selectedResolution = value;
        });
      },
      title: Text(option.title),
      subtitle: Text(option.description),
      dense: true,
    )).toList();
  }

  List<ResolutionOption> _getResolutionOptions() {
    switch (widget.conflictType) {
      case ConflictType.factual:
        return [
          ResolutionOption(
            value: UserResolution.prefer_newer,
            title: 'Keep the newer memory',
            description: 'The more recent information is likely more accurate',
          ),
          ResolutionOption(
            value: UserResolution.prefer_older,
            title: 'Keep the older memory',
            description: 'The original information is more reliable',
          ),
          ResolutionOption(
            value: UserResolution.keep_both,
            title: 'Keep both memories',
            description: 'Both perspectives might be valid in different contexts',
          ),
          ResolutionOption(
            value: UserResolution.custom_explanation,
            title: 'Provide my own explanation',
            description: 'I\'ll explain how these memories relate to each other',
          ),
        ];
      case ConflictType.temporal:
        return [
          ResolutionOption(
            value: UserResolution.keep_both,
            title: 'Reconcile timeline',
            description: 'These events happened at different times',
          ),
          ResolutionOption(
            value: UserResolution.keep_both,
            title: 'Keep both memories',
            description: 'Both events are important to remember',
          ),
        ];
      case ConflictType.emotional:
        return [
          ResolutionOption(
            value: UserResolution.keep_both,
            title: 'Acknowledge emotional growth',
            description: 'My feelings have evolved over time',
          ),
          ResolutionOption(
            value: UserResolution.keep_both,
            title: 'Keep both emotional states',
            description: 'Both feelings are valid parts of my journey',
          ),
        ];
      case ConflictType.value_system:
        return [
          ResolutionOption(
            value: UserResolution.merge_insights,
            title: 'Integrate both perspectives',
            description: 'These values can coexist and complement each other',
          ),
          ResolutionOption(
            value: UserResolution.keep_both,
            title: 'Keep both value systems',
            description: 'My values have complexity and nuance',
          ),
        ];
      case ConflictType.phase:
        return [
          ResolutionOption(
            value: UserResolution.contextual_both,
            title: 'Contextualize by phase',
            description: 'These memories reflect different growth phases',
          ),
          ResolutionOption(
            value: UserResolution.keep_both,
            title: 'Keep both phase memories',
            description: 'Both phases are important parts of my journey',
          ),
        ];
    }
  }

  void _handleResolution() {
    if (_selectedResolution == null) return;

    final response = ConflictResolutionResponse(
      resolution: _selectedResolution!,
      userExplanation: _explanationController.text.isNotEmpty 
          ? _explanationController.text 
          : null,
      rememberChoice: _rememberChoice,
    );

    Navigator.pop(context, response);
  }

  IconData _getConflictIcon() {
    switch (widget.conflictType) {
      case ConflictType.factual:
        return Icons.fact_check;
      case ConflictType.temporal:
        return Icons.schedule;
      case ConflictType.emotional:
        return Icons.psychology;
      case ConflictType.value_system:
        return Icons.flag;
      case ConflictType.phase:
        return Icons.trending_up;
    }
  }

  Color _getConflictColor() {
    switch (widget.conflictType) {
      case ConflictType.factual:
        return Colors.red;
      case ConflictType.temporal:
        return Colors.blue;
      case ConflictType.emotional:
        return Colors.purple;
      case ConflictType.value_system:
        return Colors.orange;
      case ConflictType.phase:
        return Colors.green;
    }
  }

  String _getConflictTitle() {
    switch (widget.conflictType) {
      case ConflictType.factual:
        return 'Factual Conflict Detected';
      case ConflictType.temporal:
        return 'Timeline Conflict Detected';
      case ConflictType.emotional:
        return 'Emotional Conflict Detected';
      case ConflictType.value_system:
        return 'Value System Conflict Detected';
      case ConflictType.phase:
        return 'Phase Conflict Detected';
    }
  }

  String _getConflictTypeDisplay() {
    switch (widget.conflictType) {
      case ConflictType.factual:
        return 'Factual';
      case ConflictType.temporal:
        return 'Timeline';
      case ConflictType.emotional:
        return 'Emotional';
      case ConflictType.value_system:
        return 'Value System';
      case ConflictType.phase:
        return 'Phase';
    }
  }
}

class ResolutionOption {
  final UserResolution value;
  final String title;
  final String description;

  const ResolutionOption({
    required this.value,
    required this.title,
    required this.description,
  });
}

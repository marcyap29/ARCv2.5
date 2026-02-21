// lib/features/settings/conflict_management_view.dart
// View for managing and resolving memory conflicts

import 'package:flutter/material.dart';
import 'package:my_app/mira/memory/enhanced_mira_memory_service.dart';
import 'package:my_app/mira/memory/conflict_resolution_service.dart';
import 'package:my_app/mira/memory/enhanced_memory_schema.dart';
import 'package:my_app/mira/mira_service.dart';
import 'package:my_app/arc/chat/widgets/conflict_resolution_dialog.dart';

class ConflictManagementView extends StatefulWidget {
  const ConflictManagementView({super.key});

  @override
  State<ConflictManagementView> createState() => _ConflictManagementViewState();
}

class _ConflictManagementViewState extends State<ConflictManagementView> {
  late EnhancedMiraMemoryService _memoryService;
  late ConflictResolutionService _conflictService;
  List<MemoryConflict> _activeConflicts = [];
  List<ConflictResolution> _resolutionHistory = [];
  bool _isLoading = true;
  String? _errorMessage;
  ConflictSeverity? _selectedSeverity;
  ConflictType? _selectedType;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      _memoryService = EnhancedMiraMemoryService(
        miraService: MiraService.instance,
      );
      
      await _memoryService.initialize(
        userId: 'current_user', // This should use actual user ID
        sessionId: null,
        currentPhase: 'Discovery', // This should use actual current phase
      );
      
      _conflictService = ConflictResolutionService();
      await _loadConflicts();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize conflict management: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadConflicts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final conflicts = _conflictService.getActiveConflicts();
      final history = <ConflictResolution>[]; // TODO: Implement getResolutionHistory method
      
      setState(() {
        _activeConflicts = conflicts;
        _resolutionHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load conflicts: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Conflicts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadConflicts,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'filter_severity',
                child: Text('Filter by Severity'),
              ),
              const PopupMenuItem(
                value: 'filter_type',
                child: Text('Filter by Type'),
              ),
              const PopupMenuItem(
                value: 'clear_resolved',
                child: Text('Clear Resolved'),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return Column(
      children: [
        _buildSummaryCard(),
        _buildFilterChips(),
        Expanded(
          child: _activeConflicts.isEmpty
              ? _buildEmptyState()
              : _buildConflictsList(),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final totalConflicts = _activeConflicts.length;
    final resolvedCount = _resolutionHistory.length;
    final highSeverityCount = _activeConflicts.where((c) => c.severity == ConflictSeverity.high).length;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conflict Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatItem('Active', totalConflicts.toString(), Colors.orange),
                const SizedBox(width: 16),
                _buildStatItem('Resolved', resolvedCount.toString(), Colors.green),
                const SizedBox(width: 16),
                _buildStatItem('High Priority', highSeverityCount.toString(), Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: [
          FilterChip(
            label: const Text('All Severities'),
            selected: _selectedSeverity == null,
            onSelected: (selected) {
              setState(() {
                _selectedSeverity = null;
              });
            },
          ),
          ...ConflictSeverity.values.map((severity) => FilterChip(
            label: Text(severity.name.toUpperCase()),
            selected: _selectedSeverity == severity,
            onSelected: (selected) {
              setState(() {
                _selectedSeverity = selected ? severity : null;
              });
            },
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Conflicts',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Your memories are in harmony!',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Conflicts',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadConflicts,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictsList() {
    final filteredConflicts = _getFilteredConflicts();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredConflicts.length,
      itemBuilder: (context, index) {
        final conflict = filteredConflicts[index];
        return _buildConflictCard(conflict);
      },
    );
  }

  List<MemoryConflict> _getFilteredConflicts() {
    var conflicts = _activeConflicts;
    
    if (_selectedSeverity != null) {
      conflicts = conflicts.where((c) => c.severity == _selectedSeverity).toList();
    }
    
    if (_selectedType != null) {
      conflicts = conflicts.where((c) => ConflictType.values.firstWhere((t) => t.name == c.conflictType) == _selectedType).toList();
    }
    
    return conflicts;
  }

  Widget _buildConflictCard(MemoryConflict conflict) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(_getConflictTitle(conflict)),
        subtitle: Text(_getConflictDescription(conflict)),
        leading: Icon(
          _getConflictIcon(ConflictType.values.firstWhere((t) => t.name == conflict.conflictType)),
          color: _getSeverityColor(_getSeverityFromDouble(conflict.severity)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConflictDetails(conflict),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _resolveConflict(conflict),
                        icon: const Icon(Icons.check),
                        label: const Text('Resolve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _viewConflictDetails(conflict),
                        icon: const Icon(Icons.info),
                        label: const Text('Details'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictDetails(MemoryConflict conflict) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Type', _formatConflictType(ConflictType.values.firstWhere((t) => t.name == conflict.conflictType))),
        _buildDetailRow('Severity', _formatSeverity(_getSeverityFromDouble(conflict.severity))),
        _buildDetailRow('Detected', _formatDate(conflict.detected)),
        if (conflict.description != null)
          _buildDetailRow('Description', conflict.description!),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveConflict(MemoryConflict conflict) async {
    try {
      // Get the conflicting nodes - TODO: Implement getConflictingNodes method
      final nodes = <EnhancedMiraNode>[]; // Placeholder
      if (nodes.length < 2) {
        _showSnackBar('Unable to load conflicting memories', isError: true);
        return;
      }

      // Generate resolution prompt
      final prompt = _conflictService.generateResolutionPrompt(
        conflict: conflict,
        nodeA: nodes[0],
        nodeB: nodes[1],
      );

      // Show resolution dialog
      final response = await ConflictResolutionDialog.show(
        context: context,
        conflict: conflict,
        nodeA: nodes[0],
        nodeB: nodes[1],
        resolutionPrompt: prompt,
        conflictType: ConflictType.values.firstWhere((t) => t.name == conflict.conflictType),
      );

      if (response != null) {
        // Apply resolution
        await _conflictService.resolveConflict(
          conflictId: conflict.id,
          userResolution: response.resolution,
          userExplanation: response.userExplanation,
        );

        _showSnackBar('Conflict resolved successfully');
        await _loadConflicts();
      }
    } catch (e) {
      _showSnackBar('Failed to resolve conflict: $e', isError: true);
    }
  }

  void _viewConflictDetails(MemoryConflict conflict) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Conflict Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', conflict.id),
              _buildDetailRow('Type', _formatConflictType(ConflictType.values.firstWhere((t) => t.name == conflict.conflictType))),
              _buildDetailRow('Severity', _formatSeverity(_getSeverityFromDouble(conflict.severity))),
              _buildDetailRow('Detected', _formatDate(conflict.detected)),
              if (conflict.description != null)
                _buildDetailRow('Description', conflict.description!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'filter_severity':
        _showSeverityFilter();
        break;
      case 'filter_type':
        _showTypeFilter();
        break;
      case 'clear_resolved':
        _clearResolvedConflicts();
        break;
    }
  }

  void _showSeverityFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Severity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ConflictSeverity.values.map((severity) => 
            RadioListTile<ConflictSeverity>(
              value: severity,
              groupValue: _selectedSeverity,
              onChanged: (value) {
                setState(() {
                  _selectedSeverity = value;
                });
                Navigator.pop(context);
              },
              title: Text(severity.name.toUpperCase()),
            ),
          ).toList(),
        ),
      ),
    );
  }

  void _showTypeFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ConflictType.values.map((type) => 
            RadioListTile<ConflictType>(
              value: type,
              groupValue: _selectedType,
              onChanged: (value) {
                setState(() {
                  _selectedType = value;
                });
                Navigator.pop(context);
              },
              title: Text(_formatConflictType(type)),
            ),
          ).toList(),
        ),
      ),
    );
  }

  void _clearResolvedConflicts() {
    // This would clear resolved conflicts from history
    _showSnackBar('Resolved conflicts cleared');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _getConflictTitle(MemoryConflict conflict) {
    return '${_formatConflictType(ConflictType.values.firstWhere((t) => t.name == conflict.conflictType))} Conflict';
  }

  String _getConflictDescription(MemoryConflict conflict) {
    return 'Detected ${_formatDate(conflict.detected)} - ${_formatSeverity(_getSeverityFromDouble(conflict.severity))}';
  }

  IconData _getConflictIcon(ConflictType type) {
    switch (type) {
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

  Color _getSeverityColor(ConflictSeverity severity) {
    switch (severity) {
      case ConflictSeverity.low:
        return Colors.green;
      case ConflictSeverity.medium:
        return Colors.orange;
      case ConflictSeverity.high:
        return Colors.red;
    }
  }

  String _formatConflictType(ConflictType type) {
    switch (type) {
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

  String _formatSeverity(ConflictSeverity severity) {
    return severity.name.toUpperCase();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  ConflictSeverity _getSeverityFromDouble(double severity) {
    if (severity >= 0.8) return ConflictSeverity.high;
    if (severity >= 0.5) return ConflictSeverity.medium;
    return ConflictSeverity.low;
  }
}

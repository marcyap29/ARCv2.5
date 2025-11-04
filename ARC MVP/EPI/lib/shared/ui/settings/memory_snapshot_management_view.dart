// lib/features/settings/memory_snapshot_management_view.dart
// UI for managing memory snapshots and rollback functionality

import 'package:flutter/material.dart';
import 'package:my_app/polymeta/memory/enhanced_mira_memory_service.dart';
import 'package:my_app/polymeta/mira_service.dart';

class MemorySnapshotManagementView extends StatefulWidget {
  const MemorySnapshotManagementView({super.key});

  @override
  State<MemorySnapshotManagementView> createState() => _MemorySnapshotManagementViewState();
}

class _MemorySnapshotManagementViewState extends State<MemorySnapshotManagementView> {
  late EnhancedMiraMemoryService _memoryService;
  List<Map<String, dynamic>> _snapshots = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadSnapshots();
  }

  void _initializeServices() {
    _memoryService = EnhancedMiraMemoryService(
      miraService: MiraService.instance,
    );
  }

  Future<void> _loadSnapshots() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _memoryService.initialize(
        userId: 'current_user', // This should use actual user ID
        sessionId: null,
        currentPhase: 'Discovery', // This should use actual current phase
      );
      final snapshots = await _memoryService.getAvailableSnapshots();
      setState(() {
        _snapshots = snapshots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load snapshots: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createSnapshot() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const CreateSnapshotDialog(),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await _memoryService.storeMemorySnapshot(
          name: result['name']!,
          description: result['description'],
        );
        await _loadSnapshots();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Snapshot "${result['name']}" created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to create snapshot: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _rollbackToSnapshot(String snapshotId, String snapshotName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => RollbackConfirmationDialog(snapshotName: snapshotName),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final success = await _memoryService.rollbackToSnapshot(snapshotId);
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully rolled back to "$snapshotName"'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'Rollback failed';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Rollback failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteSnapshot(String snapshotId, String snapshotName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteSnapshotDialog(snapshotName: snapshotName),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await _memoryService.deleteSnapshot(snapshotId);
        await _loadSnapshots();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Snapshot "$snapshotName" deleted successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to delete snapshot: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _compareSnapshots(String snapshotId1, String snapshotId2) async {
    try {
      final comparison = await _memoryService.compareSnapshots(snapshotId1, snapshotId2);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => SnapshotComparisonDialog(comparison: comparison),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to compare snapshots: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Snapshots'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSnapshots,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with create button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Manage your memory snapshots',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _createSnapshot,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

          // Error message
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _errorMessage = null),
                  ),
                ],
              ),
            ),

          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),

          // Snapshots list
          Expanded(
            child: _snapshots.isEmpty && !_isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.backup_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No snapshots yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create your first snapshot to backup your memories',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _snapshots.length,
                    itemBuilder: (context, index) {
                      final snapshot = _snapshots[index];
                      return SnapshotCard(
                        snapshot: snapshot,
                        onRollback: () => _rollbackToSnapshot(
                          snapshot['id'],
                          snapshot['name'],
                        ),
                        onDelete: () => _deleteSnapshot(
                          snapshot['id'],
                          snapshot['name'],
                        ),
                        onCompare: index < _snapshots.length - 1
                            ? () => _compareSnapshots(
                                  snapshot['id'],
                                  _snapshots[index + 1]['id'],
                                )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class SnapshotCard extends StatelessWidget {
  final Map<String, dynamic> snapshot;
  final VoidCallback onRollback;
  final VoidCallback onDelete;
  final VoidCallback? onCompare;

  const SnapshotCard({
    super.key,
    required this.snapshot,
    required this.onRollback,
    required this.onDelete,
    this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.parse(snapshot['created_at']);
    final nodeCount = snapshot['node_count'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.backup,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    snapshot['name'] ?? 'Unnamed Snapshot',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'rollback':
                        onRollback();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                      case 'compare':
                        onCompare?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rollback',
                      child: Row(
                        children: [
                          Icon(Icons.restore),
                          SizedBox(width: 8),
                          Text('Rollback to this snapshot'),
                        ],
                      ),
                    ),
                    if (onCompare != null)
                      const PopupMenuItem(
                        value: 'compare',
                        child: Row(
                          children: [
                            Icon(Icons.compare),
                            SizedBox(width: 8),
                            Text('Compare with next'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Description
            if (snapshot['description'] != null) ...[
              const SizedBox(height: 8),
              Text(
                snapshot['description'],
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],

            // Metadata
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMetadataChip(
                  Icons.memory,
                  '$nodeCount memories',
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildMetadataChip(
                  Icons.access_time,
                  _formatDate(createdAt),
                  Colors.green,
                ),
              ],
            ),

            // Actions
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: onRollback,
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Rollback'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(100, 32),
                  ),
                ),
                const SizedBox(width: 8),
                if (onCompare != null)
                  OutlinedButton.icon(
                    onPressed: onCompare,
                    icon: const Icon(Icons.compare, size: 16),
                    label: const Text('Compare'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(100, 32),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete snapshot',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class CreateSnapshotDialog extends StatefulWidget {
  const CreateSnapshotDialog({super.key});

  @override
  State<CreateSnapshotDialog> createState() => _CreateSnapshotDialogState();
}

class _CreateSnapshotDialogState extends State<CreateSnapshotDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Memory Snapshot'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Snapshot Name',
                hintText: 'e.g., Before major changes',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a snapshot name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Describe what this snapshot contains',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'name': _nameController.text.trim(),
                'description': _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class RollbackConfirmationDialog extends StatelessWidget {
  final String snapshotName;

  const RollbackConfirmationDialog({
    super.key,
    required this.snapshotName,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Rollback'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Are you sure you want to rollback to this snapshot?',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This will replace all current memories with the snapshot data. This action cannot be undone.',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Rolling back to: "$snapshotName"',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Rollback'),
        ),
      ],
    );
  }
}

class DeleteSnapshotDialog extends StatelessWidget {
  final String snapshotName;

  const DeleteSnapshotDialog({
    super.key,
    required this.snapshotName,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Snapshot'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Are you sure you want to delete this snapshot?',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This action cannot be undone. The snapshot will be permanently deleted.',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Deleting: "$snapshotName"',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class SnapshotComparisonDialog extends StatelessWidget {
  final Map<String, dynamic> comparison;

  const SnapshotComparisonDialog({
    super.key,
    required this.comparison,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot1 = comparison['snapshot1'] as Map<String, dynamic>;
    final snapshot2 = comparison['snapshot2'] as Map<String, dynamic>;
    final differences = comparison['differences'] as Map<String, dynamic>;

    return AlertDialog(
      title: const Text('Snapshot Comparison'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Snapshot 1
            _buildSnapshotInfo('Snapshot 1', snapshot1, Colors.blue),
            const SizedBox(height: 16),
            
            // Snapshot 2
            _buildSnapshotInfo('Snapshot 2', snapshot2, Colors.green),
            const SizedBox(height: 16),
            
            // Differences
            const Text(
              'Differences:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            _buildDifferenceItem(
              'Node Count Difference',
              '${differences['node_count_difference']} nodes',
              differences['node_count_difference'] > 0 ? Colors.green : Colors.red,
            ),
            
            _buildDifferenceItem(
              'Time Difference',
              '${differences['time_difference']} days',
              Colors.blue,
            ),
            
            _buildDifferenceItem(
              'Common Nodes',
              '${(differences['common_nodes'] as List).length} nodes',
              Colors.grey,
            ),
            
            _buildDifferenceItem(
              'Unique to Snapshot 1',
              '${(differences['unique_to_snapshot1'] as List).length} nodes',
              Colors.blue,
            ),
            
            _buildDifferenceItem(
              'Unique to Snapshot 2',
              '${(differences['unique_to_snapshot2'] as List).length} nodes',
              Colors.green,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildSnapshotInfo(String title, Map<String, dynamic> snapshot, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text('Name: ${snapshot['name']}'),
          Text('Created: ${_formatDate(DateTime.parse(snapshot['created_at']))}'),
          Text('Nodes: ${snapshot['node_count']}'),
        ],
      ),
    );
  }

  Widget _buildDifferenceItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

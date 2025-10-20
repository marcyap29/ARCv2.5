import 'package:flutter/material.dart';
import 'package:my_app/prism/mcp/models/media_pack_metadata.dart';
import 'package:my_app/services/media_pack_tracking_service.dart';

/// Dashboard widget for managing media packs
class MediaPackDashboard extends StatefulWidget {
  const MediaPackDashboard({super.key});

  @override
  State<MediaPackDashboard> createState() => _MediaPackDashboardState();
}

class _MediaPackDashboardState extends State<MediaPackDashboard> {
  MediaPackStatus _filterStatus = MediaPackStatus.active;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Simulate loading time
    await Future.delayed(const Duration(milliseconds: 300));
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final trackingService = MediaPackTrackingService.instance;
    final stats = trackingService.getStorageStats();
    final packs = _getFilteredPacks(trackingService);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Statistics
        _buildSummaryStats(stats),
        const SizedBox(height: 16),
        
        // Filter Controls
        _buildFilterControls(),
        const SizedBox(height: 16),
        
        // Packs List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildPacksList(packs, trackingService),
        ),
      ],
    );
  }

  Widget _buildSummaryStats(Map<String, dynamic> stats) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storage Overview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Packs',
                    '${stats['totalPacks'] ?? 0}',
                    Icons.folder,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Active',
                    '${stats['activePacks'] ?? 0}',
                    Icons.folder_open,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Archived',
                    '${stats['archivedPacks'] ?? 0}',
                    Icons.archive,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Storage',
                    _formatBytes(stats['totalStorageBytes'] ?? 0),
                    Icons.storage,
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Total Files',
                    '${stats['totalFileCount'] ?? 0}',
                    Icons.photo,
                    Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterControls() {
    return Row(
      children: [
        Text(
          'Filter:',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Active', MediaPackStatus.active),
                const SizedBox(width: 8),
                _buildFilterChip('Archived', MediaPackStatus.archived),
                const SizedBox(width: 8),
                _buildFilterChip('All', null),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, MediaPackStatus? status) {
    final isSelected = _filterStatus == status;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (status == null) {
            _filterStatus = MediaPackStatus.active; // Show all
          } else {
            _filterStatus = status;
          }
        });
      },
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[700],
    );
  }

  Widget _buildPacksList(List<MediaPackMetadata> packs, MediaPackTrackingService trackingService) {
    if (packs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No media packs found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Export your journal to create media packs',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: packs.length,
      itemBuilder: (context, index) {
        final pack = packs[index];
        return _buildPackCard(pack, trackingService);
      },
    );
  }

  Widget _buildPackCard(MediaPackMetadata pack, MediaPackTrackingService trackingService) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(pack.status),
                  color: _getStatusColor(pack.status),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pack.packId,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusBadge(pack.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPackInfo(
                    'Created',
                    pack.formattedCreatedAt,
                    Icons.calendar_today,
                  ),
                ),
                Expanded(
                  child: _buildPackInfo(
                    'Files',
                    '${pack.fileCount}',
                    Icons.photo,
                  ),
                ),
                Expanded(
                  child: _buildPackInfo(
                    'Size',
                    pack.formattedSize,
                    Icons.storage,
                  ),
                ),
              ],
            ),
            if (pack.description != null) ...[
              const SizedBox(height: 8),
              Text(
                pack.description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (pack.status == MediaPackStatus.active) ...[
                  TextButton.icon(
                    onPressed: () => _archivePack(pack, trackingService),
                    icon: const Icon(Icons.archive, size: 16),
                    label: const Text('Archive'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange[700],
                    ),
                  ),
                ] else if (pack.status == MediaPackStatus.archived) ...[
                  TextButton.icon(
                    onPressed: () => _unarchivePack(pack, trackingService),
                    icon: const Icon(Icons.unarchive, size: 16),
                    label: const Text('Unarchive'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green[700],
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _deletePack(pack, trackingService),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackInfo(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(MediaPackStatus status) {
    final color = _getStatusColor(status);
    final label = status.name.toUpperCase();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  IconData _getStatusIcon(MediaPackStatus status) {
    switch (status) {
      case MediaPackStatus.active:
        return Icons.folder_open;
      case MediaPackStatus.archived:
        return Icons.archive;
      case MediaPackStatus.deleted:
        return Icons.delete;
    }
  }

  Color _getStatusColor(MediaPackStatus status) {
    switch (status) {
      case MediaPackStatus.active:
        return Colors.green;
      case MediaPackStatus.archived:
        return Colors.orange;
      case MediaPackStatus.deleted:
        return Colors.red;
    }
  }

  List<MediaPackMetadata> _getFilteredPacks(MediaPackTrackingService trackingService) {
    if (_filterStatus == MediaPackStatus.active) {
      return trackingService.getAllPacks(); // Show all when "All" is selected
    }
    return trackingService.getPacksByStatus(_filterStatus);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  Future<void> _archivePack(MediaPackMetadata pack, MediaPackTrackingService trackingService) async {
    try {
      await trackingService.archivePack(pack.packId);
      setState(() {});
      _showSnackBar('Pack archived: ${pack.packId}', Colors.orange);
    } catch (e) {
      _showSnackBar('Error archiving pack: $e', Colors.red);
    }
  }

  Future<void> _unarchivePack(MediaPackMetadata pack, MediaPackTrackingService trackingService) async {
    try {
      await trackingService.unarchivePack(pack.packId);
      setState(() {});
      _showSnackBar('Pack unarchived: ${pack.packId}', Colors.green);
    } catch (e) {
      _showSnackBar('Error unarchiving pack: $e', Colors.red);
    }
  }

  Future<void> _deletePack(MediaPackMetadata pack, MediaPackTrackingService trackingService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pack'),
        content: Text('Are you sure you want to delete pack "${pack.packId}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await trackingService.deletePack(pack.packId);
        setState(() {});
        _showSnackBar('Pack deleted: ${pack.packId}', Colors.red);
      } catch (e) {
        _showSnackBar('Error deleting pack: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

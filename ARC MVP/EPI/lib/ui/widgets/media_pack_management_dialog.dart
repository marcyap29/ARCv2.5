import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_app/prism/mcp/models/media_pack_manifest.dart';
import 'package:my_app/prism/mcp/zip/mcp_zip_reader.dart';
import 'package:file_picker/file_picker.dart';

/// Dialog for managing media packs (mounting, unmounting, viewing statistics)
class MediaPackManagementDialog extends StatefulWidget {
  final List<String> mountedPacks;
  final Function(String packPath) onMountPack;
  final Function(String packPath) onUnmountPack;

  const MediaPackManagementDialog({
    super.key,
    required this.mountedPacks,
    required this.onMountPack,
    required this.onUnmountPack,
  });

  @override
  State<MediaPackManagementDialog> createState() => _MediaPackManagementDialogState();
}

class _MediaPackManagementDialogState extends State<MediaPackManagementDialog> {
  final Map<String, MediaPackManifest?> _packManifests = {};
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPackManifests();
  }

  Future<void> _loadPackManifests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      for (final packPath in widget.mountedPacks) {
        try {
          final reader = await McpZipReader.fromFile(packPath);
          final manifest = reader.readMediaPackManifest();
          _packManifests[packPath] = manifest;
        } catch (e) {
          print('Error reading manifest for $packPath: $e');
          _packManifests[packPath] = null;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndMountPack() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        dialogTitle: 'Select Media Pack',
      );

      if (result != null && result.files.single.path != null) {
        final packPath = result.files.single.path!;

        // Verify it's a valid media pack
        try {
          final reader = await McpZipReader.fromFile(packPath);
          final manifest = reader.readMediaPackManifest();

          if (manifest == null) {
            _showError('Invalid media pack: No manifest found');
            return;
          }

          // Mount the pack
          widget.onMountPack(packPath);

          // Update UI
          setState(() {
            _packManifests[packPath] = manifest;
          });

          _showSuccess('Media pack "${manifest.id}" mounted successfully');
        } catch (e) {
          _showError('Failed to read media pack: $e');
        }
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
  }

  Future<void> _unmountPack(String packPath) async {
    final manifest = _packManifests[packPath];
    final packId = manifest?.id ?? 'Unknown';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unmount Media Pack'),
        content: Text(
          'Unmount media pack "$packId"?\n\n'
          'Photos from this pack will not be available until re-mounted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('UNMOUNT'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onUnmountPack(packPath);
      setState(() {
        _packManifests.remove(packPath);
      });
      _showSuccess('Media pack "$packId" unmounted');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_special, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Media Pack Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : _buildPackList(),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.mountedPacks.length} pack(s) mounted',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickAndMountPack,
                    icon: const Icon(Icons.add),
                    label: const Text('Mount Pack'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading media packs',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPackManifests,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPackList() {
    if (widget.mountedPacks.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.mountedPacks.length,
      itemBuilder: (context, index) {
        final packPath = widget.mountedPacks[index];
        final manifest = _packManifests[packPath];
        return _buildPackCard(packPath, manifest);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Media Packs Mounted',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Mount media packs to view full-resolution photos.\n'
              'Thumbnails are always available in the journal.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickAndMountPack,
            icon: const Icon(Icons.add),
            label: const Text('Mount First Pack'),
          ),
        ],
      ),
    );
  }

  Widget _buildPackCard(String packPath, MediaPackManifest? manifest) {
    final file = File(packPath);
    final fileName = file.path.split('/').last;
    final fileSize = file.existsSync() ? file.lengthSync() : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          manifest != null ? Icons.check_circle : Icons.error,
          color: manifest != null ? Colors.green : Colors.orange,
        ),
        title: Text(
          manifest?.id ?? fileName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: manifest != null
            ? Text(
                '${manifest.itemCount} photos • ${_formatBytes(manifest.totalSize)}',
              )
            : const Text('Invalid manifest'),
        trailing: IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () => _unmountPack(packPath),
          tooltip: 'Unmount pack',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: manifest != null
                ? _buildPackDetails(packPath, manifest, fileSize)
                : _buildInvalidPackDetails(packPath, fileSize),
          ),
        ],
      ),
    );
  }

  Widget _buildPackDetails(String packPath, MediaPackManifest manifest, int fileSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Pack ID', manifest.id),
        _buildDetailRow('Date Range',
            '${_formatDate(manifest.from)} - ${_formatDate(manifest.to)}'),
        _buildDetailRow('Photos', manifest.itemCount.toString()),
        _buildDetailRow('Content Size', _formatBytes(manifest.totalSize)),
        _buildDetailRow('File Size', _formatBytes(fileSize)),
        _buildDetailRow('Location', packPath, monospace: true),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showPackContents(manifest),
                icon: const Icon(Icons.list, size: 18),
                label: const Text('View Contents'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blue[700],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInvalidPackDetails(String packPath, int fileSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('Status', 'Invalid or corrupted', error: true),
        _buildDetailRow('File Size', _formatBytes(fileSize)),
        _buildDetailRow('Location', packPath, monospace: true),
        const SizedBox(height: 8),
        const Text(
          'This pack could not be read. It may be corrupted or not a valid media pack.',
          style: TextStyle(color: Colors.orange, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool monospace = false, bool error = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: monospace ? 'monospace' : null,
                fontSize: monospace ? 11 : 14,
                color: error ? Colors.red : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPackContents(MediaPackManifest manifest) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pack Contents: ${manifest.id}'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: ListView.builder(
            itemCount: manifest.items.length,
            itemBuilder: (context, index) {
              final entry = manifest.items.entries.elementAt(index);
              final sha = entry.key;
              final item = entry.value;

              return ListTile(
                leading: const Icon(Icons.photo),
                title: Text(
                  '${sha.substring(0, 16)}...',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                subtitle: Text('${item.format.toUpperCase()} • ${_formatBytes(item.bytes)}'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

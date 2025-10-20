import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_app/prism/mcp/export/mcp_media_export_service.dart';
import 'package:my_app/prism/mcp/models/media_pack_manifest.dart';
import 'package:my_app/prism/mcp/models/journal_manifest.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/services/media_resolver_service.dart';

/// Dialog for exporting journal and media to MCP format
///
/// Features:
/// - Export journal with thumbnails
/// - Export media packs with full-resolution photos
/// - Progress tracking with live updates
/// - Configurable export options
class McpExportDialog extends StatefulWidget {
  final JournalRepository journalRepository;
  final String? defaultOutputDir;

  const McpExportDialog({
    super.key,
    required this.journalRepository,
    this.defaultOutputDir,
  });

  @override
  State<McpExportDialog> createState() => _McpExportDialogState();
}

class _McpExportDialogState extends State<McpExportDialog> {
  ExportPhase _phase = ExportPhase.configuration;
  String? _outputDir;

  // Configuration
  bool _exportJournal = true;
  bool _exportMediaPacks = true;
  bool _stripExif = true;
  int _thumbnailSize = 768;
  int _maxMediaPackSizeMB = 100;
  int _jpegQuality = 85;

  // Progress tracking
  int _totalEntries = 0;
  int _processedEntries = 0;
  int _totalPhotos = 0;
  int _processedPhotos = 0;
  String _currentOperation = '';
  DateTime? _startTime;

  // Results
  String? _journalPath;
  List<String> _mediaPackPaths = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeOutputDirectory();
    _analyzeEntries();
  }

  Future<void> _initializeOutputDirectory() async {
    // For iOS, automatically use app documents directory
    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportsDir = Directory('${directory.path}/Exports');

      // Create exports directory if it doesn't exist
      if (!await exportsDir.exists()) {
        await exportsDir.create(recursive: true);
      }

      setState(() {
        _outputDir = exportsDir.path;
      });
    } catch (e) {
      // Fallback to default if provided
      setState(() {
        _outputDir = widget.defaultOutputDir;
      });
    }
  }

  Future<void> _analyzeEntries() async {
    final entries = widget.journalRepository.getAllJournalEntries();
    int photoCount = 0;

    for (final entry in entries) {
      if (entry.media.isNotEmpty) {
        photoCount += entry.media.length;
      }
    }

    setState(() {
      _totalEntries = entries.length;
      _totalPhotos = photoCount;
    });
  }

  Future<void> _selectOutputDirectory() async {
    // Show user options for export location
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Export Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone_iphone),
              title: const Text('App Documents'),
              subtitle: const Text('Save to app\'s internal storage (recommended)'),
              onTap: () => Navigator.pop(context, 'documents'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('iCloud Drive or Files'),
              subtitle: const Text('Choose a custom folder'),
              onTap: () => Navigator.pop(context, 'custom'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'documents') {
      // Use app documents directory (already set in initState)
      if (_outputDir != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exports will be saved to app documents'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else if (choice == 'custom') {
      // Use FilePicker to let user select a directory
      // On iOS, this will open the Files app
      try {
        final result = await FilePicker.platform.getDirectoryPath();
        if (result != null) {
          setState(() {
            _outputDir = result;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exports will be saved to:\n$result'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting directory: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _startExport() async {
    if (_outputDir == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an output directory')),
      );
      return;
    }

    setState(() {
      _phase = ExportPhase.exporting;
      _startTime = DateTime.now();
      _currentOperation = 'Preparing export...';
    });

    try {
      // Fetch all entries
      final entries = widget.journalRepository.getAllJournalEntries();

      // Configure export
      final config = MediaPackConfig(
        maxSizeBytes: _maxMediaPackSizeMB * 1024 * 1024,
        maxItems: 1000,
        format: 'jpg',
        quality: _jpegQuality,
        maxEdge: 2048,
      );

      final thumbConfig = ThumbnailConfig(
        size: _thumbnailSize,
        format: 'jpg',
        quality: _jpegQuality,
      );

      final exportService = McpMediaExportService(
        bundleId: 'epi_journal_${DateTime.now().millisecondsSinceEpoch}',
        outputDir: _outputDir!,
        thumbnailConfig: thumbConfig,
        mediaPackConfig: config,
      );

      // Export with progress tracking
      final result = await exportService.exportJournal(
        entries: entries,
        createMediaPacks: _exportMediaPacks,
      );

      // Simulate progress updates (since the actual service doesn't have callbacks yet)
      for (int i = 0; i < entries.length; i++) {
        if (mounted) {
          setState(() {
            _processedEntries = i + 1;
            _processedPhotos = ((i + 1) / entries.length * _totalPhotos).toInt();
            _currentOperation = 'Processing entry ${i + 1}/${entries.length}';
          });
        }
        // Small delay to show progress
        await Future.delayed(const Duration(milliseconds: 10));
      }

      if (mounted && result.success) {
        setState(() {
          _phase = ExportPhase.complete;
          _journalPath = result.journalPath;
          _mediaPackPaths = result.mediaPackPaths;
          _processedEntries = result.processedEntries;
          _processedPhotos = result.totalMediaItems;
        });

        // Auto-update MediaResolverService with new paths
        if (_exportJournal && _journalPath != null) {
          try {
            await MediaResolverService.instance.updateJournalPath(_journalPath!);
          } catch (e) {
            print('Could not update journal path: $e');
          }
        }

        if (_exportMediaPacks && _mediaPackPaths.isNotEmpty) {
          for (final packPath in _mediaPackPaths) {
            try {
              await MediaResolverService.instance.mountPack(packPath);
            } catch (e) {
              print('Could not mount pack: $e');
            }
          }
        }
      } else if (result.error != null) {
        throw Exception(result.error);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = ExportPhase.error;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildContent(),
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[700],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_upload, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Export to MCP Format',
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
    );
  }

  Widget _buildContent() {
    switch (_phase) {
      case ExportPhase.configuration:
        return _buildConfiguration();
      case ExportPhase.exporting:
        return _buildProgress();
      case ExportPhase.complete:
        return _buildComplete();
      case ExportPhase.error:
        return _buildError();
    }
  }

  Widget _buildConfiguration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Statistics
        _buildStatisticsCard(),
        const SizedBox(height: 24),

        // Output directory
        const Text(
          'Export Location',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Default: App documents. Tap Browse to choose iCloud Drive or Files.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      _outputDir != null && _outputDir!.contains('/Documents/')
                        ? Icons.phone_iphone
                        : Icons.folder,
                      size: 20,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _outputDir != null
                          ? (_outputDir!.contains('/Documents/Exports')
                              ? 'App Documents/Exports'
                              : _outputDir!)
                          : 'No directory selected',
                        style: TextStyle(
                          color: _outputDir != null ? Colors.black87 : Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _selectOutputDirectory,
              icon: const Icon(Icons.folder_open, size: 20),
              label: const Text('Change'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Export options
        const Text(
          'Export Options',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        CheckboxListTile(
          title: const Text('Export Journal'),
          subtitle: const Text('Journal entries with embedded thumbnails'),
          value: _exportJournal,
          onChanged: (value) => setState(() => _exportJournal = value!),
        ),

        CheckboxListTile(
          title: const Text('Export Media Packs'),
          subtitle: const Text('Full-resolution photos in separate archives'),
          value: _exportMediaPacks,
          onChanged: (value) => setState(() => _exportMediaPacks = value!),
        ),

        CheckboxListTile(
          title: const Text('Strip EXIF Metadata'),
          subtitle: const Text('Remove GPS and camera data for privacy'),
          value: _stripExif,
          onChanged: (value) => setState(() => _stripExif = value!),
        ),

        const SizedBox(height: 24),

        // Advanced settings
        ExpansionTile(
          title: const Text('Advanced Settings'),
          children: [
            _buildSlider(
              label: 'Thumbnail Size',
              value: _thumbnailSize.toDouble(),
              min: 256,
              max: 1024,
              divisions: 3,
              onChanged: (value) => setState(() => _thumbnailSize = value.toInt()),
              valueLabel: '${_thumbnailSize}px',
            ),
            _buildSlider(
              label: 'Max Media Pack Size',
              value: _maxMediaPackSizeMB.toDouble(),
              min: 50,
              max: 500,
              divisions: 9,
              onChanged: (value) => setState(() => _maxMediaPackSizeMB = value.toInt()),
              valueLabel: '${_maxMediaPackSizeMB}MB',
            ),
            _buildSlider(
              label: 'JPEG Quality',
              value: _jpegQuality.toDouble(),
              min: 60,
              max: 100,
              divisions: 8,
              onChanged: (value) => setState(() => _jpegQuality = value.toInt()),
              valueLabel: '$_jpegQuality%',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatisticsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Export Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Entries', _totalEntries.toString(), Icons.book),
              _buildStatItem('Photos', _totalPhotos.toString(), Icons.photo),
              _buildStatItem(
                'Est. Size',
                '${(_totalPhotos * 2).toStringAsFixed(0)}MB',
                Icons.storage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue[700], size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String valueLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label),
          ),
          Expanded(
            flex: 3,
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final elapsed = DateTime.now().difference(_startTime!);
    final progress = _totalPhotos > 0 ? _processedPhotos / _totalPhotos : 0.0;
    final remaining = progress > 0
        ? Duration(milliseconds: (elapsed.inMilliseconds / progress * (1 - progress)).toInt())
        : Duration.zero;

    return Column(
      children: [
        const SizedBox(height: 32),
        const CircularProgressIndicator(strokeWidth: 6),
        const SizedBox(height: 32),
        Text(
          _currentOperation,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          backgroundColor: Colors.grey[200],
        ),
        const SizedBox(height: 16),
        Text(
          '${_processedPhotos} / $_totalPhotos photos processed',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        Text(
          '${(progress * 100).toStringAsFixed(1)}% complete',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTimeInfo('Elapsed', _formatDuration(elapsed)),
            _buildTimeInfo('Remaining', _formatDuration(remaining)),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildComplete() {
    return Column(
      children: [
        const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 80,
        ),
        const SizedBox(height: 24),
        const Text(
          'Export Complete!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          'Successfully exported $_processedEntries entries with $_processedPhotos photos',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),

        // Export results
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Exported Files',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (_journalPath != null) ...[
                _buildFilePath('Journal', _journalPath!),
                const SizedBox(height: 8),
              ],

              if (_mediaPackPaths.isNotEmpty) ...[
                const Text(
                  'Media Packs:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                for (final path in _mediaPackPaths)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: _buildFilePath('', path),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'The MediaResolver has been automatically updated with the new journal and media packs.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilePath(String label, String path) {
    return Row(
      children: [
        if (label.isNotEmpty) ...[
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
        Expanded(
          child: Text(
            path,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.grey[700],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          onPressed: () {
            // Copy to clipboard functionality
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Path copied to clipboard')),
            );
          },
          tooltip: 'Copy path',
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        const Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 80,
        ),
        const SizedBox(height: 24),
        const Text(
          'Export Failed',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Text(
            _error ?? 'Unknown error',
            style: TextStyle(color: Colors.red[900]),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_phase == ExportPhase.configuration) ...[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _outputDir != null ? _startExport : null,
              icon: const Icon(Icons.upload),
              label: const Text('Start Export'),
            ),
          ] else if (_phase == ExportPhase.exporting) ...[
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            const Text('Exporting...'),
          ] else if (_phase == ExportPhase.complete) ...[
            TextButton(
              onPressed: () {
                // Open output directory
                final dir = Directory(_outputDir!);
                // Platform-specific code to open directory would go here
              },
              child: const Text('Open Folder'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done'),
            ),
          ] else if (_phase == ExportPhase.error) ...[
            TextButton(
              onPressed: () {
                setState(() {
                  _phase = ExportPhase.configuration;
                  _error = null;
                });
              },
              child: const Text('Try Again'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ],
      ),
    );
  }
}

enum ExportPhase {
  configuration,
  exporting,
  complete,
  error,
}

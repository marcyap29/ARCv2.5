// lib/lumara/ui/model_download_screen.dart
// Model download screen with progress tracking

import 'package:flutter/material.dart';
import '../llm/bridge.pigeon.dart';
import '../llm/model_progress_service.dart';

class ModelDownloadScreen extends StatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen> {
  final LumaraNative _bridge = LumaraNative();
  final ModelProgressService _progressService = ModelProgressService();

  bool _isDownloading = false;
  bool _isDownloaded = false;
  double _downloadProgress = 0.0;
  String _statusMessage = '';
  String? _errorMessage;

  // Google Drive direct download URL (bypasses virus scan warning for large files)
  static const String _modelDownloadUrl =
      'https://drive.usercontent.google.com/download?id=12r9FgMRHz7ksmqPQd1zkwRf03NC-lOg8&export=download&confirm=t';
  static const String _modelId = 'qwen3-1.7b-mlx-4bit';
  static const String _modelName = 'Qwen3 1.7B MLX (4-bit)';
  static const String _modelSize = '~900 MB';

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
    _setupProgressListener();
  }

  Future<void> _checkModelStatus() async {
    try {
      final isDownloaded = await _bridge.isModelDownloaded(_modelId);
      if (mounted) {
        setState(() {
          _isDownloaded = isDownloaded;
          _statusMessage = isDownloaded
              ? 'Model ready to use'
              : 'Model not downloaded yet';
        });
      }
    } catch (e) {
      debugPrint('Error checking model status: $e');
    }
  }

  void _setupProgressListener() {
    _progressService.progressStream.listen((progress) {
      if (progress.modelId == _modelId && mounted) {
        setState(() {
          if (progress.message == 'Ready to use') {
            _isDownloading = false;
            _isDownloaded = true;
            _downloadProgress = 1.0;
            _statusMessage = 'Download complete!';
          }
        });
      }
    });
  }

  Future<void> _startDownload() async {
    try {
      setState(() {
        _isDownloading = true;
        _errorMessage = null;
        _downloadProgress = 0.0;
        _statusMessage = 'Starting download...';
      });

      final success = await _bridge.downloadModel(_modelId, _modelDownloadUrl);

      if (!success && mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Failed to start download';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }

  Future<void> _cancelDownload() async {
    try {
      await _bridge.cancelModelDownload();
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
          _statusMessage = 'Download cancelled';
        });
      }
    } catch (e) {
      debugPrint('Error cancelling download: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download AI Model'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Model Info Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.psychology, color: theme.colorScheme.primary, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _modelName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Size: $_modelSize',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isDownloaded)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.check_circle, color: Colors.green, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'DOWNLOADED',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      icon: Icons.security,
                      title: 'Privacy First',
                      subtitle: 'Runs entirely on your device',
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      icon: Icons.offline_bolt,
                      title: 'Works Offline',
                      subtitle: 'No internet needed after download',
                      theme: theme,
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      icon: Icons.speed,
                      title: 'Fast Responses',
                      subtitle: 'Optimized for Apple Silicon',
                      theme: theme,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Download Progress Card
            if (_isDownloading || _downloadProgress > 0)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Download Progress',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _downloadProgress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_isDownloading) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _cancelDownload,
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel Download'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Error Message
            if (_errorMessage != null)
              Card(
                elevation: 2,
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Download Button
            if (!_isDownloaded && !_isDownloading)
              ElevatedButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download, size: 24),
                label: const Text('Download Model'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // Info Text
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Important Information',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Requires $_modelSize of free storage\n'
                    '• Download only over WiFi recommended\n'
                    '• Model stays on your device permanently\n'
                    '• Can be deleted anytime from Settings',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

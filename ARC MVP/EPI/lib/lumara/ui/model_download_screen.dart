// lib/lumara/ui/model_download_screen.dart
// Model download screen with progress tracking

import 'package:flutter/material.dart';
import '../llm/bridge.pigeon.dart';
import '../llm/model_progress_service.dart';

// Model information data class
class ModelInfo {
  final String id;
  final String name;
  final String size;
  final String downloadUrl;
  final String description;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.size,
    required this.downloadUrl,
    required this.description,
  });
}

class ModelDownloadScreen extends StatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen> {
  final LumaraNative _bridge = LumaraNative();
  final ModelProgressService _progressService = ModelProgressService();

  // Available models for download
  static const List<ModelInfo> _availableModels = [
    ModelInfo(
      id: 'qwen3-1.7b-mlx-4bit',
      name: 'Qwen3 1.7B MLX (4-bit)',
      size: '~900 MB',
      downloadUrl: 'https://drive.usercontent.google.com/download?id=12r9FgMRHz7ksmqPQd1zkwRf03NC-lOg8&export=download&confirm=t',
      description: 'Fast and efficient for most tasks',
    ),
    ModelInfo(
      id: 'phi-3.5-mini-instruct-4bit',
      name: 'Phi-3.5-mini-instruct (4-bit)',
      size: '~2.1 GB',
      downloadUrl: 'https://drive.usercontent.google.com/download?id=16MqOfRVQHurRvPtD61WKU1XShad0nWZr&export=download&confirm=t',
      description: 'More capable, better for complex reasoning',
    ),
  ];

  // Track download state for each model
  final Map<String, bool> _isDownloading = {};
  final Map<String, bool> _isDownloaded = {};
  final Map<String, double> _downloadProgress = {};
  final Map<String, String> _statusMessage = {};
  final Map<String, String?> _errorMessage = {};

  @override
  void initState() {
    super.initState();
    _checkAllModelsStatus();
    _setupProgressListener();
  }

  Future<void> _checkAllModelsStatus() async {
    for (final model in _availableModels) {
      try {
        final isDownloaded = await _bridge.isModelDownloaded(model.id);
        if (mounted) {
          setState(() {
            _isDownloaded[model.id] = isDownloaded;
            _statusMessage[model.id] = isDownloaded
                ? 'Model ready to use'
                : 'Model not downloaded yet';
          });
        }
      } catch (e) {
        debugPrint('Error checking model status for ${model.id}: $e');
        if (mounted) {
          setState(() {
            _isDownloaded[model.id] = false;
            _statusMessage[model.id] = 'Error checking status';
          });
        }
      }
    }
  }

  void _setupProgressListener() {
    _progressService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          if (progress.message == 'Ready to use') {
            _isDownloading[progress.modelId] = false;
            _isDownloaded[progress.modelId] = true;
            _downloadProgress[progress.modelId] = 1.0;
            _statusMessage[progress.modelId] = 'Download complete!';
          }
        });
      }
    });
  }

  Future<void> _startDownload(ModelInfo model) async {
    try {
      setState(() {
        _isDownloading[model.id] = true;
        _errorMessage[model.id] = null;
        _downloadProgress[model.id] = 0.0;
        _statusMessage[model.id] = 'Starting download...';
      });

      final success = await _bridge.downloadModel(model.id, model.downloadUrl);

      if (!success && mounted) {
        setState(() {
          _isDownloading[model.id] = false;
          _errorMessage[model.id] = 'Failed to start download';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading[model.id] = false;
          _errorMessage[model.id] = 'Error: $e';
        });
      }
    }
  }

  Future<void> _cancelDownload(String modelId) async {
    try {
      await _bridge.cancelModelDownload();
      if (mounted) {
        setState(() {
          _isDownloading[modelId] = false;
          _downloadProgress[modelId] = 0.0;
          _statusMessage[modelId] = 'Download cancelled';
        });
      }
    } catch (e) {
      debugPrint('Error cancelling download: $e');
    }
  }

  Future<void> _deleteModel(String modelId) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Model'),
          content: const Text('Are you sure you want to delete this model? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Delete the model via bridge
      await _bridge.deleteModel(modelId);

      // Refresh status
      await _checkAllModelsStatus();

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Model deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting model: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download AI Models'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // Refresh model availability before returning
            await _checkAllModelsStatus();
            if (mounted) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Info
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
                                'On-Device AI Models',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Download models for privacy-first AI',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
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

            // Available Models List
            Text(
              'Available Models',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Render each model card
            ..._availableModels.map((model) => _buildModelCard(model, theme)),

            const SizedBox(height: 24),

            // Info Text
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
                    '• Download only over WiFi recommended\n'
                    '• Models stay on your device permanently\n'
                    '• Can be deleted anytime from Settings\n'
                    '• Larger models provide better responses',
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

  Widget _buildModelCard(ModelInfo model, ThemeData theme) {
    final isDownloaded = _isDownloaded[model.id] ?? false;
    final isDownloading = _isDownloading[model.id] ?? false;
    final progress = _downloadProgress[model.id] ?? 0.0;
    final status = _statusMessage[model.id] ?? '';
    final error = _errorMessage[model.id];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Model Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        model.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Size: ${model.size}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDownloaded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'READY',
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

            // Download Progress
            if (isDownloading) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    status,
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],

            // Error Message
            if (error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons
            const SizedBox(height: 16),
            if (!isDownloaded && !isDownloading)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _startDownload(model),
                  icon: const Icon(Icons.download, size: 20),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            else if (isDownloading)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelDownload(model.id),
                  icon: const Icon(Icons.cancel, size: 20),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              )
            else if (isDownloaded)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteModel(model.id),
                      icon: const Icon(Icons.delete, size: 20),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _checkAllModelsStatus(),
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
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

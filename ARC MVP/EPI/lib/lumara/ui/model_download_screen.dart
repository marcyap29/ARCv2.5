// lib/lumara/ui/model_download_screen.dart
// Model download screen with progress tracking

import 'package:flutter/material.dart';
import '../llm/bridge.pigeon.dart';
import '../services/download_state_service.dart';
import '../config/api_config.dart';

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
  final DownloadStateService _downloadStateService = DownloadStateService.instance;

  // Available GGUF models for download (llama.cpp + Metal)
  static const List<ModelInfo> _availableModels = [
    ModelInfo(
      id: 'Llama-3.2-3b-Instruct-Q4_K_M.gguf',
      name: 'Llama 3.2 3B Instruct (Q4_K_M)',
      size: '~1.9 GB',
      downloadUrl: 'https://huggingface.co/hugging-quants/Llama-3.2-3B-Instruct-Q4_K_M-GGUF/resolve/main/llama-3.2-3b-instruct-q4_k_m.gguf?download=true',
      description: 'Recommended: Fast, efficient, 4-bit quantized',
    ),
    ModelInfo(
      id: 'Phi-3.5-mini-instruct-Q5_K_M.gguf',
      name: 'Phi-3.5 Mini Instruct (Q5_K_M)',
      size: '~2.6 GB',
      downloadUrl: 'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q5_K_M.gguf?download=true',
      description: 'High quality, 5-bit quantized, excellent reasoning',
    ),
    ModelInfo(
      id: 'Qwen3-4B-Instruct-2507-Q5_K_M.gguf',
      name: 'Qwen3 4B Instruct (Q5_K_M)',
      size: '~2.3 GB',
      downloadUrl: 'https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q5_K_M.gguf?download=true',
      description: 'Multilingual, 5-bit quantized, great for diverse tasks',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkAllModelsStatus();
    _setupStateListener();
  }

  Future<void> _checkAllModelsStatus() async {
    for (final model in _availableModels) {
      try {
        final isDownloaded = await _bridge.isModelDownloaded(model.id);
        _downloadStateService.updateAvailability(model.id, isDownloaded);
      } catch (e) {
        debugPrint('Error checking model status for ${model.id}: $e');
        _downloadStateService.updateAvailability(model.id, false);
      }
    }
  }

  void _setupStateListener() {
    // Listen to download state changes and trigger UI rebuild
    _downloadStateService.addListener(_onDownloadStateChanged);
  }

  void _onDownloadStateChanged() {
    if (mounted) {
      setState(() {
        // State rebuild triggered by DownloadStateService
      });
    }
  }

  @override
  void dispose() {
    _downloadStateService.removeListener(_onDownloadStateChanged);
    super.dispose();
  }

  Future<void> _startDownload(ModelInfo model) async {
    try {
      // Update persistent state with model name
      _downloadStateService.startDownload(model.id, modelName: model.name);

      final success = await _bridge.downloadModel(model.id, model.downloadUrl);

      if (!success) {
        _downloadStateService.failDownload(model.id, 'Failed to start download');
      }
    } catch (e) {
      _downloadStateService.failDownload(model.id, 'Error: $e');
    }
  }

  Future<void> _cancelDownload(String modelId) async {
    try {
      // For now, use the general cancel method since the specific model cancel isn't in the bridge yet
      await _bridge.cancelModelDownload();
      _downloadStateService.cancelDownload(modelId);
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

      // Refresh status - both local and API config
      await _checkAllModelsStatus();
      await LumaraAPIConfig.instance.refreshModelAvailability();

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Model deleted successfully - provider status updated'),
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
    // Get state from persistent service
    final state = _downloadStateService.getState(model.id);
    final isDownloaded = state?.isDownloaded ?? false;
    final isDownloading = state?.isDownloading ?? false;
    final progress = state?.progress ?? 0.0;
    final status = state?.statusMessage ?? '';
    final error = state?.errorMessage;
    final downloadSizeText = state?.downloadSizeText ?? '';

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Only show status message if not downloaded (to hide "Download complete!" message)
                        if (!isDownloaded)
                          Text(
                            status,
                            style: theme.textTheme.bodySmall,
                          ),
                        if (downloadSizeText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            downloadSizeText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Ready',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _deleteModel(model.id),
                    icon: const Icon(Icons.delete, size: 20),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
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

import 'package:flutter/material.dart';

/// Card widget for displaying model information and actions
class ModelCard extends StatelessWidget {
  final String modelName;
  final String description;
  final bool isDownloaded;
  final bool isActive;
  final bool isDownloading;
  final double? downloadProgress;
  final VoidCallback onDownload;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  const ModelCard({
    super.key,
    required this.modelName,
    required this.description,
    required this.isDownloaded,
    required this.isActive,
    required this.isDownloading,
    this.downloadProgress,
    required this.onDownload,
    required this.onActivate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isActive ? 4 : 1,
      child: Container(
        decoration: isActive
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Model icon and name
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getModelColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getModelIcon(),
                            color: _getModelColor(),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getDisplayName(),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                description,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Status badge
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else if (isDownloaded)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Text(
                        'READY',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Download progress (if downloading)
              if (isDownloading) ...[
                LinearProgressIndicator(
                  value: downloadProgress,
                  backgroundColor: Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  downloadProgress != null
                      ? 'Downloading... ${(downloadProgress! * 100).toInt()}%'
                      : 'Preparing download...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Action buttons
              Row(
                children: [
                  if (!isDownloaded && !isDownloading)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onDownload,
                        icon: const Icon(Icons.download, size: 18),
                        label: Text(_getDownloadSize()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    )
                  else if (isDownloaded && !isActive)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onActivate,
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Activate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    )
                  else if (isActive)
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
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Currently Active',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  if (isDownloaded && !isDownloading) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      tooltip: 'Delete model',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDisplayName() {
    switch (modelName) {
      case 'Llama-3.2-3b-Instruct-Q4_K_M.gguf':
        return 'Llama 3.2 3B Instruct (Q4_K_M)';
      case 'Phi-3.5-mini-instruct-Q5_K_M.gguf':
        return 'Phi-3.5 Mini Instruct (Q5_K_M)';
      case 'Qwen3-4B-Instruct-2507-Q4_K_S.gguf':
        return 'Qwen3 4B Instruct (Q4_K_S)';
      // Legacy model names for backward compatibility
      case 'gemma-3-270m':
        return 'Gemma 3 (270M)';
      case 'gemma-3-1b':
        return 'Gemma 3 (1B)';
      case 'qwen2.5-1.5b':
        return 'Qwen 2.5 (1.5B)';
      case 'llama-3.2-1b':
        return 'Llama 3.2 (1B)';
      case 'phi-4':
        return 'Phi-4';
      default:
        return modelName;
    }
  }

  IconData _getModelIcon() {
    if (modelName.contains('gemma')) {
      return Icons.auto_awesome;
    } else if (modelName.contains('qwen')) {
      return Icons.psychology;
    } else if (modelName.contains('llama')) {
      return Icons.pets;
    } else if (modelName.contains('phi')) {
      return Icons.school;
    }
    return Icons.memory;
  }

  Color _getModelColor() {
    if (modelName.contains('gemma')) {
      return Colors.blue;
    } else if (modelName.contains('qwen')) {
      return Colors.purple;
    } else if (modelName.contains('llama')) {
      return Colors.orange;
    } else if (modelName.contains('phi')) {
      return Colors.green;
    }
    return Colors.grey;
  }

  String _getDownloadSize() {
    // GGUF model sizes - in a real implementation, these would come from the model metadata
    if (modelName.contains('Llama-3.2-3b-Instruct-Q4_K_M.gguf')) {
      return 'Download (~1.9GB)';
    } else if (modelName.contains('Phi-3.5-mini-instruct-Q5_K_M.gguf')) {
      return 'Download (~2.6GB)';
    } else if (modelName.contains('Qwen3-4B-Instruct-2507-Q4_K_S.gguf')) {
      return 'Download (~2.3GB)';
    }
    // Legacy model sizes for backward compatibility
    else if (modelName.contains('270m')) {
      return 'Download (~200MB)';
    } else if (modelName.contains('1b') || modelName.contains('1.5b')) {
      return 'Download (~1GB)';
    } else if (modelName.contains('phi-4')) {
      return 'Download (~2.5GB)';
    }
    return 'Download';
  }
}
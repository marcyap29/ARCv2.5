import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/chat/bloc/model_management_cubit.dart';
import 'package:my_app/arc/chat/ui/widgets/model_card.dart';
import 'package:my_app/arc/chat/ui/widgets/download_progress_dialog.dart';

/// Screen for managing AI models in LUMARA
class ModelManagementScreen extends StatefulWidget {
  const ModelManagementScreen({super.key});

  @override
  State<ModelManagementScreen> createState() => _ModelManagementScreenState();
}

class _ModelManagementScreenState extends State<ModelManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Load model information when screen opens
    try {
      print('LUMARA Debug: ModelManagementScreen initState');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          print('LUMARA Debug: Loading models');
          context.read<ModelManagementCubit>().loadModels();
        } catch (e, stackTrace) {
          print('LUMARA Debug: Error loading models: $e');
          print('LUMARA Debug: Stack trace: $stackTrace');
        }
      });
    } catch (e, stackTrace) {
      print('LUMARA Debug: Error in initState: $e');
      print('LUMARA Debug: Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Models'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ModelManagementCubit>().loadModels();
            },
          ),
        ],
      ),
      body: BlocConsumer<ModelManagementCubit, ModelManagementState>(
        listener: (context, state) {
          if (state is ModelManagementError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
          
          if (state is ModelDownloadComplete) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${state.modelName} downloaded successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ModelManagementLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is ModelManagementError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading models',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ModelManagementCubit>().loadModels();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is ModelManagementLoaded) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.psychology, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Offline AI Models',
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    Text(
                                      'Download models to enable advanced AI features',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (state.activeModel != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Active: ${state.activeModel}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.warning, size: 16, color: Colors.orange),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'No active model - using rule-based responses',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Available models section
                  Text(
                    'Available Models',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Model cards
                  ...state.availableModels.entries.map((entry) {
                    final modelName = entry.key;
                    final description = entry.value;
                    final isDownloaded = state.downloadedModels.contains(modelName);
                    final isActive = state.activeModel == modelName;
                    final isDownloading = state.downloadingModel == modelName;
                    final downloadProgress = state.downloadProgress;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ModelCard(
                        modelName: modelName,
                        description: description,
                        isDownloaded: isDownloaded,
                        isActive: isActive,
                        isDownloading: isDownloading,
                        downloadProgress: downloadProgress,
                        onDownload: () => _downloadModel(context, modelName),
                        onActivate: () => _activateModel(context, modelName),
                        onDelete: () => _deleteModel(context, modelName),
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 24),
                  
                  // Info section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline),
                              const SizedBox(width: 8),
                              Text(
                                'About AI Models',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '• Models run entirely on your device for privacy\n'
                            '• Larger models provide better responses but use more storage\n'
                            '• Download requires internet, but usage is offline\n'
                            '• You can switch between models anytime',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return const Center(
            child: Text('Unknown state'),
          );
        },
      ),
    );
  }

  void _downloadModel(BuildContext context, String modelName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<ModelManagementCubit>(),
        child: DownloadProgressDialog(modelName: modelName),
      ),
    );
    
    context.read<ModelManagementCubit>().downloadModel(modelName);
  }

  void _activateModel(BuildContext context, String modelName) {
    context.read<ModelManagementCubit>().activateModel(modelName);
  }

  void _deleteModel(BuildContext context, String modelName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete $modelName? This will free up storage space but you\'ll need to download it again to use it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<ModelManagementCubit>().deleteModel(modelName);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
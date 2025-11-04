import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/arc/chat/bloc/model_management_cubit.dart';

/// Dialog showing download progress for AI models
class DownloadProgressDialog extends StatelessWidget {
  final String modelName;

  const DownloadProgressDialog({
    super.key,
    required this.modelName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<ModelManagementCubit, ModelManagementState>(
      listener: (context, state) {
        if (state is ModelDownloadComplete && state.modelName == modelName) {
          Navigator.of(context).pop();
        } else if (state is ModelManagementError) {
          Navigator.of(context).pop();
          // Show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: ${state.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      child: AlertDialog(
        title: Text('Downloading ${_getDisplayName()}'),
        content: BlocBuilder<ModelManagementCubit, ModelManagementState>(
          builder: (context, state) {
            double? progress;
            String statusText = 'Preparing download...';

            if (state is ModelManagementLoaded) {
              progress = state.downloadProgress;
              statusText = 'Downloading... ${((progress ?? 0.0) * 100).toInt()}%';
                        }

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      'This may take several minutes depending on your connection.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Note: In a full implementation, this would cancel the download
            },
            child: const Text('Cancel'),
          ),
        ],
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
}
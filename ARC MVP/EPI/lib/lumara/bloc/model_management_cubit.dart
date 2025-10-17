import 'package:flutter_bloc/flutter_bloc.dart';

/// Model Management States
abstract class ModelManagementState {}

class ModelManagementInitial extends ModelManagementState {}

class ModelManagementLoading extends ModelManagementState {}

class ModelManagementLoaded extends ModelManagementState {
  final Map<String, String> availableModels;
  final List<String> downloadedModels;
  final String? activeModel;
  final String? downloadingModel;
  final double? downloadProgress;

  ModelManagementLoaded({
    required this.availableModels,
    required this.downloadedModels,
    this.activeModel,
    this.downloadingModel,
    this.downloadProgress,
  });

  ModelManagementLoaded copyWith({
    Map<String, String>? availableModels,
    List<String>? downloadedModels,
    String? activeModel,
    String? downloadingModel,
    double? downloadProgress,
    bool clearDownloading = false,
  }) {
    return ModelManagementLoaded(
      availableModels: availableModels ?? this.availableModels,
      downloadedModels: downloadedModels ?? this.downloadedModels,
      activeModel: activeModel ?? this.activeModel,
      downloadingModel: clearDownloading ? null : (downloadingModel ?? this.downloadingModel),
      downloadProgress: clearDownloading ? null : (downloadProgress ?? this.downloadProgress),
    );
  }
}

class ModelManagementError extends ModelManagementState {
  final String message;
  
  ModelManagementError(this.message);
}

class ModelDownloadComplete extends ModelManagementState {
  final String modelName;
  
  ModelDownloadComplete(this.modelName);
}

/// Cubit for managing AI model downloads and activation
class ModelManagementCubit extends Cubit<ModelManagementState> {
  ModelManagementCubit() : super(ModelManagementInitial());

  /// Load available models and their status
  Future<void> loadModels() async {
    try {
      print('LUMARA Debug: ModelManagementCubit.loadModels() called');
      emit(ModelManagementLoading());
      
      // GGUF model information (llama.cpp + Metal)
      print('LUMARA Debug: Getting GGUF model info');
  final availableModels = <String, String>{
    'Llama-3.2-3b-Instruct-Q4_K_M.gguf': 'Llama 3.2 3B Instruct (Q4_K_M) - Recommended: Fast, efficient, 4-bit quantized',
    'Qwen3-4B-Instruct-2507-Q4_K_S.gguf': 'Qwen3 4B Instruct (Q4_K_S) - Multilingual, 4-bit quantized, excellent reasoning capabilities',
    'rule_based': 'Rule-based responses (no model required)',
  };
      print('LUMARA Debug: Available models: $availableModels');
      
      // Currently using rule-based adapter only
      const isAiEnabled = false;
      const currentModel = 'rule_based';
      
      // For now, we don't have actual downloaded models - they need to be manually installed
      final downloadedModels = <String>[];
      const activeModel = isAiEnabled ? currentModel : null;

      print('LUMARA Debug: Available models: $availableModels');
      print('LUMARA Debug: Downloaded models: $downloadedModels');
      print('LUMARA Debug: Active model: $activeModel');

      emit(ModelManagementLoaded(
        availableModels: availableModels,
        downloadedModels: downloadedModels,
        activeModel: activeModel,
      ));
      
      print('LUMARA Debug: ModelManagementLoaded state emitted successfully');
    } catch (e, stackTrace) {
      print('LUMARA Debug: Error in loadModels: $e');
      print('LUMARA Debug: Stack trace: $stackTrace');
      emit(ModelManagementError('Failed to load models: $e'));
    }
  }

  /// Download a model with progress tracking
  Future<void> downloadModel(String modelName) async {
    final currentState = state;
    if (currentState is! ModelManagementLoaded) return;

    try {
      // Update state to show download in progress
      emit(currentState.copyWith(
        downloadingModel: modelName,
        downloadProgress: 0.0,
      ));

      // For now, model downloads are not supported in the new adapter pattern
      // The app will automatically use the best available model
      const success = false; // No actual download - models need to be manually installed

      if (success) {
        // Update downloaded models list
        final updatedDownloaded = [...currentState.downloadedModels];
        if (!updatedDownloaded.contains(modelName)) {
          updatedDownloaded.add(modelName);
        }

        // Show success and return to normal state
        emit(ModelDownloadComplete(modelName));
        
        // Wait a moment then return to loaded state with updated models
        await Future.delayed(const Duration(milliseconds: 500));
        
        emit(ModelManagementLoaded(
          availableModels: currentState.availableModels,
          downloadedModels: updatedDownloaded,
          activeModel: currentState.activeModel,
        ));
      } else {
        // Handle download failure
        emit(ModelManagementError('Model downloads not available. Please install model files manually. See setup guide for details.'));
        
        // Return to loaded state after error
        await Future.delayed(const Duration(seconds: 2));
        emit(currentState.copyWith(clearDownloading: true));
      }
    } catch (e) {
      // Handle exceptions
      emit(ModelManagementError('Download error: $e'));
      
      // Return to loaded state after error
      await Future.delayed(const Duration(seconds: 2));
      emit(currentState.copyWith(clearDownloading: true));
    }
  }

  /// Activate a model for use in LUMARA
  Future<void> activateModel(String modelName) async {
    final currentState = state;
    if (currentState is! ModelManagementLoaded) return;

    try {
      emit(ModelManagementLoading());

      // Model activation using llama.cpp
      final success = modelName == 'rule_based'; // Only rule-based model available

      if (success) {
        emit(currentState.copyWith(activeModel: modelName));
      } else {
        emit(ModelManagementError('Failed to activate $modelName'));
        emit(currentState);
      }
    } catch (e) {
      emit(ModelManagementError('Activation error: $e'));
      emit(currentState);
    }
  }

  /// Delete a downloaded model
  Future<void> deleteModel(String modelName) async {
    final currentState = state;
    if (currentState is! ModelManagementLoaded) return;

    try {
      // For now, just remove from the downloaded list
      // In a full implementation, this would delete the actual model file
      final updatedDownloaded = currentState.downloadedModels
          .where((model) => model != modelName)
          .toList();

      String? newActiveModel = currentState.activeModel;
      if (currentState.activeModel == modelName) {
        // If deleting the active model, deactivate it
        newActiveModel = null;
        // Model disposal using llama.cpp
      }

      emit(currentState.copyWith(
        downloadedModels: updatedDownloaded,
        activeModel: newActiveModel,
      ));
    } catch (e) {
      emit(ModelManagementError('Failed to delete $modelName: $e'));
      emit(currentState);
    }
  }

  /// Get current model status for display
  String getModelStatus() {
    final currentState = state;
    if (currentState is ModelManagementLoaded) {
      if (currentState.activeModel != null) {
        return 'Active: ${currentState.activeModel}';
      } else {
        return 'Using rule-based responses (no AI model loaded)';
      }
    }
    return 'Loading...';
  }

  /// Check if any model is active
  bool get hasActiveModel {
    final currentState = state;
    return currentState is ModelManagementLoaded && currentState.activeModel != null;
  }
}
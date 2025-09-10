import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/lumara/llm/qwen_service.dart';

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
      
      // Get model information from QwenService
      print('LUMARA Debug: Getting model info from QwenService');
      final availableModels = QwenService.availableModels;
      final status = QwenService.getStatus();
      print('LUMARA Debug: Available models: $availableModels');
      print('LUMARA Debug: Service status: $status');
      
      // Check if AI is enabled (not rule-based)
      final isAiEnabled = status['aiInferenceEnabled'] as bool? ?? false;
      final currentModel = status['currentModel'] as String?;
      final adapterType = status['adapterType'] as String?;
      
      // For now, we don't have actual downloaded models - they need to be manually installed
      final downloadedModels = <String>[];
      final activeModel = isAiEnabled ? currentModel : null;

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
      final success = false; // No actual download - models need to be manually installed

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

      // Initialize the model in QwenService
      final success = await QwenService.initialize();

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
        await QwenService.dispose();
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
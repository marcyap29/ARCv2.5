import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../../core/app_flags.dart';

/// Native bridge for LUMARA Qwen models
/// Provides unified interface for chat, vision, and embedding models
class LumaraNative {
  static const _channel = MethodChannel('lumara_native');

  /// Initialize chat model (Qwen3-4B-Instruct or 1.7B fallback)
  static Future<bool> initChatModel({
    required String modelPath,
    GenParams? params,
  }) async {
    final args = {
      'modelPath': modelPath,
      if (params != null) ...params.toMap(),
    };
    
    return await _channel.invokeMethod<bool>('initChatModel', args) ?? false;
  }

  /// Generate text response using Qwen chat model
  static Future<String> qwenText(String prompt) async {
    final result = await _channel.invokeMethod<String>('qwenText', {
      'prompt': prompt,
    });
    return result ?? '';
  }

  /// Generate streaming text response (returns stream of partial responses)
  static Stream<String> qwenTextStream(String prompt) async* {
    // For now, return single response - streaming can be added later
    final result = await qwenText(prompt);
    yield result;
  }

  /// Initialize vision-language model (Qwen2.5-VL-3B or 2B fallback)
  static Future<bool> initVisionModel({
    required String modelPath,
    GenParams? params,
  }) async {
    final args = {
      'modelPath': modelPath,
      if (params != null) ...params.toMap(),
    };
    
    return await _channel.invokeMethod<bool>('initVisionModel', args) ?? false;
  }

  /// Ask vision model about an image
  static Future<String> qwenVision({
    required String prompt,
    required Uint8List imageJpeg,
  }) async {
    final result = await _channel.invokeMethod<String>('qwenVision', {
      'prompt': prompt,
      'imageJpeg': imageJpeg,
    });
    return result ?? '';
  }

  /// Initialize embedding model (Qwen3-Embedding-0.6B)
  static Future<bool> initEmbeddingModel({
    required String modelPath,
  }) async {
    return await _channel.invokeMethod<bool>('initEmbeddingModel', {
      'modelPath': modelPath,
    }) ?? false;
  }

  /// Generate embeddings for text
  static Future<List<double>> embedText(String text) async {
    final result = await _channel.invokeMethod<List<dynamic>>('embedText', {
      'text': text,
    });
    return result?.map((e) => (e as num).toDouble()).toList() ?? const [];
  }

  /// Generate embeddings for multiple texts (batch processing)
  static Future<List<List<double>>> embedTextBatch(List<String> texts) async {
    final result = await _channel.invokeMethod<List<dynamic>>('embedTextBatch', {
      'texts': texts,
    });
    
    if (result == null) return [];
    
    return result.map((batch) => 
      (batch as List<dynamic>).map((e) => (e as num).toDouble()).toList()
    ).toList();
  }

  /// Check device RAM and recommend models
  static Future<DeviceCapabilities> getDeviceCapabilities() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDeviceCapabilities');
    
    if (result == null) {
      return const DeviceCapabilities(
        totalRamMB: 4096,
        availableRamMB: 2048,
        recommendedChatModel: QwenModel.qwen3_1p7b_instruct,
        recommendedVlmModel: QwenModel.qwen2_vl_2b_instruct,
        canRunEmbeddings: true,
      );
    }
    
    final totalRamMB = result['totalRamMB'] as int? ?? 4096;
    final availableRamMB = result['availableRamMB'] as int? ?? 2048;
    
    // Recommend models based on available RAM
    QwenModel recommendedChat = totalRamMB >= AppFlags.minRamForQwen4B * 1024
        ? QwenModel.qwen3_4b_instruct 
        : QwenModel.qwen3_1p7b_instruct;
        
    QwenModel recommendedVlm = totalRamMB >= AppFlags.minRamForQwenVL3B * 1024
        ? QwenModel.qwen2p5_vl_3b_instruct 
        : QwenModel.qwen2_vl_2b_instruct;
    
    return DeviceCapabilities(
      totalRamMB: totalRamMB,
      availableRamMB: availableRamMB,
      recommendedChatModel: recommendedChat,
      recommendedVlmModel: recommendedVlm,
      canRunEmbeddings: totalRamMB >= 2 * 1024, // 2GB minimum for embeddings
    );
  }

  /// Check if specific model is ready for inference
  static Future<bool> isModelReady(String modelType) async {
    return await _channel.invokeMethod<bool>('isModelReady', {
      'modelType': modelType,
    }) ?? false;
  }

  /// Get model loading progress (for UI progress indicators)
  static Future<double> getModelLoadingProgress(String modelType) async {
    return await _channel.invokeMethod<double>('getModelLoadingProgress', {
      'modelType': modelType,
    }) ?? 0.0;
  }

  /// Unload models to free memory
  static Future<void> dispose() async {
    await _channel.invokeMethod('dispose');
  }

  /// Switch runtime (llama.cpp vs MLC LLM)
  static Future<bool> switchRuntime(LlmRuntime runtime) async {
    return await _channel.invokeMethod<bool>('switchRuntime', {
      'runtime': runtime.name,
    }) ?? false;
  }

  /// Get current runtime information
  static Future<RuntimeInfo> getRuntimeInfo() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getRuntimeInfo');
    
    if (result == null) {
      return const RuntimeInfo(
        runtime: LlmRuntime.llamacpp,
        version: 'unknown',
        supportedModels: [],
      );
    }
    
    return RuntimeInfo(
      runtime: LlmRuntime.values.firstWhere(
        (r) => r.name == result['runtime'],
        orElse: () => LlmRuntime.llamacpp,
      ),
      version: result['version'] as String? ?? 'unknown',
      supportedModels: (result['supportedModels'] as List<dynamic>?)
          ?.cast<String>() ?? [],
    );
  }
}

/// Device capabilities for model recommendation
class DeviceCapabilities {
  final int totalRamMB;
  final int availableRamMB;
  final QwenModel recommendedChatModel;
  final QwenModel recommendedVlmModel;
  final bool canRunEmbeddings;

  const DeviceCapabilities({
    required this.totalRamMB,
    required this.availableRamMB,
    required this.recommendedChatModel,
    required this.recommendedVlmModel,
    required this.canRunEmbeddings,
  });

  /// Get total RAM in GB
  double get totalRamGB => totalRamMB / 1024.0;

  /// Get available RAM in GB  
  double get availableRamGB => availableRamMB / 1024.0;

  /// Check if device can run 4B models
  bool get canRun4BModels => totalRamGB >= AppFlags.minRamForQwen4B;

  /// Check if device can run 3B VLM
  bool get canRun3BVLM => totalRamGB >= AppFlags.minRamForQwenVL3B;
}

/// Runtime information
class RuntimeInfo {
  final LlmRuntime runtime;
  final String version;
  final List<String> supportedModels;

  const RuntimeInfo({
    required this.runtime,
    required this.version,
    required this.supportedModels,
  });
}
import 'package:flutter/services.dart';

class LlmBridgeAdapter {
  static const _channel = MethodChannel('epi.llm/bridge');

  Future<String> getModelRootPath() async {
    final path = await _channel.invokeMethod<String>('getModelRootPath');
    if (path == null || path.isEmpty) {
      throw StateError('Model root path unavailable');
    }
    return path;
  }

  Future<Map<String, dynamic>> listModels() async {
    final res = await _channel.invokeMethod<dynamic>('listModels');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<String> getActiveModelPath(String modelId) async {
    final path = await _channel.invokeMethod<String>('getActiveModelPath', {
      'modelId': modelId,
    });
    if (path == null || path.isEmpty) {
      throw StateError('Active model path unavailable for $modelId');
    }
    return path;
  }

  Future<void> setActiveModel(String modelId) async {
    await _channel.invokeMethod('setActiveModel', {'modelId': modelId});
  }

  Future<void> startModel(String modelId) async {
    await _channel.invokeMethod('startModel', {'modelId': modelId});
  }

  Future<void> stopModel() async {
    await _channel.invokeMethod('stopModel');
  }

  Future<String> generateText(String prompt) async {
    final response = await _channel.invokeMethod<String>('generateText', {
      'prompt': prompt,
    });
    if (response == null || response.isEmpty) {
      throw StateError('Text generation failed');
    }
    return response;
  }

  // Download methods
  Future<void> downloadModel({
    required String modelId,
    required String url,
    String? sha256,
    bool isDirectoryFormat = true,
  }) async {
    await _channel.invokeMethod('downloadModel', {
      'modelId': modelId,
      'url': url,
      'sha256': sha256,
      'isDirectoryFormat': isDirectoryFormat,
    });
  }

  // Progress EventChannel name must match Swift
  static String progressChannelName(String modelId) => 'epi.llm/download/$modelId';

  Future<void> cancelDownload(String modelId) async {
    await _channel.invokeMethod('cancelDownload', {'modelId': modelId});
  }

  // Model status checking
  Future<Map<String, dynamic>> getModelStatus(String modelId) async {
    final result = await _channel.invokeMethod('getModelStatus', {'modelId': modelId});
    return Map<String, dynamic>.from(result as Map);
  }
}

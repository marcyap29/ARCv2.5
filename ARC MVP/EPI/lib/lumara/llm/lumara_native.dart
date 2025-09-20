// lib/lumara/llm/lumara_native.dart
// Stub native bridge for LUMARA on-device models. Provides a safe fallback
// so the app compiles and runs without native plugins.

import 'dart:async';
import '../../core/app_flags.dart';

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

  double get totalRamGB => totalRamMB / 1024.0;
}

class LumaraNative {
  static Future<DeviceCapabilities> getDeviceCapabilities() async {
    // Provide conservative defaults; real implementation supplied by platform.
    return const DeviceCapabilities(
      totalRamMB: 4096,
      availableRamMB: 2048,
      recommendedChatModel: QwenModel.qwen2p5_1p5b_instruct,
      recommendedVlmModel: QwenModel.qwen2_vl_2b_instruct,
      canRunEmbeddings: true,
    );
  }

  static Future<bool> initChatModel({
    required String modelPath,
    required GenParams params,
  }) async {
    // Return false to indicate native path not active; upstream will fallback.
    return false;
  }

  static Future<String> qwenText(String prompt) async {
    // Minimal placeholder response when native bridge is unavailable.
    return '[[native-bridge-unavailable]]';
  }

  static Future<void> dispose() async {}
}



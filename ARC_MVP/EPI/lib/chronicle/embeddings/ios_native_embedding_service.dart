// lib/chronicle/embeddings/ios_native_embedding_service.dart

import 'package:flutter/services.dart';
import 'embedding_service.dart';

/// On-device embeddings on iOS using Apple Natural Language (NLEmbedding.sentenceEmbedding).
/// 512-dim, no TFLite required. Use when [createEmbeddingService] selects iOS native.
class IOSNativeEmbeddingService extends EmbeddingService {
  static const _channel = MethodChannel('com.epi.arcmvp/embedding');

  bool? _available;

  @override
  Future<void> initialize() async {
    if (_available != null) return;
    try {
      final v = await _channel.invokeMethod<bool>('isAvailable');
      _available = v ?? false;
    } catch (_) {
      _available = false;
    }
  }

  bool get isAvailable => _available == true;

  @override
  Future<List<double>> embed(String text) async {
    if (_available == null) await initialize();
    if (_available != true) {
      throw StateError('iOS native embedding is not available');
    }
    final list = await _channel.invokeMethod<List<Object?>>('embed', text);
    if (list == null) throw StateError('embed returned null');
    return list.map((e) => (e as num).toDouble()).toList();
  }
}

// lib/chronicle/embeddings/create_embedding_service.dart

import 'dart:io' show Platform;

import 'embedding_service.dart';
import 'ios_native_embedding_service.dart';
import 'local_embedding_service.dart';

/// Creates an on-device embedding service for the current platform.
///
/// - **iOS**: Tries Apple Natural Language (NLEmbedding.sentenceEmbedding) first;
///   if available, uses it (no TFLite). Otherwise falls back to TFLite (may fail on device).
/// - **Android**: Uses TFLite (Universal Sentence Encoder).
///
/// Call [EmbeddingService.initialize] on the returned instance before use.
Future<EmbeddingService> createEmbeddingService() async {
  if (Platform.isIOS) {
    final native = IOSNativeEmbeddingService();
    await native.initialize();
    if (native.isAvailable) {
      return native;
    }
  }
  return LocalEmbeddingService();
}

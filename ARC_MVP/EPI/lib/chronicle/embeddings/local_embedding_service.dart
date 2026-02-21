// lib/chronicle/embeddings/local_embedding_service.dart

import 'dart:math' show sqrt;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'embedding_service.dart';

/// Generates semantic embeddings entirely on-device via TensorFlow Lite.
/// Model: Universal Sentence Encoder Lite (512 dimensions)
/// Performance: <100ms per embedding on mid-range phones
class LocalEmbeddingService extends EmbeddingService {
  Interpreter? _interpreter;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/universal_sentence_encoder.tflite',
        options: InterpreterOptions()
          ..threads = 4
          ..useNnApiForAndroid = true,
      );

      _initialized = true;
      // ignore: avoid_print
      print('✓ Local embedding service initialized');
      // ignore: avoid_print
      print('   Input shape: ${_interpreter!.getInputTensor(0).shape}');
      // ignore: avoid_print
      print('   Output shape: ${_interpreter!.getOutputTensor(0).shape}');
    } catch (e) {
      // ignore: avoid_print
      print('✗ Error initializing embedding service: $e');
      rethrow;
    }
  }

  /// Generate 512-dimensional embedding for text
  Future<List<double>> embed(String text) async {
    if (!_initialized) await initialize();

    // Universal Sentence Encoder takes raw strings as input
    // No manual tokenization needed!

    final input = [text]; // Just wrap string in array
    final dim = EmbeddingService.embeddingDimension;
    final output = _reshape2D(List<double>.filled(dim, 0.0), 1, dim);

    _interpreter!.run(input, output);

    final embedding = (output[0] as List).cast<double>();
    return _normalize(embedding);
  }

  /// L2-normalize embedding for cosine similarity.
  static List<double> _normalize(List<double> v) {
    final norm = sqrt(v.fold<double>(0, (s, x) => s + x * x));
    if (norm == 0) return v;
    return v.map((x) => x / norm).toList();
  }

  /// Batch embed multiple texts
  Future<Map<String, List<double>>> embedBatch(List<String> texts) async {
    final results = <String, List<double>>{};

    for (final text in texts) {
      results[text] = await embed(text);
    }

    return results;
  }

  @override
  double cosineSimilarity(List<double> embedding1, List<double> embedding2) {
    assert(embedding1.length == embedding2.length);

    double dotProduct = 0.0;
    for (var i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }

    return dotProduct;
  }

  void dispose() {
    _interpreter?.close();
    _initialized = false;
  }
}

/// 2D reshape for TFLite output buffer (avoids conflict with tflite_flutter's reshape).
List<List<double>> _reshape2D(List<double> flat, int rows, int cols) {
  final result = <List<double>>[];
  for (var i = 0; i < rows; i++) {
    final start = i * cols;
    final end = start + cols;
    result.add(flat.sublist(start, end));
  }
  return result;
}

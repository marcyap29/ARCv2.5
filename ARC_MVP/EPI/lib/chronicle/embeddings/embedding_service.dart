// lib/chronicle/embeddings/embedding_service.dart

/// Abstraction for on-device text embedding services (TFLite, iOS Natural Language, etc.).
abstract class EmbeddingService {
  static const int embeddingDimension = 512;

  int get dimension => embeddingDimension;

  Future<void> initialize() async {}

  Future<List<double>> embed(String text);

  Future<Map<String, List<double>>> embedBatch(List<String> texts) async {
    final results = <String, List<double>>{};
    for (final text in texts) {
      results[text] = await embed(text);
    }
    return results;
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }

  void dispose() {}
}

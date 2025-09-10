import 'dart:math';
import '../llm/lumara_native.dart';
import '../../core/app_flags.dart';

/// Qwen3-Embedding adapter for semantic search and RAG
class QwenEmbeddingAdapter {
  static bool _isInitialized = false;
  static int _embeddingDimensions = 512; // Qwen3-Embedding-0.6B default
  
  /// Initialize the Qwen embedding adapter
  static Future<bool> initialize() async {
    try {
      final deviceCaps = await LumaraNative.getDeviceCapabilities();
      
      if (!deviceCaps.canRunEmbeddings) {
        print('QwenEmbeddingAdapter: Device does not meet minimum requirements for embeddings');
        return false;
      }
      
      final modelConfig = modelConfigs[QwenModel.qwen3_embedding_0p6b]!;
      final modelPath = 'assets/models/qwen/${modelConfig.filename}';
      
      print('QwenEmbeddingAdapter: Initializing ${modelConfig.displayName}');
      print('  Model size: ${modelConfig.estimatedSizeMB}MB');
      print('  Expected dimensions: $_embeddingDimensions');
      
      final success = await LumaraNative.initEmbeddingModel(
        modelPath: modelPath,
      );
      
      if (success) {
        _isInitialized = true;
        print('QwenEmbeddingAdapter: Successfully initialized');
        return true;
      } else {
        print('QwenEmbeddingAdapter: Failed to initialize model');
        return false;
      }
    } catch (e) {
      print('QwenEmbeddingAdapter: Initialization error - $e');
      return false;
    }
  }
  
  /// Check if embedding adapter is ready
  static bool get isReady => _isInitialized;
  
  /// Get embedding dimensions
  static int get dimensions => _embeddingDimensions;

  /// Generate embeddings for a single text
  static Future<List<double>> embedText(String text) async {
    if (!isReady) {
      print('QwenEmbeddingAdapter: Not initialized');
      return [];
    }

    if (text.trim().isEmpty) {
      print('QwenEmbeddingAdapter: Empty text provided');
      return [];
    }

    try {
      // Clean and prepare text
      final cleanText = _preprocessText(text);
      
      print('QwenEmbeddingAdapter: Embedding text: ${cleanText.substring(0, 50)}...');

      final embeddings = await LumaraNative.embedText(cleanText);
      
      if (embeddings.isEmpty) {
        print('QwenEmbeddingAdapter: Received empty embeddings');
        return [];
      }
      
      // Update dimensions if needed
      if (embeddings.length != _embeddingDimensions) {
        _embeddingDimensions = embeddings.length;
        print('QwenEmbeddingAdapter: Updated embedding dimensions to $_embeddingDimensions');
      }
      
      return embeddings;
    } catch (e) {
      print('QwenEmbeddingAdapter: Error embedding text - $e');
      return [];
    }
  }

  /// Generate embeddings for multiple texts (batch processing)
  static Future<List<List<double>>> embedTextBatch(List<String> texts) async {
    if (!isReady) {
      print('QwenEmbeddingAdapter: Not initialized');
      return [];
    }

    if (texts.isEmpty) {
      return [];
    }

    try {
      // Clean and prepare texts
      final cleanTexts = texts.map(_preprocessText).toList();
      
      print('QwenEmbeddingAdapter: Embedding ${cleanTexts.length} texts in batch');

      final batchEmbeddings = await LumaraNative.embedTextBatch(cleanTexts);
      
      if (batchEmbeddings.isNotEmpty && batchEmbeddings.first.isNotEmpty) {
        // Update dimensions if needed
        final firstEmbeddingLength = batchEmbeddings.first.length;
        if (firstEmbeddingLength != _embeddingDimensions) {
          _embeddingDimensions = firstEmbeddingLength;
          print('QwenEmbeddingAdapter: Updated embedding dimensions to $_embeddingDimensions');
        }
      }
      
      return batchEmbeddings;
    } catch (e) {
      print('QwenEmbeddingAdapter: Error in batch embedding - $e');
      return [];
    }
  }

  /// Compute cosine similarity between two embeddings
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    normA = sqrt(normA);
    normB = sqrt(normB);

    if (normA == 0.0 || normB == 0.0) return 0.0;

    return dotProduct / (normA * normB);
  }

  /// Find most similar embeddings to a query embedding
  static List<SimilarityResult> findSimilar(
    List<double> queryEmbedding,
    List<EmbeddingEntry> candidates, {
    int topK = 10,
    double threshold = 0.3,
  }) {
    if (queryEmbedding.isEmpty || candidates.isEmpty) return [];

    final results = <SimilarityResult>[];

    for (final candidate in candidates) {
      if (candidate.embedding.isEmpty) continue;

      final similarity = cosineSimilarity(queryEmbedding, candidate.embedding);
      
      if (similarity >= threshold) {
        results.add(SimilarityResult(
          entry: candidate,
          similarity: similarity,
        ));
      }
    }

    // Sort by similarity (descending) and take top K
    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    
    return results.take(topK).toList();
  }

  /// Preprocess text for embedding
  static String _preprocessText(String text) {
    // Basic text cleaning
    return text
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .replaceAll(RegExp(r'[^\w\s.,!?;:]'), '') // Remove special chars except basic punctuation
        .substring(0, text.length > 512 ? 512 : text.length); // Limit length
  }

  /// Get embedding model status and statistics
  static Map<String, dynamic> getStatus() {
    return {
      'initialized': _isInitialized,
      'dimensions': _embeddingDimensions,
      'model': 'Qwen3-Embedding-0.6B',
      'ready': isReady,
    };
  }
  
  /// Dispose of resources
  static Future<void> dispose() async {
    _isInitialized = false;
    _embeddingDimensions = 512; // Reset to default
    print('QwenEmbeddingAdapter: Disposed');
  }
}

/// Represents a text entry with its embedding
class EmbeddingEntry {
  final String id;
  final String text;
  final List<double> embedding;
  final Map<String, dynamic>? metadata;

  const EmbeddingEntry({
    required this.id,
    required this.text,
    required this.embedding,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'embedding': embedding,
    'metadata': metadata,
  };

  factory EmbeddingEntry.fromJson(Map<String, dynamic> json) => EmbeddingEntry(
    id: json['id'] as String,
    text: json['text'] as String,
    embedding: (json['embedding'] as List<dynamic>)
        .map((e) => (e as num).toDouble())
        .toList(),
    metadata: json['metadata'] as Map<String, dynamic>?,
  );
}

/// Result of similarity search
class SimilarityResult {
  final EmbeddingEntry entry;
  final double similarity;

  const SimilarityResult({
    required this.entry,
    required this.similarity,
  });

  @override
  String toString() => 'SimilarityResult(id: ${entry.id}, similarity: ${similarity.toStringAsFixed(3)})';
}
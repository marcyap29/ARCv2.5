// lib/chronicle/search/chronicle_search.dart
//
// LUMARA CHRONICLE search: models and feature-based reranking.
// When HybridSearchEngine (BM25 + semantic + RRF) is implemented,
// pass its results to FeatureBasedReranker for optional reranking.

export 'adaptive_fusion_engine.dart';
export 'bm25_index.dart';
export 'chronicle_rerank_service.dart';
export 'chronicle_search_models.dart';
export 'feature_based_reranker.dart';
export 'hybrid_search_engine.dart';
export 'rerank_context_builder.dart';
export 'semantic_index.dart';

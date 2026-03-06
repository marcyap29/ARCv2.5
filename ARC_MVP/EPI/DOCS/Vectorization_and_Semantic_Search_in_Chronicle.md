# Vectorization and Semantic Search in Chronicle

This document describes the **vectorization algorithm** used in the ARC Chronicle system, how it integrates with **Chronicle** (pattern index and entry-level search), and the **interplay between vectorization and semantic search** for data retrieval.

---

## 1. Overview

Chronicle uses **two distinct vectorization flows**:

| Flow | What is vectorized | Stored? | Purpose |
|------|--------------------|--------|---------|
| **Pattern index** | Theme summaries (from monthly synthesis) | Yes (ChronicleIndex JSON) | Cross-temporal pattern recognition, theme clustering, related entries |
| **Entry-level search** | Raw entry content (Layer 0) | No (in-memory cache) | Hybrid search (BM25 + semantic) for retrieval by query |

Both flows use the same **embedding service** (512-dimensional, on-device) and **cosine similarity** for matching. The pattern index persists embeddings in theme clusters; the semantic index is built on demand when search runs and is not persisted.

---

## 2. The Vectorization Algorithm

### 2.1 Embedding abstraction

- **Interface**: `EmbeddingService` (`lib/chronicle/embeddings/embedding_service.dart`)
  - **Dimension**: 512 (fixed).
  - **Methods**:
    - `embed(String text) → List<double>`
    - `embedBatch(List<String> texts) → Map<String, List<double>>` (default: sequential `embed` per text)
    - `cosineSimilarity(List<double> a, List<double> b) → double`
  - Embeddings are **L2-normalized**, so cosine similarity is implemented as the **dot product** of two vectors (no explicit norm division).

### 2.2 Implementations

1. **LocalEmbeddingService** (`local_embedding_service.dart`)
   - **Backend**: TensorFlow Lite, model `assets/models/universal_sentence_encoder.tflite` (Universal Sentence Encoder–style, 512-d).
   - **Input**: Raw string (no manual tokenization).
   - **Output**: 512-d vector, then **L2-normalized** so that `cosineSimilarity(a, b)` is the dot product.
   - **Performance**: Target &lt;100 ms per embedding on mid-range devices.
   - **Batch**: Sequential `embed()` per text (no batched TFLite run).

2. **IOSNativeEmbeddingService** (`ios_native_embedding_service.dart`)
   - **Backend**: Apple Natural Language (`NLEmbedding.sentenceEmbedding`) via MethodChannel `com.epi.arcmvp/embedding`.
   - **Dimension**: 512 (same as interface).
   - Used when available so TFLite is not required on iOS.

### 2.3 Creation and initialization

- **createEmbeddingService()** (`create_embedding_service.dart`):
  - **iOS**: Tries `IOSNativeEmbeddingService` first; if not available, falls back to `LocalEmbeddingService`.
  - **Android**: Uses `LocalEmbeddingService` (TFLite).
- Callers must call `initialize()` on the returned service before use (e.g. load TFLite model or check native availability).

### 2.4 Summary of the “algorithm”

- **Encode**: Text → 512-d vector (sentence encoder), then L2-normalize.
- **Compare**: Similarity = dot product of two normalized vectors (= cosine similarity).
- **No training in-app**: The model (USE Lite or iOS NL) is fixed; vectorization is inference-only.

---

## 3. Vectorization and Chronicle — Two Flows

### 3.1 Flow A: Pattern index (theme-level vectorization)

**Purpose**: Cross-temporal pattern recognition: link recurring themes across months, build theme clusters, drive “related entries” and pattern queries.

**Where it runs**:  
`ChronicleIndexBuilder`, `ThreeStagePatternMatcher`, `PatternQueryRouter`; wired from `VeilChronicleFactory` (synthesis + narrative integration).

**What gets vectorized**:
- **Not** raw journal entries.
- **Dominant themes** from **monthly synthesis** (e.g. from `MonthlyAggregation.dominantThemes`).
- For each theme label, a **theme summary** is built (e.g. `"Theme 'X' appeared in YYYY-MM during Z phase. Context: ..."`).
- That summary is embedded once: `_embedder.embed(summary)` → stored in `DominantTheme.embedding`.

**Storage**:
- Embeddings are stored inside the **ChronicleIndex** (JSON via `ChronicleIndexStorage`).
- Each **ThemeCluster** has a **canonicalEmbedding** (the cluster’s theme vector).
- When a new theme is merged into a cluster, the cluster’s canonical embedding is that of the theme that defined the cluster (or the matched cluster); aliases and appearances are added without re-embedding the full corpus.

**Matching pipeline (ThreeStagePatternMatcher)**:
1. **Stage 1 — Keyword filter**: Reduce clusters to candidates that share at least one word with the query theme label/summary (labels and aliases).
2. **Stage 2 — Semantic match**: For each candidate cluster, `cosineSimilarity(queryTheme.embedding, cluster.canonicalEmbedding)`. Keep matches ≥ 0.60, sort by similarity.
3. **Stage 3 — Confidence**:
   - ≥ 0.80 → high confidence, auto-link to cluster.
   - ≥ 0.65 + supporting evidence (phase, context, intensity) → auto-link.
   - ≥ 0.65 without evidence → candidate echo (for review).
   - &lt; 0.65 → no match (new cluster or ignore).

**Related entries**:  
`RelatedEntriesService` does **not** call the embedding service. It uses the **pattern index only**: entries that share a theme cluster (via `ThemeAppearance.entryIds`) are “related.” So “vectorization” affects related entries only indirectly (by defining which themes belong to which cluster).

**Pattern queries**:  
`PatternQueryRouter` embeds the **extracted theme string** from the user query, builds a `DominantTheme`, and runs `ThreeStagePatternMatcher` against the stored index to return pattern recognition or “no pattern” responses.

### 3.2 Flow B: Entry-level semantic search (hybrid search)

**Purpose**: Retrieve Chronicle (Layer 0) entries by a free-text query using both **keyword** (BM25) and **semantic** (dense) signals, then optionally rerank.

**Where it runs**:  
`HybridSearchEngine` uses `ChronicleQueryAdapter` for entry loading, `BM25Index`, `SemanticIndex`, `AdaptiveFusionEngine`, and optionally `ChronicleRerankService` (feature-based reranker).

**What gets vectorized**:
- **Raw entry content** (`UserEntry.content` / `IndexableEntry.text`) for each entry loaded for the user.
- **Query** at search time: the same embedding service embeds the query string.

**Storage**:
- **No persistent storage** of entry embeddings.
- **SemanticIndex** keeps an in-memory `Map<String, List<double>>` (entry id → embedding).
- Index is **built on demand** when `HybridSearchEngine.search(userId, query)` is called: load entries → `embedBatch(entry.text)` → fill cache. Cache is keyed by userId and entry id set; invalidated when entries change via `invalidateCache(userId)`.
- **BM25** index is also rebuilt from the same entry set on each search (no persistence).

**Search pipeline**:
1. Load entries for user (`ChronicleQueryAdapter.loadEntries(userId)`).
2. Build BM25 index over `IndexableEntry(id, text)`.
3. Build or reuse semantic index: embed all entry texts, cache by id.
4. Run in parallel:
   - BM25: `BM25Index.search(query, topK: candidateK)` (candidateK = topK × candidateMultiplier, default 3).
   - Semantic: `SemanticIndex.search(query, topK: candidateK)` (embed query, cosine similarity to all cached embeddings, return top-K).
5. **Fuse** the two ranked lists with **Reciprocal Rank Fusion (RRF)**:
   - `score(doc) = weightBM25/(k + rankBM25) + weightSemantic/(k + rankSemantic)` (default k=60, weights 1.0).
6. Take top `topK` by fused score; optionally **rerank** with `ChronicleRerankService` (entity/temporal/theme/recency features; no extra embeddings).

---

## 4. Interplay Between Vectorization and Semantic Search for Data Retrieval

### 4.1 Roles of sparse vs dense retrieval

| Channel | Mechanism | Vectorization? | Best for |
|--------|-----------|----------------|----------|
| **BM25** | Sparse: term frequency, document length, IDF | No | Exact or stemmed keywords, names, dates, phrases |
| **Semantic** | Dense: embed query and documents, cosine similarity | Yes | Concepts, paraphrases, “similar to this” |

- **BM25** does not use vectors; it uses token counts and document statistics.
- **Semantic search** is entirely driven by vectorization: same embedding model and cosine similarity for both indexing (entry text → vector) and query (query string → vector).

### 4.2 Why hybrid (BM25 + semantic)?

- **Complementarity**: Keyword match catches precise mentions; semantic match catches meaning without exact words.
- **RRF** combines the two **rankings** (not raw scores), so scale differences between BM25 and cosine do not matter; only relative order in each list matters.
- **Candidate expansion** (topK × multiplier from each channel) before fusion increases recall; fusion and optional rerank then improve precision.

### 4.3 End-to-end data retrieval path (entry-level)

1. **Input**: User id, query string, options (topK, reranking on/off).
2. **Data source**: Chronicle Layer 0 entries (and annotations if used) via `ChronicleQueryAdapter`.
3. **Vectorization**:
   - **Indexing**: Each entry’s `content` is embedded and stored in `SemanticIndex` cache (and BM25 terms are indexed).
   - **Query**: Query string is embedded once for the semantic channel.
4. **Retrieval**:
   - BM25 returns a ranked list of document ids.
   - Semantic returns a ranked list of document ids (by cosine similarity).
5. **Fusion**: RRF merges the two lists into one ranked list of ids (with fused score).
6. **Optional rerank**: Feature-based reranker adjusts order using entity match, temporal match, theme overlap, recency, content length (no further vectorization).
7. **Output**: Ordered list of entry ids (and scores); caller fetches full entries by id (e.g. via the same adapter).

So: **vectorization** feeds **semantic search**; semantic search and BM25 are **combined** by RRF; **reranking** refines the result without more embeddings.

### 4.4 Pattern index vs entry-level semantic search

- **Pattern index**: Vectorization is over **theme summaries** (from synthesis). Stored in ChronicleIndex. Used for:
  - Deciding whether a new theme links to an existing cluster (ThreeStagePatternMatcher).
  - Answering pattern queries (PatternQueryRouter).
  - Defining “related entries” by cluster membership (RelatedEntriesService), without running embeddings at related-entries time.
- **Entry-level semantic search**: Vectorization is over **entry text** and **query**. Not stored; used only inside the hybrid search path for retrieval by meaning.

The two flows share the same **embedding service and dimension** but differ in **what is embedded**, **where results are stored**, and **how they are consumed** (pattern logic vs. search + RRF + rerank).

### 4.5 When vectorization runs

| Event | What is vectorized | Flow |
|-------|--------------------|------|
| Monthly synthesis completes | Theme summaries for dominant themes | Pattern index (ChronicleIndexBuilder) |
| User asks a pattern-style question | Extracted theme string from query | PatternQueryRouter → ThreeStagePatternMatcher |
| Hybrid search requested (e.g. feed/search UI) | All loaded entry texts + query | HybridSearchEngine → SemanticIndex |
| Viewing “related entries” | Nothing (uses cluster membership) | RelatedEntriesService |

---

## 5. Key Files Reference

| Area | File(s) |
|------|--------|
| Embedding API | `lib/chronicle/embeddings/embedding_service.dart` |
| TFLite embedding | `lib/chronicle/embeddings/local_embedding_service.dart` |
| iOS native embedding | `lib/chronicle/embeddings/ios_native_embedding_service.dart` |
| Create service | `lib/chronicle/embeddings/create_embedding_service.dart` |
| Semantic index (entry-level) | `lib/chronicle/search/semantic_index.dart` |
| BM25 index | `lib/chronicle/search/bm25_index.dart` |
| Hybrid engine | `lib/chronicle/search/hybrid_search_engine.dart` |
| RRF fusion | `lib/chronicle/search/adaptive_fusion_engine.dart` |
| Rerank | `lib/chronicle/search/chronicle_rerank_service.dart`, `feature_based_reranker.dart` |
| Pattern index build | `lib/chronicle/index/chronicle_index_builder.dart` |
| Theme matching | `lib/chronicle/matching/three_stage_matcher.dart` |
| Pattern queries | `lib/chronicle/query/pattern_query_router.dart` |
| Related entries | `lib/chronicle/related_entries_service.dart` |
| Chronicle index storage | `lib/chronicle/storage/chronicle_index_storage.dart` |
| Entry loading for search | `lib/chronicle/dual/services/chronicle_query_adapter.dart` |

---

## 6. Summary

- **Vectorization** in Chronicle is **512-d on-device embeddings** (TFLite USE Lite or iOS NLEmbedding), L2-normalized, with similarity = dot product (cosine).
- **Two uses**: (1) **Pattern index** — theme summaries from monthly synthesis are embedded and stored in theme clusters for matching and related entries; (2) **Entry-level semantic search** — entry content and query are embedded on demand, not persisted, and used inside hybrid search.
- **Semantic search** for data retrieval is the **dense channel** of hybrid search: it relies entirely on this vectorization; BM25 is the sparse channel. RRF fuses the two rankings; optional feature-based reranking then refines results without further vectorization. Together, vectorization and semantic search enable meaning-based retrieval of Chronicle entries alongside keyword-based retrieval, while the pattern index uses the same embedding pipeline for theme-level, cross-temporal reasoning.

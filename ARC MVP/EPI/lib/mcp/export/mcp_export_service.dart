/// MCP Export Service
/// 
/// High-level orchestrator for exporting MIRA memory into MCP Memory Bundle format.
/// Handles SAGE-to-Node mapping, pointer creation, embedding generation, and edge derivation.
library;

import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../models/mcp_schemas.dart';
import '../validation/mcp_validator.dart';
import 'ndjson_writer.dart';
import 'manifest_builder.dart';
import 'checksum_utils.dart';

class McpExportService {
  final String bundleId;
  final McpStorageProfile storageProfile;
  final String? notes;

  McpExportService({
    String? bundleId,
    this.storageProfile = McpStorageProfile.balanced,
    this.notes,
  }) : bundleId = bundleId ?? McpManifestBuilder.generateBundleId();

  /// Export MIRA memory to MCP bundle
  Future<McpExportResult> exportToMcp({
    required Directory outputDir,
    required McpExportScope scope,
    required List<JournalEntry> journalEntries,
    List<MediaFile>? mediaFiles,
    Map<String, dynamic>? customScope,
  }) async {
    try {
      // Ensure output directory exists
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // Filter entries based on scope
      final filteredEntries = _filterEntriesByScope(journalEntries, scope, customScope);
      
      // Convert journal entries to MCP nodes (SAGE mapping)
      final nodes = await _convertJournalEntriesToNodes(filteredEntries);
      
      // Create pointers for media files
      final pointers = await _createPointersFromMedia(mediaFiles ?? []);
      
      // Generate embeddings for nodes and pointers
      final embeddings = await _generateEmbeddings(nodes, pointers);
      
      // Derive edges from relationships
      final edges = await _deriveEdges(nodes, embeddings);
      
      // Validate all records
      final validationResult = await _validateRecords(nodes, edges, pointers, embeddings);
      if (!validationResult.isValid) {
        throw McpExportException('Validation failed: ${validationResult.errors.join(', ')}');
      }
      
      // Write NDJSON files
      final ndjsonWriter = McpNdjsonWriter(outputDir: outputDir);
      final ndjsonFiles = await ndjsonWriter.writeAll(
        nodes: nodes,
        edges: edges,
        pointers: pointers,
        embeddings: embeddings,
      );
      
      // Build and write manifest
      final manifestBuilder = McpManifestBuilder(
        bundleId: bundleId,
        storageProfile: storageProfile,
        notes: notes,
      );
      
      final counts = McpCounts(
        nodes: nodes.length,
        edges: edges.length,
        pointers: pointers.length,
        embeddings: embeddings.length,
      );
      
      final encoderRegistry = McpManifestBuilder.createEncoderRegistry(embeddings);
      
      final manifestFile = await manifestBuilder.buildAndWriteManifest(
        outputDir: outputDir,
        ndjsonFiles: ndjsonFiles,
        counts: counts,
        encoderRegistry: encoderRegistry,
      );
      
      return McpExportResult(
        success: true,
        bundleId: bundleId,
        outputDir: outputDir,
        manifestFile: manifestFile,
        ndjsonFiles: ndjsonFiles,
        counts: counts,
        encoderRegistry: encoderRegistry,
      );
      
    } catch (e) {
      return McpExportResult(
        success: false,
        error: e.toString(),
        bundleId: bundleId,
        outputDir: outputDir,
      );
    }
  }

  /// Filter journal entries based on export scope
  List<JournalEntry> _filterEntriesByScope(
    List<JournalEntry> entries,
    McpExportScope scope,
    Map<String, dynamic>? customScope,
  ) {
    final now = DateTime.now();
    
    switch (scope) {
      case McpExportScope.last30Days:
        final cutoff = now.subtract(const Duration(days: 30));
        return entries.where((e) => e.createdAt.isAfter(cutoff)).toList();
        
      case McpExportScope.last90Days:
        final cutoff = now.subtract(const Duration(days: 90));
        return entries.where((e) => e.createdAt.isAfter(cutoff)).toList();
        
      case McpExportScope.lastYear:
        final cutoff = now.subtract(const Duration(days: 365));
        return entries.where((e) => e.createdAt.isAfter(cutoff)).toList();
        
      case McpExportScope.all:
        return entries;
        
      case McpExportScope.custom:
        if (customScope == null) return entries;
        
        final startDate = customScope['start_date'] as DateTime?;
        final endDate = customScope['end_date'] as DateTime?;
        final tags = customScope['tags'] as List<String>?;
        
        var filtered = entries;
        
        if (startDate != null) {
          filtered = filtered.where((e) => e.createdAt.isAfter(startDate)).toList();
        }
        if (endDate != null) {
          filtered = filtered.where((e) => e.createdAt.isBefore(endDate)).toList();
        }
        if (tags != null && tags.isNotEmpty) {
          filtered = filtered.where((e) => 
            e.tags.any((tag) => tags.contains(tag))).toList();
        }
        
        return filtered;
    }
  }

  /// Convert journal entries to MCP nodes with SAGE mapping
  Future<List<McpNode>> _convertJournalEntriesToNodes(List<JournalEntry> entries) async {
    final nodes = <McpNode>[];
    
    for (final entry in entries) {
      // Extract SAGE narrative from journal content
      final narrative = _extractSageNarrative(entry);
      
      // Determine phase hint from entry metadata
      final phaseHint = _determinePhaseHint(entry);
      
      // Extract emotions from entry
      final emotions = _extractEmotions(entry);
      
      // Create node ID
      final nodeId = 'entry_${entry.createdAt.year}_${entry.createdAt.month.toString().padLeft(2, '0')}_${entry.createdAt.day.toString().padLeft(2, '0')}_${entry.id}';
      
      final node = McpNode(
        id: nodeId,
        type: 'journal_entry',
        timestamp: entry.createdAt.toUtc(),
        contentSummary: _createContentSummary(entry),
        phaseHint: phaseHint,
        keywords: entry.tags.toList(),
        narrative: narrative,
        emotions: emotions,
        provenance: McpProvenance(
          source: 'ARC',
          device: Platform.operatingSystem,
          app: 'EPI',
          importMethod: 'journal_entry',
          userId: entry.userId,
        ),
      );
      
      nodes.add(node);
    }
    
    return nodes;
  }

  /// Extract SAGE narrative from journal entry
  McpNarrative _extractSageNarrative(JournalEntry entry) {
    // This is a simplified implementation
    // In a real implementation, you'd use AI to extract SAGE components
    final content = entry.content;
    
    return McpNarrative(
      situation: _extractSituation(content),
      action: _extractAction(content),
      growth: _extractGrowth(content),
      essence: _extractEssence(content),
    );
  }

  /// Extract situation from journal content
  String? _extractSituation(String content) {
    // Simplified: look for situation keywords
    final situationKeywords = ['situation', 'context', 'when', 'where', 'circumstance'];
    for (final keyword in situationKeywords) {
      if (content.toLowerCase().contains(keyword)) {
        return 'Situation extracted from journal entry';
      }
    }
    return null;
  }

  /// Extract action from journal content
  String? _extractAction(String content) {
    // Simplified: look for action keywords
    final actionKeywords = ['action', 'did', 'took', 'decided', 'chose'];
    for (final keyword in actionKeywords) {
      if (content.toLowerCase().contains(keyword)) {
        return 'Action extracted from journal entry';
      }
    }
    return null;
  }

  /// Extract growth from journal content
  String? _extractGrowth(String content) {
    // Simplified: look for growth keywords
    final growthKeywords = ['growth', 'learned', 'realized', 'understood', 'insight'];
    for (final keyword in growthKeywords) {
      if (content.toLowerCase().contains(keyword)) {
        return 'Growth extracted from journal entry';
      }
    }
    return null;
  }

  /// Extract essence from journal content
  String? _extractEssence(String content) {
    // Simplified: look for essence keywords
    final essenceKeywords = ['essence', 'core', 'meaning', 'purpose', 'value'];
    for (final keyword in essenceKeywords) {
      if (content.toLowerCase().contains(keyword)) {
        return 'Essence extracted from journal entry';
      }
    }
    return null;
  }

  /// Determine phase hint from journal entry
  String? _determinePhaseHint(JournalEntry entry) {
    // This would integrate with your existing phase detection system
    // For now, return a default or extract from entry metadata
    return entry.metadata['phase'] as String?;
  }

  /// Extract emotions from journal entry
  Map<String, double> _extractEmotions(JournalEntry entry) {
    // This would integrate with your existing emotion analysis
    // For now, return a simple mapping
    return {
      'calm': 0.6,
      'curious': 0.4,
    };
  }

  /// Create content summary from journal entry
  String _createContentSummary(JournalEntry entry) {
    // Create a summary of the journal entry
    final words = entry.content.split(' ');
    if (words.length <= 20) {
      return entry.content;
    } else {
      return '${words.take(20).join(' ')}...';
    }
  }

  /// Create pointers from media files
  Future<List<McpPointer>> _createPointersFromMedia(List<MediaFile> mediaFiles) async {
    final pointers = <McpPointer>[];
    
    for (final mediaFile in mediaFiles) {
      final pointerId = 'ptr_${mediaFile.id}';
      
      // Create content hash
      final contentBytes = await mediaFile.file.readAsBytes();
      final contentHash = sha256.convert(contentBytes).toString();
      
      // Create CAS URI
      final casUri = McpChecksumUtils.generateCasUri(contentBytes);
      
      final pointer = McpPointer(
        id: pointerId,
        mediaType: mediaFile.type,
        sourceUri: mediaFile.uri,
        altUris: [casUri],
        descriptor: McpDescriptor(
          language: mediaFile.language,
          length: contentBytes.length,
          mimeType: mediaFile.mimeType,
          metadata: {
            'original_filename': mediaFile.filename,
            'duration': mediaFile.duration,
          },
        ),
        samplingManifest: McpSamplingManifest(
          spans: _createSpansForMedia(mediaFile),
          keyframes: _createKeyframesForMedia(mediaFile),
          metadata: {
            'sampling_method': 'automatic',
            'quality': 'balanced',
          },
        ),
        integrity: McpIntegrity(
          contentHash: contentHash,
          bytes: contentBytes.length,
          mime: mediaFile.mimeType,
          createdAt: mediaFile.createdAt.toUtc(),
        ),
        provenance: McpProvenance(
          source: 'ARC',
          device: Platform.operatingSystem,
          app: 'EPI',
          importMethod: 'media_import',
          userId: mediaFile.userId,
        ),
        privacy: McpPrivacy(
          containsPii: _detectPii(mediaFile),
          facesDetected: _detectFaces(mediaFile),
          locationPrecision: _detectLocation(mediaFile),
          sharingPolicy: 'private',
        ),
        labels: mediaFile.tags.toList(),
      );
      
      pointers.add(pointer);
    }
    
    return pointers;
  }

  /// Create spans for media file
  List<McpSpan> _createSpansForMedia(MediaFile mediaFile) {
    // This would create text spans for audio transcripts, video captions, etc.
    return [];
  }

  /// Create keyframes for media file
  List<McpKeyframe> _createKeyframesForMedia(MediaFile mediaFile) {
    // This would create keyframes for video files
    return [];
  }

  /// Detect PII in media file
  bool _detectPii(MediaFile mediaFile) {
    // This would use your existing PII detection
    return false;
  }

  /// Detect faces in media file
  bool _detectFaces(MediaFile mediaFile) {
    // This would use your existing face detection
    return false;
  }

  /// Detect location in media file
  String? _detectLocation(MediaFile mediaFile) {
    // This would use your existing location detection
    return null;
  }

  /// Generate embeddings for nodes and pointers
  Future<List<McpEmbedding>> _generateEmbeddings(
    List<McpNode> nodes,
    List<McpPointer> pointers,
  ) async {
    final embeddings = <McpEmbedding>[];
    
    // Generate embeddings for nodes
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final embeddingId = 'emb_node_$i';
      
      // This would use your existing embedding service
      final vector = await _generateEmbeddingVector(node.contentSummary ?? '');
      
      final embedding = McpEmbedding(
        id: embeddingId,
        pointerRef: node.pointerRef ?? '',
        docScope: node.id,
        vector: vector,
        modelId: 'qwen-2.5-1.5b',
        embeddingVersion: '1.0.0',
        dim: vector.length,
      );
      
      embeddings.add(embedding);
    }
    
    // Generate embeddings for pointers
    for (int i = 0; i < pointers.length; i++) {
      final pointer = pointers[i];
      final embeddingId = 'emb_ptr_$i';
      
      // This would use your existing embedding service
      final vector = await _generateEmbeddingVector(pointer.descriptor.metadata.toString());
      
      final embedding = McpEmbedding(
        id: embeddingId,
        pointerRef: pointer.id,
        vector: vector,
        modelId: 'qwen-2.5-1.5b',
        embeddingVersion: '1.0.0',
        dim: vector.length,
      );
      
      embeddings.add(embedding);
    }
    
    return embeddings;
  }

  /// Generate embedding vector for text
  Future<List<double>> _generateEmbeddingVector(String text) async {
    // This would use your existing embedding service
    // For now, return a dummy vector
    return List.generate(384, (index) => (index * 0.01) % 1.0);
  }

  /// Derive edges from relationships
  Future<List<McpEdge>> _deriveEdges(
    List<McpNode> nodes,
    List<McpEmbedding> embeddings,
  ) async {
    final edges = <McpEdge>[];
    
    // Create time adjacency edges
    for (int i = 0; i < nodes.length - 1; i++) {
      final current = nodes[i];
      final next = nodes[i + 1];
      
      final edge = McpEdge(
        source: current.id,
        target: next.id,
        relation: 'time_adjacent',
        timestamp: current.timestamp,
        weight: 0.8,
      );
      
      edges.add(edge);
    }
    
    // Create theme similarity edges based on embeddings
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final node1 = nodes[i];
        final node2 = nodes[j];
        
        // Find embeddings for these nodes
        final emb1 = embeddings.firstWhere(
          (e) => e.docScope == node1.id,
          orElse: () => throw StateError('Embedding not found for node ${node1.id}'),
        );
        final emb2 = embeddings.firstWhere(
          (e) => e.docScope == node2.id,
          orElse: () => throw StateError('Embedding not found for node ${node2.id}'),
        );
        
        // Calculate cosine similarity
        final similarity = _calculateCosineSimilarity(emb1.vector, emb2.vector);
        
        if (similarity > 0.7) {
          final edge = McpEdge(
            source: node1.id,
            target: node2.id,
            relation: 'theme_similar',
            timestamp: node1.timestamp,
            weight: similarity,
          );
          
          edges.add(edge);
        }
      }
    }
    
    return edges;
  }

  /// Calculate cosine similarity between two vectors
  double _calculateCosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    
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

  /// Validate all records
  Future<ValidationResult> _validateRecords(
    List<McpNode> nodes,
    List<McpEdge> edges,
    List<McpPointer> pointers,
    List<McpEmbedding> embeddings,
  ) async {
    final allErrors = <String>[];
    
    // Validate nodes
    for (final node in nodes) {
      final result = McpValidator.validateNode(node);
      if (!result.isValid) {
        allErrors.addAll(result.errors.map((e) => 'Node ${node.id}: $e'));
      }
    }
    
    // Validate edges
    for (final edge in edges) {
      final result = McpValidator.validateEdge(edge);
      if (!result.isValid) {
        allErrors.addAll(result.errors.map((e) => 'Edge ${edge.source}->${edge.target}: $e'));
      }
    }
    
    // Validate pointers
    for (final pointer in pointers) {
      final result = McpValidator.validatePointer(pointer);
      if (!result.isValid) {
        allErrors.addAll(result.errors.map((e) => 'Pointer ${pointer.id}: $e'));
      }
    }
    
    // Validate embeddings
    for (final embedding in embeddings) {
      final result = McpValidator.validateEmbedding(embedding);
      if (!result.isValid) {
        allErrors.addAll(result.errors.map((e) => 'Embedding ${embedding.id}: $e'));
      }
    }
    
    return ValidationResult(
      isValid: allErrors.isEmpty,
      errors: allErrors,
    );
  }
}

/// MCP Export Result
class McpExportResult {
  final bool success;
  final String? error;
  final String bundleId;
  final Directory outputDir;
  final File? manifestFile;
  final Map<String, File>? ndjsonFiles;
  final McpCounts? counts;
  final List<McpEncoderRegistry>? encoderRegistry;

  const McpExportResult({
    required this.success,
    this.error,
    required this.bundleId,
    required this.outputDir,
    this.manifestFile,
    this.ndjsonFiles,
    this.counts,
    this.encoderRegistry,
  });
}

/// MCP Export Exception
class McpExportException implements Exception {
  final String message;
  const McpExportException(this.message);
  
  @override
  String toString() => 'McpExportException: $message';
}

/// Placeholder classes for journal and media data
class JournalEntry {
  final String id;
  final String content;
  final DateTime createdAt;
  final Set<String> tags;
  final String userId;
  final Map<String, dynamic> metadata;

  const JournalEntry({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.tags,
    required this.userId,
    this.metadata = const {},
  });
}

class MediaFile {
  final String id;
  final String type;
  final String uri;
  final String filename;
  final String mimeType;
  final String? language;
  final Duration? duration;
  final DateTime createdAt;
  final String userId;
  final Set<String> tags;
  final File file;

  const MediaFile({
    required this.id,
    required this.type,
    required this.uri,
    required this.filename,
    required this.mimeType,
    this.language,
    this.duration,
    required this.createdAt,
    required this.userId,
    required this.tags,
    required this.file,
  });
}

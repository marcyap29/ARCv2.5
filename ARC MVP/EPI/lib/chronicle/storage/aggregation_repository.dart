import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/chronicle_aggregation.dart';
import '../models/chronicle_layer.dart';

/// Repository for storing CHRONICLE aggregations (Layers 1-3)
/// 
/// Uses file-based storage in markdown + YAML format:
/// - chronicle/monthly/2025-01.md
/// - chronicle/yearly/2025.md
/// - chronicle/multiyear/2020-2024.md

class AggregationRepository {
  static const String monthlyDir = 'monthly';
  static const String yearlyDir = 'yearly';
  static const String multiyearDir = 'multiyear';

  /// Get the base directory for CHRONICLE storage
  Future<Directory> _getChronicleDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final chronicleDir = Directory(path.join(appDir.path, 'chronicle'));
    
    if (!await chronicleDir.exists()) {
      await chronicleDir.create(recursive: true);
    }
    
    return chronicleDir;
  }

  /// Get directory for a specific layer
  Future<Directory> _getLayerDirectory(ChronicleLayer layer) async {
    final baseDir = await _getChronicleDirectory();
    String subdir;
    
    switch (layer) {
      case ChronicleLayer.monthly:
        subdir = monthlyDir;
        break;
      case ChronicleLayer.yearly:
        subdir = yearlyDir;
        break;
      case ChronicleLayer.multiyear:
        subdir = multiyearDir;
        break;
      default:
        throw ArgumentError('Layer $layer does not use file storage (use Layer0Repository)');
    }
    
    final layerDir = Directory(path.join(baseDir.path, subdir));
    if (!await layerDir.exists()) {
      await layerDir.create(recursive: true);
    }
    
    return layerDir;
  }

  /// Get file path for an aggregation
  Future<File> _getAggregationFile(ChronicleLayer layer, String period) async {
    final layerDir = await _getLayerDirectory(layer);
    final filename = '$period.md';
    return File(path.join(layerDir.path, filename));
  }

  /// Save a monthly aggregation
  Future<void> saveMonthly(String userId, ChronicleAggregation aggregation) async {
    if (aggregation.layer != ChronicleLayer.monthly) {
      throw ArgumentError('Expected monthly aggregation, got ${aggregation.layer}');
    }
    
    final file = await _getAggregationFile(ChronicleLayer.monthly, aggregation.period);
    final content = _buildMarkdownWithFrontmatter(aggregation);
    await file.writeAsString(content);
    
    print('✅ AggregationRepository: Saved monthly aggregation ${aggregation.period}');
  }

  /// Save a yearly aggregation
  Future<void> saveYearly(String userId, ChronicleAggregation aggregation) async {
    if (aggregation.layer != ChronicleLayer.yearly) {
      throw ArgumentError('Expected yearly aggregation, got ${aggregation.layer}');
    }
    
    final file = await _getAggregationFile(ChronicleLayer.yearly, aggregation.period);
    final content = _buildMarkdownWithFrontmatter(aggregation);
    await file.writeAsString(content);
    
    print('✅ AggregationRepository: Saved yearly aggregation ${aggregation.period}');
  }

  /// Save a multi-year aggregation
  Future<void> saveMultiYear(String userId, ChronicleAggregation aggregation) async {
    if (aggregation.layer != ChronicleLayer.multiyear) {
      throw ArgumentError('Expected multiyear aggregation, got ${aggregation.layer}');
    }
    
    final file = await _getAggregationFile(ChronicleLayer.multiyear, aggregation.period);
    final content = _buildMarkdownWithFrontmatter(aggregation);
    await file.writeAsString(content);
    
    print('✅ AggregationRepository: Saved multi-year aggregation ${aggregation.period}');
  }

  /// Build markdown content with YAML frontmatter
  String _buildMarkdownWithFrontmatter(ChronicleAggregation aggregation) {
    final frontmatter = '''---
type: ${aggregation.layer.name}_aggregation
period: ${aggregation.period}
synthesis_date: ${aggregation.synthesisDate.toIso8601String()}
entry_count: ${aggregation.entryCount}
compression_ratio: ${aggregation.compressionRatio}
user_edited: ${aggregation.userEdited}
version: ${aggregation.version}
source_entry_ids: ${aggregation.sourceEntryIds.join(', ')}
user_id: ${aggregation.userId}
---

''';
    
    return frontmatter + aggregation.content;
  }

  /// Load an aggregation from file
  Future<ChronicleAggregation?> loadLayer({
    required String userId,
    required ChronicleLayer layer,
    required String period,
  }) async {
    if (layer == ChronicleLayer.layer0) {
      throw ArgumentError('Layer 0 uses Layer0Repository, not AggregationRepository');
    }

    final file = await _getAggregationFile(layer, period);
    
    if (!await file.exists()) {
      return null;
    }

    final content = await file.readAsString();
    return _parseMarkdownWithFrontmatter(content, layer, period, userId);
  }

  /// Parse markdown with YAML frontmatter
  ChronicleAggregation _parseMarkdownWithFrontmatter(
    String content,
    ChronicleLayer layer,
    String period,
    String userId,
  ) {
    // Split frontmatter and markdown
    if (!content.startsWith('---')) {
      throw FormatException('Invalid aggregation format: missing frontmatter');
    }

    final parts = content.split('---');
    if (parts.length < 3) {
      throw FormatException('Invalid aggregation format: malformed frontmatter');
    }

    final frontmatter = parts[1].trim();
    final markdown = parts.sublist(2).join('---').trim();

    // Parse YAML frontmatter (simplified - just extract key values)
    final metadata = <String, dynamic>{};
    for (final line in frontmatter.split('\n')) {
      if (line.contains(':')) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join(':').trim();
          
          // Parse value based on type
          if (key == 'entry_count' || key == 'version') {
            metadata[key] = int.parse(value);
          } else if (key == 'compression_ratio') {
            metadata[key] = double.parse(value);
          } else if (key == 'user_edited') {
            metadata[key] = value.toLowerCase() == 'true';
          } else if (key == 'synthesis_date') {
            metadata[key] = DateTime.parse(value);
          } else if (key == 'source_entry_ids') {
            metadata[key] = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          } else {
            metadata[key] = value;
          }
        }
      }
    }

    return ChronicleAggregation(
      layer: layer,
      period: period,
      synthesisDate: metadata['synthesis_date'] as DateTime,
      entryCount: metadata['entry_count'] as int,
      compressionRatio: metadata['compression_ratio'] as double,
      content: markdown,
      sourceEntryIds: List<String>.from(metadata['source_entry_ids'] as List? ?? []),
      userEdited: metadata['user_edited'] as bool? ?? false,
      version: metadata['version'] as int? ?? 1,
      userId: userId,
    );
  }

  /// Get all aggregations for a layer
  Future<List<ChronicleAggregation>> getAllForLayer({
    required String userId,
    required ChronicleLayer layer,
  }) async {
    if (layer == ChronicleLayer.layer0) {
      throw ArgumentError('Layer 0 uses Layer0Repository, not AggregationRepository');
    }

    final layerDir = await _getLayerDirectory(layer);
    final files = layerDir.listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();

    final aggregations = <ChronicleAggregation>[];
    
    for (final file in files) {
      final period = path.basenameWithoutExtension(file.path);
      try {
        final agg = await loadLayer(userId: userId, layer: layer, period: period);
        if (agg != null) {
          aggregations.add(agg);
        }
      } catch (e) {
        print('⚠️ AggregationRepository: Failed to load ${file.path}: $e');
      }
    }

    return aggregations;
  }

  /// Delete an aggregation
  Future<void> deleteAggregation(ChronicleLayer layer, String period) async {
    final file = await _getAggregationFile(layer, period);
    if (await file.exists()) {
      await file.delete();
      print('🗑️ AggregationRepository: Deleted ${layer.name} aggregation $period');
    }
  }
}

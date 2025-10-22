// lib/lumara/services/mcp_bundle_parser.dart
// Parse MCP bundles to extract ReflectiveNode objects

import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import '../models/reflective_node.dart';

class McpBundleParser {
  Future<List<ReflectiveNode>> parseBundle(String bundlePath) async {
    print('LUMARA: Parsing MCP bundle at $bundlePath');
    final nodes = <ReflectiveNode>[];
    
    try {
      // 1. Parse nodes.jsonl
      final nodesFromJsonl = await _parseNodesJsonl(bundlePath);
      nodes.addAll(nodesFromJsonl);
      print('LUMARA: Parsed ${nodesFromJsonl.length} nodes from nodes.jsonl');
      
      // 2. Parse journal_v1.mcp.zip entries
      final journalNodes = await _parseJournalZip(bundlePath);
      nodes.addAll(journalNodes);
      print('LUMARA: Parsed ${journalNodes.length} journal entries from ZIP');
      
      // 3. Parse media metadata from mcp_media_*.zip
      final mediaNodes = await _parseMediaPacks(bundlePath);
      nodes.addAll(mediaNodes);
      print('LUMARA: Parsed ${mediaNodes.length} media nodes from packs');
      
      // 4. Parse drafts if available
      final draftNodes = await _parseDrafts(bundlePath);
      nodes.addAll(draftNodes);
      print('LUMARA: Parsed ${draftNodes.length} draft nodes');
      
      print('LUMARA: Total nodes parsed: ${nodes.length}');
      return nodes;
    } catch (e) {
      print('LUMARA: Error parsing bundle: $e');
      rethrow;
    }
  }

  Future<List<ReflectiveNode>> _parseNodesJsonl(String bundlePath) async {
    final nodes = <ReflectiveNode>[];
    
    try {
      final bundleDir = Directory(bundlePath);
      final nodesFile = File('${bundleDir.path}/nodes.jsonl');
      
      if (!await nodesFile.exists()) {
        print('LUMARA: nodes.jsonl not found in bundle');
        return nodes;
      }
      
      final lines = await nodesFile.readAsLines();
      
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          
          // Only process journal_entry nodes
          // Handle journal entries, phase regimes, and chat data
          if (json['type'] != 'journal_entry' && 
              json['type'] != 'phase_regime' && 
              json['type'] != 'ChatSession' && 
              json['type'] != 'ChatMessage') continue;
          
          final node = _createReflectiveNodeFromJson(json);
          if (node != null) {
            nodes.add(node);
          }
        } catch (e) {
          print('LUMARA: Error parsing nodes.jsonl line: $e');
          continue;
        }
      }
    } catch (e) {
      print('LUMARA: Error reading nodes.jsonl: $e');
    }
    
    return nodes;
  }

  Future<List<ReflectiveNode>> _parseJournalZip(String bundlePath) async {
    final nodes = <ReflectiveNode>[];
    
    try {
      final bundleDir = Directory(bundlePath);
      final journalZipFile = File('${bundleDir.path}/journal_v1.mcp.zip');
      
      if (!await journalZipFile.exists()) {
        print('LUMARA: journal_v1.mcp.zip not found in bundle');
        return nodes;
      }
      
      final bytes = await journalZipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      for (final file in archive) {
        if (file.isFile && file.name.startsWith('entries/') && file.name.endsWith('.json')) {
          try {
            final content = utf8.decode(file.content as List<int>);
            final json = jsonDecode(content) as Map<String, dynamic>;
            
            final node = _createReflectiveNodeFromJournalEntry(json);
            if (node != null) {
              nodes.add(node);
            }
          } catch (e) {
            print('LUMARA: Error parsing journal entry ${file.name}: $e');
            continue;
          }
        }
      }
    } catch (e) {
      print('LUMARA: Error parsing journal ZIP: $e');
    }
    
    return nodes;
  }

  Future<List<ReflectiveNode>> _parseMediaPacks(String bundlePath) async {
    final nodes = <ReflectiveNode>[];
    
    try {
      final bundleDir = Directory(bundlePath);
      final files = await bundleDir.list().toList();
      
      for (final file in files) {
        if (file is File && file.path.contains('mcp_media_') && file.path.endsWith('.zip')) {
          final mediaNodes = await _parseMediaPack(file.path);
          nodes.addAll(mediaNodes);
        }
      }
    } catch (e) {
      print('LUMARA: Error parsing media packs: $e');
    }
    
    return nodes;
  }

  Future<List<ReflectiveNode>> _parseMediaPack(String packPath) async {
    final nodes = <ReflectiveNode>[];
    
    try {
      final bytes = await File(packPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      for (final file in archive) {
        if (file.isFile && file.name.endsWith('.json')) {
          try {
            final content = utf8.decode(file.content as List<int>);
            final json = jsonDecode(content) as Map<String, dynamic>;
            
            final node = _createReflectiveNodeFromMedia(json, packPath);
            if (node != null) {
              nodes.add(node);
            }
          } catch (e) {
            print('LUMARA: Error parsing media file ${file.name}: $e');
            continue;
          }
        }
      }
    } catch (e) {
      print('LUMARA: Error parsing media pack $packPath: $e');
    }
    
    return nodes;
  }

  Future<List<ReflectiveNode>> _parseDrafts(String bundlePath) async {
    // TODO: Implement draft parsing if drafts are stored in MCP bundles
    // For now, return empty list
    return [];
  }

  /// Create a ReflectiveNode from phase regime data
  ReflectiveNode? _createPhaseRegimeNode(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
      final timestamp = _parseTimestamp(json['timestamp'] ?? json['created_at']);
      final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
      
      // Extract phase regime information
      final phaseLabel = metadata['phase_label'] as String? ?? 'discovery';
      final phaseSource = metadata['phase_source'] as String? ?? 'user';
      final confidence = metadata['confidence'] as double?;
      final startTime = metadata['start_time'] as String?;
      final endTime = metadata['end_time'] as String?;
      final isOngoing = metadata['is_ongoing'] as bool? ?? false;
      final anchors = (metadata['anchors'] as List<dynamic>?)?.cast<String>() ?? [];
      
      // Create content summary
      final contentSummary = 'Phase: ${phaseLabel.toUpperCase()}';
      if (startTime != null) {
        final start = DateTime.tryParse(startTime);
        final end = endTime != null ? DateTime.tryParse(endTime) : null;
        if (start != null) {
          final duration = (end ?? DateTime.now()).difference(start);
          contentSummary += ' (${duration.inDays} days)';
        }
      }
      
      // Extract phase hint
      PhaseHint? phaseHint;
      try {
        phaseHint = PhaseHint.values.firstWhere(
          (e) => e.name == phaseLabel.toLowerCase(),
          orElse: () => PhaseHint.discovery,
        );
      } catch (e) {
        phaseHint = PhaseHint.discovery;
      }
      
      return ReflectiveNode(
        id: id,
        content: contentSummary,
        timestamp: timestamp,
        type: NodeType.phaseRegime,
        phaseHint: phaseHint,
        keywords: [phaseLabel],
        metadata: {
          'phase_regime_id': id,
          'phase_label': phaseLabel,
          'phase_source': phaseSource,
          'confidence': confidence,
          'start_time': startTime,
          'end_time': endTime,
          'is_ongoing': isOngoing,
          'anchors': anchors,
          'duration_days': metadata['duration_days'],
        },
      );
    } catch (e) {
      print('LUMARA: Error creating phase regime node: $e');
      return null;
    }
  }

  /// Create a ReflectiveNode from ChatSession data
  ReflectiveNode? _createChatSessionNode(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
      final timestamp = _parseTimestamp(json['timestamp'] ?? json['created_at']);
      final contentSummary = json['contentSummary'] as String? ?? '';
      final keywords = (json['keywords'] as List<dynamic>?)?.cast<String>() ?? [];
      
      return ReflectiveNode(
        id: id,
        content: contentSummary,
        timestamp: timestamp,
        type: NodeType.chatSession,
        keywords: keywords,
        metadata: {
          'chat_session_id': id,
          'subject': contentSummary,
          'tags': keywords,
        },
      );
    } catch (e) {
      print('LUMARA: Error creating chat session node: $e');
      return null;
    }
  }

  /// Create a ReflectiveNode from ChatMessage data
  ReflectiveNode? _createChatMessageNode(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
      final timestamp = _parseTimestamp(json['timestamp'] ?? json['created_at']);
      final contentSummary = json['contentSummary'] as String? ?? '';
      
      return ReflectiveNode(
        id: id,
        content: contentSummary,
        timestamp: timestamp,
        type: NodeType.chatMessage,
        keywords: [],
        metadata: {
          'chat_message_id': id,
          'content': contentSummary,
        },
      );
    } catch (e) {
      print('LUMARA: Error creating chat message node: $e');
      return null;
    }
  }

  ReflectiveNode? _createReflectiveNodeFromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
      final type = json['type'] as String? ?? 'unknown';
      final content = json['content'] as String? ?? '';
      final createdAt = _parseTimestamp(json['created_at'] ?? json['timestamp']);
      final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
      final mediaCount = json['media_count'] as int? ?? 0;
      
      // Handle different node types
      if (type == 'phase_regime') {
        return _createPhaseRegimeNode(json);
      } else if (type == 'ChatSession') {
        return _createChatSessionNode(json);
      } else if (type == 'ChatMessage') {
        return _createChatMessageNode(json);
      }
      
      // Extract phase hint from metadata
      PhaseHint? phaseHint;
      final phaseStr = metadata['phase_hint'] as String?;
      if (phaseStr != null) {
        phaseHint = PhaseHint.values.firstWhere(
          (e) => e.name == phaseStr.toLowerCase(),
          orElse: () => PhaseHint.discovery,
        );
      }
      
      // Create media refs if media_count > 0
      List<MediaRef>? mediaRefs;
      if (mediaCount > 0) {
        mediaRefs = [
          MediaRef(
            id: 'media_${id}_${DateTime.now().millisecondsSinceEpoch}',
            mimeType: 'application/octet-stream',
            caption: 'Media attachment',
          ),
        ];
      }
      
      // Use original keywords if available, otherwise extract from content
      final originalKeywords = json['keywords'] as List<dynamic>?;
      final keywords = originalKeywords?.cast<String>() ?? _extractKeywords(content);
      
      return ReflectiveNode(
        id: id,
        mcpId: metadata['original_mcp_id'] as String?,
        type: NodeType.journal,
        contentText: content,
        keywords: keywords,
        phaseHint: phaseHint,
        mediaRefs: mediaRefs,
        createdAt: createdAt,
        importTimestamp: DateTime.now(),
        userId: 'default', // TODO: Get from user context
        sourceBundleId: _extractBundleId(json),
        extra: {
          'media_count': mediaCount,
          'imported_from_mcp': true,
        },
      );
    } catch (e) {
      print('LUMARA: Error creating ReflectiveNode from JSON: $e');
      return null;
    }
  }

  ReflectiveNode? _createReflectiveNodeFromJournalEntry(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
      final content = json['content'] as String? ?? '';
      final timestamp = _parseTimestamp(json['timestamp'] ?? json['created_at']);
      final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
      
      // Extract phase hint
      PhaseHint? phaseHint;
      final phaseStr = metadata['phase_hint'] as String?;
      if (phaseStr != null) {
        phaseHint = PhaseHint.values.firstWhere(
          (e) => e.name == phaseStr.toLowerCase(),
          orElse: () => PhaseHint.discovery,
        );
      }
      
      // Extract media references
      List<MediaRef>? mediaRefs;
      final media = json['media'] as List<dynamic>?;
      if (media != null && media.isNotEmpty) {
        mediaRefs = media.map((m) {
          final mediaJson = m as Map<String, dynamic>;
          return MediaRef(
            id: mediaJson['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
            mimeType: mediaJson['mimeType'] as String?,
            sha256: mediaJson['sha256'] as String?,
            caption: mediaJson['caption'] as String?,
          );
        }).toList();
      }
      
      // Use original keywords if available, otherwise extract from content
      final originalKeywords = json['keywords'] as List<dynamic>?;
      final keywords = originalKeywords?.cast<String>() ?? _extractKeywords(content);
      
      return ReflectiveNode(
        id: id,
        mcpId: metadata['original_mcp_id'] as String?,
        type: NodeType.journal,
        contentText: content,
        keywords: keywords,
        phaseHint: phaseHint,
        mediaRefs: mediaRefs,
        createdAt: timestamp,
        importTimestamp: DateTime.now(),
        userId: 'default',
        sourceBundleId: _extractBundleId(json),
        extra: {
          'from_journal_zip': true,
        },
      );
    } catch (e) {
      print('LUMARA: Error creating ReflectiveNode from journal entry: $e');
      return null;
    }
  }

  ReflectiveNode? _createReflectiveNodeFromMedia(Map<String, dynamic> json, String packPath) {
    try {
      final id = json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
      final mimeType = json['mimeType'] as String? ?? 'application/octet-stream';
      final caption = json['caption'] as String?;
      final timestamp = _parseTimestamp(json['created_at'] ?? json['timestamp']);
      
      // Determine node type from MIME type
      NodeType type;
      if (mimeType.startsWith('image/')) {
        type = NodeType.photo;
      } else if (mimeType.startsWith('audio/')) {
        type = NodeType.audio;
      } else if (mimeType.startsWith('video/')) {
        type = NodeType.video;
      } else {
        type = NodeType.photo; // Default fallback
      }
      
      return ReflectiveNode(
        id: id,
        mcpId: json['original_mcp_id'] as String?,
        type: type,
        captionText: caption,
        keywords: caption != null ? _extractKeywords(caption) : null,
        mediaRefs: [
          MediaRef(
            id: id,
            mimeType: mimeType,
            sha256: json['sha256'] as String?,
            caption: caption,
            bytes: json['bytes'] as int?,
            width: json['width'] as int?,
            height: json['height'] as int?,
            durationSec: json['durationSec'] as double?,
          ),
        ],
        createdAt: timestamp,
        importTimestamp: DateTime.now(),
        userId: 'default',
        sourceBundleId: _extractBundleId(json),
        extra: {
          'from_media_pack': true,
          'pack_path': packPath,
        },
      );
    } catch (e) {
      print('LUMARA: Error creating ReflectiveNode from media: $e');
      return null;
    }
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp).toUtc();
      } catch (e) {
        print('LUMARA: Error parsing timestamp "$timestamp": $e');
        return DateTime.now();
      }
    }
    
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toUtc();
    }
    
    return DateTime.now();
  }

  List<String> _extractKeywords(String text) {
    if (text.isEmpty) return [];
    
    // Simple keyword extraction - split by whitespace and common delimiters
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 3)
        .toList();
    
    // Count word frequency
    final wordCount = <String, int>{};
    for (final word in words) {
      wordCount[word] = (wordCount[word] ?? 0) + 1;
    }
    
    // Return top 10 most frequent words
    final sortedWords = wordCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedWords.take(10).map((e) => e.key).toList();
  }

  String _extractBundleId(Map<String, dynamic> json) {
    // Extract bundle ID from various possible fields
    return json['bundle_id'] as String? ??
           json['sourceBundleId'] as String? ??
           'unknown_bundle';
  }
}
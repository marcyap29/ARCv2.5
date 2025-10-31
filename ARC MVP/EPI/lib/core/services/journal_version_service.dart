/// Journal Version Service
///
/// Manages immutable versions and draft state for journal entries.
/// Implements single-draft-per-entry, content-hash-based autosave, and versioning.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/lumara/chat/ulid.dart' as ulid;

/// Represents an immutable version of a journal entry
class JournalVersion {
  final String versionId; // ULID
  final int rev; // Revision number, starting at 1
  final String entryId; // Entry ULID
  final String content;
  final List<MediaItem> media;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final String? baseVersionId; // If editing an old version, reference the base
  final String? phase;
  final Map<String, dynamic>? sentiment; // Optional sentiment data
  final String contentHash; // SHA-256 of content for deduplication

  JournalVersion({
    required this.versionId,
    required this.rev,
    required this.entryId,
    required this.content,
    required this.media,
    this.metadata = const {},
    required this.createdAt,
    this.baseVersionId,
    this.phase,
    this.sentiment,
    required this.contentHash,
  });

  Map<String, dynamic> toJson() => {
    'versionId': versionId,
    'rev': rev,
    'entryId': entryId,
    'content': content,
    'media': media.map((m) => m.toJson()).toList(),
    'metadata': metadata,
    'createdAt': createdAt.toIso8601String(),
    'baseVersionId': baseVersionId,
    'phase': phase,
    'sentiment': sentiment,
    'contentHash': contentHash,
  };

  factory JournalVersion.fromJson(Map<String, dynamic> json) {
    return JournalVersion(
      versionId: json['versionId'] as String,
      rev: json['rev'] as int,
      entryId: json['entryId'] as String,
      content: json['content'] as String,
      media: (json['media'] as List?)
          ?.map((item) => MediaItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      createdAt: DateTime.parse(json['createdAt'] as String),
      baseVersionId: json['baseVersionId'] as String?,
      phase: json['phase'] as String?,
      sentiment: json['sentiment'] != null 
          ? Map<String, dynamic>.from(json['sentiment'] as Map)
          : null,
      contentHash: json['contentHash'] as String,
    );
  }
}

/// Represents the latest version pointer
class LatestVersion {
  final int rev;
  final String versionId;
  final DateTime updatedAt;

  LatestVersion({
    required this.rev,
    required this.versionId,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'rev': rev,
    'versionId': versionId,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory LatestVersion.fromJson(Map<String, dynamic> json) {
    return LatestVersion(
      rev: json['rev'] as int,
      versionId: json['versionId'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// Media reference in draft/version
class DraftMediaItem {
  final String id; // ULID
  final String kind; // 'image' | 'video' | 'audio'
  final String? filename;
  final String? mime;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? thumb; // relative path to thumbnail
  final String path; // relative path to original
  final String sha256; // Content hash
  final DateTime createdAt;

  DraftMediaItem({
    required this.id,
    required this.kind,
    this.filename,
    this.mime,
    this.width,
    this.height,
    this.durationMs,
    this.thumb,
    required this.path,
    required this.sha256,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'filename': filename,
    'mime': mime,
    'width': width,
    'height': height,
    'duration_ms': durationMs,
    'thumb': thumb,
    'path': path,
    'sha256': sha256,
    'created_at': createdAt.toIso8601String(),
  };

  factory DraftMediaItem.fromJson(Map<String, dynamic> json) {
    return DraftMediaItem(
      id: json['id'] as String,
      kind: json['kind'] as String,
      filename: json['filename'] as String?,
      mime: json['mime'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      durationMs: json['duration_ms'] as int?,
      thumb: json['thumb'] as String?,
      path: json['path'] as String,
      sha256: json['sha256'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  DraftMediaItem copyWith({
    String? id,
    String? kind,
    String? filename,
    String? mime,
    int? width,
    int? height,
    int? durationMs,
    String? thumb,
    String? path,
    String? sha256,
    DateTime? createdAt,
  }) {
    return DraftMediaItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      filename: filename ?? this.filename,
      mime: mime ?? this.mime,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs ?? this.durationMs,
      thumb: thumb ?? this.thumb,
      path: path ?? this.path,
      sha256: sha256 ?? this.sha256,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// AI content block in draft/version
class DraftAIContent {
  final String id; // ULID
  final String role; // 'assistant' | 'system' | 'user'
  final String scope; // 'inline' | 'sidebar'
  final String purpose; // 'suggestion' | 'reflection' | 'prompt'
  final String text;
  final DateTime createdAt;
  final Map<String, dynamic>? models; // e.g., {"name":"LUMARA-...","params":{}}
  final Map<String, dynamic>? provenance; // e.g., {"source":"in-journal","trace_id":"..."}

  DraftAIContent({
    required this.id,
    required this.role,
    required this.scope,
    required this.purpose,
    required this.text,
    required this.createdAt,
    this.models,
    this.provenance,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'scope': scope,
    'purpose': purpose,
    'text': text,
    'created_at': createdAt.toIso8601String(),
    'models': models,
    'provenance': provenance,
  };

  factory DraftAIContent.fromJson(Map<String, dynamic> json) {
    return DraftAIContent(
      id: json['id'] as String,
      role: json['role'] as String,
      scope: json['scope'] as String,
      purpose: json['purpose'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      models: json['models'] != null ? Map<String, dynamic>.from(json['models']) : null,
      provenance: json['provenance'] != null ? Map<String, dynamic>.from(json['provenance']) : null,
    );
  }
}

/// Represents a working draft with hash tracking (includes media and AI)
class JournalDraftWithHash {
  final String entryId;
  final String type; // 'journal'
  final String content; // Text content
  final List<DraftMediaItem> media;
  final List<DraftAIContent> ai;
  final Map<String, dynamic> metadata;
  final DateTime updatedAt;
  final String? baseVersionId;
  final String? phase;
  final Map<String, dynamic>? sentiment;
  final String contentHash;
  final DateTime createdAt;

  JournalDraftWithHash({
    required this.entryId,
    this.type = 'journal',
    required this.content,
    required this.media,
    required this.ai,
    this.metadata = const {},
    required this.updatedAt,
    this.baseVersionId,
    this.phase,
    this.sentiment,
    required this.contentHash,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'entry_id': entryId,
    'type': type,
    'content': {
      'text': content,
      'blocks': [], // Rich blocks can be added later
    },
    'media': media.map((m) => m.toJson()).toList(),
    'ai': ai.map((a) => a.toJson()).toList(),
    'metadata': metadata,
    'updated_at': updatedAt.toIso8601String(),
    'base_version_id': baseVersionId,
    'phase': phase,
    'sentiment': sentiment,
    'content_hash': contentHash,
    'created_at': createdAt.toIso8601String(),
  };

  factory JournalDraftWithHash.fromJson(Map<String, dynamic> json) {
    final contentObj = json['content'];
    final contentText = contentObj is Map
        ? (contentObj['text'] as String? ?? json['content'] as String? ?? '')
        : (json['content'] as String? ?? '');
    
    return JournalDraftWithHash(
      entryId: (json['entry_id'] ?? json['entryId']) as String,
      type: json['type'] as String? ?? 'journal',
      content: contentText,
      media: (json['media'] as List?)
          ?.map((item) => DraftMediaItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      ai: (json['ai'] as List?)
          ?.map((item) => DraftAIContent.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      updatedAt: DateTime.parse((json['updated_at'] ?? json['updatedAt']) as String),
      baseVersionId: (json['base_version_id'] ?? json['baseVersionId']) as String?,
      phase: json['phase'] as String?,
      sentiment: json['sentiment'] != null
          ? Map<String, dynamic>.from(json['sentiment'] as Map)
          : null,
      contentHash: (json['content_hash'] ?? json['contentHash']) as String,
      createdAt: DateTime.parse((json['created_at'] ?? json['createdAt']) as String),
    );
  }

  JournalDraftWithHash copyWith({
    String? content,
    List<DraftMediaItem>? media,
    List<DraftAIContent>? ai,
    Map<String, dynamic>? metadata,
    DateTime? updatedAt,
    String? baseVersionId,
    String? phase,
    Map<String, dynamic>? sentiment,
    String? contentHash,
  }) {
    final newContent = content ?? this.content;
    final newMedia = media ?? this.media;
    final newAi = ai ?? this.ai;
    
    return JournalDraftWithHash(
      entryId: entryId,
      type: type,
      content: newContent,
      media: newMedia,
      ai: newAi,
      metadata: metadata ?? this.metadata,
      updatedAt: updatedAt ?? DateTime.now(),
      baseVersionId: baseVersionId ?? this.baseVersionId,
      phase: phase ?? this.phase,
      sentiment: sentiment ?? this.sentiment,
      contentHash: contentHash ?? _computeContentHash(newContent, newMedia, newAi),
      createdAt: createdAt,
    );
  }

  /// Compute content hash including text, media SHA256s, and AI IDs
  static String _computeContentHash(
    String content,
    List<DraftMediaItem> media,
    List<DraftAIContent> ai,
  ) {
    // Normalize: text + sorted media SHA256s + sorted AI IDs
    final mediaHashes = media.map((m) => m.sha256).toList()..sort();
    final aiIds = ai.map((a) => a.id).toList()..sort();
    
    final normalized = '$content|${mediaHashes.join('|')}|${aiIds.join('|')}';
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

/// Service for managing journal entry versions and drafts
class JournalVersionService {
  static JournalVersionService? _instance;
  static JournalVersionService get instance => _instance ??= JournalVersionService._();
  JournalVersionService._();

  /// Get the MCP entries directory for an entry (public for extension)
  Future<Directory> _getEntryDir(String entryId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final mcpDir = Directory(path.join(appDir.path, 'mcp', 'entries', entryId));
    if (!await mcpDir.exists()) {
      await mcpDir.create(recursive: true);
    }
    return mcpDir;
  }

  /// Compute SHA-256 hash of content (legacy - use JournalDraftWithHash._computeContentHash for media+AI)
  static String computeContentHash(String content) {
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate a ULID using the ULID class
  static String generateUlid() {
    return ulid.ULID.generate();
  }

  /// Get draft for an entry (if exists)
  Future<JournalDraftWithHash?> getDraft(String entryId) async {
    try {
      final entryDir = await _getEntryDir(entryId);
      final draftFile = File(path.join(entryDir.path, 'draft.json'));
      if (!await draftFile.exists()) return null;

      final content = await draftFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return JournalDraftWithHash.fromJson(json);
    } catch (e) {
      debugPrint('JournalVersionService: Error reading draft: $e');
      return null;
    }
  }

  /// Convert MediaItem to DraftMediaItem (with file copying)
  Future<DraftMediaItem?> _convertMediaItem(
    MediaItem mediaItem,
    String entryId,
    String draftMediaDir,
  ) async {
    try {
      final sourceFile = File(mediaItem.uri);
      if (!await sourceFile.exists()) {
        debugPrint('JournalVersionService: Media file not found: ${mediaItem.uri}');
        return null;
      }

      // Get file info
      final bytes = await sourceFile.readAsBytes();
      final fileHash = sha256.convert(bytes).toString();
      
      // Determine media kind
      final kind = mediaItem.type == MediaType.video 
          ? 'video' 
          : mediaItem.type == MediaType.audio 
              ? 'audio' 
              : 'image';

      // Copy to draft_media/ with hash-based filename
      final extension = mediaItem.uri.split('.').last;
      final fileName = '$fileHash.$extension';
      final targetPath = path.join(draftMediaDir, fileName);
      
      final targetFile = File(targetPath);
      if (!await targetFile.exists()) {
        await targetFile.writeAsBytes(bytes);
      }

      // Generate thumbnail for images/videos (async, don't block)
      String? thumbPath;
      if (kind == 'image' || kind == 'video') {
        // TODO: Generate thumbnail - for now use same file
        thumbPath = fileName; // Will be implemented with image processing
      }

      return DraftMediaItem(
        id: mediaItem.id,
        kind: kind,
        filename: sourceFile.path.split('/').last,
        mime: _getMimeType(extension),
        width: null, // TODO: Extract from image/video if needed
        height: null, // TODO: Extract from image/video if needed
        durationMs: mediaItem.duration?.inMilliseconds,
        thumb: thumbPath,
        path: 'draft_media/$fileName', // Relative path
        sha256: fileHash,
        createdAt: mediaItem.createdAt,
      );
    } catch (e) {
      debugPrint('JournalVersionService: Error converting media item: $e');
      return null;
    }
  }

  /// Get MIME type from file extension (public for extension)
  String? _getMimeType(String extension) {
    return _getMimeTypeStatic(extension);
  }

  /// Static helper for MIME type
  static String? _getMimeTypeStatic(String extension) {
    final ext = extension.toLowerCase();
    if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
    if (ext == 'png') return 'image/png';
    if (ext == 'gif') return 'image/gif';
    if (ext == 'mp4') return 'video/mp4';
    if (ext == 'mov') return 'video/quicktime';
    if (ext == 'm4a') return 'audio/mp4';
    if (ext == 'mp3') return 'audio/mpeg';
    return null;
  }

  /// Save draft with hash checking (includes media and AI)
  Future<bool> saveDraft({
    required String entryId,
    required String content,
    required List<MediaItem> media,
    List<DraftAIContent>? ai,
    Map<String, dynamic>? metadata,
    String? baseVersionId,
    String? phase,
    Map<String, dynamic>? sentiment,
  }) async {
    try {
      final entryDir = await _getEntryDir(entryId);
      final draftMediaDir = path.join(entryDir.path, 'draft_media');
      await Directory(draftMediaDir).create(recursive: true);

      // Convert MediaItems to DraftMediaItems (copy files)
      final draftMedia = <DraftMediaItem>[];
      for (final mediaItem in media) {
        final draftMediaItem = await _convertMediaItem(mediaItem, entryId, draftMediaDir);
        if (draftMediaItem != null) {
          draftMedia.add(draftMediaItem);
        }
      }

      final draftAi = ai ?? [];
      
      // Compute hash including media and AI
      final newHash = JournalDraftWithHash._computeContentHash(content, draftMedia, draftAi);
      
      // Check existing draft
      final existingDraft = await getDraft(entryId);
      if (existingDraft != null && existingDraft.contentHash == newHash) {
        debugPrint('JournalVersionService: Draft content unchanged (hash match), skipping write');
        return false; // No change
      }

      // Create or update draft
      final draft = existingDraft?.copyWith(
        content: content,
        media: draftMedia,
        ai: draftAi,
        metadata: metadata,
        baseVersionId: baseVersionId,
        phase: phase,
        sentiment: sentiment,
      ) ?? JournalDraftWithHash(
        entryId: entryId,
        content: content,
        media: draftMedia,
        ai: draftAi,
        metadata: metadata ?? {},
        updatedAt: DateTime.now(),
        baseVersionId: baseVersionId,
        phase: phase,
        sentiment: sentiment,
        contentHash: newHash,
        createdAt: DateTime.now(),
      );

      // Write draft file
      final draftFile = File(path.join(entryDir.path, 'draft.json'));
      await draftFile.writeAsString(jsonEncode(draft.toJson()));

      debugPrint('JournalVersionService: Draft saved for entry $entryId (hash: ${draft.contentHash.substring(0, 8)}..., ${draftMedia.length} media, ${draftAi.length} AI)');
      return true; // Written
    } catch (e) {
      debugPrint('JournalVersionService: Error saving draft: $e');
      rethrow;
    }
  }

  /// Get latest version pointer
  Future<LatestVersion?> getLatestVersion(String entryId) async {
    try {
      final entryDir = await _getEntryDir(entryId);
      final latestFile = File(path.join(entryDir.path, 'latest.json'));
      if (!await latestFile.exists()) return null;

      final content = await latestFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return LatestVersion.fromJson(json);
    } catch (e) {
      debugPrint('JournalVersionService: Error reading latest version: $e');
      return null;
    }
  }

  /// Get a specific version by revision number
  Future<JournalVersion?> getVersion(String entryId, int rev) async {
    try {
      final entryDir = await _getEntryDir(entryId);
      final versionDir = Directory(path.join(entryDir.path, 'v'));
      if (!await versionDir.exists()) return null;

      final versionFile = File(path.join(versionDir.path, '$rev.json'));
      if (!await versionFile.exists()) return null;

      final content = await versionFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return JournalVersion.fromJson(json);
    } catch (e) {
      debugPrint('JournalVersionService: Error reading version: $e');
      return null;
    }
  }

  /// Get all versions for an entry (sorted by rev)
  Future<List<JournalVersion>> getAllVersions(String entryId) async {
    try {
      final entryDir = await _getEntryDir(entryId);
      final versionDir = Directory(path.join(entryDir.path, 'v'));
      if (!await versionDir.exists()) return [];

      final versions = <JournalVersion>[];
      await for (final entity in versionDir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            versions.add(JournalVersion.fromJson(json));
          } catch (e) {
            debugPrint('JournalVersionService: Error parsing version file ${entity.path}: $e');
          }
        }
      }

      versions.sort((a, b) => a.rev.compareTo(b.rev));
      return versions;
    } catch (e) {
      debugPrint('JournalVersionService: Error listing versions: $e');
      return [];
    }
  }

  /// Snapshot media files from draft_media/ to version_media/
  Future<void> _snapshotMedia(
    String entryId,
    int rev,
    List<DraftMediaItem> draftMedia,
  ) async {
    try {
      final entryDir = await _getEntryDir(entryId);
      final draftMediaDir = Directory(path.join(entryDir.path, 'draft_media'));
      final versionMediaDir = Directory(path.join(entryDir.path, 'v', '${rev}_media'));
      await versionMediaDir.create(recursive: true);

      // Copy each media file from draft_media/ to version_media/
      for (final mediaItem in draftMedia) {
        final fileName = mediaItem.path.split('/').last;
        final sourceFile = File(path.join(draftMediaDir.path, fileName));
        if (await sourceFile.exists()) {
          final targetFile = File(path.join(versionMediaDir.path, fileName));
          await sourceFile.copy(targetFile.path);
        }
      }

      debugPrint('JournalVersionService: Snapshot media for v$rev (${draftMedia.length} files)');
    } catch (e) {
      debugPrint('JournalVersionService: Error snapshotting media: $e');
      // Don't fail the version save if media snapshot fails
    }
  }

  /// Save a new version (increments rev, snapshots media)
  Future<JournalVersion> saveVersion({
    required String entryId,
    required String content,
    required List<MediaItem> media,
    List<DraftAIContent>? ai,
    Map<String, dynamic>? metadata,
    String? baseVersionId,
    String? phase,
    Map<String, dynamic>? sentiment,
  }) async {
    try {
      // Get draft to use its media/AI
      final draft = await getDraft(entryId);
      final draftMedia = draft?.media ?? [];
      final draftAi = ai ?? draft?.ai ?? [];

      // Get latest version to determine next rev
      final latest = await getLatestVersion(entryId);
      final nextRev = (latest?.rev ?? 0) + 1;

      final versionId = generateUlid();
      
      // Convert draft media to version media format
      final versionMedia = <DraftMediaItem>[];
      for (final draftMediaItem in draftMedia) {
        // Update path to point to version_media/
        versionMedia.add(DraftMediaItem(
          id: draftMediaItem.id,
          kind: draftMediaItem.kind,
          filename: draftMediaItem.filename,
          mime: draftMediaItem.mime,
          width: draftMediaItem.width,
          height: draftMediaItem.height,
          durationMs: draftMediaItem.durationMs,
          thumb: draftMediaItem.thumb,
          path: 'v/${nextRev}_media/${draftMediaItem.path.split('/').last}',
          sha256: draftMediaItem.sha256,
          createdAt: draftMediaItem.createdAt,
        ));
      }

      final contentHash = JournalDraftWithHash._computeContentHash(content, versionMedia, draftAi);

      final version = JournalVersion(
        versionId: versionId,
        rev: nextRev,
        entryId: entryId,
        content: content,
        media: media, // Keep MediaItem list for compatibility
        metadata: metadata ?? {},
        createdAt: DateTime.now(),
        baseVersionId: baseVersionId,
        phase: phase,
        sentiment: sentiment,
        contentHash: contentHash,
      );

      // Write version file
      final entryDir = await _getEntryDir(entryId);
      final versionDir = Directory(path.join(entryDir.path, 'v'));
      await versionDir.create(recursive: true);
      final versionFile = File(path.join(versionDir.path, '$nextRev.json'));
      await versionFile.writeAsString(jsonEncode(version.toJson()));

      // Snapshot media files
      await _snapshotMedia(entryId, nextRev, draftMedia);

      debugPrint('JournalVersionService: Saved version v$nextRev for entry $entryId');
      return version;
    } catch (e) {
      debugPrint('JournalVersionService: Error saving version: $e');
      rethrow;
    }
  }

  /// Publish draft (saves as version, updates latest, clears draft and draft_media/)
  Future<JournalVersion> publish({
    required String entryId,
    required String content,
    required List<MediaItem> media,
    List<DraftAIContent>? ai,
    Map<String, dynamic>? metadata,
    String? phase,
    Map<String, dynamic>? sentiment,
  }) async {
    try {
      // Get draft to preserve baseVersionId if editing old version
      final draft = await getDraft(entryId);
      final baseVersionId = draft?.baseVersionId;
      final draftAi = ai ?? draft?.ai ?? [];

      // Save as new version (this snapshots media)
      final version = await saveVersion(
        entryId: entryId,
        content: content,
        media: media,
        ai: draftAi,
        metadata: metadata,
        baseVersionId: baseVersionId,
        phase: phase,
        sentiment: sentiment,
      );

      // Update latest.json
      final entryDir = await _getEntryDir(entryId);
      final latestFile = File(path.join(entryDir.path, 'latest.json'));
      final latest = LatestVersion(
        rev: version.rev,
        versionId: version.versionId,
        updatedAt: DateTime.now(),
      );
      await latestFile.writeAsString(jsonEncode(latest.toJson()));

      // Clear draft and draft_media/
      await discardDraft(entryId);
      final draftMediaDir = Directory(path.join(entryDir.path, 'draft_media'));
      if (await draftMediaDir.exists()) {
        await draftMediaDir.delete(recursive: true);
      }

      debugPrint('JournalVersionService: Published version v${version.rev} for entry $entryId');
      return version;
    } catch (e) {
      debugPrint('JournalVersionService: Error publishing: $e');
      rethrow;
    }
  }

  /// Discard draft (delete draft.json, keep versions)
  Future<void> discardDraft(String entryId) async {
    try {
      final entryDir = await _getEntryDir(entryId);
      final draftFile = File(path.join(entryDir.path, 'draft.json'));
      if (await draftFile.exists()) {
        await draftFile.delete();
        debugPrint('JournalVersionService: Discarded draft for entry $entryId');
      }
    } catch (e) {
      debugPrint('JournalVersionService: Error discarding draft: $e');
      rethrow;
    }
  }

  /// Check for conflicts (same entry modified on different devices)
  Future<ConflictInfo?> checkConflict(String entryId) async {
    try {
      final draft = await getDraft(entryId);
      if (draft == null) return null;

      // Get latest version
      final latest = await getLatestVersion(entryId);
      if (latest == null) return null;

      // Get the latest version content to compare
      final latestVersion = await getVersion(entryId, latest.rev);
      if (latestVersion == null) return null;

      if (draft.baseVersionId != null) {
        // Draft is based on an old version
        final baseVersion = await _findVersionByVersionId(entryId, draft.baseVersionId!);
        if (baseVersion == null) return null;

        // If latest rev is newer than base, there's a conflict
        if (latest.rev > baseVersion.rev) {
          return ConflictInfo(
            localHash: draft.contentHash,
            localUpdatedAt: draft.updatedAt,
            remoteHash: latestVersion.contentHash,
            remoteUpdatedAt: latestVersion.createdAt,
            localDraft: draft,
            remoteVersion: latestVersion,
          );
        }
      } else {
        // Draft is based on latest, check if content differs
        if (draft.contentHash != latestVersion.contentHash) {
          // Content differs - potential conflict if timestamps overlap
          final timeDiff = draft.updatedAt.difference(latestVersion.createdAt).abs();
          if (timeDiff.inHours < 1) {
            // Modified within 1 hour - consider it a conflict
            return ConflictInfo(
              localHash: draft.contentHash,
              localUpdatedAt: draft.updatedAt,
              remoteHash: latestVersion.contentHash,
              remoteUpdatedAt: latestVersion.createdAt,
              localDraft: draft,
              remoteVersion: latestVersion,
            );
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('JournalVersionService: Error checking conflict: $e');
      return null;
    }
  }

  /// Find version by versionId
  Future<JournalVersion?> _findVersionByVersionId(String entryId, String versionId) async {
    final versions = await getAllVersions(entryId);
    try {
      return versions.firstWhere((v) => v.versionId == versionId);
    } catch (e) {
      return null;
    }
  }

  /// Migrate legacy media files to new draft_media/ structure
  /// Scans entries for existing media in /photos/ or entry attachments/ directories
  Future<MigrationResult> migrateLegacyMedia() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mcpEntriesDir = Directory(path.join(appDir.path, 'mcp', 'entries'));
      
      int entriesProcessed = 0;
      int mediaFilesMigrated = 0;
      int errors = 0;

      // Process entries that have media references
      if (await mcpEntriesDir.exists()) {
        await for (final entry in mcpEntriesDir.list()) {
          if (entry is Directory) {
            final entryId = path.basename(entry.path);
            
            try {
              // Check if there's a draft that might reference legacy media
              final draftFile = File(path.join(entry.path, 'draft.json'));
              if (await draftFile.exists()) {
                final draftData = await draftFile.readAsString();
                final draft = JournalDraftWithHash.fromJson(jsonDecode(draftData));
                
                // Check if draft has media with old-style paths
                bool needsMigration = false;
                final updatedMedia = <DraftMediaItem>[];
                
                for (final mediaItem in draft.media) {
                  // Check if path points to old /photos/ directory
                  if (mediaItem.path.contains('/photos/') && 
                      !mediaItem.path.contains('draft_media/') &&
                      !mediaItem.path.contains('v/')) {
                    needsMigration = true;
                    
                    // Try to find and copy file
                    final oldPath = path.join(appDir.path, mediaItem.path);
                    final oldFile = File(oldPath);
                    
                    if (await oldFile.exists()) {
                      // Copy to draft_media/
                      final draftMediaDir = Directory(path.join(entry.path, 'draft_media'));
                      await draftMediaDir.create(recursive: true);
                      
                      // Compute hash if not already set
                      String fileHash = mediaItem.sha256;
                      String finalFileName;
                      
                      if (fileHash.isEmpty) {
                        final bytes = await oldFile.readAsBytes();
                        fileHash = sha256.convert(bytes).toString();
                        final extension = oldPath.split('.').last;
                        finalFileName = '$fileHash.$extension';
                      } else {
                        finalFileName = '${mediaItem.sha256}.${oldPath.split('.').last}';
                      }
                      
                      final finalPath = path.join(draftMediaDir.path, finalFileName);
                      await oldFile.copy(finalPath);
                      
                      // Update media item path
                      updatedMedia.add(mediaItem.copyWith(
                        path: 'draft_media/$finalFileName',
                        sha256: fileHash,
                      ));
                      
                      mediaFilesMigrated++;
                    } else {
                      // File not found, keep original (might be in another location)
                      updatedMedia.add(mediaItem);
                      errors++;
                    }
                  } else {
                    // Path already in correct format
                    updatedMedia.add(mediaItem);
                  }
                }
                
                // Update draft if migration was needed
                if (needsMigration && updatedMedia.length == draft.media.length) {
                  final updatedDraft = draft.copyWith(media: updatedMedia);
                  await draftFile.writeAsString(jsonEncode(updatedDraft.toJson()));
                  entriesProcessed++;
                  debugPrint('JournalVersionService: Migrated media for entry $entryId');
                }
              }
              
              // Also check for legacy attachments/ directory
              final attachmentsDir = Directory(path.join(entry.path, 'attachments'));
              if (await attachmentsDir.exists()) {
                // Move files from attachments/ to draft_media/ if not already in draft
                await for (final file in attachmentsDir.list()) {
                  if (file is File) {
                    try {
                      final bytes = await file.readAsBytes();
                      final fileHash = sha256.convert(bytes).toString();
                      final extension = file.path.split('.').last;
                      final fileName = '$fileHash.$extension';
                      
                      final draftMediaDir = Directory(path.join(entry.path, 'draft_media'));
                      await draftMediaDir.create(recursive: true);
                      final targetPath = path.join(draftMediaDir.path, fileName);
                      
                      if (!await File(targetPath).exists()) {
                        await file.copy(targetPath);
                        mediaFilesMigrated++;
                        debugPrint('JournalVersionService: Migrated attachment file: $fileName');
                      }
                    } catch (e) {
                      debugPrint('JournalVersionService: Error migrating attachment: $e');
                      errors++;
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('JournalVersionService: Error processing entry $entryId: $e');
              errors++;
            }
          }
        }
      }

      debugPrint('JournalVersionService: Migration completed - $entriesProcessed entries, $mediaFilesMigrated media files');
      return MigrationResult(
        entriesProcessed: entriesProcessed,
        mediaFilesMigrated: mediaFilesMigrated,
        errors: errors,
      );
    } catch (e) {
      debugPrint('JournalVersionService: Error during migration: $e');
      return MigrationResult(entriesProcessed: 0, mediaFilesMigrated: 0, errors: 1);
    }
  }


  /// Migrate legacy drafts to new format (consolidate duplicates)
  Future<int> migrateLegacyDrafts() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mcpEntriesDir = Directory(path.join(appDir.path, 'mcp', 'entries'));
      if (!await mcpEntriesDir.exists()) {
        debugPrint('JournalVersionService: No MCP entries directory found, nothing to migrate');
        return 0;
      }

      int migrated = 0;
      await for (final entry in mcpEntriesDir.list()) {
        if (entry is Directory) {
          // Check for multiple draft files (draft.json, draft_*.json)
          final draftFiles = <File>[];
          await for (final file in entry.list()) {
            if (file is File && file.path.contains('draft') && file.path.endsWith('.json')) {
              draftFiles.add(file);
            }
          }
          
          if (draftFiles.length > 1) {
            // Multiple drafts found - keep the newest one
            // Sort by modification time
            final sortedFiles = await Future.wait(
              draftFiles.map((f) async {
                final stat = await f.stat();
                return {'file': f, 'modified': stat.modified};
              }),
            );
            sortedFiles.sort((a, b) => (b['modified'] as DateTime).compareTo(a['modified'] as DateTime));
            
            // Keep the first (newest) and delete the rest
            final newestDraft = sortedFiles.first['file'] as File;
            for (int i = 1; i < sortedFiles.length; i++) {
              final fileToDelete = sortedFiles[i]['file'] as File;
              await fileToDelete.delete();
              debugPrint('JournalVersionService: Deleted duplicate draft: ${fileToDelete.path}');
            }
            
            // Rename newest to draft.json if not already
            if (newestDraft.path != path.join(entry.path, 'draft.json')) {
              final targetFile = File(path.join(entry.path, 'draft.json'));
              await newestDraft.rename(targetFile.path);
            }
            
            migrated++;
          } else if (draftFiles.length == 1) {
            // Single draft - verify it's named correctly
            final draftFile = draftFiles.first;
            if (draftFile.path != path.join(entry.path, 'draft.json')) {
              final targetFile = File(path.join(entry.path, 'draft.json'));
              await draftFile.rename(targetFile.path);
            }
            migrated++;
          }
        }
      }

      debugPrint('JournalVersionService: Migration completed, verified/consolidated $migrated drafts');
      return migrated;
    } catch (e) {
      debugPrint('JournalVersionService: Error during migration: $e');
      return 0;
    }
  }
}

/// Migration result statistics
class MigrationResult {
  final int entriesProcessed;
  final int mediaFilesMigrated;
  final int errors;

  MigrationResult({
    required this.entriesProcessed,
    required this.mediaFilesMigrated,
    required this.errors,
  });
}

/// Conflict information for multi-device scenarios
class ConflictInfo {
  final String localHash;
  final DateTime localUpdatedAt;
  final String remoteHash;
  final DateTime remoteUpdatedAt;
  final JournalDraftWithHash? localDraft;
  final JournalVersion? remoteVersion;

  ConflictInfo({
    required this.localHash,
    required this.localUpdatedAt,
    required this.remoteHash,
    required this.remoteUpdatedAt,
    this.localDraft,
    this.remoteVersion,
  });
}

/// Conflict resolution action
enum ConflictResolution {
  keepLocal,
  keepRemote,
  merge,
}

/// Service extension for conflict resolution
extension ConflictResolutionExtension on JournalVersionService {
  /// Resolve conflict by merging media by SHA256
  Future<JournalDraftWithHash> resolveConflict({
    required String entryId,
    required ConflictInfo conflict,
    required ConflictResolution resolution,
  }) async {
    try {
      final draft = await getDraft(entryId);
      if (draft == null) {
        throw StateError('No draft found for conflict resolution');
      }

      switch (resolution) {
        case ConflictResolution.keepLocal:
          // Keep local draft as-is
          debugPrint('JournalVersionService: Keeping local draft');
          return draft;

        case ConflictResolution.keepRemote:
          // Load remote version content into draft
          if (conflict.remoteVersion == null) {
            throw StateError('Remote version not available');
          }
          final remoteVersion = conflict.remoteVersion!;
          
          // Get remote media if available (would need to load from version_media/)
          final mergedDraft = draft.copyWith(
            content: remoteVersion.content,
            baseVersionId: remoteVersion.versionId, // Update base to remote
          );
          
          await _saveDraftFile(entryId, mergedDraft);
          return mergedDraft;

        case ConflictResolution.merge:
          // Merge content and media by SHA256 deduplication
          if (conflict.remoteVersion == null) {
            throw StateError('Remote version not available for merge');
          }
          
          return await _mergeDrafts(
            entryId: entryId,
            localDraft: draft,
            remoteVersion: conflict.remoteVersion!,
          );
      }
    } catch (e) {
      debugPrint('JournalVersionService: Error resolving conflict: $e');
      rethrow;
    }
  }

  /// Merge local draft with remote version (dedupe media by SHA256)
  Future<JournalDraftWithHash> _mergeDrafts({
    required String entryId,
    required JournalDraftWithHash localDraft,
    required JournalVersion remoteVersion,
  }) async {
    final service = JournalVersionService.instance;
    final entryDir = await service._getEntryDir(entryId);
    final draftMediaDir = Directory(path.join(entryDir.path, 'draft_media'));
    await draftMediaDir.create(recursive: true);

    // Merge media by SHA256 (deduplicate)
    final mergedMedia = <DraftMediaItem>[];
    final mediaByHash = <String, DraftMediaItem>{};

    // Add local media first
    for (final mediaItem in localDraft.media) {
      mediaByHash[mediaItem.sha256] = mediaItem;
      mergedMedia.add(mediaItem);
    }

    // Add remote media (load from version_media/ if available)
    // Check if remote version has media snapshot
    final remoteVersionMediaDir = Directory(path.join(entryDir.path, 'v', '${remoteVersion.rev}_media'));
    if (await remoteVersionMediaDir.exists()) {
      // Load remote media files and add to merged list (dedupe by SHA256)
      await for (final entity in remoteVersionMediaDir.list()) {
        if (entity is File) {
          try {
            final bytes = await entity.readAsBytes();
            final fileHash = sha256.convert(bytes).toString();
            
            // Skip if already in merged media
            if (!mediaByHash.containsKey(fileHash)) {
              // Copy to draft_media/ if not exists
              final fileName = entity.path.split('/').last;
              final targetPath = path.join(draftMediaDir.path, fileName);
              final targetFile = File(targetPath);
              
              if (!await targetFile.exists()) {
                await entity.copy(targetPath);
              }

              // Create DraftMediaItem for remote media
              final kind = fileName.split('.').last.toLowerCase();
              final isVideo = kind == 'mp4' || kind == 'mov' || kind == 'avi';
              final isAudio = kind == 'mp3' || kind == 'm4a' || kind == 'wav';
              
              final remoteMediaItem = DraftMediaItem(
                id: JournalVersionService.generateUlid(),
                kind: isVideo ? 'video' : (isAudio ? 'audio' : 'image'),
                filename: fileName,
                mime: JournalVersionService._getMimeTypeStatic(kind),
                path: 'draft_media/$fileName',
                sha256: fileHash,
                createdAt: remoteVersion.createdAt,
              );
              
              mediaByHash[fileHash] = remoteMediaItem;
              mergedMedia.add(remoteMediaItem);
            }
          } catch (e) {
            debugPrint('JournalVersionService: Error processing remote media file: $e');
          }
        }
      }
    }

    // Merge AI content (dedupe by ID)
    final mergedAi = <DraftAIContent>[];
    final aiById = <String, DraftAIContent>{};

    // Add local AI content
    for (final aiItem in localDraft.ai) {
      aiById[aiItem.id] = aiItem;
      mergedAi.add(aiItem);
    }

    // Note: Remote version AI would be in version metadata if stored
    // For now, we keep local AI and merge content

    // Merge content: append remote with divider
    final mergedContent = '${localDraft.content}\n\n---\n\n${remoteVersion.content}';

    final mergedDraft = localDraft.copyWith(
      content: mergedContent,
      media: mergedMedia,
      ai: mergedAi,
      baseVersionId: remoteVersion.versionId, // Update base to latest
    );

    await _saveDraftFile(entryId, mergedDraft);
    debugPrint('JournalVersionService: Merged drafts (${mergedMedia.length} media, ${mergedAi.length} AI)');
    return mergedDraft;
  }

  /// Helper to save draft file
  Future<void> _saveDraftFile(String entryId, JournalDraftWithHash draft) async {
    final service = JournalVersionService.instance;
    final entryDir = await service._getEntryDir(entryId);
    final draftFile = File(path.join(entryDir.path, 'draft.json'));
    await draftFile.writeAsString(jsonEncode(draft.toJson()));
  }
  
}


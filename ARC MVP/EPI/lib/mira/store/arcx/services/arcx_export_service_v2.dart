/// ARCX Export Service V2
/// 
/// Implements the new ARCX export specification with multiselect, separate groups,
/// media packs, and improved folder structure.
library arcx_export_service_v2;

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/platform/photo_bridge.dart';
import 'package:my_app/core/services/photo_library_service.dart';
import 'package:my_app/arc/chat/chat/chat_repo.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/models/phase_models.dart';
import '../models/arcx_manifest.dart';
import 'arcx_crypto_service.dart';
import 'package:my_app/prism/atlas/rivet/rivet_storage.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart' as rivet_models;
import 'package:my_app/models/arcform_snapshot_model.dart';
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:my_app/arc/chat/data/models/lumara_favorite.dart';
import 'package:hive/hive.dart';
import 'package:my_app/services/export_history_service.dart';
import 'package:flutter/foundation.dart';

const _uuid = Uuid();

/// ARCX Export Strategy
enum ARCXExportStrategy {
  together, // All in one archive (default)
  separateGroups, // 3 separate archives (Entries, Chats, Media)
  entriesChatsTogetherMediaSeparate, // 2 archives (Entries+Chats, Media)
}

/// ARCX Export Options
class ARCXExportOptions {
  final ARCXExportStrategy strategy;
  final int mediaPackTargetSizeMB;
  final bool encrypt; // Always required, ARCX native encryption
  final String compression; // 'auto' or 'off', default 'auto'
  final bool dedupeMedia;
  final bool includeChecksums;
  final DateTime? startDate; // Optional date range filter
  final DateTime? endDate; // Optional date range filter
  
  // NEW: Incremental backup options
  final bool incrementalMode;        // If true, only export new/changed entries
  final bool skipExportedMedia;      // If true, skip media already in export history
  final bool trackExportHistory;     // If true, record this export in history
  final bool excludeMediaFromIncremental; // If true, exclude all media from incremental backups (text-only)
  
  ARCXExportOptions({
    this.strategy = ARCXExportStrategy.together,
    this.mediaPackTargetSizeMB = 200,
    this.encrypt = true,
    this.compression = 'auto',
    this.dedupeMedia = true,
    this.includeChecksums = true,
    this.startDate,
    this.endDate,
    // NEW defaults
    this.incrementalMode = false,
    this.skipExportedMedia = false,
    this.trackExportHistory = true,
    this.excludeMediaFromIncremental = false, // Default: include media in incremental backups
  });
  
  // Convenience constructor for incremental backup
  factory ARCXExportOptions.incremental({
    ARCXExportStrategy strategy = ARCXExportStrategy.together,
    bool encrypt = true,
    bool excludeMedia = false, // Option to exclude media for text-only incremental backups
  }) => ARCXExportOptions(
    strategy: strategy,
    encrypt: encrypt,
    incrementalMode: true,
    skipExportedMedia: !excludeMedia, // If excluding media, don't skip (we're not including any)
    trackExportHistory: true,
    excludeMediaFromIncremental: excludeMedia,
  );
  
  // Convenience constructor for full backup
  factory ARCXExportOptions.fullBackup({
    ARCXExportStrategy strategy = ARCXExportStrategy.together,
    bool encrypt = true,
  }) => ARCXExportOptions(
    strategy: strategy,
    encrypt: encrypt,
    incrementalMode: false,
    skipExportedMedia: false,
    trackExportHistory: true,
  );
  
  // Backward compatibility: separateGroups getter
  bool get separateGroups => strategy == ARCXExportStrategy.separateGroups;
}

/// ARCX Export Selection
class ARCXExportSelection {
  final List<String> entryIds;
  final List<String> chatThreadIds;
  final List<String> mediaIds;
  final DateTime? startDate; // Optional date range filter
  final DateTime? endDate; // Optional date range filter
  
  ARCXExportSelection({
    this.entryIds = const [],
    this.chatThreadIds = const [],
    this.mediaIds = const [],
    this.startDate,
    this.endDate,
  });
  
  bool get isEmpty => entryIds.isEmpty && chatThreadIds.isEmpty && mediaIds.isEmpty;
}

/// Result of a chunked backup operation
class ChunkedBackupResult {
  final bool success;
  final String folderPath;
  final List<String> chunkPaths;
  final int totalChunks;
  final int totalEntries;
  final int totalChats;
  final int totalMedia;
  final DateTime timestamp;
  final String? error;
  
  ChunkedBackupResult({
    required this.success,
    required this.folderPath,
    required this.chunkPaths,
    required this.totalChunks,
    required this.totalEntries,
    required this.totalChats,
    required this.totalMedia,
    required this.timestamp,
    this.error,
  });
  
  factory ChunkedBackupResult.failure(String error) {
    return ChunkedBackupResult(
      success: false,
      folderPath: '',
      chunkPaths: [],
      totalChunks: 0,
      totalEntries: 0,
      totalChats: 0,
      totalMedia: 0,
      timestamp: DateTime.now(),
      error: error,
    );
  }
}

/// A chunk of data for export (used internally)
class _ExportChunk {
  final List<JournalEntry> entries;
  final List<ChatSession> chats;
  final int estimatedSizeBytes;
  
  _ExportChunk({
    required this.entries,
    required this.chats,
    required this.estimatedSizeBytes,
  });
}

/// ARCX Export Service V2
class ARCXExportServiceV2 {
  final JournalRepository? _journalRepo;
  final ChatRepo? _chatRepo;
  final PhaseRegimeService? _phaseRegimeService;
  
  ARCXExportServiceV2({
    JournalRepository? journalRepo,
    ChatRepo? chatRepo,
    PhaseRegimeService? phaseRegimeService,
  }) : _journalRepo = journalRepo,
       _chatRepo = chatRepo,
       _phaseRegimeService = phaseRegimeService;
  
  /// Export data to ARCX format
  Future<ARCXExportResultV2> export({
    required ARCXExportSelection selection,
    required ARCXExportOptions options,
    required Directory outputDir,
    String? password,
    Function(String)? onProgress,
    int? exportNumber, // Optional export number for filename labeling (1, 2, 3, etc.)
  }) async {
    try {
      print('ARCX Export V2: Starting export...');
      onProgress?.call('Preparing export...');
      
      // Validate selection
      if (selection.isEmpty) {
        throw Exception('Export selection is empty');
      }
      
      // Generate export ID
      final exportId = 'arcx-exp-${_uuid.v4()}';
      final exportedAt = DateTime.now().toUtc().toIso8601String();
      
      // Create temp directory
      final appDocDir = await getApplicationDocumentsDirectory();
      final tempDir = Directory(path.join(appDocDir.path, 'arcx_export_v2_${DateTime.now().millisecondsSinceEpoch}'));
      await tempDir.create(recursive: true);
      
      try {
        // Load data with date filtering
        onProgress?.call('Loading entries, chats, and media...');
        final dateRange = selection.startDate != null || selection.endDate != null
            ? (startDate: selection.startDate ?? options.startDate, endDate: selection.endDate ?? options.endDate)
            : (startDate: options.startDate, endDate: options.endDate);
        
        final entries = await _loadEntries(selection.entryIds, dateRange.startDate, dateRange.endDate);
        final chats = await _loadChats(selection.chatThreadIds, dateRange.startDate, dateRange.endDate);
        
        // Collect media from entries and also load explicitly selected media
        // Note: Media from entries/chats outside date range should still be included if referenced
        final mediaFromEntries = <MediaItem>[];
        for (final entry in entries) {
          mediaFromEntries.addAll(entry.media);
        }
        final explicitMedia = await _loadMedia(selection.mediaIds, dateRange.startDate, dateRange.endDate);
        
        // Combine and deduplicate media
        final mediaMap = <String, MediaItem>{};
        for (final mediaItem in mediaFromEntries) {
          mediaMap[mediaItem.id] = mediaItem;
        }
        for (final mediaItem in explicitMedia) {
          mediaMap[mediaItem.id] = mediaItem;
        }
        final media = mediaMap.values.toList();
        
        print('ARCX Export V2: Loaded ${entries.length} entries, ${chats.length} chats, ${media.length} media items');
        
        // Route based on export strategy
        switch (options.strategy) {
          case ARCXExportStrategy.together:
            return await _exportTogether(
              entries: entries,
              chats: chats,
              media: media,
              options: options,
              exportId: exportId,
              exportedAt: exportedAt,
              outputDir: outputDir,
              password: password,
              onProgress: onProgress,
              exportNumber: exportNumber,
            );
          case ARCXExportStrategy.separateGroups:
            return await _exportSeparateGroups(
              entries: entries,
              chats: chats,
              media: media,
              options: options,
              exportId: exportId,
              exportedAt: exportedAt,
              outputDir: outputDir,
              password: password,
              onProgress: onProgress,
              exportNumber: exportNumber,
            );
          case ARCXExportStrategy.entriesChatsTogetherMediaSeparate:
            return await _exportEntriesChatsTogetherMediaSeparate(
              entries: entries,
              chats: chats,
              media: media,
              options: options,
              exportId: exportId,
              exportedAt: exportedAt,
              outputDir: outputDir,
              password: password,
              onProgress: onProgress,
              exportNumber: exportNumber,
            );
        }
      } finally {
        // Clean up temp directory
        try {
          await tempDir.delete(recursive: true);
        } catch (e) {
          print('Warning: Could not delete temp directory: $e');
        }
      }
    } catch (e, stackTrace) {
      print('ARCX Export V2: ✗ Failed: $e');
      print('Stack trace: $stackTrace');
      return ARCXExportResultV2.failure(e.toString());
    }
  }
  
  /// Export all groups together in one ARCX package
  Future<ARCXExportResultV2> _exportTogether({
    required List<JournalEntry> entries,
    required List<ChatSession> chats,
    required List<MediaItem> media,
    required ARCXExportOptions options,
    required String exportId,
    required String exportedAt,
    required Directory outputDir,
    String? password,
    Function(String)? onProgress,
    int? exportNumber,
  }) async {
    // Create payload directory
    final appDocDir = await getApplicationDocumentsDirectory();
    final tempDir = Directory(path.join(appDocDir.path, 'arcx_export_v2_${DateTime.now().millisecondsSinceEpoch}'));
    await tempDir.create(recursive: true);
    final payloadDir = Directory(path.join(tempDir.path, 'payload'));
    await payloadDir.create(recursive: true);
    
    try {
      // Build links map
      final links = _buildLinksMap(entries, chats, media);
      
      // Export entries
      int entriesExported = 0;
      if (entries.isNotEmpty) {
        onProgress?.call('Exporting ${entries.length} entries...');
        entriesExported = await _exportEntries(
          entries: entries,
          links: links,
          payloadDir: payloadDir,
          onProgress: onProgress,
        );
      }
      
      // Export chats
      int chatsExported = 0;
      if (chats.isNotEmpty) {
        onProgress?.call('Exporting ${chats.length} chats...');
        final chatExportResult = await _exportChats(
          chats: chats,
          links: links,
          payloadDir: payloadDir,
          onProgress: onProgress,
        );
        chatsExported = chatExportResult['count'] as int;
        // Export edges.jsonl (aligned with MCP format)
        if (chatExportResult['edges'] != null) {
          await _exportEdges(chatExportResult['edges'] as List<Map<String, dynamic>>, payloadDir);
        }
      }
      
      // Export media with packs
      int mediaExported = 0;
      if (media.isNotEmpty) {
        onProgress?.call('Exporting ${media.length} media items...');
        mediaExported = await _exportMediaWithPacks(
          media: media,
          links: links,
          payloadDir: payloadDir,
          options: options,
          onProgress: onProgress,
        );
      }
      
      // Export phase regimes, RIVET state, Sentinel state, ArcForm timeline, and LUMARA favorites
      int phaseRegimesExported = 0;
      Map<String, int> lumaraFavoritesExported = {'total': 0, 'answers': 0, 'chats': 0, 'entries': 0};
      if (_phaseRegimeService != null) {
        onProgress?.call('Exporting phase regimes...');
        phaseRegimesExported = await _exportPhaseRegimes(payloadDir);
      }
      
      // Export RIVET state, Sentinel state, ArcForm timeline
      onProgress?.call('Exporting RIVET and system states...');
      await _exportRivetState(payloadDir);
      await _exportSentinelState(payloadDir);
      await _exportArcFormTimeline(payloadDir);
      
      // Export LUMARA favorites (always export, independent of phase regimes)
      onProgress?.call('Exporting LUMARA favorites...');
      lumaraFavoritesExported = await _exportLumaraFavorites(payloadDir);
      
      // Export health streams (aligned with MCP format)
      if (entries.isNotEmpty) {
        onProgress?.call('Exporting health streams...');
        await _exportHealthStreams(entries, payloadDir);
      }
      
      // Generate checksums
      if (options.includeChecksums) {
        onProgress?.call('Generating checksums...');
        await _generateChecksums(payloadDir);
      }
      
      // Create manifest
      final manifest = _createManifest(
        exportId: exportId,
        exportedAt: exportedAt,
        entriesCount: entriesExported,
        chatsCount: chatsExported,
        mediaCount: mediaExported,
        phaseRegimesCount: phaseRegimesExported,
        lumaraFavoritesCount: lumaraFavoritesExported['total'] ?? 0,
        lumaraFavoritesAnswersCount: lumaraFavoritesExported['answers'] ?? 0,
        lumaraFavoritesChatsCount: lumaraFavoritesExported['chats'] ?? 0,
        lumaraFavoritesEntriesCount: lumaraFavoritesExported['entries'] ?? 0,
        separateGroups: false,
        options: options,
      );
      
      // Write manifest
      final manifestFile = File(path.join(payloadDir.path, 'manifest.json'));
      await manifestFile.writeAsString(jsonEncode(manifest.toJson()));
      
      // Package and encrypt
      onProgress?.call('Packaging and encrypting...');
      final arcxPath = await _packageAndEncrypt(
        payloadDir: payloadDir,
        manifest: manifest,
        outputDir: outputDir,
        exportId: exportId,
        password: password,
        onProgress: onProgress,
        compression: options.compression,
        exportNumber: exportNumber,
      );
      
      onProgress?.call('Export complete!');
      
      return ARCXExportResultV2.success(
        arcxPath: arcxPath,
        entriesExported: entriesExported,
        chatsExported: chatsExported,
        mediaExported: mediaExported,
      );
    } finally {
      // Clean up
      try {
        await tempDir.delete(recursive: true);
      } catch (e) {
        print('Warning: Could not delete temp directory: $e');
      }
    }
  }
  
  /// Export groups separately (3 ARCX packages)
  Future<ARCXExportResultV2> _exportSeparateGroups({
    required List<JournalEntry> entries,
    required List<ChatSession> chats,
    required List<MediaItem> media,
    required ARCXExportOptions options,
    required String exportId,
    required String exportedAt,
    required Directory outputDir,
    String? password,
    Function(String)? onProgress,
    int? exportNumber,
  }) async {
    // Build links map for all groups
    final links = _buildLinksMap(entries, chats, media);
    
    final results = <String>[];
    
    // Export Entries (includes phase regimes)
    if (entries.isNotEmpty) {
      onProgress?.call('Exporting ${entries.length} entries...');
      final entriesPath = await _exportSingleGroup(
        groupType: 'Entries',
        entries: entries,
        chats: [],
        media: [],
        links: links,
        options: options,
        exportId: '${exportId}-entries',
        exportedAt: exportedAt,
        outputDir: outputDir,
        password: password,
        onProgress: onProgress,
        includePhaseRegimes: true, // Phase regimes included with entries
        exportNumber: exportNumber,
      );
      results.add(entriesPath);
    }
    
    // Export Chats
    if (chats.isNotEmpty) {
      onProgress?.call('Exporting ${chats.length} chats...');
      final chatsPath = await _exportSingleGroup(
        groupType: 'Chats',
        entries: [],
        chats: chats,
        media: [],
        links: links,
        options: options,
        exportId: '${exportId}-chats',
        exportedAt: exportedAt,
        outputDir: outputDir,
        password: password,
        onProgress: onProgress,
        exportNumber: exportNumber,
      );
      results.add(chatsPath);
    }
    
    // Export Media
    if (media.isNotEmpty) {
      onProgress?.call('Exporting ${media.length} media items...');
      final mediaPath = await _exportSingleGroup(
        groupType: 'Media',
        entries: [],
        chats: [],
        media: media,
        links: links,
        options: options,
        exportId: '${exportId}-media',
        exportedAt: exportedAt,
        outputDir: outputDir,
        password: password,
        onProgress: onProgress,
        exportNumber: exportNumber,
      );
      results.add(mediaPath);
    }
    
    return ARCXExportResultV2.success(
      arcxPath: results.first, // Return first path for compatibility
      entriesExported: entries.length,
      chatsExported: chats.length,
      mediaExported: media.length,
      separatePackages: results,
    );
  }
  
  /// Export Entries+Chats together, Media separately (2 ARCX packages)
  Future<ARCXExportResultV2> _exportEntriesChatsTogetherMediaSeparate({
    required List<JournalEntry> entries,
    required List<ChatSession> chats,
    required List<MediaItem> media,
    required ARCXExportOptions options,
    required String exportId,
    required String exportedAt,
    required Directory outputDir,
    String? password,
    Function(String)? onProgress,
    int? exportNumber,
  }) async {
    // Build links map for all groups
    final links = _buildLinksMap(entries, chats, media);
    
    final results = <String>[];
    
    // Export Entries + Chats together (compressed)
    if (entries.isNotEmpty || chats.isNotEmpty) {
      onProgress?.call('Exporting ${entries.length} entries and ${chats.length} chats...');
      
      final appDocDir = await getApplicationDocumentsDirectory();
      final tempDir = Directory(path.join(appDocDir.path, 'arcx_export_${exportId}-entries-chats'));
      await tempDir.create(recursive: true);
      final payloadDir = Directory(path.join(tempDir.path, 'payload'));
      await payloadDir.create(recursive: true);
      
      try {
        int entriesExported = 0;
        int chatsExported = 0;
        
        // Export entries
        if (entries.isNotEmpty) {
          entriesExported = await _exportEntries(
            entries: entries,
            links: links,
            payloadDir: payloadDir,
            onProgress: onProgress,
          );
        }
        
        // Export chats
        if (chats.isNotEmpty) {
        final chatExportResult = await _exportChats(
            chats: chats,
            links: links,
            payloadDir: payloadDir,
            onProgress: onProgress,
          );
        chatsExported = chatExportResult['count'] as int;
        // Export edges.jsonl (aligned with MCP format)
        if (chatExportResult['edges'] != null) {
          await _exportEdges(chatExportResult['edges'] as List<Map<String, dynamic>>, payloadDir);
        }
        }
        
        // Export phase regimes, RIVET state, Sentinel state, ArcForm timeline, and LUMARA favorites (included with entries+chats archive)
        int phaseRegimesExported = 0;
        Map<String, int> lumaraFavoritesExported = {'total': 0, 'answers': 0, 'chats': 0, 'entries': 0};
        if (_phaseRegimeService != null) {
          onProgress?.call('Exporting phase regimes...');
          phaseRegimesExported = await _exportPhaseRegimes(payloadDir);
        }
        
        // Export RIVET state, Sentinel state, ArcForm timeline
        onProgress?.call('Exporting RIVET and system states...');
        await _exportRivetState(payloadDir);
        await _exportSentinelState(payloadDir);
        await _exportArcFormTimeline(payloadDir);
        
        // Export LUMARA favorites (always export, independent of phase regimes)
        onProgress?.call('Exporting LUMARA favorites...');
        lumaraFavoritesExported = await _exportLumaraFavorites(payloadDir);
        
        // Generate checksums
        if (options.includeChecksums) {
          await _generateChecksums(payloadDir);
        }
        
        // Create manifest for Entries+Chats archive
        final entriesChatsOptions = ARCXExportOptions(
          strategy: options.strategy,
          mediaPackTargetSizeMB: options.mediaPackTargetSizeMB,
          encrypt: options.encrypt,
          compression: 'auto', // Compressed for Entries+Chats
          dedupeMedia: options.dedupeMedia,
          includeChecksums: options.includeChecksums,
          startDate: options.startDate,
          endDate: options.endDate,
        );
        
        final manifest = _createManifest(
          exportId: '${exportId}-entries-chats',
          exportedAt: exportedAt,
          entriesCount: entriesExported,
          chatsCount: chatsExported,
          mediaCount: 0, // Media is in separate archive
          phaseRegimesCount: phaseRegimesExported,
          lumaraFavoritesCount: lumaraFavoritesExported['total'] ?? 0,
          lumaraFavoritesAnswersCount: lumaraFavoritesExported['answers'] ?? 0,
          lumaraFavoritesChatsCount: lumaraFavoritesExported['chats'] ?? 0,
          lumaraFavoritesEntriesCount: lumaraFavoritesExported['entries'] ?? 0,
          separateGroups: true, // Indicates this is part of a separated export
          options: entriesChatsOptions,
        );
        
        // Write manifest
        final manifestFile = File(path.join(payloadDir.path, 'manifest.json'));
        await manifestFile.writeAsString(jsonEncode(manifest.toJson()));
        
        // Package and encrypt (compressed)
        final entriesChatsPath = await _packageAndEncrypt(
          payloadDir: payloadDir,
          manifest: manifest,
          outputDir: outputDir,
          exportId: '${exportId}-entries-chats',
          password: password,
          onProgress: onProgress,
          compression: entriesChatsOptions.compression,
          exportNumber: exportNumber,
        );
        
        results.add(entriesChatsPath);
      } finally {
        try {
          await tempDir.delete(recursive: true);
        } catch (e) {
          print('Warning: Could not delete temp directory: $e');
        }
      }
    }
    
    // Export Media separately (uncompressed)
    if (media.isNotEmpty) {
      onProgress?.call('Exporting ${media.length} media items (uncompressed)...');
      
      // Create options with compression 'off' for media archive
      final mediaOptions = ARCXExportOptions(
        strategy: options.strategy,
        mediaPackTargetSizeMB: options.mediaPackTargetSizeMB,
        encrypt: options.encrypt,
        compression: 'off', // Uncompressed for Media archive
        dedupeMedia: options.dedupeMedia,
        includeChecksums: options.includeChecksums,
        startDate: options.startDate,
        endDate: options.endDate,
      );
      
      final mediaPath = await _exportSingleGroup(
        groupType: 'Media',
        entries: [],
        chats: [],
        media: media,
        links: links,
        options: mediaOptions,
        exportId: '${exportId}-media',
        exportedAt: exportedAt,
        outputDir: outputDir,
        password: password,
        onProgress: onProgress,
        exportNumber: exportNumber,
      );
      results.add(mediaPath);
    }
    
    return ARCXExportResultV2.success(
      arcxPath: results.first, // Return first path for compatibility
      entriesExported: entries.length,
      chatsExported: chats.length,
      mediaExported: media.length,
      separatePackages: results,
    );
  }
  
  /// Export a single group (Entries, Chats, or Media)
  Future<String> _exportSingleGroup({
    required String groupType,
    required List<JournalEntry> entries,
    required List<ChatSession> chats,
    required List<MediaItem> media,
    required Map<String, Map<String, List<String>>> links,
    required ARCXExportOptions options,
    required String exportId,
    required String exportedAt,
    required Directory outputDir,
    String? password,
    Function(String)? onProgress,
    bool includePhaseRegimes = false,
    int? exportNumber,
  }) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final tempDir = Directory(path.join(appDocDir.path, 'arcx_export_${exportId}'));
    await tempDir.create(recursive: true);
    final payloadDir = Directory(path.join(tempDir.path, 'payload'));
    await payloadDir.create(recursive: true);
    
    try {
      int entriesExported = 0;
      int chatsExported = 0;
      int mediaExported = 0;
      int phaseRegimesExported = 0;
      
      if (groupType == 'Entries' && entries.isNotEmpty) {
        entriesExported = await _exportEntries(
          entries: entries,
          links: links,
          payloadDir: payloadDir,
          onProgress: onProgress,
        );
      } else if (groupType == 'Chats' && chats.isNotEmpty) {
        final chatExportResult = await _exportChats(
          chats: chats,
          links: links,
          payloadDir: payloadDir,
          onProgress: onProgress,
        );
        chatsExported = chatExportResult['count'] as int;
        // Export edges.jsonl (aligned with MCP format)
        if (chatExportResult['edges'] != null) {
          await _exportEdges(chatExportResult['edges'] as List<Map<String, dynamic>>, payloadDir);
        }
      } else if (groupType == 'Media' && media.isNotEmpty) {
        mediaExported = await _exportMediaWithPacks(
          media: media,
          links: links,
          payloadDir: payloadDir,
          options: options,
          onProgress: onProgress,
        );
      }
      
      // Export phase regimes if requested (typically with Entries group)
      if (includePhaseRegimes && _phaseRegimeService != null) {
        onProgress?.call('Exporting phase regimes...');
        phaseRegimesExported = await _exportPhaseRegimes(payloadDir);
      }
      
      // Export RIVET state, Sentinel state, ArcForm timeline (if phase regimes included)
      if (includePhaseRegimes) {
        onProgress?.call('Exporting RIVET and system states...');
        await _exportRivetState(payloadDir);
        await _exportSentinelState(payloadDir);
        await _exportArcFormTimeline(payloadDir);
      }
      
      // Export LUMARA favorites (always export, independent of phase regimes)
      Map<String, int> lumaraFavoritesExported = {'total': 0, 'answers': 0, 'chats': 0, 'entries': 0};
      onProgress?.call('Exporting LUMARA favorites...');
      lumaraFavoritesExported = await _exportLumaraFavorites(payloadDir);
      
      // Generate checksums
      if (options.includeChecksums) {
        await _generateChecksums(payloadDir);
      }
      
      // Create manifest
      final manifest = _createManifest(
        exportId: exportId,
        exportedAt: exportedAt,
        entriesCount: entriesExported,
        chatsCount: chatsExported,
        mediaCount: mediaExported,
        phaseRegimesCount: phaseRegimesExported,
        lumaraFavoritesCount: lumaraFavoritesExported['total'] ?? 0,
        lumaraFavoritesAnswersCount: lumaraFavoritesExported['answers'] ?? 0,
        lumaraFavoritesChatsCount: lumaraFavoritesExported['chats'] ?? 0,
        lumaraFavoritesEntriesCount: lumaraFavoritesExported['entries'] ?? 0,
        separateGroups: true,
        options: options,
      );
      
      // Write manifest
      final manifestFile = File(path.join(payloadDir.path, 'manifest.json'));
      await manifestFile.writeAsString(jsonEncode(manifest.toJson()));
      
      // Package and encrypt
      final arcxPath = await _packageAndEncrypt(
        payloadDir: payloadDir,
        manifest: manifest,
        outputDir: outputDir,
        exportId: exportId,
        password: password,
        onProgress: onProgress,
        compression: options.compression,
        exportNumber: exportNumber,
      );
      
      return arcxPath;
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (e) {
        print('Warning: Could not delete temp directory: $e');
      }
    }
  }
  
  // Helper methods continue...
  // (I'll add the rest in the next edit)
  
  /// Load entries by IDs with optional date filtering
  Future<List<JournalEntry>> _loadEntries(List<String> entryIds, DateTime? startDate, DateTime? endDate) async {
    if (_journalRepo == null || entryIds.isEmpty) return [];

    // Ensure LUMARA migration runs before export to convert legacy inlineBlocks to lumaraBlocks
    print('ARCX Export V2: Ensuring LUMARA migration is complete before export...');
    await _journalRepo!.migrateLumaraBlocks();

    final entries = <JournalEntry>[];
    for (final id in entryIds) {
      final entry = await _journalRepo!.getJournalEntryById(id);
      if (entry != null) {
        // Apply date filtering if provided
        if (startDate != null && entry.createdAt.isBefore(startDate)) continue;
        if (endDate != null && entry.createdAt.isAfter(endDate)) continue;
        entries.add(entry);
      }
    }

    // Log LUMARA blocks found for verification
    final totalLumaraBlocks = entries.fold(0, (sum, entry) => sum + entry.lumaraBlocks.length);
    if (totalLumaraBlocks > 0) {
      print('ARCX Export V2: ✓ Found $totalLumaraBlocks LUMARA blocks across ${entries.length} entries');
    } else {
      print('ARCX Export V2: ⚠️ No LUMARA blocks found in ${entries.length} entries');
    }

    return entries;
  }
  
  /// Load chats by thread IDs with optional date filtering
  Future<List<ChatSession>> _loadChats(List<String> chatThreadIds, DateTime? startDate, DateTime? endDate) async {
    if (_chatRepo == null || chatThreadIds.isEmpty) return [];
    
    final chats = <ChatSession>[];
    for (final id in chatThreadIds) {
      try {
        final chat = await _chatRepo!.getSession(id);
        if (chat != null) {
          // Apply date filtering if provided
          if (startDate != null && chat.createdAt.isBefore(startDate)) continue;
          if (endDate != null && chat.createdAt.isAfter(endDate)) continue;
          chats.add(chat);
        }
      } catch (e) {
        print('Warning: Could not load chat $id: $e');
      }
    }
    return chats;
  }
  
  /// Load media by IDs with optional date filtering
  Future<List<MediaItem>> _loadMedia(List<String> mediaIds, DateTime? startDate, DateTime? endDate) async {
    if (mediaIds.isEmpty) return [];
    
    // Collect all media from entries
    final allMedia = <MediaItem>[];
    if (_journalRepo != null) {
      // Get all entries and extract their media
      // For now, we'll collect media from entries that are being exported
      // This will be populated when entries are loaded
    }
    
    // Filter to requested media IDs and apply date filtering if provided
    return allMedia.where((m) {
      if (!mediaIds.contains(m.id)) return false;
      if (startDate != null && m.createdAt.isBefore(startDate)) return false;
      if (endDate != null && m.createdAt.isAfter(endDate)) return false;
      return true;
    }).toList();
  }
  
  /// Build links map for entries, chats, and media
  Map<String, Map<String, List<String>>> _buildLinksMap(
    List<JournalEntry> entries,
    List<ChatSession> chats,
    List<MediaItem> media,
  ) {
    final links = <String, Map<String, List<String>>>{};
    
    // Build entry links
    for (final entry in entries) {
      final entryLinks = <String, List<String>>{
        'media_ids': entry.media.map((m) => m.id).toList(),
        'chat_thread_ids': [], // TODO: Extract from entry metadata if available
      };
      links['entry-${entry.id}'] = entryLinks;
    }
    
    // Build chat links
    for (final chat in chats) {
      final chatLinks = <String, List<String>>{
        'entry_ids': [], // TODO: Extract from chat metadata if available
        'media_ids': [], // TODO: Extract from chat messages if available
      };
      links['chat-${chat.id}'] = chatLinks;
    }
    
    // Build media links
    for (final entry in entries) {
      for (final mediaItem in entry.media) {
        final mediaLinks = <String, List<String>>{
          'entry_ids': [entry.id],
          'chat_thread_ids': [], // TODO: Extract if available
        };
        links['media-${mediaItem.id}'] = mediaLinks;
      }
    }
    
    return links;
  }
  
  /// Generate slug from title
  String _generateSlug(String title) {
    if (title.isEmpty) return 'untitled';
    
    // Convert to lowercase, replace spaces and special chars with hyphens
    var slug = title.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
    
    // Limit length
    if (slug.length > 50) {
      slug = slug.substring(0, 50);
    }
    
    // Remove leading/trailing hyphens
    slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
    
    return slug.isEmpty ? 'untitled' : slug;
  }
  
  /// Create manifest
  ARCXManifest _createManifest({
    required String exportId,
    required String exportedAt,
    required int entriesCount,
    required int chatsCount,
    required int mediaCount,
    int phaseRegimesCount = 0,
    int lumaraFavoritesCount = 0,
    int lumaraFavoritesAnswersCount = 0,
    int lumaraFavoritesChatsCount = 0,
    int lumaraFavoritesEntriesCount = 0,
    required bool separateGroups,
    required ARCXExportOptions options,
  }) {
    return ARCXManifest(
      version: '1.0', // Legacy field
      algo: 'AES-256-GCM', // Legacy field
      kdf: 'pbkdf2-sha256-600000', // Legacy field
      sha256: '', // Will be filled after encryption
      signerPubkeyFpr: '', // Will be filled after signing
      signatureB64: '', // Will be filled after signing
      payloadMeta: ARCXPayloadMeta(
        journalCount: entriesCount,
        photoMetaCount: mediaCount,
        bytes: 0, // Will be calculated
      ),
      mcpManifestSha256: '', // Not used in new format
      exportedAt: exportedAt,
      appVersion: '1.0.0',
      redactionReport: {},
      exportId: exportId,
      arcxVersion: '1.2',
      scope: ARCXScope(
        entriesCount: entriesCount,
        chatsCount: chatsCount,
        mediaCount: mediaCount,
        phaseRegimesCount: phaseRegimesCount,
        lumaraFavoritesCount: lumaraFavoritesCount,
        lumaraFavoritesAnswersCount: lumaraFavoritesAnswersCount,
        lumaraFavoritesChatsCount: lumaraFavoritesChatsCount,
        lumaraFavoritesEntriesCount: lumaraFavoritesEntriesCount,
        separateGroups: separateGroups,
      ),
      encryptionInfo: ARCXEncryptionInfo(
        enabled: options.encrypt,
        algorithm: 'XChaCha20-Poly1305',
      ),
      checksumsInfo: options.includeChecksums
          ? ARCXChecksumsInfo(
              enabled: true,
              algorithm: 'sha256',
              file: '/_checksums/sha256.txt',
            )
          : null,
    );
  }
  
  /// Export entries to /Entries/{yyyy}/{mm}/{dd}/entry-{uuid}-{slug}.arcx.json
  Future<int> _exportEntries({
    required List<JournalEntry> entries,
    required Map<String, Map<String, List<String>>> links,
    required Directory payloadDir,
    Function(String)? onProgress,
  }) async {
    final entriesDir = Directory(path.join(payloadDir.path, 'Entries'));
    await entriesDir.create(recursive: true);
    
    int exported = 0;
    final usedSlugs = <String, int>{}; // Track slug collisions
    
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      onProgress?.call('Exporting entry ${i + 1}/${entries.length}...');
      
      // Create date bucket directory
      final date = entry.createdAt;
      final dateBucket = '${date.year.toString().padLeft(4, '0')}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      final dateDir = Directory(path.join(entriesDir.path, dateBucket));
      await dateDir.create(recursive: true);
      
      // Generate slug and handle collisions
      var slug = _generateSlug(entry.title);
      final slugKey = '$dateBucket/$slug';
      if (usedSlugs.containsKey(slugKey)) {
        usedSlugs[slugKey] = (usedSlugs[slugKey] ?? 0) + 1;
        slug = '${slug}-${usedSlugs[slugKey]}';
      } else {
        usedSlugs[slugKey] = 0;
      }
      
      // Create health association for this entry's date (aligned with MCP format)
      final entryDate = '${entry.createdAt.year.toString().padLeft(4, '0')}-'
                     '${entry.createdAt.month.toString().padLeft(2, '0')}-'
                     '${entry.createdAt.day.toString().padLeft(2, '0')}';
      
      final healthAssociation = {
        'date': entryDate,
        'health_data_available': true,
        'stream_reference': 'streams/health/${entryDate.substring(0, 7)}.jsonl',
        'metrics_included': [
          'steps', 'active_energy', 'resting_energy', 'sleep_total_minutes',
          'resting_hr', 'avg_hr', 'hrv_sdnn'
        ],
        'association_created_at': DateTime.now().toUtc().toIso8601String(),
      };
      
      // Create entry JSON with links
      final entryLinks = links['entry-${entry.id}'] ?? {'media_ids': [], 'chat_thread_ids': []};
      
      // Create embedded media metadata (aligned with MCP format)
      // This provides self-containment even though links are also available
      final embeddedMedia = entry.media.map((m) => <String, dynamic>{
        'id': m.id,
        'kind': m.type.name, // 'image', 'video', 'audio', 'file'
        'type': m.type.name,
        'uri': m.uri,
        'createdAt': m.createdAt.toUtc().toIso8601String(),
        if (m.duration != null) 'duration': m.duration!.inSeconds,
        if (m.sizeBytes != null) 'sizeBytes': m.sizeBytes,
        if (m.altText != null) 'altText': m.altText,
        if (m.ocrText != null) 'ocrText': m.ocrText,
        if (m.transcript != null) 'transcript': m.transcript,
        if (m.analysisData != null) 'analysisData': m.analysisData,
        if (m.sha256 != null && m.sha256!.isNotEmpty) 'sha256': m.sha256,
      }).toList();
      
      final entryJson = {
        'id': entry.id,
        'type': 'entry',
        'created_at': entry.createdAt.toUtc().toIso8601String(),
        'timestamp': entry.createdAt.toUtc().toIso8601String(), // Aligned with MCP format
        'date_bucket': dateBucket,
        'title': entry.title,
        'slug': slug,
        'content': entry.content,
        'media': embeddedMedia, // Aligned with MCP format - embedded media metadata
        'links': {
          'media_ids': entryLinks['media_ids'] ?? [],
          'chat_thread_ids': entryLinks['chat_thread_ids'] ?? [],
        },
        'emotion': entry.emotion,
        'emotionReason': entry.emotionReason,
        'phase': entry.phase, // Legacy field for backward compatibility
        'keywords': entry.keywords,
        // New phase detection fields
        'autoPhase': entry.autoPhase,
        'autoPhaseConfidence': entry.autoPhaseConfidence,
        'userPhaseOverride': entry.userPhaseOverride,
        'isPhaseLocked': entry.isPhaseLocked,
        'legacyPhaseTag': entry.legacyPhaseTag,
        'importSource': entry.importSource,
        'phaseInferenceVersion': entry.phaseInferenceVersion,
        'phaseMigrationStatus': entry.phaseMigrationStatus,
        'metadata': entry.metadata ?? {},
        'health_association': healthAssociation, // Aligned with MCP format
        // LUMARA blocks in new format (migrated from legacy inlineBlocks)
        'lumaraBlocks': entry.lumaraBlocks.map((block) => block.toJson()).toList(),
      };
      
      // Write entry file
      final entryFileName = 'entry-${entry.id}-$slug.arcx.json';
      final entryFile = File(path.join(dateDir.path, entryFileName));
      await entryFile.writeAsString(jsonEncode(entryJson));
      
      exported++;
    }
    
    print('ARCX Export V2: Exported $exported entries');
    return exported;
  }
  
  /// Export chats to /Chats/{yyyy}/{mm}/{dd}/chat-{threadId}.arcx.json
  /// Returns map with 'count' and 'edges' for edges.jsonl export
  Future<Map<String, dynamic>> _exportChats({
    required List<ChatSession> chats,
    required Map<String, Map<String, List<String>>> links,
    required Directory payloadDir,
    Function(String)? onProgress,
  }) async {
    if (_chatRepo == null) {
      print('ARCX Export V2: No ChatRepo available, skipping chat export');
      return {'count': 0, 'edges': <Map<String, dynamic>>[]};
    }
    
    final chatsDir = Directory(path.join(payloadDir.path, 'Chats'));
    await chatsDir.create(recursive: true);
    
    int exported = 0;
    final edges = <Map<String, dynamic>>[];
    
    for (int i = 0; i < chats.length; i++) {
      final chat = chats[i];
      onProgress?.call('Exporting chat ${i + 1}/${chats.length}...');
      
      // Get messages for this chat
      final messages = await _chatRepo!.getMessages(chat.id);
      
      // Create date bucket directory
      final date = chat.createdAt;
      final dateBucket = '${date.year.toString().padLeft(4, '0')}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      final dateDir = Directory(path.join(chatsDir.path, dateBucket));
      await dateDir.create(recursive: true);
      
      // Create chat JSON with links
      final chatLinks = links['chat-${chat.id}'] ?? {'entry_ids': [], 'media_ids': []};
      final chatJson = {
        'id': chat.id,
        'type': 'chat',
        'created_at': chat.createdAt.toUtc().toIso8601String(),
        'date_bucket': dateBucket,
        'thread_id': chat.id,
        'subject': chat.subject,
        'messages': messages.asMap().entries.map((entry) {
          final msg = entry.value;
          final index = entry.key;
          // Create edge for each message (aligned with MCP format)
          edges.add({
            'source': 'chat:${chat.id}',
            'target': 'message:${msg.id}',
            'relation': 'contains',
            'timestamp': msg.createdAt.toUtc().toIso8601String(),
            'order': index,
          });
          return {
          'id': msg.id,
          'role': msg.role,
          'content': msg.textContent,
          'created_at': msg.createdAt.toUtc().toIso8601String(),
          if (msg.contentParts != null) 'content_parts': msg.contentParts!.map((p) => p.toJson()).toList(),
          if (msg.metadata != null) 'metadata': msg.metadata,
          };
        }).toList(),
        'links': {
          'entry_ids': chatLinks['entry_ids'] ?? [],
          'media_ids': chatLinks['media_ids'] ?? [],
        },
        'is_archived': chat.isArchived,
        'is_pinned': chat.isPinned,
        'tags': chat.tags,
        'metadata': chat.metadata ?? {},
      };
      
      // Write chat file
      final chatFileName = 'chat-${chat.id}.arcx.json';
      final chatFile = File(path.join(dateDir.path, chatFileName));
      await chatFile.writeAsString(jsonEncode(chatJson));
      
      exported++;
    }
    
    print('ARCX Export V2: Exported $exported chats');
    return {'count': exported, 'edges': edges};
  }
  
  /// Export edges.jsonl file (aligned with MCP format)
  Future<void> _exportEdges(List<Map<String, dynamic>> edges, Directory payloadDir) async {
    if (edges.isEmpty) return;
    
    try {
      final edgesFile = File(path.join(payloadDir.path, 'edges.jsonl'));
      final edgesLines = edges.map((e) => jsonEncode(e)).toList();
      await edgesFile.writeAsString(edgesLines.join('\n') + '\n');
      print('ARCX Export V2: Exported ${edges.length} edges to edges.jsonl');
    } catch (e) {
      print('ARCX Export V2: Error exporting edges: $e');
    }
  }
  
  /// Export media with packs to /Media/packs/pack-XXX/ and /Media/media_index.json
  Future<int> _exportMediaWithPacks({
    required List<MediaItem> media,
    required Map<String, Map<String, List<String>>> links,
    required Directory payloadDir,
    required ARCXExportOptions options,
    Function(String)? onProgress,
  }) async {
    if (media.isEmpty) return 0;
    
    final mediaDir = Directory(path.join(payloadDir.path, 'Media'));
    await mediaDir.create(recursive: true);
    final packsDir = Directory(path.join(mediaDir.path, 'packs'));
    await packsDir.create(recursive: true);
    
    final mediaIndex = <String, dynamic>{
      'packs': <Map<String, dynamic>>[],
      'total_media_items': 0,
      'total_bytes': 0,
      'items': <Map<String, dynamic>>[],
    };
    
    final packTargetSizeBytes = options.mediaPackTargetSizeMB * 1024 * 1024;
    final packs = <Map<String, dynamic>>[];
    final currentPack = <Map<String, dynamic>>[];
    int currentPackSize = 0;
    int packNumber = 1;
    int totalMediaBytes = 0;
    final seenMediaHashes = <String, String>{}; // For deduplication
    
    for (int i = 0; i < media.length; i++) {
      final mediaItem = media[i];
      onProgress?.call('Exporting media ${i + 1}/${media.length}...');
      
      try {
        // Read media file with multiple fallback methods
        Uint8List? mediaBytes;
        
        // Try 1: Direct file path
        final mediaFile = File(mediaItem.uri);
        if (await mediaFile.exists()) {
          try {
            mediaBytes = await mediaFile.readAsBytes();
            print('ARCX Export V2: ✓ Got bytes from file path: ${mediaItem.uri} (${mediaBytes.length} bytes)');
          } catch (e) {
            print('ARCX Export V2: ⚠️ Error reading file ${mediaItem.uri}: $e');
          }
        }
        
        // Try 2: Photo library URI (ph://)
        if (mediaBytes == null && PhotoBridge.isPhotoLibraryUri(mediaItem.uri)) {
          final localId = PhotoBridge.extractLocalIdentifier(mediaItem.uri);
          if (localId != null && mediaItem.type == MediaType.image) {
            final photoData = await PhotoBridge.getPhotoBytes(localId);
            if (photoData != null) {
              mediaBytes = photoData['bytes'] as Uint8List;
              print('ARCX Export V2: ✓ Got bytes from PhotoBridge for ph:// URI (${mediaBytes.length} bytes)');
            } else {
              // Fallback: Try PhotoLibraryService thumbnail
              print('ARCX Export V2: PhotoBridge returned null, trying PhotoLibraryService...');
              try {
                final thumbnailPath = await PhotoLibraryService.getPhotoThumbnail(mediaItem.uri, size: 1920);
                if (thumbnailPath != null) {
                  final thumbFile = File(thumbnailPath);
                  if (await thumbFile.exists()) {
                    mediaBytes = await thumbFile.readAsBytes();
                    print('ARCX Export V2: ✓ Got bytes from PhotoLibraryService thumbnail (${mediaBytes.length} bytes)');
                  }
                }
              } catch (e) {
                print('ARCX Export V2: ⚠️ PhotoLibraryService thumbnail failed: $e');
              }
            }
          }
        }
        
        // Try 3: Search in Documents/photos directory
        if (mediaBytes == null && mediaItem.type == MediaType.image) {
          try {
            final appDir = await getApplicationDocumentsDirectory();
            final photosDir = Directory(path.join(appDir.path, 'photos'));
            if (await photosDir.exists()) {
              // Try to find by filename
              final fileName = path.basename(mediaItem.uri);
              final possibleFile = File(path.join(photosDir.path, fileName));
              if (await possibleFile.exists()) {
                mediaBytes = await possibleFile.readAsBytes();
                print('ARCX Export V2: ✓ Found photo in Documents/photos: $fileName (${mediaBytes.length} bytes)');
              } else {
                // Try searching by media ID
                final files = await photosDir.list().toList();
                for (final file in files) {
                  if (file is File && file.path.contains(mediaItem.id)) {
                    mediaBytes = await file.readAsBytes();
                    print('ARCX Export V2: ✓ Found photo by ID search: ${file.path} (${mediaBytes.length} bytes)');
                    break;
                  }
                }
              }
            }
          } catch (e) {
            print('ARCX Export V2: ⚠️ Fallback photo search failed: $e');
          }
        }
        
        // If still no bytes, skip this media item
        if (mediaBytes == null) {
          print('ARCX Export V2: ⚠️ Could not get bytes for media ${mediaItem.id} (URI: ${mediaItem.uri}, Type: ${mediaItem.type})');
          print('ARCX Export V2: ⚠️ This photo will NOT be included in the export');
          continue;
        }
        
        final mediaHash = sha256.convert(mediaBytes).toString();
        
        // Deduplicate if enabled
        if (options.dedupeMedia && seenMediaHashes.containsKey(mediaHash)) {
          print('ARCX Export V2: Skipping duplicate media (hash: ${mediaHash.substring(0, 8)}...)');
          // Still add to index but reference existing file
          final existingId = seenMediaHashes[mediaHash]!;
          (mediaIndex['items'] as List<Map<String, dynamic>>).add({
            'id': mediaItem.id,
            'type': 'media',
            'origin': 'upload',
            'created_at': mediaItem.createdAt.toUtc().toIso8601String(),
            'pack': 'existing',
            'filename': path.basename(mediaItem.uri),
            'content_type': _getContentType(mediaItem.type),
            'bytes': mediaBytes.length,
            'links': links['media-${mediaItem.id}'] ?? {'entry_ids': [], 'chat_thread_ids': []},
            'duplicate_of': existingId,
          });
          continue;
        }
        
        seenMediaHashes[mediaHash] = mediaItem.id;
        
        // Check if we need a new pack
        if (currentPackSize + mediaBytes.length > packTargetSizeBytes && currentPack.isNotEmpty) {
          // Finalize current pack
          final packName = 'pack-${packNumber.toString().padLeft(3, '0')}';
          await _finalizePack(
            packName: packName,
            packItems: currentPack,
            packsDir: packsDir,
            mediaIndex: mediaIndex,
            prevPack: packs.isNotEmpty ? packs.last['name'] as String? : null,
          );
          
          if (packs.isNotEmpty) {
            packs.last['next'] = packName;
          }
          
          packs.add({
            'name': packName,
            'prev': packs.isNotEmpty ? packs.last['name'] : null,
            'next': null,
            'total_bytes': currentPackSize,
            'items': currentPack.map((item) => item['id'] as String).toList(),
          });
          
          currentPack.clear();
          currentPackSize = 0;
          packNumber++;
        }
        
        // Copy media file to current pack
        final packName = 'pack-${packNumber.toString().padLeft(3, '0')}';
        final packDir = Directory(path.join(packsDir.path, packName));
        await packDir.create(recursive: true);
        
        final fileName = path.basename(mediaItem.uri);
        final destFile = File(path.join(packDir.path, fileName));
        await destFile.writeAsBytes(mediaBytes);
        
        // Add to current pack
        final mediaLinks = links['media-${mediaItem.id}'] ?? {'entry_ids': [], 'chat_thread_ids': []};
        currentPack.add({
          'id': mediaItem.id,
          'type': 'media',
          'origin': 'upload',
          'created_at': mediaItem.createdAt.toUtc().toIso8601String(),
          'pack': packName,
          'filename': fileName,
          'content_type': _getContentType(mediaItem.type),
          'bytes': mediaBytes.length,
          'links': mediaLinks,
        });
        
        currentPackSize += mediaBytes.length;
        totalMediaBytes += mediaBytes.length;
        
      } catch (e) {
        print('ARCX Export V2: Error exporting media ${mediaItem.id}: $e');
      }
    }
    
    // Finalize last pack
    if (currentPack.isNotEmpty) {
      final packName = 'pack-${packNumber.toString().padLeft(3, '0')}';
      await _finalizePack(
        packName: packName,
        packItems: currentPack,
        packsDir: packsDir,
        mediaIndex: mediaIndex,
        prevPack: packs.isNotEmpty ? packs.last['name'] as String? : null,
      );
      
      if (packs.isNotEmpty) {
        packs.last['next'] = packName;
      }
      
      packs.add({
        'name': packName,
        'prev': packs.isNotEmpty ? packs.last['name'] : null,
        'next': null,
        'total_bytes': currentPackSize,
        'items': currentPack.map((item) => item['id'] as String).toList(),
      });
    }
    
    // Update media index
    mediaIndex['packs'] = packs;
    mediaIndex['total_media_items'] = (mediaIndex['items'] as List).length;
    mediaIndex['total_bytes'] = totalMediaBytes;
    
    // Write media index
    final mediaIndexFile = File(path.join(mediaDir.path, 'media_index.json'));
    await mediaIndexFile.writeAsString(jsonEncode(mediaIndex));
    
    print('ARCX Export V2: Exported ${(mediaIndex['items'] as List).length} media items in ${packs.length} packs');
    return (mediaIndex['items'] as List).length;
  }
  
  /// Finalize a media pack
  Future<void> _finalizePack({
    required String packName,
    required List<Map<String, dynamic>> packItems,
    required Directory packsDir,
    required Map<String, dynamic> mediaIndex,
    String? prevPack,
  }) async {
    // Add items to media index
    for (final item in packItems) {
      (mediaIndex['items'] as List<Map<String, dynamic>>).add(item);
    }
  }
  
  /// Get content type from media type
  String _getContentType(MediaType type) {
    switch (type) {
      case MediaType.image:
        return 'image/jpeg';
      case MediaType.video:
        return 'video/mp4';
      case MediaType.audio:
        return 'audio/m4a';
      case MediaType.file:
        return 'application/octet-stream';
    }
  }
  
  /// Export phase regimes to extensions/phase_regimes.json
  Future<int> _exportPhaseRegimes(Directory payloadDir) async {
    try {
      if (_phaseRegimeService == null) {
        return 0;
      }
      
      // Get all phase regimes
      final regimes = _phaseRegimeService!.allRegimes;
      
      if (regimes.isEmpty) {
        print('ARCX Export V2: No phase regimes to export');
        return 0;
      }
      
      // Create extensions directory (aligned with MCP format)
      final phaseRegimesDir = Directory(path.join(payloadDir.path, 'extensions'));
      await phaseRegimesDir.create(recursive: true);
      
      // Export phase regimes using the service's export method
      final exportData = _phaseRegimeService!.exportForMcp();
      
      // Write phase_regimes.json
      final phaseRegimesFile = File(path.join(phaseRegimesDir.path, 'phase_regimes.json'));
      await phaseRegimesFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(exportData)
      );
      
      print('ARCX Export V2: Exported ${regimes.length} phase regimes');
      return regimes.length;
    } catch (e) {
      print('ARCX Export V2: Error exporting phase regimes: $e');
      return 0;
    }
  }

  /// Export RIVET state to extensions/rivet_state.json
  Future<void> _exportRivetState(Directory payloadDir) async {
    try {
      // Ensure extensions directory exists (aligned with MCP format)
      final phaseRegimesDir = Directory(path.join(payloadDir.path, 'extensions'));
      await phaseRegimesDir.create(recursive: true);

      if (!Hive.isBoxOpen(RivetBox.boxName)) {
        await Hive.openBox(RivetBox.boxName);
      }
      
      final stateBox = Hive.box(RivetBox.boxName);
      final eventsBox = Hive.isBoxOpen(RivetBox.eventsBoxName) 
          ? Hive.box(RivetBox.eventsBoxName)
          : await Hive.openBox(RivetBox.eventsBoxName);

      final rivetStates = <String, dynamic>{};
      
      // Export all user states
      for (final userId in stateBox.keys) {
        final stateData = stateBox.get(userId);
        if (stateData == null) continue;

        final rivetState = rivet_models.RivetState.fromJson(
          stateData is Map<String, dynamic> 
              ? stateData 
              : Map<String, dynamic>.from(stateData as Map),
        );

        // Get events for this user
        final eventsData = eventsBox.get(userId, defaultValue: <dynamic>[]);
        final events = <rivet_models.RivetEvent>[];
        if (eventsData is List) {
          for (final eventData in eventsData) {
            try {
              final eventMap = eventData is Map<String, dynamic>
                  ? eventData
                  : Map<String, dynamic>.from(eventData as Map);
              events.add(rivet_models.RivetEvent.fromJson(eventMap));
            } catch (e) {
              print('ARCX Export V2: Failed to parse RIVET event: $e');
            }
          }
        }

        rivetStates[userId.toString()] = {
          'state': rivetState.toJson(),
          'events': events.map((e) => e.toJson()).toList(),
          'exported_at': DateTime.now().toIso8601String(),
        };
      }

      if (rivetStates.isNotEmpty) {
        final rivetStateFile = File(path.join(phaseRegimesDir.path, 'rivet_state.json'));
        await rivetStateFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'rivet_states': rivetStates,
            'exported_at': DateTime.now().toIso8601String(),
            'version': '1.0',
          })
        );
        print('ARCX Export V2: Exported RIVET state for ${rivetStates.length} users');
      }
    } catch (e) {
      print('ARCX Export V2: Error exporting RIVET state: $e');
    }
  }

  /// Export Sentinel state to PhaseRegimes/sentinel_state.json
  Future<void> _exportSentinelState(Directory payloadDir) async {
    try {
      // Ensure extensions directory exists (aligned with MCP format)
      final phaseRegimesDir = Directory(path.join(payloadDir.path, 'extensions'));
      await phaseRegimesDir.create(recursive: true);

      // Sentinel state is computed dynamically, so we export a placeholder
      final sentinelStateFile = File(path.join(phaseRegimesDir.path, 'sentinel_state.json'));
      await sentinelStateFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'sentinel_state': {
            'state': 'ok',
            'notes': [],
            'exported_at': DateTime.now().toIso8601String(),
            'note': 'Sentinel state is computed dynamically. This export represents the system state at export time.',
          },
          'exported_at': DateTime.now().toIso8601String(),
          'version': '1.0',
        })
      );
      print('ARCX Export V2: Exported Sentinel state');
    } catch (e) {
      print('ARCX Export V2: Error exporting Sentinel state: $e');
    }
  }

  /// Export ArcForm timeline history to extensions/arcform_timeline.json
  Future<void> _exportArcFormTimeline(Directory payloadDir) async {
    try {
      // Ensure extensions directory exists (aligned with MCP format)
      final phaseRegimesDir = Directory(path.join(payloadDir.path, 'extensions'));
      await phaseRegimesDir.create(recursive: true);

      if (!Hive.isBoxOpen('arcform_snapshots')) {
        await Hive.openBox<ArcformSnapshot>('arcform_snapshots');
      }

      final box = Hive.box<ArcformSnapshot>('arcform_snapshots');
      final snapshots = box.values.toList();

      if (snapshots.isNotEmpty) {
        final arcformTimelineFile = File(path.join(phaseRegimesDir.path, 'arcform_timeline.json'));
        await arcformTimelineFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'arcform_snapshots': snapshots.map((s) => s.toJson()).toList(),
            'exported_at': DateTime.now().toIso8601String(),
            'version': '1.0',
          })
        );
        print('ARCX Export V2: Exported ${snapshots.length} ArcForm timeline snapshots');
      }
    } catch (e) {
      print('ARCX Export V2: Error exporting ArcForm timeline: $e');
    }
  }

  /// Export LUMARA favorites to extensions/lumara_favorites.json
  /// Returns map with total count and per-category counts
  /// Note: Favorites are separate from phase regimes - they're user-saved content (answers, chats, entries)
  /// Phase regimes are system-generated phase tracking data exported separately to phase_regimes.json
  Future<Map<String, int>> _exportLumaraFavorites(Directory payloadDir) async {
    try {
      // Ensure extensions directory exists (aligned with MCP format)
      final extensionsDir = Directory(path.join(payloadDir.path, 'extensions'));
      await extensionsDir.create(recursive: true);

      final favoritesService = FavoritesService.instance;
      await favoritesService.initialize();
      final allFavorites = await favoritesService.getAllFavorites();

      if (allFavorites.isEmpty) {
        print('ARCX Export V2: No LUMARA favorites to export');
        return {
          'total': 0,
          'answers': 0,
          'chats': 0,
          'entries': 0,
        };
      }

      // Separate by category for counting
      final answers = allFavorites.where((f) => f.category == 'answer').toList();
      final chats = allFavorites.where((f) => f.category == 'chat').toList();
      final entries = allFavorites.where((f) => f.category == 'journal_entry').toList();

      // Enrich favorites with phase information for temporal context
      // This allows references like "You felt this way when you wrote this" or 
      // "You were in the same phase when you encountered something similar"
      final enrichedFavorites = await _enrichFavoritesWithPhaseInfo(allFavorites);

      final favoritesFile = File(path.join(extensionsDir.path, 'lumara_favorites.json'));
      await favoritesFile.writeAsString(
        JsonEncoder.withIndent('  ').convert({
          'lumara_favorites': enrichedFavorites, // Already enriched with phase info
          'exported_at': DateTime.now().toIso8601String(),
          'version': '1.2', // Updated to include phase information
          'counts': {
            'answers': answers.length,
            'chats': chats.length,
            'entries': entries.length,
          },
        })
      );

      print('ARCX Export V2: Exported ${allFavorites.length} LUMARA favorites (${answers.length} answers, ${chats.length} chats, ${entries.length} entries)');
      return {
        'total': allFavorites.length,
        'answers': answers.length,
        'chats': chats.length,
        'entries': entries.length,
      };
    } catch (e) {
      print('ARCX Export V2: Error exporting LUMARA favorites: $e');
      return {
        'total': 0,
        'answers': 0,
        'chats': 0,
        'entries': 0,
      };
    }
  }

  /// Enrich favorites with phase information from phase regimes
  /// This adds temporal context so favorites can reference phase like:
  /// "You felt this way when you wrote this" or "You were in the same phase when you encountered something similar"
  /// Returns list of favorite maps with phase data added
  Future<List<Map<String, dynamic>>> _enrichFavoritesWithPhaseInfo(List<LumaraFavorite> favorites) async {
    final enriched = <Map<String, dynamic>>[];
    
    for (final favorite in favorites) {
      final map = <String, dynamic>{
        'id': favorite.id,
        'content': favorite.content,
        'timestamp': favorite.timestamp.toIso8601String(),
        'source_id': favorite.sourceId,
        'source_type': favorite.sourceType,
        'metadata': favorite.metadata,
        'category': favorite.category,
      };

      // Add category-specific fields
      if (favorite.sessionId != null) {
        map['session_id'] = favorite.sessionId;
      }
      if (favorite.entryId != null) {
        map['entry_id'] = favorite.entryId;
      }

      // Try to get phase from metadata first (if already stored)
      String? phase;
      String? phaseRegimeId;
      
      if (favorite.metadata.containsKey('phase')) {
        phase = favorite.metadata['phase']?.toString();
      }
      if (favorite.metadata.containsKey('phase_regime_id')) {
        phaseRegimeId = favorite.metadata['phase_regime_id']?.toString();
      }

      // If no phase in metadata, look up from phase regime service using timestamp
      if ((phase == null || phase.isEmpty) && _phaseRegimeService != null) {
        try {
          final regime = _phaseRegimeService!.phaseIndex.regimeFor(favorite.timestamp);
          if (regime != null) {
            phase = _getPhaseLabelName(regime.label);
            phaseRegimeId = regime.id;
          }
        } catch (e) {
          print('ARCX Export V2: Error looking up phase for favorite ${favorite.id}: $e');
        }
      }

      // Add phase information if available
      if (phase != null && phase.isNotEmpty) {
        map['phase'] = phase;
      }
      if (phaseRegimeId != null && phaseRegimeId.isNotEmpty) {
        map['phase_regime_id'] = phaseRegimeId;
      }

      enriched.add(map);
    }

    return enriched;
  }

  /// Get phase label name from PhaseLabel enum
  String _getPhaseLabelName(PhaseLabel label) {
    switch (label) {
      case PhaseLabel.discovery:
        return 'discovery';
      case PhaseLabel.expansion:
        return 'expansion';
      case PhaseLabel.transition:
        return 'transition';
      case PhaseLabel.consolidation:
        return 'consolidation';
      case PhaseLabel.recovery:
        return 'recovery';
      case PhaseLabel.breakthrough:
        return 'breakthrough';
    }
  }
  
  /// Export health streams (aligned with MCP format)
  Future<void> _exportHealthStreams(List<JournalEntry> entries, Directory payloadDir) async {
    try {
      // Extract journal entry dates for health filtering
      final journalDates = <String>{};
      for (final entry in entries) {
        final dateKey = '${entry.createdAt.year.toString().padLeft(4, '0')}-'
                       '${entry.createdAt.month.toString().padLeft(2, '0')}-'
                       '${entry.createdAt.day.toString().padLeft(2, '0')}';
        journalDates.add(dateKey);
      }
      
      if (journalDates.isEmpty) {
        print('ARCX Export V2: No journal entry dates to filter health streams');
        return;
      }
      
      // Create streams/health directory
      final streamsDir = Directory(path.join(payloadDir.path, 'streams', 'health'));
      await streamsDir.create(recursive: true);
      
      // Copy health streams from app documents if they exist - filtered by journal entry dates
      final appDocDir = await getApplicationDocumentsDirectory();
      final sourceHealthDir = Directory(path.join(appDocDir.path, 'mcp', 'streams', 'health'));
      
      if (!await sourceHealthDir.exists()) {
        print('ARCX Export V2: No health streams directory found');
        return;
      }
      
      print('ARCX Export V2: Copying filtered health streams for ${journalDates.length} journal entry dates...');
      
      int fileCount = 0;
      int totalLines = 0;
      int filteredLines = 0;
      
      await for (final entity in sourceHealthDir.list()) {
        if (entity is File && entity.path.endsWith('.jsonl')) {
          final filename = path.basename(entity.path);
          final destFile = File(path.join(streamsDir.path, filename));
          
          // Read source file and filter lines by journal entry dates
          final sourceLines = await entity.readAsLines();
          final filteredHealthData = <String>[];
          
          for (final line in sourceLines) {
            if (line.trim().isEmpty) continue;
            totalLines++;
            
            try {
              final json = jsonDecode(line) as Map<String, dynamic>;
              final timeslice = json['timeslice'] as Map<String, dynamic>?;
              final startStr = timeslice?['start'] as String?;
              
              if (startStr != null) {
                // Extract date from timeslice start (format: YYYY-MM-DDTHH:MM:SSZ)
                final date = startStr.substring(0, 10); // Extract YYYY-MM-DD part
                
                if (journalDates.contains(date)) {
                  // Add health pointer/association to the health data
                  final enhancedJson = Map<String, dynamic>.from(json);
                  enhancedJson['journal_association'] = {
                    'date': date,
                    'has_journal_entry': true,
                    'exported_at': DateTime.now().toUtc().toIso8601String(),
                  };
                  
                  filteredHealthData.add(jsonEncode(enhancedJson));
                  filteredLines++;
                }
              }
            } catch (e) {
              print('ARCX Export V2: Warning - Could not parse health data line: $e');
            }
          }
          
          // Write filtered data if any lines matched
          if (filteredHealthData.isNotEmpty) {
            await destFile.writeAsString(filteredHealthData.join('\n') + '\n');
            fileCount++;
            print('ARCX Export V2: Filtered health stream: $filename (${filteredHealthData.length} lines)');
          }
        }
      }
      
      if (fileCount > 0) {
        print('ARCX Export V2: ✓ Copied $fileCount filtered health file(s) ($filteredLines/$totalLines lines)');
      } else {
        print('ARCX Export V2: ✓ No health data matched journal entry dates');
      }
    } catch (e) {
      print('ARCX Export V2: Error exporting health streams: $e');
    }
  }
  
  /// Generate checksums for all files
  Future<void> _generateChecksums(Directory payloadDir) async {
    final checksumsDir = Directory(path.join(payloadDir.path, '_checksums'));
    await checksumsDir.create(recursive: true);
    final checksumsFile = File(path.join(checksumsDir.path, 'sha256.txt'));
    
    final checksumLines = <String>[];
    
    // Recursively process all files
    await for (final entity in payloadDir.list(recursive: true)) {
      if (entity is File) {
        // Skip the checksums file itself
        if (entity.path.contains('_checksums')) continue;
        
        final bytes = await entity.readAsBytes();
        final hash = sha256.convert(bytes);
        final relativePath = path.relative(entity.path, from: payloadDir.path);
        checksumLines.add('${hash.toString()}  ./$relativePath');
      }
    }
    
    await checksumsFile.writeAsString(checksumLines.join('\n'));
    print('ARCX Export V2: Generated ${checksumLines.length} checksums');
  }
  
  /// Package and encrypt the ARCX archive
  Future<String> _packageAndEncrypt({
    required Directory payloadDir,
    required ARCXManifest manifest,
    required Directory outputDir,
    required String exportId,
    String? password,
    Function(String)? onProgress,
    String compression = 'auto', // 'auto' or 'off'
    int? exportNumber, // Optional export number for filename labeling
  }) async {
    onProgress?.call('Creating archive...');
    
    // Create ZIP archive from payload
    final archive = Archive();
    await _addDirectoryToArchive(archive, payloadDir, '', compression: compression);
    
    final zipEncoder = ZipEncoder();
    final plaintextZip = zipEncoder.encode(archive);
    
    if (plaintextZip == null) {
      throw Exception('Failed to create ZIP archive');
    }
    
    // Update manifest with payload size
    final updatedManifest = ARCXManifest(
      version: manifest.version,
      algo: manifest.algo,
      kdf: manifest.kdf,
      kdfParams: manifest.kdfParams,
      sha256: '', // Will be set after encryption
      signerPubkeyFpr: '', // Will be set after signing
      signatureB64: '', // Will be set after signing
      payloadMeta: ARCXPayloadMeta(
        journalCount: manifest.payloadMeta.journalCount,
        photoMetaCount: manifest.payloadMeta.photoMetaCount,
        bytes: plaintextZip.length,
      ),
      mcpManifestSha256: manifest.mcpManifestSha256,
      exportedAt: manifest.exportedAt,
      appVersion: manifest.appVersion,
      redactionReport: manifest.redactionReport,
      metadata: manifest.metadata,
      isPasswordEncrypted: password != null && password.isNotEmpty,
      saltB64: manifest.saltB64,
      exportId: manifest.exportId,
      chunkSize: manifest.chunkSize,
      totalChunks: manifest.totalChunks,
      formatVersion: manifest.formatVersion,
      arcxVersion: manifest.arcxVersion,
      scope: manifest.scope,
      encryptionInfo: manifest.encryptionInfo,
      checksumsInfo: manifest.checksumsInfo,
    );
    
    // Encrypt
    onProgress?.call('Encrypting...');
    Uint8List ciphertext;
    String? saltB64;
    
    if (password != null && password.isNotEmpty) {
      final (encryptedData, salt) = await ARCXCryptoService.encryptWithPassword(
        Uint8List.fromList(plaintextZip),
        password,
      );
      ciphertext = encryptedData;
      saltB64 = base64Encode(salt);
    } else {
      ciphertext = await ARCXCryptoService.encryptAEAD(Uint8List.fromList(plaintextZip));
    }
    
    // Compute ciphertext hash
    final ciphertextHash = sha256.convert(ciphertext);
    final ciphertextHashB64 = base64Encode(ciphertextHash.bytes);
    
    // Sign manifest
    onProgress?.call('Signing...');
    final pubkeyFpr = await ARCXCryptoService.getSigningPublicKeyFingerprint();
    final manifestJson = jsonEncode(updatedManifest.toJson());
    final manifestBytes = utf8.encode(manifestJson);
    final signature = await ARCXCryptoService.signData(Uint8List.fromList(manifestBytes));
    
    // Create final manifest with signature
    final finalManifest = ARCXManifest(
      version: updatedManifest.version,
      algo: updatedManifest.algo,
      kdf: updatedManifest.kdf,
      kdfParams: updatedManifest.kdfParams,
      sha256: ciphertextHashB64,
      signerPubkeyFpr: pubkeyFpr,
      signatureB64: signature,
      payloadMeta: updatedManifest.payloadMeta,
      mcpManifestSha256: updatedManifest.mcpManifestSha256,
      exportedAt: updatedManifest.exportedAt,
      appVersion: updatedManifest.appVersion,
      redactionReport: updatedManifest.redactionReport,
      metadata: updatedManifest.metadata,
      isPasswordEncrypted: updatedManifest.isPasswordEncrypted,
      saltB64: saltB64,
      exportId: updatedManifest.exportId,
      chunkSize: updatedManifest.chunkSize,
      totalChunks: updatedManifest.totalChunks,
      formatVersion: updatedManifest.formatVersion,
      arcxVersion: updatedManifest.arcxVersion,
      scope: updatedManifest.scope,
      encryptionInfo: updatedManifest.encryptionInfo,
      checksumsInfo: updatedManifest.checksumsInfo,
    );
    
    // Create final .arcx ZIP
    onProgress?.call('Writing archive...');
    
    // Ensure output directory exists and is writable
    if (!await outputDir.exists()) {
      try {
        await outputDir.create(recursive: true);
        print('ARCX Export V2: Created output directory: ${outputDir.path}');
      } catch (e) {
        throw Exception('Cannot create output directory: ${outputDir.path}. Error: $e');
      }
    }
    
    // Verify directory is writable
    try {
      final testFile = File(path.join(outputDir.path, '.test_write'));
      await testFile.writeAsString('test');
      await testFile.delete();
    } catch (e) {
      throw Exception('Output directory is not writable: ${outputDir.path}. Error: $e. Please check folder permissions.');
    }
    
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    // Include export number in filename for UI/UX tracking (e.g., export_1_2026-01-10T17-15-40.arcx)
    final arcxFileName = exportNumber != null 
        ? 'export_${exportNumber}_$timestamp.arcx'
        : 'export_$timestamp.arcx';
    
    // Clean path: remove trailing spaces and normalize
    final cleanOutputPath = outputDir.path.trim();
    final arcxPath = path.join(cleanOutputPath, arcxFileName);
    
    print('ARCX Export V2: Writing to: $arcxPath');
    
    final finalArchive = Archive();
    finalArchive.addFile(ArchiveFile(
      'archive.arcx',
      ciphertext.length,
      ciphertext,
    ));
    finalArchive.addFile(ArchiveFile(
      'manifest.json',
      utf8.encode(jsonEncode(finalManifest.toJson())).length,
      utf8.encode(jsonEncode(finalManifest.toJson())),
    ));
    
    final finalZipBytes = ZipEncoder().encode(finalArchive);
    if (finalZipBytes == null) {
      throw Exception('Failed to create final ZIP archive');
    }
    
    // Write file with error handling
    try {
      final outputFile = File(arcxPath);
      await outputFile.writeAsBytes(finalZipBytes);
      print('ARCX Export V2: ✓ Created ARCX archive: $arcxPath (${finalZipBytes.length} bytes)');
    } catch (e) {
      // Check for disk space errors specifically
      final errorString = e.toString();
      if (errorString.contains('No space left on device') || 
          errorString.contains('errno = 28') ||
          errorString.contains('ENOSPC')) {
        throw Exception(
          'Backup failed: Not enough storage space on device.\n\n'
          'The backup requires approximately ${(finalZipBytes.length / (1024 * 1024)).toStringAsFixed(1)} MB of free space.\n\n'
          'Please free up space on your device and try again:\n'
          '• Delete unused apps or files\n'
          '• Clear app caches\n'
          '• Move photos/videos to iCloud\n'
          '• Check Settings → General → iPhone Storage'
        );
      } else if (errorString.contains('Permission denied') || 
                 errorString.contains('errno = 13')) {
        throw Exception(
          'Backup failed: Write permission denied.\n\n'
          'The selected backup folder does not have write permissions.\n\n'
          'Please:\n'
          '• Select a different folder (try "On My iPhone" → "ARC")\n'
          '• Avoid iCloud Drive folders\n'
          '• Use the "Use App Documents" button for recommended location'
        );
      } else {
        // Generic error with helpful context
        throw Exception(
          'Backup failed: Failed to write ARCX file to $arcxPath\n\n'
          'Error: $e\n\n'
          'Possible causes:\n'
          '• Not enough storage space (most common)\n'
          '• Write permission denied\n'
          '• Folder is read-only\n\n'
          'Try:\n'
          '• Free up space on your device\n'
          '• Select a different backup folder\n'
          '• Use "Use App Documents" for recommended location'
        );
      }
    }
    
    return arcxPath;
  }
  
  /// Recursively add directory to archive
  Future<void> _addDirectoryToArchive(Archive archive, Directory dir, String basePath, {String compression = 'auto'}) async {
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        await _addDirectoryToArchive(archive, entity, path.join(basePath, path.basename(entity.path)), compression: compression);
      } else if (entity is File) {
        final content = await entity.readAsBytes();
        final relativePath = path.join(basePath, path.basename(entity.path));
        final archiveFile = ArchiveFile(relativePath, content.length, content);
        
        // Control compression based on option
        if (compression == 'off') {
          // Uncompressed archive: disable compression for all files
          archiveFile.compress = false;
        } else {
          // Auto compression: skip compression for already-compressed media files
          final ext = path.extension(entity.path).toLowerCase();
          if (['.jpg', '.jpeg', '.png', '.mp4', '.mov', '.heic', '.heif', '.m4a'].contains(ext)) {
            archiveFile.compress = false;
          }
        }
        
        archive.addFile(archiveFile);
      }
    }
  }
  
  /// Export incrementally - only new/changed entries since last export
  /// 
  /// [excludeMedia] - If true, creates text-only backup (entries + chats, no media)
  ///                   This makes incremental backups much smaller and faster
  /// 
  /// Uses the "Backup Set" model:
  /// - If no backup set exists, creates one with a full chunked backup first
  /// - Subsequent incrementals continue numbering in the same backup set folder
  /// - Incremental files are named: ARC_Inc_NNN_YYYY-MM-DD.arcx
  Future<ARCXExportResultV2> exportIncremental({
    required Directory outputDir,
    String? password,
    Function(String)? onProgress,
    ARCXExportStrategy strategy = ARCXExportStrategy.together,
    bool excludeMedia = false, // Option to exclude media for space-efficient text-only backups
  }) async {
    try {
      final historyService = ExportHistoryService.instance;
      final lastExportDate = await historyService.getLastExportDate();
      final history = await historyService.getHistory();
      
      // Find the latest backup set folder
      Directory? backupSetDir = await _findLatestBackupSet(outputDir);
      
      // If no backup set exists OR no previous exports, create a new backup set with full backup
      if (backupSetDir == null || lastExportDate == null || history.totalExports == 0) {
        onProgress?.call('No backup set found. Creating new backup set with full backup...');
        debugPrint('ARCX Export: No backup set found - creating new backup set');
        
        // Use chunked full backup to create the backup set
        final chunkedResult = await exportFullBackupChunked(
          outputDir: outputDir,
          password: password,
          onProgress: onProgress,
          chunkSizeMB: 200,
        );
        
        if (chunkedResult.success) {
          return ARCXExportResultV2.success(
            arcxPath: chunkedResult.folderPath,
            entriesExported: chunkedResult.totalEntries,
            chatsExported: chunkedResult.totalChats,
            mediaExported: chunkedResult.totalMedia,
            separatePackages: chunkedResult.chunkPaths,
          );
        } else {
          return ARCXExportResultV2.failure(chunkedResult.error ?? 'Failed to create backup set');
        }
      }
      
      // Normal incremental export (backup set and previous exports exist)
      onProgress?.call('Analyzing changes since last backup...');
      
      // Get all current entries and chats
      final allEntries = await _journalRepo?.getAllJournalEntries() ?? [];
      final allChats = await _chatRepo?.listAll(includeArchived: true) ?? [];
      
      // Filter to only new/modified since last export
      final entriesToExport = allEntries.where((e) => 
          e.createdAt.isAfter(lastExportDate) || 
          e.updatedAt.isAfter(lastExportDate)
        ).toList();
        
      final chatsToExport = allChats.where((c) => 
          c.createdAt.isAfter(lastExportDate) ||
          c.updatedAt.isAfter(lastExportDate)
        ).toList();
      
      // Collect media from entries to export (unless excluded)
      final mediaToExport = <MediaItem>[];
      
      // Only collect media if not excluded from incremental backups
      if (!excludeMedia) {
        for (final entry in entriesToExport) {
          for (final media in entry.media) {
            // Skip if already exported (by hash)
            if (media.sha256 != null && 
                history.allExportedMediaHashes.contains(media.sha256)) {
              continue;
            }
            mediaToExport.add(media);
          }
        }
      }
      
      // Show preview
      if (excludeMedia) {
        onProgress?.call(
          'Found ${entriesToExport.length} new entries, '
          '${chatsToExport.length} new chats (text-only backup, media excluded)'
        );
      } else {
        onProgress?.call(
          'Found ${entriesToExport.length} new entries, '
          '${chatsToExport.length} new chats, '
          '${mediaToExport.length} new media items'
        );
      }
      
      if (entriesToExport.isEmpty && chatsToExport.isEmpty) {
        onProgress?.call('No new data to export since last backup');
        return ARCXExportResultV2.success(
          arcxPath: backupSetDir.path,
          entriesExported: 0,
          chatsExported: 0,
          mediaExported: 0,
        );
      }
      
      // Get the next file number in the backup set
      final highestNum = await _getHighestFileNumber(backupSetDir);
      final nextNum = (highestNum + 1).toString().padLeft(3, '0');
      final timestamp = DateTime.now();
      final dateStr = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
      final incFilename = 'ARC_Inc_${nextNum}_$dateStr';
      
      onProgress?.call('Creating incremental backup: $incFilename.arcx');
      
      // Collect media for this incremental's entries
      final incMedia = <MediaItem>[];
      for (final entry in entriesToExport) {
        incMedia.addAll(entry.media);
      }
      
      final options = ARCXExportOptions(
        strategy: strategy,
        incrementalMode: true,
        skipExportedMedia: !excludeMedia, // If excluding media, don't skip (we're not including any)
        trackExportHistory: true,
        excludeMediaFromIncremental: excludeMedia,
      );
      
      final exportId = _uuid.v4();
      final exportedAt = DateTime.now().toUtc().toIso8601String();
      
      // Export to backup set folder using _exportTogether
      final result = await _exportTogether(
        entries: entriesToExport,
        chats: chatsToExport,
        media: excludeMedia ? [] : incMedia,
        options: options,
        exportId: exportId,
        exportedAt: exportedAt,
        outputDir: backupSetDir, // Export to the backup set folder
        password: password,
        onProgress: onProgress,
        exportNumber: highestNum + 1,
      );
      
      String? finalPath;
      if (result.success && result.arcxPath != null) {
        // Rename to use our incremental filename format
        final originalFile = File(result.arcxPath!);
        finalPath = path.join(backupSetDir.path, '$incFilename.arcx');
        await originalFile.rename(finalPath);
        debugPrint('ARCX Incremental: Created $finalPath');
      }
      
      // Record export in history
      if (result.success && options.trackExportHistory) {
        final mediaHashes = mediaToExport
            .where((m) => m.sha256 != null)
            .map((m) => m.sha256!)
            .toSet();
        
        final exportNumber = await historyService.getNextExportNumber();
        await historyService.recordExport(ExportRecord(
          exportId: 'arcx-inc-${timestamp.millisecondsSinceEpoch}',
          exportedAt: timestamp,
          exportPath: finalPath ?? result.arcxPath,
          entryIds: entriesToExport.map((e) => e.id).toSet(),
          chatIds: chatsToExport.map((c) => c.id).toSet(),
          mediaHashes: mediaHashes,
          entriesCount: result.entriesExported,
          chatsCount: result.chatsExported,
          mediaCount: result.mediaExported,
          archiveSizeBytes: await _getFileSize(finalPath ?? result.arcxPath ?? ''),
          isFullBackup: false,
          exportNumber: exportNumber,
        ));
      }
      
      return ARCXExportResultV2.success(
        arcxPath: finalPath ?? result.arcxPath ?? backupSetDir.path,
        entriesExported: result.entriesExported,
        chatsExported: result.chatsExported,
        mediaExported: result.mediaExported,
      );
    } catch (e, stackTrace) {
      debugPrint('ARCX Incremental Export: Failed: $e');
      debugPrint('Stack trace: $stackTrace');
      return ARCXExportResultV2.failure(e.toString());
    }
  }
  
  /// Export full backup and record in history
  Future<ARCXExportResultV2> exportFullBackup({
    required Directory outputDir,
    String? password,
    Function(String)? onProgress,
    ARCXExportStrategy strategy = ARCXExportStrategy.together,
  }) async {
    onProgress?.call('Creating full backup...');
    
    // Get all data
    final allEntries = await _journalRepo?.getAllJournalEntries() ?? [];
    final allChats = await _chatRepo?.listAll(includeArchived: true) ?? [];
    
    final selection = ARCXExportSelection(
      entryIds: allEntries.map((e) => e.id).toList(),
      chatThreadIds: allChats.map((c) => c.id).toList(),
    );
    
    final options = ARCXExportOptions.fullBackup(strategy: strategy);
    
    // Get export number for sequential labeling
    final historyService = ExportHistoryService.instance;
    final exportNumber = await historyService.getNextExportNumber();
    
    final result = await export(
      selection: selection,
      options: options,
      outputDir: outputDir,
      password: password,
      onProgress: onProgress,
      exportNumber: exportNumber,
    );
    
    // Record full backup in history
    if (result.success) {
      // Collect all media hashes
      final mediaHashes = <String>{};
      for (final entry in allEntries) {
        for (final media in entry.media) {
          if (media.sha256 != null) {
            mediaHashes.add(media.sha256!);
          }
        }
      }
      
      await historyService.recordExport(ExportRecord(
        exportId: 'arcx-full-${DateTime.now().millisecondsSinceEpoch}',
        exportedAt: DateTime.now(),
        exportPath: result.arcxPath,
        entryIds: allEntries.map((e) => e.id).toSet(),
        chatIds: allChats.map((c) => c.id).toSet(),
        mediaHashes: mediaHashes,
        entriesCount: result.entriesExported,
        chatsCount: result.chatsExported,
        mediaCount: result.mediaExported,
        archiveSizeBytes: await _getFileSize(result.arcxPath ?? ''),
        isFullBackup: true,
        exportNumber: exportNumber,
      ));
    }
    
    return result;
  }
  
  /// Export full backup split into chunks of ~chunkSizeMB each
  /// 
  /// Creates a "backup set" folder containing multiple .arcx files, each up to the specified size.
  /// Files are numbered sequentially (001, 002, etc.) with oldest entries first.
  /// Incremental backups will continue numbering in this same folder.
  /// 
  /// Example output:
  /// ```
  /// ARC_BackupSet_2026-01-16/
  ///   ├── ARC_Full_001.arcx  (oldest entries, ≤200MB)
  ///   ├── ARC_Full_002.arcx  (next batch, ≤200MB)
  ///   ├── ARC_Full_003.arcx  (newest entries, remaining)
  ///   ├── ARC_Inc_004_2026-01-17.arcx  (incremental backup later)
  ///   └── ARC_Inc_005_2026-01-20.arcx  (another incremental)
  /// ```
  Future<ChunkedBackupResult> exportFullBackupChunked({
    required Directory outputDir,
    String? password,
    Function(String)? onProgress,
    int chunkSizeMB = 200,
  }) async {
    try {
      onProgress?.call('Preparing chunked backup...');
      
      final timestamp = DateTime.now();
      final dateStr = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
      final dateFolderName = 'ARC_BackupSet_$dateStr';
      final backupDir = Directory(path.join(outputDir.path, dateFolderName));
      
      // Create backup folder
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      // Get all entries sorted chronologically (oldest first)
      final allEntries = await _journalRepo?.getAllJournalEntries() ?? [];
      allEntries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      final allChats = await _chatRepo?.listAll(includeArchived: true) ?? [];
      allChats.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      onProgress?.call('Found ${allEntries.length} entries and ${allChats.length} chats');
      
      if (allEntries.isEmpty && allChats.isEmpty) {
        return ChunkedBackupResult.failure('No data to backup');
      }
      
      // Split into chunks based on ACTUAL media sizes (async version checks accessibility)
      onProgress?.call('Analyzing data for optimal chunking...');
      final chunks = await _splitDataIntoChunksAsync(allEntries, allChats, chunkSizeMB, onProgress);
      onProgress?.call('Splitting into ${chunks.length} chunk(s) of ~${chunkSizeMB}MB each');
      
      final chunkPaths = <String>[];
      int totalMedia = 0;
      
      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final chunkNum = (i + 1).toString().padLeft(3, '0');
        final chunkFilename = 'ARC_Full_$chunkNum';
        
        onProgress?.call('Exporting chunk ${i + 1}/${chunks.length} (${chunk.entries.length} entries, ${chunk.chats.length} chats)...');
        
        // Collect media for this chunk's entries
        final chunkMedia = <MediaItem>[];
        for (final entry in chunk.entries) {
          chunkMedia.addAll(entry.media);
        }
        totalMedia += chunkMedia.length;
        
        final options = ARCXExportOptions.fullBackup();
        final exportId = _uuid.v4();
        final exportedAt = DateTime.now().toUtc().toIso8601String();
        
        // Export this chunk using _exportTogether
        final result = await _exportTogether(
          entries: chunk.entries,
          chats: chunk.chats,
          media: chunkMedia,
          options: options,
          exportId: exportId,
          exportedAt: exportedAt,
          outputDir: backupDir,
          password: password,
          onProgress: (msg) => onProgress?.call('Chunk ${i + 1}: $msg'),
          exportNumber: i + 1,
        );
        
        if (result.success && result.arcxPath != null) {
          // Rename to use our custom filename format
          final originalFile = File(result.arcxPath!);
          final newPath = path.join(backupDir.path, '$chunkFilename.arcx');
          await originalFile.rename(newPath);
          chunkPaths.add(newPath);
          debugPrint('ARCX Chunked Backup: Created chunk ${i + 1}: $newPath');
        } else {
          debugPrint('ARCX Chunked Backup: Failed to create chunk ${i + 1}: ${result.error}');
          return ChunkedBackupResult.failure('Failed to create chunk ${i + 1}: ${result.error}');
        }
      }
      
      onProgress?.call('Chunked backup complete: ${chunks.length} files created');
      
      // Record in export history
      final historyService = ExportHistoryService.instance;
      final mediaHashes = <String>{};
      for (final entry in allEntries) {
        for (final media in entry.media) {
          if (media.sha256 != null) {
            mediaHashes.add(media.sha256!);
          }
        }
      }
      
      await historyService.recordExport(ExportRecord(
        exportId: 'arcx-chunked-${timestamp.millisecondsSinceEpoch}',
        exportedAt: timestamp,
        exportPath: backupDir.path,
        entryIds: allEntries.map((e) => e.id).toSet(),
        chatIds: allChats.map((c) => c.id).toSet(),
        mediaHashes: mediaHashes,
        entriesCount: allEntries.length,
        chatsCount: allChats.length,
        mediaCount: totalMedia,
        archiveSizeBytes: await _getFolderSize(backupDir.path),
        isFullBackup: true,
        exportNumber: await historyService.getNextExportNumber(),
      ));
      
      return ChunkedBackupResult(
        success: true,
        folderPath: backupDir.path,
        chunkPaths: chunkPaths,
        totalChunks: chunks.length,
        totalEntries: allEntries.length,
        totalChats: allChats.length,
        totalMedia: totalMedia,
        timestamp: timestamp,
      );
    } catch (e, stackTrace) {
      debugPrint('ARCX Chunked Backup: Failed: $e');
      debugPrint('Stack trace: $stackTrace');
      return ChunkedBackupResult.failure(e.toString());
    }
  }
  
  /// Split entries and chats into chunks based on estimated size (async version with accurate media sizing)
  Future<List<_ExportChunk>> _splitDataIntoChunksAsync(
    List<JournalEntry> entries,
    List<ChatSession> chats,
    int chunkSizeMB,
    Function(String)? onProgress,
  ) async {
    final chunkSizeBytes = chunkSizeMB * 1024 * 1024;
    final chunks = <_ExportChunk>[];
    
    var currentEntries = <JournalEntry>[];
    var currentChats = <ChatSession>[];
    var currentSize = 0;
    
    debugPrint('ARCX Chunking: Target chunk size: ${chunkSizeMB}MB (${chunkSizeBytes} bytes)');
    debugPrint('ARCX Chunking: Processing ${entries.length} entries and ${chats.length} chats');
    onProgress?.call('Analyzing ${entries.length} entries for chunking...');
    
    // Process entries (already sorted oldest → newest)
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      
      // Show progress during estimation (this can take time for many entries with media)
      if (i % 10 == 0 || entry.media.isNotEmpty) {
        onProgress?.call('Analyzing entry ${i + 1}/${entries.length}...');
      }
      
      // Use async estimation that checks actual media accessibility
      final entrySize = await _estimateEntrySizeAsync(entry);
      
      debugPrint('ARCX Chunking: Entry ${entry.id.length > 8 ? entry.id.substring(0, 8) : entry.id}... actual size: ${(entrySize / 1024 / 1024).toStringAsFixed(2)}MB, media count: ${entry.media.length}');
      
      // If current chunk is already at/over target and we have data, finalize it
      if (currentSize >= chunkSizeBytes && currentEntries.isNotEmpty) {
        debugPrint('ARCX Chunking: Creating chunk with ${currentEntries.length} entries, size ${(currentSize / 1024 / 1024).toStringAsFixed(2)}MB');
        chunks.add(_ExportChunk(
          entries: List.from(currentEntries),
          chats: List.from(currentChats),
          estimatedSizeBytes: currentSize,
        ));
        currentEntries = [];
        currentChats = [];
        currentSize = 0;
      }
      
      // If adding this entry would exceed chunk size AND we already have entries, start new chunk
      if (currentSize + entrySize > chunkSizeBytes && currentEntries.isNotEmpty) {
        debugPrint('ARCX Chunking: Entry would exceed limit. Creating chunk with ${currentEntries.length} entries, size ${(currentSize / 1024 / 1024).toStringAsFixed(2)}MB');
        chunks.add(_ExportChunk(
          entries: List.from(currentEntries),
          chats: List.from(currentChats),
          estimatedSizeBytes: currentSize,
        ));
        currentEntries = [];
        currentChats = [];
        currentSize = 0;
      }
      
      currentEntries.add(entry);
      currentSize += entrySize;
    }
    
    // Process remaining chats - add to the last chunk or create new one
    onProgress?.call('Analyzing ${chats.length} chats...');
    for (final chat in chats) {
      final chatSize = _estimateChatSize(chat);
      
      if (currentSize + chatSize > chunkSizeBytes && (currentEntries.isNotEmpty || currentChats.isNotEmpty)) {
        chunks.add(_ExportChunk(
          entries: List.from(currentEntries),
          chats: List.from(currentChats),
          estimatedSizeBytes: currentSize,
        ));
        currentEntries = [];
        currentChats = [];
        currentSize = 0;
      }
      
      currentChats.add(chat);
      currentSize += chatSize;
    }
    
    // Add remaining data as final chunk
    if (currentEntries.isNotEmpty || currentChats.isNotEmpty) {
      debugPrint('ARCX Chunking: Final chunk with ${currentEntries.length} entries, ${currentChats.length} chats, size ${(currentSize / 1024 / 1024).toStringAsFixed(2)}MB');
      chunks.add(_ExportChunk(
        entries: currentEntries,
        chats: currentChats,
        estimatedSizeBytes: currentSize,
      ));
    }
    
    // If no chunks were created (shouldn't happen), create one with all data
    if (chunks.isEmpty && (entries.isNotEmpty || chats.isNotEmpty)) {
      int totalSize = 0;
      for (final e in entries) {
        totalSize += await _estimateEntrySizeAsync(e);
      }
      for (final c in chats) {
        totalSize += _estimateChatSize(c);
      }
      chunks.add(_ExportChunk(
        entries: entries,
        chats: chats,
        estimatedSizeBytes: totalSize,
      ));
    }
    
    debugPrint('ARCX Chunking: Created ${chunks.length} chunks total');
    onProgress?.call('Data will be split into ${chunks.length} chunk(s)');
    return chunks;
  }
  
  
  /// Estimate the size of a journal entry including media
  /// This async version checks actual media accessibility to provide accurate estimates
  Future<int> _estimateEntrySizeAsync(JournalEntry entry) async {
    // Base JSON size (rough estimate)
    var size = utf8.encode(jsonEncode(entry.toJson())).length;
    
    // Add media sizes - only count media that can actually be retrieved
    for (final media in entry.media) {
      final mediaSize = await _getActualMediaSize(media);
      size += mediaSize;
    }
    
    return size;
  }
  
  /// Get the actual size of a media item by checking if it's accessible
  /// Returns 0 if media cannot be retrieved (won't be included in export)
  Future<int> _getActualMediaSize(MediaItem media) async {
    // If we have a known size and it's a file:// URI, trust it
    if (media.sizeBytes != null && media.sizeBytes! > 0) {
      final mediaFile = File(media.uri);
      if (await mediaFile.exists()) {
        return media.sizeBytes!;
      }
    }
    
    // Try 1: Direct file path
    final mediaFile = File(media.uri);
    if (await mediaFile.exists()) {
      try {
        return await mediaFile.length();
      } catch (_) {}
    }
    
    // Try 2: Photo library URI (ph://)
    if (PhotoBridge.isPhotoLibraryUri(media.uri)) {
      final localId = PhotoBridge.extractLocalIdentifier(media.uri);
      if (localId != null && media.type == MediaType.image) {
        try {
          final photoData = await PhotoBridge.getPhotoBytes(localId);
          if (photoData != null) {
            final bytes = photoData['bytes'] as Uint8List?;
            if (bytes != null) {
              return bytes.length;
            }
          }
        } catch (_) {}
        
        // Try thumbnail fallback
        try {
          final thumbnailPath = await PhotoLibraryService.getPhotoThumbnail(media.uri, size: 1920);
          if (thumbnailPath != null) {
            final thumbFile = File(thumbnailPath);
            if (await thumbFile.exists()) {
              return await thumbFile.length();
            }
          }
        } catch (_) {}
      }
    }
    
    // Try 3: Search in Documents/photos directory
    if (media.type == MediaType.image) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final photosDir = Directory(path.join(appDir.path, 'photos'));
        if (await photosDir.exists()) {
          final fileName = path.basename(media.uri);
          final possibleFile = File(path.join(photosDir.path, fileName));
          if (await possibleFile.exists()) {
            return await possibleFile.length();
          }
        }
      } catch (_) {}
    }
    
    // Media is not accessible - will be skipped during export
    // Return 0 so it doesn't inflate the chunk size estimate
    debugPrint('ARCX Chunking: Media not accessible, will skip: ${media.uri}');
    return 0;
  }
  
  
  /// Estimate the size of a chat session
  int _estimateChatSize(ChatSession chat) {
    // Estimate: ~1KB per message + metadata
    // ChatSession.messages might be lazy-loaded, estimate based on typical size
    return 50000; // 50KB average per session (conservative estimate)
  }
  
  /// Get total size of a folder
  Future<int> _getFolderSize(String folderPath) async {
    int totalSize = 0;
    try {
      final dir = Directory(folderPath);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (_) {}
    return totalSize;
  }
  
  /// Get file size helper
  Future<int> _getFileSize(String path) async {
    if (path.isEmpty) return 0;
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return 0;
  }
  
  /// Find the latest backup set folder in the output directory
  /// Returns null if no backup set exists
  Future<Directory?> _findLatestBackupSet(Directory outputDir) async {
    if (!await outputDir.exists()) return null;
    
    Directory? latestSet;
    DateTime? latestDate;
    
    await for (final entity in outputDir.list()) {
      if (entity is Directory) {
        final name = path.basename(entity.path);
        // Match ARC_BackupSet_YYYY-MM-DD pattern
        final match = RegExp(r'^ARC_BackupSet_(\d{4})-(\d{2})-(\d{2})$').firstMatch(name);
        if (match != null) {
          try {
            final year = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            final day = int.parse(match.group(3)!);
            final setDate = DateTime(year, month, day);
            
            if (latestDate == null || setDate.isAfter(latestDate)) {
              latestDate = setDate;
              latestSet = entity;
            }
          } catch (_) {}
        }
      }
    }
    
    return latestSet;
  }
  
  /// Get the highest file number in a backup set folder
  /// Returns 0 if folder is empty or no numbered files exist
  Future<int> _getHighestFileNumber(Directory backupSetDir) async {
    int highestNum = 0;
    
    if (!await backupSetDir.exists()) return 0;
    
    await for (final entity in backupSetDir.list()) {
      if (entity is File && entity.path.endsWith('.arcx')) {
        final fileName = path.basenameWithoutExtension(entity.path);
        // Match ARC_Full_NNN or ARC_Inc_NNN_* pattern
        final fullMatch = RegExp(r'^ARC_Full_(\d{3})$').firstMatch(fileName);
        final incMatch = RegExp(r'^ARC_Inc_(\d{3})_').firstMatch(fileName);
        
        int? num;
        if (fullMatch != null) {
          num = int.tryParse(fullMatch.group(1)!);
        } else if (incMatch != null) {
          num = int.tryParse(incMatch.group(1)!);
        }
        
        if (num != null && num > highestNum) {
          highestNum = num;
        }
      }
    }
    
    return highestNum;
  }
  
  /// Get the timestamp of the newest file in a backup set
  Future<DateTime?> _getLatestBackupTimestamp(Directory backupSetDir) async {
    DateTime? latestTime;
    
    if (!await backupSetDir.exists()) return null;
    
    await for (final entity in backupSetDir.list()) {
      if (entity is File && entity.path.endsWith('.arcx')) {
        try {
          final stat = await entity.stat();
          if (latestTime == null || stat.modified.isAfter(latestTime)) {
            latestTime = stat.modified;
          }
        } catch (_) {}
      }
    }
    
    return latestTime;
  }
  
  /// Get incremental export preview (for UI)
  Future<Map<String, dynamic>> getIncrementalExportPreview() async {
    final historyService = ExportHistoryService.instance;
    final lastExportDate = await historyService.getLastExportDate();
    
    final allEntries = await _journalRepo?.getAllJournalEntries() ?? [];
    final allChats = await _chatRepo?.listAll(includeArchived: true) ?? [];
    
    int newEntries = 0;
    int modifiedEntries = 0;
    int newChats = 0;
    int newMedia = 0;
    
    if (lastExportDate != null) {
      final history = await historyService.getHistory();
      
      for (final entry in allEntries) {
        if (entry.createdAt.isAfter(lastExportDate)) {
          newEntries++;
          // Count new media
          for (final media in entry.media) {
            if (media.sha256 == null || 
                !history.allExportedMediaHashes.contains(media.sha256)) {
              newMedia++;
            }
          }
        } else if (entry.updatedAt.isAfter(lastExportDate)) {
          modifiedEntries++;
        }
      }
      
      for (final chat in allChats) {
        if (chat.createdAt.isAfter(lastExportDate)) {
          newChats++;
        }
      }
    } else {
      // No previous export
      newEntries = allEntries.length;
      newChats = allChats.length;
      for (final entry in allEntries) {
        newMedia += entry.media.length;
      }
    }
    
    return {
      'lastExportDate': lastExportDate,
      'newEntries': newEntries,
      'modifiedEntries': modifiedEntries,
      'newChats': newChats,
      'newMedia': newMedia,
      'totalEntries': allEntries.length,
      'totalChats': allChats.length,
      'hasChanges': newEntries > 0 || modifiedEntries > 0 || newChats > 0,
    };
  }
}

/// ARCX Export Result V2
class ARCXExportResultV2 {
  final bool success;
  final String? arcxPath;
  final int entriesExported;
  final int chatsExported;
  final int mediaExported;
  final List<String>? separatePackages;
  final String? error;
  
  ARCXExportResultV2({
    required this.success,
    this.arcxPath,
    this.entriesExported = 0,
    this.chatsExported = 0,
    this.mediaExported = 0,
    this.separatePackages,
    this.error,
  });
  
  factory ARCXExportResultV2.success({
    required String arcxPath,
    int entriesExported = 0,
    int chatsExported = 0,
    int mediaExported = 0,
    List<String>? separatePackages,
  }) {
    return ARCXExportResultV2(
      success: true,
      arcxPath: arcxPath,
      entriesExported: entriesExported,
      chatsExported: chatsExported,
      mediaExported: mediaExported,
      separatePackages: separatePackages,
    );
  }
  
  factory ARCXExportResultV2.failure(String error) {
    return ARCXExportResultV2(
      success: false,
      error: error,
    );
  }
}


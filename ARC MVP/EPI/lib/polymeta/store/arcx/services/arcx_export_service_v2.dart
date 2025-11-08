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
import '../models/arcx_manifest.dart';
import 'arcx_crypto_service.dart';

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
  
  ARCXExportOptions({
    this.strategy = ARCXExportStrategy.together,
    this.mediaPackTargetSizeMB = 200,
    this.encrypt = true,
    this.compression = 'auto',
    this.dedupeMedia = true,
    this.includeChecksums = true,
    this.startDate,
    this.endDate,
  });
  
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

/// ARCX Export Service V2
class ARCXExportServiceV2 {
  final JournalRepository? _journalRepo;
  final ChatRepo? _chatRepo;
  
  ARCXExportServiceV2({
    JournalRepository? journalRepo,
    ChatRepo? chatRepo,
  }) : _journalRepo = journalRepo,
       _chatRepo = chatRepo;
  
  /// Export data to ARCX format
  Future<ARCXExportResultV2> export({
    required ARCXExportSelection selection,
    required ARCXExportOptions options,
    required Directory outputDir,
    String? password,
    Function(String)? onProgress,
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
        chatsExported = await _exportChats(
          chats: chats,
          links: links,
          payloadDir: payloadDir,
          onProgress: onProgress,
        );
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
  }) async {
    // Build links map for all groups
    final links = _buildLinksMap(entries, chats, media);
    
    final results = <String>[];
    
    // Export Entries
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
          chatsExported = await _exportChats(
            chats: chats,
            links: links,
            payloadDir: payloadDir,
            onProgress: onProgress,
          );
        }
        
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
      
      if (groupType == 'Entries' && entries.isNotEmpty) {
        entriesExported = await _exportEntries(
          entries: entries,
          links: links,
          payloadDir: payloadDir,
          onProgress: onProgress,
        );
      } else if (groupType == 'Chats' && chats.isNotEmpty) {
        chatsExported = await _exportChats(
          chats: chats,
          links: links,
          payloadDir: payloadDir,
          onProgress: onProgress,
        );
      } else if (groupType == 'Media' && media.isNotEmpty) {
        mediaExported = await _exportMediaWithPacks(
          media: media,
          links: links,
          payloadDir: payloadDir,
          options: options,
          onProgress: onProgress,
        );
      }
      
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
    
    final entries = <JournalEntry>[];
    for (final id in entryIds) {
      final entry = _journalRepo!.getJournalEntryById(id);
      if (entry != null) {
        // Apply date filtering if provided
        if (startDate != null && entry.createdAt.isBefore(startDate)) continue;
        if (endDate != null && entry.createdAt.isAfter(endDate)) continue;
        entries.add(entry);
      }
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
      
      // Create entry JSON with links
      final entryLinks = links['entry-${entry.id}'] ?? {'media_ids': [], 'chat_thread_ids': []};
      final entryJson = {
        'id': entry.id,
        'type': 'entry',
        'created_at': entry.createdAt.toUtc().toIso8601String(),
        'date_bucket': dateBucket,
        'title': entry.title,
        'slug': slug,
        'content': entry.content,
        'links': {
          'media_ids': entryLinks['media_ids'] ?? [],
          'chat_thread_ids': entryLinks['chat_thread_ids'] ?? [],
        },
        'emotion': entry.emotion,
        'emotionReason': entry.emotionReason,
        'phase': entry.phase,
        'keywords': entry.keywords,
        'metadata': entry.metadata ?? {},
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
  Future<int> _exportChats({
    required List<ChatSession> chats,
    required Map<String, Map<String, List<String>>> links,
    required Directory payloadDir,
    Function(String)? onProgress,
  }) async {
    if (_chatRepo == null) {
      print('ARCX Export V2: No ChatRepo available, skipping chat export');
      return 0;
    }
    
    final chatsDir = Directory(path.join(payloadDir.path, 'Chats'));
    await chatsDir.create(recursive: true);
    
    int exported = 0;
    
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
        'messages': messages.map((msg) => {
          'id': msg.id,
          'role': msg.role,
          'content': msg.textContent,
          'created_at': msg.createdAt.toUtc().toIso8601String(),
          if (msg.contentParts != null) 'content_parts': msg.contentParts!.map((p) => p.toJson()).toList(),
          if (msg.metadata != null) 'metadata': msg.metadata,
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
    return exported;
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
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final arcxFileName = 'export_$timestamp.arcx';
    final arcxPath = path.join(outputDir.path, arcxFileName);
    
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
    
    await File(arcxPath).writeAsBytes(finalZipBytes);
    
    print('ARCX Export V2: ✓ Created ARCX archive: $arcxPath');
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


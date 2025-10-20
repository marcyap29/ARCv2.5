import 'dart:io';
import 'dart:typed_data';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/prism/mcp/zip/mcp_zip_reader.dart';
import 'package:my_app/prism/mcp/media_resolver.dart';
import 'package:my_app/prism/mcp/models/journal_manifest.dart';
import 'package:my_app/arc/core/journal_repository.dart';

/// Content-addressed media import service
class ContentAddressedImportService {
  final String _journalPath;
  final List<String> _mediaPackPaths;
  final JournalRepository _journalRepository;
  late final MediaResolver _mediaResolver;

  ContentAddressedImportService({
    required String journalPath,
    required List<String> mediaPackPaths,
    required JournalRepository journalRepository,
  }) : _journalPath = journalPath,
       _mediaPackPaths = mediaPackPaths,
       _journalRepository = journalRepository {
    _mediaResolver = MediaResolver(
      journalPath: _journalPath,
      mediaPackPaths: _mediaPackPaths,
    );
  }

  /// Import journal with content-addressed media
  Future<ContentAddressedImportResult> importJournal() async {
    try {
      // Read journal ZIP
      final journalReader = await McpZipReader.fromFile(_journalPath);
      final manifest = journalReader.readJournalManifest();
      
      if (manifest == null) {
        return ContentAddressedImportResult(
          success: false,
          error: 'Could not read journal manifest',
          importedEntries: 0,
          importedMedia: 0,
        );
      }

      // Build media resolver cache
      await _mediaResolver.buildCache();

      // Get list of journal entries
      final entryIds = journalReader.listJournalEntries();
      final importedEntries = <JournalEntry>[];
      int totalMedia = 0;

      for (final entryId in entryIds) {
        try {
          final entryData = journalReader.readJournalEntry(entryId);
          if (entryData != null) {
            final journalEntry = await _convertToJournalEntry(entryData, journalReader);
            if (journalEntry != null) {
              // Save to repository
              await _journalRepository.createJournalEntry(journalEntry);
              importedEntries.add(journalEntry);
              totalMedia += journalEntry.media.length;
            }
          }
        } catch (e) {
          print('ContentAddressedImportService: Error importing entry $entryId: $e');
        }
      }

      return ContentAddressedImportResult(
        success: true,
        importedEntries: importedEntries.length,
        importedMedia: totalMedia,
        journalManifest: manifest,
      );
    } catch (e) {
      return ContentAddressedImportResult(
        success: false,
        error: e.toString(),
        importedEntries: 0,
        importedMedia: 0,
      );
    }
  }

  /// Convert entry data to JournalEntry with resolved media
  Future<JournalEntry?> _convertToJournalEntry(
    Map<String, dynamic> entryData,
    McpZipReader journalReader,
  ) async {
    try {
      final mediaList = <MediaItem>[];
      final mediaData = entryData['media'] as List<dynamic>? ?? [];

      for (final mediaItemData in mediaData) {
        if (mediaItemData is Map<String, dynamic>) {
          final mediaItem = await _convertMediaItem(mediaItemData, journalReader);
          if (mediaItem != null) {
            mediaList.add(mediaItem);
          }
        }
      }

      return JournalEntry(
        id: entryData['id'] as String,
        title: entryData['content'] as String? ?? '',
        content: entryData['content'] as String? ?? '',
        emotion: entryData['emotion'] as String?,
        emotionReason: entryData['emotionReason'] as String?,
        phase: entryData['phase'] as String?,
        createdAt: DateTime.parse(entryData['timestamp'] as String),
        updatedAt: DateTime.parse(entryData['timestamp'] as String),
        tags: [],
        mood: entryData['emotion'] as String? ?? '',
        media: mediaList,
        metadata: Map<String, dynamic>.from(entryData['metadata'] ?? {}),
      );
    } catch (e) {
      print('ContentAddressedImportService: Error converting entry: $e');
      return null;
    }
  }

  /// Convert media item data to MediaItem with resolved content
  Future<MediaItem?> _convertMediaItem(
    Map<String, dynamic> mediaData,
    McpZipReader journalReader,
  ) async {
    try {
      final sha = mediaData['sha256'] as String?;
      final kind = mediaData['kind'] as String? ?? 'photo';
      final fullRef = mediaData['fullRef'] as String?;
      final thumbUri = mediaData['thumbUri'] as String?;
      final createdAt = DateTime.parse(mediaData['createdAt'] as String);

      if (sha == null) {
        print('ContentAddressedImportService: Media item missing SHA-256');
        return null;
      }

      // Try to resolve full image first
      Uint8List? fullImageBytes;
      String? fullImagePath;

      if (fullRef != null && fullRef.startsWith('mcp://photo/')) {
        fullImageBytes = await _mediaResolver.loadFullImage(sha);
        if (fullImageBytes != null) {
          // Save full image to temporary file
          final tempDir = Directory.systemTemp;
          final tempFile = File('${tempDir.path}/$sha.jpg');
          await tempFile.writeAsBytes(fullImageBytes);
          fullImagePath = tempFile.path;
        }
      }

      // Fallback to thumbnail if full image not available
      if (fullImageBytes == null && thumbUri != null) {
        final thumbnailBytes = await _mediaResolver.loadThumbnail(sha);
        if (thumbnailBytes != null) {
          // Save thumbnail to temporary file
          final tempDir = Directory.systemTemp;
          final tempFile = File('${tempDir.path}/${sha}_thumb.jpg');
          await tempFile.writeAsBytes(thumbnailBytes);
          fullImagePath = tempFile.path;
        }
      }

      if (fullImagePath == null) {
        print('ContentAddressedImportService: Could not resolve media for SHA $sha');
        return null;
      }

      return MediaItem(
        id: mediaData['id'] as String,
        uri: fullImagePath,
        type: MediaType.image, // Assume image for now
        createdAt: createdAt,
        altText: mediaData['altText'] as String?,
        ocrText: mediaData['ocrText'] as String?,
        analysisData: Map<String, dynamic>.from(mediaData['analysisData'] ?? {}),
      );
    } catch (e) {
      print('ContentAddressedImportService: Error converting media item: $e');
      return null;
    }
  }

  /// Add a media pack to the resolver
  void addMediaPack(String packPath) {
    _mediaResolver.addMediaPack(packPath);
  }

  /// Remove a media pack from the resolver
  void removeMediaPack(String packPath) {
    _mediaResolver.removeMediaPack(packPath);
  }

  /// Get available media packs
  List<String> get availableMediaPacks => _mediaResolver.availablePacks;

  /// Get resolver cache statistics
  Map<String, dynamic> get cacheStats => _mediaResolver.cacheStats;
}

/// Result of content-addressed import
class ContentAddressedImportResult {
  final bool success;
  final String? error;
  final int importedEntries;
  final int importedMedia;
  final JournalManifest? journalManifest;

  const ContentAddressedImportResult({
    required this.success,
    this.error,
    required this.importedEntries,
    required this.importedMedia,
    this.journalManifest,
  });
}

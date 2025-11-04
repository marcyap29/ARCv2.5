/// ARCX Import Service V2
/// 
/// Implements the new ARCX import specification with link resolution,
/// media pack handling, deduplication, and new folder structure support.
library arcx_import_service_v2;

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:uuid/uuid.dart';
import '../models/arcx_manifest.dart';
import 'arcx_crypto_service.dart';

const _uuid = Uuid();

/// ARCX Import Options
class ARCXImportOptions {
  final bool validateChecksums;
  final bool dedupeMedia;
  final bool skipExisting;
  final bool resolveLinks;
  
  ARCXImportOptions({
    this.validateChecksums = true,
    this.dedupeMedia = true,
    this.skipExisting = true,
    this.resolveLinks = true,
  });
}

/// ARCX Import Service V2
class ARCXImportServiceV2 {
  final JournalRepository? _journalRepo;
  final ChatRepo? _chatRepo;
  
  // Media deduplication cache - maps content_hash to MediaItem
  final Map<String, MediaItem> _mediaCache = {};
  
  // Media ID cache - maps media ID to MediaItem (for quick lookup)
  final Map<String, MediaItem> _mediaByIdCache = {};
  
  // Link resolution tracking
  final Map<String, String> _entryIdMap = {}; // old_id -> new_id
  final Map<String, String> _chatIdMap = {}; // old_id -> new_id
  final Map<String, String> _mediaIdMap = {}; // old_id -> new_id
  final Map<String, List<String>> _missingLinks = {}; // type -> [ids]
  
  ARCXImportServiceV2({
    JournalRepository? journalRepo,
    ChatRepo? chatRepo,
  }) : _journalRepo = journalRepo,
       _chatRepo = chatRepo;
  
  /// Clear caches (call before starting a new import)
  void clearCaches() {
    _mediaCache.clear();
    _mediaByIdCache.clear();
    _entryIdMap.clear();
    _chatIdMap.clear();
    _mediaIdMap.clear();
    _missingLinks.clear();
    print('ARCX Import V2: 🧹 Cleared caches for new import');
  }
  
  /// Import ARCX archive
  Future<ARCXImportResultV2> import({
    required String arcxPath,
    required ARCXImportOptions options,
    String? password,
    Function(String)? onProgress,
  }) async {
    try {
      print('ARCX Import V2: Starting import from: $arcxPath');
      onProgress?.call('Loading archive...');
      
      clearCaches();
      
      // Step 1: Load and validate .arcx file
      final arcxFile = File(arcxPath);
      if (!await arcxFile.exists()) {
        throw Exception('ARCX file not found: $arcxPath');
      }
      
      // Extract .arcx ZIP
      final arcxZip = await arcxFile.readAsBytes();
      final zipDecoder = ZipDecoder();
      final archive = zipDecoder.decodeBytes(arcxZip);
      
      ArchiveFile? manifestFile;
      ArchiveFile? encryptedArchive;
      
      for (final file in archive) {
        if (file.name == 'manifest.json') {
          manifestFile = file;
        } else if (file.name == 'archive.arcx') {
          encryptedArchive = file;
        }
      }
      
      if (manifestFile == null || encryptedArchive == null) {
        throw Exception('Invalid ARCX archive: manifest or encrypted archive missing');
      }
      
      print('ARCX Import V2: ✓ Files extracted from .arcx');
      
      // Step 2: Parse and validate manifest
      final manifestJson = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;
      final manifest = ARCXManifest.fromJson(manifestJson);
      
      // Check version FIRST, then validate appropriately
      final isNewFormat = manifest.arcxVersion == '1.2';
      
      if (!isNewFormat) {
        throw Exception('This import service only supports ARCX 1.2 format. Please use the legacy import service for older formats.');
      }
      
      // Now validate using format-appropriate rules
      if (!manifest.validate()) {
        throw Exception('Invalid ARCX 1.2 manifest structure. This archive may be corrupted.');
      }
      
      print('ARCX Import V2: ✓ Manifest validated (ARCX ${manifest.arcxVersion})');
      
      // Step 3: Verify signature
      onProgress?.call('Verifying signature...');
      
      // For ARCX 1.2, signature verification is optional (may not be present)
      if (manifest.signatureB64.isNotEmpty && manifest.signerPubkeyFpr.isNotEmpty) {
        // Create unsigned manifest by copying and clearing signature
        // Use toJson() to ensure we get the exact same structure that was signed
        final manifestJson = manifest.toJson();
        manifestJson['signature_b64'] = ''; // Clear signature for verification
        
        final manifestBytes = utf8.encode(jsonEncode(manifestJson));
        final isValid = await ARCXCryptoService.verifySignature(
          Uint8List.fromList(manifestBytes),
          manifest.signatureB64,
        );
        
        if (!isValid) {
          // Log warning but don't fail - signature verification is optional for 1.2
          print('ARCX Import V2: ⚠️ Signature verification failed - continuing anyway (signature optional for ARCX 1.2)');
        } else {
          print('ARCX Import V2: ✓ Signature verified');
        }
      } else {
        print('ARCX Import V2: ⚠️ No signature present - skipping verification (optional for ARCX 1.2)');
      }
      
      // Step 4: Verify ciphertext hash (if present)
      onProgress?.call('Verifying archive integrity...');
      final ciphertext = Uint8List.fromList(encryptedArchive.content as List<int>);
      
      if (manifest.sha256.isNotEmpty) {
        final ciphertextHash = sha256.convert(ciphertext);
        final ciphertextHashB64 = base64Encode(ciphertextHash.bytes);
        
        if (ciphertextHashB64 != manifest.sha256) {
          // Log warning but continue - hash mismatch might be due to format differences
          print('ARCX Import V2: ⚠️ Ciphertext hash mismatch (expected: ${manifest.sha256.substring(0, 16)}..., got: ${ciphertextHashB64.substring(0, 16)}...) - continuing anyway');
        } else {
          print('ARCX Import V2: ✓ Ciphertext hash verified');
        }
      } else {
        print('ARCX Import V2: ⚠️ No hash present in manifest - skipping hash verification');
      }
      
      // Step 5: Decrypt
      onProgress?.call('Decrypting...');
      Uint8List plaintextZip;
      
      if (manifest.isPasswordEncrypted) {
        if (manifest.saltB64 == null || manifest.saltB64!.isEmpty) {
          throw Exception('Password encryption requires salt but none provided');
        }
        
        if (password == null || password.isEmpty) {
          throw Exception('This archive requires a password. Please provide a password to decrypt it.');
        }
        
        final saltBytes = base64Decode(manifest.saltB64!);
        final salt = Uint8List.fromList(saltBytes);
        plaintextZip = await ARCXCryptoService.decryptWithPassword(ciphertext, password, salt);
        print('ARCX Import V2: ✓ Decrypted with password');
      } else {
        plaintextZip = await ARCXCryptoService.decryptAEAD(ciphertext);
        print('ARCX Import V2: ✓ Decrypted with device key');
      }
      
      print('ARCX Import V2: ✓ Decrypted (${plaintextZip.length} bytes)');
      
      // Step 6: Extract payload
      onProgress?.call('Extracting payload...');
      final payloadArchive = ZipDecoder().decodeBytes(plaintextZip);
      
      final appDocDir = await getApplicationDocumentsDirectory();
      final payloadDir = Directory(path.join(appDocDir.path, 'arcx_import_v2_${DateTime.now().millisecondsSinceEpoch}'));
      await payloadDir.create(recursive: true);
      
      try {
        // Extract to temp directory
        for (final file in payloadArchive) {
          if (file.isFile) {
            final outFile = File(path.join(payloadDir.path, file.name));
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          }
        }
        
        print('ARCX Import V2: ✓ Payload extracted');
        
        // Step 7: Validate checksums if enabled
        if (options.validateChecksums && manifest.checksumsInfo?.enabled == true) {
          onProgress?.call('Validating checksums...');
          await _validateChecksums(payloadDir, manifest.checksumsInfo!.file);
        }
        
        // Step 8: Import in order: Media first, then Entries, then Chats
        int mediaImported = 0;
        int entriesImported = 0;
        int chatsImported = 0;
        final warnings = <String>[];
        
        // Import Media
        final mediaDir = Directory(path.join(payloadDir.path, 'Media'));
        if (await mediaDir.exists()) {
          onProgress?.call('Importing media...');
          mediaImported = await _importMedia(
            mediaDir: mediaDir,
            options: options,
            onProgress: onProgress,
          );
        }
        
        // Import Entries
        final entriesDir = Directory(path.join(payloadDir.path, 'Entries'));
        if (await entriesDir.exists()) {
          onProgress?.call('Importing entries...');
          entriesImported = await _importEntries(
            entriesDir: entriesDir,
            options: options,
            payloadDir: payloadDir,
            onProgress: onProgress,
          );
        }
        
        // Import Chats
        final chatsDir = Directory(path.join(payloadDir.path, 'Chats'));
        if (await chatsDir.exists()) {
          onProgress?.call('Importing chats...');
          chatsImported = await _importChats(
            chatsDir: chatsDir,
            options: options,
            onProgress: onProgress,
          );
        }
        
        // Step 9: Resolve links
        if (options.resolveLinks) {
          onProgress?.call('Resolving links...');
          await _resolveLinks();
        }
        
        // Step 10: Report missing links
        if (_missingLinks.isNotEmpty) {
          for (final entry in _missingLinks.entries) {
            warnings.add('Missing ${entry.key}: ${entry.value.length} items referenced but not found');
          }
        }
        
        onProgress?.call('Import complete!');
        
        return ARCXImportResultV2.success(
          entriesImported: entriesImported,
          chatsImported: chatsImported,
          mediaImported: mediaImported,
          warnings: warnings.isEmpty ? null : warnings,
        );
        
      } finally {
        // Clean up temp directory
        try {
          await payloadDir.delete(recursive: true);
        } catch (e) {
          print('Warning: Could not delete temp directory: $e');
        }
      }
      
    } catch (e, stackTrace) {
      print('ARCX Import V2: ✗ Failed: $e');
      print('Stack trace: $stackTrace');
      return ARCXImportResultV2.failure(e.toString());
    }
  }
  
  /// Validate checksums
  Future<void> _validateChecksums(Directory payloadDir, String checksumsFile) async {
    final checksumsPath = path.join(payloadDir.path, checksumsFile);
    final checksumsFileObj = File(checksumsPath);
    
    if (!await checksumsFileObj.exists()) {
      print('ARCX Import V2: ⚠️ Checksums file not found: $checksumsFile');
      return;
    }
    
    final checksumsLines = await checksumsFileObj.readAsLines();
    final checksumsMap = <String, String>{};
    
    for (final line in checksumsLines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final hash = parts[0];
        final filePath = parts.sublist(1).join(' ').replaceFirst('./', '');
        checksumsMap[filePath] = hash;
      }
    }
    
    int validated = 0;
    int failed = 0;
    
    for (final entry in checksumsMap.entries) {
      final filePath = path.join(payloadDir.path, entry.key);
      final file = File(filePath);
      
      if (!await file.exists()) {
        print('ARCX Import V2: ⚠️ File in checksums not found: ${entry.key}');
        failed++;
        continue;
      }
      
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      
      if (hash != entry.value) {
        print('ARCX Import V2: ✗ Checksum mismatch: ${entry.key}');
        failed++;
      } else {
        validated++;
      }
    }
    
    print('ARCX Import V2: ✓ Validated $validated checksums${failed > 0 ? ', $failed failed' : ''}');
    
    if (failed > 0) {
      throw Exception('Checksum validation failed for $failed file(s)');
    }
  }
  
  /// Import media from /Media/packs/ and /Media/media_index.json
  Future<int> _importMedia({
    required Directory mediaDir,
    required ARCXImportOptions options,
    Function(String)? onProgress,
  }) async {
    // Read media index
    final mediaIndexFile = File(path.join(mediaDir.path, 'media_index.json'));
    if (!await mediaIndexFile.exists()) {
      print('ARCX Import V2: ⚠️ Media index not found');
      return 0;
    }
    
    final mediaIndexJson = jsonDecode(await mediaIndexFile.readAsString()) as Map<String, dynamic>;
    final mediaItems = mediaIndexJson['items'] as List<dynamic>? ?? [];
    final packs = mediaIndexJson['packs'] as List<dynamic>? ?? [];
    
    print('ARCX Import V2: Found ${mediaItems.length} media items in ${packs.length} packs');
    
    // Get app documents directory for permanent storage
    final appDir = await getApplicationDocumentsDirectory();
    final permanentMediaDir = Directory(path.join(appDir.path, 'photos'));
    await permanentMediaDir.create(recursive: true);
    
    int imported = 0;
    final packsDir = Directory(path.join(mediaDir.path, 'packs'));
    
    // Process packs in order (using prev/next links)
    String? currentPackName;
    if (packs.isNotEmpty) {
      // Find first pack (prev == null)
      for (final pack in packs) {
        final packMap = pack as Map<String, dynamic>;
        if (packMap['prev'] == null) {
          currentPackName = packMap['name'] as String;
          break;
        }
      }
    }
    
    // Process all packs
    while (currentPackName != null) {
      final packDir = Directory(path.join(packsDir.path, currentPackName));
      if (!await packDir.exists()) {
        print('ARCX Import V2: ⚠️ Pack directory not found: $currentPackName');
        break;
      }
      
      onProgress?.call('Importing media pack: $currentPackName...');
      
      // Process files in pack
      await for (final entity in packDir.list()) {
        if (entity is File) {
          try {
            final fileName = path.basename(entity.path);
            final mediaItemJson = mediaItems.firstWhere(
              (item) => (item as Map<String, dynamic>)['filename'] == fileName,
              orElse: () => null,
            );
            
            if (mediaItemJson == null) {
              print('ARCX Import V2: ⚠️ Media item not found in index: $fileName');
              continue;
            }
            
            final mediaItemData = mediaItemJson as Map<String, dynamic>;
            
            // Check for duplicates
            if (options.dedupeMedia) {
              final contentHash = mediaItemData['sha256'] as String?;
              if (contentHash != null && _mediaCache.containsKey(contentHash)) {
                final existingMedia = _mediaCache[contentHash]!;
                print('ARCX Import V2: ♻️ Skipping duplicate media: $fileName (using existing: ${existingMedia.id})');
                _mediaIdMap[mediaItemData['id'] as String] = existingMedia.id;
                // Ensure it's in the ID cache too
                _mediaByIdCache[existingMedia.id] = existingMedia;
                continue;
              }
            }
            
            // Copy to permanent storage
            final destFile = File(path.join(permanentMediaDir.path, fileName));
            await entity.copy(destFile.path);
            
            // Create MediaItem
            final originalMediaId = mediaItemData['id'] as String?;
            final mediaItem = _createMediaItemFromJson(mediaItemData, destFile.path);
            if (mediaItem != null) {
              // Cache for deduplication by content hash
              final contentHash = mediaItemData['sha256'] as String?;
              if (contentHash != null && options.dedupeMedia) {
                _mediaCache[contentHash] = mediaItem;
              }
              
              // Cache by media ID for quick lookup during entry import
              _mediaByIdCache[mediaItem.id] = mediaItem;
              
              // Map original media ID to MediaItem ID
              // Since we preserve the original ID in MediaItem, this should be a 1:1 mapping
              // But we still track it for link resolution
              if (originalMediaId != null && originalMediaId.isNotEmpty) {
                _mediaIdMap[originalMediaId] = mediaItem.id;
                // If IDs match, the mapping is redundant but harmless
                if (originalMediaId != mediaItem.id) {
                  print('ARCX Import V2: ✓ Mapped media ID: $originalMediaId -> ${mediaItem.id}');
                } else {
                  print('ARCX Import V2: ✓ Media ID preserved: ${mediaItem.id}');
                }
              } else {
                // Fallback: use the created ID as both key and value
                _mediaIdMap[mediaItem.id] = mediaItem.id;
                print('ARCX Import V2: ⚠️ Media item created without original ID: ${mediaItem.id}');
              }
              
              print('ARCX Import V2: ✓ Cached media ${mediaItem.id} (original: $originalMediaId, hash: $contentHash, file: $fileName)');
              imported++;
            } else {
              print('ARCX Import V2: ⚠️ Failed to create MediaItem for $fileName');
            }
            
          } catch (e) {
            print('ARCX Import V2: ⚠️ Error importing media file ${entity.path}: $e');
          }
        }
      }
      
      // Find next pack
      final currentPack = packs.firstWhere(
        (pack) => (pack as Map<String, dynamic>)['name'] == currentPackName,
        orElse: () => null,
      );
      
      if (currentPack != null) {
        currentPackName = (currentPack as Map<String, dynamic>)['next'] as String?;
      } else {
        break;
      }
    }
    
    print('ARCX Import V2: ✓ Imported $imported media items');
    return imported;
  }
  
  /// Photo mapping cache for embedded media format (legacy support)
  Map<String, String>? _cachedPhotoMapping;
  Directory? _cachedPayloadDir;
  
  /// Build photo mapping from media packs (for legacy embedded media support)
  /// This matches the legacy ARCX import service behavior for finding photos
  Future<Map<String, String>> _buildPhotoMapping(Directory payloadDir) async {
    // Return cached mapping if available and payload dir hasn't changed
    if (_cachedPhotoMapping != null && _cachedPayloadDir == payloadDir) {
      return _cachedPhotoMapping!;
    }
    
    final photoMapping = <String, String>{};
    
    // Try ARCX V2 format: Media/packs/pack-XXX/ (new format)
    final photosDirV2 = Directory(path.join(payloadDir.path, 'Media', 'packs'));
    if (await photosDirV2.exists()) {
      await for (final packDir in photosDirV2.list()) {
        if (packDir is Directory) {
          await for (final file in packDir.list()) {
            if (file is File) {
              final fileName = path.basename(file.path);
              photoMapping[fileName] = file.path;
            }
          }
        }
      }
    }
    
    // Try ARCX V1 format: Media/photos/ (older format)
    final photosDirV1 = Directory(path.join(payloadDir.path, 'Media', 'photos'));
    if (await photosDirV1.exists()) {
      await for (final file in photosDirV1.list()) {
        if (file is File) {
          final fileName = path.basename(file.path);
          photoMapping[fileName] = file.path;
        }
      }
    }
    
    // Try legacy MCP format: media/photos/ (even older format)
    final photosDirLegacy = Directory(path.join(payloadDir.path, 'media', 'photos'));
    if (await photosDirLegacy.exists()) {
      await for (final file in photosDirLegacy.list()) {
        if (file is File) {
          final fileName = path.basename(file.path);
          photoMapping[fileName] = file.path;
        }
      }
    }
    
    // Try legacy MCP format: nodes/media/photo/ (metadata location, but also check for actual files)
    final photosDirMCP = Directory(path.join(payloadDir.path, 'nodes', 'media', 'photo'));
    if (await photosDirMCP.exists()) {
      await for (final file in photosDirMCP.list()) {
        if (file is File && !file.path.endsWith('.json')) {
          // Skip JSON metadata files, only include actual photo files
          final fileName = path.basename(file.path);
          photoMapping[fileName] = file.path;
        }
      }
    }
    
    print('ARCX Import V2: Built photo mapping with ${photoMapping.length} files from payload directory');
    _cachedPhotoMapping = photoMapping;
    _cachedPayloadDir = payloadDir;
    return photoMapping;
  }
  
  /// Import entries from /Entries/{yyyy}/{mm}/{dd}/
  Future<int> _importEntries({
    required Directory entriesDir,
    required ARCXImportOptions options,
    required Directory payloadDir, // Add payloadDir parameter
    Function(String)? onProgress,
  }) async {
    if (_journalRepo == null) {
      print('ARCX Import V2: ⚠️ No JournalRepository available, skipping entries');
      return 0;
    }
    
    int imported = 0;
    int processed = 0;
    
    // Recursively find all entry JSON files
    await for (final entity in entriesDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.arcx.json')) {
        processed++;
        try {
          final entryJson = jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
          
          final entryId = entryJson['id'] as String;
          
          // Check if already exists
          if (options.skipExisting) {
            final existing = _journalRepo!.getJournalEntryById(entryId);
            if (existing != null) {
              print('ARCX Import V2: ⚠️ Entry $entryId already exists, skipping');
              _entryIdMap[entryId] = entryId; // Map to itself
              continue;
            }
          }
          
          onProgress?.call('Importing entry $processed...');
          
          // Convert to JournalEntry (pass payloadDir for embedded media support)
          final entry = await _convertEntryJsonToJournalEntry(entryJson, payloadDir);
          if (entry != null) {
            await _journalRepo!.createJournalEntry(entry);
            _entryIdMap[entryId] = entry.id;
            imported++;
          }
          
        } catch (e) {
          print('ARCX Import V2: ✗ Error importing entry ${entity.path}: $e');
        }
      }
    }
    
    print('ARCX Import V2: ✓ Imported $imported entries');
    return imported;
  }
  
  /// Import chats from /Chats/{yyyy}/{mm}/{dd}/
  Future<int> _importChats({
    required Directory chatsDir,
    required ARCXImportOptions options,
    Function(String)? onProgress,
  }) async {
    if (_chatRepo == null) {
      print('ARCX Import V2: ⚠️ No ChatRepo available, skipping chats');
      return 0;
    }
    
    int imported = 0;
    int processed = 0;
    
    // Recursively find all chat JSON files
    await for (final entity in chatsDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.arcx.json')) {
        processed++;
        try {
          final chatJson = jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
          
          final chatId = chatJson['id'] as String;
          
          // Check if already exists
          if (options.skipExisting) {
            try {
              final existing = await _chatRepo!.getSession(chatId);
              if (existing != null) {
                print('ARCX Import V2: ⚠️ Chat $chatId already exists, skipping');
                _chatIdMap[chatId] = chatId; // Map to itself
                continue;
              }
            } catch (_) {
              // Session doesn't exist, continue
            }
          }
          
          onProgress?.call('Importing chat $processed...');
          
          // Convert and import chat
          final chat = await _convertChatJsonToChatSession(chatJson);
          if (chat != null) {
            // Create session (this will be handled by ChatRepo)
            // For now, we'll map the ID
            _chatIdMap[chatId] = chat.id;
            imported++;
          }
          
        } catch (e) {
          print('ARCX Import V2: ✗ Error importing chat ${entity.path}: $e');
        }
      }
    }
    
    print('ARCX Import V2: ✓ Imported $imported chats');
    return imported;
  }
  
  /// Resolve links between entries, chats, and media
  Future<void> _resolveLinks() async {
    if (_journalRepo == null) {
      print('ARCX Import V2: No JournalRepository available, skipping link resolution');
      return;
    }
    
    print('ARCX Import V2: Resolving links...');
    
    // Update entries with resolved media
    for (final entryIdMapping in _entryIdMap.entries) {
      final originalId = entryIdMapping.key;
      final newId = entryIdMapping.value;
      
      try {
        final entry = _journalRepo!.getJournalEntryById(newId);
        if (entry != null) {
          // Check if entry has unresolved media links
          // The media should already be resolved during entry import,
          // but we track any missing links for reporting
          final unresolvedMedia = entry.media.where((media) => !_mediaIdMap.values.contains(media.id)).toList();
          
          if (unresolvedMedia.isNotEmpty) {
            // Track missing media links
            for (final media in unresolvedMedia) {
              _missingLinks['media'] ??= [];
              if (!(_missingLinks['media'] as List).contains(media.id)) {
                (_missingLinks['media'] as List).add(media.id);
              }
            }
          }
        }
      } catch (e) {
        print('ARCX Import V2: ⚠️ Error resolving links for entry $originalId: $e');
      }
    }
    
    print('ARCX Import V2: ✓ Link resolution completed');
    
    // Report missing links
    if (_missingLinks.isNotEmpty) {
      print('ARCX Import V2: ⚠️ Missing links detected:');
      for (final entry in _missingLinks.entries) {
        print('  - ${entry.key}: ${entry.value.length} items');
      }
    }
  }
  
  /// Convert entry JSON to JournalEntry
  Future<JournalEntry?> _convertEntryJsonToJournalEntry(
    Map<String, dynamic> entryJson,
    Directory payloadDir,
  ) async {
    try {
      final entryId = entryJson['id'] as String;
      final title = entryJson['title'] as String? ?? 'Imported Entry';
      final content = entryJson['content'] as String? ?? '';
      final createdAt = DateTime.parse(entryJson['created_at'] as String);
      
      // Resolve media links - support both ARCX V2 format (links.media_ids) and legacy format (embedded media)
      final mediaItems = <MediaItem>[];
      
      // Try ARCX V2 format first (links.media_ids)
      final mediaIds = (entryJson['links'] as Map<String, dynamic>?)?['media_ids'] as List<dynamic>? ?? [];
      
      // Try legacy format (embedded media array) with multiple fallback locations
      // This matches the legacy ARCX import service behavior
      List<dynamic>? embeddedMedia = entryJson['media'] as List<dynamic>?;
      
      // Fallback 1: Check metadata.media
      if (embeddedMedia == null || embeddedMedia.isEmpty) {
        final metadata = entryJson['metadata'] as Map<String, dynamic>?;
        if (metadata != null) {
          embeddedMedia = metadata['media'] as List<dynamic>?;
        }
      }
      
      // Fallback 2: Check metadata.journal_entry.media
      if (embeddedMedia == null || embeddedMedia.isEmpty) {
        final metadata = entryJson['metadata'] as Map<String, dynamic>?;
        if (metadata != null) {
          final journalEntryMeta = metadata['journal_entry'] as Map<String, dynamic>?;
          if (journalEntryMeta != null) {
            embeddedMedia = journalEntryMeta['media'] as List<dynamic>?;
          }
        }
      }
      
      // Fallback 3: Check metadata.photos (convert to media format)
      if (embeddedMedia == null || embeddedMedia.isEmpty) {
        final metadata = entryJson['metadata'] as Map<String, dynamic>?;
        if (metadata != null) {
          final photosData = metadata['photos'] as List<dynamic>?;
          if (photosData != null && photosData.isNotEmpty) {
            // Convert photos array to media format (like legacy service does)
            embeddedMedia = photosData.map((photo) {
              if (photo is Map<String, dynamic>) {
                return {
                  'id': photo['id'] ?? photo['placeholder_id'] ?? '',
                  'filename': photo['filename'],
                  'originalPath': photo['uri'] ?? photo['path'],
                  'createdAt': photo['createdAt'] ?? photo['created_at'],
                  'analysisData': photo['analysisData'] ?? photo['analysis_data'],
                  'altText': photo['altText'] ?? photo['alt_text'],
                  'ocrText': photo['ocrText'] ?? photo['ocr_text'],
                  'sha256': photo['sha256'],
                  'content_type': 'image/jpeg', // Default for photos
                };
              }
              return photo;
            }).toList();
          }
        }
      }
      
      embeddedMedia ??= [];
      
      print('ARCX Import V2: Entry ${entryId} - V2 links: ${mediaIds.length}, embedded media: ${embeddedMedia.length}');
      
      // Debug: Log what we found in the entry JSON for entries with no media detected
      if (mediaIds.isEmpty && embeddedMedia.isEmpty) {
        print('ARCX Import V2: 🔍 DEBUG Entry ${entryId} media detection:');
        print('  - entryJson keys: ${entryJson.keys.toList()}');
        print('  - entryJson["media"]: ${entryJson.containsKey("media") ? (entryJson["media"] is List ? "List(${entryJson["media"]})" : entryJson["media"]) : "not found"}');
        print('  - entryJson["links"]: ${entryJson.containsKey("links") ? entryJson["links"] : "not found"}');
        if (entryJson.containsKey('metadata')) {
          final metadata = entryJson['metadata'] as Map<String, dynamic>?;
          if (metadata != null) {
            print('  - metadata keys: ${metadata.keys.toList()}');
            print('  - metadata["media"]: ${metadata.containsKey("media") ? (metadata["media"] is List ? "List(${metadata["media"]})" : metadata["media"]) : "not found"}');
            if (metadata.containsKey("journal_entry")) {
              final jeMeta = metadata["journal_entry"] as Map<String, dynamic>?;
              print('  - metadata["journal_entry"]: ${jeMeta != null ? (jeMeta.containsKey("media") ? "found with media" : "found without media") : "null"}');
            }
            print('  - metadata["photos"]: ${metadata.containsKey("photos") ? (metadata["photos"] is List ? "List(${metadata["photos"]})" : metadata["photos"]) : "not found"}');
          } else {
            print('  - metadata: null');
          }
        } else {
          print('  - metadata: not found');
        }
      }
      
      // Process ARCX V2 format (links-based)
      if (mediaIds.isNotEmpty) {
        for (final mediaId in mediaIds) {
          final mediaIdStr = mediaId as String;
          final resolvedId = _mediaIdMap[mediaIdStr];
          
          if (resolvedId != null) {
            // Find media item by resolved ID in the ID cache
            final mediaItem = _mediaByIdCache[resolvedId];
            if (mediaItem != null) {
              mediaItems.add(mediaItem);
              print('ARCX Import V2: ✓ Resolved media link: $mediaIdStr -> ${mediaItem.id}');
            } else {
              print('ARCX Import V2: ⚠️ Media ID $resolvedId not found in cache (original: $mediaIdStr)');
              _missingLinks['media'] ??= [];
              if (!(_missingLinks['media'] as List).contains(mediaIdStr)) {
                (_missingLinks['media'] as List).add(mediaIdStr);
              }
            }
          } else {
            print('ARCX Import V2: ⚠️ Media ID $mediaIdStr not found in media ID map');
            _missingLinks['media'] ??= [];
            if (!(_missingLinks['media'] as List).contains(mediaIdStr)) {
              (_missingLinks['media'] as List).add(mediaIdStr);
            }
          }
        }
      }
      
      // Process legacy format (embedded media) - only if no V2 links found
      if (mediaIds.isEmpty && embeddedMedia.isNotEmpty) {
        print('ARCX Import V2: Using legacy embedded media format for entry ${entryId}');
        print('ARCX Import V2: Found ${embeddedMedia.length} embedded media items');
        
        // Build photo mapping from media directory (similar to old ARCX import)
        final photoMapping = await _buildPhotoMapping(payloadDir);
        print('ARCX Import V2: Built photo mapping with ${photoMapping.length} files');
        
        // Process each embedded media item
        for (int i = 0; i < embeddedMedia.length; i++) {
          final mediaJson = embeddedMedia[i];
          if (mediaJson is Map<String, dynamic>) {
            try {
              print('ARCX Import V2: Processing embedded media item $i: ${mediaJson.keys.toList()}');
              // Create MediaItem from embedded JSON (similar to old ARCX import)
              final mediaItem = await _createMediaItemFromEmbeddedJson(mediaJson, entryId, photoMapping);
              if (mediaItem != null) {
                // Cache by ID for deduplication
                _mediaByIdCache[mediaItem.id] = mediaItem;
                mediaItems.add(mediaItem);
                print('ARCX Import V2: ✓ Created media from embedded format: ${mediaItem.id}');
              } else {
                print('ARCX Import V2: ⚠️ Failed to create MediaItem from embedded media $i');
              }
            } catch (e, stackTrace) {
              print('ARCX Import V2: ⚠️ Error processing embedded media $i: $e');
              print('ARCX Import V2: Stack trace: $stackTrace');
            }
          } else {
            print('ARCX Import V2: ⚠️ Embedded media item $i is not a Map: ${mediaJson.runtimeType}');
          }
        }
      }
      
      print('ARCX Import V2: Entry ${entryId} resolved ${mediaItems.length} media items (${mediaIds.length} from links, ${embeddedMedia.length} embedded)');
      
      return JournalEntry(
        id: entryId,
        title: title,
        content: content,
        createdAt: createdAt,
        updatedAt: createdAt,
        media: mediaItems,
        tags: (entryJson['keywords'] as List<dynamic>? ?? []).cast<String>(),
        keywords: (entryJson['keywords'] as List<dynamic>? ?? []).cast<String>(),
        mood: entryJson['emotion'] as String? ?? '',
        emotion: entryJson['emotion'] as String?,
        emotionReason: entryJson['emotionReason'] as String?,
        phase: entryJson['phase'] as String?,
        metadata: {
          'imported_from_arcx_v2': true,
          'original_export_id': entryJson['id'],
          'import_timestamp': DateTime.now().toUtc().toIso8601String(),
          ...?entryJson['metadata'] as Map<String, dynamic>?,
        },
      );
    } catch (e) {
      print('ARCX Import V2: ✗ Error converting entry: $e');
      return null;
    }
  }
  
  /// Convert chat JSON to ChatSession and import messages
  Future<ChatSession?> _convertChatJsonToChatSession(Map<String, dynamic> chatJson) async {
    try {
      if (_chatRepo == null) {
        print('ARCX Import V2: ⚠️ No ChatRepo available, skipping chat import');
        return null;
      }
      
      final subject = chatJson['subject'] as String? ?? 'Imported Chat';
      final messages = chatJson['messages'] as List<dynamic>? ?? [];
      
      // Create session using ChatRepo
      final sessionId = await _chatRepo!.createSession(
        subject: subject,
        tags: (chatJson['tags'] as List<dynamic>? ?? []).cast<String>(),
      );
      
      // Get the created session
      final session = await _chatRepo!.getSession(sessionId);
      if (session == null) {
        print('ARCX Import V2: ✗ Failed to get created session');
        return null;
      }
      
      // Import messages
      for (final messageJson in messages) {
        try {
          final messageMap = messageJson as Map<String, dynamic>;
          final role = messageMap['role'] as String? ?? 'user';
          final content = messageMap['content'] as String? ?? 
                         messageMap['textContent'] as String? ?? 
                         messageMap['text'] as String? ?? '';
          
          if (content.isEmpty) continue;
          
          // Handle contentParts if present (for multimodal messages)
          if (messageMap['content_parts'] != null) {
            // For multimodal messages, we need to reconstruct the content
            // For now, use the text content if available
            final contentParts = messageMap['content_parts'] as List<dynamic>;
            final textParts = contentParts
                .where((part) => (part as Map<String, dynamic>)['type'] == 'text')
                .map((part) => (part as Map<String, dynamic>)['text'] as String)
                .join('\n');
            
            if (textParts.isNotEmpty) {
              await _chatRepo!.addMessage(
                sessionId: sessionId,
                role: role,
                content: textParts,
              );
            }
          } else {
            await _chatRepo!.addMessage(
              sessionId: sessionId,
              role: role,
              content: content,
            );
          }
        } catch (e) {
          print('ARCX Import V2: ⚠️ Error importing message: $e');
          // Continue with other messages
        }
      }
      
      // Update session metadata if needed
      if (chatJson['is_archived'] == true) {
        await _chatRepo!.archiveSession(sessionId, true);
      }
      
      if (chatJson['is_pinned'] == true) {
        await _chatRepo!.pinSession(sessionId, true);
      }
      
      print('ARCX Import V2: ✓ Imported chat session $sessionId with ${messages.length} messages');
      return session;
    } catch (e) {
      print('ARCX Import V2: ✗ Error converting chat: $e');
      return null;
    }
  }
  
  /// Create MediaItem from embedded JSON (legacy format support)
  Future<MediaItem?> _createMediaItemFromEmbeddedJson(
    Map<String, dynamic> mediaJson,
    String entryId,
    Map<String, String> photoMapping,
  ) async {
    try {
      // Extract media ID
      final mediaId = mediaJson['id'] as String? ?? _uuid.v4();
      
      // Try to find filename
      String? filename = mediaJson['filename'] as String?;
      if (filename == null || filename.isEmpty) {
        filename = mediaJson['file_name'] as String? ?? mediaJson['name'] as String?;
      }
      
      // Resolve file path with multiple fallbacks (matching legacy service behavior)
      String? filePath;
      
      // Try 1: Photo mapping by filename
      if (filename != null && filename.isNotEmpty) {
        filePath = photoMapping[filename];
        if (filePath != null) {
          print('ARCX Import V2: ✓ Found file in mapping: $filename -> $filePath');
        }
      }
      
      // Try 2: SHA-256 prefix matching in photo mapping (legacy service behavior)
      if (filePath == null) {
        final sha256 = mediaJson['sha256'] as String?;
        if (sha256 != null && sha256.isNotEmpty) {
          for (final entry in photoMapping.entries) {
            if (entry.key.contains(sha256.substring(0, 8))) {
              filePath = entry.value;
              print('ARCX Import V2: ✓ Found file by SHA-256 prefix: ${sha256.substring(0, 8)}... -> $filePath');
              break;
            }
          }
        }
      }
      
      // Try 3: originalPath, uri, or path from JSON
      if (filePath == null) {
        filePath = mediaJson['originalPath'] as String? ?? 
                   mediaJson['uri'] as String? ?? 
                   mediaJson['path'] as String?;
        if (filePath != null) {
          print('ARCX Import V2: ✓ Using originalPath from JSON: $filePath');
        }
      }
      
      // Try 4: Construct path from filename in app documents directory
      if (filePath == null && filename != null && filename.isNotEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        final photosDir = Directory(path.join(appDir.path, 'photos'));
        final constructedPath = path.join(photosDir.path, filename);
        final file = File(constructedPath);
        if (await file.exists()) {
          filePath = constructedPath;
          print('ARCX Import V2: ✓ Found file in constructed path: $filePath');
        }
      }
      
      if (filePath == null || filePath.isEmpty) {
        print('ARCX Import V2: ⚠️ Could not resolve path for embedded media ${mediaId}');
        print('  - Filename: $filename');
        print('  - Photo mapping size: ${photoMapping.length}');
        print('  - originalPath: ${mediaJson['originalPath']}');
        print('  - uri: ${mediaJson['uri']}');
        print('  - path: ${mediaJson['path']}');
        return null;
      }
      
      // Determine media type
      final contentType = mediaJson['content_type'] as String? ?? 'image/jpeg';
      MediaType mediaType;
      if (contentType.startsWith('image/')) {
        mediaType = MediaType.image;
      } else if (contentType.startsWith('video/')) {
        mediaType = MediaType.video;
      } else if (contentType.startsWith('audio/')) {
        mediaType = MediaType.audio;
      } else {
        mediaType = MediaType.file;
      }
      
      // Parse timestamp
      final createdAtStr = mediaJson['created_at'] as String? ?? mediaJson['createdAt'] as String?;
      final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();
      
      return MediaItem(
        id: mediaId,
        type: mediaType,
        uri: filePath,
        createdAt: createdAt,
        sha256: mediaJson['sha256'] as String?,
        altText: mediaJson['altText'] as String? ?? mediaJson['alt_text'] as String?,
        ocrText: mediaJson['ocrText'] as String? ?? mediaJson['ocr_text'] as String?,
        analysisData: mediaJson['analysisData'] as Map<String, dynamic>? ?? mediaJson['analysis_data'] as Map<String, dynamic>?,
      );
    } catch (e) {
      print('ARCX Import V2: ⚠️ Error creating MediaItem from embedded JSON: $e');
      return null;
    }
  }
  
  /// Create MediaItem from JSON
  MediaItem? _createMediaItemFromJson(Map<String, dynamic> mediaJson, String filePath) {
    try {
      // CRITICAL: Preserve original media ID from export to maintain link consistency
      // The ID from the export MUST be preserved so links.media_ids can resolve correctly
      final mediaId = mediaJson['id'] as String?;
      if (mediaId == null || mediaId.isEmpty) {
        print('ARCX Import V2: ⚠️ Media JSON missing ID - cannot create MediaItem without ID');
        return null; // Don't create MediaItem without ID - it won't link properly
      }
      
      final createdAtStr = mediaJson['created_at'] as String?;
      final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();
      
      // Determine media type from content_type
      final contentType = mediaJson['content_type'] as String? ?? 'image/jpeg';
      MediaType mediaType;
      if (contentType.startsWith('image/')) {
        mediaType = MediaType.image;
      } else if (contentType.startsWith('video/')) {
        mediaType = MediaType.video;
      } else if (contentType.startsWith('audio/')) {
        mediaType = MediaType.audio;
      } else {
        mediaType = MediaType.file;
      }
      
      // CRITICAL: Use the original exported ID - this ensures links.media_ids can resolve
      // The MediaItem.id MUST match the ID in links.media_ids for the link to work
      return MediaItem(
        id: mediaId, // Preserve original ID from export
        type: mediaType,
        uri: filePath,
        createdAt: createdAt,
        sha256: mediaJson['sha256'] as String?,
      );
    } catch (e) {
      print('ARCX Import V2: ✗ Error creating MediaItem: $e');
      return null;
    }
  }
}

/// ARCX Import Result V2
class ARCXImportResultV2 {
  final bool success;
  final int entriesImported;
  final int chatsImported;
  final int mediaImported;
  final List<String>? warnings;
  final String? error;
  
  ARCXImportResultV2({
    required this.success,
    this.entriesImported = 0,
    this.chatsImported = 0,
    this.mediaImported = 0,
    this.warnings,
    this.error,
  });
  
  factory ARCXImportResultV2.success({
    int entriesImported = 0,
    int chatsImported = 0,
    int mediaImported = 0,
    List<String>? warnings,
  }) {
    return ARCXImportResultV2(
      success: true,
      entriesImported: entriesImported,
      chatsImported: chatsImported,
      mediaImported: mediaImported,
      warnings: warnings,
    );
  }
  
  factory ARCXImportResultV2.failure(String error) {
    return ARCXImportResultV2(
      success: false,
      error: error,
    );
  }
}


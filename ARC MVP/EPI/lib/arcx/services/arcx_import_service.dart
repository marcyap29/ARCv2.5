/// ARCX Import Service
/// 
/// Orchestrates the import of secure .arcx archives.
library arcx_import_service;

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
import 'package:my_app/lumara/chat/chat_repo.dart';
import 'package:my_app/core/mcp/import/enhanced_mcp_import_service.dart';
import 'package:my_app/core/mcp/import/mcp_import_service.dart';
import 'arcx_crypto_service.dart';
import '../models/arcx_manifest.dart';
import '../models/arcx_result.dart';

class ARCXImportService {
  final JournalRepository? _journalRepo;
  final ChatRepo? _chatRepo;
  
  // Media deduplication cache - maps URI to MediaItem to prevent duplicates
  final Map<String, MediaItem> _mediaCache = {};
  
  ARCXImportService({
    JournalRepository? journalRepo,
    ChatRepo? chatRepo,
  }) : _journalRepo = journalRepo,
       _chatRepo = chatRepo;
  
  /// Clear the media cache (call before starting a new import)
  void clearMediaCache() {
    _mediaCache.clear();
    print('ARCX Import: 🧹 Cleared media cache for new import');
  }
  
  /// Import secure .arcx archive
  /// 
  /// Process:
  /// 1. Load .arcx and .manifest.json
  /// 2. Verify Ed25519 signature
  /// 3. Verify ciphertext SHA-256
  /// 4. Decrypt with AES-256-GCM (device-based or password-based)
  /// 5. Extract and validate payload/ structure
  /// 6. Verify MCP manifest hash
  /// 7. Convert to JournalEntry objects
  /// 8. Merge into JournalRepository
  Future<ARCXImportResult> importSecure({
    required String arcxPath,
    String? manifestPath,
    bool dryRun = false,
    String? password, // Required if archive uses password-based encryption
  }) async {
    try {
      print('ARCX Import: Starting secure import from: $arcxPath');
      
      // Step 1: Load .arcx file
      final arcxFile = File(arcxPath);
      if (!await arcxFile.exists()) {
        throw Exception('ARCX file not found: $arcxPath');
      }
      
      // Extract the .arcx ZIP to get manifest and encrypted archive
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
      
      if (manifestFile == null) {
        throw Exception('Manifest not found in .arcx archive');
      }
      
      if (encryptedArchive == null) {
        throw Exception('Encrypted archive not found in .arcx archive');
      }
      
      print('ARCX Import: ✓ Files extracted from .arcx');
      
      // Step 2: Parse and validate manifest
      final manifestJson = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;
      final manifest = ARCXManifest.fromJson(manifestJson);
      
      if (!manifest.validate()) {
        throw Exception('Invalid manifest structure');
      }
      
      print('ARCX Import: ✓ Manifest validated');
      
      // Step 3: Verify signature
      print('ARCX Import: Step 1 - Verifying signature...');
      
      // Need to rebuild manifest without signature for verification
      final unsignedManifest = ARCXManifest(
        version: manifest.version,
        algo: manifest.algo,
        kdf: manifest.kdf,
        kdfParams: manifest.kdfParams,
        sha256: manifest.sha256,
        signerPubkeyFpr: manifest.signerPubkeyFpr,
        signatureB64: '',
        payloadMeta: manifest.payloadMeta,
        mcpManifestSha256: manifest.mcpManifestSha256,
        exportedAt: manifest.exportedAt,
        appVersion: manifest.appVersion,
        redactionReport: manifest.redactionReport,
        isPasswordEncrypted: manifest.isPasswordEncrypted,
        saltB64: manifest.saltB64,
      );
      
      final manifestBytes = utf8.encode(jsonEncode(unsignedManifest.toJson()));
      final isValid = await ARCXCryptoService.verifySignature(
        Uint8List.fromList(manifestBytes),
        manifest.signatureB64,
      );
      
      if (!isValid) {
        throw Exception('Signature verification failed - archive may be tampered');
      }
      
      print('ARCX Import: ✓ Signature verified');
      
      // Step 4: Get encrypted archive data
      print('ARCX Import: Step 2 - Loading encrypted data...');
      final ciphertext = Uint8List.fromList(encryptedArchive.content as List<int>);
      final ciphertextHash = sha256.convert(ciphertext).bytes;
      final ciphertextHashB64 = base64Encode(ciphertextHash);
      
      if (ciphertextHashB64 != manifest.sha256) {
        throw Exception('Ciphertext hash mismatch - file may be corrupted');
      }
      
      print('ARCX Import: ✓ Ciphertext hash verified');
      
      // Step 5: Decrypt
      print('ARCX Import: Step 3 - Decrypting...');
      Uint8List plaintextZip;
      
      if (manifest.isPasswordEncrypted) {
        // Password-based decryption
        if (manifest.saltB64 == null || manifest.saltB64!.isEmpty) {
          throw Exception('Password encryption requires salt but none provided');
        }
        
        if (password == null || password.isEmpty) {
          throw Exception('This archive requires a password. Please provide a password to decrypt it.');
        }
        
        final saltBytes = base64Decode(manifest.saltB64!);
        
        print('ARCX Import: SaltB64 length: ${manifest.saltB64!.length} chars');
        print('ARCX Import: Decoded salt length: ${saltBytes.length} bytes');
        
        // Validate salt is exactly 32 bytes
        if (saltBytes.length != 32) {
          throw Exception('Invalid salt length: expected 32 bytes, got ${saltBytes.length}. SaltB64: "${manifest.saltB64}". This archive may be corrupted or was created with a different version.');
        }
        
        final salt = Uint8List.fromList(saltBytes);
        print('ARCX Import: Salt (hex): ${salt.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
        print('ARCX Import: Ciphertext length: ${ciphertext.length} bytes');
        plaintextZip = await ARCXCryptoService.decryptWithPassword(ciphertext, password, salt);
        print('ARCX Import: ✓ Decrypted with password');
      } else {
        // Device-based decryption
        plaintextZip = await ARCXCryptoService.decryptAEAD(ciphertext);
        print('ARCX Import: ✓ Decrypted with device key');
      }
      
      print('ARCX Import: ✓ Decrypted (${plaintextZip.length} bytes)');
      
      // Step 6: Extract and validate payload structure
      print('ARCX Import: Step 4 - Extracting payload...');
      final payloadArchive = ZipDecoder().decodeBytes(plaintextZip);
      
      final payloadDir = Directory.systemTemp.createTempSync('arcx_import_');
      
      try {
        // Extract to temp directory
        for (final file in payloadArchive) {
          if (file.isFile) {
            final outFile = File(path.join(payloadDir.path, file.name));
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          }
        }
        
        print('ARCX Import: ✓ Payload extracted');
        
        // Validate structure
        final payloadManifestFile = File(path.join(payloadDir.path, 'manifest.mcp.json'));
        if (!await payloadManifestFile.exists()) {
          throw Exception('Invalid payload structure: manifest.mcp.json not found');
        }
        
        // Step 7: Verify MCP manifest hash
        final mcpManifestData = await payloadManifestFile.readAsBytes();
        final mcpManifestHash = sha256.convert(mcpManifestData).bytes;
        final mcpManifestHashB64 = base64Encode(mcpManifestHash);
        
        if (mcpManifestHashB64 != manifest.mcpManifestSha256) {
          throw Exception('MCP manifest hash mismatch - payload may be corrupted');
        }
        
        print('ARCX Import: ✓ MCP manifest hash verified');
        
        // Step 8: Copy photos to permanent storage and create photo mapping
        final photosDir = Directory(path.join(payloadDir.path, 'media', 'photos'));
        final photoMapping = <String, String>{};
        
        if (await photosDir.exists()) {
          // Copy photos to app's permanent storage
          final appDir = await getApplicationDocumentsDirectory();
          final permanentPhotosDir = Directory('${appDir.path}/photos');
          await permanentPhotosDir.create(recursive: true);
          
          final photoFiles = await photosDir.list().toList();
          int photosCopied = 0;
          for (final file in photoFiles) {
            if (file is File && (file.path.endsWith('.jpg') || file.path.endsWith('.jpeg') || file.path.endsWith('.png'))) {
              final fileName = path.basename(file.path);
              final destFile = File(path.join(permanentPhotosDir.path, fileName));
              await file.copy(destFile.path);
              // Map filename to permanent path
              photoMapping[fileName] = destFile.path;
              photosCopied++;
            }
          }
          
          print('ARCX Import: Copied $photosCopied photos to permanent storage (${permanentPhotosDir.path})');
          print('ARCX Import: Created photo mapping with ${photoMapping.length} entries');
        }
        
        // Step 8.5: Load photo metadata files for enhanced matching
        final photoMetadataMap = await _loadPhotoMetadata(payloadDir);
        if (photoMetadataMap.isNotEmpty) {
          print('ARCX Import: Loaded ${photoMetadataMap.length} photo metadata files');
        }
        
        // Clear media cache for this import
        clearMediaCache();
        
        // Step 9: Read and convert journal entries
        final journalDir = Directory(path.join(payloadDir.path, 'journal'));
        if (!await journalDir.exists()) {
          throw Exception('Invalid payload structure: journal/ directory not found');
        }
        
        final journalFiles = await journalDir
            .list()
            .where((f) => f.path.endsWith('.json'))
            .cast<File>()
            .toList();
        
        print('ARCX Import: Step 5 - Converting ${journalFiles.length} journal entries...');
        print('ARCX Import: Journal repo available: ${_journalRepo != null}');
        print('ARCX Import: Photo mapping contains ${photoMapping.length} photos');
        
        int entriesImported = 0;
        int totalEntriesFound = 0;
        int entriesWithMedia = 0;
        final warnings = <String>[];
        
        for (final file in journalFiles) {
          totalEntriesFound++;
          try {
            final nodeJson = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
            
            final entry = await _convertMCPNodeToJournalEntry(
              nodeJson, 
              photoMapping, 
              photoMetadataMap,
            );
            
            if (entry == null) {
              print('ARCX Import: ✗ Skipped entry ${path.basename(file.path)} - conversion returned null');
              warnings.add('Failed to convert entry ${path.basename(file.path)}');
              continue;
            }
            
            // Track entries with media
            if (entry.media.isNotEmpty) {
              entriesWithMedia++;
            }
            
            if (!dryRun && _journalRepo != null) {
              try {
              await _journalRepo!.createJournalEntry(entry);
                entriesImported++;
                print('ARCX Import: ✓ Saved entry ${entry.id}: ${entry.title} (${entry.media.length} media items)');
              } catch (e, stackTrace) {
                print('ARCX Import: ✗ Failed to save entry ${entry.id} to repository: $e');
                print('   Stack trace: $stackTrace');
                warnings.add('Failed to save entry ${entry.id}: $e');
                // Continue processing other entries even if this one fails
              }
            } else {
              print('ARCX Import: ✗ Skipped entry ${entry.id} (dryRun=$dryRun, repo=${_journalRepo != null})');
              entriesImported++; // Count as imported even in dry run
            }
          } catch (e, stackTrace) {
            print('ARCX Import: ✗ Failed to import entry ${path.basename(file.path)}: $e');
            print('   Stack trace: $stackTrace');
            warnings.add('Failed to import entry ${path.basename(file.path)}: $e');
            // Continue processing other entries even if this one fails
          }
        }
        
        // Log import summary
        print('ARCX Import: 📊 Import Summary:');
        print('   Total entries found: $totalEntriesFound');
        print('   Entries with media: $entriesWithMedia');
        print('   Entries successfully imported: $entriesImported');
        
        if (entriesImported < totalEntriesFound) {
          print('ARCX Import: ⚠️ WARNING: ${totalEntriesFound - entriesImported} entries were NOT imported!');
        }
        
        // Log media cache statistics
        print('ARCX Import: 📊 Media Cache Statistics:');
        print('   Total unique media items cached: ${_mediaCache.length}');
        final mediaByType = <String, int>{};
        for (final item in _mediaCache.values) {
          mediaByType[item.type.name] = (mediaByType[item.type.name] ?? 0) + 1;
        }
        for (final entry in mediaByType.entries) {
          print('   - ${entry.key}: ${entry.value}');
        }
        
        // Step 10: Import health streams if they exist
        final streamsHealthDir = Directory(path.join(payloadDir.path, 'streams', 'health'));
        int healthStreamFilesImported = 0;
        
        if (await streamsHealthDir.exists()) {
          print('ARCX Import: Step 6 - Importing health streams...');
          final appDir = await getApplicationDocumentsDirectory();
          final destHealthDir = Directory(path.join(appDir.path, 'mcp', 'streams', 'health'));
          await destHealthDir.create(recursive: true);
          
          final streamFiles = await streamsHealthDir
              .list()
              .where((f) => f is File && f.path.endsWith('.jsonl'))
              .cast<File>()
              .toList();
          
          for (final file in streamFiles) {
            final filename = path.basename(file.path);
            final destFile = File(path.join(destHealthDir.path, filename));
            // Append mode - preserve existing data, add imported data
            final lines = await file.readAsLines();
            final sink = destFile.openWrite(mode: FileMode.append);
            for (final line in lines) {
              if (line.trim().isNotEmpty) {
                sink.writeln(line);
              }
            }
            await sink.close();
            healthStreamFilesImported++;
            print('ARCX Import: ✓ Imported health stream: $filename (${lines.length} lines)');
          }
          
          print('ARCX Import: ✓ Imported $healthStreamFilesImported health stream file(s)');
        } else {
          print('ARCX Import: No health streams found in payload');
        }
        
        // Step 11: Count photo metadata files
        final photoDir = Directory(path.join(payloadDir.path, 'media', 'photo'));
        int photosImported = 0;
        
        if (await photoDir.exists()) {
          final photoFiles = await photoDir
              .list()
              .where((f) => f.path.endsWith('.json'))
              .cast<File>()
              .toList();
          
          photosImported = photoFiles.length;
          print('ARCX Import: Found $photosImported photo metadata files');
        }
        
        print('ARCX Import: ✓ Conversion complete');
        
        // Step 12: Import chat data if nodes.jsonl exists (Enhanced MCP format)
        int chatSessionsImported = 0;
        int chatMessagesImported = 0;
        
        final nodesJsonlFile = File(path.join(payloadDir.path, 'nodes.jsonl'));
        if (await nodesJsonlFile.exists() && _chatRepo != null) {
          try {
            print('ARCX Import: Step 12 - Importing chat data from nodes.jsonl...');
            
            // Use EnhancedMcpImportService to import chats
            final enhancedImportService = EnhancedMcpImportService(
              chatRepo: _chatRepo,
            );
            
            final chatImportResult = await enhancedImportService.importBundle(
              payloadDir,
              McpImportOptions(
                strictMode: false,
                maxErrors: 100,
              ),
            );
            
            chatSessionsImported = chatImportResult.chatSessionsImported;
            chatMessagesImported = chatImportResult.chatMessagesImported;
            
            print('✅ ARCX Import: Imported $chatSessionsImported chat sessions, $chatMessagesImported chat messages');
          } catch (e) {
            print('⚠️ ARCX Import: Failed to import chat data: $e');
            // Don't fail the entire import if chat import fails
          }
        } else {
          if (!await nodesJsonlFile.exists()) {
            print('ARCX Import: No nodes.jsonl found - skipping chat import');
          }
          if (_chatRepo == null) {
            print('ARCX Import: No ChatRepo available - skipping chat import');
          }
        }
        
        if (dryRun) {
          print('ARCX Import: Dry run - no data merged');
        } else {
          print('ARCX Import: ✓ Data merged to repository');
        }
        
        return ARCXImportResult.success(
          entriesImported: entriesImported,
          photosImported: photosImported,
          chatSessionsImported: chatSessionsImported,
          chatMessagesImported: chatMessagesImported,
          warnings: warnings.isEmpty ? null : warnings,
        );
        
      } finally {
        // Clean up temp directory
        await payloadDir.delete(recursive: true);
      }
      
    } catch (e, stackTrace) {
      print('ARCX Import: ✗ Failed: $e');
      print('Stack trace: $stackTrace');
      return ARCXImportResult.failure(e.toString());
    }
  }

  /// Load photo metadata files from nodes/media/photo directory
  Future<Map<String, Map<String, dynamic>>> _loadPhotoMetadata(Directory payloadDir) async {
    final metadataMap = <String, Map<String, dynamic>>{};
    
    final photoMetadataDir = Directory(path.join(payloadDir.path, 'nodes', 'media', 'photo'));
    if (!await photoMetadataDir.exists()) {
      // Try alternative location: media/photo
      final altPhotoMetadataDir = Directory(path.join(payloadDir.path, 'media', 'photo'));
      if (!await altPhotoMetadataDir.exists()) {
        print('ARCX Import: ⚠️ No photo metadata directory found');
        return metadataMap;
      }
      
      // Use alternative location
      await for (final file in altPhotoMetadataDir.list()) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
            final photoId = json['id'] as String? ?? path.basenameWithoutExtension(file.path);
            if (photoId.isNotEmpty) {
              metadataMap[photoId] = json;
            }
          } catch (e) {
            print('ARCX Import: ⚠️ Failed to load photo metadata from ${file.path}: $e');
          }
        }
      }
      return metadataMap;
    }

    await for (final file in photoMetadataDir.list()) {
      if (file is File && file.path.endsWith('.json')) {
        try {
          final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
          final photoId = json['id'] as String? ?? path.basenameWithoutExtension(file.path);
          if (photoId.isNotEmpty) {
            metadataMap[photoId] = json;
          }
        } catch (e) {
          print('ARCX Import: ⚠️ Failed to load photo metadata from ${file.path}: $e');
        }
      }
    }

    return metadataMap;
  }

  /// Convert MCP node JSON to JournalEntry
  Future<JournalEntry?> _convertMCPNodeToJournalEntry(
    Map<String, dynamic> nodeJson,
    Map<String, String> photoMapping,
    Map<String, Map<String, dynamic>> photoMetadataMap,
  ) async {
    try {
      // The node structure is already flat with direct fields
      final nodeId = nodeJson['id'] as String;
      final originalId = _extractOriginalId(nodeId);
      
      // Extract fields directly from the node
      final content = nodeJson['content'] as String? ?? '';
      final timestamp = nodeJson['timestamp'] as String;
      final createdAt = _parseTimestamp(timestamp);
      final updatedAt = createdAt; // Use same timestamp
      
      // Extract optional fields
      final emotion = nodeJson['emotion'] as String?;
      final emotionReason = nodeJson['emotionReason'] as String?;
      final phase = nodeJson['phase'] as String?;
      final keywords = nodeJson['keywords'] as List<dynamic>?;
      
      // Extract metadata if present
      final metadata = nodeJson['metadata'] as Map<String, dynamic>?;
      
      // Generate title from content (first line or first 50 chars)
      final title = _generateTitle(content);
      
      // Process media items with robust fallback detection
      // Check multiple locations for media (robust fallback)
      final mediaItems = <MediaItem>[];
      List<dynamic>? mediaData = nodeJson['media'] as List<dynamic>?;
      
      // Fallback 1: Check metadata.media
      if (mediaData == null || mediaData.isEmpty) {
        final metadataObj = nodeJson['metadata'] as Map<String, dynamic>?;
        if (metadataObj != null) {
          mediaData = metadataObj['media'] as List<dynamic>?;
          if (mediaData != null && mediaData.isNotEmpty) {
            print('ARCX Import: 📝 Found ${mediaData.length} media items in metadata.media for entry ${originalId}');
          }
        }
      }
      
      // Fallback 2: Check metadata.journal_entry.media
      if (mediaData == null || mediaData.isEmpty) {
        final metadataObj = nodeJson['metadata'] as Map<String, dynamic>?;
        if (metadataObj != null) {
          final journalEntryMeta = metadataObj['journal_entry'] as Map<String, dynamic>?;
          if (journalEntryMeta != null) {
            mediaData = journalEntryMeta['media'] as List<dynamic>?;
            if (mediaData != null && mediaData.isNotEmpty) {
              print('ARCX Import: 📝 Found ${mediaData.length} media items in metadata.journal_entry.media for entry ${originalId}');
            }
          }
        }
      }
      
      // Fallback 3: Check metadata.photos
      if (mediaData == null || mediaData.isEmpty) {
        final metadataObj = nodeJson['metadata'] as Map<String, dynamic>?;
        if (metadataObj != null) {
          final photosData = metadataObj['photos'] as List<dynamic>?;
          if (photosData != null && photosData.isNotEmpty) {
            print('ARCX Import: 📝 Found ${photosData.length} photos in metadata.photos for entry ${originalId}');
            // Convert photos array to media format
            mediaData = photosData.map((photo) {
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
                };
              }
              return photo;
            }).toList();
          }
        }
      }
      
      mediaData ??= [];
      
      if (mediaData.isNotEmpty) {
        print('ARCX Import: 📝 Processing entry ${originalId} with ${mediaData.length} media items');
      } else {
        print('ARCX Import: 📝 Processing entry ${originalId} with NO media items');
      }
      
      for (final mediaJson in mediaData) {
        if (mediaJson is Map<String, dynamic>) {
          try {
            // Try to enhance media JSON with photo metadata if available
            final mediaId = mediaJson['id'] as String?;
            Map<String, dynamic> enhancedMediaJson = mediaJson;
            if (mediaId != null && photoMetadataMap.containsKey(mediaId)) {
              final metadataObj = photoMetadataMap[mediaId]!;
              // Merge metadata into mediaJson, preferring metadata values
              enhancedMediaJson = {
                ...mediaJson,
                // Use metadata values if mediaJson doesn't have them
                'filename': mediaJson['filename'] ?? metadataObj['filename'],
                'sha256': mediaJson['sha256'] ?? metadataObj['sha256'],
                'originalPath': mediaJson['originalPath'] ?? metadataObj['originalPath'],
                'createdAt': mediaJson['createdAt'] ?? metadataObj['createdAt'],
                'analysisData': mediaJson['analysisData'] ?? metadataObj['analysisData'],
                'altText': mediaJson['altText'] ?? metadataObj['altText'],
                'ocrText': mediaJson['ocrText'] ?? metadataObj['ocrText'],
              };
              print('ARCX Import: 📋 Enhanced media ${mediaId} with metadata from photo metadata file');
            }
            
            final mediaItem = await _createMediaItemFromJson(
              enhancedMediaJson, 
              photoMapping, 
              originalId,
            );
            if (mediaItem != null) {
              // Check cache for deduplication
              final cacheKey = mediaItem.uri;
              if (_mediaCache.containsKey(cacheKey)) {
                final cachedMediaItem = _mediaCache[cacheKey]!;
                mediaItems.add(cachedMediaItem);
                print('ARCX Import: ♻️ Reusing cached media: ${cachedMediaItem.id} -> $cacheKey');
              } else {
                _mediaCache[cacheKey] = mediaItem;
            mediaItems.add(mediaItem);
                print('ARCX Import: ✅ Added media item ${mediaItem.id} to entry ${originalId}');
              }
            } else {
              print('ARCX Import: ⚠️ Failed to create media item for entry ${originalId}');
            }
          } catch (e, stackTrace) {
            print('ARCX Import: ⚠️ ERROR creating media item for entry ${originalId}: $e');
            print('   Stack trace: $stackTrace');
            // Continue processing other media items - don't let one failure stop the entry
          }
        }
      }
      
      if (mediaData.length > 0 && mediaItems.isEmpty) {
        print('ARCX Import: ⚠️ Entry ${originalId} had ${mediaData.length} media items but none could be mapped!');
        print('   Photo mapping contains ${photoMapping.length} photos');
        print('   First media item filename: ${mediaData[0] is Map ? (mediaData[0] as Map<String, dynamic>)['filename'] : 'N/A'}');
      }
      
      // IMPORTANT: Always import the entry, even if media items failed
      print('ARCX Import: 📝 Creating journal entry $originalId with ${mediaItems.length}/${mediaData.length} media items');
      
      // Create journal entry
      JournalEntry journalEntry;
      try {
        journalEntry = JournalEntry(
        id: originalId,
        title: title,
        content: content,
        createdAt: createdAt,
        updatedAt: updatedAt,
          media: mediaItems,
        tags: (keywords?.cast<String>().toList()) ?? [],
        keywords: (keywords?.cast<String>().toList()) ?? [],
        mood: emotion ?? '',
        emotion: emotion,
        emotionReason: emotionReason,
        phase: phase,
        metadata: {
          'imported_from_arcx': true,
          'original_node_id': nodeId,
          'import_timestamp': DateTime.now().toIso8601String(),
          ...?metadata,
        },
      );
        print('ARCX Import: ✅ Successfully created JournalEntry object for $originalId');
      } catch (e, stackTrace) {
        print('ARCX Import: ❌ ERROR: Failed to create JournalEntry object for $originalId: $e');
        print('   Stack trace: $stackTrace');
        rethrow; // Re-throw to be caught by outer try-catch
      }
      
      return journalEntry;
    } catch (e, stackTrace) {
      print('ARCX Import: Failed to convert MCP node to journal entry: $e');
      print('   Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Create MediaItem from JSON with photo mapping (robust version with multiple fallbacks)
  Future<MediaItem?> _createMediaItemFromJson(
    Map<String, dynamic> mediaJson,
    Map<String, String> photoMapping,
    String entryId,
  ) async {
    try {
      // Extract media ID (try multiple field names)
      final mediaId = mediaJson['id'] as String? ?? 
                      mediaJson['photo_id'] as String? ?? 
                      mediaJson['placeholder_id'] as String? ?? 
                      '';
      
      if (mediaId.isEmpty) {
        print('ARCX Import: ⚠️ Media item missing ID field for entry $entryId');
        print('   Available keys: ${mediaJson.keys.join(', ')}');
      }
      
      // Try multiple ways to find the filename
      String? filename = mediaJson['filename'] as String?;
      if (filename == null || filename.isEmpty) {
        // Try alternative field names
        filename = mediaJson['file_name'] as String?;
        if (filename == null || filename.isEmpty) {
          filename = mediaJson['name'] as String?;
        }
      }

      // Try to get permanent path from mapping
      String? permanentPath;
      if (filename != null && filename.isNotEmpty) {
        permanentPath = photoMapping[filename];
        if (permanentPath == null) {
          // Try matching by SHA-256 if filename doesn't match
          final sha256 = mediaJson['sha256'] as String?;
          if (sha256 != null && sha256.isNotEmpty) {
            // Look for photo file that matches SHA-256
            for (final entry in photoMapping.entries) {
              if (entry.key.contains(sha256.substring(0, 8))) {
                permanentPath = entry.value;
                print('ARCX Import: 🔗 Matched photo by SHA-256 prefix: ${sha256.substring(0, 8)}...');
                break;
              }
            }
          }
        }
      }

      // Determine final URI (try multiple fallbacks)
      String finalUri;
      if (permanentPath != null) {
        finalUri = permanentPath;
      } else {
        // Fallback 1: Try originalPath
        final originalPath = mediaJson['originalPath'] as String? ?? 
                             mediaJson['original_path'] as String? ??
                             mediaJson['uri'] as String? ??
                             mediaJson['path'] as String?;
        
        if (originalPath != null && originalPath.isNotEmpty) {
          finalUri = originalPath;
          print('ARCX Import:   Using originalPath/uri as fallback: $originalPath');
        } else {
          // Fallback 2: Try to construct from filename if available
          if (filename != null && filename.isNotEmpty) {
            final appDir = await getApplicationDocumentsDirectory();
            final photosDir = Directory(path.join(appDir.path, 'photos'));
            final constructedPath = path.join(photosDir.path, filename);
            if (await File(constructedPath).exists()) {
              finalUri = constructedPath;
              print('ARCX Import:   Found photo at constructed path: $constructedPath');
            } else {
              // Last resort: placeholder URI
              finalUri = 'placeholder://$mediaId';
              print('ARCX Import: ⚠️ Could not find photo file, using placeholder: $finalUri');
            }
          } else {
            // Last resort: placeholder URI
            finalUri = 'placeholder://$mediaId';
            print('ARCX Import: ⚠️ No filename or path found, using placeholder: $finalUri');
          }
        }
      }

      // Extract analysis data (try multiple field names)
      Map<String, dynamic>? analysisData = mediaJson['analysisData'] as Map<String, dynamic>?;
      if (analysisData == null) {
        analysisData = mediaJson['analysis_data'] as Map<String, dynamic>?;
      }
      if (analysisData == null && mediaJson.containsKey('features')) {
        analysisData = {'features': mediaJson['features']};
      }

      // Extract kind/type for MediaType
      final kind = mediaJson['kind'] as String? ?? 
                   mediaJson['type'] as String? ?? 
                   'photo';
      
      final mediaType = kind == 'photo' || kind == 'image'
          ? MediaType.image
          : kind == 'video'
              ? MediaType.video
              : kind == 'audio'
                  ? MediaType.audio
                  : MediaType.image; // Default to image

      return MediaItem(
        id: mediaId,
        type: mediaType,
        uri: finalUri,
        createdAt: _parseMediaTimestamp(
          mediaJson['createdAt'] as String? ?? 
          mediaJson['created_at'] as String?
        ),
        analysisData: analysisData,
        altText: mediaJson['altText'] as String? ?? 
                 mediaJson['alt_text'] as String?,
        ocrText: mediaJson['ocrText'] as String? ?? 
                 mediaJson['ocr_text'] as String?,
        sha256: null, // Clear SHA256 - these are file-based media now, not MCP content-addressed
      );
    } catch (e, stackTrace) {
      print('ARCX Import: ⚠️ Failed to create MediaItem: $e');
      print('   Stack trace: $stackTrace');
      print('   Media JSON keys: ${mediaJson.keys.join(', ')}');
      return null;
    }
  }
  
  /// Parse timestamp with robust handling of different formats
  DateTime _parseTimestamp(String timestamp) {
    try {
      // Handle malformed timestamps missing 'Z' suffix
      if (timestamp.endsWith('.000') && !timestamp.endsWith('Z')) {
        // Add 'Z' suffix for UTC timezone
        timestamp = '${timestamp}Z';
      } else if (!timestamp.endsWith('Z') && !timestamp.contains('+') && !timestamp.contains('-', 10)) {
        // If no timezone indicator, assume UTC and add 'Z'
        timestamp = '${timestamp}Z';
      }
      
      return DateTime.parse(timestamp);
    } catch (e) {
      print('ARCX Import: ⚠️ Failed to parse timestamp "$timestamp": $e');
      // Fallback to current time if parsing fails
      return DateTime.now();
    }
  }

  /// Parse media timestamp with robust handling (can be null)
  DateTime _parseMediaTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) {
      return DateTime.now();
    }
    try {
      return _parseTimestamp(timestamp);
    } catch (e) {
      print('ARCX Import: ⚠️ Failed to parse media timestamp "$timestamp": $e, using current time');
      return DateTime.now();
    }
  }

  /// Generate title from content
  String _generateTitle(String content) {
    if (content.isEmpty) return 'Imported Entry';
    
    // Use first line as title, max 50 chars
    final firstLine = content.split('\n').first.trim();
    if (firstLine.length > 50) {
      return firstLine.substring(0, 50) + '...';
    }
    return firstLine;
  }

  /// Extract original ID from MCP node ID (remove prefixes like 'entry_', 'je_', etc.)
  String _extractOriginalId(String mcpId) {
    // Remove common prefixes
    if (mcpId.startsWith('entry_')) {
      return mcpId.substring(6);
    } else if (mcpId.startsWith('je_')) {
      return mcpId.substring(3);
    }
    return mcpId;
  }
}


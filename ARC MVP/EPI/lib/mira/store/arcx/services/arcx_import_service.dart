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
import 'package:my_app/arc/chat/chat/chat_repo.dart';
import 'package:my_app/mira/store/mcp/import/enhanced_mcp_import_service.dart';
import 'package:my_app/mira/store/mcp/import/mcp_import_service.dart';
import 'package:my_app/core/utils/timestamp_parser.dart';
import 'package:my_app/core/utils/title_generator.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/rivet_sweep_service.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/models/phase_models.dart';
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
      
      // Check if this is ARCX 1.2 format - legacy service can't handle it
      if (manifest.arcxVersion == '1.2') {
        throw Exception('This archive uses ARCX 1.2 format. Please use the V2 import service. The V2 service should have automatically detected and handled this format.');
      }
      
      if (!manifest.validate()) {
        throw Exception('Invalid manifest structure. This archive may be corrupted or in an unsupported format.');
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
                // Check if entry already exists - skip to preserve original dates
                final existingEntry = await _journalRepo!.getJournalEntryById(entry.id);
                if (existingEntry != null) {
                  print('ARCX Import: ⚠️ Entry ${entry.id} already exists - SKIPPING to preserve original dates');
                  print('   Existing createdAt: ${existingEntry.createdAt}');
                  print('   Would import createdAt: ${entry.createdAt}');
                  print('   Skipping to prevent date changes');
                  warnings.add('Entry ${entry.id} already exists - skipped to preserve dates');
                  // Don't count as imported - we skipped it
                  continue;
                }
                
                // New entry - save with imported dates from export
              await _journalRepo!.createJournalEntry(entry);
                entriesImported++;
                print('ARCX Import: ✓ Saved new entry ${entry.id}: ${entry.title}');
                print('   CreatedAt: ${entry.createdAt} (from export timestamp)');
                print('   Media items: ${entry.media.length}');
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
          
          // Rebuild phase regimes using 10-day rolling windows for imported entries
          if (entriesImported > 0 && _journalRepo != null) {
            try {
              print('ARCX Import: 🔄 Rebuilding phase regimes...');
              final allEntries = _journalRepo!.getAllJournalEntriesSync();
              final analyticsService = AnalyticsService();
              final rivetSweepService = RivetSweepService(analyticsService);
              final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
              await phaseRegimeService.initialize();
              await phaseRegimeService.rebuildRegimesFromEntries(allEntries, windowDays: 10);
              print('ARCX Import: ✅ Phase regimes rebuilt using 10-day rolling windows');
            } catch (e) {
              print('ARCX Import: ⚠️ Failed to rebuild phase regimes: $e');
              warnings.add('Phase regime rebuild failed: $e');
            }
          }
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
  /// 
  /// CRITICAL LOGIC:
  /// - Date Preservation: Entry timestamps MUST be preserved from export. Never use DateTime.now()
  ///   TimestampParser.parseEntryTimestamp() throws exceptions for unparseable timestamps rather
  ///   than falling back, ensuring entries with bad dates are skipped rather than imported with wrong dates.
  /// 
  /// - Media Deduplication: Media cache (_mediaCache) maps URI -> MediaItem to prevent duplicate
  ///   MediaItem objects. When multiple entries reference the same photo, they share the same MediaItem
  ///   instance. This prevents storage bloat and ensures consistency.
  /// 
  /// - Fallback Chains: Media extraction uses a 3-step fallback (node.media -> metadata.media ->
  ///   metadata.photos). Path resolution uses a 5-step fallback (permanent path -> originalPath ->
  ///   constructed path -> placeholder). This ensures maximum compatibility with different export formats.
  /// 
  /// - Service Differences: ARCX v1 uses simpler media resolution (photos directory only).
  ///   ARCX v2 and MCP services support media packs with type-specific directories.
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
      
      print('ARCX Import: Entry $originalId - Extracted timestamp from export: "$timestamp"');
      
      // CRITICAL: Date preservation - never use DateTime.now() for entry dates
      // TimestampParser throws exceptions for unparseable timestamps to preserve data integrity
      final timestampResult = TimestampParser.parseEntryTimestamp(timestamp);
      if (!timestampResult.isSuccess) {
        throw Exception(timestampResult.error ?? 'Failed to parse timestamp');
      }
      final createdAt = timestampResult.value!;
      final updatedAt = createdAt; // Use same timestamp
      
      print('ARCX Import: Entry $originalId - Parsed dates: createdAt=$createdAt, updatedAt=$updatedAt');
      
      // Extract optional fields
      final emotion = nodeJson['emotion'] as String?;
      final emotionReason = nodeJson['emotionReason'] as String?;
      final phase = nodeJson['phase'] as String?;
      final keywords = nodeJson['keywords'] as List<dynamic>?;
      
      // Extract phase-related fields (for RIVET integration)
      final autoPhase = nodeJson['autoPhase'] as String?;
      final autoPhaseConfidence = (nodeJson['autoPhaseConfidence'] as num?)?.toDouble();
      final userPhaseOverride = nodeJson['userPhaseOverride'] as String?;
      final isPhaseLocked = nodeJson['isPhaseLocked'] as bool? ?? false;
      final legacyPhaseTag = nodeJson['legacyPhaseTag'] as String?;
      
      // Extract metadata if present
      final metadata = nodeJson['metadata'] as Map<String, dynamic>?;
      
      // Use exported title if available, otherwise generate from content
      final exportedTitle = nodeJson['title'] as String?;
      final title = (exportedTitle != null && exportedTitle.isNotEmpty)
          ? exportedTitle
          : TitleGenerator.forImportedEntry(content);
      
      // Process media items with robust fallback detection
      // Media deduplication: _mediaCache prevents duplicate MediaItem objects when multiple entries
      // reference the same photo. Cache key is the URI - entries sharing the same photo URI
      // will share the same MediaItem instance.
      final mediaItems = <MediaItem>[];
      final mediaData = _extractMediaDataFromNode(nodeJson, originalId);
      
      // Media processing happens silently unless errors occur
      
      for (final mediaJson in mediaData) {
        if (mediaJson is Map<String, dynamic>) {
          try {
            // Try to enhance media JSON with photo metadata if available
            // Photo metadata files provide additional context (filename, SHA-256, analysis data)
            // that may not be in the main node JSON
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
            }
            
            final mediaItem = await _createMediaItemFromJson(
              enhancedMediaJson, 
              photoMapping, 
              originalId,
            );
            if (mediaItem != null) {
              // CRITICAL: Media deduplication - check cache before adding
              // Multiple entries may reference the same photo - sharing MediaItem instances
              // prevents storage bloat and ensures consistency
              final cacheKey = mediaItem.uri;
              if (_mediaCache.containsKey(cacheKey)) {
                final cachedMediaItem = _mediaCache[cacheKey]!;
                mediaItems.add(cachedMediaItem);
              } else {
                _mediaCache[cacheKey] = mediaItem;
            mediaItems.add(mediaItem);
              }
            }
          } catch (e) {
            // Log errors but continue processing other media items
            print('ARCX Import: ⚠️ ERROR creating media item for entry ${originalId}: $e');
            // Continue processing other media items - don't let one failure stop the entry
          }
        }
      }
      
      // IMPORTANT: Always import the entry, even if media items failed
      // Media failures don't prevent entry import - entries can exist without media
      if (mediaData.length > 0 && mediaItems.isEmpty) {
        print('ARCX Import: ⚠️ WARNING: Entry ${originalId} had ${mediaData.length} media items but none could be mapped!');
        print('   Photo mapping contains ${photoMapping.length} photos');
        print('   First media item filename: ${mediaData[0] is Map ? (mediaData[0] as Map<String, dynamic>)['filename'] : 'N/A'}');
      }
      
      // Apply auto-hashtag logic for imported entries using Phase Regimes
      // Check if content already has a phase hashtag
      final phaseHashtagPattern = RegExp(
        r'#(discovery|expansion|transition|consolidation|recovery|breakthrough)',
        caseSensitive: false,
      );
      
      String contentWithPhase = content;
      if (!phaseHashtagPattern.hasMatch(content)) {
        // No phase hashtag found - use Phase Regime system to determine phase based on entry date
        try {
          final analyticsService = AnalyticsService();
          final rivetSweepService = RivetSweepService(analyticsService);
          final phaseRegimeService = PhaseRegimeService(analyticsService, rivetSweepService);
          await phaseRegimeService.initialize();
          
          // Find the regime that contains the entry's date
          final regime = phaseRegimeService.phaseIndex.regimeFor(createdAt);
          
          if (regime != null) {
            // Entry date falls within a phase regime - use that phase
            final phaseName = _getPhaseLabelNameFromEnum(regime.label).toLowerCase();
            final phaseHashtag = '#$phaseName';
            contentWithPhase = '$content $phaseHashtag'.trim();
            
            print('ARCX Import: Auto-added phase hashtag $phaseHashtag to imported entry $originalId (from regime: ${regime.label}, date: $createdAt)');
          } else {
            // Entry date doesn't fall within any regime - no hashtag added
            print('ARCX Import: Entry $originalId date $createdAt does not fall within any phase regime, skipping hashtag');
          }
        } catch (e) {
          print('ARCX Import: ERROR: Failed to determine phase from regime for entry $originalId: $e');
          // Fallback: return content as-is if regime lookup fails
        }
      } else {
        print('ARCX Import: Entry $originalId already has phase hashtag, preserving existing');
      }
      
      // Create journal entry
      JournalEntry journalEntry;
      try {
        journalEntry = JournalEntry(
        id: originalId,
        title: title,
        content: contentWithPhase, // Use content with auto-added phase hashtag
        createdAt: createdAt,
        updatedAt: updatedAt,
          media: mediaItems,
        tags: (keywords?.cast<String>().toList()) ?? [],
        keywords: (keywords?.cast<String>().toList()) ?? [],
        mood: emotion ?? '',
        emotion: emotion,
        emotionReason: emotionReason,
        phase: phase,
        autoPhase: autoPhase,
        autoPhaseConfidence: autoPhaseConfidence,
        userPhaseOverride: userPhaseOverride,
        isPhaseLocked: isPhaseLocked,
        legacyPhaseTag: legacyPhaseTag,
        metadata: {
          'imported_from_arcx': true,
          'original_node_id': nodeId,
          'import_timestamp': DateTime.now().toIso8601String(),
          ...?metadata,
        },
      );
      } catch (e) {
        print('ARCX Import: ❌ ERROR: Failed to create JournalEntry object for $originalId: $e');
        rethrow; // Re-throw to be caught by outer try-catch
      }
      
      return journalEntry;
    } catch (e) {
      print('ARCX Import: ERROR: Failed to convert MCP node to journal entry: $e');
      return null;
    }
  }
  
  /// Helper to convert PhaseLabel enum to string name
  String _getPhaseLabelNameFromEnum(PhaseLabel label) {
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
        print('ARCX Import: ⚠️ WARNING: Media item missing ID field for entry $entryId');
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

      // Resolve media path with robust fallback chain
      final finalUri = await _resolveMediaPath(
        mediaJson: mediaJson,
        mediaId: mediaId,
        filename: filename,
        photoMapping: photoMapping,
        mediaType: MediaType.image, // Default to image for ARCX
      );

      // Extract analysis data (try multiple field names)
      Map<String, dynamic>? analysisData = _getFieldValue<Map<String, dynamic>>(mediaJson, 'analysisData');
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
          _getFieldValue<String>(mediaJson, 'createdAt')
        ),
        analysisData: analysisData,
        altText: _getFieldValue<String>(mediaJson, 'altText'),
        ocrText: _getFieldValue<String>(mediaJson, 'ocrText'),
        sha256: null, // Clear SHA256 - these are file-based media now, not MCP content-addressed
      );
    } catch (e) {
      print('ARCX Import: ⚠️ ERROR: Failed to create MediaItem: $e');
      return null;
    }
  }
  
  /// Parse media timestamp with robust handling (can be null)
  /// Note: Media timestamps can fallback to DateTime.now() as they're optional metadata
  DateTime _parseMediaTimestamp(String? timestamp) {
    return TimestampParser.parseMediaTimestamp(timestamp);
  }

  /// Resolve media path with robust fallback chain
  /// 
  /// Fallback order:
  /// 1. Permanent path from photo mapping (by filename)
  /// 2. Permanent path from photo mapping (by SHA-256 prefix match)
  /// 3. originalPath/uri/path from media JSON
  /// 4. Constructed path from filename in app documents directory
  /// 5. Placeholder URI as last resort
  /// 
  /// CRITICAL: Media deduplication relies on URI matching - preserve original paths when possible
  Future<String> _resolveMediaPath({
    required Map<String, dynamic> mediaJson,
    required String mediaId,
    String? filename,
    required Map<String, String> photoMapping,
    MediaType mediaType = MediaType.image,
  }) async {
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
              break;
            }
          }
        }
      }
    }

    // Determine final URI (try multiple fallbacks)
    if (permanentPath != null) {
      return permanentPath;
    }
    
    // Fallback 1: Try originalPath (with camelCase/snake_case handling)
    final originalPath = _getFieldValue<String>(mediaJson, 'originalPath') ??
                         mediaJson['uri'] as String? ??
                         mediaJson['path'] as String?;
    
    if (originalPath != null && originalPath.isNotEmpty) {
      return originalPath;
    }
    
    // Fallback 2: Try to construct from filename if available
    if (filename != null && filename.isNotEmpty) {
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(path.join(appDir.path, 'photos'));
      final constructedPath = path.join(photosDir.path, filename);
      if (await File(constructedPath).exists()) {
        return constructedPath;
      }
    }
    
    // Last resort: placeholder URI
    print('ARCX Import: ⚠️ WARNING: Could not resolve media path for $mediaId, using placeholder');
    return 'placeholder://$mediaId';
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

  /// Get field value from map handling camelCase/snake_case variations
  /// Tries camelCase first, then snake_case, returns null if neither found
  T? _getFieldValue<T>(Map<String, dynamic> map, String camelCaseKey) {
    // Try camelCase first
    if (map.containsKey(camelCaseKey)) {
      final value = map[camelCaseKey];
      if (value is T) return value;
      return null;
    }
    
    // Convert camelCase to snake_case
    final snakeCaseKey = _camelToSnake(camelCaseKey);
    if (map.containsKey(snakeCaseKey)) {
      final value = map[snakeCaseKey];
      if (value is T) return value;
      return null;
    }
    
    return null;
  }

  /// Convert camelCase to snake_case
  String _camelToSnake(String camelCase) {
    return camelCase.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match[1]}_${match[2]?.toLowerCase() ?? match[2]}',
    );
  }

  /// Extract media data from node JSON with robust fallback chain
  /// Checks multiple locations: node.media, metadata.media, metadata.journal_entry.media, metadata.photos
  /// Converts photos array format to media format when needed
  List<dynamic> _extractMediaDataFromNode(Map<String, dynamic> nodeJson, String entryId) {
    List<dynamic>? mediaData = nodeJson['media'] as List<dynamic>?;
    
    // Fallback 1: Check metadata.media
    if (mediaData == null || mediaData.isEmpty) {
      final metadataObj = nodeJson['metadata'] as Map<String, dynamic>?;
      if (metadataObj != null) {
        mediaData = metadataObj['media'] as List<dynamic>?;
      }
    }
    
    // Fallback 2: Check metadata.journal_entry.media
    if (mediaData == null || mediaData.isEmpty) {
      final metadataObj = nodeJson['metadata'] as Map<String, dynamic>?;
      if (metadataObj != null) {
        final journalEntryMeta = metadataObj['journal_entry'] as Map<String, dynamic>?;
        if (journalEntryMeta != null) {
          mediaData = journalEntryMeta['media'] as List<dynamic>?;
        }
      }
    }
    
    // Fallback 3: Check metadata.photos
    if (mediaData == null || mediaData.isEmpty) {
      final metadataObj = nodeJson['metadata'] as Map<String, dynamic>?;
      if (metadataObj != null) {
        final photosData = metadataObj['photos'] as List<dynamic>?;
        if (photosData != null && photosData.isNotEmpty) {
          // Convert photos array to media format
          mediaData = photosData.map((photo) {
            if (photo is Map<String, dynamic>) {
              return {
                'id': photo['id'] ?? photo['placeholder_id'] ?? '',
                'filename': photo['filename'],
                'originalPath': photo['uri'] ?? photo['path'],
                'createdAt': _getFieldValue<String>(photo, 'createdAt'),
                'analysisData': _getFieldValue<Map<String, dynamic>>(photo, 'analysisData'),
                'altText': _getFieldValue<String>(photo, 'altText'),
                'ocrText': _getFieldValue<String>(photo, 'ocrText'),
                'sha256': photo['sha256'],
              };
            }
            return photo;
          }).toList();
        }
      }
    }
    
    return mediaData ?? [];
  }
}


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
import 'arcx_crypto_service.dart';
import '../models/arcx_manifest.dart';
import '../models/arcx_result.dart';

class ARCXImportService {
  final JournalRepository? _journalRepo;
  
  ARCXImportService({JournalRepository? journalRepo}) : _journalRepo = journalRepo;
  
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
        
        // Step 8: Copy photos to permanent storage
        final photosDir = Directory(path.join(payloadDir.path, 'media', 'photos'));
        String? photosPath;
        
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
              photosCopied++;
            }
          }
          
          photosPath = permanentPhotosDir.path;
          print('ARCX Import: Copied $photosCopied photos to permanent storage at $photosPath');
        }
        
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
        print('ARCX Import: Photos directory: $photosPath');
        
        int entriesImported = 0;
        final warnings = <String>[];
        
        for (final file in journalFiles) {
          try {
            final nodeJson = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
            
            // DEBUG: Log the structure of the first node
            if (entriesImported == 0) {
              final nodeStr = jsonEncode(nodeJson);
              final sampleLength = nodeStr.length > 500 ? 500 : nodeStr.length;
              print('ARCX Import: First node structure:');
              print('ARCX Import: Keys: ${nodeJson.keys}');
              print('ARCX Import: Sample node: ${nodeStr.substring(0, sampleLength)}');
              if (nodeJson['media'] != null) {
                print('ARCX Import: Media field type: ${nodeJson['media'].runtimeType}');
                print('ARCX Import: Media field value: ${nodeJson['media']}');
                if (nodeJson['media'] is List) {
                  print('ARCX Import: Media list length: ${(nodeJson['media'] as List).length}');
                  if ((nodeJson['media'] as List).isNotEmpty) {
                    print('ARCX Import: First media item: ${nodeJson['media'][0]}');
                  }
                }
              } else {
                print('ARCX Import: ⚠️ No media field found in node!');
              }
            }
            
            // Log media count for all entries
            final mediaCount = (nodeJson['media'] as List<dynamic>? ?? []).length;
            if (mediaCount > 0) {
              print('ARCX Import: Entry ${nodeJson['id']} has $mediaCount media items');
            }
            
            final entry = await _convertMCPNodeToJournalEntry(nodeJson, photosPath);
            
            if (entry == null) {
              print('ARCX Import: ✗ Skipped entry ${path.basename(file.path)} - conversion returned null');
              warnings.add('Failed to convert entry ${path.basename(file.path)}');
              continue;
            }
            
            if (!dryRun && _journalRepo != null) {
              await _journalRepo!.createJournalEntry(entry);
              print('ARCX Import: ✓ Saved entry ${entry.id}: ${entry.title}');
            } else {
              print('ARCX Import: ✗ Skipped entry ${entry.id} (dryRun=$dryRun, repo=${_journalRepo != null})');
            }
            
            entriesImported++;
          } catch (e) {
            print('ARCX Import: ✗ Failed to import entry ${path.basename(file.path)}: $e');
            warnings.add('Failed to import entry ${path.basename(file.path)}: $e');
          }
        }
        
        // Step 10: Count photo metadata files
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
        
        if (dryRun) {
          print('ARCX Import: Dry run - no data merged');
        } else {
          print('ARCX Import: ✓ Data merged to repository');
        }
        
        return ARCXImportResult.success(
          entriesImported: entriesImported,
          photosImported: photosImported,
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

  /// Convert MCP node JSON to JournalEntry
  Future<JournalEntry?> _convertMCPNodeToJournalEntry(Map<String, dynamic> nodeJson, String? photosPath) async {
    try {
      // The node structure is already flat with direct fields
      final nodeId = nodeJson['id'] as String;
      final originalId = _extractOriginalId(nodeId);
      
      // Extract fields directly from the node
      final content = nodeJson['content'] as String? ?? '';
      final timestamp = nodeJson['timestamp'] as String;
      final createdAt = DateTime.parse(timestamp);
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
      
      // Reconstruct media items
      final mediaList = nodeJson['media'] as List<dynamic>? ?? [];
      final mediaItems = <MediaItem>[];
      
      print('ARCX Import: Processing entry ${originalId} with ${mediaList.length} media items');
      if (mediaList.isEmpty) {
        print('ARCX Import: ⚠️ Entry ${originalId} has NO media items');
      }
      
      for (final mediaJson in mediaList) {
        if (mediaJson is Map<String, dynamic>) {
          try {
            // Convert MCP media format to MediaItem format
            final mcpId = mediaJson['id'] as String;
            final kind = mediaJson['kind'] as String? ?? 'photo';
            final filename = mediaJson['filename'] as String?;
            final originalPath = mediaJson['originalPath'] as String?;
            final createdAtStr = mediaJson['createdAt'] as String?;
            // Note: sha256 is intentionally omitted to prevent isMcpMedia from returning true
            final altText = mediaJson['altText'] as String?;
            final ocrText = mediaJson['ocrText'] as String?;
            final analysisData = mediaJson['analysisData'] as Map<String, dynamic>?;
            
            // Map kind to MediaType
            final mediaType = kind == 'photo' || kind == 'image'
                ? MediaType.image
                : kind == 'video'
                    ? MediaType.video
                    : kind == 'audio'
                        ? MediaType.audio
                        : MediaType.image; // Default to image
            
            // Construct URI from filename or use original path
            String? uri;
            if (filename != null && photosPath != null) {
              // Construct path to photo in the extracted photos directory
              uri = path.join(photosPath, filename);
              print('ARCX Import: Constructed URI for photo: $uri');
              
              // Verify file exists
              final photoFile = File(uri);
              final exists = await photoFile.exists();
              print('ARCX Import: Photo file exists: $exists');
              if (!exists) {
                print('ARCX Import: WARNING - Photo file does not exist at: $uri');
              }
            } else if (originalPath != null) {
              uri = originalPath;
            } else if (filename != null) {
              print('ARCX Import: Warning - photos path not available, using filename as URI: $filename');
              uri = filename;
            }
            
            final createdAt = createdAtStr != null
                ? DateTime.parse(createdAtStr)
                : DateTime.now();
            
            final mediaItem = MediaItem(
              id: mcpId,
              uri: uri ?? '',
              type: mediaType,
              createdAt: createdAt,
              ocrText: ocrText,
              analysisData: analysisData,
              altText: altText,
              sha256: null, // Clear SHA256 - these are file-based media now, not MCP content-addressed
            );
            
            mediaItems.add(mediaItem);
            print('ARCX Import: ✓ Added media item: ${mediaItem.id} (type: ${mediaItem.type}, uri: ${mediaItem.uri})');
          } catch (e) {
            print('ARCX Import: Failed to parse media item: $e');
          }
        }
      }
      
      // Create the journal entry
      return JournalEntry(
        id: originalId,
        title: title,
        content: content,
        createdAt: createdAt,
        updatedAt: updatedAt,
        tags: (keywords?.cast<String>().toList()) ?? [],
        keywords: (keywords?.cast<String>().toList()) ?? [],
        mood: emotion ?? '',
        emotion: emotion,
        emotionReason: emotionReason,
        phase: phase,
        media: mediaItems,
        metadata: {
          'imported_from_arcx': true,
          'original_node_id': nodeId,
          'import_timestamp': DateTime.now().toIso8601String(),
          ...?metadata,
        },
      );
    } catch (e) {
      print('ARCX Import: Failed to convert MCP node to journal entry: $e');
      return null;
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

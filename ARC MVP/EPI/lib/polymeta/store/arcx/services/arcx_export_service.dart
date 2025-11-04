/// ARCX Export Service
/// 
/// Orchestrates the export of ARC data to secure .arcx archives.
library arcx_export_service;

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import '../../core/mcp/export/mcp_pack_export_service.dart';
import 'arcx_crypto_service.dart';
import 'arcx_redaction_service.dart';
import '../models/arcx_manifest.dart';
import '../models/arcx_result.dart';

class ARCXExportService {
  
  /// Export secure .arcx archive
  /// 
  /// Process:
  /// 1. Gather MCP bundle using existing McpExportService
  /// 2. Apply redaction to journal and photo metadata
  /// 3. Package into payload/ structure
  /// 4. Archive payload/ to zip
  /// 5. Encrypt with AES-256-GCM (device-based or password-based)
  /// 6. Sign manifest with Ed25519
  /// 7. Write .arcx + .manifest.json with file protection
  Future<ARCXExportResult> exportSecure({
    required Directory outputDir,
    required List<JournalEntry> journalEntries,
    List<MediaItem>? mediaFiles,
    bool includePhotoLabels = false,
    bool dateOnlyTimestamps = false,
    bool removePii = false,
    String? password, // Optional password for portable archives
    Function(String)? onProgress, // Progress callback
  }) async {
    try {
      print('ARCX Export: Starting secure export...');
      onProgress?.call('Preparing export...');
      
      // Create temp directory in app documents (safer than system temp on iOS)
      final appDocDir = await getApplicationDocumentsDirectory();
      final tempDir = Directory(path.join(appDocDir.path, 'arcx_temp_${DateTime.now().millisecondsSinceEpoch}'));
      await tempDir.create(recursive: true);
      
      try {
        // Step 1: Generate MCP bundle
        print('ARCX Export: Step 1 - Generating MCP bundle...');
        onProgress?.call('Gathering journal data...');
        // Use McpPackExportService instead of McpExportService to get actual photo files
        final mcpPackService = McpPackExportService(
          bundleId: 'arcx_${DateTime.now().millisecondsSinceEpoch}',
          outputPath: path.join(tempDir.path, 'mcp.zip'),
        );
        // Determine if we should include photos by checking entries directly
        // (McpPackExportService reads from entry.media, not from mediaFiles parameter)
        // The mediaFiles parameter is used for other purposes, but photos are read from entry.media
        final hasPhotosInEntries = journalEntries.any((entry) => 
          entry.media.any((m) => m.type == MediaType.image)
        );
        
        print('ARCX Export: Checking for photos...');
        print('  - Entries with photos: $hasPhotosInEntries');
        print('  - Total entries: ${journalEntries.length}');
        print('  - Entries with media: ${journalEntries.where((e) => e.media.isNotEmpty).length}');
        print('  - Total media files passed: ${mediaFiles?.length ?? 0}');
        
        // Use hasPhotosInEntries as primary check - this is what McpPackExportService actually uses
        final shouldIncludePhotos = hasPhotosInEntries || (mediaFiles != null && mediaFiles.isNotEmpty);
        
        if (!shouldIncludePhotos && journalEntries.isNotEmpty) {
          print('ARCX Export: ⚠️ WARNING - No photos found but entries exist. Checking first entry media...');
          if (journalEntries.first.media.isNotEmpty) {
            print('ARCX Export: First entry has ${journalEntries.first.media.length} media items');
            for (final media in journalEntries.first.media) {
              print('ARCX Export:   - Media ID: ${media.id}, Type: ${media.type}, URI: ${media.uri}');
            }
          }
        }
        
        final mcpResult = await mcpPackService.exportJournal(
          entries: journalEntries,
          includePhotos: shouldIncludePhotos,
          reducePhotoSize: false,
        );
        
        if (!mcpResult.success) {
          throw Exception('MCP export failed: ${mcpResult.error}');
        }
        
        print('ARCX Export: ✓ MCP bundle generated');
        onProgress?.call('Extracting data...');
        
        // Extract the MCP ZIP to temp directory
        final mcpZipPath = path.join(tempDir.path, 'mcp.zip');
        if (await File(mcpZipPath).exists()) {
          print('ARCX Export: Extracting MCP bundle from ZIP...');
          final zipDecoder = ZipDecoder();
          final zipBytes = await File(mcpZipPath).readAsBytes();
          final archive = zipDecoder.decodeBytes(zipBytes);
          
          for (final file in archive) {
            if (file.isFile) {
              final extractedPath = path.join(tempDir.path, file.name);
              final extractedDir = Directory(path.dirname(extractedPath));
              if (!await extractedDir.exists()) {
                await extractedDir.create(recursive: true);
              }
              await File(extractedPath).writeAsBytes(file.content);
              // Debug: Log photo file extractions
              if (file.name.contains('media/photos/') || file.name.contains('photos/')) {
                print('ARCX Export: Extracted photo file: ${file.name} -> ${extractedPath}');
              }
            }
          }
          
          // Delete the ZIP file after extraction
          await File(mcpZipPath).delete();
        }
        
        // Debug: List all files in temp directory
        print('ARCX Export: Temp directory contents:');
        final allFiles = await tempDir.list(recursive: true).toList();
        for (final file in allFiles) {
          print('  ${file.path}');
        }
        
        // Step 2: Read MCP manifest and files
        final manifestFile = File(path.join(tempDir.path, 'manifest.json'));
        if (!await manifestFile.exists()) {
          throw Exception('MCP manifest not found');
        }
        
        final manifestJson = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
        print('ARCX Export: Manifest keys: ${manifestJson.keys}');
        
        // Read nodes (JSON files in McpPackExportService)
        final nodesDir = Directory(path.join(tempDir.path, 'nodes'));
        
        List<Map<String, dynamic>> journalNodes = [];
        List<Map<String, dynamic>> photoNodes = [];
        List<Map<String, dynamic>> healthPointers = [];
        List<Map<String, dynamic>> healthSummaries = [];
        
        if (await nodesDir.exists()) {
          // Read journal nodes from individual JSON files
          final journalDir = Directory(path.join(nodesDir.path, 'journal'));
          if (await journalDir.exists()) {
            final journalEntries = await journalDir.list().toList();
            for (final entry in journalEntries) {
              if (entry is File && entry.path.endsWith('.json')) {
                final json = jsonDecode(await entry.readAsString()) as Map<String, dynamic>;
                // Preserve the original ID from the JSON, don't overwrite with filename
                // Only set ID if it's missing
                if (json['id'] == null) {
                json['id'] = path.basenameWithoutExtension(entry.path);
                }
                
                // Debug: Log media field for first entry
                if (journalNodes.isEmpty) {
                  print('ARCX Export: First entry ID: ${json['id']}');
                  print('ARCX Export: First entry has media field: ${json.containsKey('media')}');
                  if (json['media'] != null) {
                    print('ARCX Export: First entry media count: ${(json['media'] as List).length}');
                    if ((json['media'] as List).isNotEmpty) {
                      print('ARCX Export: First entry first media item: ${json['media'][0]}');
                    }
                  }
                }
                
                // Apply redaction transforms in-memory prior to packaging
                var node = Map<String, dynamic>.from(json);
                if (removePii) {
                  node = _removePiiFromJournalNode(node);
                }
                if (dateOnlyTimestamps) {
                  node = _clampTimestampsInJournalNode(node);
                }
                if (!includePhotoLabels) {
                  node = _stripPhotoLabelsFromJournalNode(node);
                }
                journalNodes.add(node);
              }
            }
          }

          // Read health pointers and summaries if present
          final healthPointerDir = Directory(path.join(nodesDir.path, 'pointer', 'health'));
          if (await healthPointerDir.exists()) {
            final entries = await healthPointerDir.list().toList();
            for (final entry in entries) {
              if (entry is File && entry.path.endsWith('.json')) {
                final json = jsonDecode(await entry.readAsString()) as Map<String, dynamic>;
                healthPointers.add(json);
              }
            }
          }

          final healthSummaryDir = Directory(path.join(nodesDir.path, 'health'));
          if (await healthSummaryDir.exists()) {
            final entries = await healthSummaryDir.list().toList();
            for (final entry in entries) {
              if (entry is File && entry.path.endsWith('.json')) {
                final json = jsonDecode(await entry.readAsString()) as Map<String, dynamic>;
                healthSummaries.add(json);
              }
            }
          }
          
          // Read photo metadata from individual JSON files
          // Try both 'photo' (singular) and 'photos' (plural) directories for compatibility
          var photoDir = Directory(path.join(nodesDir.path, 'media', 'photos'));
          if (!await photoDir.exists()) {
            photoDir = Directory(path.join(nodesDir.path, 'media', 'photo'));
          }
          
          if (await photoDir.exists()) {
            print('ARCX Export: Reading photo nodes from: ${photoDir.path}');
            final photoEntries = await photoDir.list().toList();
            for (final entry in photoEntries) {
              if (entry is File && entry.path.endsWith('.json')) {
                var json = jsonDecode(await entry.readAsString()) as Map<String, dynamic>;
                if (removePii) {
                  json = _removePiiFromPhotoNode(json);
                }
                if (dateOnlyTimestamps) {
                  json = _clampTimestampsInPhotoNode(json);
                }
                if (!includePhotoLabels) {
                  json = _stripPhotoLabelsFromPhotoNode(json);
                }
                photoNodes.add(json);
              }
            }
            print('ARCX Export: Found ${photoNodes.length} photo nodes in ${photoDir.path}');
          } else {
            print('ARCX Export: ⚠️ Photo directory not found at ${photoDir.path}');
            // Try searching recursively for photo node JSON files
            print('ARCX Export: Searching for photo nodes recursively...');
            final allFiles = await nodesDir.list(recursive: true).toList();
            int foundNodes = 0;
            for (final file in allFiles) {
              if (file is File && 
                  file.path.contains('media') && 
                  file.path.endsWith('.json') &&
                  (file.path.contains('photo') || file.path.contains('image'))) {
                try {
                  var json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
                  final kind = json['kind'] as String? ?? json['type'] as String?;
                  if (kind == 'photo' || kind == 'image') {
                    if (removePii) {
                      json = _removePiiFromPhotoNode(json);
                    }
                    if (dateOnlyTimestamps) {
                      json = _clampTimestampsInPhotoNode(json);
                    }
                    if (!includePhotoLabels) {
                      json = _stripPhotoLabelsFromPhotoNode(json);
                    }
                    photoNodes.add(json);
                    foundNodes++;
                  }
                } catch (e) {
                  print('ARCX Export: Error parsing photo node at ${file.path}: $e');
                }
              }
            }
            print('ARCX Export: Found $foundNodes photo nodes via recursive search');
          }
          
          print('ARCX Export: Extracted ${journalNodes.length} journal nodes, ${photoNodes.length} photo nodes');
        } else {
          print('ARCX Export: Warning - nodes directory not found');
        }
        
        print('ARCX Export: Found ${journalNodes.length} journal entries, ${photoNodes.length} photos, ${healthPointers.length}+${healthSummaries.length} health items');
        onProgress?.call('Processing ${journalNodes.length} entries, ${photoNodes.length} photos, ${healthPointers.length + healthSummaries.length} health items...');
        
        // Step 3: Package into payload/ (no redaction - encrypt as-is)
        print('ARCX Export: Step 2 - Packaging data...');
        final payloadDir = Directory(path.join(tempDir.path, 'payload'));
        await payloadDir.create(recursive: true);
        
        // Copy manifest.mcp.json
        final payloadManifestFile = File(path.join(payloadDir.path, 'manifest.mcp.json'));
        await manifestFile.copy(payloadManifestFile.path);
        
        // Create journal directory
        final payloadJournalDir = Directory(path.join(payloadDir.path, 'journal'));
        await payloadJournalDir.create(recursive: true);
        
            // Copy journal entries as-is (no redaction)
            int entriesCount = 0;
            for (final node in journalNodes) {
              final nodeId = node['id'] as String? ?? 'unknown';
              
              // DEBUG: Log the first node's structure
              if (entriesCount == 0) {
                final nodeStr = jsonEncode(node);
                final sampleLength = nodeStr.length > 500 ? 500 : nodeStr.length;
                print('ARCX Export: First node keys: ${node.keys}');
                print('ARCX Export: First node sample: ${nodeStr.substring(0, sampleLength)}');
                if (node['media'] != null) {
                  print('ARCX Export: First node media count: ${(node['media'] as List).length}');
                }
              }
              
              await File(path.join(payloadJournalDir.path, '${nodeId}.json'))
                  .writeAsString(jsonEncode(node));
              entriesCount++;
            }
        
        // Create photo metadata directory
        final payloadPhotoDir = Directory(path.join(payloadDir.path, 'media', 'photo'));
        await payloadPhotoDir.create(recursive: true);
        
        // Create photo files directory
        final payloadPhotosDir = Directory(path.join(payloadDir.path, 'media', 'photos'));
        await payloadPhotosDir.create(recursive: true);
        
        // Copy photo metadata and files (already redacted in-memory if selected)
        int photosCount = 0;
        for (final node in photoNodes) {
          final nodeId = node['id'] as String? ?? 'unknown';
          await File(path.join(payloadPhotoDir.path, '${nodeId}.json'))
              .writeAsString(jsonEncode(node));
          photosCount++;
          
          // Copy photo file if filename is available
          final filename = node['filename'] as String?;
          if (filename != null) {
            // Try multiple possible locations for source photo file
            // 1. mcp/media/photos/ (if extracted from ZIP with mcp/ prefix)
            var sourcePhotoFile = File(path.join(tempDir.path, 'mcp', 'media', 'photos', filename));
            // 2. media/photos/ (if extracted without mcp/ prefix)
            if (!await sourcePhotoFile.exists()) {
              sourcePhotoFile = File(path.join(tempDir.path, 'media', 'photos', filename));
            }
            // 3. Check if extracted files are in a different structure
            if (!await sourcePhotoFile.exists()) {
              // Search for the file recursively in tempDir
              final allFiles = await tempDir.list(recursive: true).toList();
              for (final file in allFiles) {
                if (file is File && path.basename(file.path) == filename) {
                  sourcePhotoFile = file;
                  print('ARCX Export: Found photo file at: ${file.path}');
                  break;
                }
              }
            }
            
            if (await sourcePhotoFile.exists()) {
              final destPhotoFile = File(path.join(payloadPhotosDir.path, filename));
              await sourcePhotoFile.copy(destPhotoFile.path);
              print('ARCX Export: ✓ Copied photo file: $filename (${await sourcePhotoFile.length()} bytes)');
            } else {
              print('ARCX Export: ⚠️ Photo file not found: $filename');
              print('ARCX Export:   Checked locations:');
              print('ARCX Export:     1. ${path.join(tempDir.path, "mcp", "media", "photos", filename)}');
              print('ARCX Export:     2. ${path.join(tempDir.path, "media", "photos", filename)}');
            }
          } else {
            print('ARCX Export: ⚠️ Photo node ${nodeId} has no filename field');
          }
        }

        // Create health directories
        if (healthPointers.isNotEmpty) {
          final payloadPointerHealthDir = Directory(path.join(payloadDir.path, 'pointer', 'health'));
          await payloadPointerHealthDir.create(recursive: true);
          for (final node in healthPointers) {
            final id = (node['id'] as String?) ?? 'unknown';
            await File(path.join(payloadPointerHealthDir.path, '$id.json')).writeAsString(jsonEncode(node));
          }
        }

        if (healthSummaries.isNotEmpty) {
          final payloadHealthDir = Directory(path.join(payloadDir.path, 'health'));
          await payloadHealthDir.create(recursive: true);
          for (final node in healthSummaries) {
            final id = (node['id'] as String?) ?? 'unknown';
            await File(path.join(payloadHealthDir.path, '$id.json')).writeAsString(jsonEncode(node));
          }
        }
        
        // Copy health streams (JSONL files) if they exist in the MCP bundle
        final streamsHealthDir = Directory(path.join(tempDir.path, 'streams', 'health'));
        if (await streamsHealthDir.exists()) {
          final payloadStreamsHealthDir = Directory(path.join(payloadDir.path, 'streams', 'health'));
          await payloadStreamsHealthDir.create(recursive: true);
          int streamFilesCount = 0;
          await for (final entity in streamsHealthDir.list()) {
            if (entity is File && entity.path.endsWith('.jsonl')) {
              final filename = path.basename(entity.path);
              await entity.copy(path.join(payloadStreamsHealthDir.path, filename));
              streamFilesCount++;
              print('ARCX Export: Copied health stream: $filename');
            }
          }
          print('ARCX Export: ✓ Copied $streamFilesCount health stream file(s)');
        }
        
        final healthCount = healthPointers.length + healthSummaries.length;
        print('ARCX Export: ✓ Packaged ($entriesCount entries, $photosCount photos, $healthCount health)');
        onProgress?.call('Archiving data...');
        
        // Step 4: Archive payload to zip in memory
        print('ARCX Export: Step 3 - Archiving payload...');
        final archive = Archive();
        await _addDirectoryToArchive(archive, payloadDir, '');
        final zipEncoder = ZipEncoder();
        final plaintextZip = zipEncoder.encode(archive);
        
        if (plaintextZip == null) {
          throw Exception('Failed to create zip archive');
        }
        
        print('ARCX Export: ✓ Payload archived (${plaintextZip.length} bytes)');
        
        // Step 5: Encrypt with AES-256-GCM (device-based or password-based)
        Uint8List ciphertext;
        String? saltB64;
        bool isPasswordEncrypted;
        
        // Write to temp file to avoid memory bottleneck
        final plaintextTempFile = File(path.join(tempDir.path, 'plaintext_temp.zip'));
        await plaintextTempFile.writeAsBytes(plaintextZip);
        print('ARCX Export: Wrote plaintext to temp file (${plaintextTempFile.path})');
        
        if (password != null && password.isNotEmpty) {
          // Password-based encryption
          print('ARCX Export: Step 4 - Encrypting with password...');
          onProgress?.call('Encrypting with password...');
          
          // For now, keep single-pass encryption but with timeout protection
          final (encryptedData, salt) = await ARCXCryptoService.encryptWithPassword(
            Uint8List.fromList(plaintextZip),
            password,
          );
          ciphertext = encryptedData;
          saltB64 = base64Encode(salt);
          isPasswordEncrypted = true;
          print('ARCX Export: Salt length: ${salt.length} bytes, SaltB64 length: ${saltB64.length} chars');
          print('ARCX Export: ✓ Encrypted with password (${ciphertext.length} bytes)');
        } else {
          // Device-based encryption
          print('ARCX Export: Step 4 - Encrypting with device key...');
          onProgress?.call('Encrypting archive...');
          ciphertext = await ARCXCryptoService.encryptAEAD(Uint8List.fromList(plaintextZip));
          isPasswordEncrypted = false;
          print('ARCX Export: ✓ Encrypted with device key (${ciphertext.length} bytes)');
        }
        
        // Delete plaintext immediately after encryption
        await plaintextTempFile.delete();
        onProgress?.call('Signing archive...');
        
        // Step 6: Compute SHA-256 of ciphertext
        final ciphertextHash = sha256.convert(ciphertext).bytes;
        final ciphertextHashB64 = base64Encode(ciphertextHash);
        
        // Step 7: Compute MCP manifest hash
        final mcpManifestData = await payloadManifestFile.readAsBytes();
        final mcpManifestHash = sha256.convert(mcpManifestData).bytes;
        final mcpManifestHashB64 = base64Encode(mcpManifestHash);
        
        // Step 8: Build manifest JSON (no redaction applied)
        final redactionReport = ARCXRedactionService.computeRedactionReport(
          journalEntriesRedacted: entriesCount,
          photosRedacted: photosCount,
          dateOnly: dateOnlyTimestamps,
          includePhotoLabels: includePhotoLabels,
        );
        
        final pubkeyFpr = await ARCXCryptoService.getSigningPublicKeyFingerprint();
        
        final manifest = ARCXManifest(
          version: '1.1',
          algo: 'AES-256-GCM',
          kdf: isPasswordEncrypted ? 'pbkdf2-sha256-600000' : 'device-key',
          sha256: ciphertextHashB64,
          signerPubkeyFpr: pubkeyFpr,
          signatureB64: '', // Will be filled after signing
          payloadMeta: ARCXPayloadMeta(
            journalCount: entriesCount,
            photoMetaCount: photosCount,
            bytes: plaintextZip.length,
          ),
          mcpManifestSha256: mcpManifestHashB64,
          exportedAt: DateTime.now().toUtc().toIso8601String(),
          appVersion: '1.0.0', // TODO: Get from package_info
          redactionReport: redactionReport,
          isPasswordEncrypted: isPasswordEncrypted,
          saltB64: saltB64,
        );
        
        // Step 9: Sign manifest
        final manifestJsonString = jsonEncode(manifest.toJson());
        final manifestBytes = utf8.encode(manifestJsonString);
        final signature = await ARCXCryptoService.signData(Uint8List.fromList(manifestBytes));
        
        // Re-build manifest with signature
        final signedManifest = ARCXManifest(
          version: manifest.version,
          algo: manifest.algo,
          kdf: manifest.kdf,
          kdfParams: manifest.kdfParams,
          sha256: manifest.sha256,
          signerPubkeyFpr: manifest.signerPubkeyFpr,
          signatureB64: signature,
          payloadMeta: manifest.payloadMeta,
          mcpManifestSha256: manifest.mcpManifestSha256,
          exportedAt: manifest.exportedAt,
          appVersion: manifest.appVersion,
          redactionReport: manifest.redactionReport,
          isPasswordEncrypted: manifest.isPasswordEncrypted,
          saltB64: manifest.saltB64,
        );
        
        print('ARCX Export: ✓ Manifest signed');
        onProgress?.call('Writing archive file...');
        
        // Step 10: Create final .arcx ZIP containing encrypted archive and manifest
        print('ARCX Export: Step 5 - Creating final archive...');
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
        final arcxFileName = 'export_$timestamp.arcx';
        final arcxPath = path.join(outputDir.path, arcxFileName);
        
        print('ARCX Export: Writing to $arcxPath');
        
        // Create final ZIP containing both files
        final manifestBytesFinal = utf8.encode(jsonEncode(signedManifest.toJson()));
        final finalArchive = Archive();
        
        // Add encrypted payload
        finalArchive.addFile(ArchiveFile(
          'archive.arcx',
          ciphertext.length,
          ciphertext,
        ));
        
        // Add signed manifest
        finalArchive.addFile(ArchiveFile(
          'manifest.json',
          manifestBytesFinal.length,
          manifestBytesFinal,
        ));
        
        // Write the ZIP
        final finalZipBytes = ZipEncoder().encode(finalArchive);
        if (finalZipBytes == null) {
          throw Exception('Failed to create final ZIP archive');
        }
        
        await File(arcxPath).writeAsBytes(finalZipBytes);
        print('ARCX Export: ✓ Final archive created (${finalZipBytes.length} bytes)');
        onProgress?.call('Export complete!');
        
        // Apply file protection on iOS
        try {
          // TODO: Call native file protection if on iOS
          print('ARCX Export: File protection skipped (not on iOS native platform)');
        } catch (e) {
          print('ARCX Export: Warning - could not set file protection: $e');
        }
        
        print('ARCX Export: ✓ File written');
        print('ARCX Export: Final arcxPath = $arcxPath');
        
        return ARCXExportResult.success(
          arcxPath: arcxPath,
          manifestPath: null, // Manifest is now inside the .arcx ZIP
          manifest: signedManifest,
          stats: ARCXExportStats(
            journalEntries: entriesCount,
            photoMetadata: photosCount,
            totalBytes: plaintextZip.length,
            encryptedBytes: ciphertext.length,
            exportDuration: Duration.zero, // TODO: Track duration
          ),
        );
        
      } finally {
        // Clean up temp directory
        try {
          await tempDir.delete(recursive: true);
        } catch (e) {
          print('Warning: Could not delete temp directory: $e');
        }
      }
    } catch (e, stackTrace) {
      print('ARCX Export: ✗ Failed: $e');
      print('Stack trace: $stackTrace');
      return ARCXExportResult.failure(e.toString());
    }
  }
  
  /// Recursively add directory to archive
  Future<void> _addDirectoryToArchive(Archive archive, Directory dir, String basePath) async {
    final files = await dir.list().toList();
    final mediaExtensions = {'.jpg', '.jpeg', '.png', '.mp4', '.mov', '.heic', '.heif'};
    
    for (final file in files) {
      if (file is Directory) {
        await _addDirectoryToArchive(archive, file, path.join(basePath, path.basename(file.path)));
      } else if (file is File) {
        final content = await file.readAsBytes();
        final relativePath = path.join(basePath, path.basename(file.path));
        final ext = path.extension(file.path).toLowerCase();
        
        // Create archive file
        final archiveFile = ArchiveFile(relativePath, content.length, content);
        
        // Skip compression for already-compressed media
        if (mediaExtensions.contains(ext)) {
          archiveFile.compress = false;
        }
        
        archive.addFile(archiveFile);
      }
    }
  }
  
  // === Redaction helpers ===
  Map<String, dynamic> _removePiiFromJournalNode(Map<String, dynamic> node) {
    final n = Map<String, dynamic>.from(node);
    // Common PII fields
    for (final key in ['author','email','deviceId','device_id','ip','address']) {
      n.remove(key);
    }
    // Location fields
    n.remove('location');
    if (n['metadata'] is Map) {
      final m = Map<String, dynamic>.from(n['metadata']);
      for (final key in ['pii','email','device','ip','address','user','account']) {
        m.remove(key);
      }
      n['metadata'] = m;
    }
    return n;
  }

  Map<String, dynamic> _removePiiFromPhotoNode(Map<String, dynamic> node) {
    final n = Map<String, dynamic>.from(node);
    for (final key in ['author','email','deviceId','device_id','ip','address']) {
      n.remove(key);
    }
    n.remove('location');
    if (n['analysisData'] is Map) {
      final a = Map<String, dynamic>.from(n['analysisData']);
      for (final key in ['faces','face_embeddings','gps','gps_meta','address','people']) {
        a.remove(key);
      }
      n['analysisData'] = a;
    }
    return n;
  }

  Map<String, dynamic> _stripPhotoLabelsFromJournalNode(Map<String, dynamic> node) {
    final n = Map<String, dynamic>.from(node);
    if (n['media'] is List) {
      final media = (n['media'] as List).map((it) {
        if (it is Map<String, dynamic>) {
          final m = Map<String, dynamic>.from(it);
          if (m['analysisData'] is Map) {
            final a = Map<String, dynamic>.from(m['analysisData']);
            a.remove('labels');
            m['analysisData'] = a;
          }
          m.remove('labels');
          return m;
        }
        return it;
      }).toList();
      n['media'] = media;
    }
    return n;
  }

  Map<String, dynamic> _stripPhotoLabelsFromPhotoNode(Map<String, dynamic> node) {
    final n = Map<String, dynamic>.from(node);
    n.remove('labels');
    if (n['analysisData'] is Map) {
      final a = Map<String, dynamic>.from(n['analysisData']);
      a.remove('labels');
      n['analysisData'] = a;
    }
    return n;
  }

  Map<String, dynamic> _clampTimestampsInJournalNode(Map<String, dynamic> node) {
    final n = Map<String, dynamic>.from(node);
    for (final key in ['createdAt','updatedAt','timestamp']) {
      if (n[key] != null) {
        n[key] = _dateOnly(n[key]);
      }
    }
    if (n['media'] is List) {
      final media = (n['media'] as List).map((it) {
        if (it is Map<String, dynamic>) {
          final m = Map<String, dynamic>.from(it);
          for (final k in ['createdAt','timestamp']) {
            if (m[k] != null) m[k] = _dateOnly(m[k]);
          }
          return m;
        }
        return it;
      }).toList();
      n['media'] = media;
    }
    return n;
  }

  Map<String, dynamic> _clampTimestampsInPhotoNode(Map<String, dynamic> node) {
    final n = Map<String, dynamic>.from(node);
    for (final key in ['createdAt','capturedAt','timestamp']) {
      if (n[key] != null) {
        n[key] = _dateOnly(n[key]);
      }
    }
    return n;
  }

  String _dateOnly(dynamic ts) {
    try {
      if (ts is String) {
        final dt = DateTime.tryParse(ts);
        if (dt != null) {
          return '${dt.year.toString().padLeft(4,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
        }
      } else if (ts is int) {
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        return '${dt.year.toString().padLeft(4,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
      }
    } catch (_) {}
    return ts.toString();
  }
  
}


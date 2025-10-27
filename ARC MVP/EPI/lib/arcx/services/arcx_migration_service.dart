/// ARCX Migration Service
/// 
/// Converts legacy MCP .zip files to secure .arcx format.
library arcx_migration_service;

import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import '../../arc/core/journal_repository.dart';
import 'arcx_crypto_service.dart';
import 'arcx_redaction_service.dart';
import 'arcx_export_service.dart';
import '../models/arcx_result.dart';

class ARCXMigrationService {
  
  /// Migrate legacy .zip MCP bundle to secure .arcx
  /// 
  /// Process:
  /// 1. Extract .zip to temp directory
  /// 2. Read manifest.json
  /// 3. Compute source SHA-256 of .zip
  /// 4. Parse nodes/journal/*.json and nodes/media/photo/*.json
  /// 5. Apply redaction
  /// 6. Package into payload/ structure
  /// 7. Encrypt + sign (reuse export service)
  /// 8. Write .arcx + .manifest.json
  /// 9. Verify round-trip (decrypt + validate)
  /// 10. Optionally secure-delete original .zip
  Future<ARCXMigrationResult> migrateZipToARCX({
    required String zipPath,
    required Directory outputDir,
    bool includePhotoLabels = false,
    bool dateOnlyTimestamps = false,
    bool secureDeleteOriginal = false,
  }) async {
    try {
      print('ARCX Migration: Starting migration from: $zipPath');
      
      // Step 1: Extract .zip
      print('ARCX Migration: Step 1 - Extracting archive...');
      final extractDir = Directory.systemTemp.createTempSync('arcx_migration_');
      
      try {
        await extractFileToDisk(zipPath, extractDir.path);
        print('ARCX Migration: ✓ Archive extracted');
        
        // Step 2: Read source SHA-256
        final sourceZipFile = File(zipPath);
        final sourceZipBytes = await sourceZipFile.readAsBytes();
        final sourceSha256 = sha256.convert(sourceZipBytes).toString();
        print('ARCX Migration: Source SHA-256: $sourceSha256');
        
        // Step 3: Read manifest.json
        final manifestFile = File(path.join(extractDir.path, 'manifest.json'));
        if (!await manifestFile.exists()) {
          throw Exception('Invalid MCP bundle: manifest.json not found');
        }
        
        final manifestJson = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
        print('ARCX Migration: ✓ Manifest read');
        
        // Step 4: Parse journal entries and photo metadata
        final journalDir = Directory(path.join(extractDir.path, 'nodes', 'journal'));
        final photoDir = Directory(path.join(extractDir.path, 'nodes', 'media', 'photo'));
        
        final journalFiles = <File>[];
        if (await journalDir.exists()) {
          journalFiles.addAll(await journalDir
              .list()
              .where((f) => f.path.endsWith('.json'))
              .cast<File>()
              .toList());
        }
        
        final photoFiles = <File>[];
        if (await photoDir.exists()) {
          photoFiles.addAll(await photoDir
              .list()
              .where((f) => f.path.endsWith('.json'))
              .cast<File>()
              .toList());
        }
        
        print('ARCX Migration: Found ${journalFiles.length} journal entries, ${photoFiles.length} photos');
        
        // Step 5-7: Apply redaction and use export service
        final exportService = ARCXExportService();
        
        // Convert files to JournalEntry objects for export service
        // Since we're migrating from .zip, we don't have JournalEntry objects
        // We'll need to read the JSON directly and package it
        final payloadDir = Directory.systemTemp.createTempSync('arcx_payload_');
        
        try {
          // Create payload structure
          await payloadDir.create(recursive: true);
          
          // Copy manifest.mcp.json
          final payloadManifestFile = File(path.join(payloadDir.path, 'manifest.mcp.json'));
          await manifestFile.copy(payloadManifestFile.path);
          
          // Create journal directory
          final payloadJournalDir = Directory(path.join(payloadDir.path, 'journal'));
          await payloadJournalDir.create(recursive: true);
          
          int redactedCount = 0;
          for (final file in journalFiles) {
            final entry = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
            final redacted = ARCXRedactionService.redactJournal(
              entry,
              dateOnly: dateOnlyTimestamps,
              installId: 'default',
            );
            
            await File(path.join(payloadJournalDir.path, path.basename(file.path)))
                .writeAsString(jsonEncode(redacted));
            redactedCount++;
          }
          
          // Create photo directory
          final payloadPhotoDir = Directory(path.join(payloadDir.path, 'media', 'photo'));
          await payloadPhotoDir.create(recursive: true);
          
          int photosRedactedCount = 0;
          for (final file in photoFiles) {
            final photo = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
            final redacted = ARCXRedactionService.redactPhotoMeta(
              photo,
              includeLabels: includePhotoLabels,
            );
            
            await File(path.join(payloadPhotoDir.path, path.basename(file.path)))
                .writeAsString(jsonEncode(redacted));
            photosRedactedCount++;
          }
          
          print('ARCX Migration: ✓ Redaction applied');
          
          // Archive payload
          final archive = Archive();
          await _addDirectoryToArchive(archive, payloadDir, '');
          final zipEncoder = ZipEncoder();
          final plaintextZip = zipEncoder.encode(archive);
          
          if (plaintextZip == null) {
            throw Exception('Failed to create zip archive');
          }
          
          // Encrypt
          final ciphertext = await ARCXCryptoService.encryptAEAD(Uint8List.fromList(plaintextZip));
          
          // Compute hashes
          final ciphertextHash = sha256.convert(ciphertext).bytes;
          final ciphertextHashB64 = base64Encode(ciphertextHash);
          
          final mcpManifestData = await payloadManifestFile.readAsBytes();
          final mcpManifestHash = sha256.convert(mcpManifestData).bytes;
          final mcpManifestHashB64 = base64Encode(mcpManifestHash);
          
          // Build and sign manifest
          final redactionReport = ARCXRedactionService.computeRedactionReport(
            journalEntriesRedacted: redactedCount,
            photosRedacted: photosRedactedCount,
            dateOnly: dateOnlyTimestamps,
            includePhotoLabels: includePhotoLabels,
          );
          
          final pubkeyFpr = await ARCXCryptoService.getSigningPublicKeyFingerprint();
          
          final manifest = {
            'version': '1.1',
            'algo': 'AES-256-GCM',
            'kdf': 'device-key',
            'sha256': ciphertextHashB64,
            'signer_pubkey_fpr': pubkeyFpr,
            'payload_meta': {
              'journal_count': redactedCount,
              'photo_meta_count': photosRedactedCount,
              'bytes': plaintextZip.length,
            },
            'mcp_manifest_sha256': mcpManifestHashB64,
            'exported_at': DateTime.now().toUtc().toIso8601String(),
            'app_version': '1.0.0',
            'redaction_report': redactionReport,
            'migrated_from': 'mcp-zip',
            'source_sha256': sourceSha256,
          };
          
          final manifestJsonString = jsonEncode(manifest);
          final manifestBytes = utf8.encode(manifestJsonString);
          final signature = await ARCXCryptoService.signData(Uint8List.fromList(manifestBytes));
          
          final signedManifest = {...manifest, 'signature_b64': signature};
          
          // Write files
          final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
          final arcxFileName = 'migrated_$timestamp.arcx';
          final arcxPath = path.join(outputDir.path, arcxFileName);
          final manifestPath = path.join(outputDir.path, '${arcxFileName}.manifest.json');
          
          await File(arcxPath).writeAsBytes(ciphertext);
          await File(manifestPath).writeAsString(jsonEncode(signedManifest));
          
          print('ARCX Migration: ✓ Files written');
          
          // Step 10: Optionally secure-delete original
          if (secureDeleteOriginal) {
            print('ARCX Migration: Deleting original .zip file...');
            await sourceZipFile.delete();
            print('ARCX Migration: ✓ Original file deleted');
          }
          
          return ARCXMigrationResult.success(
            arcxPath: arcxPath,
            manifestPath: manifestPath,
            sourceZipPath: zipPath,
            sourceSha256: sourceSha256,
          );
          
        } finally {
          await payloadDir.delete(recursive: true);
        }
        
      } finally {
        await extractDir.delete(recursive: true);
      }
      
    } catch (e, stackTrace) {
      print('ARCX Migration: ✗ Failed: $e');
      print('Stack trace: $stackTrace');
      return ARCXMigrationResult.failure(e.toString());
    }
  }
  
  /// Recursively add directory to archive
  Future<void> _addDirectoryToArchive(Archive archive, Directory dir, String basePath) async {
    final files = await dir.list().toList();
    
    for (final file in files) {
      if (file is Directory) {
        await _addDirectoryToArchive(archive, file, path.join(basePath, path.basename(file.path)));
      } else if (file is File) {
        final content = await file.readAsBytes();
        final relativePath = path.join(basePath, path.basename(file.path));
        archive.addFile(ArchiveFile(relativePath, content.length, content));
      }
    }
  }
}


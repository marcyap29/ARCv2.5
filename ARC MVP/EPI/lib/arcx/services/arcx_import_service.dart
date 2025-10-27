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
import '../../models/journal_entry_model.dart';
import '../../arc/core/journal_repository.dart';
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
  /// 4. Decrypt with AES-256-GCM (throws on bad tag)
  /// 5. Extract and validate payload/ structure
  /// 6. Verify MCP manifest hash
  /// 7. Convert to JournalEntry objects
  /// 8. Merge into JournalRepository
  Future<ARCXImportResult> importSecure({
    required String arcxPath,
    String? manifestPath,
    bool dryRun = false,
  }) async {
    try {
      print('ARCX Import: Starting secure import from: $arcxPath');
      
      // Step 1: Load files
      final arcxFile = File(arcxPath);
      if (!await arcxFile.exists()) {
        throw Exception('ARCX file not found: $arcxPath');
      }
      
      // Try to find manifest path if not provided
      String? actualManifestPath = manifestPath;
      if (actualManifestPath == null) {
        actualManifestPath = arcxPath.replaceFirst('.arcx', '.manifest.json');
      }
      
      final manifestFile = File(actualManifestPath);
      if (!await manifestFile.exists()) {
        throw Exception('Manifest file not found: $actualManifestPath');
      }
      
      print('ARCX Import: ✓ Files loaded');
      
      // Step 2: Parse and validate manifest
      final manifestJson = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      final manifest = ARCXManifest.fromJson(manifestJson);
      
      if (!manifest.validate()) {
        throw Exception('Invalid manifest structure');
      }
      
      print('ARCX Import: ✓ Manifest validated');
      
      // Step 3: Verify signature
      print('ARCX Import: Step 1 - Verifying signature...');
      final manifestBytes = utf8.encode(jsonEncode(manifest.toJson()));
      final isValid = await ARCXCryptoService.verifySignature(
        Uint8List.fromList(manifestBytes),
        manifest.signatureB64,
      );
      
      if (!isValid) {
        throw Exception('Signature verification failed - archive may be tampered');
      }
      
      print('ARCX Import: ✓ Signature verified');
      
      // Step 4: Verify ciphertext hash
      print('ARCX Import: Step 2 - Verifying ciphertext hash...');
      final ciphertext = await arcxFile.readAsBytes();
      final ciphertextHash = sha256.convert(ciphertext).bytes;
      final ciphertextHashB64 = base64Encode(ciphertextHash);
      
      if (ciphertextHashB64 != manifest.sha256) {
        throw Exception('Ciphertext hash mismatch - file may be corrupted');
      }
      
      print('ARCX Import: ✓ Ciphertext hash verified');
      
      // Step 5: Decrypt
      print('ARCX Import: Step 3 - Decrypting...');
      final plaintextZip = await ARCXCryptoService.decryptAEAD(ciphertext);
      
      print('ARCX Import: ✓ Decrypted (${plaintextZip.length} bytes)');
      
      // Step 6: Extract and validate payload structure
      print('ARCX Import: Step 4 - Extracting payload...');
      final archive = ZipDecoder().decodeBytes(plaintextZip);
      
      final payloadDir = Directory.systemTemp.createTempSync('arcx_import_');
      
      try {
        // Extract to temp directory
        for (final file in archive) {
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
        
        // Step 8: Read and convert journal entries
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
        
        int entriesImported = 0;
        final warnings = <String>[];
        
        for (final file in journalFiles) {
          try {
            final entryJson = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
            final entry = JournalEntry.fromJson(entryJson);
            
            if (!dryRun && _journalRepo != null) {
              await _journalRepo!.createJournalEntry(entry);
            }
            
            entriesImported++;
          } catch (e) {
            warnings.add('Failed to import entry ${path.basename(file.path)}: $e');
          }
        }
        
        // Step 9: Read photo metadata (files only, no actual photos)
        final photoDir = Directory(path.join(payloadDir.path, 'media', 'photo'));
        int photosImported = 0;
        
        if (await photoDir.exists()) {
          final photoFiles = await photoDir
              .list()
              .where((f) => f.path.endsWith('.json'))
              .cast<File>()
              .toList();
          
          photosImported = photoFiles.length;
          print('ARCX Import: Found $photosImported photo metadata files (photos not included in archive)');
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
}


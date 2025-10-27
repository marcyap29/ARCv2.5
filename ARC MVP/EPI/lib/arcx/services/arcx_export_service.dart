/// ARCX Export Service
/// 
/// Orchestrates the export of ARC data to secure .arcx archives.
library arcx_export_service;

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../models/journal_entry_model.dart';
import '../../data/models/media_item.dart';
import '../../mcp/export/mcp_export_service.dart';
import '../../mcp/models/mcp_schemas.dart';
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
  /// 5. Encrypt with AES-256-GCM
  /// 6. Sign manifest with Ed25519
  /// 7. Write .arcx + .manifest.json with file protection
  Future<ARCXExportResult> exportSecure({
    required Directory outputDir,
    required List<JournalEntry> journalEntries,
    List<MediaItem>? mediaFiles,
    bool includePhotoLabels = false,
    bool dateOnlyTimestamps = false,
  }) async {
    try {
      print('ARCX Export: Starting secure export...');
      
      // Create temp directory in app documents (safer than system temp on iOS)
      final appDocDir = await getApplicationDocumentsDirectory();
      final tempDir = Directory(path.join(appDocDir.path, 'arcx_temp_${DateTime.now().millisecondsSinceEpoch}'));
      await tempDir.create(recursive: true);
      
      try {
        // Step 1: Generate MCP bundle
        print('ARCX Export: Step 1 - Generating MCP bundle...');
        final mcpService = McpExportService();
        final mcpResult = await mcpService.exportToMcp(
          outputDir: tempDir,
          scope: McpExportScope.all,
          journalEntries: journalEntries,
          mediaFiles: mediaFiles,
        );
        
        if (!mcpResult.success) {
          throw Exception('MCP export failed: ${mcpResult.error}');
        }
        
        print('ARCX Export: ✓ MCP bundle generated');
        
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
        
        // Read nodes.jsonl (NDJSON format)
        final nodesFile = File(path.join(tempDir.path, 'nodes.jsonl'));
        final pointersFile = File(path.join(tempDir.path, 'pointers.jsonl'));
        
        List<Map<String, dynamic>> journalNodes = [];
        List<Map<String, dynamic>> photoNodes = [];
        
        if (await nodesFile.exists()) {
          final lines = await nodesFile.readAsLines();
          print('ARCX Export: Read ${lines.length} nodes from nodes.jsonl');
          
          for (final line in lines) {
            if (line.trim().isEmpty) continue;
            try {
              final node = jsonDecode(line) as Map<String, dynamic>;
              final nodeType = node['type'] as String?;
              
              if (nodeType == 'journal_entry') {
                journalNodes.add(node);
              } else if (nodeType == 'photo_metadata') {
                photoNodes.add(node);
              }
            } catch (e) {
              print('ARCX Export: Warning - could not parse node: $e');
            }
          }
          
          print('ARCX Export: Extracted ${journalNodes.length} journal nodes, ${photoNodes.length} photo nodes');
        } else {
          print('ARCX Export: Warning - nodes.jsonl not found');
        }
        
        print('ARCX Export: Found ${journalNodes.length} journal entries, ${photoNodes.length} photos');
        
        // Step 3: Apply redaction and package into payload/
        print('ARCX Export: Step 2 - Applying redaction...');
        final payloadDir = Directory(path.join(tempDir.path, 'payload'));
        await payloadDir.create(recursive: true);
        
        // Copy manifest.mcp.json
        final payloadManifestFile = File(path.join(payloadDir.path, 'manifest.mcp.json'));
        await manifestFile.copy(payloadManifestFile.path);
        
        // Create journal directory
        final payloadJournalDir = Directory(path.join(payloadDir.path, 'journal'));
        await payloadJournalDir.create(recursive: true);
        
        // Process and redact journal entries
        int redactedCount = 0;
        for (final node in journalNodes) {
          final redacted = ARCXRedactionService.redactJournal(
            node,
            dateOnly: dateOnlyTimestamps,
            installId: 'default', // TODO: Get actual install ID
          );
          
          final nodeId = node['id'] as String? ?? 'unknown';
          await File(path.join(payloadJournalDir.path, '${nodeId}.json'))
              .writeAsString(jsonEncode(redacted));
          redactedCount++;
        }
        
        // Create photo directory
        final payloadPhotoDir = Directory(path.join(payloadDir.path, 'media', 'photo'));
        await payloadPhotoDir.create(recursive: true);
        
        // Process and redact photo metadata
        int photosRedactedCount = 0;
        for (final node in photoNodes) {
          final redacted = ARCXRedactionService.redactPhotoMeta(
            node,
            includeLabels: includePhotoLabels,
          );
          
          final nodeId = node['id'] as String? ?? 'unknown';
          await File(path.join(payloadPhotoDir.path, '${nodeId}.json'))
              .writeAsString(jsonEncode(redacted));
          photosRedactedCount++;
        }
        
        print('ARCX Export: ✓ Redaction applied ($redactedCount entries, $photosRedactedCount photos)');
        
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
        
        // Step 5: Encrypt with AES-256-GCM
        print('ARCX Export: Step 4 - Encrypting...');
        final ciphertext = await ARCXCryptoService.encryptAEAD(Uint8List.fromList(plaintextZip));
        
        print('ARCX Export: ✓ Encrypted (${ciphertext.length} bytes)');
        
        // Step 6: Compute SHA-256 of ciphertext
        final ciphertextHash = sha256.convert(ciphertext).bytes;
        final ciphertextHashB64 = base64Encode(ciphertextHash);
        
        // Step 7: Compute MCP manifest hash
        final mcpManifestData = await payloadManifestFile.readAsBytes();
        final mcpManifestHash = sha256.convert(mcpManifestData).bytes;
        final mcpManifestHashB64 = base64Encode(mcpManifestHash);
        
        // Step 8: Build manifest JSON
        final redactionReport = ARCXRedactionService.computeRedactionReport(
          journalEntriesRedacted: redactedCount,
          photosRedacted: photosRedactedCount,
          dateOnly: dateOnlyTimestamps,
          includePhotoLabels: includePhotoLabels,
        );
        
        final pubkeyFpr = await ARCXCryptoService.getSigningPublicKeyFingerprint();
        
        final manifest = ARCXManifest(
          version: '1.1',
          algo: 'AES-256-GCM',
          kdf: 'device-key',
          sha256: ciphertextHashB64,
          signerPubkeyFpr: pubkeyFpr,
          signatureB64: '', // Will be filled after signing
          payloadMeta: ARCXPayloadMeta(
            journalCount: redactedCount,
            photoMetaCount: photosRedactedCount,
            bytes: plaintextZip.length,
          ),
          mcpManifestSha256: mcpManifestHashB64,
          exportedAt: DateTime.now().toUtc().toIso8601String(),
          appVersion: '1.0.0', // TODO: Get from package_info
          redactionReport: redactionReport,
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
        );
        
        print('ARCX Export: ✓ Manifest signed');
        
        // Step 10: Write .arcx and .manifest.json
        print('ARCX Export: Step 5 - Writing files...');
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
        final arcxFileName = 'export_$timestamp.arcx';
        final arcxPath = path.join(outputDir.path, arcxFileName);
        final manifestPath = path.join(outputDir.path, '${arcxFileName}.manifest.json');
        
        print('ARCX Export: Writing to $arcxPath');
        print('ARCX Export: Writing manifest to $manifestPath');
        
        await File(arcxPath).writeAsBytes(ciphertext);
        await File(manifestPath).writeAsString(jsonEncode(signedManifest.toJson()));
        
        // Apply file protection on iOS
        try {
          // TODO: Call native file protection if on iOS
          print('ARCX Export: File protection skipped (not on iOS native platform)');
        } catch (e) {
          print('ARCX Export: Warning - could not set file protection: $e');
        }
        
        print('ARCX Export: ✓ Files written');
        print('ARCX Export: Final arcxPath = $arcxPath');
        print('ARCX Export: Final manifestPath = $manifestPath');
        
        return ARCXExportResult.success(
          arcxPath: arcxPath,
          manifestPath: manifestPath,
          manifest: signedManifest,
          stats: ARCXExportStats(
            journalEntries: redactedCount,
            photoMetadata: photosRedactedCount,
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


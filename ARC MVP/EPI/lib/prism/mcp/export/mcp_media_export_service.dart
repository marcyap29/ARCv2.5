// lib/prism/mcp/export/mcp_media_export_service.dart
// MCP Media Export Service for handling media files in MCP bundles

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

class McpMediaExportService {
  static const String _mediaDirName = 'media';
  static const String _metadataFileName = 'metadata.json';

  /// Export media files to MCP bundle
  static Future<Map<String, dynamic>> exportMediaFiles({
    required List<File> mediaFiles,
    required String bundlePath,
    Map<String, dynamic>? metadata,
  }) async {
    final mediaDir = Directory(path.join(bundlePath, _mediaDirName));
    await mediaDir.create(recursive: true);

    final exportedFiles = <Map<String, dynamic>>[];
    final totalSize = <int, int>{0: 0}; // Using map to avoid final variable issue

    for (final file in mediaFiles) {
      if (await file.exists()) {
        final fileName = path.basename(file.path);
        final targetPath = path.join(mediaDir.path, fileName);
        final targetFile = File(targetPath);
        
        // Copy file
        await file.copy(targetPath);
        
        // Calculate checksums
        final fileBytes = await file.readAsBytes();
        final sha256 = sha256.convert(fileBytes).toString();
        final crc32 = _calculateCrc32(fileBytes);
        
        // Get file stats
        final stat = await file.stat();
        
        exportedFiles.add({
          'originalPath': file.path,
          'exportedPath': targetPath,
          'fileName': fileName,
          'sizeBytes': stat.size,
          'sha256': sha256,
          'crc32': crc32,
          'lastModified': stat.modified.toIso8601String(),
        });
        
        totalSize[0] = totalSize[0]! + stat.size;
      }
    }

    // Write metadata
    final metadataFile = File(path.join(mediaDir.path, _metadataFileName));
    await metadataFile.writeAsString(jsonEncode({
      'exportedAt': DateTime.now().toIso8601String(),
      'totalFiles': exportedFiles.length,
      'totalSizeBytes': totalSize[0],
      'files': exportedFiles,
      'customMetadata': metadata ?? {},
    }));

    return {
      'success': true,
      'exportedFiles': exportedFiles,
      'totalSizeBytes': totalSize[0],
      'mediaDir': mediaDir.path,
    };
  }

  /// Import media files from MCP bundle
  static Future<Map<String, dynamic>> importMediaFiles({
    required String bundlePath,
    required String targetDir,
  }) async {
    final mediaDir = Directory(path.join(bundlePath, _mediaDirName));
    
    if (!await mediaDir.exists()) {
      return {
        'success': false,
        'error': 'Media directory not found in bundle',
      };
    }

    final metadataFile = File(path.join(mediaDir.path, _metadataFileName));
    if (!await metadataFile.exists()) {
      return {
        'success': false,
        'error': 'Media metadata not found',
      };
    }

    final metadata = jsonDecode(await metadataFile.readAsString());
    final files = metadata['files'] as List<dynamic>;
    final importedFiles = <Map<String, dynamic>>[];

    for (final fileInfo in files) {
      final fileName = fileInfo['fileName'] as String;
      final sourcePath = path.join(mediaDir.path, fileName);
      final targetPath = path.join(targetDir, fileName);
      
      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        await sourceFile.copy(targetPath);
        importedFiles.add({
          'fileName': fileName,
          'targetPath': targetPath,
          'sizeBytes': fileInfo['sizeBytes'],
        });
      }
    }

    return {
      'success': true,
      'importedFiles': importedFiles,
      'totalFiles': importedFiles.length,
    };
  }

  /// Calculate CRC32 checksum
  static int _calculateCrc32(List<int> bytes) {
    int crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc ^= byte;
      for (int i = 0; i < 8; i++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ 0xEDB88320;
        } else {
          crc >>= 1;
        }
      }
    }
    return crc ^ 0xFFFFFFFF;
  }
}

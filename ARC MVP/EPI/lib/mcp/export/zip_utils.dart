import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

class ZipUtils {
  /// Create a zip archive of [sourceDir].
  /// Returns the created zip [File].
  static Future<File> zipDirectory(Directory sourceDir, {String? zipFileName}) async {
    final archive = Archive();

    final String basePath = sourceDir.path;
    await for (final entity in sourceDir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final filePath = entity.path;
        // Make a relative path inside the archive
        final String relativePath = filePath.startsWith(basePath)
            ? filePath.substring(basePath.length + 1)
            : filePath;
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      }
    }

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    if (zipBytes == null) {
      throw Exception('Failed to encode ZIP');
    }

    final String zipName = (zipFileName != null && zipFileName.isNotEmpty)
        ? (zipFileName.endsWith('.zip') ? zipFileName : '$zipFileName.zip')
        : '${sourceDir.uri.pathSegments.isNotEmpty ? sourceDir.uri.pathSegments.last : 'mcp_bundle'}.zip';

    final zipFile = File('${sourceDir.parent.path}/$zipName');
    await zipFile.writeAsBytes(zipBytes, flush: true);
    return zipFile;
  }

  /// Extract a zip file to a directory.
  /// Returns the extracted directory.
  static Future<Directory> extractZip(File zipFile, {String? extractTo}) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    
    final String extractPath = extractTo ?? 
        path.join(zipFile.parent.path, 'extracted_${DateTime.now().millisecondsSinceEpoch}');
    final extractDir = Directory(extractPath);
    
    if (!await extractDir.exists()) {
      await extractDir.create(recursive: true);
    }

    for (final file in archive.files) {
      if (file.isFile) {
        final filePath = path.join(extractDir.path, file.name);
        final outputFile = File(filePath);
        
        // Create parent directories if they don't exist
        await outputFile.parent.create(recursive: true);
        
        // Write file content
        await outputFile.writeAsBytes(file.content as List<int>);
      }
    }

    return extractDir;
  }

  /// Check if a zip file contains a valid MCP bundle.
  /// Returns true if the zip contains the required MCP files.
  static Future<bool> isValidMcpBundle(File zipFile) async {
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      
      final requiredFiles = [
        'manifest.json',
        'nodes.jsonl',
        'edges.jsonl',
        'pointers.jsonl',
        'embeddings.jsonl',
      ];
      
      final fileNames = archive.files.map((f) => f.name).toSet();
      
      // Check if all required files exist (accounting for possible subdirectories)
      for (final requiredFile in requiredFiles) {
        final found = fileNames.any((fileName) => 
            fileName.endsWith(requiredFile) || 
            fileName.endsWith('/$requiredFile'));
        if (!found) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get the root directory of an MCP bundle within a zip file.
  /// Returns the relative path to the bundle root, or null if not found.
  static Future<String?> getBundleRoot(File zipFile) async {
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      
      // Look for manifest.json to find the bundle root
      for (final file in archive.files) {
        if (file.name.endsWith('manifest.json')) {
          final dirName = path.dirname(file.name);
          return dirName.isEmpty ? '.' : dirName;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
}



import 'dart:io';
import 'package:archive/archive.dart';

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
}



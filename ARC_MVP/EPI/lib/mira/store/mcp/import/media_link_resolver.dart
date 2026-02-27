import 'dart:io';
import 'package:archive/archive_io.dart';

/// Resolves media links and thumbnails from MCP bundle directories
class MediaLinkResolver {
  final String _bundleDir;
  Directory? _journalZipDir;
  
  MediaLinkResolver({required String bundleDir}) : _bundleDir = bundleDir;

  /// Initialize the resolver by checking for journal ZIP files
  Future<void> initialize() async {
    final bundleDirectory = Directory(_bundleDir);
    if (!await bundleDirectory.exists()) {
      return;
    }

    // Look for journal_v1.mcp.zip in the bundle directory
    final journalZip = File('$_bundleDir/journal_v1.mcp.zip');
    if (await journalZip.exists()) {
      // Extract to a temporary directory for thumbnail access
      final tempDir = Directory('$_bundleDir/journal_extracted');
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await tempDir.create(recursive: true);
      
      try {
        await extractFileToDisk(journalZip.path, tempDir.path);
        _journalZipDir = tempDir;
      } catch (e) {
        print('MediaLinkResolver: Failed to extract journal ZIP: $e');
      }
    }
  }

  /// Get the local thumbnail path for a SHA-256 hash
  String? getThumbnailPath(String sha256) {
    if (_journalZipDir == null) {
      return null;
    }

    // Check in extracted journal directory for thumbnails
    final thumbPath = '${_journalZipDir!.path}/assets/thumbs/$sha256.jpg';
    final thumbFile = File(thumbPath);
    
    if (thumbFile.existsSync()) {
      return thumbPath;
    }

    return null;
  }

  /// Resolve a media link (legacy static method support)
  static Future<String?> resolveMediaLink(String link) async {
    // Placeholder implementation
    return null;
  }
}


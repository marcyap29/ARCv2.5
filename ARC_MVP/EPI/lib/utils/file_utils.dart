import 'dart:io';

/// File utilities for MCP package handling
class FileUtils {
  /// Check if file is an MCP package (.zip with MCP content)
  static bool isMcpPackage(String path) {
    return path.toLowerCase().endsWith('.zip') || path.toLowerCase().endsWith('.mcpkg');
  }

  /// Check if path is an MCP folder (.mcp/) - DEPRECATED, use .zip files only
  static bool isMcpFolder(String path) {
    return false; // No longer supported
  }

  /// Check if path is a valid MCP input (package only)
  static bool isValidMcpInput(String path) {
    return isMcpPackage(path); // Only .zip files supported
  }

  /// Get file extension
  static String getExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1) return '';
    return path.substring(lastDot + 1).toLowerCase();
  }

  /// Get filename without extension
  static String getBasename(String path) {
    final fileName = path.split('/').last;
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1) return fileName;
    return fileName.substring(0, lastDot);
  }

  /// Generate MCP package filename with date
  static String generateMcpPackageName(String basename) {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return '${basename}_$dateStr.zip';
  }

  /// Generate MCP folder name
  static String generateMcpFolderName(String basename) {
    return '$basename.mcp';
  }

  /// Format file size in human readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Check if file exists
  static Future<bool> fileExists(String path) async {
    return await File(path).exists();
  }

  /// Check if directory exists
  static Future<bool> directoryExists(String path) async {
    return await Directory(path).exists();
  }

  /// Get file size
  static Future<int> getFileSize(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// Get directory size recursively
  static Future<int> getDirectorySize(String path) async {
    int totalSize = 0;
    final dir = Directory(path);
    
    if (await dir.exists()) {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }
    
    return totalSize;
  }
}

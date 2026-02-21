import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class HashUtils {
  /// Compute SHA-256 hash of byte data
  static String sha256Hash(Uint8List data) {
    final digest = sha256.convert(data);
    return digest.toString();
  }

  /// Compute SHA-256 hash of a file
  static Future<String> sha256HashFile(File file) async {
    final bytes = await file.readAsBytes();
    return sha256Hash(bytes);
  }

  /// Compute SHA-256 hash of a stream (for large files)
  static Future<String> sha256HashStream(Stream<List<int>> stream) async {
    const digest = sha256;
    final chunks = <List<int>>[];
    
    await for (final chunk in stream) {
      chunks.add(chunk);
    }
    
    final allBytes = chunks.expand((chunk) => chunk).toList();
    return digest.convert(allBytes).toString();
  }

  /// Generate a unique ID for pointers
  static String generatePointerId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomSeed = DateTime.now().microsecondsSinceEpoch;
    final combined = '$timestamp$randomSeed';
    return 'ptr_${sha256Hash(Uint8List.fromList(utf8.encode(combined))).substring(0, 16)}';
  }

  /// Generate a unique ID for embeddings
  static String generateEmbeddingId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomSeed = DateTime.now().microsecondsSinceEpoch;
    final combined = '$timestamp$randomSeed';
    return 'emb_${sha256Hash(Uint8List.fromList(utf8.encode(combined))).substring(0, 16)}';
  }

  /// Generate a unique ID for nodes
  static String generateNodeId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomSeed = DateTime.now().microsecondsSinceEpoch;
    final combined = '$timestamp$randomSeed';
    return 'node_${sha256Hash(Uint8List.fromList(utf8.encode(combined))).substring(0, 16)}';
  }
}

class CASStore {
  static const String _casDirectoryName = 'cas';
  
  /// Get the CAS root directory
  static Future<Directory> get _casDirectory async {
    final appDir = await getApplicationSupportDirectory();
    final casDir = Directory(path.join(appDir.path, _casDirectoryName));
    
    if (!await casDir.exists()) {
      await casDir.create(recursive: true);
    }
    
    return casDir;
  }

  /// Generate CAS URI for content
  static String generateCASUri(String type, String size, String hash) {
    return 'cas://$type/$size/sha256:$hash';
  }

  /// Parse CAS URI to get components
  static CASUriComponents? parseCASUri(String uri) {
    final regex = RegExp(r'^cas://([^/]+)/([^/]+)/sha256:([a-f0-9]{64})$');
    final match = regex.firstMatch(uri);
    
    if (match == null) return null;
    
    return CASUriComponents(
      type: match.group(1)!,
      size: match.group(2)!,
      hash: match.group(3)!,
    );
  }

  /// Get file path for CAS URI
  static Future<File> getFileForCASUri(String uri) async {
    final components = parseCASUri(uri);
    if (components == null) {
      throw ArgumentError('Invalid CAS URI: $uri');
    }
    
    final casDir = await _casDirectory;
    final typePath = path.join(casDir.path, components.type);
    final sizePath = path.join(typePath, components.size);
    
    // Ensure directories exist
    await Directory(sizePath).create(recursive: true);
    
    final filePath = path.join(sizePath, components.hash);
    return File(filePath);
  }

  /// Store content in CAS and return URI
  static Future<String> store(String type, String size, Uint8List data) async {
    final hash = HashUtils.sha256Hash(data);
    final uri = generateCASUri(type, size, hash);
    final file = await getFileForCASUri(uri);
    
    // Only write if file doesn't exist (content-addressed deduplication)
    if (!await file.exists()) {
      await file.writeAsBytes(data);
    }
    
    return uri;
  }

  /// Retrieve content from CAS
  static Future<Uint8List?> retrieve(String uri) async {
    try {
      final file = await getFileForCASUri(uri);
      
      if (!await file.exists()) {
        return null;
      }
      
      return await file.readAsBytes();
    } catch (e) {
      print('CASStore: Error retrieving $uri: $e');
      return null;
    }
  }

  /// Check if content exists in CAS
  static Future<bool> exists(String uri) async {
    try {
      final file = await getFileForCASUri(uri);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Delete content from CAS
  static Future<bool> delete(String uri) async {
    try {
      final file = await getFileForCASUri(uri);
      
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      
      return false;
    } catch (e) {
      print('CASStore: Error deleting $uri: $e');
      return false;
    }
  }

  /// Get storage usage for a specific type
  static Future<int> getStorageUsage({String? type, String? size}) async {
    try {
      final casDir = await _casDirectory;
      Directory searchDir = casDir;
      
      if (type != null) {
        searchDir = Directory(path.join(casDir.path, type));
        if (size != null) {
          searchDir = Directory(path.join(searchDir.path, size));
        }
      }
      
      if (!await searchDir.exists()) {
        return 0;
      }
      
      int totalSize = 0;
      await for (final entity in searchDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      print('CASStore: Error calculating storage usage: $e');
      return 0;
    }
  }

  /// Clean up unreferenced CAS entries
  static Future<int> cleanup(Set<String> referencedUris) async {
    try {
      final casDir = await _casDirectory;
      int cleanedCount = 0;
      
      await for (final entity in casDir.list(recursive: true)) {
        if (entity is File) {
          // Try to construct CAS URI from file path
          final relativePath = path.relative(entity.path, from: casDir.path);
          final parts = relativePath.split(path.separator);
          
          if (parts.length >= 3) {
            final type = parts[0];
            final size = parts[1];
            final hash = path.basename(entity.path);
            final uri = generateCASUri(type, size, hash);
            
            if (!referencedUris.contains(uri)) {
              try {
                await entity.delete();
                cleanedCount++;
                print('CASStore: Cleaned up unreferenced file: $uri');
              } catch (e) {
                print('CASStore: Error cleaning up file ${entity.path}: $e');
              }
            }
          }
        }
      }
      
      return cleanedCount;
    } catch (e) {
      print('CASStore: Error during cleanup: $e');
      return 0;
    }
  }

  /// Get all CAS URIs in storage
  static Future<Set<String>> getAllUris() async {
    final Set<String> uris = {};
    
    try {
      final casDir = await _casDirectory;
      
      await for (final entity in casDir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = path.relative(entity.path, from: casDir.path);
          final parts = relativePath.split(path.separator);
          
          if (parts.length >= 3) {
            final type = parts[0];
            final size = parts[1];
            final hash = path.basename(entity.path);
            final uri = generateCASUri(type, size, hash);
            uris.add(uri);
          }
        }
      }
    } catch (e) {
      print('CASStore: Error listing URIs: $e');
    }
    
    return uris;
  }
}

class CASUriComponents {
  final String type;
  final String size;
  final String hash;

  const CASUriComponents({
    required this.type,
    required this.size,
    required this.hash,
  });

  @override
  String toString() => 'CAS($type/$size/$hash)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CASUriComponents &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          size == other.size &&
          hash == other.hash;

  @override
  int get hashCode => type.hashCode ^ size.hashCode ^ hash.hashCode;
}
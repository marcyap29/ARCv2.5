// lib/chronicle/dual/storage/chronicle_storage.dart
//
// File system operations for dual-chronicle storage.
// User data: user-data/chronicle/
// LUMARA data: lumara-data/chronicle/

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Low-level file storage for dual chronicle.
/// Does not enforce sacred separation; repositories do.
class ChronicleStorage {
  ChronicleStorage({Directory? testBaseDirectory})
      : _testBase = testBaseDirectory;

  /// If set (e.g. in tests), used instead of getApplicationDocumentsDirectory().
  final Directory? _testBase;

  static const String userDataDir = 'user-data';
  static const String lumaraDataDir = 'lumara-data';
  static const String chronicleSubdir = 'chronicle';

  /// Base directory for app documents (or test base when provided).
  Future<Directory> _getAppDocuments() async {
    if (_testBase != null) return Future.value(_testBase!);
    return getApplicationDocumentsDirectory();
  }

  /// User's Chronicle root: .../user-data/chronicle/
  Future<Directory> getUserChronicleRoot() async {
    final appDir = await _getAppDocuments();
    final dir = Directory(path.join(appDir.path, userDataDir, chronicleSubdir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// LUMARA's Chronicle root: .../lumara-data/chronicle/
  Future<Directory> getLumaraChronicleRoot() async {
    final appDir = await _getAppDocuments();
    final dir = Directory(path.join(appDir.path, lumaraDataDir, chronicleSubdir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Save JSON to a path under a root directory. Creates parent dirs.
  Future<void> save(String relativePath, Map<String, dynamic> data) async {
    final appDir = await _getAppDocuments();
    final fullPath = path.join(appDir.path, relativePath);
    final file = File(fullPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data), flush: true);
  }

  /// Save under user-data/chronicle/{userId}/...
  Future<void> saveUserChronicle(String userId, String subPath, Map<String, dynamic> data) async {
    final root = await getUserChronicleRoot();
    final fullPath = path.join(root.path, userId, subPath);
    final file = File(fullPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data), flush: true);
  }

  /// Save under lumara-data/chronicle/{userId}/...
  Future<void> saveLumaraChronicle(String userId, String subPath, Map<String, dynamic> data) async {
    final root = await getLumaraChronicleRoot();
    final fullPath = path.join(root.path, userId, subPath);
    final file = File(fullPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data), flush: true);
  }

  /// Load JSON from path under app documents
  Future<Map<String, dynamic>?> load(String relativePath) async {
    final appDir = await _getAppDocuments();
    final fullPath = path.join(appDir.path, relativePath);
    final file = File(fullPath);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>?;
  }

  /// Load from user-data/chronicle/{userId}/...
  Future<Map<String, dynamic>?> loadUserChronicle(String userId, String subPath) async {
    final root = await getUserChronicleRoot();
    final fullPath = path.join(root.path, userId, subPath);
    final file = File(fullPath);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>?;
  }

  /// Load from lumara-data/chronicle/{userId}/...
  Future<Map<String, dynamic>?> loadLumaraChronicle(String userId, String subPath) async {
    final root = await getLumaraChronicleRoot();
    final fullPath = path.join(root.path, userId, subPath);
    final file = File(fullPath);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>?;
  }

  /// List all JSON files in a directory (non-recursive by default)
  Future<List<File>> listJsonFiles(Directory dir, {bool recursive = false}) async {
    if (!await dir.exists()) return [];
    final list = <File>[];
    await for (final entity in dir.list(recursive: recursive)) {
      if (entity is File && entity.path.endsWith('.json')) list.add(entity);
    }
    return list;
  }

  /// Delete a file by relative path under app documents
  Future<void> delete(String relativePath) async {
    final appDir = await _getAppDocuments();
    final fullPath = path.join(appDir.path, relativePath);
    final file = File(fullPath);
    if (await file.exists()) await file.delete();
  }

  /// Delete user chronicle file: user-data/chronicle/{userId}/...
  Future<void> deleteUserChronicle(String userId, String subPath) async {
    final root = await getUserChronicleRoot();
    final fullPath = path.join(root.path, userId, subPath);
    final file = File(fullPath);
    if (await file.exists()) await file.delete();
  }

  /// Delete lumara chronicle file: lumara-data/chronicle/{userId}/...
  Future<void> deleteLumaraChronicle(String userId, String subPath) async {
    final root = await getLumaraChronicleRoot();
    final fullPath = path.join(root.path, userId, subPath);
    final file = File(fullPath);
    if (await file.exists()) await file.delete();
  }

  /// Get directory for user chronicle subpath (e.g. layer0/entries)
  Future<Directory> getUserChronicleDir(String userId, String subPath) async {
    final root = await getUserChronicleRoot();
    final dir = Directory(path.join(root.path, userId, subPath));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Get directory for lumara chronicle subpath (e.g. gap-fills)
  Future<Directory> getLumaraChronicleDir(String userId, String subPath) async {
    final root = await getLumaraChronicleRoot();
    final dir = Directory(path.join(root.path, userId, subPath));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}

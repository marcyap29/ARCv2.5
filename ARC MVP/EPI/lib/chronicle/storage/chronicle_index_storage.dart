import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Persists and loads the Chronicle cross-temporal index as JSON.
class ChronicleIndexStorage {
  Future<String> _indexPath(String userId) async {
    final appDir = await getApplicationDocumentsDirectory();
    return path.join(appDir.path, 'chronicle', userId, 'index', 'chronicle_index.json');
  }

  Future<bool> exists(String userId) async {
    final p = await _indexPath(userId);
    return File(p).exists();
  }

  Future<Map<String, dynamic>> read(String userId) async {
    final p = await _indexPath(userId);
    final file = File(p);
    if (!await file.exists()) return {};

    final content = await file.readAsString();
    if (content.trim().isEmpty) return {};

    return jsonDecode(content) as Map<String, dynamic>;
  }

  Future<void> write(String userId, Map<String, dynamic> json) async {
    final p = await _indexPath(userId);
    final file = File(p);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
      flush: true,
    );
  }
}

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class McpFs {
  /// Returns the base MCP directory inside app documents, e.g. <app-docs>/mcp
  static Future<Directory> base() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'mcp'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Get the month file path: mcp/<rel>/<YYYY-MM>.jsonl
  static Future<File> monthFile(String rel, String monthKey) async {
    final root = await base();
    final file = File(p.join(root.path, rel, '$monthKey.jsonl'));
    if (!await file.parent.exists()) await file.parent.create(recursive: true);
    return file;
  }

  /// Convenience for the two health streams
  static Future<File> healthMonth(String monthKey) => monthFile('streams/health', monthKey);
  static Future<File> fusionMonth(String monthKey) => monthFile('fusions/daily', monthKey);
  static Future<File> veilMonth(String monthKey) => monthFile('policies/veil', monthKey);
}




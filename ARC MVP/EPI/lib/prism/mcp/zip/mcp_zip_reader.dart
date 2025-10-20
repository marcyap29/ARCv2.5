import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:my_app/prism/mcp/models/journal_manifest.dart';
import 'package:my_app/prism/mcp/models/media_pack_manifest.dart';

/// Reader for MCP journal and media pack ZIP files
class McpZipReader {
  final Archive _archive;
  final String _filePath;

  McpZipReader._(this._archive, this._filePath);

  /// Create a reader from a file path
  static Future<McpZipReader> fromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('ZIP file not found: $filePath');
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    return McpZipReader._(archive, filePath);
  }

  /// Create a reader from bytes
  static McpZipReader fromBytes(Uint8List bytes, String filePath) {
    final archive = ZipDecoder().decodeBytes(bytes);
    return McpZipReader._(archive, filePath);
  }

  /// Read a file from the archive
  Uint8List? readFile(String archivePath) {
    final file = _archive.findFile(archivePath);
    return file?.content;
  }

  /// Read a text file from the archive
  String? readTextFile(String archivePath) {
    final data = readFile(archivePath);
    if (data == null) return null;
    return String.fromCharCodes(data);
  }

  /// Read a JSON file from the archive
  Map<String, dynamic>? readJsonFile(String archivePath) {
    final text = readTextFile(archivePath);
    if (text == null) return null;
    
    try {
      return _jsonDecode(text);
    } catch (e) {
      print('McpZipReader: Error parsing JSON from $archivePath: $e');
      return null;
    }
  }

  /// Read journal manifest
  JournalManifest? readJournalManifest() {
    final json = readJsonFile('manifest.json');
    if (json == null) return null;
    
    try {
      return JournalManifest.fromJson(json);
    } catch (e) {
      print('McpZipReader: Error parsing journal manifest: $e');
      return null;
    }
  }

  /// Read media pack manifest
  MediaPackManifest? readMediaPackManifest() {
    final json = readJsonFile('manifest.json');
    if (json == null) return null;
    
    try {
      return MediaPackManifest.fromJson(json);
    } catch (e) {
      print('McpZipReader: Error parsing media pack manifest: $e');
      return null;
    }
  }

  /// Read a journal entry
  Map<String, dynamic>? readJournalEntry(String entryId) {
    return readJsonFile('entries/$entryId.json');
  }

  /// Read a thumbnail
  Uint8List? readThumbnail(String sha) {
    return readFile('assets/thumbs/$sha.jpg');
  }

  /// Read a full-resolution photo from media pack
  Uint8List? readPhoto(String sha, String extension) {
    return readFile('photos/$sha.$extension');
  }

  /// List all files in the archive
  List<String> listFiles() {
    return _archive.files.map((file) => file.name).toList();
  }

  /// List journal entries
  List<String> listJournalEntries() {
    return _archive.files
        .where((file) => file.name.startsWith('entries/') && file.name.endsWith('.json'))
        .map((file) => file.name.substring(8, file.name.length - 5)) // Remove 'entries/' and '.json'
        .toList();
  }

  /// List thumbnails
  List<String> listThumbnails() {
    return _archive.files
        .where((file) => file.name.startsWith('assets/thumbs/') && file.name.endsWith('.jpg'))
        .map((file) => file.name.substring(14, file.name.length - 4)) // Remove 'assets/thumbs/' and '.jpg'
        .toList();
  }

  /// List photos in media pack
  List<String> listPhotos() {
    return _archive.files
        .where((file) => file.name.startsWith('photos/'))
        .map((file) => file.name.substring(7)) // Remove 'photos/'
        .toList();
  }

  /// Check if a file exists in the archive
  bool hasFile(String archivePath) {
    return _archive.findFile(archivePath) != null;
  }

  /// Get file size
  int? getFileSize(String archivePath) {
    final file = _archive.findFile(archivePath);
    return file?.size;
  }

  /// Get archive statistics
  Map<String, dynamic> get stats => {
    'filePath': _filePath,
    'totalFiles': _archive.files.length,
    'totalSize': _archive.files.fold(0, (sum, file) => sum + file.size),
    'isJournal': hasFile('manifest.json') && hasFile('entries/'),
    'isMediaPack': hasFile('manifest.json') && hasFile('photos/'),
  };

  /// JSON decoder
  Map<String, dynamic> _jsonDecode(String json) {
    return jsonDecode(json) as Map<String, dynamic>;
  }
}

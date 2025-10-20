import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:my_app/prism/mcp/models/journal_manifest.dart';
import 'package:my_app/prism/mcp/models/media_pack_manifest.dart';

/// Writer for MCP journal and media pack ZIP files
class McpZipWriter {
  final Archive _archive = Archive();
  final String _outputPath;

  McpZipWriter({
    required String outputPath,
  }) : _outputPath = outputPath;

  /// Add a file to the archive
  void addFile(String archivePath, Uint8List data) {
    final file = ArchiveFile(
      archivePath,
      data.length,
      data,
    );
    _archive.addFile(file);
  }

  /// Add a text file to the archive
  void addTextFile(String archivePath, String content) {
    addFile(archivePath, Uint8List.fromList(content.codeUnits));
  }

  /// Add a JSON file to the archive
  void addJsonFile(String archivePath, Map<String, dynamic> json) {
    final content = _jsonEncode(json);
    addTextFile(archivePath, content);
  }

  /// Add journal manifest
  void addJournalManifest(JournalManifest manifest) {
    addJsonFile('manifest.json', manifest.toJson());
  }

  /// Add media pack manifest
  void addMediaPackManifest(MediaPackManifest manifest) {
    addJsonFile('manifest.json', manifest.toJson());
  }

  /// Add journal entry
  void addJournalEntry(String entryId, Map<String, dynamic> entryData) {
    addJsonFile('entries/$entryId.json', entryData);
  }

  /// Add thumbnail
  void addThumbnail(String sha, Uint8List thumbnailData) {
    addFile('assets/thumbs/$sha.jpg', thumbnailData);
  }

  /// Add full-resolution photo to media pack
  void addPhoto(String sha, String extension, Uint8List photoData) {
    addFile('photos/$sha.$extension', photoData);
  }

  /// Write the archive to disk
  Future<void> write() async {
    final zipData = ZipEncoder().encode(_archive);
    if (zipData == null) {
      throw Exception('Failed to encode ZIP archive');
    }

    final file = File(_outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(zipData);
  }

  /// Get the current archive size in bytes
  int get archiveSize {
    return _archive.files.fold(0, (sum, file) => sum + file.size);
  }

  /// Get the number of files in the archive
  int get fileCount => _archive.files.length;

  /// Check if a file exists in the archive
  bool hasFile(String archivePath) {
    return _archive.findFile(archivePath) != null;
  }

  /// Get file size if it exists
  int? getFileSize(String archivePath) {
    final file = _archive.findFile(archivePath);
    return file?.size;
  }

  /// JSON encoding with proper formatting
  String _jsonEncode(Map<String, dynamic> json) {
    return const JsonEncoder.withIndent('  ').convert(json);
  }
}

/// Writer specifically for media packs
class MediaPackWriter extends McpZipWriter {
  final String _packId;
  final DateTime _from;
  final DateTime _to;
  final Map<String, MediaPackItem> _items = {};

  MediaPackWriter({
    required String outputPath,
    required String packId,
    required DateTime from,
    required DateTime to,
  }) : _packId = packId,
       _from = from,
       _to = to,
       super(outputPath: outputPath);

  /// Add a photo to the media pack
  void addPhoto(String sha, String extension, Uint8List photoData) {
    super.addPhoto(sha, extension, photoData);
    
    // Track the item in our manifest
    _items[sha] = MediaPackItem(
      path: 'photos/$sha.$extension',
      bytes: photoData.length,
      format: extension,
    );
  }

  /// Finalize the media pack and write manifest
  Future<void> finalize() async {
    final manifest = MediaPackManifest(
      id: _packId,
      from: _from,
      to: _to,
      items: _items,
    );
    
    addMediaPackManifest(manifest);
    await write();
  }

  /// Get current pack statistics
  Map<String, dynamic> get stats => {
    'packId': _packId,
    'itemCount': _items.length,
    'totalSize': _items.values.fold(0, (sum, item) => sum + item.bytes),
    'from': _from.toIso8601String(),
    'to': _to.toIso8601String(),
  };
}

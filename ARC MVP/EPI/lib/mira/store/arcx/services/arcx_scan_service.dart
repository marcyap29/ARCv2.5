/// ARCX Scan Service – scan .arcx files without importing.
/// Returns per-file summary: counts, date range, size, status.
library arcx_scan_service;

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import '../models/arcx_manifest.dart';
import 'arcx_crypto_service.dart';

/// Result of scanning a single .arcx file.
class ARCXFileScanResult {
  final String filePath;
  final int fileSizeBytes;
  final String? error;
  final ARCXManifest? manifest;
  final int entriesCount;
  final int chatsCount;
  final int mediaCount;
  final String? entriesDateRangeStart;
  final String? entriesDateRangeEnd;
  final String? exportedAt;

  const ARCXFileScanResult({
    required this.filePath,
    required this.fileSizeBytes,
    this.error,
    this.manifest,
    this.entriesCount = 0,
    this.chatsCount = 0,
    this.mediaCount = 0,
    this.entriesDateRangeStart,
    this.entriesDateRangeEnd,
    this.exportedAt,
  });

  String get fileName => path.basename(filePath);
  bool get isOk => error == null;
}

/// Scan a single .arcx file: read manifest, decrypt payload, count entries/chats/media and derive date range.
Future<ARCXFileScanResult> scanArcxFile({
  required String arcxPath,
  String? password,
}) async {
  int size = 0;
  try {
    final file = File(arcxPath);
    if (!await file.exists()) {
      return ARCXFileScanResult(filePath: arcxPath, fileSizeBytes: 0, error: 'File not found');
    }
    size = await file.length();
    final bytes = await file.readAsBytes();
    final zipDecoder = ZipDecoder();
    final archive = zipDecoder.decodeBytes(bytes);
    ArchiveFile? manifestFile;
    ArchiveFile? encryptedArchive;
    for (final f in archive) {
      if (f.name == 'manifest.json') manifestFile = f;
      else if (f.name == 'archive.arcx') encryptedArchive = f;
    }
    if (manifestFile == null || encryptedArchive == null) {
      return ARCXFileScanResult(filePath: arcxPath, fileSizeBytes: size, error: 'Invalid ARCX: manifest or archive missing');
    }
    final manifestJson = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;
    final manifest = ARCXManifest.fromJson(manifestJson);
    final ciphertext = encryptedArchive.content as List<int>;
    Uint8List plaintextZip;
    if (manifest.isPasswordEncrypted) {
      if (password == null || password.isEmpty || manifest.saltB64 == null) {
        return ARCXFileScanResult(filePath: arcxPath, fileSizeBytes: size, error: 'Password required', manifest: manifest);
      }
      final salt = Uint8List.fromList(base64Decode(manifest.saltB64!));
      plaintextZip = await ARCXCryptoService.decryptWithPassword(Uint8List.fromList(ciphertext), password, salt);
    } else {
      try {
        plaintextZip = await ARCXCryptoService.decryptAEAD(Uint8List.fromList(ciphertext));
      } catch (e) {
        return ARCXFileScanResult(filePath: arcxPath, fileSizeBytes: size, error: 'Decrypt failed: $e', manifest: manifest);
      }
    }
    final payloadArchive = ZipDecoder().decodeBytes(plaintextZip);
    int entriesCount = 0;
    int chatsCount = 0;
    int mediaCount = 0;
    DateTime? entriesMin;
    DateTime? entriesMax;
    for (final f in payloadArchive) {
      if (!f.isFile) continue;
      final name = f.name;
      if (name.startsWith('Entries/') && name.endsWith('.arcx.json')) {
        entriesCount++;
        final parts = name.split('/');
        if (parts.length >= 4) {
          final y = int.tryParse(parts[1]);
          final m = int.tryParse(parts[2]);
          final d = int.tryParse(parts[3]);
          if (y != null && m != null && d != null) {
            final dt = DateTime(y, m, d);
            if (entriesMin == null || dt.isBefore(entriesMin)) entriesMin = dt;
            if (entriesMax == null || dt.isAfter(entriesMax)) entriesMax = dt;
          }
        }
      } else if (name.startsWith('Chats/') && name.endsWith('.arcx.json')) {
        chatsCount++;
      } else if (name == 'Media/media_index.json') {
        try {
          final content = jsonDecode(utf8.decode(f.content as List<int>)) as Map<String, dynamic>?;
          final items = content?['items'] as List<dynamic>? ?? [];
          mediaCount = items.length;
        } catch (_) {}
      }
    }
    String? startStr = entriesMin != null ? _formatDate(entriesMin) : (manifest.metadata?['entries_date_range_start'] as String?);
    String? endStr = entriesMax != null ? _formatDate(entriesMax) : (manifest.metadata?['entries_date_range_end'] as String?);
    return ARCXFileScanResult(
      filePath: arcxPath,
      fileSizeBytes: size,
      manifest: manifest,
      entriesCount: entriesCount,
      chatsCount: chatsCount,
      mediaCount: mediaCount,
      entriesDateRangeStart: startStr,
      entriesDateRangeEnd: endStr,
      exportedAt: manifest.exportedAt,
    );
  } catch (e) {
    return ARCXFileScanResult(filePath: arcxPath, fileSizeBytes: size, error: e.toString());
  }
}

String _formatDate(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Scan multiple .arcx files. On error per file, result has [error] set; others continue.
Future<List<ARCXFileScanResult>> scanArcxFiles({
  required List<String> arcxPaths,
  String? password,
  void Function(String message, double fraction)? onProgress,
}) async {
  final results = <ARCXFileScanResult>[];
  final total = arcxPaths.length;
  for (int i = 0; i < total; i++) {
    onProgress?.call('Scanning ${i + 1}/$total: ${path.basename(arcxPaths[i])}...', (i + 1) / total);
    final r = await scanArcxFile(arcxPath: arcxPaths[i], password: password);
    results.add(r);
  }
  onProgress?.call('Scan complete.', 1.0);
  return results;
}

/// Scan a folder for .arcx files and return one result per file.
Future<List<ARCXFileScanResult>> scanArcxFolder(
  Directory directory, {
  String? password,
  bool recursive = false,
  void Function(String message, double fraction)? onProgress,
}) async {
  final paths = <String>[];
  await for (final e in directory.list(followLinks: false)) {
    if (e is File && e.path.toLowerCase().endsWith('.arcx')) {
      paths.add(e.path);
    }
  }
  paths.sort();
  if (paths.isEmpty) return [];
  return scanArcxFiles(arcxPaths: paths, password: password, onProgress: onProgress);
}

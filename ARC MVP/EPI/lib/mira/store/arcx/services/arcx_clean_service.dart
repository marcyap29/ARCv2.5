/// ARCX Clean Service
///
/// Removes chat sessions with fewer than [minLumaraResponses] assistant messages
/// from device-key-encrypted .arcx files. Only works on this device's exports
/// (same key used for encryptAEAD/decryptAEAD).

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import '../models/arcx_manifest.dart';
import 'arcx_crypto_service.dart';

/// Result of cleaning an ARCX file.
class ARCXCleanResult {
  final bool success;
  final String? outputPath;
  final int removedCount;
  final int keptCount;
  final String? error;

  const ARCXCleanResult({
    required this.success,
    this.outputPath,
    this.removedCount = 0,
    this.keptCount = 0,
    this.error,
  });
}

/// Minimum assistant messages required to keep a chat (must match app filter).
const int kMinLumaraResponsesToKeep = 3;

/// Clean an ARCX file: remove chats with fewer than [minLumaraResponses] LUMARA replies.
/// Only supports **device-key-encrypted** archives (not password-encrypted).
///
/// [arcxPath] - path to the .arcx file
/// [outputPath] - optional; default is same directory with _cleaned before .arcx
/// Returns path to the cleaned file on success.
Future<ARCXCleanResult> cleanArcxFile({
  required String arcxPath,
  String? outputPath,
  int minLumaraResponses = kMinLumaraResponsesToKeep,
  void Function(String message)? onProgress,
}) async {
  onProgress?.call('Reading archive...');
  final file = File(arcxPath);
  if (!await file.exists()) {
    return const ARCXCleanResult(success: false, error: 'File not found');
  }

  final bytes = await file.readAsBytes();
  Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (e) {
    return ARCXCleanResult(success: false, error: 'Invalid ZIP: $e');
  }

  ArchiveFile? manifestFile;
  ArchiveFile? encryptedPayload;
  for (final f in archive) {
    if (f.name == 'manifest.json') manifestFile = f;
    if (f.name == 'archive.arcx') encryptedPayload = f;
  }
  if (manifestFile == null || encryptedPayload == null) {
    return const ARCXCleanResult(success: false, error: 'Invalid ARCX: manifest or archive.arcx missing');
  }

  final manifestJson = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;
  final manifest = ARCXManifest.fromJson(manifestJson);

  if (manifest.arcxVersion != '1.2') {
    return const ARCXCleanResult(success: false, error: 'Only ARCX 1.2 format is supported');
  }
  if (manifest.isPasswordEncrypted) {
    return const ARCXCleanResult(
      success: false,
      error: 'This file is password-encrypted. Use the Python script scripts/clean_arcx_chats.py with your password.',
    );
  }

  onProgress?.call('Decrypting...');
  Uint8List plaintextZip;
  try {
    final ciphertext = Uint8List.fromList(encryptedPayload.content as List<int>);
    plaintextZip = await ARCXCryptoService.decryptAEAD(ciphertext);
  } catch (e) {
    return ARCXCleanResult(
      success: false,
      error: 'Decryption failed. This file may have been created on another device.',
    );
  }

  onProgress?.call('Filtering chats...');
  final payloadArchive = ZipDecoder().decodeBytes(plaintextZip);
  int removed = 0;
  int kept = 0;
  final newPayload = Archive();

  for (final f in payloadArchive) {
    if (!f.isFile) continue;
    final name = f.name;
    final content = f.content as List<int>;

    if (name.startsWith('Chats/') && name.endsWith('.arcx.json')) {
      int assistantCount = 0;
      try {
        final chat = jsonDecode(utf8.decode(content)) as Map<String, dynamic>;
        final messages = chat['messages'] as List<dynamic>? ?? [];
        assistantCount = messages.where((m) => m is Map && (m['role'] == 'assistant')).length;
      } catch (_) {}
      if (assistantCount < minLumaraResponses) {
        removed++;
        continue;
      }
      kept++;
    }
    newPayload.addFile(ArchiveFile(name, content.length, content));
  }

  onProgress?.call('Re-encrypting...');
  final newPayloadZip = ZipEncoder().encode(newPayload);
  if (newPayloadZip == null) {
    return const ARCXCleanResult(success: false, error: 'Failed to create payload ZIP');
  }

  final newCiphertext = await ARCXCryptoService.encryptAEAD(Uint8List.fromList(newPayloadZip));
  final newSha256 = base64Encode(sha256.convert(newCiphertext).bytes);

  final newScope = manifest.scope != null
      ? ARCXScope(
          entriesCount: manifest.scope!.entriesCount,
          chatsCount: kept,
          mediaCount: manifest.scope!.mediaCount,
          phaseRegimesCount: manifest.scope!.phaseRegimesCount,
          lumaraFavoritesCount: manifest.scope!.lumaraFavoritesCount,
          lumaraFavoritesAnswersCount: manifest.scope!.lumaraFavoritesAnswersCount,
          lumaraFavoritesChatsCount: manifest.scope!.lumaraFavoritesChatsCount,
          lumaraFavoritesEntriesCount: manifest.scope!.lumaraFavoritesEntriesCount,
          chronicleMonthlyCount: manifest.scope!.chronicleMonthlyCount,
          chronicleYearlyCount: manifest.scope!.chronicleYearlyCount,
          chronicleMultiyearCount: manifest.scope!.chronicleMultiyearCount,
          chronicleChangelogEntries: manifest.scope!.chronicleChangelogEntries,
          voiceNotesCount: manifest.scope!.voiceNotesCount,
          separateGroups: manifest.scope!.separateGroups,
        )
      : null;

  final updatedManifest = ARCXManifest(
    version: manifest.version,
    algo: manifest.algo,
    kdf: manifest.kdf,
    kdfParams: manifest.kdfParams,
    sha256: newSha256,
    signerPubkeyFpr: manifest.signerPubkeyFpr,
    signatureB64: '', // Cleared after content change
    payloadMeta: ARCXPayloadMeta(
      journalCount: manifest.payloadMeta.journalCount,
      photoMetaCount: manifest.payloadMeta.photoMetaCount,
      bytes: newPayloadZip.length,
    ),
    mcpManifestSha256: manifest.mcpManifestSha256,
    exportedAt: manifest.exportedAt,
    appVersion: manifest.appVersion,
    redactionReport: manifest.redactionReport,
    metadata: manifest.metadata,
    isPasswordEncrypted: false,
    saltB64: manifest.saltB64,
    exportId: manifest.exportId,
    chunkSize: manifest.chunkSize,
    totalChunks: manifest.totalChunks,
    formatVersion: manifest.formatVersion,
    arcxVersion: manifest.arcxVersion,
    scope: newScope,
    encryptionInfo: manifest.encryptionInfo,
    checksumsInfo: manifest.checksumsInfo,
  );

  final outPath = outputPath ?? path.join(
    path.dirname(arcxPath),
    '${path.basenameWithoutExtension(arcxPath)}_cleaned.arcx',
  );

  onProgress?.call('Writing...');
  final finalArchive = Archive();
  finalArchive.addFile(ArchiveFile('archive.arcx', newCiphertext.length, newCiphertext));
  finalArchive.addFile(ArchiveFile(
    'manifest.json',
    utf8.encode(jsonEncode(updatedManifest.toJson())).length,
    utf8.encode(jsonEncode(updatedManifest.toJson())),
  ));
  final outZip = ZipEncoder().encode(finalArchive);
  if (outZip == null) {
    return const ARCXCleanResult(success: false, error: 'Failed to create output ZIP');
  }

  try {
    await File(outPath).writeAsBytes(outZip);
  } catch (e) {
    return ARCXCleanResult(success: false, error: 'Write failed: $e');
  }

  return ARCXCleanResult(
    success: true,
    outputPath: outPath,
    removedCount: removed,
    keptCount: kept,
  );
}

/// Result of cleaning multiple ARCX files.
class ARCXCleanBatchResult {
  final int totalCount;
  final int successCount;
  final int failCount;
  final List<ARCXCleanResult> results;
  final List<String> paths;

  const ARCXCleanBatchResult({
    required this.totalCount,
    required this.successCount,
    required this.failCount,
    required this.results,
    required this.paths,
  });
}

/// List all .arcx files in [directoryPath] (top-level only, case-insensitive .arcx).
List<String> listArcxFilesInDirectory(String directoryPath) {
  final dir = Directory(directoryPath);
  if (!dir.existsSync()) return [];
  final files = dir.listSync().whereType<File>().where((f) {
    final name = f.path;
    return name.toLowerCase().endsWith('.arcx');
  }).map((f) => f.path).toList();
  files.sort();
  return files;
}

/// Clean multiple ARCX files. Each is opened, decrypted, chats filtered, re-encrypted; output next to original as *_cleaned.arcx.
/// [onFileStart] (index, total, path) when starting a file; [onProgress] (index, total, path, message) for step messages.
Future<ARCXCleanBatchResult> cleanArcxPaths({
  required List<String> arcxPaths,
  int minLumaraResponses = kMinLumaraResponsesToKeep,
  void Function(int index, int total, String path)? onFileStart,
  void Function(int index, int total, String path, String message)? onProgress,
}) async {
  final results = <ARCXCleanResult>[];
  final paths = List<String>.from(arcxPaths);
  final total = paths.length;
  int successCount = 0;

  for (var i = 0; i < paths.length; i++) {
    final arcxPath = paths[i];
    onFileStart?.call(i + 1, total, arcxPath);
    final result = await cleanArcxFile(
      arcxPath: arcxPath,
      minLumaraResponses: minLumaraResponses,
      onProgress: (message) => onProgress?.call(i + 1, total, arcxPath, message),
    );
    results.add(result);
    if (result.success) successCount++;
  }

  return ARCXCleanBatchResult(
    totalCount: total,
    successCount: successCount,
    failCount: total - successCount,
    results: results,
    paths: paths,
  );
}

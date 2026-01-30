/// Checkpoint persistence for ARCX import/export resume.
/// Stores minimal state so interrupted operations can be resumed.
library arcx_checkpoint_service;

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Checkpoint for an interrupted import.
/// When present and payload dir exists, import can resume from extracted payload.
class ArcxImportCheckpoint {
  final String arcxPath;
  final int arcxFileLastModifiedMs;
  final int arcxFileSize;
  final String payloadDirPath;
  final String createdAtIso;

  const ArcxImportCheckpoint({
    required this.arcxPath,
    required this.arcxFileLastModifiedMs,
    required this.arcxFileSize,
    required this.payloadDirPath,
    required this.createdAtIso,
  });

  Map<String, dynamic> toJson() => {
        'arcx_path': arcxPath,
        'arcx_file_last_modified_ms': arcxFileLastModifiedMs,
        'arcx_file_size': arcxFileSize,
        'payload_dir_path': payloadDirPath,
        'created_at_iso': createdAtIso,
      };

  static ArcxImportCheckpoint? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final pathStr = json['arcx_path'] as String?;
    final lastMod = json['arcx_file_last_modified_ms'] as int?;
    final size = json['arcx_file_size'] as int?;
    final payloadPath = json['payload_dir_path'] as String?;
    final createdAt = json['created_at_iso'] as String?;
    if (pathStr == null || lastMod == null || size == null || payloadPath == null || createdAt == null) {
      return null;
    }
    return ArcxImportCheckpoint(
      arcxPath: pathStr,
      arcxFileLastModifiedMs: lastMod,
      arcxFileSize: size,
      payloadDirPath: payloadPath,
      createdAtIso: createdAt,
    );
  }

  /// True if the given file matches this checkpoint (same path, mtime, size).
  bool matchesFile(File file) {
    try {
      if (file.path != arcxPath) return false;
      final stat = file.statSync();
      return stat.modified.millisecondsSinceEpoch == arcxFileLastModifiedMs && stat.size == arcxFileSize;
    } catch (_) {
      return false;
    }
  }
}

/// Checkpoint for an interrupted export.
/// When present and staging dir exists, export can resume from existing payload.
class ArcxExportCheckpoint {
  final String stagingDirPath;
  final String outputDirPath;
  final String exportId;
  final List<String> entryIds;
  final List<String> chatThreadIds;
  final List<String> mediaIds;
  final String? startDateIso;
  final String? endDateIso;
  final String createdAtIso;

  const ArcxExportCheckpoint({
    required this.stagingDirPath,
    required this.outputDirPath,
    required this.exportId,
    this.entryIds = const [],
    this.chatThreadIds = const [],
    this.mediaIds = const [],
    this.startDateIso,
    this.endDateIso,
    required this.createdAtIso,
  });

  Map<String, dynamic> toJson() => {
        'staging_dir_path': stagingDirPath,
        'output_dir_path': outputDirPath,
        'export_id': exportId,
        'entry_ids': entryIds,
        'chat_thread_ids': chatThreadIds,
        'media_ids': mediaIds,
        'start_date_iso': startDateIso,
        'end_date_iso': endDateIso,
        'created_at_iso': createdAtIso,
      };

  static ArcxExportCheckpoint? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final staging = json['staging_dir_path'] as String?;
    final output = json['output_dir_path'] as String?;
    final eid = json['export_id'] as String?;
    final createdAt = json['created_at_iso'] as String?;
    if (staging == null || output == null || eid == null || createdAt == null) return null;
    return ArcxExportCheckpoint(
      stagingDirPath: staging,
      outputDirPath: output,
      exportId: eid,
      entryIds: (json['entry_ids'] as List<dynamic>?)?.cast<String>() ?? const [],
      chatThreadIds: (json['chat_thread_ids'] as List<dynamic>?)?.cast<String>() ?? const [],
      mediaIds: (json['media_ids'] as List<dynamic>?)?.cast<String>() ?? const [],
      startDateIso: json['start_date_iso'] as String?,
      endDateIso: json['end_date_iso'] as String?,
      createdAtIso: createdAt,
    );
  }
}

/// Persists and loads checkpoints under app documents directory.
class ArcxCheckpointService {
  ArcxCheckpointService._();
  static final ArcxCheckpointService instance = ArcxCheckpointService._();

  static const _kImportCheckpointFileName = 'arcx_import_checkpoint.json';
  static const _kExportCheckpointFileName = 'arcx_export_checkpoint.json';

  Future<String> _checkpointDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return path.join(dir.path, 'arcx_checkpoints');
  }

  Future<File> _importCheckpointFile() async {
    final dir = await _checkpointDir();
    await Directory(dir).create(recursive: true);
    return File(path.join(dir, _kImportCheckpointFileName));
  }

  Future<File> _exportCheckpointFile() async {
    final dir = await _checkpointDir();
    await Directory(dir).create(recursive: true);
    return File(path.join(dir, _kExportCheckpointFileName));
  }

  // ----- Import checkpoint -----

  Future<void> saveImportCheckpoint(ArcxImportCheckpoint checkpoint) async {
    final file = await _importCheckpointFile();
    await file.writeAsString(jsonEncode(checkpoint.toJson()));
  }

  Future<ArcxImportCheckpoint?> loadImportCheckpoint() async {
    final file = await _importCheckpointFile();
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>?;
      return ArcxImportCheckpoint.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearImportCheckpoint() async {
    final file = await _importCheckpointFile();
    if (await file.exists()) await file.delete();
  }

  /// Returns the import checkpoint if it exists and the payload directory still exists.
  Future<ArcxImportCheckpoint?> getResumableImportCheckpoint() async {
    final cp = await loadImportCheckpoint();
    if (cp == null) return null;
    if (!await Directory(cp.payloadDirPath).exists()) {
      await clearImportCheckpoint();
      return null;
    }
    return cp;
  }

  // ----- Export checkpoint -----

  Future<void> saveExportCheckpoint(ArcxExportCheckpoint checkpoint) async {
    final file = await _exportCheckpointFile();
    await file.writeAsString(jsonEncode(checkpoint.toJson()));
  }

  Future<ArcxExportCheckpoint?> loadExportCheckpoint() async {
    final file = await _exportCheckpointFile();
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>?;
      return ArcxExportCheckpoint.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearExportCheckpoint() async {
    final file = await _exportCheckpointFile();
    if (await file.exists()) await file.delete();
  }

  /// Returns the export checkpoint if it exists and the staging directory still exists.
  Future<ArcxExportCheckpoint?> getResumableExportCheckpoint() async {
    final cp = await loadExportCheckpoint();
    if (cp == null) return null;
    if (!await Directory(cp.stagingDirPath).exists()) {
      await clearExportCheckpoint();
      return null;
    }
    return cp;
  }
}

/// ARCX Result Models
/// 
/// Result types for ARCX export, import, and migration operations.
library arcx_result;

import 'arcx_manifest.dart';

class ARCXExportResult {
  final bool success;
  final String? arcxPath;
  final String? manifestPath;
  final String? error;
  final ARCXManifest? manifest;
  final ARCXExportStats? stats;
  
  ARCXExportResult({
    required this.success,
    this.arcxPath,
    this.manifestPath,
    this.error,
    this.manifest,
    this.stats,
  });
  
  factory ARCXExportResult.success({
    required String arcxPath,
    String? manifestPath,
    ARCXManifest? manifest,
    ARCXExportStats? stats,
  }) {
    return ARCXExportResult(
      success: true,
      arcxPath: arcxPath,
      manifestPath: manifestPath,
      manifest: manifest,
      stats: stats,
    );
  }
  
  factory ARCXExportResult.failure(String error) {
    return ARCXExportResult(
      success: false,
      error: error,
    );
  }
}

class ARCXImportResult {
  final bool success;
  final String? error;
  final int? entriesImported;
  final int? photosImported;
  final int? chatSessionsImported;
  final int? chatMessagesImported;
  final List<String>? warnings;
  
  ARCXImportResult({
    required this.success,
    this.error,
    this.entriesImported,
    this.photosImported,
    this.chatSessionsImported,
    this.chatMessagesImported,
    this.warnings,
  });
  
  factory ARCXImportResult.success({
    int? entriesImported,
    int? photosImported,
    int? chatSessionsImported,
    int? chatMessagesImported,
    List<String>? warnings,
  }) {
    return ARCXImportResult(
      success: true,
      entriesImported: entriesImported,
      photosImported: photosImported,
      chatSessionsImported: chatSessionsImported,
      chatMessagesImported: chatMessagesImported,
      warnings: warnings,
    );
  }
  
  factory ARCXImportResult.failure(String error) {
    return ARCXImportResult(
      success: false,
      error: error,
    );
  }
}

class ARCXMigrationResult {
  final bool success;
  final String? arcxPath;
  final String? manifestPath;
  final String? error;
  final ARCXManifest? manifest;
  final String? sourceZipPath;
  final String? sourceSha256;
  
  ARCXMigrationResult({
    required this.success,
    this.arcxPath,
    this.manifestPath,
    this.error,
    this.manifest,
    this.sourceZipPath,
    this.sourceSha256,
  });
  
  factory ARCXMigrationResult.success({
    required String arcxPath,
    String? manifestPath,
    ARCXManifest? manifest,
    String? sourceZipPath,
    String? sourceSha256,
  }) {
    return ARCXMigrationResult(
      success: true,
      arcxPath: arcxPath,
      manifestPath: manifestPath,
      manifest: manifest,
      sourceZipPath: sourceZipPath,
      sourceSha256: sourceSha256,
    );
  }
  
  factory ARCXMigrationResult.failure(String error) {
    return ARCXMigrationResult(
      success: false,
      error: error,
    );
  }
}

class ARCXExportStats {
  final int journalEntries;
  final int photoMetadata;
  final int totalBytes;
  final int encryptedBytes;
  final Duration exportDuration;
  
  ARCXExportStats({
    required this.journalEntries,
    required this.photoMetadata,
    required this.totalBytes,
    required this.encryptedBytes,
    required this.exportDuration,
  });
}


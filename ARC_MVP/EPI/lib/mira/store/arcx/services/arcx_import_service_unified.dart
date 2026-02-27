/// Unified ARCX Import Service
/// 
/// Provides a single interface for importing ARCX archives of all versions.
/// Automatically detects version and routes to the appropriate implementation.
library arcx_import_service_unified;

import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo.dart';
import 'package:my_app/services/phase_regime_service.dart';
import '../models/arcx_manifest.dart';
import '../models/arcx_result.dart';
import 'arcx_import_service.dart';
import 'arcx_import_service_v2.dart';

/// Unified ARCX Import Options
class UnifiedARCXImportOptions {
  final bool validateChecksums;
  final bool dedupeMedia;
  final bool skipExisting;
  final bool resolveLinks;
  
  UnifiedARCXImportOptions({
    this.validateChecksums = true,
    this.dedupeMedia = true,
    this.skipExisting = true,
    this.resolveLinks = true,
  });
}

/// Unified ARCX Import Result
class UnifiedARCXImportResult {
  final bool success;
  final int? entriesImported;
  final int? chatsImported;
  final int? mediaImported;
  final String? error;
  final List<String> warnings;
  final String? version; // ARCX version that was imported

  UnifiedARCXImportResult({
    required this.success,
    this.entriesImported,
    this.chatsImported,
    this.mediaImported,
    this.error,
    this.warnings = const [],
    this.version,
  });

  factory UnifiedARCXImportResult.fromV1(ARCXImportResult result) {
    return UnifiedARCXImportResult(
      success: result.success,
      entriesImported: result.entriesImported,
      chatsImported: result.chatSessionsImported,
      mediaImported: result.photosImported,
      error: result.error,
      warnings: result.warnings ?? [],
      version: '1.0/1.1',
    );
  }

  factory UnifiedARCXImportResult.fromV2(ARCXImportResultV2 result) {
    return UnifiedARCXImportResult(
      success: result.success,
      entriesImported: result.entriesImported,
      chatsImported: result.chatsImported,
      mediaImported: result.mediaImported,
      error: result.error,
      warnings: result.warnings ?? [],
      version: '1.2',
    );
  }
}

/// Unified ARCX Import Service
/// 
/// Automatically detects ARCX version and routes to appropriate implementation:
/// - ARCX 1.2 → ARCXImportServiceV2
/// - ARCX 1.0/1.1 → ARCXImportService (legacy)
class UnifiedARCXImportService {
  final JournalRepository? _journalRepo;
  final ChatRepo? _chatRepo;
  final PhaseRegimeService? _phaseRegimeService;
  
  ARCXImportService? _legacyService;
  ARCXImportServiceV2? _v2Service;

  UnifiedARCXImportService({
    JournalRepository? journalRepo,
    ChatRepo? chatRepo,
    PhaseRegimeService? phaseRegimeService,
  }) : _journalRepo = journalRepo,
       _chatRepo = chatRepo,
       _phaseRegimeService = phaseRegimeService;

  /// Detect ARCX version from manifest
  Future<String?> _detectVersion(String arcxPath) async {
    try {
      final arcxFile = File(arcxPath);
      if (!await arcxFile.exists()) {
        return null;
      }

      final arcxZip = await arcxFile.readAsBytes();
      final zipDecoder = ZipDecoder();
      final archive = zipDecoder.decodeBytes(arcxZip);

      ArchiveFile? manifestFile;
      for (final file in archive) {
        if (file.name == 'manifest.json') {
          manifestFile = file;
          break;
        }
      }

      if (manifestFile == null) {
        return null;
      }

      final manifestJson = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;
      final manifest = ARCXManifest.fromJson(manifestJson);
      
      return manifest.arcxVersion;
    } catch (e) {
      print('Unified ARCX Import: Failed to detect version: $e');
      return null;
    }
  }

  /// Import ARCX archive with automatic version detection
  Future<UnifiedARCXImportResult> import({
    required String arcxPath,
    UnifiedARCXImportOptions? options,
    String? password,
    Function(String)? onProgress,
  }) async {
    try {
      onProgress?.call('Detecting ARCX version...');
      
      // Detect version
      final version = await _detectVersion(arcxPath);
      
      if (version == '1.2') {
        // Use V2 service for ARCX 1.2
        _v2Service ??= ARCXImportServiceV2(
          journalRepo: _journalRepo,
          chatRepo: _chatRepo,
          phaseRegimeService: _phaseRegimeService,
        );
        
        final v2Options = ARCXImportOptions(
          validateChecksums: options?.validateChecksums ?? true,
          dedupeMedia: options?.dedupeMedia ?? true,
          skipExisting: options?.skipExisting ?? true,
          resolveLinks: options?.resolveLinks ?? true,
        );
        
        final result = await _v2Service!.import(
          arcxPath: arcxPath,
          options: v2Options,
          password: password,
          onProgress: onProgress != null ? (msg, [f]) => onProgress(msg) : null,
        );
        
        return UnifiedARCXImportResult.fromV2(result);
      } else {
        // Use legacy service for ARCX 1.0/1.1
        _legacyService ??= ARCXImportService(
          journalRepo: _journalRepo,
          chatRepo: _chatRepo,
        );
        
        final result = await _legacyService!.importSecure(
          arcxPath: arcxPath,
          manifestPath: null,
          dryRun: false,
          password: password,
        );
        
        return UnifiedARCXImportResult.fromV1(result);
      }
    } catch (e) {
      return UnifiedARCXImportResult(
        success: false,
        error: e.toString(),
        warnings: [],
      );
    }
  }
}


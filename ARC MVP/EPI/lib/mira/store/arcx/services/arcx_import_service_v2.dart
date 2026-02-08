/// ARCX Import Service V2
/// 
/// Implements the new ARCX import specification with link resolution,
/// media pack handling, deduplication, and new folder structure support.
library arcx_import_service_v2;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/arc/chat/chat/chat_repo.dart';
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:my_app/services/phase_regime_service.dart';
import 'package:my_app/models/phase_models.dart';
import 'package:uuid/uuid.dart';
import '../models/arcx_manifest.dart';
import 'arcx_crypto_service.dart';
import 'package:my_app/prism/atlas/rivet/rivet_storage.dart';
import 'package:my_app/prism/atlas/rivet/rivet_models.dart' as rivet_models;
import 'package:my_app/models/arcform_snapshot_model.dart';
import 'package:my_app/arc/chat/services/favorites_service.dart';
import 'package:my_app/arc/chat/data/models/lumara_favorite.dart';
import 'package:my_app/state/journal_entry_state.dart';
import 'package:hive/hive.dart';
import 'package:my_app/models/user_profile_model.dart';
import 'package:my_app/prism/atlas/phase/phase_inference_service.dart';
import 'package:my_app/services/export_history_service.dart';
import 'arcx_checkpoint_service.dart';
import 'arcx_import_set_index_service.dart';
import 'package:my_app/chronicle/storage/aggregation_repository.dart';
import 'package:my_app/chronicle/storage/changelog_repository.dart';
import 'package:my_app/chronicle/models/chronicle_layer.dart';
import 'package:my_app/chronicle/models/chronicle_aggregation.dart';
import 'package:my_app/arc/voice_notes/models/voice_note.dart';
import 'package:my_app/arc/voice_notes/repositories/voice_note_repository.dart';

const _uuid = Uuid();

/// Callback for import progress: message and optional fraction [0.0, 1.0].
typedef ImportProgressCallback = void Function(String message, [double fraction]);

/// ARCX Import Options
class ARCXImportOptions {
  final bool validateChecksums;
  final bool dedupeMedia;
  final bool skipExisting;
  final bool resolveLinks;
  
  ARCXImportOptions({
    this.validateChecksums = true,
    this.dedupeMedia = true,
    this.skipExisting = true,
    this.resolveLinks = true,
  });
}

/// Phase weights for overall progress (0.0 to 1.0)
const double _kPhaseLoad = 0.05;
const double _kPhaseVerify = 0.10;
const double _kPhaseDecrypt = 0.20;
const double _kPhaseExtract = 0.25;
const double _kPhaseMediaEnd = 0.50;
const double _kPhaseRegimesEnd = 0.55;
const double _kPhaseEntriesEnd = 0.90;
const double _kPhaseChatsEnd = 0.95;
const double _kPhaseResolveEnd = 1.0;
const int _kYieldInterval = 5;
const Duration _kYieldDuration = Duration(milliseconds: 100);

/// ARCX Import Service V2
class ARCXImportServiceV2 {
  final JournalRepository? _journalRepo;
  final ChatRepo? _chatRepo;
  final PhaseRegimeService? _phaseRegimeService;
  
  // Media deduplication cache - maps content_hash to MediaItem
  final Map<String, MediaItem> _mediaCache = {};
  
  // Link resolution tracking
  final Map<String, String> _entryIdMap = {}; // old_id -> new_id
  final Map<String, String> _chatIdMap = {}; // old_id -> new_id
  final Map<String, String> _mediaIdMap = {}; // old_id -> new_id
  final Map<String, List<String>> _missingLinks = {}; // type -> [ids]
  
  // Tracking for first backup on import
  bool _wasAppEmptyBeforeImport = false;
  final Set<String> _importedEntryIds = {};
  final Set<String> _importedChatIds = {};
  final Set<String> _importedMediaHashes = {};
  /// Total entry files in archive (for X of Y in result).
  int _entriesTotalInArchive = 0;
  /// Entry files that failed to import (parse/convert error).
  int _entriesFailed = 0;
  
  ARCXImportServiceV2({
    JournalRepository? journalRepo,
    ChatRepo? chatRepo,
    PhaseRegimeService? phaseRegimeService,
  }) : _journalRepo = journalRepo,
       _chatRepo = chatRepo,
       _phaseRegimeService = phaseRegimeService;
  
  /// Clear caches (call before starting a new import)
  void clearCaches() {
    _mediaCache.clear();
    _entryIdMap.clear();
    _chatIdMap.clear();
    _mediaIdMap.clear();
    _missingLinks.clear();
    _wasAppEmptyBeforeImport = false;
    _importedEntryIds.clear();
    _importedChatIds.clear();
    _importedMediaHashes.clear();
    _entriesTotalInArchive = 0;
    _entriesFailed = 0;
    print('ARCX Import V2: 🧹 Cleared caches for new import');
  }
  
  /// Check if app is empty (no entries, no chats)
  Future<bool> _checkIfAppIsEmpty() async {
    try {
      // Check entries
      if (_journalRepo != null) {
        final entries = await _journalRepo!.getAllJournalEntries();
        if (entries.isNotEmpty) {
          return false;
        }
      }
      
      // Check chats
      if (_chatRepo != null) {
        final chats = await _chatRepo!.listAll(includeArchived: true);
        if (chats.isNotEmpty) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      print('ARCX Import V2: ⚠️ Error checking if app is empty: $e');
      // If we can't check, assume not empty to be safe
      return false;
    }
  }
  
  /// Import ARCX archive.
  /// If [resumeIfPossible] is true (default), checks for an interrupted import of the same file
  /// and resumes from the extracted payload when possible.
  Future<ARCXImportResultV2> import({
    required String arcxPath,
    required ARCXImportOptions options,
    String? password,
    ImportProgressCallback? onProgress,
    bool resumeIfPossible = true,
  }) async {
    bool importSucceeded = false;
    bool didWriteCheckpoint = false;
    Directory? payloadDir;
    ARCXManifest? manifest;

    try {
      print('ARCX Import V2: Starting import from: $arcxPath');
      onProgress?.call('Loading archive...', 0.0);
      
      clearCaches();
      
      // Check if app is empty before import (for first backup tracking)
      _wasAppEmptyBeforeImport = await _checkIfAppIsEmpty();
      if (_wasAppEmptyBeforeImport) {
        print('ARCX Import V2: 📋 App is empty - will create export record after successful import');
      }
      
      final arcxFile = File(arcxPath);
      if (!await arcxFile.exists()) {
        throw Exception('ARCX file not found: $arcxPath');
      }

      // Resume: if we have a checkpoint for this file and payload dir exists, skip load/decrypt/extract
      if (resumeIfPossible) {
        final checkpoint = await ArcxCheckpointService.instance.getResumableImportCheckpoint();
        if (checkpoint != null && checkpoint.matchesFile(arcxFile)) {
          payloadDir = Directory(checkpoint.payloadDirPath);
          if (await payloadDir.exists()) {
            print('ARCX Import V2: 📂 Resuming from checkpoint (payload at ${payloadDir.path})');
            onProgress?.call('Resuming import...', _kPhaseExtract);
            // Parse manifest from payload for checksums/options
            final manifestFile = File(path.join(payloadDir.path, 'manifest.json'));
            if (await manifestFile.exists()) {
              final manifestJson = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
              manifest = ARCXManifest.fromJson(manifestJson);
            }
          }
        }
      }

      if (payloadDir == null) {
        // Step 1: Load and validate .arcx file
        final arcxZip = await arcxFile.readAsBytes();
        final zipDecoder = ZipDecoder();
        final archive = zipDecoder.decodeBytes(arcxZip);
        
        ArchiveFile? manifestFile;
        ArchiveFile? encryptedArchive;
        
        for (final file in archive) {
          if (file.name == 'manifest.json') {
            manifestFile = file;
          } else if (file.name == 'archive.arcx') {
            encryptedArchive = file;
          }
        }
        
        if (manifestFile == null || encryptedArchive == null) {
          throw Exception('Invalid ARCX archive: manifest or encrypted archive missing');
        }
        
        print('ARCX Import V2: ✓ Files extracted from .arcx');
        
        // Step 2: Parse and validate manifest
        final manifestJson = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;
        manifest = ARCXManifest.fromJson(manifestJson);
        
        final isNewFormat = manifest!.arcxVersion == '1.2';
        
        if (!isNewFormat) {
          throw Exception('This import service only supports ARCX 1.2 format. Please use the legacy import service for older formats.');
        }
        
        if (!manifest!.validate()) {
          throw Exception('Invalid ARCX 1.2 manifest structure. This archive may be corrupted.');
        }
        
        print('ARCX Import V2: ✓ Manifest validated (ARCX ${manifest!.arcxVersion})');
        await Future.delayed(_kYieldDuration);
        
        // Step 3: Verify signature
        onProgress?.call('Verifying signature...', _kPhaseLoad);
        
        if (manifest!.signatureB64.isNotEmpty && manifest!.signerPubkeyFpr.isNotEmpty) {
          final mj = manifest!.toJson();
          mj['signature_b64'] = '';
          final manifestBytes = utf8.encode(jsonEncode(mj));
          final isValid = await ARCXCryptoService.verifySignature(
            Uint8List.fromList(manifestBytes),
            manifest!.signatureB64,
          );
          if (!isValid) {
            print('ARCX Import V2: ⚠️ Signature verification failed - continuing anyway (signature optional for ARCX 1.2)');
          } else {
            print('ARCX Import V2: ✓ Signature verified');
          }
        } else {
          print('ARCX Import V2: ⚠️ No signature present - skipping verification (optional for ARCX 1.2)');
        }
        
        // Step 4: Verify ciphertext hash (if present)
        onProgress?.call('Verifying archive integrity...', _kPhaseVerify);
        final ciphertext = Uint8List.fromList(encryptedArchive.content as List<int>);
        
        if (manifest!.sha256.isNotEmpty) {
          final ciphertextHash = sha256.convert(ciphertext);
          final ciphertextHashB64 = base64Encode(ciphertextHash.bytes);
          if (ciphertextHashB64 != manifest!.sha256) {
            print('ARCX Import V2: ⚠️ Ciphertext hash mismatch - continuing anyway');
          } else {
            print('ARCX Import V2: ✓ Ciphertext hash verified');
          }
        } else {
          print('ARCX Import V2: ⚠️ No hash present in manifest - skipping hash verification');
        }
        
        // Step 5: Decrypt
        onProgress?.call('Decrypting...', _kPhaseVerify);
        Uint8List plaintextZip;
        
        try {
          if (manifest!.isPasswordEncrypted) {
            if (manifest!.saltB64 == null || manifest!.saltB64!.isEmpty) {
              throw Exception('Password encryption requires salt but none provided');
            }
            if (password == null || password.isEmpty) {
              throw Exception('This archive requires a password. Please provide a password to decrypt it.');
            }
            final saltBytes = base64Decode(manifest!.saltB64!);
            final salt = Uint8List.fromList(saltBytes);
            plaintextZip = await ARCXCryptoService.decryptWithPassword(ciphertext, password, salt);
            print('ARCX Import V2: ✓ Decrypted with password');
          } else {
            plaintextZip = await ARCXCryptoService.decryptAEAD(ciphertext);
            print('ARCX Import V2: ✓ Decrypted with device key');
          }
        } catch (e) {
          final msg = e.toString().toLowerCase();
          // CryptoKit Error 3 = authentication failure (wrong key or corrupted)
          if (msg.contains('decrypt') && (msg.contains('cryptokit') || msg.contains('crytptokit') || msg.contains('error 3') || msg.contains('authentication'))) {
            if (manifest!.isPasswordEncrypted) {
              throw Exception(
                'Could not decrypt this backup. The password may be wrong, or the file may be damaged.\n\n'
                'Try the password you used when creating the backup. If you don’t remember it, you’ll need a backup that was created with a password you know.',
              );
            } else {
              throw Exception(
                'This backup was encrypted with this device\'s secure key, but decryption failed. That can happen on the same device if the app was reinstalled or the key was reset (e.g. after an OS update).\n\n'
                'This backup cannot be opened without the original key. For backups you might need to open later (even on this device), create a new backup and choose “Encrypt with password” when exporting.',
              );
            }
          }
          rethrow;
        }
        
        print('ARCX Import V2: ✓ Decrypted (${plaintextZip.length} bytes)');
        await Future.delayed(_kYieldDuration);
        
        // Step 6: Extract payload
        onProgress?.call('Extracting payload...', _kPhaseDecrypt);
        final payloadArchive = ZipDecoder().decodeBytes(plaintextZip);
        
        final appDocDir = await getApplicationDocumentsDirectory();
        payloadDir = Directory(path.join(appDocDir.path, 'arcx_import_v2_${DateTime.now().millisecondsSinceEpoch}'));
        await payloadDir.create(recursive: true);
        
        for (final file in payloadArchive) {
          if (file.isFile) {
            final outFile = File(path.join(payloadDir!.path, file.name));
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          }
        }
        
        print('ARCX Import V2: ✓ Payload extracted');
        await Future.delayed(_kYieldDuration);
        
        // Save checkpoint so we can resume if interrupted
        final stat = await arcxFile.stat();
        await ArcxCheckpointService.instance.saveImportCheckpoint(ArcxImportCheckpoint(
          arcxPath: arcxPath,
          arcxFileLastModifiedMs: stat.modified.millisecondsSinceEpoch,
          arcxFileSize: stat.size,
          payloadDirPath: payloadDir!.path,
          createdAtIso: DateTime.now().toUtc().toIso8601String(),
        ));
        didWriteCheckpoint = true;
        
        // Step 7: Validate checksums if enabled
        if (options.validateChecksums && manifest!.checksumsInfo?.enabled == true) {
          onProgress?.call('Validating checksums...', _kPhaseExtract);
          await _validateChecksums(payloadDir!, manifest!.checksumsInfo!.file);
        }
      } else if (manifest != null && options.validateChecksums && manifest!.checksumsInfo?.enabled == true) {
        onProgress?.call('Validating checksums...', _kPhaseExtract);
        await _validateChecksums(payloadDir, manifest!.checksumsInfo!.file);
      }
      
      // Step 8: Import in order: Media first, then Phase Regimes (for entry tagging), then Entries, then Chats
        int mediaImported = 0;
        int entriesImported = 0;
        int chatsImported = 0;
        int phaseRegimesImported = 0;
        final warnings = <String>[];
        
        // Import Media
        final mediaDir = Directory(path.join(payloadDir!.path, 'Media'));
        if (await mediaDir.exists()) {
          onProgress?.call('Importing media...', _kPhaseExtract);
          mediaImported = await _importMedia(
            mediaDir: mediaDir,
            options: options,
            phaseStart: _kPhaseExtract,
            phaseEnd: _kPhaseMediaEnd,
            onProgress: onProgress,
          );
        }
        
        // Import Phase Regimes FIRST (before entries) so entries can be tagged correctly
        int rivetStatesImported = 0;
        int sentinelStatesImported = 0;
        int arcformSnapshotsImported = 0;
        Map<String, int> lumaraFavoritesImported = {'answers': 0, 'chats': 0, 'entries': 0};
        
        if (_phaseRegimeService != null) {
          phaseRegimesImported = await _importPhaseRegimes(
            payloadDir: payloadDir!,
            onProgress: onProgress,
          );
          
          // Re-initialize service after importing regimes to refresh PhaseIndex
          if (phaseRegimesImported > 0) {
            await _phaseRegimeService!.initialize();
            print('ARCX Import V2: ✓ Re-initialized PhaseRegimeService after importing $phaseRegimesImported regimes');
            
            // Update user profile with current phase from imported regimes
            await _updateUserPhaseFromRegimes();
          }
          
          // Import RIVET state, Sentinel state, ArcForm timeline, and LUMARA favorites alongside phase regimes
          rivetStatesImported = await _importRivetState(payloadDir!, onProgress: onProgress);
          sentinelStatesImported = await _importSentinelState(payloadDir!, onProgress: onProgress);
          arcformSnapshotsImported = await _importArcFormTimeline(payloadDir!, onProgress: onProgress);
        }
        
        // Import LUMARA favorites (doesn't require phaseRegimeService)
        lumaraFavoritesImported = await _importLumaraFavorites(payloadDir!, onProgress: onProgress);
        
        // Import CHRONICLE aggregations (monthly/yearly/multiyear .md files + changelog)
        onProgress?.call('Importing CHRONICLE aggregations...', _kPhaseRegimesEnd);
        final chronicleImported = await _importChronicle(payloadDir!, onProgress: onProgress);
        
        // Import voice notes (Voice Notes tab)
        onProgress?.call('Importing voice notes...', _kPhaseRegimesEnd);
        await _importVoiceNotes(payloadDir!, onProgress: onProgress);
        
        // Import Entries AFTER phase regimes so they can be tagged correctly
        final entriesDir = Directory(path.join(payloadDir!.path, 'Entries'));
        if (await entriesDir.exists()) {
          onProgress?.call('Importing entries...', _kPhaseRegimesEnd);
          entriesImported = await _importEntries(
            entriesDir: entriesDir,
            options: options,
            phaseStart: _kPhaseRegimesEnd,
            phaseEnd: _kPhaseEntriesEnd,
            onProgress: onProgress,
          );
          
          // Update user profile with current phase after entries are imported
          // (in case phase regimes were imported and current phase should be updated)
          if (_phaseRegimeService != null && phaseRegimesImported > 0) {
            await _updateUserPhaseFromRegimes();
          }
        }
        
        // Import Chats
        final chatsDir = Directory(path.join(payloadDir!.path, 'Chats'));
        if (await chatsDir.exists()) {
          onProgress?.call('Importing chats...', _kPhaseEntriesEnd);
          chatsImported = await _importChats(
            chatsDir: chatsDir,
            options: options,
            phaseStart: _kPhaseEntriesEnd,
            phaseEnd: _kPhaseChatsEnd,
            onProgress: onProgress,
          );
        }
        
        // Step 9: Resolve links
        if (options.resolveLinks) {
          onProgress?.call('Resolving links...', _kPhaseChatsEnd);
          await _resolveLinks();
        }
        
        // Step 10: Report missing links
        if (_missingLinks.isNotEmpty) {
          for (final entry in _missingLinks.entries) {
            warnings.add('Missing ${entry.key}: ${entry.value.length} items referenced but not found');
          }
        }
        
        onProgress?.call('Import complete!', _kPhaseResolveEnd);
        
        // Create export record if app was empty before import and we imported data
        if (_wasAppEmptyBeforeImport && (entriesImported > 0 || chatsImported > 0)) {
          try {
            await _createExportRecordFromImport(
              arcxPath: arcxPath,
              entriesImported: entriesImported,
              chatsImported: chatsImported,
              mediaImported: mediaImported,
            );
          } catch (e) {
            print('ARCX Import V2: ⚠️ Failed to create export record: $e');
            // Don't fail the import if export record creation fails
          }
        }
        
        return ARCXImportResultV2.success(
          entriesImported: entriesImported,
          chatsImported: chatsImported,
          mediaImported: mediaImported,
          phaseRegimesImported: phaseRegimesImported,
          rivetStatesImported: rivetStatesImported,
          sentinelStatesImported: sentinelStatesImported,
          arcformSnapshotsImported: arcformSnapshotsImported,
          lumaraFavoritesImported: lumaraFavoritesImported,
          warnings: warnings.isEmpty ? null : warnings,
          importedEntryIds: Set<String>.from(_importedEntryIds),
          importedChatIds: Set<String>.from(_importedChatIds),
          entriesTotalInArchive: _entriesTotalInArchive > 0 ? _entriesTotalInArchive : null,
          entriesFailed: _entriesFailed > 0 ? _entriesFailed : null,
        );
        
    } catch (e, stackTrace) {
      print('ARCX Import V2: ✗ Failed: $e');
      print('Stack trace: $stackTrace');
      return ARCXImportResultV2.failure(e.toString());
    } finally {
      // Clean up temp directory
      try {
        await payloadDir?.delete(recursive: true);
      } catch (e) {
        print('Warning: Could not delete temp directory: $e');
      }
    }
  }

  /// Preview what would be imported if we "continue import from folder":
  /// lists .arcx files and which are already in the import set index.
  Future<Map<String, dynamic>> getImportSetDiffPreview(Directory folder) async {
    return ArcxImportSetIndexService.instance.getImportSetDiffPreview(folder);
  }

  /// Look at a folder of .arcx files, skip ones already in the import set index,
  /// and import only the rest (with skipExisting so duplicates are skipped).
  /// After each successful import, records the source in the index.
  Future<ARCXImportContinueResult> importContinueFromFolder({
    required Directory folder,
    required ARCXImportOptions options,
    String? password,
    ImportProgressCallback? onProgress,
  }) async {
    final indexService = ArcxImportSetIndexService.instance;
    final preview = await indexService.getImportSetDiffPreview(folder);
    final toImportPaths = preview['toImportPaths'] as List<dynamic>? ?? [];
    if (toImportPaths.isEmpty) {
      onProgress?.call('All files in this folder have already been imported.', 1.0);
      return ARCXImportContinueResult(
        success: true,
        filesProcessed: 0,
        filesSkipped: preview['filesAlreadyImported'] as int? ?? 0,
        totalEntriesImported: 0,
        totalChatsImported: 0,
        totalMediaImported: 0,
        errors: null,
      );
    }
    int totalEntries = 0;
    int totalChats = 0;
    int totalMedia = 0;
    final errors = <String>[];
    final total = toImportPaths.length;
    for (int i = 0; i < toImportPaths.length; i++) {
      final arcxPath = toImportPaths[i] as String;
      final file = File(arcxPath);
      if (!await file.exists()) {
        errors.add('File no longer exists: $arcxPath');
        continue;
      }
      final frac = (i + 1) / total;
      onProgress?.call('Importing ${i + 1}/$total: ${path.basename(arcxPath)}...', frac);
      try {
        final result = await this.import(
          arcxPath: arcxPath,
          options: options,
          password: password,
          onProgress: onProgress,
          resumeIfPossible: true,
        );
        if (result.success) {
          totalEntries += result.entriesImported;
          totalChats += result.chatsImported;
          totalMedia += result.mediaImported;
          final stat = await file.stat();
          await indexService.recordImport(
            sourcePath: arcxPath,
            lastModifiedMs: stat.modified.millisecondsSinceEpoch,
            importedEntryIds: result.importedEntryIds ?? {},
            importedChatIds: result.importedChatIds ?? {},
          );
        } else {
          errors.add('${path.basename(arcxPath)}: ${result.error}');
        }
      } catch (e) {
        errors.add('${path.basename(arcxPath)}: $e');
      }
    }
    onProgress?.call('Continue import complete.', 1.0);
    return ARCXImportContinueResult(
      success: errors.isEmpty,
      filesProcessed: toImportPaths.length,
      filesSkipped: preview['filesAlreadyImported'] as int? ?? 0,
      totalEntriesImported: totalEntries,
      totalChatsImported: totalChats,
      totalMediaImported: totalMedia,
      errors: errors.isEmpty ? null : errors,
    );
  }
  
  /// Validate checksums
  Future<void> _validateChecksums(Directory payloadDir, String checksumsFile) async {
    final checksumsPath = path.join(payloadDir.path, checksumsFile);
    final checksumsFileObj = File(checksumsPath);
    
    if (!await checksumsFileObj.exists()) {
      print('ARCX Import V2: ⚠️ Checksums file not found: $checksumsFile');
      return;
    }
    
    final checksumsLines = await checksumsFileObj.readAsLines();
    final checksumsMap = <String, String>{};
    
    for (final line in checksumsLines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final hash = parts[0];
        final filePath = parts.sublist(1).join(' ').replaceFirst('./', '');
        checksumsMap[filePath] = hash;
      }
    }
    
    int validated = 0;
    int failed = 0;
    
    for (final entry in checksumsMap.entries) {
      final filePath = path.join(payloadDir.path, entry.key);
      final file = File(filePath);
      
      if (!await file.exists()) {
        print('ARCX Import V2: ⚠️ File in checksums not found: ${entry.key}');
        failed++;
        continue;
      }
      
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      
      if (hash != entry.value) {
        print('ARCX Import V2: ✗ Checksum mismatch: ${entry.key}');
        failed++;
      } else {
        validated++;
      }
    }
    
    print('ARCX Import V2: ✓ Validated $validated checksums${failed > 0 ? ', $failed failed' : ''}');
    
    if (failed > 0) {
      throw Exception('Checksum validation failed for $failed file(s)');
    }
  }
  
  /// Import media from /Media/packs/ and /Media/media_index.json
  Future<int> _importMedia({
    required Directory mediaDir,
    required ARCXImportOptions options,
    required double phaseStart,
    required double phaseEnd,
    ImportProgressCallback? onProgress,
  }) async {
    // Read media index
    final mediaIndexFile = File(path.join(mediaDir.path, 'media_index.json'));
    if (!await mediaIndexFile.exists()) {
      print('ARCX Import V2: ⚠️ Media index not found');
      return 0;
    }
    
    final mediaIndexJson = jsonDecode(await mediaIndexFile.readAsString()) as Map<String, dynamic>;
    final mediaItems = mediaIndexJson['items'] as List<dynamic>? ?? [];
    final packs = mediaIndexJson['packs'] as List<dynamic>? ?? [];
    
    print('ARCX Import V2: Found ${mediaItems.length} media items in ${packs.length} packs');
    
    // Get app documents directory for permanent storage
    final appDir = await getApplicationDocumentsDirectory();
    final permanentMediaDir = Directory(path.join(appDir.path, 'photos'));
    await permanentMediaDir.create(recursive: true);
    
    int imported = 0;
    final packsDir = Directory(path.join(mediaDir.path, 'packs'));
    
    // Process packs in order (using prev/next links)
    String? currentPackName;
    if (packs.isNotEmpty) {
      // Find first pack (prev == null)
      for (final pack in packs) {
        final packMap = pack as Map<String, dynamic>;
        if (packMap['prev'] == null) {
          currentPackName = packMap['name'] as String;
          break;
        }
      }
    }
    
    final totalPacks = packs.length;
    int packIndex = 0;
    // Process all packs
    while (currentPackName != null) {
      final packDir = Directory(path.join(packsDir.path, currentPackName));
      if (!await packDir.exists()) {
        print('ARCX Import V2: ⚠️ Pack directory not found: $currentPackName');
        break;
      }
      final frac = totalPacks > 0
          ? phaseStart + (phaseEnd - phaseStart) * (packIndex + 1) / totalPacks
          : phaseEnd;
      onProgress?.call('Importing media pack: $currentPackName...', frac);
      if (packIndex > 0) await Future.delayed(_kYieldDuration);
      
      // Process files in pack
      await for (final entity in packDir.list()) {
        if (entity is File) {
          try {
            final fileName = path.basename(entity.path);
            final mediaItemJson = mediaItems.firstWhere(
              (item) => (item as Map<String, dynamic>)['filename'] == fileName,
              orElse: () => null,
            );
            
            if (mediaItemJson == null) {
              print('ARCX Import V2: ⚠️ Media item not found in index: $fileName');
              continue;
            }
            
            final mediaItemData = mediaItemJson as Map<String, dynamic>;
            
            // Check for duplicates
            if (options.dedupeMedia) {
              final contentHash = mediaItemData['sha256'] as String?;
              if (contentHash != null && _mediaCache.containsKey(contentHash)) {
                print('ARCX Import V2: ♻️ Skipping duplicate media: $fileName');
                _mediaIdMap[mediaItemData['id'] as String] = _mediaCache[contentHash]!.id;
                continue;
              }
            }
            
            // Copy to permanent storage
            final destFile = File(path.join(permanentMediaDir.path, fileName));
            await entity.copy(destFile.path);
            
            // Create MediaItem
            final mediaItem = _createMediaItemFromJson(mediaItemData, destFile.path);
            if (mediaItem != null) {
              // Cache for deduplication (by SHA256 hash)
              final contentHash = mediaItemData['sha256'] as String?;
              if (contentHash != null) {
                if (options.dedupeMedia) {
                _mediaCache[contentHash] = mediaItem;
                }
                // Track media hash for export record
                _importedMediaHashes.add(contentHash);
              }
              
              // ALWAYS cache by ID for link resolution (even if deduplication is disabled)
              // This ensures media items can be found when resolving entry links
              if (!_mediaCache.values.any((item) => item.id == mediaItem.id)) {
                // If not already cached by hash, cache by ID
                _mediaCache[mediaItem.id] = mediaItem;
              }
              
              _mediaIdMap[mediaItemData['id'] as String] = mediaItem.id;
              imported++;
            }
            
          } catch (e) {
            print('ARCX Import V2: ⚠️ Error importing media file ${entity.path}: $e');
          }
        }
      }
      
      packIndex++;
      // Find next pack
      final currentPack = packs.firstWhere(
        (pack) => (pack as Map<String, dynamic>)['name'] == currentPackName,
        orElse: () => null,
      );
      
      if (currentPack != null) {
        currentPackName = (currentPack as Map<String, dynamic>)['next'] as String?;
      } else {
        break;
      }
    }
    
    print('ARCX Import V2: ✓ Imported $imported media items');
    return imported;
  }
  
  /// Import entries from /Entries/{yyyy}/{mm}/{dd}/
  Future<int> _importEntries({
    required Directory entriesDir,
    required ARCXImportOptions options,
    required double phaseStart,
    required double phaseEnd,
    ImportProgressCallback? onProgress,
  }) async {
    if (_journalRepo == null) {
      print('ARCX Import V2: ⚠️ No JournalRepository available, skipping entries');
      return 0;
    }
    
    // Collect all entry files first for progress and yielding
    final entryFiles = <File>[];
    await for (final entity in entriesDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.arcx.json')) {
        entryFiles.add(entity);
      }
    }
    final total = entryFiles.length;
    if (total == 0) {
      print('ARCX Import V2: No entry files found');
      return 0;
    }
    
    int imported = 0;
    int failed = 0;
    int processed = 0;
    for (int i = 0; i < entryFiles.length; i++) {
      final entity = entryFiles[i];
      processed++;
      try {
        final entryJson = jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        
        final entryId = entryJson['id'] as String;
        
        // Check if already exists
        if (options.skipExisting) {
          final existing = await _journalRepo!.getJournalEntryById(entryId);
          if (existing != null) {
            print('ARCX Import V2: ⚠️ Entry $entryId already exists, skipping');
            _entryIdMap[entryId] = entryId;
            _importedEntryIds.add(entryId);
            continue;
          }
        }
        
        final frac = phaseStart + (phaseEnd - phaseStart) * (i + 1) / total;
        onProgress?.call('Importing entry $processed/$total...', frac);
        if ((i + 1) % _kYieldInterval == 0) await Future.delayed(_kYieldDuration);
        
        // Convert to JournalEntry
        final entry = await _convertEntryJsonToJournalEntry(entryJson);
        if (entry != null) {
          await _journalRepo!.createJournalEntry(entry);
          _entryIdMap[entryId] = entry.id;
          _importedEntryIds.add(entry.id);
          imported++;
          
          if (entry.phaseMigrationStatus == 'PENDING' && !entry.isPhaseLocked) {
            _inferPhaseForImportedEntry(entry);
          }
        } else {
          failed++;
        }
        
      } catch (e) {
        print('ARCX Import V2: ✗ Error importing entry ${entity.path}: $e');
        failed++;
      }
    }
    
    _entriesTotalInArchive = total;
    _entriesFailed = failed;
    print('ARCX Import V2: ✓ Imported $imported entries (total in archive: $total, failed: $failed)');
    return imported;
  }
  
  /// Import phase regimes from PhaseRegimes/phase_regimes.json
  Future<int> _importPhaseRegimes({
    required Directory payloadDir,
    ImportProgressCallback? onProgress,
  }) async {
    if (_phaseRegimeService == null) {
      print('ARCX Import V2: ⚠️ No PhaseRegimeService available, skipping phase regimes');
      return 0;
    }
    
    // Try extensions/ first (new standard), fallback to PhaseRegimes/ for backward compatibility
    Directory phaseRegimesDir = Directory(path.join(payloadDir.path, 'extensions'));
    if (!await phaseRegimesDir.exists()) {
      phaseRegimesDir = Directory(path.join(payloadDir.path, 'PhaseRegimes'));
      if (!await phaseRegimesDir.exists()) {
        print('ARCX Import V2: ⚠️ extensions or PhaseRegimes directory not found');
      return 0;
      }
    }
    
    final phaseRegimesFile = File(path.join(phaseRegimesDir.path, 'phase_regimes.json'));
    if (!await phaseRegimesFile.exists()) {
      print('ARCX Import V2: ⚠️ phase_regimes.json not found');
      return 0;
    }
    
    try {
      onProgress?.call('Importing phase regimes...', _kPhaseRegimesEnd);
      final content = await phaseRegimesFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      
      await _phaseRegimeService!.importFromMcp(data);
      
      final regimes = data['phase_regimes'] as List? ?? [];
      print('ARCX Import V2: ✓ Imported ${regimes.length} phase regimes');
      return regimes.length;
    } catch (e) {
      print('ARCX Import V2: ⚠️ Error importing phase regimes: $e');
      return 0;
    }
  }

  /// Import RIVET state from extensions/rivet_state.json
  /// Returns the number of user states imported
  Future<int> _importRivetState(
    Directory payloadDir, {
    ImportProgressCallback? onProgress,
  }) async {
    try {
      // Try extensions/ first (new standard), fallback to PhaseRegimes/ for backward compatibility
      Directory phaseRegimesDir = Directory(path.join(payloadDir.path, 'extensions'));
      if (!await phaseRegimesDir.exists()) {
        phaseRegimesDir = Directory(path.join(payloadDir.path, 'PhaseRegimes'));
        if (!await phaseRegimesDir.exists()) {
          print('ARCX Import V2: ⚠️ extensions or PhaseRegimes directory not found, skipping RIVET state');
        return 0;
        }
      }

      final rivetStateFile = File(path.join(phaseRegimesDir.path, 'rivet_state.json'));
      if (!await rivetStateFile.exists()) {
        print('ARCX Import V2: ⚠️ rivet_state.json not found, skipping RIVET state');
        return 0;
      }

      onProgress?.call('Importing RIVET state...', _kPhaseRegimesEnd);
      final content = await rivetStateFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      
      final rivetStates = data['rivet_states'] as Map<String, dynamic>? ?? {};
      
      if (!Hive.isBoxOpen(RivetBox.boxName)) {
        await Hive.openBox(RivetBox.boxName);
      }
      if (!Hive.isBoxOpen(RivetBox.eventsBoxName)) {
        await Hive.openBox(RivetBox.eventsBoxName);
      }
      
      final stateBox = Hive.box(RivetBox.boxName);
      final eventsBox = Hive.box(RivetBox.eventsBoxName);
      
      int importedCount = 0;
      for (final entry in rivetStates.entries) {
        final userId = entry.key;
        final userData = entry.value as Map<String, dynamic>;
        
        final stateJson = userData['state'] as Map<String, dynamic>;
        final rivetState = rivet_models.RivetState.fromJson(stateJson);
        
        // Save state
        await stateBox.put(userId, rivetState.toJson());
        
        // Save events if present
        final eventsJson = userData['events'] as List<dynamic>? ?? [];
        if (eventsJson.isNotEmpty) {
          final events = eventsJson
              .map((e) => rivet_models.RivetEvent.fromJson(e as Map<String, dynamic>))
              .toList();
          await eventsBox.put(userId, events.map((e) => e.toJson()).toList());
        }
        
        importedCount++;
      }
      
      print('ARCX Import V2: ✓ Imported RIVET state for $importedCount users');
      return importedCount;
    } catch (e) {
      print('ARCX Import V2: ⚠️ Error importing RIVET state: $e');
      return 0;
    }
  }

  /// Import Sentinel state from extensions/sentinel_state.json
  /// Returns 1 if imported successfully, 0 otherwise
  Future<int> _importSentinelState(
    Directory payloadDir, {
    ImportProgressCallback? onProgress,
  }) async {
    try {
      // Try extensions/ first (new standard), fallback to PhaseRegimes/ for backward compatibility
      Directory phaseRegimesDir = Directory(path.join(payloadDir.path, 'extensions'));
      if (!await phaseRegimesDir.exists()) {
        phaseRegimesDir = Directory(path.join(payloadDir.path, 'PhaseRegimes'));
        if (!await phaseRegimesDir.exists()) {
          print('ARCX Import V2: ⚠️ extensions or PhaseRegimes directory not found, skipping Sentinel state');
        return 0;
        }
      }

      final sentinelStateFile = File(path.join(phaseRegimesDir.path, 'sentinel_state.json'));
      if (!await sentinelStateFile.exists()) {
        print('ARCX Import V2: ⚠️ sentinel_state.json not found, skipping Sentinel state');
        return 0;
      }

      onProgress?.call('Importing Sentinel state...', _kPhaseRegimesEnd);
      await sentinelStateFile.readAsString(); // Read to validate file exists
      
      // Sentinel state is computed dynamically, so we just log that it was imported
      // In the future, if Sentinel state is stored persistently, we can restore it here
      print('ARCX Import V2: ✓ Imported Sentinel state (note: Sentinel state is computed dynamically)');
      return 1;
    } catch (e) {
      print('ARCX Import V2: ⚠️ Error importing Sentinel state: $e');
      return 0;
    }
  }

  /// Import ArcForm timeline from PhaseRegimes/arcform_timeline.json
  /// Returns the number of snapshots imported
  Future<int> _importArcFormTimeline(
    Directory payloadDir, {
    ImportProgressCallback? onProgress,
  }) async {
    try {
      final phaseRegimesDir = Directory(path.join(payloadDir.path, 'PhaseRegimes'));
      if (!await phaseRegimesDir.exists()) {
        print('ARCX Import V2: ⚠️ PhaseRegimes directory not found, skipping ArcForm timeline');
        return 0;
      }

      final arcformTimelineFile = File(path.join(phaseRegimesDir.path, 'arcform_timeline.json'));
      if (!await arcformTimelineFile.exists()) {
        print('ARCX Import V2: ⚠️ arcform_timeline.json not found, skipping ArcForm timeline');
        return 0;
      }

      onProgress?.call('Importing ArcForm timeline...', _kPhaseRegimesEnd);
      final content = await arcformTimelineFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      
      final snapshotsJson = data['arcform_snapshots'] as List<dynamic>? ?? [];
      
      if (!Hive.isBoxOpen('arcform_snapshots')) {
        await Hive.openBox<ArcformSnapshot>('arcform_snapshots');
      }
      
      final box = Hive.box<ArcformSnapshot>('arcform_snapshots');
      
      int importedCount = 0;
      int skippedCount = 0;
      
      for (final snapshotJson in snapshotsJson) {
        try {
          final snapshot = ArcformSnapshot.fromJson(snapshotJson as Map<String, dynamic>);
          
          // Check for duplicates
          if (box.containsKey(snapshot.id)) {
            skippedCount++;
            continue;
          }
          
          await box.put(snapshot.id, snapshot);
          importedCount++;
        } catch (e) {
          print('ARCX Import V2: ⚠️ Failed to import ArcForm snapshot: $e');
          skippedCount++;
        }
      }
      
      print('ARCX Import V2: ✓ Imported $importedCount ArcForm snapshots ($skippedCount skipped)');
      return importedCount;
    } catch (e) {
      print('ARCX Import V2: ⚠️ Error importing ArcForm timeline: $e');
      return 0;
    }
  }

  /// Import LUMARA favorites from extensions/lumara_favorites.json
  /// Returns map with counts per category: {'answers': X, 'chats': Y, 'entries': Z}
  /// Imports with deduplication - checks for existing favorites by sourceId, sessionId, or entryId
  Future<Map<String, int>> _importLumaraFavorites(
    Directory payloadDir, {
    ImportProgressCallback? onProgress,
  }) async {
    try {
      // Try extensions/ first (new standard), fallback to PhaseRegimes/ for backward compatibility
      Directory extensionsDir = Directory(path.join(payloadDir.path, 'extensions'));
      if (!await extensionsDir.exists()) {
        extensionsDir = Directory(path.join(payloadDir.path, 'PhaseRegimes'));
        if (!await extensionsDir.exists()) {
          print('ARCX Import V2: ⚠️ extensions or PhaseRegimes directory not found, skipping LUMARA favorites');
          return {'answers': 0, 'chats': 0, 'entries': 0};
        }
      }

      final favoritesFile = File(path.join(extensionsDir.path, 'lumara_favorites.json'));
      if (!await favoritesFile.exists()) {
        print('ARCX Import V2: ⚠️ lumara_favorites.json not found in ${extensionsDir.path}, skipping LUMARA favorites');
        return {'answers': 0, 'chats': 0, 'entries': 0};
      }

      onProgress?.call('Importing LUMARA favorites...', _kPhaseRegimesEnd);
      final content = await favoritesFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      
      final favoritesJson = data['lumara_favorites'] as List<dynamic>? ?? [];
      
      // Initialize FavoritesService with timeout to prevent hanging
      FavoritesService favoritesService;
      try {
        favoritesService = FavoritesService.instance;
        await favoritesService.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('ARCX Import V2: ⚠️ FavoritesService.initialize() timed out after 10 seconds');
            throw TimeoutException('FavoritesService initialization timed out', const Duration(seconds: 10));
          },
        );
      } catch (e) {
        print('ARCX Import V2: ⚠️ Failed to initialize FavoritesService: $e');
        print('ARCX Import V2: ⚠️ Skipping LUMARA favorites import due to initialization failure');
        return {'answers': 0, 'chats': 0, 'entries': 0}; // Don't fail the entire import if favorites service fails
      }
      
      // Import with deduplication - check for existing favorites to avoid duplicates
      int importedAnswers = 0;
      int importedChats = 0;
      int importedEntries = 0;
      int skippedCount = 0;
      
      for (final favoriteJson in favoritesJson) {
        try {
          final favoriteMap = favoriteJson as Map<String, dynamic>;
          
          // Get category (default to 'answer' for backward compatibility)
          final category = favoriteMap['category'] as String? ?? 'answer';
          
          final favorite = LumaraFavorite(
            id: favoriteMap['id'] as String,
            content: favoriteMap['content'] as String,
            timestamp: DateTime.parse(favoriteMap['timestamp'] as String),
            sourceId: favoriteMap['source_id'] as String?,
            sourceType: favoriteMap['source_type'] as String?,
            metadata: favoriteMap['metadata'] as Map<String, dynamic>? ?? {},
            category: category,
            sessionId: favoriteMap['session_id'] as String?,
            entryId: favoriteMap['entry_id'] as String?,
          );
          
          // Check if favorite already exists (by sourceId if available, or by sessionId/entryId for category-specific)
          bool alreadyExists = false;
          if (favorite.sourceId != null) {
            try {
              final existing = await favoritesService.findFavoriteBySourceId(favorite.sourceId!).timeout(
                const Duration(seconds: 2),
                onTimeout: () => null,
              );
              if (existing != null) {
                alreadyExists = true;
              }
            } catch (e) {
              // Continue to try adding it anyway
            }
          }
          
          // Also check category-specific lookups
          if (!alreadyExists) {
            if (category == 'chat' && favorite.sessionId != null) {
              final existing = await favoritesService.findFavoriteChatBySessionId(favorite.sessionId!);
              if (existing != null) {
                alreadyExists = true;
              }
            } else if (category == 'journal_entry' && favorite.entryId != null) {
              final existing = await favoritesService.findFavoriteJournalEntryByEntryId(favorite.entryId!);
              if (existing != null) {
                alreadyExists = true;
              }
            }
          }
          
          if (alreadyExists) {
            skippedCount++;
            continue;
          }
          
          // Check category-specific capacity
          try {
            final atCapacity = await favoritesService.isCategoryAtCapacity(category).timeout(
              const Duration(seconds: 2),
              onTimeout: () => false,
            );
            if (atCapacity) {
              print('ARCX Import V2: ⚠️ Category $category at capacity, cannot import more');
              skippedCount++;
              continue;
            }
          } catch (e) {
            print('ARCX Import V2: ⚠️ Error checking capacity for $category: $e');
            // Continue to try adding it anyway
          }
          
          // Add favorite with timeout
          try {
            final added = await favoritesService.addFavorite(favorite).timeout(
              const Duration(seconds: 5),
              onTimeout: () => false,
            );
            if (added) {
              if (category == 'answer') {
                importedAnswers++;
              } else if (category == 'chat') {
                importedChats++;
              } else if (category == 'journal_entry') {
                importedEntries++;
              }
            } else {
              skippedCount++;
            }
          } catch (e) {
            print('ARCX Import V2: ⚠️ Error adding favorite ${favorite.id}: $e');
            skippedCount++;
          }
        } catch (e) {
          print('ARCX Import V2: ⚠️ Failed to import LUMARA favorite: $e');
          skippedCount++;
        }
      }
      
      print('ARCX Import V2: ✓ Imported LUMARA favorites (${importedAnswers} answers, ${importedChats} chats, ${importedEntries} entries, $skippedCount skipped)');
      return {
        'answers': importedAnswers,
        'chats': importedChats,
        'entries': importedEntries,
      };
    } catch (e, stackTrace) {
      print('ARCX Import V2: ⚠️ Error importing LUMARA favorites: $e');
      print('ARCX Import V2: Stack trace: $stackTrace');
      // Don't fail the entire import if favorites fail - just return empty map
      return {'answers': 0, 'chats': 0, 'entries': 0};
    }
  }

  /// Import CHRONICLE aggregations from Chronicle/ directory
  /// Returns map with counts: {'monthly': X, 'yearly': Y, 'multiyear': Z, 'changelog_entries': N}
  Future<Map<String, int>> _importChronicle(
    Directory payloadDir, {
    ImportProgressCallback? onProgress,
  }) async {
    try {
      final chronicleDir = Directory(path.join(payloadDir.path, 'Chronicle'));
      if (!await chronicleDir.exists()) {
        print('ARCX Import V2: ⚠️ Chronicle directory not found, skipping CHRONICLE import');
        return {
          'monthly': 0,
          'yearly': 0,
          'multiyear': 0,
          'changelog_entries': 0,
        };
      }

      final aggregationRepo = AggregationRepository();
      final changelogRepo = ChangelogRepository();
      
      // Get current user ID (default to 'default_user' if not available)
      // In production, this should come from FirebaseAuthService
      const userId = 'default_user';
      
      int monthlyCount = 0;
      int yearlyCount = 0;
      int multiyearCount = 0;
      
      // Helper function to parse markdown with frontmatter
      ChronicleAggregation _parseAggregationFile(
        String content,
        ChronicleLayer layer,
        String period,
      ) {
        // Split frontmatter and markdown
        if (!content.startsWith('---')) {
          throw FormatException('Invalid aggregation format: missing frontmatter');
        }

        final parts = content.split('---');
        if (parts.length < 3) {
          throw FormatException('Invalid aggregation format: malformed frontmatter');
        }

        final frontmatter = parts[1].trim();
        final markdown = parts.sublist(2).join('---').trim();

        // Parse YAML frontmatter
        final metadata = <String, dynamic>{};
        for (final line in frontmatter.split('\n')) {
          if (line.contains(':')) {
            final parts = line.split(':');
            if (parts.length >= 2) {
              final key = parts[0].trim();
              final value = parts.sublist(1).join(':').trim();
              
              if (key == 'entry_count' || key == 'version') {
                metadata[key] = int.parse(value);
              } else if (key == 'compression_ratio') {
                metadata[key] = double.parse(value);
              } else if (key == 'user_edited') {
                metadata[key] = value.toLowerCase() == 'true';
              } else if (key == 'synthesis_date') {
                metadata[key] = DateTime.parse(value);
              } else if (key == 'source_entry_ids') {
                metadata[key] = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              }
            }
          }
        }

        return ChronicleAggregation(
          layer: layer,
          period: period,
          synthesisDate: metadata['synthesis_date'] as DateTime,
          entryCount: metadata['entry_count'] as int,
          compressionRatio: metadata['compression_ratio'] as double,
          content: markdown,
          sourceEntryIds: List<String>.from(metadata['source_entry_ids'] as List? ?? []),
          userEdited: metadata['user_edited'] as bool? ?? false,
          version: metadata['version'] as int? ?? 1,
          userId: userId,
        );
      }
      
      // Import monthly aggregations
      final monthlyDir = Directory(path.join(chronicleDir.path, 'monthly'));
      if (await monthlyDir.exists()) {
        onProgress?.call('Importing monthly aggregations...', _kPhaseRegimesEnd);
        final monthlyFiles = monthlyDir.listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.md'))
            .toList();
        
        for (final file in monthlyFiles) {
          try {
            final content = await file.readAsString();
            final period = path.basenameWithoutExtension(file.path);
            
            final aggregation = _parseAggregationFile(
              content,
              ChronicleLayer.monthly,
              period,
            );
            
            await aggregationRepo.saveMonthly(userId, aggregation);
            monthlyCount++;
          } catch (e) {
            print('ARCX Import V2: ⚠️ Failed to import monthly aggregation ${file.path}: $e');
          }
        }
      }
      
      // Import yearly aggregations
      final yearlyDir = Directory(path.join(chronicleDir.path, 'yearly'));
      if (await yearlyDir.exists()) {
        onProgress?.call('Importing yearly aggregations...', _kPhaseRegimesEnd);
        final yearlyFiles = yearlyDir.listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.md'))
            .toList();
        
        for (final file in yearlyFiles) {
          try {
            final content = await file.readAsString();
            final period = path.basenameWithoutExtension(file.path);
            
            final aggregation = _parseAggregationFile(
              content,
              ChronicleLayer.yearly,
              period,
            );
            
            await aggregationRepo.saveYearly(userId, aggregation);
            yearlyCount++;
          } catch (e) {
            print('ARCX Import V2: ⚠️ Failed to import yearly aggregation ${file.path}: $e');
          }
        }
      }
      
      // Import multi-year aggregations
      final multiyearDir = Directory(path.join(chronicleDir.path, 'multiyear'));
      if (await multiyearDir.exists()) {
        onProgress?.call('Importing multi-year aggregations...', _kPhaseRegimesEnd);
        final multiyearFiles = multiyearDir.listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.md'))
            .toList();
        
        for (final file in multiyearFiles) {
          try {
            final content = await file.readAsString();
            final period = path.basenameWithoutExtension(file.path);
            
            final aggregation = _parseAggregationFile(
              content,
              ChronicleLayer.multiyear,
              period,
            );
            
            await aggregationRepo.saveMultiYear(userId, aggregation);
            multiyearCount++;
          } catch (e) {
            print('ARCX Import V2: ⚠️ Failed to import multi-year aggregation ${file.path}: $e');
          }
        }
      }
      
      // Import changelog
      final changelogFile = File(path.join(chronicleDir.path, 'changelog.jsonl'));
      int changelogEntries = 0;
      if (await changelogFile.exists()) {
        onProgress?.call('Importing changelog...', _kPhaseRegimesEnd);
        final content = await changelogFile.readAsString();
        final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
        
        for (final line in lines) {
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            final entry = ChangelogEntry.fromJson(json);
            
            // Log the entry (this will append to the existing changelog)
            await changelogRepo.log(
              userId: entry.userId,
              layer: entry.layer,
              action: entry.action,
              metadata: entry.metadata,
              error: entry.error,
            );
            changelogEntries++;
          } catch (e) {
            print('ARCX Import V2: ⚠️ Failed to import changelog entry: $e');
          }
        }
      }
      
      print('ARCX Import V2: ✓ Imported CHRONICLE: $monthlyCount monthly, $yearlyCount yearly, $multiyearCount multiyear, $changelogEntries changelog entries');
      
      return {
        'monthly': monthlyCount,
        'yearly': yearlyCount,
        'multiyear': multiyearCount,
        'changelog_entries': changelogEntries,
      };
    } catch (e) {
      print('ARCX Import V2: ⚠️ Error importing CHRONICLE: $e');
      return {
        'monthly': 0,
        'yearly': 0,
        'multiyear': 0,
        'changelog_entries': 0,
      };
    }
  }

  /// Import voice notes from extensions/voice_notes.json
  Future<int> _importVoiceNotes(
    Directory payloadDir, {
    ImportProgressCallback? onProgress,
  }) async {
    try {
      Directory extensionsDir = Directory(path.join(payloadDir.path, 'extensions'));
      if (!await extensionsDir.exists()) {
        print('ARCX Import V2: ⚠️ extensions directory not found, skipping voice notes');
        return 0;
      }

      final voiceNotesFile = File(path.join(extensionsDir.path, 'voice_notes.json'));
      if (!await voiceNotesFile.exists()) {
        print('ARCX Import V2: ⚠️ voice_notes.json not found, skipping voice notes');
        return 0;
      }

      onProgress?.call('Importing voice notes...', _kPhaseRegimesEnd);
      final content = await voiceNotesFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final notesJson = data['voice_notes'] as List<dynamic>? ?? [];

      Box<VoiceNote> box;
      if (Hive.isBoxOpen(VoiceNoteRepository.boxName)) {
        box = Hive.box<VoiceNote>(VoiceNoteRepository.boxName);
      } else {
        box = await Hive.openBox<VoiceNote>(VoiceNoteRepository.boxName);
      }

      int imported = 0;
      for (final noteJson in notesJson) {
        try {
          final m = noteJson as Map<String, dynamic>;
          final note = VoiceNote(
            id: m['id'] as String,
            timestamp: DateTime.parse(m['timestamp'] as String),
            transcription: m['transcription'] as String? ?? '',
            tags: (m['tags'] as List<dynamic>?)?.cast<String>() ?? [],
            archived: m['archived'] as bool? ?? false,
            convertedToJournal: m['convertedToJournal'] as bool? ?? false,
            convertedEntryId: m['convertedEntryId'] as String?,
            durationMs: m['durationMs'] as int?,
          );
          await box.put(note.id, note);
          imported++;
        } catch (e) {
          print('ARCX Import V2: ⚠️ Failed to import voice note: $e');
        }
      }

      print('ARCX Import V2: ✓ Imported $imported voice notes');
      return imported;
    } catch (e) {
      print('ARCX Import V2: ⚠️ Error importing voice notes: $e');
      return 0;
    }
  }

  /// Import chats from /Chats/{yyyy}/{mm}/{dd}/
  Future<int> _importChats({
    required Directory chatsDir,
    required ARCXImportOptions options,
    required double phaseStart,
    required double phaseEnd,
    ImportProgressCallback? onProgress,
  }) async {
    if (_chatRepo == null) {
      print('ARCX Import V2: ⚠️ No ChatRepo available, skipping chats');
      return 0;
    }
    
    if (!await chatsDir.exists()) {
      print('ARCX Import V2: ⚠️ Chats directory does not exist: ${chatsDir.path}');
      return 0;
    }
    
    // Collect all chat files first for progress and yielding
    final chatFiles = <File>[];
    await for (final entity in chatsDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.arcx.json')) {
        chatFiles.add(entity);
      }
    }
    final total = chatFiles.length;
    if (total == 0) {
      print('ARCX Import V2: No chat files found');
      return 0;
    }
    
    int imported = 0;
    int processed = 0;
    int skipped = 0;
    int errors = 0;
    print('ARCX Import V2: 🔍 Importing ${chatFiles.length} chat files...');
    
    for (int i = 0; i < chatFiles.length; i++) {
      final entity = chatFiles[i];
      processed++;
      try {
        final chatJson = jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        
        final chatId = chatJson['id'] as String? ?? 'unknown';
        final subject = chatJson['subject'] as String? ?? 'Imported Chat';
        final messages = chatJson['messages'] as List<dynamic>? ?? [];
        
        if (options.skipExisting) {
          try {
            final existing = await _chatRepo!.getSession(chatId);
            if (existing != null) {
              _chatIdMap[chatId] = chatId;
              _importedChatIds.add(chatId);
              skipped++;
              continue;
            }
          } catch (_) {}
        }
        
        final frac = phaseStart + (phaseEnd - phaseStart) * (i + 1) / total;
        onProgress?.call('Importing chat $processed/$total: "$subject"...', frac);
        if ((i + 1) % _kYieldInterval == 0) await Future.delayed(_kYieldDuration);
        
        final chat = await _convertChatJsonToChatSession(chatJson);
        if (chat != null) {
          _chatIdMap[chatId] = chat.id;
          _importedChatIds.add(chat.id);
          imported++;
        } else {
          errors++;
        }
        
      } catch (e, stackTrace) {
        print('ARCX Import V2: ✗ Error importing chat ${entity.path}: $e');
        errors++;
      }
    }
    
    print('ARCX Import V2: ✓ Chat import complete - Processed: $processed, Imported: $imported, Skipped: $skipped, Errors: $errors');
    return imported;
  }
  
  /// Resolve links between entries, chats, and media
  Future<void> _resolveLinks() async {
    if (_journalRepo == null) {
      print('ARCX Import V2: No JournalRepository available, skipping link resolution');
      return;
    }
    
    print('ARCX Import V2: Resolving links...');
    
    // Update entries with resolved media
    for (final entryIdMapping in _entryIdMap.entries) {
      final originalId = entryIdMapping.key;
      final newId = entryIdMapping.value;
      
      try {
        final entry = await _journalRepo!.getJournalEntryById(newId);
        if (entry != null) {
          // Check if entry has unresolved media links
          // The media should already be resolved during entry import,
          // but we track any missing links for reporting
          final unresolvedMedia = entry.media.where((media) => !_mediaIdMap.values.contains(media.id)).toList();
          
          if (unresolvedMedia.isNotEmpty) {
            // Track missing media links
            for (final media in unresolvedMedia) {
              _missingLinks['media'] ??= [];
              if (!(_missingLinks['media'] as List).contains(media.id)) {
                (_missingLinks['media'] as List).add(media.id);
              }
            }
          }
        }
      } catch (e) {
        print('ARCX Import V2: ⚠️ Error resolving links for entry $originalId: $e');
      }
    }
    
    print('ARCX Import V2: ✓ Link resolution completed');
    
    // Report missing links
    if (_missingLinks.isNotEmpty) {
      print('ARCX Import V2: ⚠️ Missing links detected:');
      for (final entry in _missingLinks.entries) {
        print('  - ${entry.key}: ${entry.value.length} items');
      }
    }
  }
  
  /// Convert entry JSON to JournalEntry
  Future<JournalEntry?> _convertEntryJsonToJournalEntry(Map<String, dynamic> entryJson) async {
    try {
      final entryId = entryJson['id'] as String;
      final title = entryJson['title'] as String? ?? 'Imported Entry';
      final content = entryJson['content'] as String? ?? '';
      final createdAt = DateTime.parse(entryJson['created_at'] as String);
      
      // Resolve media links - try link-based format first, then fallback to embedded media
      final mediaItems = <MediaItem>[];
      
      // Method 1: Try link-based format (links.media_ids)
      final mediaIds = (entryJson['links'] as Map<String, dynamic>?)?['media_ids'] as List<dynamic>? ?? [];
      
      for (final mediaId in mediaIds) {
        final resolvedId = _mediaIdMap[mediaId as String];
        if (resolvedId != null) {
          // Find media item by resolved ID (try direct lookup first, then search)
          MediaItem? mediaItem;
          
          // Try direct lookup by ID (if cached by ID)
          if (_mediaCache.containsKey(resolvedId)) {
            mediaItem = _mediaCache[resolvedId];
          } else {
            // Fallback: search by ID in cache values
            try {
              mediaItem = _mediaCache.values.firstWhere(
                (item) => item.id == resolvedId,
              );
            } catch (_) {
              // Media item not found in cache
              mediaItem = null;
            }
          }
          
          if (mediaItem != null) {
            mediaItems.add(mediaItem);
          } else {
            // Track missing media link
            _missingLinks['media'] ??= [];
            if (!(_missingLinks['media'] as List).contains(mediaId)) {
              (_missingLinks['media'] as List).add(mediaId);
            }
            print('ARCX Import V2: ⚠️ Media item not found in cache: original_id=$mediaId, resolved_id=$resolvedId');
          }
        } else {
          // Original media ID not found in mapping
          _missingLinks['media'] ??= [];
          if (!(_missingLinks['media'] as List).contains(mediaId)) {
            (_missingLinks['media'] as List).add(mediaId);
          }
          print('ARCX Import V2: ⚠️ Media ID not found in mapping: $mediaId');
        }
      }
      
      // Method 2: Fallback to embedded media format (for backward compatibility)
      // This handles ARCX exports that use the old format with embedded media arrays
      if (mediaItems.isEmpty) {
        final embeddedMediaData = _extractEmbeddedMediaData(entryJson);
        if (embeddedMediaData.isNotEmpty) {
          print('ARCX Import V2: Found ${embeddedMediaData.length} embedded media items for entry $entryId');
          
          for (final mediaJson in embeddedMediaData) {
            if (mediaJson is Map<String, dynamic>) {
              try {
                final mediaId = mediaJson['id'] as String? ?? 
                               mediaJson['photo_id'] as String? ?? 
                               mediaJson['placeholder_id'] as String? ?? 
                               '';
                
                // Try to find this media item in the cache by ID
                MediaItem? mediaItem;
                
                // First, check if we have a mapping for this ID
                final resolvedId = _mediaIdMap[mediaId];
                if (resolvedId != null) {
                  // Try direct lookup
                  if (_mediaCache.containsKey(resolvedId)) {
                    mediaItem = _mediaCache[resolvedId];
                  } else {
                    // Search cache values
                    try {
                      mediaItem = _mediaCache.values.firstWhere(
                        (item) => item.id == resolvedId,
                      );
                    } catch (_) {
                      mediaItem = null;
                    }
                  }
                } else if (mediaId.isNotEmpty) {
                  // Try direct lookup by original ID
                  try {
                    mediaItem = _mediaCache.values.firstWhere(
                      (item) => item.id == mediaId,
                    );
                  } catch (_) {
                    mediaItem = null;
                  }
                }
                
                // If still not found, try to create from embedded data
                if (mediaItem == null && mediaJson['filename'] != null) {
                  final filename = mediaJson['filename'] as String;
                  // Try to find media file by filename
                  try {
                    final appDir = await getApplicationDocumentsDirectory();
                    final permanentMediaDir = Directory(path.join(appDir.path, 'photos'));
                    final mediaFile = File(path.join(permanentMediaDir.path, filename));
                    
                    if (await mediaFile.exists()) {
                      // Create MediaItem from embedded data
                      mediaItem = _createMediaItemFromEmbeddedData(mediaJson, mediaFile.path);
                      if (mediaItem != null) {
                        // Cache it for future lookups
                        _mediaCache[mediaItem.id] = mediaItem;
                        if (mediaId.isNotEmpty) {
                          _mediaIdMap[mediaId] = mediaItem.id;
                        }
                      }
                    }
                  } catch (e) {
                    print('ARCX Import V2: ⚠️ Error creating media item from embedded data: $e');
                  }
                }
                
                if (mediaItem != null) {
                  mediaItems.add(mediaItem);
                } else {
                  print('ARCX Import V2: ⚠️ Could not resolve embedded media item: id=$mediaId, filename=${mediaJson['filename']}');
                }
              } catch (e) {
                print('ARCX Import V2: ⚠️ Error processing embedded media item: $e');
              }
            }
          }
        }
      }
      
      // Read phase fields from imported JSON (new versioned phase system)
      // Preserve phase data from newer archives, set migration status for older ones
      final autoPhase = entryJson['autoPhase'] as String?;
      final autoPhaseConfidence = (entryJson['autoPhaseConfidence'] as num?)?.toDouble();
      final userPhaseOverride = entryJson['userPhaseOverride'] as String?;
      final isPhaseLocked = entryJson['isPhaseLocked'] as bool? ?? false;
      final legacyPhaseTag = entryJson['legacyPhaseTag'] as String? ?? entryJson['phase'] as String?;
      final importSource = entryJson['importSource'] as String? ?? 'ARCHX';
      final phaseInferenceVersion = entryJson['phaseInferenceVersion'] as int?;
      final phaseMigrationStatus = entryJson['phaseMigrationStatus'] as String?;

      // Extract LUMARA blocks from new or legacy locations
      final lumaraBlocks = _parseLumaraBlocks(
        entryJson['lumaraBlocks'] ??
            (entryJson['metadata'] as Map<String, dynamic>?)?['inlineBlocks'],
      );
      
      // Determine migration status:
      // - If phaseInferenceVersion is null or < CURRENT_VERSION, mark as PENDING
      // - If phase fields are present, preserve them
      // - Otherwise, set to PENDING for inference after import
      final migrationStatus = phaseMigrationStatus ?? 
          (phaseInferenceVersion == null || phaseInferenceVersion < CURRENT_PHASE_INFERENCE_VERSION 
              ? 'PENDING' 
              : 'DONE');
      
      return JournalEntry(
        id: entryId,
        title: title,
        content: content, // Content without auto-added phase hashtag
        createdAt: createdAt,
        updatedAt: createdAt,
        media: mediaItems,
        tags: (entryJson['keywords'] as List<dynamic>? ?? []).cast<String>(),
        keywords: (entryJson['keywords'] as List<dynamic>? ?? []).cast<String>(),
        mood: entryJson['emotion'] as String? ?? '',
        emotion: entryJson['emotion'] as String?,
        emotionReason: entryJson['emotionReason'] as String?,
        phase: legacyPhaseTag, // Keep old phase field for backward compatibility
        autoPhase: autoPhase,
        autoPhaseConfidence: autoPhaseConfidence,
        userPhaseOverride: userPhaseOverride,
        isPhaseLocked: isPhaseLocked,
        legacyPhaseTag: legacyPhaseTag,
        importSource: importSource,
        phaseInferenceVersion: phaseInferenceVersion,
        phaseMigrationStatus: migrationStatus,
        lumaraBlocks: lumaraBlocks,
        metadata: {
          'imported_from_arcx_v2': true,
          'original_export_id': entryJson['id'],
          'import_timestamp': DateTime.now().toUtc().toIso8601String(),
          ...?entryJson['metadata'] as Map<String, dynamic>?,
        },
      );
    } catch (e) {
      print('ARCX Import V2: ✗ Error converting entry: $e');
      return null;
    }
  }
  
  /// Convert chat JSON to ChatSession and import messages
  Future<ChatSession?> _convertChatJsonToChatSession(Map<String, dynamic> chatJson) async {
    try {
      if (_chatRepo == null) {
        print('ARCX Import V2: ⚠️ No ChatRepo available, skipping chat import');
        return null;
      }
      
      final subject = chatJson['subject'] as String? ?? 'Imported Chat';
      final messages = chatJson['messages'] as List<dynamic>? ?? [];
      
      // Create session using ChatRepo
      final sessionId = await _chatRepo!.createSession(
        subject: subject,
        tags: (chatJson['tags'] as List<dynamic>? ?? []).cast<String>(),
      );
      
      // Get the created session
      final session = await _chatRepo!.getSession(sessionId);
      if (session == null) {
        print('ARCX Import V2: ✗ Failed to get created session');
        return null;
      }
      
      // Import messages
      for (final messageJson in messages) {
        try {
          final messageMap = messageJson as Map<String, dynamic>;
          final role = messageMap['role'] as String? ?? 'user';
          final content = messageMap['content'] as String? ?? 
                         messageMap['textContent'] as String? ?? 
                         messageMap['text'] as String? ?? '';
          
          if (content.isEmpty) continue;
          
          // Handle contentParts if present (for multimodal messages)
          if (messageMap['content_parts'] != null) {
            // For multimodal messages, we need to reconstruct the content
            // For now, use the text content if available
            final contentParts = messageMap['content_parts'] as List<dynamic>;
            final textParts = contentParts
                .where((part) => (part as Map<String, dynamic>)['type'] == 'text')
                .map((part) => (part as Map<String, dynamic>)['text'] as String)
                .join('\n');
            
            if (textParts.isNotEmpty) {
              await _chatRepo!.addMessage(
                sessionId: sessionId,
                role: role,
                content: textParts,
              );
            }
          } else {
            await _chatRepo!.addMessage(
              sessionId: sessionId,
              role: role,
              content: content,
            );
          }
        } catch (e) {
          print('ARCX Import V2: ⚠️ Error importing message: $e');
          // Continue with other messages
        }
      }
      
      // Update session metadata if needed
      // Only archive if explicitly set to true (don't archive by default)
      final isArchived = chatJson['is_archived'] as bool? ?? false;
      if (isArchived) {
        await _chatRepo!.archiveSession(sessionId, true);
        print('ARCX Import V2: 📦 Chat $sessionId was archived in export, keeping archived status');
      } else {
        // Ensure chat is NOT archived (in case it was archived before)
        await _chatRepo!.archiveSession(sessionId, false);
        print('ARCX Import V2: ✅ Chat $sessionId is active (not archived)');
      }
      
      if (chatJson['is_pinned'] == true) {
        await _chatRepo!.pinSession(sessionId, true);
      }
      
      // Verify final state
      final finalSession = await _chatRepo!.getSession(sessionId);
      final finalMessages = await _chatRepo!.getMessages(sessionId);
      
      print('ARCX Import V2: ✓ Imported chat session $sessionId');
      print('  - Subject: "${finalSession?.subject ?? subject}"');
      print('  - Messages: ${finalMessages.length}/${messages.length}');
      print('  - Archived: ${finalSession?.isArchived ?? false}');
      print('  - Pinned: ${finalSession?.isPinned ?? false}');
      
      return session;
    } catch (e) {
      print('ARCX Import V2: ✗ Error converting chat: $e');
      return null;
    }
  }
  
  /// Extract embedded media data from entry JSON (backward compatibility)
  /// Checks multiple locations: entry.media, metadata.media, metadata.journal_entry.media, metadata.photos
  List<dynamic> _extractEmbeddedMediaData(Map<String, dynamic> entryJson) {
    List<dynamic>? mediaData = entryJson['media'] as List<dynamic>?;
    
    // Fallback 1: Check metadata.media
    if (mediaData == null || mediaData.isEmpty) {
      final metadataObj = entryJson['metadata'] as Map<String, dynamic>?;
      if (metadataObj != null) {
        mediaData = metadataObj['media'] as List<dynamic>?;
      }
    }
    
    // Fallback 2: Check metadata.journal_entry.media
    if (mediaData == null || mediaData.isEmpty) {
      final metadataObj = entryJson['metadata'] as Map<String, dynamic>?;
      if (metadataObj != null) {
        final journalEntryMeta = metadataObj['journal_entry'] as Map<String, dynamic>?;
        if (journalEntryMeta != null) {
          mediaData = journalEntryMeta['media'] as List<dynamic>?;
        }
      }
    }
    
    // Fallback 3: Check metadata.photos
    if (mediaData == null || mediaData.isEmpty) {
      final metadataObj = entryJson['metadata'] as Map<String, dynamic>?;
      if (metadataObj != null) {
        final photosData = metadataObj['photos'] as List<dynamic>?;
        if (photosData != null && photosData.isNotEmpty) {
          // Convert photos array to media format
          mediaData = photosData.map((photo) {
            if (photo is Map<String, dynamic>) {
              return {
                'id': photo['id'] ?? photo['placeholder_id'] ?? '',
                'filename': photo['filename'],
                'originalPath': photo['uri'] ?? photo['path'],
                'createdAt': photo['createdAt'],
                'analysisData': photo['analysisData'],
                'altText': photo['altText'],
                'ocrText': photo['ocrText'],
                'sha256': photo['sha256'],
                'content_type': photo['content_type'] ?? 'image/jpeg',
              };
            }
            return photo;
          }).toList();
        }
      }
    }
    
    return mediaData ?? [];
  }

  /// Parse LUMARA inline blocks from either List<Map> or JSON string formats used in older exports.
  List<InlineBlock> _parseLumaraBlocks(dynamic rawBlocks) {
    if (rawBlocks == null) return const [];

    try {
      if (rawBlocks is List) {
        return rawBlocks
            .whereType<Map>()
            .map((block) => InlineBlock.fromJson(block.cast<String, dynamic>()))
            .toList();
      }

      if (rawBlocks is String) {
        final decoded = jsonDecode(rawBlocks);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((block) => InlineBlock.fromJson(block.cast<String, dynamic>()))
              .toList();
        }
      }
    } catch (e) {
      print('ARCX Import V2: ⚠️ Error parsing LUMARA blocks: $e');
    }

    return const [];
  }
  
  /// Create MediaItem from embedded data (wrapper for _createMediaItemFromJson)
  MediaItem? _createMediaItemFromEmbeddedData(Map<String, dynamic> mediaJson, String filePath) {
    // Ensure required fields are present
    final enhancedJson = {
      ...mediaJson,
      'filename': mediaJson['filename'] ?? path.basename(filePath),
      'content_type': mediaJson['content_type'] ?? 'image/jpeg',
    };
    
    return _createMediaItemFromJson(enhancedJson, filePath);
  }
  
  /// Create MediaItem from JSON
  MediaItem? _createMediaItemFromJson(Map<String, dynamic> mediaJson, String filePath) {
    try {
      final mediaId = mediaJson['id'] as String? ?? _uuid.v4();
      final createdAtStr = mediaJson['created_at'] as String?;
      final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();
      
      // Determine media type from content_type
      final contentType = mediaJson['content_type'] as String? ?? 'image/jpeg';
      MediaType mediaType;
      if (contentType.startsWith('image/')) {
        mediaType = MediaType.image;
      } else if (contentType.startsWith('video/')) {
        mediaType = MediaType.video;
      } else if (contentType.startsWith('audio/')) {
        mediaType = MediaType.audio;
      } else {
        mediaType = MediaType.file;
      }
      
      return MediaItem(
        id: mediaId,
        type: mediaType,
        uri: filePath,
        createdAt: createdAt,
        sha256: mediaJson['sha256'] as String?,
      );
    } catch (e) {
      print('ARCX Import V2: ✗ Error creating MediaItem: $e');
      return null;
    }
  }
  
  /// Helper to convert PhaseLabel enum to string name
  String _getPhaseLabelNameFromEnum(PhaseLabel label) {
    switch (label) {
      case PhaseLabel.discovery:
        return 'discovery';
      case PhaseLabel.expansion:
        return 'expansion';
      case PhaseLabel.transition:
        return 'transition';
      case PhaseLabel.consolidation:
        return 'consolidation';
      case PhaseLabel.recovery:
        return 'recovery';
      case PhaseLabel.breakthrough:
        return 'breakthrough';
    }
  }

  /// Update user profile with current phase from phase regimes
  Future<void> _updateUserPhaseFromRegimes() async {
    try {
      if (_phaseRegimeService == null) {
        print('ARCX Import V2: No PhaseRegimeService available, skipping phase update');
        return;
      }

      // Determine current phase from phase index
      String? currentPhaseName;
      final currentRegime = _phaseRegimeService!.phaseIndex.currentRegime;
      
      if (currentRegime != null) {
        // Use current ongoing regime
        currentPhaseName = _getPhaseLabelNameFromEnum(currentRegime.label);
        // Capitalize first letter
        currentPhaseName = currentPhaseName.substring(0, 1).toUpperCase() + currentPhaseName.substring(1);
      } else {
        // No current ongoing regime, use most recent one
        final allRegimes = _phaseRegimeService!.phaseIndex.allRegimes;
        if (allRegimes.isNotEmpty) {
          final sortedRegimes = List<PhaseRegime>.from(allRegimes)
            ..sort((a, b) => b.start.compareTo(a.start));
          final mostRecent = sortedRegimes.first;
          currentPhaseName = _getPhaseLabelNameFromEnum(mostRecent.label);
          // Capitalize first letter
          currentPhaseName = currentPhaseName.substring(0, 1).toUpperCase() + currentPhaseName.substring(1);
        } else {
          // No regimes at all, use default
          currentPhaseName = 'Discovery';
        }
      }

      // Update user profile
      final userBox = await Hive.openBox<UserProfile>('user_profile');
      final userProfile = userBox.get('profile');
      
      if (userProfile != null) {
        final updatedProfile = userProfile.copyWith(
          onboardingCurrentSeason: currentPhaseName,
          currentPhase: currentPhaseName,
          lastPhaseChangeAt: DateTime.now(),
        );
        await userBox.put('profile', updatedProfile);
        print('ARCX Import V2: ✓ Updated user profile phase to: $currentPhaseName');
      } else {
        print('ARCX Import V2: ⚠️ No user profile found, cannot update phase');
      }
    } catch (e) {
      print('ARCX Import V2: ⚠️ Error updating user phase from regimes: $e');
      // Don't throw - phase update failure shouldn't break import
    }
  }
  
  /// Create export record from imported backup (for first backup on import)
  Future<void> _createExportRecordFromImport({
    required String arcxPath,
    required int entriesImported,
    required int chatsImported,
    required int mediaImported,
  }) async {
    try {
      print('ARCX Import V2: 📝 Creating export record for imported backup...');
      
      // Get file size
      int archiveSizeBytes = 0;
      try {
        final arcxFile = File(arcxPath);
        if (await arcxFile.exists()) {
          archiveSizeBytes = await arcxFile.length();
        }
      } catch (e) {
        print('ARCX Import V2: ⚠️ Could not get file size: $e');
      }
      
      // Get next export number (or use 1 if no history exists)
      final exportHistoryService = ExportHistoryService.instance;
      final history = await exportHistoryService.getHistory();
      final exportNumber = history.totalExports == 0 
          ? 1 
          : await exportHistoryService.getNextExportNumber();
      
      // Create export record
      final record = ExportRecord(
        exportId: _uuid.v4(),
        exportedAt: DateTime.now(),
        exportPath: arcxPath,
        entryIds: _importedEntryIds,
        chatIds: _importedChatIds,
        mediaHashes: _importedMediaHashes,
        entriesCount: entriesImported,
        chatsCount: chatsImported,
        mediaCount: mediaImported,
        archiveSizeBytes: archiveSizeBytes,
        isFullBackup: true,
        exportNumber: exportNumber,
      );
      
      // Record the export
      await exportHistoryService.recordExport(record);
      
      print('ARCX Import V2: ✅ Created export record #$exportNumber');
      print('  - Entries: ${_importedEntryIds.length} (${entriesImported} imported)');
      print('  - Chats: ${_importedChatIds.length} (${chatsImported} imported)');
      print('  - Media: ${_importedMediaHashes.length} (${mediaImported} imported)');
      
      // Clear tracking variables
      _importedEntryIds.clear();
      _importedChatIds.clear();
      _importedMediaHashes.clear();
    } catch (e, stackTrace) {
      print('ARCX Import V2: ✗ Error creating export record: $e');
      print('ARCX Import V2: Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Infer phase for an imported entry that needs migration
  Future<void> _inferPhaseForImportedEntry(JournalEntry entry) async {
    try {
      if (_journalRepo == null) return;
      
      // Get recent entries for context
      final allEntries = await _journalRepo!.getAllJournalEntries();
      allEntries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final recentEntries = allEntries.take(7).toList();
      
      // Get user profile for userId
      final userBox = await Hive.openBox<UserProfile>('user_profile');
      final userProfile = userBox.get('profile');
      final userId = userProfile?.id ?? '';
      
      // Run phase inference
      final inferenceResult = await PhaseInferenceService.inferPhaseForEntry(
        entryContent: entry.content,
        userId: userId,
        createdAt: entry.createdAt,
        recentEntries: recentEntries,
        emotion: entry.emotion,
        emotionReason: entry.emotionReason,
        selectedKeywords: entry.keywords,
      );
      
      // Update entry with phase fields
      final updatedEntry = entry.copyWith(
        autoPhase: inferenceResult.phase,
        autoPhaseConfidence: inferenceResult.confidence,
        phaseInferenceVersion: CURRENT_PHASE_INFERENCE_VERSION,
        phaseMigrationStatus: 'DONE',
      );
      
      // Save updated entry
      await _journalRepo!.updateJournalEntry(updatedEntry);
      
      print('ARCX Import V2: ✓ Phase inference completed for entry ${entry.id}: ${inferenceResult.phase} (confidence: ${inferenceResult.confidence.toStringAsFixed(3)})');
    } catch (e) {
      print('ARCX Import V2: ✗ Phase inference failed for entry ${entry.id}: $e');
    }
  }
}

/// ARCX Import Result V2
class ARCXImportResultV2 {
  final bool success;
  final int entriesImported;
  final int chatsImported;
  final int mediaImported;
  final int phaseRegimesImported;
  final int rivetStatesImported;
  final int sentinelStatesImported;
  final int arcformSnapshotsImported;
  final Map<String, int> lumaraFavoritesImported;
  final List<String>? warnings;
  final String? error;
  /// IDs actually imported (for import set index / continue-import tracking).
  final Set<String>? importedEntryIds;
  final Set<String>? importedChatIds;
  /// Total entry files in archive (for "X of Y" in UI).
  final int? entriesTotalInArchive;
  /// Entry files that failed to import.
  final int? entriesFailed;

  ARCXImportResultV2({
    required this.success,
    this.entriesImported = 0,
    this.chatsImported = 0,
    this.mediaImported = 0,
    this.phaseRegimesImported = 0,
    this.rivetStatesImported = 0,
    this.sentinelStatesImported = 0,
    this.arcformSnapshotsImported = 0,
    this.lumaraFavoritesImported = const {'answers': 0, 'chats': 0, 'entries': 0},
    this.warnings,
    this.error,
    this.importedEntryIds,
    this.importedChatIds,
    this.entriesTotalInArchive,
    this.entriesFailed,
  });

  factory ARCXImportResultV2.success({
    int entriesImported = 0,
    int chatsImported = 0,
    int mediaImported = 0,
    int phaseRegimesImported = 0,
    int rivetStatesImported = 0,
    int sentinelStatesImported = 0,
    int arcformSnapshotsImported = 0,
    Map<String, int>? lumaraFavoritesImported,
    List<String>? warnings,
    Set<String>? importedEntryIds,
    Set<String>? importedChatIds,
    int? entriesTotalInArchive,
    int? entriesFailed,
  }) {
    return ARCXImportResultV2(
      success: true,
      entriesImported: entriesImported,
      chatsImported: chatsImported,
      mediaImported: mediaImported,
      phaseRegimesImported: phaseRegimesImported,
      rivetStatesImported: rivetStatesImported,
      sentinelStatesImported: sentinelStatesImported,
      arcformSnapshotsImported: arcformSnapshotsImported,
      lumaraFavoritesImported: lumaraFavoritesImported ?? const {'answers': 0, 'chats': 0, 'entries': 0},
      warnings: warnings,
      importedEntryIds: importedEntryIds,
      importedChatIds: importedChatIds,
      entriesTotalInArchive: entriesTotalInArchive,
      entriesFailed: entriesFailed,
    );
  }
  
  factory ARCXImportResultV2.failure(String error) {
    return ARCXImportResultV2(
      success: false,
      error: error,
    );
  }
}

/// Result of "continue import from folder" (multiple .arcx files).
class ARCXImportContinueResult {
  final bool success;
  final int filesProcessed;
  final int filesSkipped;
  final int totalEntriesImported;
  final int totalChatsImported;
  final int totalMediaImported;
  final List<String>? errors;

  const ARCXImportContinueResult({
    required this.success,
    required this.filesProcessed,
    required this.filesSkipped,
    required this.totalEntriesImported,
    required this.totalChatsImported,
    required this.totalMediaImported,
    this.errors,
  });
}

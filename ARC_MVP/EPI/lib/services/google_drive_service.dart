// Google Drive service for export/import backup via OAuth.
// Uses drive.file scope so the app only accesses files it creates or opens.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/models/journal_entry_model.dart';

const String _kPrefSelectedFolderId = 'google_drive_backup_folder_id';
const String _kPrefSyncFolderId = 'google_drive_sync_folder_id';
const String _kPrefSyncFolderName = 'google_drive_sync_folder_name';
const String _kPrefSyncedTxtIds = 'google_drive_synced_txt_ids';
const String _kPrefSyncedTxtRecords = 'google_drive_synced_txt_records';
const int _kMaxSyncedTxtRecords = 500;
const String _kDriveAppFolderName = 'LUMARA Backups';

/// One synced .txt file: maps Drive file ID to ARC entry and last known Drive modified time.
class SyncedTxtRecord {
  final String driveFileId;
  final String journalEntryId;
  final String? modifiedTimeIso; // Drive file modifiedTime when we last synced
  /// Folder ID this file was synced from (for filtering "push to Drive" by current sync folder).
  final String? syncFolderId;

  SyncedTxtRecord({
    required this.driveFileId,
    required this.journalEntryId,
    this.modifiedTimeIso,
    this.syncFolderId,
  });

  Map<String, dynamic> toJson() => {
        'driveFileId': driveFileId,
        'journalEntryId': journalEntryId,
        'modifiedTimeIso': modifiedTimeIso,
        if (syncFolderId != null && syncFolderId!.isNotEmpty) 'syncFolderId': syncFolderId,
      };

  static SyncedTxtRecord? fromJson(dynamic map) {
    if (map is! Map) return null;
    final driveFileId = map['driveFileId']?.toString();
    final journalEntryId = map['journalEntryId']?.toString();
    if (driveFileId == null || driveFileId.isEmpty) return null;
    return SyncedTxtRecord(
      driveFileId: driveFileId,
      journalEntryId: journalEntryId ?? '',
      modifiedTimeIso: map['modifiedTimeIso']?.toString(),
      syncFolderId: map['syncFolderId']?.toString(),
    );
  }
}

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  static GoogleDriveService get instance => _instance;

  GoogleSignIn? _googleSignIn;
  drive.DriveApi? _driveApi;
  String? _currentAccountEmail;
  bool _initialized = false;

  /// Cache of dated subfolder ID by date name (yyyy-MM-dd) so multiple uploads the same day
  /// always use the same folder without relying on list eventual consistency.
  final Map<String, String> _datedSubfolderIdByDateName = {};

  /// Drive API scope: only files the app creates or opens.
  static const String driveFileScope = 'https://www.googleapis.com/auth/drive.file';
  /// Read-only scope: list and download files from any folder (for folder picker / import from Drive).
  static const String driveReadOnlyScope = 'https://www.googleapis.com/auth/drive.readonly';
  /// All Drive scopes used for sign-in (file + readonly for browse/import).
  static const List<String> driveScopes = [driveFileScope, driveReadOnlyScope];

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      _googleSignIn = GoogleSignIn.instance;
      await _googleSignIn!.initialize(
        clientId: kIsWeb ? const String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID') : null,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('GoogleDriveService: init failed: $e');
      rethrow;
    }
  }

  /// Sign in with Google and request Drive (drive.file + drive.readonly) scope.
  /// Returns the signed-in account email or null if user cancelled.
  Future<String?> signIn() async {
    await _ensureInitialized();
    try {
      final account = await _googleSignIn!.authenticate(
        scopeHint: driveScopes,
      );
      final auth = await account.authorizationClient.authorizeScopes(driveScopes);
      final client = auth.authClient(scopes: driveScopes);
      _driveApi = drive.DriveApi(client);
      _currentAccountEmail = account.email;
      return account.email;
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('cancelled') || msg.contains('sign_in_canceled')) {
        return null;
      }
      debugPrint('GoogleDriveService: signIn failed: $e');
      rethrow;
    }
  }

  /// Sign out from Drive (does not sign out from Firebase/Google Sign-In used for app auth).
  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    _driveApi = null;
    _currentAccountEmail = null;
    _datedSubfolderIdByDateName.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefSelectedFolderId);
  }

  /// Whether the user is signed in for Drive and we have an API client.
  bool get isSignedIn => _driveApi != null;

  /// Current account email if signed in.
  String? get currentUserEmail => _currentAccountEmail;

  /// Ensure we have a valid Drive API client (e.g. after app restart, restore from cached account).
  /// Attempts to restore the last signed-in account via attemptLightweightAuthentication (7.x), then authorizes Drive scope.
  Future<bool> restoreSession() async {
    await _ensureInitialized();
    if (_driveApi != null && _currentAccountEmail != null) return true;
    try {
      final future = _googleSignIn!.attemptLightweightAuthentication(reportAllExceptions: false);
      if (future == null) return false;
      final account = await future;
      if (account == null) return false;
      final auth = await account.authorizationClient.authorizeScopes(driveScopes);
      final client = auth.authClient(scopes: driveScopes);
      _driveApi = drive.DriveApi(client);
      _currentAccountEmail = account.email;
      return true;
    } on Exception catch (e) {
      debugPrint('GoogleDriveService: restoreSession failed: $e');
      return false;
    }
  }

  /// Selected backup folder ID (persisted).
  Future<String?> getSelectedFolderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrefSelectedFolderId);
  }

  Future<void> setSelectedFolderId(String? folderId) async {
    final prefs = await SharedPreferences.getInstance();
    if (folderId == null) {
      await prefs.remove(_kPrefSelectedFolderId);
    } else {
      await prefs.setString(_kPrefSelectedFolderId, folderId);
    }
  }

  /// Create or get the single "LUMARA Backups" folder. Looks for an existing folder by name first to avoid creating duplicates.
  /// Returns folder ID.
  Future<String> getOrCreateAppFolder() async {
    _requireDriveApi();
    final existingId = await getSelectedFolderId();
    if (existingId != null && existingId.isNotEmpty) {
      try {
        await _driveApi!.files.get(existingId);
        return existingId;
      } catch (_) {
        // Folder may have been deleted; fall through to search then create.
      }
    }
    // Search for an existing "LUMARA Backups" folder (avoids duplicate folders).
    try {
      final response = await _driveApi!.files.list(
        q: "name = '$_kDriveAppFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        pageSize: 10,
        $fields: 'files(id,name)',
      );
      final files = response.files ?? [];
      if (files.isNotEmpty) {
        final id = files.first.id;
        if (id != null && id.isNotEmpty) {
          await setSelectedFolderId(id);
          return id;
        }
      }
    } catch (e) {
      debugPrint('GoogleDriveService: search for LUMARA Backups folder: $e');
    }
    // No existing folder found; create one.
    final file = drive.File();
    file.name = _kDriveAppFolderName;
    file.mimeType = 'application/vnd.google-apps.folder';
    final created = await _driveApi!.files.create(file);
    await setSelectedFolderId(created.id);
    return created.id!;
  }

  /// Get or create a dated subfolder (yyyy-MM-dd) inside "LUMARA Backups". Returns the dated folder ID.
  /// Always looks for an existing folder for that date first so multiple uploads the same day
  /// go into the same folder (no duplicate same-day folders). Uses an in-memory cache so a
  /// second upload in the same session reuses the folder even if Drive list hasn't updated yet.
  Future<String> getOrCreateDatedSubfolder(DateTime date) async {
    _requireDriveApi();
    final dateName = _formatDateFolderName(date);
    final cached = _datedSubfolderIdByDateName[dateName];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final arcBackupsId = await getOrCreateAppFolder();
    // Look for a folder created earlier today (or on this date) so we reuse it.
    final response = await _driveApi!.files.list(
      q: "'$arcBackupsId' in parents and name = '$dateName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      pageSize: 5,
      $fields: 'files(id,name)',
    );
    final files = response.files ?? [];
    if (files.isNotEmpty) {
      final id = files.first.id;
      if (id != null && id.isNotEmpty) {
        _datedSubfolderIdByDateName[dateName] = id;
        return id;
      }
    }
    // None found for this date; create one.
    final folder = drive.File();
    folder.name = dateName;
    folder.mimeType = 'application/vnd.google-apps.folder';
    folder.parents = [arcBackupsId];
    final created = await _driveApi!.files.create(folder);
    final createdId = created.id!;
    _datedSubfolderIdByDateName[dateName] = createdId;
    return createdId;
  }

  static String _formatDateFolderName(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Create a new folder on Drive under [parentFolderId] with [folderName].
  /// Returns the created folder's id and name, or null on failure.
  Future<({String id, String name})?> createFolder({
    required String parentFolderId,
    required String folderName,
  }) async {
    _requireDriveApi();
    final name = folderName.trim();
    if (name.isEmpty) return null;
    try {
      final file = drive.File();
      file.name = name;
      file.mimeType = 'application/vnd.google-apps.folder';
      file.parents = [parentFolderId];
      final created = await _driveApi!.files.create(file);
      final id = created.id;
      final createdName = created.name ?? name;
      if (id == null || id.isEmpty) return null;
      return (id: id, name: createdName);
    } catch (e) {
      debugPrint('GoogleDriveService: createFolder failed: $e');
      return null;
    }
  }

  /// List files in the given folder (or app folder if [folderId] is null).
  /// Use [folderId] of [rootFolderId] to list the top-level "My Drive" contents.
  static const String rootFolderId = 'root';

  Future<List<drive.File>> listFiles({String? folderId, int pageSize = 100}) async {
    _requireDriveApi();
    final parentId = folderId ?? await getOrCreateAppFolder();
    final response = await _driveApi!.files.list(
      q: "'$parentId' in parents and trashed = false",
      pageSize: pageSize,
      orderBy: 'folder asc, modifiedTime desc',
      $fields: 'files(id,name,mimeType,size,modifiedTime,webContentLink,parents)',
    );
    return response.files ?? [];
  }

  /// Get file or folder metadata (e.g. for parent ID when navigating back).
  Future<drive.File?> getFileMetadata(String fileId, {String fields = 'id,name,parents,mimeType'}) async {
    _requireDriveApi();
    try {
      final f = await _driveApi!.files.get(fileId, $fields: fields);
      return f is drive.File ? f : null;
    } catch (_) {
      return null;
    }
  }

  /// Recursively collect all backup and text file IDs under the given folder.
  /// Returns list of Drive files (.arcx, .zip, manifest .json, .txt, .md).
  Future<List<drive.File>> listImportableFilesInFolder(String folderId, {int maxFiles = 500}) async {
    _requireDriveApi();
    final result = <drive.File>[];
    await _listImportableFilesRecursive(folderId, result, maxFiles);
    return result;
  }

  Future<void> _listImportableFilesRecursive(String folderId, List<drive.File> out, int maxFiles) async {
    if (out.length >= maxFiles) return;
    final items = await listFiles(folderId: folderId, pageSize: 100);
    for (final item in items) {
      if (out.length >= maxFiles) return;
      final name = item.name ?? '';
      final mime = item.mimeType ?? '';
      if (mime == 'application/vnd.google-apps.folder') {
        final id = item.id;
        if (id != null) await _listImportableFilesRecursive(id, out, maxFiles);
      } else {
        final isBackup = name.endsWith('.arcx') || name.endsWith('.zip') ||
            (name.startsWith('arc_backup_manifest_') && name.endsWith('.json'));
        final isText = name.endsWith('.txt') || name.endsWith('.md');
        if (isBackup || isText) out.add(item);
      }
    }
  }

  /// One-time import of .txt/.md files from Drive (e.g. from Browse Drive folder picker).
  /// Creates LUMARA entries with #googledrive and folder hashtag. Does not add to sync records.
  Future<int> importTextFilesFromDrive(List<drive.File> files, JournalRepository journalRepo) async {
    _requireDriveApi();
    int count = 0;
    for (final file in files) {
      final fileId = file.id;
      final name = file.name ?? '';
      if (fileId == null || fileId.isEmpty) continue;
      if (!name.endsWith('.txt') && !name.endsWith('.md')) continue;
      try {
        final path = await downloadToTempFile(fileId, suggestedName: file.name);
        final content = await File(path).readAsString();
        try {
          await File(path).delete();
        } catch (_) {}
        final parentId = file.parents != null && file.parents!.isNotEmpty ? file.parents!.first : null;
        final folderName = parentId != null ? (await getFileMetadata(parentId, fields: 'name'))?.name ?? 'Drive' : 'Drive';
        final folderTag = _folderNameToHashtag(folderName);
        final hashtags = ' #googledrive #$folderTag';
        final title = name.replaceAll(RegExp(r'\.(txt|md)$'), '').trim();
        final now = DateTime.now();
        final entry = JournalEntry(
          id: const Uuid().v4(),
          title: title.isEmpty ? 'Imported from Drive' : title,
          content: content.trim() + hashtags,
          createdAt: now,
          updatedAt: now,
          tags: const [],
          mood: '',
          keywords: ['googledrive', folderTag],
          importSource: 'GOOGLE_DRIVE',
        );
        await journalRepo.createJournalEntry(entry);
        count++;
      } catch (e) {
        debugPrint('GoogleDriveService: import text file $fileId failed: $e');
      }
    }
    return count;
  }

  // --- Sync folder (for .txt auto-import) ---

  Future<String?> getSyncFolderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrefSyncFolderId);
  }

  Future<String?> getSyncFolderName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrefSyncFolderName);
  }

  Future<void> setSyncFolder(String? folderId, String? folderName) async {
    final prefs = await SharedPreferences.getInstance();
    if (folderId == null) {
      await prefs.remove(_kPrefSyncFolderId);
      await prefs.remove(_kPrefSyncFolderName);
    } else {
      await prefs.setString(_kPrefSyncFolderId, folderId);
      await prefs.setString(_kPrefSyncFolderName, folderName ?? '');
    }
  }

  /// Records of synced .txt files (driveFileId → journalEntryId + modifiedTime) for create/update.
  /// If [syncFolderId] is provided, only returns records that were synced from that folder.
  Future<List<SyncedTxtRecord>> getSyncedTxtRecords({String? syncFolderId}) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kPrefSyncedTxtRecords);
    if (json != null && json.isNotEmpty) {
      try {
        final list = jsonDecode(json) as List<dynamic>?;
        if (list != null) {
          var records = list.map((e) => SyncedTxtRecord.fromJson(e)).whereType<SyncedTxtRecord>().toList();
          if (syncFolderId != null && syncFolderId.isNotEmpty) {
            records = records.where((r) => r.syncFolderId == syncFolderId).toList();
          }
          if (records.isNotEmpty) return records;
        }
      } catch (_) {}
    }
    // Migration: old format was just list of file IDs; treat those as "synced but no entry id" so we don't re-import.
    final oldJson = prefs.getString(_kPrefSyncedTxtIds);
    if (oldJson != null && oldJson.isNotEmpty) {
      try {
        final list = jsonDecode(oldJson) as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          return list.map((e) => SyncedTxtRecord(driveFileId: e.toString(), journalEntryId: '', modifiedTimeIso: null, syncFolderId: null)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  Future<void> _saveSyncedTxtRecords(List<SyncedTxtRecord> records) async {
    var list = records;
    if (list.length > _kMaxSyncedTxtRecords) {
      list = list.sublist(list.length - _kMaxSyncedTxtRecords);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefSyncedTxtRecords, jsonEncode(list.map((r) => r.toJson()).toList()));
  }

  static String _folderNameToHashtag(String name) {
    final s = name.replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    return s.isEmpty ? 'Drive' : s;
  }

  static DateTime? _parseDriveModifiedTime(dynamic modifiedTime) {
    if (modifiedTime == null) return null;
    if (modifiedTime is DateTime) return modifiedTime;
    if (modifiedTime is String) {
      try {
        return DateTime.parse(modifiedTime);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Sync .txt/.md files from the chosen sync folder: create new entries or update existing if the file was edited on Drive.
  /// Returns the number of entries created or updated. Call on app open or when user taps Sync.
  Future<int> syncTxtFromDriveToTimeline(JournalRepository journalRepo) async {
    final folderId = await getSyncFolderId();
    if (folderId == null || folderId.isEmpty) return 0;
    final restored = await restoreSession();
    if (!restored) return 0;

    final records = await getSyncedTxtRecords();
    final byDriveId = <String, SyncedTxtRecord>{};
    for (final r in records) {
      byDriveId[r.driveFileId] = r;
    }

    final pairs = await listTxtFilesInFolderWithParent(folderId, maxFiles: 200);
    int createdOrUpdated = 0;
    final updatedRecords = <String, SyncedTxtRecord>{...byDriveId};

    for (final pair in pairs) {
      final fileId = pair.file.id;
      if (fileId == null || fileId.isEmpty) continue;

      final driveModified = _parseDriveModifiedTime(pair.file.modifiedTime);
      final record = byDriveId[fileId];

      // Already synced: update entry if Drive file is newer.
      if (record != null) {
        if (record.journalEntryId.isEmpty) continue; // Legacy: no entry id, skip to avoid duplicate.
        final lastModified = record.modifiedTimeIso != null ? DateTime.tryParse(record.modifiedTimeIso!) : null;
        final driveIsNewer = driveModified != null &&
            (lastModified == null || driveModified.isAfter(lastModified));
        if (!driveIsNewer) continue;

        try {
          final existing = await journalRepo.getJournalEntryById(record.journalEntryId);
          if (existing == null) {
            // Entry was deleted in ARC; remove record and fall through to create new.
            updatedRecords.remove(fileId);
          } else {
            final path = await downloadToTempFile(fileId, suggestedName: pair.file.name);
            final content = await File(path).readAsString();
            try {
              await File(path).delete();
            } catch (_) {}
            final parentMeta = await getFileMetadata(pair.parentFolderId, fields: 'name');
            final folderName = parentMeta?.name ?? 'Drive';
            final folderTag = _folderNameToHashtag(folderName);
            final hashtags = ' #googledrive #$folderTag';
final title = (pair.file.name ?? 'Note').replaceAll(RegExp(r'\.(txt|md)$'), '').trim();
        final updated = existing.copyWith(
              content: content.trim() + hashtags,
              title: title.isEmpty ? 'Imported from Drive' : title,
              updatedAt: DateTime.now(),
              keywords: ['googledrive', folderTag],
            );
            await journalRepo.updateJournalEntry(updated);
            updatedRecords[fileId] = SyncedTxtRecord(
              driveFileId: fileId,
              journalEntryId: record.journalEntryId,
              modifiedTimeIso: driveModified.toIso8601String(),
              syncFolderId: folderId,
            );
            createdOrUpdated++;
            continue;
          }
        } catch (e) {
          debugPrint('GoogleDriveService: update .txt $fileId failed: $e');
          continue;
        }
      }

      // New file: create entry and add record.
      try {
        final path = await downloadToTempFile(fileId, suggestedName: pair.file.name);
        final content = await File(path).readAsString();
        try {
          await File(path).delete();
        } catch (_) {}
        final parentMeta = await getFileMetadata(pair.parentFolderId, fields: 'name');
        final folderName = parentMeta?.name ?? 'Drive';
        final folderTag = _folderNameToHashtag(folderName);
        final hashtags = ' #googledrive #$folderTag';
        final now = DateTime.now();
        final title = (pair.file.name ?? 'Note').replaceAll(RegExp(r'\.(txt|md)$'), '').trim();
        final entry = JournalEntry(
          id: const Uuid().v4(),
          title: title.isEmpty ? 'Imported from Drive' : title,
          content: content.trim() + hashtags,
          createdAt: now,
          updatedAt: now,
          tags: const [],
          mood: '',
          keywords: ['googledrive', folderTag],
          importSource: 'GOOGLE_DRIVE',
        );
        await journalRepo.createJournalEntry(entry);
        updatedRecords[fileId] = SyncedTxtRecord(
          driveFileId: fileId,
          journalEntryId: entry.id,
          modifiedTimeIso: driveModified?.toIso8601String(),
          syncFolderId: folderId,
        );
        createdOrUpdated++;
      } catch (e) {
        debugPrint('GoogleDriveService: sync .txt $fileId failed: $e');
      }
    }

    await _saveSyncedTxtRecords(updatedRecords.values.toList());
    return createdOrUpdated;
  }

  /// List .txt/.md files under [folderId] with each file's direct parent folder id (for folder-name hashtag).
  Future<List<({drive.File file, String parentFolderId})>> listTxtFilesInFolderWithParent(String folderId, {int maxFiles = 200}) async {
    _requireDriveApi();
    final result = <({drive.File file, String parentFolderId})>[];
    await _listTxtWithParentRecursive(folderId, folderId, result, maxFiles);
    return result;
  }

  Future<void> _listTxtWithParentRecursive(String folderId, String parentId, List<({drive.File file, String parentFolderId})> out, int maxFiles) async {
    if (out.length >= maxFiles) return;
    final items = await listFiles(folderId: folderId, pageSize: 100);
    for (final item in items) {
      if (out.length >= maxFiles) return;
      final name = item.name ?? '';
      final mime = item.mimeType ?? '';
      if (mime == 'application/vnd.google-apps.folder') {
        final id = item.id;
        if (id != null) await _listTxtWithParentRecursive(id, id, out, maxFiles);
      } else if (name.endsWith('.txt') || name.endsWith('.md')) {
        final parents = item.parents;
        final pid = (parents != null && parents.isNotEmpty) ? parents.first : parentId;
        out.add((file: item, parentFolderId: pid));
      }
    }
  }

  /// List all backup files (manifests, .arcx, .zip) from LUMARA Backups: from dated subfolders and any at root.
  /// Used by Import from Drive so backups in dated folders (e.g. 2026-02-02) are shown.
  Future<List<drive.File>> listAllBackupFiles({int pageSize = 200}) async {
    _requireDriveApi();
    final arcBackupsId = await getOrCreateAppFolder();
    final allFiles = <drive.File>[];
    final children = await listFiles(folderId: arcBackupsId, pageSize: 100);
    for (final item in children) {
      final mime = item.mimeType;
      final name = item.name ?? '';
      if (mime == 'application/vnd.google-apps.folder') {
        // Dated subfolder: list its contents.
        final id = item.id;
        if (id != null) {
          final subFiles = await listFiles(folderId: id, pageSize: 100);
          for (final f in subFiles) {
            final n = f.name ?? '';
            if (n.endsWith('.arcx') || n.endsWith('.zip') ||
                (n.startsWith('arc_backup_manifest_') && n.endsWith('.json'))) {
              allFiles.add(f);
            }
          }
        }
      } else {
        // File at root (e.g. old uploads before dated subfolders).
        if (name.endsWith('.arcx') || name.endsWith('.zip') ||
            (name.startsWith('arc_backup_manifest_') && name.endsWith('.json'))) {
          allFiles.add(item);
        }
      }
    }
    // Sort by modifiedTime desc so newest first.
    allFiles.sort((a, b) {
      final aTime = a.modifiedTime;
      final bTime = b.modifiedTime;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return allFiles;
  }

  /// Upload a local file to Drive in the given folder (or app folder if null).
  /// Returns the created Drive file ID.
  Future<String> uploadFile({
    required File localFile,
    String? folderId,
    String? nameOverride,
  }) async {
    _requireDriveApi();
    final parentId = folderId ?? await getOrCreateAppFolder();
    final name = nameOverride ?? localFile.path.split(RegExp(r'[/\\]')).last;
    final file = drive.File();
    file.name = name;
    file.parents = [parentId];
    final length = await localFile.length();
    final media = drive.Media(localFile.openRead(), length);
    final created = await _driveApi!.files.create(
      file,
      uploadMedia: media,
    );
    return created.id!;
  }

  /// Update an existing Drive file's content (and optionally name). Used to push timeline entry back to Drive.
  /// Returns the updated file's modifiedTime as ISO string, or null.
  Future<String?> updateFileContent(String fileId, String content, {String? fileName}) async {
    _requireDriveApi();
    final dir = Directory.systemTemp;
    final name = fileName ?? 'note.txt';
    final ext = name.contains('.') ? '' : '.txt';
    final localPath = '${dir.path}/gdrive_update_${DateTime.now().millisecondsSinceEpoch}_${path.basename(name)}$ext';
    final file = File(localPath);
    try {
      await file.writeAsString(content, encoding: utf8);
      final len = await file.length();
      final driveFile = drive.File();
      if (fileName != null && fileName.isNotEmpty) driveFile.name = fileName;
      final media = drive.Media(file.openRead(), len);
      final updated = await _driveApi!.files.update(
        driveFile,
        fileId,
        uploadMedia: media,
      );
      final mod = updated.modifiedTime;
      if (mod != null) return mod.toIso8601String();
      return null;
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  /// Push a journal entry's content back to the linked Drive file. Strips trailing #googledrive #X hashtags for clean .txt.
  /// Updates the synced record's modifiedTimeIso. Returns true on success.
  Future<bool> pushEntryContentToDrive({
    required JournalEntry entry,
    required String driveFileId,
    required JournalRepository journalRepo,
  }) async {
    final content = entry.content.trim();
    // Strip trailing sync hashtags so the .txt on Drive stays clean
    final withoutHashtags = content
        .replaceAll(RegExp(r'\s*#googledrive\s*'), ' ')
        .replaceAll(RegExp(r'\s*#[a-zA-Z0-9_]+\s*$'), '')
        .trim();
    final body = withoutHashtags.isEmpty ? content : withoutHashtags;
    final fileName = '${entry.title.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_').trim()}.txt';
    try {
      await updateFileContent(driveFileId, body, fileName: fileName);
      final records = await getSyncedTxtRecords();
      final byDriveId = <String, SyncedTxtRecord>{};
      for (final r in records) {
        byDriveId[r.driveFileId] = r;
      }
      final existing = byDriveId[driveFileId];
      if (existing != null) {
        byDriveId[driveFileId] = SyncedTxtRecord(
          driveFileId: driveFileId,
          journalEntryId: existing.journalEntryId,
          modifiedTimeIso: DateTime.now().toIso8601String(),
          syncFolderId: existing.syncFolderId,
        );
        await _saveSyncedTxtRecords(byDriveId.values.toList());
      }
      return true;
    } catch (e) {
      debugPrint('GoogleDriveService: pushEntryContentToDrive failed: $e');
      return false;
    }
  }

  /// Download a Drive file to a local path.
  Future<void> downloadFile(String fileId, String localPath) async {
    _requireDriveApi();
    final media = await _driveApi!.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );
    if (media is! drive.Media) {
      throw StateError('Expected Media response for file download');
    }
    final file = File(localPath);
    final sink = file.openWrite();
    await for (final chunk in media.stream) {
      sink.add(chunk);
    }
    await sink.close();
  }

  /// Upload arcx files in size order (smallest first), then upload a manifest.
  /// Files are placed in a dated subfolder (yyyy-MM-dd) inside "LUMARA Backups".
  /// [arcxPaths] = paths to .arcx files; [manifestTimestamp] = ISO timestamp for manifest name.
  /// [onProgress] is called with (current, total, phase) after each upload.
  Future<void> uploadChunkedBackup({
    required List<String> arcxPaths,
    required String manifestTimestamp,
    void Function(int current, int total, String phase)? onProgress,
  }) async {
    _requireDriveApi();
    if (arcxPaths.isEmpty) return;

    // Use today's dated subfolder inside LUMARA Backups (e.g. 2026-02-02).
    final datedFolderId = await getOrCreateDatedSubfolder(DateTime.now());

    // Sort by file size ascending so smaller arcx files upload first.
    final pathsWithSize = <MapEntry<String, int>>[];
    for (final p in arcxPaths) {
      final f = File(p);
      if (await f.exists()) {
        pathsWithSize.add(MapEntry(p, await f.length()));
      }
    }
    pathsWithSize.sort((a, b) => a.value.compareTo(b.value));
    final sortedPaths = pathsWithSize.map((e) => e.key).toList();

    final basenameToFileId = <String, String>{};
    final total = sortedPaths.length;
    int current = 0;

    for (final p in sortedPaths) {
      onProgress?.call(current, total, 'Uploading arcx ${current + 1}/$total');
      final file = File(p);
      final name = path.basename(p);
      final fileId = await uploadFile(localFile: file, folderId: datedFolderId, nameOverride: name);
      basenameToFileId[name] = fileId;
      current++;
      await Future.delayed(Duration.zero);
    }

    // Restore order: sort by basename (LUMARA_Full_001.arcx, LUMARA_Full_002.arcx, ...).
    final basenames = basenameToFileId.keys.toList()..sort();
    final chunkFileIds = basenames.map((name) => basenameToFileId[name]!).toList();

    final manifest = <String, dynamic>{
      'version': 1,
      'timestamp': manifestTimestamp,
      'chunkCount': chunkFileIds.length,
      'chunkFileIds': chunkFileIds,
    };
    final manifestJson = jsonEncode(manifest);
    final manifestName = 'arc_backup_manifest_${manifestTimestamp.replaceAll(RegExp(r'[:\-.]'), '_')}.json';
    final tempDir = Directory.systemTemp;
    final manifestPath = '${tempDir.path}/$manifestName';
    try {
      await File(manifestPath).writeAsString(manifestJson);
      onProgress?.call(total, total, 'Uploading manifest');
      await uploadFile(
        localFile: File(manifestPath),
        folderId: datedFolderId,
        nameOverride: manifestName,
      );
    } finally {
      try {
        await File(manifestPath).delete();
      } catch (_) {}
    }
  }

  /// Download a chunked backup: manifest + arcx files into a temp folder.
  /// Returns the path to that folder (caller zips it and calls import).
  Future<String> downloadChunkedBackup(String manifestFileId) async {
    _requireDriveApi();
    final manifestPath = await downloadToTempFile(manifestFileId, suggestedName: 'arc_backup_manifest.json');
    final manifestJson = jsonDecode(await File(manifestPath).readAsString()) as Map<String, dynamic>;
    final chunkFileIds = (manifestJson['chunkFileIds'] as List<dynamic>).cast<String>();
    try {
      await File(manifestPath).delete();
    } catch (_) {}

    final dir = Directory.systemTemp;
    final backupDir = Directory('${dir.path}/arc_restore_${DateTime.now().millisecondsSinceEpoch}');
    await backupDir.create(recursive: true);

    for (var i = 0; i < chunkFileIds.length; i++) {
      final numStr = (i + 1).toString().padLeft(3, '0');
      final name = 'LUMARA_Full_$numStr.arcx';
      final localPath = path.join(backupDir.path, name);
      await downloadFile(chunkFileIds[i], localPath);
    }
    return backupDir.path;
  }

  /// Get download URL or stream for a file (for small files we can use get with alt=media).
  /// For larger files, download to temp file and return path.
  Future<String> downloadToTempFile(String fileId, {String? suggestedName}) async {
    _requireDriveApi();
    final meta = await _driveApi!.files.get(fileId, $fields: 'name');
    final fileMeta = meta is drive.File ? meta : null;
    String name = suggestedName ?? fileMeta?.name ?? 'drive_file';
    name = name.replaceAll(RegExp(r'[/\\]'), '_');
    final dir = Directory.systemTemp;
    final localPath = '${dir.path}/gdrive_${DateTime.now().millisecondsSinceEpoch}_$name';
    await downloadFile(fileId, localPath);
    return localPath;
  }

  drive.DriveApi _requireDriveApi() {
    if (_driveApi == null) {
      throw StateError('Google Drive not connected. Sign in first.');
    }
    return _driveApi!;
  }
}

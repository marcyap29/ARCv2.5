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

const String _kPrefSelectedFolderId = 'google_drive_backup_folder_id';
const String _kDriveAppFolderName = 'ARC Backups';

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  static GoogleDriveService get instance => _instance;

  GoogleSignIn? _googleSignIn;
  drive.DriveApi? _driveApi;
  String? _currentAccountEmail;
  bool _initialized = false;

  /// Drive API scope: only files the app creates or opens.
  static const String driveFileScope = 'https://www.googleapis.com/auth/drive.file';

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

  /// Sign in with Google and request Drive (drive.file) scope.
  /// Returns the signed-in account email or null if user cancelled.
  Future<String?> signIn() async {
    await _ensureInitialized();
    try {
      final account = await _googleSignIn!.authenticate(
        scopeHint: [driveFileScope],
      );
      final auth = await account.authorizationClient.authorizeScopes([driveFileScope]);
      final client = auth.authClient(scopes: [driveFileScope]);
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
      final auth = await account.authorizationClient.authorizeScopes([driveFileScope]);
      final client = auth.authClient(scopes: [driveFileScope]);
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

  /// Create or get the app backup folder. Returns folder ID.
  Future<String> getOrCreateAppFolder() async {
    _requireDriveApi();
    final existingId = await getSelectedFolderId();
    if (existingId != null && existingId.isNotEmpty) {
      try {
        await _driveApi!.files.get(existingId);
        return existingId;
      } catch (_) {
        // Folder may have been deleted; fall through to create.
      }
    }
    final file = drive.File();
    file.name = _kDriveAppFolderName;
    file.mimeType = 'application/vnd.google-apps.folder';
    final created = await _driveApi!.files.create(file);
    await setSelectedFolderId(created.id);
    return created.id!;
  }

  /// List files in the given folder (or app folder if [folderId] is null).
  Future<List<drive.File>> listFiles({String? folderId, int pageSize = 50}) async {
    _requireDriveApi();
    final parentId = folderId ?? await getOrCreateAppFolder();
    final response = await _driveApi!.files.list(
      q: "'$parentId' in parents and trashed = false",
      pageSize: pageSize,
      orderBy: 'modifiedTime desc',
      $fields: 'files(id,name,mimeType,size,modifiedTime,webContentLink)',
    );
    return response.files ?? [];
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
  /// [arcxPaths] = paths to .arcx files; [manifestTimestamp] = ISO timestamp for manifest name.
  /// [onProgress] is called with (current, total, phase) after each upload.
  Future<void> uploadChunkedBackup({
    required List<String> arcxPaths,
    required String manifestTimestamp,
    void Function(int current, int total, String phase)? onProgress,
  }) async {
    _requireDriveApi();
    if (arcxPaths.isEmpty) return;

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
      final fileId = await uploadFile(localFile: file, nameOverride: name);
      basenameToFileId[name] = fileId;
      current++;
      await Future.delayed(Duration.zero);
    }

    // Restore order: sort by basename (ARC_Full_001.arcx, ARC_Full_002.arcx, ...).
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
      final name = 'ARC_Full_$numStr.arcx';
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

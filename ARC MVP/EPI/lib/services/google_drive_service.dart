// lib/services/google_drive_service.dart
// Google Drive API integration for backup uploads

import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Google Drive service for backup file uploads
class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  static GoogleDriveService get instance => _instance;

  GoogleSignIn? _googleSignIn;
  drive.DriveApi? _driveApi;
  String? _selectedFolderId;
  String? _connectedAccountEmail;
  GoogleSignInAccount? _currentAccount;

  /// Initialize Google Drive service
  Future<void> initialize() async {
    _googleSignIn = GoogleSignIn.instance;
    
    // Initialize with configuration (required in 7.x)
    // Note: For iOS, scopes need to be configured in GoogleService-Info.plist
    // For web, clientId can be passed here
    await _googleSignIn!.initialize();
    print('Google Drive Service: Initialized');
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _currentAccount != null && _driveApi != null;

  /// Get connected account email
  String? get connectedAccountEmail => _connectedAccountEmail;

  /// Get selected folder ID
  String? get selectedFolderId => _selectedFolderId;

  /// Authenticate user with Google
  Future<bool> authenticate() async {
    try {
      if (_googleSignIn == null) {
        await initialize();
      }

      print('Google Drive Service: Starting authentication...');
      
      // Trigger the authentication flow (7.x API uses authenticate() with scopeHint)
      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn!.authenticate(
          scopeHint: ['https://www.googleapis.com/auth/drive.file'],
        );
      } catch (e) {
        print('Google Drive Service: Google Sign-In trigger failed: $e');
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('canceled') || errorString.contains('cancelled')) {
          return false; // User cancelled, not an error
        }
        rethrow;
      }

      // In 7.x, authenticate() throws on cancellation, doesn't return null
      // If we get here, authentication succeeded

      print('Google Drive Service: Authenticated as ${account.email}');
      _connectedAccountEmail = account.email;
      _currentAccount = account;

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await account.authentication;
      
      if (googleAuth.idToken == null) {
        print('Google Drive Service: No ID token received');
        return false;
      }

      // Get access token via authorization client (7.x API)
      String? accessToken;
      try {
        // Try to get authorization for the Drive scope
        final authorization = await account.authorizationClient.authorizationForScopes(
          ['https://www.googleapis.com/auth/drive.file'],
        );
        if (authorization != null) {
          accessToken = authorization.accessToken;
          print('Google Drive Service: Got access token from authorizationForScopes');
        } else {
          print('Google Drive Service: authorizationForScopes returned null, trying authorizeScopes...');
        }
      } catch (e) {
        print('Google Drive Service: Could not get access token from authorizationForScopes: $e');
      }
      
      // If authorizationForScopes returned null, try authorizeScopes (requires user interaction)
      if (accessToken == null) {
        try {
          print('Google Drive Service: Requesting additional scopes via authorizeScopes...');
          final authorization = await account.authorizationClient.authorizeScopes(
            ['https://www.googleapis.com/auth/drive.file'],
          );
          accessToken = authorization.accessToken;
          print('Google Drive Service: Got access token from authorizeScopes');
        } catch (e2) {
          print('Google Drive Service: Could not get access token via authorizeScopes: $e2');
          // Re-throw if it's not a cancellation
          final errorString = e2.toString().toLowerCase();
          if (!errorString.contains('canceled') && !errorString.contains('cancelled')) {
            rethrow;
          }
        }
      }

      if (accessToken == null) {
        print('Google Drive Service: Failed to get access token after all attempts');
        throw Exception('Unable to obtain Google Drive access token. Please ensure Google Sign-In is properly configured.');
      }

      // Create authenticated HTTP client
      final authClient = AuthenticatedClient(
        http.Client(),
        auth.AccessCredentials(
          auth.AccessToken('Bearer', accessToken, DateTime.now().toUtc().add(const Duration(hours: 1))),
          googleAuth.idToken,
          ['https://www.googleapis.com/auth/drive.file'],
        ),
      );

      // Initialize Drive API
      _driveApi = drive.DriveApi(authClient);
      print('Google Drive Service: Drive API initialized');

      return true;
    } catch (e) {
      print('Google Drive Service: Authentication error: $e');
      return false;
    }
  }

  /// Disconnect Google account
  Future<void> disconnect() async {
    try {
      await _googleSignIn?.signOut();
      _driveApi = null;
      _selectedFolderId = null;
      _connectedAccountEmail = null;
      _currentAccount = null;
      print('Google Drive Service: Disconnected');
    } catch (e) {
      print('Google Drive Service: Disconnect error: $e');
    }
  }

  /// List folders in user's Drive
  Future<List<drive.File>> listFolders() async {
    if (_driveApi == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    try {
      final response = await _driveApi!.files.list(
        q: "mimeType='application/vnd.google-apps.folder' and trashed=false",
        $fields: 'files(id, name, parents)',
        pageSize: 100,
      );

      return response.files ?? [];
    } catch (e) {
      print('Google Drive Service: Error listing folders: $e');
      rethrow;
    }
  }

  /// Select a folder by ID
  Future<bool> selectFolder(String folderId) async {
    if (_driveApi == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    try {
      // Verify folder exists and is accessible
      final folder = await _driveApi!.files.get(folderId) as drive.File;

      if (folder.mimeType != 'application/vnd.google-apps.folder') {
        throw Exception('Selected item is not a folder');
      }

      _selectedFolderId = folderId;
      print('Google Drive Service: Selected folder: ${folder.name} (ID: $folderId)');
      return true;
    } catch (e) {
      print('Google Drive Service: Error selecting folder: $e');
      return false;
    }
  }

  /// Upload a file to Google Drive
  /// 
  /// [file] - The file to upload
  /// [folderId] - Optional folder ID (uses selected folder if not provided)
  /// [onProgress] - Optional progress callback (bytes uploaded, total bytes)
  Future<drive.File> uploadFile(
    File file, {
    String? folderId,
    void Function(int uploaded, int total)? onProgress,
  }) async {
    if (_driveApi == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    final targetFolderId = folderId ?? _selectedFolderId;
    if (targetFolderId == null) {
      throw Exception('No folder selected. Call selectFolder() first.');
    }

    try {
      final fileName = path.basename(file.path);
      final fileSize = await file.length();
      
      print('Google Drive Service: Uploading $fileName (${fileSize} bytes) to folder $targetFolderId');

      // Create file metadata
      final drive.File driveFile = drive.File();
      driveFile.name = fileName;
      driveFile.parents = [targetFolderId];

      // Upload file
      final media = drive.Media(file.openRead(), fileSize, contentType: 'application/octet-stream');
      
      final uploadedFile = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
      );

      print('Google Drive Service: Upload complete. File ID: ${uploadedFile.id}');
      return uploadedFile;
    } catch (e) {
      print('Google Drive Service: Upload error: $e');
      rethrow;
    }
  }

  /// Refresh authentication token
  Future<bool> refreshToken() async {
    try {
      if (_googleSignIn == null || _currentAccount == null) {
        return false;
      }

      // Get fresh authorization
      String? accessToken;
      try {
        final authorization = await _currentAccount!.authorizationClient.authorizationForScopes(
          ['https://www.googleapis.com/auth/drive.file'],
        );
        if (authorization != null) {
          accessToken = authorization.accessToken;
        }
      } catch (e) {
        print('Google Drive Service: Could not refresh access token: $e');
      }

      if (accessToken == null) {
        // Try to re-authenticate
        return await authenticate();
      }

      final googleAuth = await _currentAccount!.authentication;
      if (googleAuth.idToken == null) {
        return false;
      }

      // Recreate Drive API client with new token
      final authClient = AuthenticatedClient(
        http.Client(),
        auth.AccessCredentials(
          auth.AccessToken('Bearer', accessToken, DateTime.now().toUtc().add(const Duration(hours: 1))),
          googleAuth.idToken,
          ['https://www.googleapis.com/auth/drive.file'],
        ),
      );

      _driveApi = drive.DriveApi(authClient);
      print('Google Drive Service: Token refreshed');
      return true;
    } catch (e) {
      print('Google Drive Service: Token refresh error: $e');
      return false;
    }
  }

  /// Get folder name by ID
  Future<String?> getFolderName(String folderId) async {
    if (_driveApi == null) {
      return null;
    }

    try {
      final folder = await _driveApi!.files.get(folderId) as drive.File;
      return folder.name;
    } catch (e) {
      print('Google Drive Service: Error getting folder name: $e');
      return null;
    }
  }
}

/// Authenticated HTTP client wrapper for Google APIs
class AuthenticatedClient extends http.BaseClient {
  final http.Client _client;
  final auth.AccessCredentials _credentials;

  AuthenticatedClient(this._client, this._credentials);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = '${_credentials.accessToken.type} ${_credentials.accessToken.data}';
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}


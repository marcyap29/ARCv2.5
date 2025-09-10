import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import '../pointer/pointer_models.dart';

// Storage policy definitions
enum StoragePolicy {
  localOnly,
  encryptedLocal,
  cloudSync,
  temporary,
  permanent,
  minimal,
  balanced,
  comprehensive,
  hiFidelity
}

/// Abstract interface for resolving media pointers to actual content
abstract class PointerResolver {
  Future<Uint8List?> loadBytes(
    String sourceUri, {
    int? maxBytes,
    String? platform,
  });
  
  Future<void> openInHostApp(
    String sourceUri, {
    String? platform,
  });
  
  Future<bool> isSourceAvailable(
    String sourceUri, {
    String? platform,
  });
}

/// Cross-platform pointer resolver with iOS and Android support
class CrossPlatformPointerResolver implements PointerResolver {
  static const MethodChannel _channel = MethodChannel('pointer_resolver');

  @override
  Future<Uint8List?> loadBytes(
    String sourceUri, {
    int? maxBytes,
    String? platform,
  }) async {
    try {
      final detectedPlatform = platform ?? _detectPlatform(sourceUri);
      
      switch (detectedPlatform) {
        case 'ios':
          return await _loadBytesIOS(sourceUri, maxBytes);
        case 'android':
          return await _loadBytesAndroid(sourceUri, maxBytes);
        default:
          throw UnsupportedError('Unsupported platform: $detectedPlatform');
      }
    } catch (e) {
      print('PointerResolver: Failed to load bytes from $sourceUri: $e');
      return null;
    }
  }

  @override
  Future<void> openInHostApp(
    String sourceUri, {
    String? platform,
  }) async {
    try {
      final detectedPlatform = platform ?? _detectPlatform(sourceUri);
      
      switch (detectedPlatform) {
        case 'ios':
          await _openInHostAppIOS(sourceUri);
          break;
        case 'android':
          await _openInHostAppAndroid(sourceUri);
          break;
        default:
          throw UnsupportedError('Unsupported platform: $detectedPlatform');
      }
    } catch (e) {
      print('PointerResolver: Failed to open in host app $sourceUri: $e');
      // Fallback to generic URI opening
      final uri = Uri.tryParse(sourceUri);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  @override
  Future<bool> isSourceAvailable(
    String sourceUri, {
    String? platform,
  }) async {
    try {
      final detectedPlatform = platform ?? _detectPlatform(sourceUri);
      
      switch (detectedPlatform) {
        case 'ios':
          return await _isSourceAvailableIOS(sourceUri);
        case 'android':
          return await _isSourceAvailableAndroid(sourceUri);
        default:
          return false;
      }
    } catch (e) {
      print('PointerResolver: Error checking availability for $sourceUri: $e');
      return false;
    }
  }

  /// Detect platform from URI scheme
  String _detectPlatform(String sourceUri) {
    if (sourceUri.startsWith('ph://') || sourceUri.startsWith('applephotos://')) {
      return 'ios';
    } else if (sourceUri.startsWith('content://') || sourceUri.startsWith('androidmedia://')) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    } else if (Platform.isAndroid) {
      return 'android';
    }
    return 'unknown';
  }

  /// Load bytes from iOS Photos using PHImageManager
  Future<Uint8List?> _loadBytesIOS(String sourceUri, int? maxBytes) async {
    try {
      final localIdentifier = _extractIOSLocalIdentifier(sourceUri);
      if (localIdentifier == null) return null;

      // Use PhotoManager to get the asset
      final asset = await AssetEntity.fromId(localIdentifier);
      if (asset == null) return null;

      // Get the file bytes
      final file = await asset.file;
      if (file == null) return null;

      final bytes = await file.readAsBytes();
      
      if (maxBytes != null && bytes.length > maxBytes) {
        return Uint8List.fromList(bytes.take(maxBytes).toList());
      }
      
      return bytes;
    } catch (e) {
      print('PointerResolver: iOS bytes loading failed: $e');
      return null;
    }
  }

  /// Load bytes from Android MediaStore using ContentResolver
  Future<Uint8List?> _loadBytesAndroid(String sourceUri, int? maxBytes) async {
    try {
      // Use method channel to access Android ContentResolver
      final bytes = await _channel.invokeMethod<Uint8List>(
        'loadBytesFromUri',
        {
          'uri': sourceUri,
          'maxBytes': maxBytes,
        },
      );
      
      return bytes;
    } catch (e) {
      print('PointerResolver: Android bytes loading failed: $e');
      return null;
    }
  }

  /// Open iOS Photos app to specific asset
  Future<void> _openInHostAppIOS(String sourceUri) async {
    final localIdentifier = _extractIOSLocalIdentifier(sourceUri);
    if (localIdentifier == null) throw Exception('Invalid iOS URI');

    // Try to open Photos app with specific asset
    final photosUrl = 'photos-redirect://asset?identifier=$localIdentifier';
    final uri = Uri.parse(photosUrl);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to general Photos app
      final fallbackUri = Uri.parse('photos-redirect://');
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri);
      }
    }
  }

  /// Open Android gallery/files app to specific content
  Future<void> _openInHostAppAndroid(String sourceUri) async {
    try {
      await _channel.invokeMethod('openInHostApp', {'uri': sourceUri});
    } catch (e) {
      // Fallback to ACTION_VIEW
      final uri = Uri.parse(sourceUri);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  /// Check if iOS source is available
  Future<bool> _isSourceAvailableIOS(String sourceUri) async {
    final localIdentifier = _extractIOSLocalIdentifier(sourceUri);
    if (localIdentifier == null) return false;

    try {
      final asset = await AssetEntity.fromId(localIdentifier);
      return asset != null;
    } catch (e) {
      return false;
    }
  }

  /// Check if Android source is available
  Future<bool> _isSourceAvailableAndroid(String sourceUri) async {
    try {
      final isAvailable = await _channel.invokeMethod<bool>(
        'isSourceAvailable',
        {'uri': sourceUri},
      );
      return isAvailable ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Extract local identifier from iOS URI schemes
  String? _extractIOSLocalIdentifier(String sourceUri) {
    // Handle ph://<localIdentifier> format
    if (sourceUri.startsWith('ph://')) {
      return sourceUri.substring(5);
    }
    
    // Handle applephotos://asset/<localIdentifier> format
    if (sourceUri.startsWith('applephotos://asset/')) {
      return sourceUri.substring(20);
    }
    
    return null;
  }
}

/// Enhanced pointer models with platform information
extension PointerPlatformExtensions on ImageDescriptor {
  /// Get platform from descriptor
  String? get platform => null; // Would be added to the model
}

/// URI scheme generators for different platforms
class PointerUriGenerator {
  /// Generate iOS Photos URI using PHAsset localIdentifier
  static String generateIOSPhotosUri(String localIdentifier) {
    return 'ph://$localIdentifier';
  }

  /// Generate Android MediaStore URI
  static String generateAndroidMediaUri(String contentUri) {
    return contentUri; // Keep original content:// URI
  }

  /// Generate Voice Memos URI (iOS only)
  static String generateVoiceMemosUri(String localIdentifier) {
    return 'voicememos://$localIdentifier';
  }

  /// Generate file URI for general files
  static String generateFileUri(String filePath) {
    return 'file://$filePath';
  }
}

/// Missing source handler
class MissingSourceHandler {
  final PointerResolver _resolver;

  const MissingSourceHandler(this._resolver);

  /// Check if source is missing and provide resolution options
  Future<SourceStatus> checkSourceStatus(String sourceUri, {String? platform}) async {
    final isAvailable = await _resolver.isSourceAvailable(sourceUri, platform: platform);
    
    if (isAvailable) {
      return SourceStatus.available;
    } else {
      return SourceStatus.missing;
    }
  }

  /// Resolve missing source with user action
  Future<String?> resolveMissingSource({
    required String originalUri,
    required SourceResolutionAction action,
    String? replacementUri,
  }) async {
    switch (action) {
      case SourceResolutionAction.selectReplacement:
        return replacementUri;
      case SourceResolutionAction.removeLink:
        return null;
      case SourceResolutionAction.keepBroken:
        return originalUri;
    }
  }
}

enum SourceStatus {
  available,
  missing,
  unauthorized,
}

enum SourceResolutionAction {
  selectReplacement,
  removeLink,
  keepBroken,
}

/// Consent tracking for import decisions
class ConsentTrail {
  final StoragePolicy profile;
  final StoragePolicy? perImportOverride;
  final DateTime timestamp;
  final String userId;
  final String deviceId;

  const ConsentTrail({
    required this.profile,
    this.perImportOverride,
    required this.timestamp,
    required this.userId,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() => {
    'profile': profile.toString().split('.').last,
    'per_import_override': perImportOverride?.toString().split('.').last,
    'timestamp': timestamp.toIso8601String(),
    'user_id': userId,
    'device_id': deviceId,
  };

  factory ConsentTrail.fromJson(Map<String, dynamic> json) {
    return ConsentTrail(
      profile: _parseStoragePolicy(json['profile']),
      perImportOverride: json['per_import_override'] != null 
          ? _parseStoragePolicy(json['per_import_override'])
          : null,
      timestamp: DateTime.parse(json['timestamp']),
      userId: json['user_id'],
      deviceId: json['device_id'],
    );
  }

  static StoragePolicy _parseStoragePolicy(String policy) {
    switch (policy) {
      case 'minimal':
        return StoragePolicy.minimal;
      case 'balanced':
        return StoragePolicy.balanced;
      case 'hiFidelity':
        return StoragePolicy.hiFidelity;
      default:
        return StoragePolicy.minimal;
    }
  }
}
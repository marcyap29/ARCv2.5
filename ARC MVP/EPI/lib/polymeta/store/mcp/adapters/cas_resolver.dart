import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Exception thrown during CAS resolution
class CasResolutionException implements Exception {
  final String message;
  final String? casUri;
  final dynamic cause;

  const CasResolutionException(this.message, {this.casUri, this.cause});

  @override
  String toString() {
    final uriInfo = casUri != null ? ' for $casUri' : '';
    final causeInfo = cause != null ? ' (caused by: $cause)' : '';
    return 'CasResolutionException: $message$uriInfo$causeInfo';
  }
}

/// Result of CAS content resolution
class CasResolutionResult {
  final bool success;
  final Uint8List? content;
  final String? contentType;
  final int? contentLength;
  final String? actualHash;
  final bool hashVerified;
  final String? errorMessage;
  final Duration resolutionTime;

  const CasResolutionResult({
    required this.success,
    this.content,
    this.contentType,
    this.contentLength,
    this.actualHash,
    required this.hashVerified,
    this.errorMessage,
    required this.resolutionTime,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'content_type': contentType,
    'content_length': contentLength,
    'actual_hash': actualHash,
    'hash_verified': hashVerified,
    'error_message': errorMessage,
    'resolution_time_ms': resolutionTime.inMilliseconds,
  };
}

/// Configuration for CAS resolver
class CasResolverConfig {
  final Duration timeout;
  final int maxRetries;
  final Duration retryDelay;
  final int maxContentSize;
  final bool enableCaching;
  final String? cacheDirectory;
  final List<String> trustedRemotes;
  final Map<String, String> customHeaders;

  const CasResolverConfig({
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.maxContentSize = 100 * 1024 * 1024, // 100MB
    this.enableCaching = true,
    this.cacheDirectory,
    this.trustedRemotes = const [],
    this.customHeaders = const {},
  });
}

/// Content-Addressable Storage (CAS) resolver
/// 
/// Resolves CAS URIs (hash-based) to actual content with verification.
/// Supports local file system, HTTP(S) remotes, and caching for performance.
/// Ensures content integrity through hash verification.
class CasResolver {
  final CasResolverConfig config;
  final String? _localStorageRoot;
  final http.Client _httpClient;
  final Map<String, CasResolutionResult> _memoryCache = {};

  CasResolver({
    CasResolverConfig? config,
    String? localStorageRoot,
    http.Client? httpClient,
  }) : config = config ?? const CasResolverConfig(),
       _localStorageRoot = localStorageRoot,
       _httpClient = httpClient ?? http.Client();

  /// Resolve CAS URI to content with hash verification
  Future<CasResolutionResult> resolveContent(String casUri) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(casUri)) {
        final cached = _memoryCache[casUri]!;
        return CasResolutionResult(
          success: cached.success,
          content: cached.content,
          contentType: cached.contentType,
          contentLength: cached.contentLength,
          actualHash: cached.actualHash,
          hashVerified: cached.hashVerified,
          errorMessage: cached.errorMessage,
          resolutionTime: stopwatch.elapsed,
        );
      }

      // Parse CAS URI to extract hash algorithm and hash value
      final parsedUri = _parseCasUri(casUri);
      if (parsedUri == null) {
        stopwatch.stop();
        return _createErrorResult(
          'Invalid CAS URI format: $casUri',
          stopwatch.elapsed,
        );
      }

      final hashAlgorithm = parsedUri['algorithm']!;
      final expectedHash = parsedUri['hash']!;

      // Try local storage first
      if (_localStorageRoot != null) {
        final localResult = await _resolveFromLocal(hashAlgorithm, expectedHash);
        if (localResult.success) {
          stopwatch.stop();
          final result = CasResolutionResult(
            success: true,
            content: localResult.content,
            contentType: localResult.contentType,
            contentLength: localResult.content?.length,
            actualHash: localResult.actualHash,
            hashVerified: localResult.hashVerified,
            resolutionTime: stopwatch.elapsed,
          );
          _memoryCache[casUri] = result;
          return result;
        }
      }

      // Try remote resolvers
      for (final remote in config.trustedRemotes) {
        final remoteResult = await _resolveFromRemote(remote, hashAlgorithm, expectedHash);
        if (remoteResult.success) {
          stopwatch.stop();
          
          // Cache locally if caching is enabled
          if (config.enableCaching && remoteResult.content != null) {
            await _cacheContent(hashAlgorithm, expectedHash, remoteResult.content!);
          }
          
          final result = CasResolutionResult(
            success: true,
            content: remoteResult.content,
            contentType: remoteResult.contentType,
            contentLength: remoteResult.content?.length,
            actualHash: remoteResult.actualHash,
            hashVerified: remoteResult.hashVerified,
            resolutionTime: stopwatch.elapsed,
          );
          _memoryCache[casUri] = result;
          return result;
        }
      }

      stopwatch.stop();
      return _createErrorResult(
        'Content not found in any configured source',
        stopwatch.elapsed,
      );

    } catch (e) {
      stopwatch.stop();
      return _createErrorResult(
        'Failed to resolve CAS URI: $e',
        stopwatch.elapsed,
      );
    }
  }

  /// Verify content hash without resolving
  Future<bool> verifyContentHash(String casUri, Uint8List content) async {
    final parsedUri = _parseCasUri(casUri);
    if (parsedUri == null) return false;

    final hashAlgorithm = parsedUri['algorithm']!;
    final expectedHash = parsedUri['hash']!;
    final actualHash = _calculateHash(content, hashAlgorithm);

    return actualHash == expectedHash;
  }

  /// Store content in local CAS storage
  Future<String> storeContent(Uint8List content, {String algorithm = 'sha256'}) async {
    if (_localStorageRoot == null) {
      throw const CasResolutionException('Local storage not configured');
    }

    final hash = _calculateHash(content, algorithm);
    final casUri = 'cas:$algorithm:$hash';
    
    await _cacheContent(algorithm, hash, content);
    
    return casUri;
  }

  /// List available content in local storage
  Future<List<String>> listLocalContent({String? algorithm}) async {
    if (_localStorageRoot == null) return [];

    final cacheDir = Directory(_getCacheDirectory());
    if (!cacheDir.existsSync()) return [];

    final casUris = <String>[];
    
    await for (final entity in cacheDir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: cacheDir.path);
        final parts = relativePath.split(path.separator);
        
        if (parts.length == 2) {
          final algo = parts[0];
          final hash = path.basenameWithoutExtension(parts[1]);
          
          if (algorithm == null || algo == algorithm) {
            casUris.add('cas:$algo:$hash');
          }
        }
      }
    }
    
    return casUris;
  }

  /// Cleanup old cached content
  Future<void> cleanupCache({
    Duration? olderThan,
    int? keepRecentCount,
  }) async {
    if (_localStorageRoot == null) return;

    final cacheDir = Directory(_getCacheDirectory());
    if (!cacheDir.existsSync()) return;

    final files = <File>[];
    await for (final entity in cacheDir.list(recursive: true)) {
      if (entity is File) {
        files.add(entity);
      }
    }

    // Sort by modification time
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    int deletedCount = 0;

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      bool shouldDelete = false;

      // Keep recent count
      if (keepRecentCount != null && i >= keepRecentCount) {
        shouldDelete = true;
      }

      // Age-based cleanup
      if (olderThan != null) {
        final fileAge = DateTime.now().difference(file.lastModifiedSync());
        if (fileAge > olderThan) {
          shouldDelete = true;
        }
      }

      if (shouldDelete) {
        try {
          await file.delete();
          deletedCount++;
        } catch (e) {
          print('Warning: Failed to delete cached file ${file.path}: $e');
        }
      }
    }

    if (deletedCount > 0) {
      print('Cleaned up $deletedCount cached CAS files');
    }
  }

  /// Parse CAS URI format: cas:algorithm:hash
  Map<String, String>? _parseCasUri(String casUri) {
    final uriPattern = RegExp(r'^cas:([a-zA-Z0-9]+):([a-fA-F0-9]+)$');
    final match = uriPattern.firstMatch(casUri);
    
    if (match == null) return null;
    
    return {
      'algorithm': match.group(1)!,
      'hash': match.group(2)!,
    };
  }

  /// Resolve content from local storage
  Future<CasResolutionResult> _resolveFromLocal(String algorithm, String expectedHash) async {
    try {
      final file = File(_getCacheFilePath(algorithm, expectedHash));
      if (!file.existsSync()) {
        return _createErrorResult('Content not found in local storage', Duration.zero);
      }

      final content = await file.readAsBytes();
      final actualHash = _calculateHash(content, algorithm);
      final hashVerified = actualHash == expectedHash;

      return CasResolutionResult(
        success: hashVerified,
        content: hashVerified ? content : null,
        contentType: _detectContentType(content),
        actualHash: actualHash,
        hashVerified: hashVerified,
        errorMessage: hashVerified ? null : 'Hash verification failed',
        resolutionTime: Duration.zero,
      );
    } catch (e) {
      return _createErrorResult('Error reading from local storage: $e', Duration.zero);
    }
  }

  /// Resolve content from remote CAS server
  Future<CasResolutionResult> _resolveFromRemote(String remote, String algorithm, String expectedHash) async {
    for (int attempt = 0; attempt < config.maxRetries; attempt++) {
      try {
        final url = '$remote/cas/$algorithm/$expectedHash';
        final response = await _httpClient.get(
          Uri.parse(url),
          headers: config.customHeaders,
        ).timeout(config.timeout);

        if (response.statusCode == 200) {
          final content = response.bodyBytes;
          
          // Check content size limit
          if (content.length > config.maxContentSize) {
            return _createErrorResult(
              'Content size ${content.length} exceeds limit ${config.maxContentSize}',
              Duration.zero,
            );
          }

          final actualHash = _calculateHash(content, algorithm);
          final hashVerified = actualHash == expectedHash;

          return CasResolutionResult(
            success: hashVerified,
            content: hashVerified ? content : null,
            contentType: response.headers['content-type'],
            actualHash: actualHash,
            hashVerified: hashVerified,
            errorMessage: hashVerified ? null : 'Hash verification failed',
            resolutionTime: Duration.zero,
          );
        } else if (response.statusCode == 404) {
          break; // Don't retry for 404
        }
      } catch (e) {
        if (attempt == config.maxRetries - 1) {
          return _createErrorResult('Remote resolution failed: $e', Duration.zero);
        }
        await Future.delayed(config.retryDelay);
      }
    }

    return _createErrorResult('Content not found on remote', Duration.zero);
  }

  /// Cache content locally
  Future<void> _cacheContent(String algorithm, String hash, Uint8List content) async {
    if (!config.enableCaching || _localStorageRoot == null) return;

    try {
      final file = File(_getCacheFilePath(algorithm, hash));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(content);
    } catch (e) {
      print('Warning: Failed to cache content: $e');
    }
  }

  /// Get cache file path
  String _getCacheFilePath(String algorithm, String hash) {
    return path.join(_getCacheDirectory(), algorithm, '$hash.bin');
  }

  /// Get cache directory path
  String _getCacheDirectory() {
    return config.cacheDirectory ?? 
           path.join(_localStorageRoot!, 'cas_cache');
  }

  /// Calculate hash for content
  String _calculateHash(Uint8List content, String algorithm) {
    switch (algorithm.toLowerCase()) {
      case 'sha256':
        return sha256.convert(content).toString();
      case 'sha1':
        return sha1.convert(content).toString();
      case 'md5':
        return md5.convert(content).toString();
      default:
        throw CasResolutionException('Unsupported hash algorithm: $algorithm');
    }
  }

  /// Detect content type from content
  String? _detectContentType(Uint8List content) {
    if (content.isEmpty) return null;

    // Check for common file signatures
    if (content.length >= 4) {
      // PNG
      if (content[0] == 0x89 && content[1] == 0x50 && content[2] == 0x4E && content[3] == 0x47) {
        return 'image/png';
      }
      // JPEG
      if (content[0] == 0xFF && content[1] == 0xD8 && content[2] == 0xFF) {
        return 'image/jpeg';
      }
      // PDF
      if (content[0] == 0x25 && content[1] == 0x50 && content[2] == 0x44 && content[3] == 0x46) {
        return 'application/pdf';
      }
    }

    // Check if it's UTF-8 text
    try {
      final text = utf8.decode(content);
      if (text.startsWith('{') || text.startsWith('[')) {
        return 'application/json';
      }
      if (text.startsWith('<')) {
        return 'text/xml';
      }
      return 'text/plain';
    } catch (e) {
      return 'application/octet-stream';
    }
  }

  /// Create error result
  CasResolutionResult _createErrorResult(String message, Duration duration) {
    return CasResolutionResult(
      success: false,
      hashVerified: false,
      errorMessage: message,
      resolutionTime: duration,
    );
  }

  /// Get resolver statistics
  Map<String, dynamic> getStats() {
    return {
      'memory_cache_size': _memoryCache.length,
      'trusted_remotes': config.trustedRemotes.length,
      'caching_enabled': config.enableCaching,
      'local_storage_configured': _localStorageRoot != null,
    };
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
    _memoryCache.clear();
  }
}
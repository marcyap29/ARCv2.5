// lib/mcp/bundle/manifest.dart
// Builder for MCP manifest.json with deterministic output
// Accumulates counts, bytes, and checksums while maintaining encoder registry

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;

/// Builder for MCP bundle manifest
class ManifestBuilder {
  String? _bundleId;
  String? _version;
  String? _storageProfile;
  final Map<String, int> _counts = {};
  final Map<String, int> _bytes = {};
  final Map<String, String> _checksums = {};
  final List<Map<String, dynamic>> _encoderRegistry = [];
  final List<String> _casRemotes = [];
  String? _notes;

  /// Set bundle metadata
  void setBundleInfo({
    required String bundleId,
    required String version,
    required String storageProfile,
    String? notes,
  }) {
    _bundleId = bundleId;
    _version = version;
    _storageProfile = storageProfile;
    _notes = notes;
  }

  /// Add file statistics
  void addFileStats({
    required String filename,
    required int count,
    required int bytes,
    required String checksum,
  }) {
    final key = filename.replaceAll('.jsonl', '');
    _counts[key] = count;
    _bytes['${key}_jsonl'] = bytes;
    _checksums['${key}_jsonl'] = checksum;
  }

  /// Add encoder to registry
  void addEncoder({
    required String encoderId,
    required String version,
    required Map<String, dynamic> config,
  }) {
    _encoderRegistry.add({
      'encoder_id': encoderId,
      'version': version,
      'config': config,
    });
  }

  /// Add CAS remote
  void addCasRemote(String remoteUrl) {
    if (!_casRemotes.contains(remoteUrl)) {
      _casRemotes.add(remoteUrl);
    }
  }

  /// Build the manifest as a sorted map
  Map<String, dynamic> build() {
    if (_bundleId == null || _version == null || _storageProfile == null) {
      throw StateError('Bundle ID, version, and storage profile must be set');
    }

    final manifest = {
      'bundle_id': _bundleId!,
      'version': _version!,
      'schema_version': '1.0.0', // Add schema_version for manifest compatibility
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'storage_profile': _storageProfile!,
      'counts': Map<String, dynamic>.from(_counts),
      'bytes': Map<String, dynamic>.from(_bytes),
      'checksums': Map<String, dynamic>.from(_checksums),
      'encoder_registry': List<Map<String, dynamic>>.from(_encoderRegistry),
      'cas_remotes': List<String>.from(_casRemotes),
    };

    if (_notes != null && _notes!.isNotEmpty) {
      manifest['notes'] = _notes!;
    }

    return _sortMapKeys(manifest);
  }

  /// Build and write manifest to file
  Future<void> writeToFile(File file) async {
    final manifest = build();
    final json = const JsonEncoder.withIndent('  ').convert(manifest);
    await file.writeAsString(json);
  }

  /// Sort map keys recursively for deterministic output
  Map<String, dynamic> _sortMapKeys(Map<String, dynamic> map) {
    final sorted = Map<String, dynamic>.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    sorted.updateAll((key, value) {
      if (value is Map<String, dynamic>) {
        return _sortMapKeys(value);
      } else if (value is List) {
        return value.map((item) {
          if (item is Map<String, dynamic>) {
            return _sortMapKeys(item);
          }
          return item;
        }).toList();
      }
      return value;
    });

    return sorted;
  }

  /// Reset builder state
  void reset() {
    _bundleId = null;
    _version = null;
    _storageProfile = null;
    _counts.clear();
    _bytes.clear();
    _checksums.clear();
    _encoderRegistry.clear();
    _casRemotes.clear();
    _notes = null;
  }
}

/// Helper class for file checksum calculation
class FileChecksumCalculator {
  final File file;
  final crypto.Digest digest;

  FileChecksumCalculator._(this.file, this.digest);

  /// Calculate SHA-256 checksum of a file
  static Future<FileChecksumCalculator> sha256(File file) async {
    final bytes = await file.readAsBytes();
    final digest = crypto.sha256.convert(bytes);
    return FileChecksumCalculator._(file, digest);
  }

  /// Get checksum as hex string with algorithm prefix
  String get checksumString => 'sha256:$digest';

  /// Get raw digest
  crypto.Digest get rawDigest => digest;

  /// Get file size in bytes
  Future<int> get fileSize async => await file.length();
}

/// Default encoder registry for EPI
class DefaultEncoderRegistry {
  /// Get default encoders for EPI system
  static List<Map<String, dynamic>> get encoders => [
    {
      'encoder_id': 'gemini_1_5_flash',
      'version': '1.0.0',
      'config': {
        'model': 'gemini-2.5-flash',
        'temperature': 0.7,
        'max_tokens': 2048,
        'features': ['sage_echo', 'arcform_keywords', 'phase_hints'],
      },
    },
    {
      'encoder_id': 'arc_llm_system',
      'version': '1.0.0',
      'config': {
        'prompts_version': 'v1',
        'fallback_enabled': true,
        'rule_based_adapter': true,
      },
    },
  ];

  /// Get encoder for specific model
  static Map<String, dynamic>? getEncoder(String encoderId) {
    return encoders.cast<Map<String, dynamic>?>().firstWhere(
      (encoder) => encoder?['encoder_id'] == encoderId,
      orElse: () => null,
    );
  }
}
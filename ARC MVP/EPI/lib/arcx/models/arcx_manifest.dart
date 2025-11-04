/// ARCX Manifest Model
/// 
/// Represents the metadata and cryptographic information for an .arcx archive.
library arcx_manifest;

class ARCXManifest {
  final String version;
  final String algo;
  final String kdf;
  final Map<String, dynamic>? kdfParams;
  final String sha256;
  final String signerPubkeyFpr;
  final String signatureB64;
  final ARCXPayloadMeta payloadMeta;
  final String mcpManifestSha256;
  final String exportedAt;
  final String appVersion;
  final Map<String, dynamic> redactionReport;
  final Map<String, dynamic>? metadata;
  
  // Password-based encryption fields
  final bool isPasswordEncrypted;
  final String? saltB64;
  
  // Chunked format fields
  final String? exportId;
  final int? chunkSize;
  final int? totalChunks;
  final String? formatVersion;
  
  // New ARCX 1.2 format fields
  final String? arcxVersion; // "1.2" for new format
  final ARCXScope? scope; // entries_count, chats_count, media_count, separate_groups
  final ARCXEncryptionInfo? encryptionInfo; // enabled, algorithm
  final ARCXChecksumsInfo? checksumsInfo; // enabled, algorithm, file
  
  ARCXManifest({
    required this.version,
    required this.algo,
    required this.kdf,
    this.kdfParams,
    required this.sha256,
    required this.signerPubkeyFpr,
    required this.signatureB64,
    required this.payloadMeta,
    required this.mcpManifestSha256,
    required this.exportedAt,
    required this.appVersion,
    required this.redactionReport,
    this.metadata,
    this.isPasswordEncrypted = false,
    this.saltB64,
    this.exportId,
    this.chunkSize,
    this.totalChunks,
    this.formatVersion,
    this.arcxVersion,
    this.scope,
    this.encryptionInfo,
    this.checksumsInfo,
  });
  
  factory ARCXManifest.fromJson(Map<String, dynamic> json) {
    // Support both old format (version-based) and new format (arcx_version-based)
    return ARCXManifest(
      version: json['version'] as String? ?? '1.0',
      algo: json['algo'] as String? ?? (json['encryption'] as Map<String, dynamic>?)?['algorithm'] as String? ?? 'AES-256-GCM',
      kdf: json['kdf'] as String? ?? 'pbkdf2-sha256-600000',
      kdfParams: json['kdf_params'] as Map<String, dynamic>?,
      sha256: json['sha256'] as String? ?? '',
      signerPubkeyFpr: json['signer_pubkey_fpr'] as String? ?? '',
      signatureB64: json['signature_b64'] as String? ?? '',
      payloadMeta: json['payload_meta'] != null 
          ? ARCXPayloadMeta.fromJson(json['payload_meta'] as Map<String, dynamic>)
          : ARCXPayloadMeta(journalCount: 0, photoMetaCount: 0, bytes: 0),
      mcpManifestSha256: json['mcp_manifest_sha256'] as String? ?? '',
      exportedAt: json['exported_at'] as String? ?? DateTime.now().toUtc().toIso8601String(),
      appVersion: json['app_version'] as String? ?? '1.0.0',
      redactionReport: json['redaction_report'] as Map<String, dynamic>? ?? {},
      metadata: json['metadata'] as Map<String, dynamic>?,
      isPasswordEncrypted: json['is_password_encrypted'] as bool? ?? false,
      saltB64: json['salt_b64'] as String?,
      exportId: json['export_id'] as String?,
      chunkSize: json['chunk_size'] as int?,
      totalChunks: json['total_chunks'] as int?,
      formatVersion: json['format_version'] as String?,
      arcxVersion: json['arcx_version'] as String?,
      scope: json['scope'] != null ? ARCXScope.fromJson(json['scope'] as Map<String, dynamic>) : null,
      encryptionInfo: json['encryption'] != null ? ARCXEncryptionInfo.fromJson(json['encryption'] as Map<String, dynamic>) : null,
      checksumsInfo: json['checksums'] != null ? ARCXChecksumsInfo.fromJson(json['checksums'] as Map<String, dynamic>) : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    final isNewFormat = arcxVersion != null;
    
    if (isNewFormat) {
      // New ARCX 1.2 format
      return {
        'arcx_version': arcxVersion!,
        'exported_at': exportedAt,
        'export_id': exportId ?? '',
        'scope': scope?.toJson(),
        'encryption': encryptionInfo?.toJson(),
        'checksums': checksumsInfo?.toJson(),
        // Keep legacy fields for backward compatibility
        'version': version,
        'sha256': sha256,
        'signature_b64': signatureB64,
        'signer_pubkey_fpr': signerPubkeyFpr,
      };
    } else {
      // Legacy format
      return {
        'version': version,
        'algo': algo,
        'kdf': kdf,
        if (kdfParams != null) 'kdf_params': kdfParams,
        'sha256': sha256,
        'signer_pubkey_fpr': signerPubkeyFpr,
        'signature_b64': signatureB64,
        'payload_meta': payloadMeta.toJson(),
        'mcp_manifest_sha256': mcpManifestSha256,
        'exported_at': exportedAt,
        'app_version': appVersion,
        'redaction_report': redactionReport,
        if (metadata != null) 'metadata': metadata,
        'is_password_encrypted': isPasswordEncrypted,
        if (saltB64 != null) 'salt_b64': saltB64,
        if (exportId != null) 'export_id': exportId,
        if (chunkSize != null) 'chunk_size': chunkSize,
        if (totalChunks != null) 'total_chunks': totalChunks,
        if (formatVersion != null) 'format_version': formatVersion,
      };
    }
  }
  
  /// Validate that the manifest structure is correct
  bool validate() {
    if (version.isEmpty || algo.isEmpty || kdf.isEmpty) return false;
    if (sha256.isEmpty || signerPubkeyFpr.isEmpty || signatureB64.isEmpty) return false;
    if (mcpManifestSha256.isEmpty || exportedAt.isEmpty || appVersion.isEmpty) return false;
    if (!payloadMeta.validate()) return false;
    return true;
  }
}

class ARCXPayloadMeta {
  final int journalCount;
  final int photoMetaCount;
  final int bytes;
  
  ARCXPayloadMeta({
    required this.journalCount,
    required this.photoMetaCount,
    required this.bytes,
  });
  
  factory ARCXPayloadMeta.fromJson(Map<String, dynamic> json) {
    return ARCXPayloadMeta(
      journalCount: json['journal_count'] as int? ?? 0,
      photoMetaCount: json['photo_meta_count'] as int? ?? 0,
      bytes: json['bytes'] as int? ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'journal_count': journalCount,
      'photo_meta_count': photoMetaCount,
      'bytes': bytes,
    };
  }
  
  bool validate() {
    return journalCount >= 0 && photoMetaCount >= 0 && bytes >= 0;
  }
}

/// ARCX Scope - describes what was exported
class ARCXScope {
  final int entriesCount;
  final int chatsCount;
  final int mediaCount;
  final bool separateGroups;
  
  ARCXScope({
    required this.entriesCount,
    required this.chatsCount,
    required this.mediaCount,
    required this.separateGroups,
  });
  
  factory ARCXScope.fromJson(Map<String, dynamic> json) {
    return ARCXScope(
      entriesCount: json['entries_count'] as int? ?? 0,
      chatsCount: json['chats_count'] as int? ?? 0,
      mediaCount: json['media_count'] as int? ?? 0,
      separateGroups: json['separate_groups'] as bool? ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'entries_count': entriesCount,
      'chats_count': chatsCount,
      'media_count': mediaCount,
      'separate_groups': separateGroups,
    };
  }
}

/// ARCX Encryption Info
class ARCXEncryptionInfo {
  final bool enabled;
  final String algorithm;
  
  ARCXEncryptionInfo({
    required this.enabled,
    required this.algorithm,
  });
  
  factory ARCXEncryptionInfo.fromJson(Map<String, dynamic> json) {
    return ARCXEncryptionInfo(
      enabled: json['enabled'] as bool? ?? true,
      algorithm: json['algorithm'] as String? ?? 'XChaCha20-Poly1305',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'algorithm': algorithm,
    };
  }
}

/// ARCX Checksums Info
class ARCXChecksumsInfo {
  final bool enabled;
  final String algorithm;
  final String file;
  
  ARCXChecksumsInfo({
    required this.enabled,
    required this.algorithm,
    required this.file,
  });
  
  factory ARCXChecksumsInfo.fromJson(Map<String, dynamic> json) {
    return ARCXChecksumsInfo(
      enabled: json['enabled'] as bool? ?? true,
      algorithm: json['algorithm'] as String? ?? 'sha256',
      file: json['file'] as String? ?? '/_checksums/sha256.txt',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'algorithm': algorithm,
      'file': file,
    };
  }
}


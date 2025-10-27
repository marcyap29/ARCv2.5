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
  });
  
  factory ARCXManifest.fromJson(Map<String, dynamic> json) {
    return ARCXManifest(
      version: json['version'] as String,
      algo: json['algo'] as String,
      kdf: json['kdf'] as String,
      kdfParams: json['kdf_params'] as Map<String, dynamic>?,
      sha256: json['sha256'] as String,
      signerPubkeyFpr: json['signer_pubkey_fpr'] as String,
      signatureB64: json['signature_b64'] as String,
      payloadMeta: ARCXPayloadMeta.fromJson(json['payload_meta'] as Map<String, dynamic>),
      mcpManifestSha256: json['mcp_manifest_sha256'] as String,
      exportedAt: json['exported_at'] as String,
      appVersion: json['app_version'] as String,
      redactionReport: json['redaction_report'] as Map<String, dynamic>,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  
  Map<String, dynamic> toJson() {
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
    };
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


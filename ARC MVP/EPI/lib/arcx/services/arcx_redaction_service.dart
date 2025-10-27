/// ARCX Redaction Service
/// 
/// MCP-aware redaction for journal entries and photo metadata.
library arcx_redaction_service;

import 'dart:convert';
import 'package:crypto/crypto.dart';

class ARCXRedactionService {
  
  /// Redact a journal entry
  /// 
  /// - Rotates ID with HKDF if installId provided
  /// - Clamps timestamp to date-only if dateOnly=true
  /// - Removes emotion and other PII fields
  static Map<String, dynamic> redactJournal(
    Map<String, dynamic> entry, {
    bool dateOnly = false,
    String? installId,
  }) {
    final out = Map<String, dynamic>.from(entry);
    
    // Rotate ID with HKDF (use installId as salt)
    if (out['id'] != null && installId != null) {
      out['id'] = _hkdfRotate(out['id'], installId);
    }
    
    // Clamp timestamp to date-only if requested
    if (dateOnly && out['timestamp'] is String) {
      out['timestamp'] = (out['timestamp'] as String).substring(0, 10);
    }
    
    // Remove PII fields
    out.remove('emotion'); // may contain sensitive info
    out.remove('emotionReason');
    
    // Redact metadata
    if (out['metadata'] is Map) {
      final meta = Map<String, dynamic>.from(out['metadata']);
      meta.remove('device_id');
      meta.remove('ip');
      meta.remove('imported_from_mcp'); // may indicate source
      out['metadata'] = meta;
    }
    
    return out;
  }
  
  /// Redact photo metadata
  /// 
  /// - Always keeps sha256 + filename (already hashed)
  /// - Removes OCR text (may contain PII)
  /// - Optionally removes labels unless includeLabels=true
  static Map<String, dynamic> redactPhotoMeta(
    Map<String, dynamic> photo, {
    bool includeLabels = false,
  }) {
    final out = Map<String, dynamic>.from(photo);
    
    // Remove OCR text (may contain PII)
    out.remove('ocrText');
    
    // Remove analysisData labels unless opted-in
    if (!includeLabels) {
      if (out['analysisData'] is Map) {
        final analysis = Map<String, dynamic>.from(out['analysisData']);
        analysis.remove('labels');
        analysis.remove('faces');
        analysis.remove('objects'); // may contain identifiable objects
        out['analysisData'] = analysis;
      }
    }
    
    return out;
  }
  
  /// HKDF-based ID rotation using SHA-256
  /// 
  /// Takes an ID and rotates it deterministically using a salt.
  /// This allows the same install to always get the same rotated ID
  /// for the same original ID.
  static String _hkdfRotate(String id, String salt) {
    final key = utf8.encode(salt);
    final input = utf8.encode(id);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(input);
    return digest.toString().substring(0, 12); // First 12 hex chars
  }
  
  /// Compute redaction report
  /// 
  /// Returns a summary of what was redacted for the manifest.
  static Map<String, dynamic> computeRedactionReport({
    required int journalEntriesRedacted,
    required int photosRedacted,
    bool dateOnly = false,
    bool includePhotoLabels = false,
  }) {
    return {
      'journal_count': journalEntriesRedacted,
      'photo_count': photosRedacted,
      'timestamp_precision': dateOnly ? 'date-only' : 'full',
      'photo_labels_included': includePhotoLabels,
      'pii_fields_removed': ['emotion', 'emotionReason', 'ocrText', 'device_id', 'ip'],
    };
  }
}


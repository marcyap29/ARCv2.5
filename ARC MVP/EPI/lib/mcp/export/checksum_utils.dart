/// MCP Checksum Utilities
/// 
/// Provides SHA-256 checksum computation for MCP bundle files
/// and validation utilities.

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class McpChecksumUtils {
  /// Compute SHA-256 checksum for a file
  static String computeFileChecksum(File file) {
    final bytes = file.readAsBytesSync();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Compute SHA-256 checksum for bytes
  static String computeBytesChecksum(List<int> bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Compute SHA-256 checksum for a string
  static String computeStringChecksum(String content) {
    final bytes = utf8.encode(content);
    return computeBytesChecksum(bytes);
  }

  /// Compute SHA-256 checksum for JSON content
  static String computeJsonChecksum(Map<String, dynamic> json) {
    final jsonString = jsonEncode(json);
    return computeStringChecksum(jsonString);
  }

  /// Compute SHA-256 checksum for NDJSON content
  static String computeNdjsonChecksum(List<Map<String, dynamic>> records) {
    final ndjsonString = records
        .map((record) => jsonEncode(record))
        .join('\n');
    return computeStringChecksum(ndjsonString);
  }

  /// Verify file checksum
  static bool verifyFileChecksum(File file, String expectedChecksum) {
    try {
      final actualChecksum = computeFileChecksum(file);
      return actualChecksum == expectedChecksum;
    } catch (e) {
      return false;
    }
  }

  /// Verify NDJSON file checksum
  static bool verifyNdjsonChecksum(File file, String expectedChecksum) {
    try {
      final content = file.readAsStringSync();
      final actualChecksum = computeStringChecksum(content);
      return actualChecksum == expectedChecksum;
    } catch (e) {
      return false;
    }
  }

  /// Generate content-addressed URI
  static String generateCasUri(List<int> content) {
    final digest = sha256.convert(content);
    return 'cas://sha256/${digest.toString()}';
  }

  /// Generate content-addressed URI for string
  static String generateCasUriForString(String content) {
    final bytes = utf8.encode(content);
    return generateCasUri(bytes);
  }

  /// Generate content-addressed URI for JSON
  static String generateCasUriForJson(Map<String, dynamic> json) {
    final jsonString = jsonEncode(json);
    return generateCasUriForString(jsonString);
  }

  /// Extract hash from CAS URI
  static String? extractHashFromCasUri(String casUri) {
    final regex = RegExp(r'cas://sha256/([a-f0-9]{64})');
    final match = regex.firstMatch(casUri);
    return match?.group(1);
  }

  /// Validate CAS URI format
  static bool isValidCasUri(String casUri) {
    return extractHashFromCasUri(casUri) != null;
  }
}

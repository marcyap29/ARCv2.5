/// ARCX Crypto Service
/// 
/// Platform channel bridge to iOS native crypto operations.
library arcx_crypto_service;

import 'dart:typed_data';
import 'package:flutter/services.dart';

class ARCXCryptoService {
  static const MethodChannel _channel = MethodChannel('arcx/crypto');
  
  /// Sign data with Ed25519 (via iOS Secure Enclave)
  /// Returns base64-encoded signature
  static Future<String> signData(Uint8List data) async {
    try {
      final result = await _channel.invokeMethod<String>('signData', {
        'data': data,
      });
      if (result == null) throw Exception('Signing returned null');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to sign data: ${e.message}');
    }
  }
  
  /// Verify Ed25519 signature
  /// Returns true if signature is valid
  static Future<bool> verifySignature(Uint8List data, String signatureB64) async {
    try {
      final result = await _channel.invokeMethod<bool>('verifySignature', {
        'data': data,
        'signatureB64': signatureB64,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to verify signature: ${e.message}');
    }
  }
  
  /// Encrypt data with AES-256-GCM
  /// Returns ciphertext with appended nonce and tag
  static Future<Uint8List> encryptAEAD(Uint8List plaintext) async {
    try {
      final result = await _channel.invokeMethod<List<int>>('encryptAEAD', {
        'plaintext': plaintext,
      });
      if (result == null) throw Exception('Encryption returned null');
      return Uint8List.fromList(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to encrypt data: ${e.message}');
    }
  }
  
  /// Decrypt AES-256-GCM ciphertext
  /// Throws if authentication tag verification fails
  static Future<Uint8List> decryptAEAD(Uint8List ciphertext) async {
    try {
      final result = await _channel.invokeMethod<List<int>>('decryptAEAD', {
        'ciphertext': ciphertext,
      });
      if (result == null) throw Exception('Decryption returned null');
      return Uint8List.fromList(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to decrypt data: ${e.message}');
    }
  }
  
  /// Get signing public key fingerprint (hex)
  static Future<String> getSigningPublicKeyFingerprint() async {
    try {
      final result = await _channel.invokeMethod<String>('getSigningPublicKeyFingerprint');
      if (result == null) throw Exception('Fingerprint returned null');
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to get key fingerprint: ${e.message}');
    }
  }
}


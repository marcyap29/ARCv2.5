/// ARCX Crypto Service
/// 
/// Platform channel bridge to iOS native crypto operations.
library arcx_crypto_service;

import 'dart:async';
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
  
  // MARK: - Password-Based Encryption
  
  /// Derive key from password using PBKDF2
  static Future<Uint8List> deriveKeyPBKDF2({
    required String password,
    required Uint8List salt,
    required int iterations,
  }) async {
    try {
      final result = await _channel.invokeMethod<List<int>>('deriveKeyPBKDF2', {
        'password': password,
        'salt': salt,
        'iterations': iterations,
      });
      if (result == null) throw Exception('Key derivation returned null');
      return Uint8List.fromList(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to derive key: ${e.message}');
    }
  }
  
  /// Encrypt with password-derived key
  /// Returns (ciphertext, salt) tuple
  static Future<(Uint8List ciphertext, Uint8List salt)> encryptWithPassword(
    Uint8List plaintext,
    String password,
  ) async {
    try {
      print('ARCXCrypto: Starting encryption of ${plaintext.length} bytes');
      final result = await _channel.invokeMethod<Map>('encryptWithPassword', {
        'plaintext': plaintext,
        'password': password,
      }).timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw Exception('Encryption timed out after 120 seconds. The data may be too large. Try a smaller export.');
        },
      );
      
      if (result == null) throw Exception('Encryption returned null');
      
      final ciphertextData = result['ciphertext'] as List<int>?;
      final saltData = result['salt'] as List<int>?;
      
      if (ciphertextData == null || saltData == null) {
        throw Exception('Missing ciphertext or salt in response');
      }
      
      print('ARCXCrypto: Encryption complete (${ciphertextData.length} bytes)');
      print('ARCXCrypto: Salt received: ${saltData.length} bytes');
      print('ARCXCrypto: Salt hex: ${saltData.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
      return (
        Uint8List.fromList(ciphertextData),
        Uint8List.fromList(saltData),
      );
    } on PlatformException catch (e) {
      throw Exception('Failed to encrypt: ${e.message}');
    } on TimeoutException catch (e) {
      throw Exception('Encryption timed out: ${e.message}');
    }
  }
  
  /// Decrypt with password-derived key
  static Future<Uint8List> decryptWithPassword(
    Uint8List ciphertext,
    String password,
    Uint8List salt,
  ) async {
    try {
      final result = await _channel.invokeMethod<List<int>>('decryptWithPassword', {
        'ciphertext': ciphertext,
        'password': password,
        'salt': salt,
      });
      if (result == null) throw Exception('Decryption returned null');
      return Uint8List.fromList(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to decrypt: ${e.message}');
    }
  }
  
  /// Generate random salt (32 bytes)
  static Future<Uint8List> generateSalt() async {
    try {
      final result = await _channel.invokeMethod<List<int>>('generateSalt');
      if (result == null) throw Exception('Salt generation returned null');
      return Uint8List.fromList(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to generate salt: ${e.message}');
    }
  }
  
  /// Encrypt chunk with provided key and nonce
  static Future<Uint8List> encryptChunk(
    Uint8List plaintext,
    Uint8List key,
    Uint8List nonce, {
    Uint8List? aad,
  }) async {
    try {
      final result = await _channel.invokeMethod<List<int>>('encryptChunk', {
        'plaintext': plaintext,
        'key': key,
        'nonce': nonce,
        'aad': aad ?? Uint8List(0),
      });
      if (result == null) throw Exception('Chunk encryption returned null');
      return Uint8List.fromList(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to encrypt chunk: ${e.message}');
    }
  }
  
  /// Decrypt chunk with provided key and nonce
  static Future<Uint8List> decryptChunk(
    Uint8List ciphertext,
    Uint8List key,
    Uint8List nonce, {
    Uint8List? aad,
  }) async {
    try {
      final result = await _channel.invokeMethod<List<int>>('decryptChunk', {
        'ciphertext': ciphertext,
        'key': key,
        'nonce': nonce,
        'aad': aad ?? Uint8List(0),
      });
      if (result == null) throw Exception('Chunk decryption returned null');
      return Uint8List.fromList(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to decrypt chunk: ${e.message}');
    }
  }
}


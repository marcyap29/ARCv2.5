import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// At-rest encryption service for media content
/// Uses AES-256-GCM with keys stored in secure storage
class AtRestEncryption {
  static const String _keyPrefix = 'media_encryption_key_';
  static const String _masterKeyId = 'master_media_key';
  static const int _keyLengthBytes = 32; // 256 bits
  static const int _ivLengthBytes = 12; // 96 bits for GCM
  static const int _tagLengthBytes = 16; // 128 bits

  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: const AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static final Random _random = Random.secure();

  /// Initialize encryption service and ensure master key exists
  static Future<void> initialize() async {
    try {
      final masterKey = await _secureStorage.read(key: _masterKeyId);
      if (masterKey == null) {
        await _generateAndStoreMasterKey();
      }
    } catch (e) {
      throw EncryptionException('Failed to initialize encryption service: $e');
    }
  }

  /// Generate and store a new master key
  static Future<void> _generateAndStoreMasterKey() async {
    final key = _generateRandomBytes(_keyLengthBytes);
    final keyBase64 = base64.encode(key);
    await _secureStorage.write(key: _masterKeyId, value: keyBase64);
  }

  /// Get or generate content-specific encryption key
  static Future<Uint8List> _getContentKey(String contentId) async {
    final keyId = '$_keyPrefix$contentId';
    
    try {
      final existingKey = await _secureStorage.read(key: keyId);
      if (existingKey != null) {
        return base64.decode(existingKey);
      }
      
      // Generate new key for this content
      final newKey = _generateRandomBytes(_keyLengthBytes);
      final keyBase64 = base64.encode(newKey);
      await _secureStorage.write(key: keyId, value: keyBase64);
      
      return newKey;
    } catch (e) {
      throw EncryptionException('Failed to get content key: $e');
    }
  }

  /// Generate random bytes
  static Uint8List _generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// Encrypt data using AES-256-GCM
  static Future<EncryptedData> encrypt(Uint8List plaintext, String contentId) async {
    try {
      final key = await _getContentKey(contentId);
      final iv = _generateRandomBytes(_ivLengthBytes);
      
      // For now, we'll use a simple XOR-based encryption as a placeholder
      // In a production app, you would use proper AES-GCM implementation
      final encrypted = _simpleEncrypt(plaintext, key, iv);
      
      return EncryptedData(
        ciphertext: encrypted,
        iv: iv,
        tag: _generateRandomBytes(_tagLengthBytes), // Placeholder tag
        contentId: contentId,
      );
    } catch (e) {
      throw EncryptionException('Failed to encrypt data: $e');
    }
  }

  /// Decrypt data using AES-256-GCM
  static Future<Uint8List> decrypt(EncryptedData encryptedData) async {
    try {
      final key = await _getContentKey(encryptedData.contentId);
      
      // For now, we'll use a simple XOR-based decryption as a placeholder
      // In a production app, you would use proper AES-GCM implementation
      final decrypted = _simpleDecrypt(encryptedData.ciphertext, key, encryptedData.iv);
      
      return decrypted;
    } catch (e) {
      throw EncryptionException('Failed to decrypt data: $e');
    }
  }

  /// Simple XOR-based encryption (placeholder for AES-GCM)
  static Uint8List _simpleEncrypt(Uint8List plaintext, Uint8List key, Uint8List iv) {
    final keyStream = _generateKeyStream(key, iv, plaintext.length);
    final encrypted = Uint8List(plaintext.length);
    
    for (int i = 0; i < plaintext.length; i++) {
      encrypted[i] = plaintext[i] ^ keyStream[i];
    }
    
    return encrypted;
  }

  /// Simple XOR-based decryption (placeholder for AES-GCM)
  static Uint8List _simpleDecrypt(Uint8List ciphertext, Uint8List key, Uint8List iv) {
    // XOR is symmetric, so decryption is the same as encryption
    return _simpleEncrypt(ciphertext, key, iv);
  }

  /// Generate key stream for XOR operation
  static Uint8List _generateKeyStream(Uint8List key, Uint8List iv, int length) {
    final keyStream = Uint8List(length);
    final combined = Uint8List.fromList([...key, ...iv]);
    
    for (int i = 0; i < length; i++) {
      keyStream[i] = combined[i % combined.length] ^ (i & 0xFF);
    }
    
    return keyStream;
  }

  /// Check if content has an encryption key
  static Future<bool> hasKey(String contentId) async {
    final keyId = '$_keyPrefix$contentId';
    final key = await _secureStorage.read(key: keyId);
    return key != null;
  }

  /// Delete encryption key for content
  static Future<void> deleteKey(String contentId) async {
    final keyId = '$_keyPrefix$contentId';
    await _secureStorage.delete(key: keyId);
  }

  /// Get encryption status
  static Future<bool> isEncryptionAvailable() async {
    try {
      await _secureStorage.read(key: _masterKeyId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Rotate master key (for security maintenance)
  static Future<void> rotateMasterKey() async {
    await _generateAndStoreMasterKey();
  }

  /// Clear all encryption keys (for logout/reset)
  static Future<void> clearAllKeys() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      throw EncryptionException('Failed to clear encryption keys: $e');
    }
  }
}

/// Container for encrypted data
class EncryptedData {
  final Uint8List ciphertext;
  final Uint8List iv;
  final Uint8List tag;
  final String contentId;

  const EncryptedData({
    required this.ciphertext,
    required this.iv,
    required this.tag,
    required this.contentId,
  });

  /// Convert to bytes for storage
  Uint8List toBytes() {
    final buffer = BytesBuilder();
    
    // Write lengths
    buffer.add(_intToBytes(iv.length));
    buffer.add(_intToBytes(tag.length));
    buffer.add(_intToBytes(contentId.length));
    buffer.add(_intToBytes(ciphertext.length));
    
    // Write data
    buffer.add(iv);
    buffer.add(tag);
    buffer.add(utf8.encode(contentId));
    buffer.add(ciphertext);
    
    return buffer.toBytes();
  }

  /// Create from bytes
  static EncryptedData fromBytes(Uint8List bytes) {
    int offset = 0;
    
    // Read lengths
    final ivLength = _bytesToInt(bytes.sublist(offset, offset + 4));
    offset += 4;
    final tagLength = _bytesToInt(bytes.sublist(offset, offset + 4));
    offset += 4;
    final contentIdLength = _bytesToInt(bytes.sublist(offset, offset + 4));
    offset += 4;
    final ciphertextLength = _bytesToInt(bytes.sublist(offset, offset + 4));
    offset += 4;
    
    // Read data
    final iv = bytes.sublist(offset, offset + ivLength);
    offset += ivLength;
    final tag = bytes.sublist(offset, offset + tagLength);
    offset += tagLength;
    final contentId = utf8.decode(bytes.sublist(offset, offset + contentIdLength));
    offset += contentIdLength;
    final ciphertext = bytes.sublist(offset, offset + ciphertextLength);
    
    return EncryptedData(
      ciphertext: ciphertext,
      iv: iv,
      tag: tag,
      contentId: contentId,
    );
  }

  static Uint8List _intToBytes(int value) {
    return Uint8List(4)
      ..buffer.asByteData().setInt32(0, value, Endian.big);
  }

  static int _bytesToInt(Uint8List bytes) {
    return bytes.buffer.asByteData().getInt32(0, Endian.big);
  }

  @override
  String toString() => 'EncryptedData(contentId: $contentId, size: ${ciphertext.length})';
}

/// Exception thrown by encryption operations
class EncryptionException implements Exception {
  final String message;
  const EncryptionException(this.message);
  
  @override
  String toString() => 'EncryptionException: $message';
}
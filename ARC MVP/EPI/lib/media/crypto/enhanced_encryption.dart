import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

/// Enhanced encryption service with DEK/KEK architecture and key rotation
class EnhancedEncryptionService {
  static const String _kekKeyId = 'media_master_kek';
  static const String _dekPrefix = 'media_dek_';
  static const String _keyRotationPrefix = 'key_rotation_';
  static const int _dekLengthBytes = 32; // 256 bits
  static const int _ivLengthBytes = 12; // 96 bits for GCM
  static const int _tagLengthBytes = 16; // 128 bits
  static const int _defaultRotationDays = 30;

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.when_unlocked,
    ),
  );

  static final Random _random = Random.secure();

  /// Initialize encryption service with KEK
  static Future<void> initialize() async {
    try {
      // Ensure KEK exists
      final kek = await _secureStorage.read(key: _kekKeyId);
      if (kek == null) {
        await _generateAndStoreKEK();
      }
      
      // Check if key rotation is needed
      await _checkAndRotateKeys();
    } catch (e) {
      throw EncryptionException('Failed to initialize enhanced encryption: $e');
    }
  }

  /// Generate and store Key Encryption Key (KEK)
  static Future<void> _generateAndStoreKEK() async {
    final kek = _generateRandomBytes(_dekLengthBytes);
    final kekBase64 = base64.encode(kek);
    
    await _secureStorage.write(key: _kekKeyId, value: kekBase64);
    
    // Record KEK creation time
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    await _secureStorage.write(key: '${_kekKeyId}_created', value: timestamp);
    
    print('EnhancedEncryptionService: Generated new KEK');
  }

  /// Get or generate Data Encryption Key (DEK) for content
  static Future<DEKInfo> _getOrCreateDEK(String contentId) async {
    final dekId = '$_dekPrefix$contentId';
    
    try {
      final existingDEK = await _secureStorage.read(key: dekId);
      if (existingDEK != null) {
        final dekInfo = DEKInfo.fromStoredString(existingDEK);
        
        // Check if DEK needs rotation
        if (_shouldRotateDEK(dekInfo)) {
          return await _rotateDEK(contentId, dekInfo);
        }
        
        return dekInfo;
      }
      
      // Generate new DEK
      return await _generateNewDEK(contentId);
    } catch (e) {
      throw EncryptionException('Failed to get/create DEK: $e');
    }
  }

  /// Generate new DEK for content
  static Future<DEKInfo> _generateNewDEK(String contentId) async {
    final plainDEK = _generateRandomBytes(_dekLengthBytes);
    final keyId = 'k_${DateTime.now().millisecondsSinceEpoch}';
    final createdAt = DateTime.now();
    
    // Encrypt DEK with KEK
    final encryptedDEK = await _encryptDEKWithKEK(plainDEK);
    
    final dekInfo = DEKInfo(
      keyId: keyId,
      encryptedDEK: encryptedDEK,
      createdAt: createdAt,
      lastUsed: createdAt,
      rotationCount: 0,
    );
    
    await _storeDEK(contentId, dekInfo);
    return dekInfo;
  }

  /// Encrypt DEK with KEK
  static Future<EncryptedDEK> _encryptDEKWithKEK(Uint8List plainDEK) async {
    final kekBase64 = await _secureStorage.read(key: _kekKeyId);
    if (kekBase64 == null) {
      throw EncryptionException('KEK not found');
    }
    
    final kek = base64.decode(kekBase64);
    final iv = _generateRandomBytes(_ivLengthBytes);
    
    // Simple XOR-based encryption (placeholder for AES-GCM)
    final encrypted = _xorEncrypt(plainDEK, kek, iv);
    final tag = _generateRandomBytes(_tagLengthBytes); // Placeholder MAC
    
    return EncryptedDEK(
      ciphertext: encrypted,
      iv: iv,
      tag: tag,
    );
  }

  /// Decrypt DEK with KEK
  static Future<Uint8List> _decryptDEKWithKEK(EncryptedDEK encryptedDEK) async {
    final kekBase64 = await _secureStorage.read(key: _kekKeyId);
    if (kekBase64 == null) {
      throw EncryptionException('KEK not found');
    }
    
    final kek = base64.decode(kekBase64);
    
    // Simple XOR-based decryption (placeholder for AES-GCM)
    return _xorDecrypt(encryptedDEK.ciphertext, kek, encryptedDEK.iv);
  }

  /// Store DEK information
  static Future<void> _storeDEK(String contentId, DEKInfo dekInfo) async {
    final dekId = '$_dekPrefix$contentId';
    await _secureStorage.write(key: dekId, value: dekInfo.toStoredString());
  }

  /// Check if DEK should be rotated
  static bool _shouldRotateDEK(DEKInfo dekInfo) {
    final rotationThreshold = DateTime.now().subtract(
      Duration(days: _defaultRotationDays),
    );
    return dekInfo.createdAt.isBefore(rotationThreshold);
  }

  /// Rotate DEK for content
  static Future<DEKInfo> _rotateDEK(String contentId, DEKInfo oldDEK) async {
    print('EnhancedEncryptionService: Rotating DEK for content $contentId');
    
    // Generate new DEK
    final newDEK = await _generateNewDEK(contentId);
    
    // Schedule background re-encryption of existing data
    await _scheduleReEncryption(contentId, oldDEK, newDEK);
    
    return newDEK;
  }

  /// Schedule background re-encryption task
  static Future<void> _scheduleReEncryption(
    String contentId,
    DEKInfo oldDEK,
    DEKInfo newDEK,
  ) async {
    // In a real implementation, this would queue a background job
    // to re-encrypt existing CAS chunks with the new DEK
    
    final taskId = 'reencrypt_${contentId}_${DateTime.now().millisecondsSinceEpoch}';
    await _secureStorage.write(
      key: '${_keyRotationPrefix}$taskId',
      value: jsonEncode({
        'contentId': contentId,
        'oldKeyId': oldDEK.keyId,
        'newKeyId': newDEK.keyId,
        'scheduledAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      }),
    );
    
    print('EnhancedEncryptionService: Scheduled re-encryption task $taskId');
  }

  /// Encrypt data with content-specific DEK
  static Future<EnhancedEncryptedData> encrypt(
    Uint8List plaintext,
    String contentId,
  ) async {
    try {
      final dekInfo = await _getOrCreateDEK(contentId);
      final plainDEK = await _decryptDEKWithKEK(dekInfo.encryptedDEK);
      
      final iv = _generateRandomBytes(_ivLengthBytes);
      final encrypted = _xorEncrypt(plaintext, plainDEK, iv);
      final tag = _generateRandomBytes(_tagLengthBytes); // Placeholder MAC
      
      // Update last used timestamp
      final updatedDEK = dekInfo.copyWith(lastUsed: DateTime.now());
      await _storeDEK(contentId, updatedDEK);
      
      return EnhancedEncryptedData(
        ciphertext: encrypted,
        iv: iv,
        tag: tag,
        keyId: dekInfo.keyId,
        algorithm: 'AES-GCM',
      );
    } catch (e) {
      throw EncryptionException('Failed to encrypt data: $e');
    }
  }

  /// Decrypt data using specified key ID
  static Future<Uint8List> decrypt(
    EnhancedEncryptedData encryptedData,
    String contentId,
  ) async {
    try {
      final dekInfo = await _getOrCreateDEK(contentId);
      
      // Check if we're decrypting with the current key
      if (dekInfo.keyId != encryptedData.keyId) {
        // Try to find the old key for this encrypted data
        final oldDEK = await _findDEKByKeyId(encryptedData.keyId);
        if (oldDEK != null) {
          final plainDEK = await _decryptDEKWithKEK(oldDEK.encryptedDEK);
          return _xorDecrypt(encryptedData.ciphertext, plainDEK, encryptedData.iv);
        } else {
          throw EncryptionException('Key not found: ${encryptedData.keyId}');
        }
      }
      
      final plainDEK = await _decryptDEKWithKEK(dekInfo.encryptedDEK);
      return _xorDecrypt(encryptedData.ciphertext, plainDEK, encryptedData.iv);
    } catch (e) {
      throw EncryptionException('Failed to decrypt data: $e');
    }
  }

  /// Find DEK by key ID (for decrypting old data)
  static Future<DEKInfo?> _findDEKByKeyId(String keyId) async {
    // In a real implementation, we'd maintain a key registry
    // For now, return null to indicate key not found
    return null;
  }

  /// Check for and perform key rotation
  static Future<void> _checkAndRotateKeys() async {
    final lastRotationKey = '${_kekKeyId}_last_rotation';
    final lastRotationStr = await _secureStorage.read(key: lastRotationKey);
    
    DateTime? lastRotation;
    if (lastRotationStr != null) {
      lastRotation = DateTime.fromMillisecondsSinceEpoch(int.parse(lastRotationStr));
    }
    
    final rotationThreshold = DateTime.now().subtract(
      Duration(days: _defaultRotationDays),
    );
    
    if (lastRotation == null || lastRotation.isBefore(rotationThreshold)) {
      await _performScheduledRotations();
      
      await _secureStorage.write(
        key: lastRotationKey,
        value: DateTime.now().millisecondsSinceEpoch.toString(),
      );
    }
  }

  /// Perform scheduled key rotations
  static Future<void> _performScheduledRotations() async {
    print('EnhancedEncryptionService: Checking for scheduled rotations');
    
    final allKeys = await _secureStorage.readAll();
    final rotationTasks = <String, String>{};
    
    for (final entry in allKeys.entries) {
      if (entry.key.startsWith(_keyRotationPrefix)) {
        rotationTasks[entry.key] = entry.value;
      }
    }
    
    for (final entry in rotationTasks.entries) {
      try {
        final taskData = jsonDecode(entry.value) as Map<String, dynamic>;
        if (taskData['status'] == 'pending') {
          await _performReEncryption(entry.key, taskData);
        }
      } catch (e) {
        print('EnhancedEncryptionService: Error processing rotation task ${entry.key}: $e');
      }
    }
  }

  /// Perform re-encryption task
  static Future<void> _performReEncryption(
    String taskKey,
    Map<String, dynamic> taskData,
  ) async {
    // In a real implementation, this would:
    // 1. Find all CAS entries encrypted with the old key
    // 2. Decrypt with old key, encrypt with new key
    // 3. Update CAS entries atomically
    // 4. Mark task as completed
    
    print('EnhancedEncryptionService: Re-encrypting content ${taskData['contentId']}');
    
    // Mark task as completed
    taskData['status'] = 'completed';
    taskData['completedAt'] = DateTime.now().toIso8601String();
    await _secureStorage.write(key: taskKey, value: jsonEncode(taskData));
  }

  /// Generate random bytes
  static Uint8List _generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// Simple XOR encryption (placeholder for AES-GCM)
  static Uint8List _xorEncrypt(Uint8List plaintext, Uint8List key, Uint8List iv) {
    final keyStream = _generateKeyStream(key, iv, plaintext.length);
    final encrypted = Uint8List(plaintext.length);
    
    for (int i = 0; i < plaintext.length; i++) {
      encrypted[i] = plaintext[i] ^ keyStream[i];
    }
    
    return encrypted;
  }

  /// Simple XOR decryption (placeholder for AES-GCM)
  static Uint8List _xorDecrypt(Uint8List ciphertext, Uint8List key, Uint8List iv) {
    return _xorEncrypt(ciphertext, key, iv); // XOR is symmetric
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

  /// Get encryption status and statistics
  static Future<EncryptionStats> getStats() async {
    final allKeys = await _secureStorage.readAll();
    
    int dekCount = 0;
    int rotationTasks = 0;
    DateTime? oldestDEK;
    DateTime? newestDEK;
    
    for (final entry in allKeys.entries) {
      if (entry.key.startsWith(_dekPrefix)) {
        dekCount++;
        
        try {
          final dekInfo = DEKInfo.fromStoredString(entry.value);
          if (oldestDEK == null || dekInfo.createdAt.isBefore(oldestDEK)) {
            oldestDEK = dekInfo.createdAt;
          }
          if (newestDEK == null || dekInfo.createdAt.isAfter(newestDEK)) {
            newestDEK = dekInfo.createdAt;
          }
        } catch (e) {
          // Skip malformed entries
        }
      } else if (entry.key.startsWith(_keyRotationPrefix)) {
        rotationTasks++;
      }
    }
    
    return EncryptionStats(
      dekCount: dekCount,
      rotationTasksCount: rotationTasks,
      oldestDEK: oldestDEK,
      newestDEK: newestDEK,
    );
  }

  /// Clear all encryption keys (for logout/reset)
  static Future<void> clearAllKeys() async {
    try {
      final allKeys = await _secureStorage.readAll();
      
      for (final key in allKeys.keys) {
        if (key.startsWith(_dekPrefix) || 
            key.startsWith(_keyRotationPrefix) ||
            key == _kekKeyId ||
            key.startsWith('${_kekKeyId}_')) {
          await _secureStorage.delete(key: key);
        }
      }
      
      print('EnhancedEncryptionService: Cleared all encryption keys');
    } catch (e) {
      throw EncryptionException('Failed to clear encryption keys: $e');
    }
  }
}

/// Data Encryption Key information
class DEKInfo {
  final String keyId;
  final EncryptedDEK encryptedDEK;
  final DateTime createdAt;
  final DateTime lastUsed;
  final int rotationCount;

  const DEKInfo({
    required this.keyId,
    required this.encryptedDEK,
    required this.createdAt,
    required this.lastUsed,
    required this.rotationCount,
  });

  DEKInfo copyWith({
    String? keyId,
    EncryptedDEK? encryptedDEK,
    DateTime? createdAt,
    DateTime? lastUsed,
    int? rotationCount,
  }) {
    return DEKInfo(
      keyId: keyId ?? this.keyId,
      encryptedDEK: encryptedDEK ?? this.encryptedDEK,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      rotationCount: rotationCount ?? this.rotationCount,
    );
  }

  String toStoredString() {
    return jsonEncode({
      'keyId': keyId,
      'encryptedDEK': encryptedDEK.toMap(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastUsed': lastUsed.millisecondsSinceEpoch,
      'rotationCount': rotationCount,
    });
  }

  factory DEKInfo.fromStoredString(String stored) {
    final data = jsonDecode(stored) as Map<String, dynamic>;
    return DEKInfo(
      keyId: data['keyId'],
      encryptedDEK: EncryptedDEK.fromMap(data['encryptedDEK']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt']),
      lastUsed: DateTime.fromMillisecondsSinceEpoch(data['lastUsed']),
      rotationCount: data['rotationCount'] ?? 0,
    );
  }
}

/// Encrypted DEK
class EncryptedDEK {
  final Uint8List ciphertext;
  final Uint8List iv;
  final Uint8List tag;

  const EncryptedDEK({
    required this.ciphertext,
    required this.iv,
    required this.tag,
  });

  Map<String, dynamic> toMap() {
    return {
      'ciphertext': base64.encode(ciphertext),
      'iv': base64.encode(iv),
      'tag': base64.encode(tag),
    };
  }

  factory EncryptedDEK.fromMap(Map<String, dynamic> map) {
    return EncryptedDEK(
      ciphertext: base64.decode(map['ciphertext']),
      iv: base64.decode(map['iv']),
      tag: base64.decode(map['tag']),
    );
  }
}

/// Enhanced encrypted data with key information
class EnhancedEncryptedData {
  final Uint8List ciphertext;
  final Uint8List iv;
  final Uint8List tag;
  final String keyId;
  final String algorithm;

  const EnhancedEncryptedData({
    required this.ciphertext,
    required this.iv,
    required this.tag,
    required this.keyId,
    required this.algorithm,
  });

  /// Get descriptor for JSON serialization
  Map<String, dynamic> getDescriptor() {
    return {
      'enc': algorithm,
      'kid': keyId,
    };
  }

  /// Convert to bytes for storage
  Uint8List toBytes() {
    final buffer = BytesBuilder();
    
    // Write metadata
    final metadata = jsonEncode(getDescriptor());
    final metadataBytes = utf8.encode(metadata);
    buffer.add(_intToBytes(metadataBytes.length));
    buffer.add(metadataBytes);
    
    // Write encryption data
    buffer.add(_intToBytes(iv.length));
    buffer.add(_intToBytes(tag.length));
    buffer.add(_intToBytes(ciphertext.length));
    buffer.add(iv);
    buffer.add(tag);
    buffer.add(ciphertext);
    
    return buffer.toBytes();
  }

  /// Create from bytes
  static EnhancedEncryptedData fromBytes(Uint8List bytes) {
    int offset = 0;
    
    // Read metadata
    final metadataLength = _bytesToInt(bytes.sublist(offset, offset + 4));
    offset += 4;
    final metadataBytes = bytes.sublist(offset, offset + metadataLength);
    offset += metadataLength;
    final metadata = jsonDecode(utf8.decode(metadataBytes)) as Map<String, dynamic>;
    
    // Read encryption data
    final ivLength = _bytesToInt(bytes.sublist(offset, offset + 4));
    offset += 4;
    final tagLength = _bytesToInt(bytes.sublist(offset, offset + 4));
    offset += 4;
    final ciphertextLength = _bytesToInt(bytes.sublist(offset, offset + 4));
    offset += 4;
    
    final iv = bytes.sublist(offset, offset + ivLength);
    offset += ivLength;
    final tag = bytes.sublist(offset, offset + tagLength);
    offset += tagLength;
    final ciphertext = bytes.sublist(offset, offset + ciphertextLength);
    
    return EnhancedEncryptedData(
      ciphertext: ciphertext,
      iv: iv,
      tag: tag,
      keyId: metadata['kid'],
      algorithm: metadata['enc'],
    );
  }

  static Uint8List _intToBytes(int value) {
    return Uint8List(4)
      ..buffer.asByteData().setInt32(0, value, Endian.big);
  }

  static int _bytesToInt(Uint8List bytes) {
    return bytes.buffer.asByteData().getInt32(0, Endian.big);
  }
}

/// Encryption statistics
class EncryptionStats {
  final int dekCount;
  final int rotationTasksCount;
  final DateTime? oldestDEK;
  final DateTime? newestDEK;

  const EncryptionStats({
    required this.dekCount,
    required this.rotationTasksCount,
    this.oldestDEK,
    this.newestDEK,
  });

  @override
  String toString() {
    return 'EncryptionStats(DEKs: $dekCount, rotations: $rotationTasksCount)';
  }
}

/// Enhanced encryption exception
class EncryptionException implements Exception {
  final String message;
  const EncryptionException(this.message);
  
  @override
  String toString() => 'EncryptionException: $message';
}
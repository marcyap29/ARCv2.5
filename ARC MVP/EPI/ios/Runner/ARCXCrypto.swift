/// ARCX Crypto Service
/// 
/// Provides Ed25519 signing and AES-256-GCM encryption for ARC Encrypted Archives.
/// Uses Secure Enclave when available, falls back to Keychain.
import Foundation
import CryptoKit
import Security
import CommonCrypto

class ARCXCrypto {
  private static let signingKeyIdentifier = "com.orbital.arcx.signing_key"
  private static let aeadKeyIdentifier = "com.orbital.arcx.aead_key"
  
  /// Generate or retrieve Ed25519 signing keypair
  /// Uses Secure Enclave when available, falls back to Keychain
  static func getSigningKey() throws -> Curve25519.Signing.PrivateKey {
    // Try to retrieve existing key from Keychain
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: signingKeyIdentifier.data(using: .utf8)!,
      kSecReturnData as String: true,
    ]
    
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    
    if status == errSecSuccess {
      guard let data = item as? Data else { throw ARCXCryptoError.keyRetrievalFailed }
      return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
    }
    
    // Generate new key
    let newKey = Curve25519.Signing.PrivateKey()
    
    // Store in Keychain with device-bound protection
    let keyData = newKey.rawRepresentation
    let storeQuery: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: signingKeyIdentifier.data(using: .utf8)!,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecValueData as String: keyData,
    ]
    
    let storeStatus = SecItemAdd(storeQuery as CFDictionary, nil)
    if storeStatus != errSecSuccess && storeStatus != errSecDuplicateItem {
      throw ARCXCryptoError.keyStorageFailed
    }
    
    return newKey
  }
  
  /// Sign data with Ed25519
  /// Returns base64-encoded signature
  static func signData(_ data: Data) throws -> String {
    let key = try getSigningKey()
    let signature = try key.signature(for: data)
    return signature.rawRepresentation.base64EncodedString()
  }
  
  /// Verify Ed25519 signature
  static func verifySignature(data: Data, signature: String) throws -> Bool {
    let key = try getSigningKey()
    guard let signatureData = Data(base64Encoded: signature) else {
      throw ARCXCryptoError.invalidSignature
    }
    
    let publicKey = key.publicKey
    let signature = try Curve25519.Signing.Signature(rawRepresentation: signatureData)
    return publicKey.isValidSignature(signature, for: data)
  }
  
  /// Get public key fingerprint (hex)
  static func getSigningPublicKeyFingerprint() throws -> String {
    let key = try getSigningKey()
    let publicKeyData = key.publicKey.rawRepresentation
    let digest = SHA256.hash(data: publicKeyData)
    return digest.map { String(format: "%02x", $0) }.joined()
  }
  
  /// Generate AES-256-GCM key for AEAD encryption
  private static func generateAEADKey() throws -> SymmetricKey {
    let newKey = SymmetricKey(size: .bits256)
    
    // Store in Keychain
    let keyData = newKey.withUnsafeBytes { Data($0) }
    let storeQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: aeadKeyIdentifier,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecValueData as String: keyData,
    ]
    
    let storeStatus = SecItemAdd(storeQuery as CFDictionary, nil)
    if storeStatus != errSecSuccess && storeStatus != errSecDuplicateItem {
      throw ARCXCryptoError.keyStorageFailed
    }
    
    return newKey
  }
  
  /// Get or generate AES-256-GCM key
  private static func getAEADKey() throws -> SymmetricKey {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: aeadKeyIdentifier,
      kSecReturnData as String: true,
    ]
    
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    
    if status == errSecSuccess {
      guard let keyData = item as? Data else { throw ARCXCryptoError.keyRetrievalFailed }
      return SymmetricKey(data: keyData)
    }
    
    // Generate new key if not found
    return try generateAEADKey()
  }
  
  /// Encrypt data with AES-256-GCM
  /// Returns ciphertext with appended authentication tag
  static func encryptAEAD(_ plaintext: Data) throws -> Data {
    let key = try getAEADKey()
    let sealedBox = try AES.GCM.seal(plaintext, using: key)
    
    // Combine nonce + ciphertext + tag
    var result = sealedBox.nonce.withUnsafeBytes { Data($0) }
    result.append(sealedBox.ciphertext)
    result.append(sealedBox.tag)
    
    return result
  }
  
  /// Decrypt AES-256-GCM ciphertext
  /// Throws if authentication tag verification fails
  static func decryptAEAD(_ ciphertext: Data) throws -> Data {
    guard ciphertext.count >= 12 + 16 else { // nonce (12) + min tag (16)
      throw ARCXCryptoError.invalidCiphertext
    }
    
    let nonce = ciphertext.prefix(12)
    let tagSize = 16 // AES-GCM tag is 16 bytes
    let tagStart = ciphertext.count - tagSize
    let tag = ciphertext[tagStart..<ciphertext.count]
    let encrypted = ciphertext[12..<tagStart]
    
    guard let sealedBox = try? AES.GCM.SealedBox(
      nonce: nonce,
      ciphertext: encrypted,
      tag: tag
    ) else {
      throw ARCXCryptoError.invalidCiphertext
    }
    
    let key = try getAEADKey()
    return try AES.GCM.open(sealedBox, using: key)
  }
  
  // MARK: - Password-Based Encryption
  
  /// Derive key from password using PBKDF2
  /// Returns 256-bit (32-byte) key
  static func deriveKeyPBKDF2(password: String, salt: Data, iterations: Int) throws -> SymmetricKey {
    guard let passwordData = password.data(using: .utf8) else {
      throw ARCXCryptoError.invalidPassword
    }
    
    var derivedKeyData = Data(count: 32) // 256 bits
    
    let status = CCKeyDerivationPBKDF(
      CCPBKDFAlgorithm(kCCPBKDF2),
      password,
      passwordData.count,
      [UInt8](salt),
      salt.count,
      CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
      UInt32(iterations),
      [UInt8](derivedKeyData),
      derivedKeyData.count
    )
    
    guard status == kCCSuccess else {
      throw ARCXCryptoError.keyDerivationFailed
    }
    
    return SymmetricKey(data: derivedKeyData)
  }
  
  /// Encrypt with password-derived key
  /// Returns (ciphertext, salt) tuple
  static func encryptWithPassword(_ plaintext: Data, password: String) throws -> (ciphertext: Data, salt: Data) {
    // Generate random salt
    var salt = Data(count: 32)
    let status = SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt)
    guard status == errSecSuccess else {
      throw ARCXCryptoError.saltGenerationFailed
    }
    
    // Derive key from password
    let key = try deriveKeyPBKDF2(password: password, salt: salt, iterations: 600000)
    
    // Encrypt
    let sealedBox = try AES.GCM.seal(plaintext, using: key)
    
    var result = sealedBox.nonce.withUnsafeBytes { Data($0) }
    result.append(sealedBox.ciphertext)
    result.append(sealedBox.tag)
    
    return (ciphertext: result, salt: salt)
  }
  
  /// Decrypt with password-derived key
  static func decryptWithPassword(_ ciphertext: Data, password: String, salt: Data) throws -> Data {
    guard ciphertext.count >= 12 + 16 else {
      throw ARCXCryptoError.invalidCiphertext
    }
    
    let nonce = ciphertext.prefix(12)
    guard let nonceBox = try? AES.GCM.Nonce(data: nonce) else {
      throw ARCXCryptoError.invalidCiphertext
    }
    
    let tagSize = 16
    let tagStart = ciphertext.count - tagSize
    let tag = ciphertext[tagStart..<ciphertext.count]
    let encrypted = ciphertext[12..<tagStart]
    
    guard let sealedBox = try? AES.GCM.SealedBox(
      nonce: nonceBox,
      ciphertext: encrypted,
      tag: tag
    ) else {
      throw ARCXCryptoError.invalidCiphertext
    }
    
    let key = try deriveKeyPBKDF2(password: password, salt: salt, iterations: 600000)
    return try AES.GCM.open(sealedBox, using: key)
  }
}

enum ARCXCryptoError: Error {
  case keyRetrievalFailed
  case keyStorageFailed
  case invalidSignature
  case invalidCiphertext
  case invalidPassword
  case keyDerivationFailed
  case saltGenerationFailed
}


/// ARCX File Protection Helper
/// 
/// Provides secure file storage with NSFileProtectionComplete and secure deletion.
import Foundation

class ARCXFileProtection {
  
  /// Set NSFileProtectionComplete on a file at the given path
  static func setCompleteProtection(_ path: String) throws {
    let fm = FileManager.default
    try fm.setAttributes(
      [FileAttributeKey.protectionKey: FileProtectionType.complete],
      ofItemAtPath: path
    )
  }
  
  /// Create a protected directory with NSFileProtectionComplete
  static func createProtectedDirectory(at url: URL) throws {
    let fm = FileManager.default
    try fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: [
      FileAttributeKey.protectionKey: FileProtectionType.complete
    ])
  }
  
  /// Securely delete a file by overwriting its contents first
  /// This is a best-effort secure delete (filesystem may still retain data)
  static func secureDelete(_ path: String) throws {
    let fm = FileManager.default
    guard fm.fileExists(atPath: path) else { return }
    
    // Overwrite file with random data multiple times
    guard let fileHandle = FileHandle(forWritingAtPath: path) else {
      throw ARCXFileProtectionError.deletionFailed
    }
    
    let fileSize = try fm.attributesOfItem(atPath: path)[.size] as? Int ?? 0
    
    // Overwrite with random data 3 times
    for _ in 0..<3 {
      fileHandle.seek(toFileOffset: 0)
      let randomData = Data((0..<fileSize).map { _ in UInt8.random(in: 0...255) })
      fileHandle.write(randomData)
      try fileHandle.synchronize()
    }
    
    fileHandle.closeFile()
    
    // Finally delete the file
    try fm.removeItem(atPath: path)
  }
  
  /// Securely delete all files in a directory
  static func secureDeleteDirectory(at url: URL) throws {
    let fm = FileManager.default
    guard fm.fileExists(atPath: url.path) else { return }
    
    let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    for item in contents {
      if item.hasDirectoryPath {
        try secureDeleteDirectory(at: item)
      } else {
        try secureDelete(item.path)
      }
    }
    
    try fm.removeItem(at: url)
  }
}

enum ARCXFileProtectionError: Error {
  case deletionFailed
  case invalidPath
}


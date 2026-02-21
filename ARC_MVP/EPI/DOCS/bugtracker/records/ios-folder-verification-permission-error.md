# iOS Folder Verification Permission Error

Date: 2026-01-31
Status: Resolved ✅
Area: Export/Import, iOS Platform, File System Permissions
Severity: High

## Summary
Fixed critical issue where folder verification in `VerifyBackupScreen` failed on iOS with "Operation not permitted" error when attempting to scan `.arcx` backup files in user-selected folders.

## Impact
- **User Experience**: Users could not verify backup files on iOS devices
- **Functionality**: Complete failure of backup verification feature on iOS
- **Error Message**: `PathAccessException: Operation not permitted, errno = 1`
- **Platform**: iOS only (Android and other platforms unaffected)

## Root Cause
On iOS, when users select a folder using `FilePicker.platform.getDirectoryPath()`, the returned path is a **security-scoped resource** that requires explicit access permissions. The code was attempting to list directory contents without first requesting access to the security-scoped resource, causing iOS to deny the operation.

### Technical Details
- iOS sandboxing requires apps to explicitly request access to security-scoped resources
- `FilePicker` returns paths that are security-scoped but access must be granted before use
- Directory listing (`directory.list()`) fails without proper security-scoped access
- The `accessing_security_scoped_resource` package was already in dependencies but not being used

## Fix
Implemented proper security-scoped resource handling in two files:

### 1. `lib/mira/store/arcx/services/arcx_scan_service.dart`
- Added import for `accessing_security_scoped_resource` package
- Modified `scanArcxFolder()` to start accessing security-scoped resource before listing directory
- Added proper cleanup in `finally` block to stop accessing resource
- Added error handling for access failures

### 2. `lib/shared/ui/settings/verify_backup_screen.dart`
- Added import for `accessing_security_scoped_resource` package
- Modified `_scanFolder()` to start accessing security-scoped resource before scanning
- Added user-friendly error messages when access is denied
- Added proper cleanup in `finally` block to stop accessing resource

## Technical Implementation

### Security-Scoped Resource Access Pattern
```dart
// On iOS, start accessing security-scoped resource if needed
bool isAccessing = false;
if (Platform.isIOS) {
  try {
    final plugin = AccessingSecurityScopedResource();
    isAccessing = await plugin.startAccessingSecurityScopedResourceWithFilePath(directory.path);
    if (!isAccessing) {
      // Handle access denial
      return;
    }
  } catch (e) {
    // Handle access errors
    return;
  }
}

try {
  // Perform directory operations (listing, scanning, etc.)
  await for (final e in directory.list(followLinks: false)) {
    // Process files
  }
} finally {
  // Always stop accessing security-scoped resource
  if (Platform.isIOS && isAccessing) {
    try {
      final plugin = AccessingSecurityScopedResource();
      await plugin.stopAccessingSecurityScopedResourceWithFilePath(directory.path);
    } catch (e) {
      // Ignore errors when stopping access
    }
  }
}
```

### Key Changes
1. **Start Access**: Call `startAccessingSecurityScopedResourceWithFilePath()` before any directory operations
2. **Perform Operations**: Directory listing and file scanning work normally after access is granted
3. **Stop Access**: Always call `stopAccessingSecurityScopedResourceWithFilePath()` in `finally` block to release access
4. **Platform Check**: Only apply on iOS (other platforms don't require this)

## Files Modified
- `lib/mira/store/arcx/services/arcx_scan_service.dart`
  - Added security-scoped resource access handling in `scanArcxFolder()`
  - Added proper cleanup in `finally` block
  
- `lib/shared/ui/settings/verify_backup_screen.dart`
  - Added security-scoped resource access handling in `_scanFolder()`
  - Added user-friendly error messages
  - Added proper cleanup in `finally` block

## Verification
- ✅ Folder verification now works on iOS devices
- ✅ Security-scoped resources are properly accessed and released
- ✅ Error messages are user-friendly when access is denied
- ✅ No impact on Android or other platforms
- ✅ Proper cleanup ensures resources are always released

## Related Issues
- This is an iOS-specific platform issue related to file system permissions
- Similar patterns may be needed for other file operations that use `FilePicker` on iOS

## References
- iOS Security-Scoped Resources: [Apple Documentation](https://developer.apple.com/documentation/foundation/nsurl/1417051-startaccessingsecurityscopedreso)
- `accessing_security_scoped_resource` package: Already in `pubspec.yaml` (v3.4.0)
- Related: Export/Import system uses similar patterns for file access

## Prevention Measures
- Always use security-scoped resource access when working with `FilePicker` paths on iOS
- Wrap directory operations in try-finally blocks to ensure cleanup
- Test file system operations on iOS devices, not just simulators
- Consider creating a utility function for iOS security-scoped resource handling if this pattern is needed elsewhere

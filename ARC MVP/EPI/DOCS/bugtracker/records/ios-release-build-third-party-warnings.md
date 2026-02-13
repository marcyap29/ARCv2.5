# iOS Release Build: Third-Party Deprecation and Warning Noise

Date: 2026-02-13
Status: Open (tech debt)
Area: Build, iOS, Pods, Flutter plugins
Severity: Low (non-blocking)

## Summary
`flutter build ios --release` emits a large number of warnings from iOS Pods and Flutter plugin native code. Build can still succeed; these are tracked for future cleanup or dependency upgrades.

## Impact
- **Build**: Build may succeed despite warnings
- **Log noise**: Harder to spot real errors; CI/log review noisier
- **Future risk**: Some deprecations may become errors in future Xcode/SDK versions

## Sources of Warnings (from build log)

### DKImagePickerController (Pods)
- `timeRange` deprecated (iOS 16) → use `load(.timeRange)`
- `frameInterval` deprecated (iOS 10) → `preferredFramesPerSecond`
- `isExportable` deprecated (iOS 16) → `load(.isExportable)`
- `requestImageData(for:options:resultHandler:)` deprecated (iOS 13)
- `keyWindow` deprecated (iOS 13) — multiple scenes
- FileManager non-Sendable capture (Swift 6)

### gRPC-Core / zlib (Pods)
- `OS_CODE` macro redefined (zutil.h 170 vs 141)

### RevenueCatUI (Pods)
- `NavigationLink(destination:isActive:label:)` deprecated (iOS 16) → NavigationStack / navigationDestination

### file_picker (Flutter plugin, pub-cache)
- `UTTypeCreatePreferredIdentifierForTag` / `kUTTagClassFilenameExtension` deprecated (iOS 15) → UTType
- `UIApplication.shared.windows` deprecated (iOS 15) → UIWindowScene.windows
- `UIDocumentPickerMode*` / `initWithURL:inMode:` / `initWithDocumentTypes:inMode:` deprecated (iOS 14) → initForExportingURLs / initForOpeningContentTypes
- `kUTTypeMovie`, `kUTTypeImage`, etc. deprecated (iOS 15) → UTType
- `UIActivityIndicatorViewStyleWhite` deprecated (iOS 13) → UIActivityIndicatorViewStyleMedium
- `documentPickerMode` deprecated; incompatible pointer types (NSMutableArray vs NSArray); unused variable

### purchases_flutter (RevenueCat)
- `configureWithAPIKey:...` deprecated → full configure method
- `setDebugLogsEnabled:` deprecated → setLogLevel

### Firebase (Firestore, cloud_functions, firebase_core, firebase_auth, cloud_firestore)
- Extension conformance warnings (DocumentReference, GeoPoint, Timestamp, VectorValue, FlutterError) → add `@retroactive`
- `deepLinkURLScheme` deprecated; parameter type mismatch (BOOL vs NSNumber) in firebase_core
- `dynamicLinkDomain` deprecated (Firebase Dynamic Links) → Firebase Hosting / linkDomain
- firebase_auth: FLTFirebasePlugin type mismatch; unused variables; `keyWindow` deprecated; `fetchSignInMethodsForEmail` / `updateEmail` deprecated
- cloud_firestore: `setIndexConfigurationFromJSON:completion:` deprecated → enableIndexAutoCreation

### Other
- `ld: warning: ignoring duplicate libraries: '-lc++'`
- Run script phase "Create Symlinks to Header Folders" (gRPC-Core, gRPC-C++, abseil, BoringSSL-GRPC) — no outputs
- `PrivacyInfo.xcprivacy` no rule to process (accessing_security_scoped_resource)

## Recommendations
- **Short term**: Ignore for release if build succeeds; use to triage real errors vs warnings.
- **Medium term**: Upgrade Flutter plugins (file_picker, firebase_*, purchases_flutter) to versions that address deprecations; update or replace DKImagePickerController if maintained.
- **Long term**: Track Xcode/SDK upgrade path; replace deprecated APIs in forked or local pod code if any.

## Related Issues
- [ios-build-local-embedding-service-errors.md](ios-build-local-embedding-service-errors.md) — actual build failure (Dart errors) from same build run

## References
- Build log: `flutter build ios --release` (Feb 2026)
- Apple: deprecation notes in SDK headers
- DOCS: claude.md, ARCHITECTURE.md

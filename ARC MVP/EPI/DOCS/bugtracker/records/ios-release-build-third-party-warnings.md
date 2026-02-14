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

## How to fix (by priority)

1. **Short term (unblock release):**  
   - Treat these as warnings only; if `flutter build ios --release` succeeds, you can ship.  
   - When reviewing logs, ignore the known third‑party warning blocks and focus on real errors (e.g. Dart compile errors, signing failures).

2. **Reduce "Create Symlinks" / script phase noise (Xcode):**  
   - In Xcode: open the Pods project → select target (e.g. abseil, BoringSSL-GRPC, gRPC-Core, gRPC-C++) → Build Phases → "Create Symlinks to Header Folders".  
   - Either add explicit output paths for that script so it doesn’t run every time, or enable "Based on dependency analysis" / equivalent so the phase runs only when inputs change.

3. **PrivacyInfo.xcprivacy "no rule to process":**  
   - The `accessing_security_scoped_resource` pod ships a `.xcprivacy` file that Xcode doesn’t compile. Ensure the file is not added to "Compile Sources"; it should only be a resource/copy. If needed, exclude it from the target’s Compile Sources in the Pods project.

4. **Medium term (deprecations):**  
   - Upgrade Flutter plugins: `file_picker`, `firebase_*`, `purchases_flutter` (RevenueCat) to newer versions that fix iOS deprecations.  
   - Update or replace DKImagePickerController if a maintained fork or alternative exists.  
   - For Firebase: upgrade to versions that use `@retroactive` and the new APIs mentioned in the warnings.

5. **Long term:**  
   - Track Xcode/SDK upgrades; plan to replace or patch deprecated APIs in any forked or local pod code before they become hard errors.

## Recommendations (summary)
- **Short term**: Ignore for release if build succeeds; use to triage real errors vs warnings.
- **Medium term**: Upgrade Flutter plugins (file_picker, firebase_*, purchases_flutter) to versions that address deprecations; update or replace DKImagePickerController if maintained.
- **Long term**: Track Xcode/SDK upgrade path; replace deprecated APIs in forked or local pod code if any.

## Related Issues
- [ios-build-rivet-models-keywords-set-type.md](ios-build-rivet-models-keywords-set-type.md) — build failure (rivet_models.g.dart List/Set type) from same build run (resolved)
- [ios-build-local-embedding-service-errors.md](ios-build-local-embedding-service-errors.md) — actual build failure (Dart errors) from same build run

## References
- Build log: `flutter build ios --release` (Feb 2026)
- Terminal ref: 2026-02-13 — same build also showed: Run script "Create Symlinks to Header Folders" (abseil, BoringSSL-GRPC, gRPC-Core, gRPC-C++); "Create Symlinks" no outputs; PrivacyInfo.xcprivacy no rule (accessing_security_scoped_resource); Runner "Run Script" and "Thin Binary" run every build.
- Apple: deprecation notes in SDK headers
- DOCS: claude.md, ARCHITECTURE.md

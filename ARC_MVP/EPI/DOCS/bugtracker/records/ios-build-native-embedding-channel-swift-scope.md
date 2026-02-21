# iOS Build: NativeEmbeddingChannel Not in Scope (Swift)

Date: 2026-02-13
Status: Open
Area: Build, iOS, CHRONICLE, Native plugin
Severity: Critical

## Summary
After Dart compile succeeds, `flutter build ios --release` fails with **Swift Compiler Error**: `Cannot find 'NativeEmbeddingChannel' in scope` at `ios/Runner/AppDelegate.swift:104`. AppDelegate calls `NativeEmbeddingChannel.register(with: controller.binaryMessenger)` but the Swift compiler does not see the type.

## Impact
- **Build**: iOS release/device build fails at the Swift compilation step.
- **Error locus**: `ios/Runner/AppDelegate.swift:104`
- **Effect**: On-device embedding channel registration never runs; CHRONICLE embedding flow may fall back or fail at runtime if it relies on this channel.

## Reported Error (from build log)
```
Swift Compiler Error (Xcode): Cannot find 'NativeEmbeddingChannel' in scope
/Users/mymac/Software/Development/ARCv2.5/ARC%20MVP/EPI/ios/Runner/AppDelegate.swift:104:4
```

## Context
- `NativeEmbeddingChannel.swift` exists in `ios/Runner/` and is referenced in `Runner.xcodeproj/project.pbxproj` (PBXBuildFile / PBXFileReference, Sources).
- AppDelegate.swift line 104: `NativeEmbeddingChannel.register(with: controller.binaryMessenger)`
- So the type is defined in the same target (Runner); "not in scope" usually means the Swift file is not in the same target as AppDelegate, not compiled in the right order, or the symbol is not visible (e.g. wrong access level or missing import).

## Root Cause (suspected)
- **Target membership**: `NativeEmbeddingChannel.swift` might not be in the Runner target’s "Compile Sources", or the project file may be out of sync.
- **Visibility**: Class might be `internal` in a different module; AppDelegate is in Runner, so same target should see it. If the file was added but not added to the target, it would explain "not in scope."
- **Path/encoding**: Path with `%20` (space) in the error is URL-encoded; actual path is `ARC MVP/EPI` — ensure project and scheme use the same path and that the file is on disk at `ios/Runner/NativeEmbeddingChannel.swift`.

## Fix (when applying)
1. In Xcode: Select `NativeEmbeddingChannel.swift` → File Inspector → ensure "Target Membership" includes **Runner**.
2. In project.pbxproj: Confirm `NativeEmbeddingChannel.swift` appears in the Runner target’s `PBXSourcesBuildPhase` (e.g. `1F3EEF752E93526C009BFF74 /* NativeEmbeddingChannel.swift in Sources */`).
3. Clean build folder (Product → Clean Build Folder), then `flutter build ios --release` (or build from Xcode).
4. If the app uses a single Swift target and no custom modules, no extra import should be needed; if `NativeEmbeddingChannel` is in another target/module, add the appropriate import or move the type into Runner.

## Files Involved
- `ios/Runner/AppDelegate.swift` — call site (line 104).
- `ios/Runner/NativeEmbeddingChannel.swift` — type definition.
- `ios/Runner.xcodeproj/project.pbxproj` — target membership and compile sources.

## Verification
- [ ] Xcode build for Runner target succeeds.
- [ ] `flutter build ios --release` completes without Swift compiler errors.
- [ ] At runtime, embedding channel registration log appears if applicable (e.g. "NativeEmbeddingChannel registered ✅").

## Related Issues
- [ios-build-local-embedding-service-errors.md](ios-build-local-embedding-service-errors.md) — Dart-side CHRONICLE embedding errors that were fixed before this Swift error appeared.

## References
- Build log: `flutter build ios --release` (Feb 2026).
- DOCS: ARCHITECTURE.md (CHRONICLE, on-device embeddings), claude.md

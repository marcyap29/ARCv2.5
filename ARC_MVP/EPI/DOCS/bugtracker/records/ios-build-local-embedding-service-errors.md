# iOS Release Build Failure: CHRONICLE Embedding Stack (Dart + Swift)

Date: 2026-02-13
Status: Open (verify fix)
Area: Build, CHRONICLE, Embeddings, iOS
Severity: Critical

## Summary
`flutter build ios --release` fails in multiple phases: (1) Dart parse/type errors in `LocalEmbeddingService` and `ChronicleIndexBuilder`; (2) Dart type mismatch where call sites pass `EmbeddingService` but constructor required `LocalEmbeddingService`; (3) Swift compiler error: `NativeEmbeddingChannel` not in scope in AppDelegate. This record covers the Dart-side chain; the Swift error is also documented in [ios-build-native-embedding-channel-swift-scope.md](ios-build-native-embedding-channel-swift-scope.md).

## Impact
- **Build**: iOS release and device builds do not complete (kernel_snapshot_program failed, then Swift compile failed).
- **Error loci**: `lib/chronicle/embeddings/local_embedding_service.dart`, `lib/chronicle/index/chronicle_index_builder.dart`, call sites in `enhanced_lumara_api.dart`, `veil_chronicle_factory.dart`, `chronicle_management_view.dart`; then `ios/Runner/AppDelegate.swift`.

---

## Phase 1: Parse / type not found (Dart)

### Reported errors
1. **lib/chronicle/embeddings/local_embedding_service.dart:11:54** — `Error: Can't find '}' to match '{'.` at `class LocalEmbeddingService extends EmbeddingService {`.
2. **lib/chronicle/index/chronicle_index_builder.dart:24:14** — `Error: Type 'LocalEmbeddingService' not found` / `'LocalEmbeddingService' isn't a type` (constructor `required LocalEmbeddingService embedder`).
3. **lib/chronicle/embeddings/local_embedding_service.dart:54:12** — `Error: The method '_normalize' isn't defined for the type 'LocalEmbeddingService'.` at `return _normalize(embedding);`.

### Root cause (suspected)
Syntax/brace mismatch in `local_embedding_service.dart`; parser treats class body as unclosed so `LocalEmbeddingService` is undefined and `_normalize` appears out of scope.

### Fix
- Ensure brace balance in `local_embedding_service.dart`; keep `_normalize` as static or instance method on the same class.

---

## Phase 2: EmbeddingService vs LocalEmbeddingService (Dart)

### Reported errors (after Phase 1 fixed)
- **lib/arc/chat/services/enhanced_lumara_api.dart:231** — `The argument type 'EmbeddingService' can't be assigned to the parameter type 'LocalEmbeddingService'.` at `embedder: embedder`.
- **lib/chronicle/integration/veil_chronicle_factory.dart:44** — same.
- **lib/shared/ui/settings/chronicle_management_view.dart:135** — same.

### Root cause
`ChronicleIndexBuilder` (and/or `ThreeStagePatternMatcher`) was declared to take `LocalEmbeddingService`; call sites obtain an `EmbeddingService` (e.g. from `createEmbeddingService()`), so the type is too narrow.

### Fix
Use the **abstract type** `EmbeddingService` in public APIs so any implementation (e.g. `LocalEmbeddingService`) can be passed. In `chronicle_index_builder.dart`: `required EmbeddingService embedder` (not `LocalEmbeddingService`). Same for `ThreeStagePatternMatcher` if it had been constrained to `LocalEmbeddingService`. The codebase currently has `EmbeddingService` in `ChronicleIndexBuilder`; if the build still fails at these call sites, ensure all constructor and parameter types use `EmbeddingService`.

---

## Phase 3: Swift (separate record)
See [ios-build-native-embedding-channel-swift-scope.md](ios-build-native-embedding-channel-swift-scope.md) — `Cannot find 'NativeEmbeddingChannel' in scope` at `AppDelegate.swift:104`.

---

## Files Involved (Dart)
- `lib/chronicle/embeddings/local_embedding_service.dart` — parse/brace; `_normalize` visibility.
- `lib/chronicle/index/chronicle_index_builder.dart` — parameter type `EmbeddingService` (not `LocalEmbeddingService`).
- `lib/arc/chat/services/enhanced_lumara_api.dart`, `lib/chronicle/integration/veil_chronicle_factory.dart`, `lib/shared/ui/settings/chronicle_management_view.dart` — call sites passing `EmbeddingService`.

## Verification
- [ ] `flutter analyze` passes with no errors in `lib/chronicle/` and call sites.
- [ ] Dart kernel_snapshot_program succeeds.
- [ ] Swift build succeeds (see NativeEmbeddingChannel record).

## Related Issues
- [ios-build-native-embedding-channel-swift-scope.md](ios-build-native-embedding-channel-swift-scope.md) — next failure after Dart is fixed.
- CHRONICLE pattern index depends on `EmbeddingService` and `ChronicleIndexBuilder`.

## References
- Build log: `flutter build ios --release` (Feb 2026), multiple runs.
- DOCS: ARCHITECTURE.md (CHRONICLE), claude.md

# Photo Duplication in View Entry

Date: 2025-10-29
Status: Resolved ✅
Area: Journal UI

Summary
- Photos appeared twice in view-only mode: once inline in content and again in the Photos section.

Impact
- Visual duplication, confusing UX in entry view.

Root Cause
- `_buildContentView()` rendered photos when `isViewOnly`.
- `_buildInterleavedContent()` also rendered photos via `_buildPhotoThumbnailGrid()`.

Fix
- Remove photo rendering from `_buildContentView()`; only render text.
- Keep single source of truth via `_buildInterleavedContent()` → `_buildPhotoThumbnailGrid()`.

Files
- `lib/ui/journal/journal_screen.dart`

Verification
- Photos render only once in Photos section; layout clean.

References
- `docs/status/PHOTO_DUPLICATION_FIX_OCT_29_2025.md`


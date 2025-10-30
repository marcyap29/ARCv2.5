# MediaItem Adapter Registration Conflict

Date: 2025-10-29
Status: Resolved ✅
Area: Hive adapters, Import

Summary
- Import failed to save entries with media due to adapter ID conflicts and registration timing.

Impact
- Entries with photos failed to persist; import reported not imported entries.

Root Cause
- Rivet adapters used IDs 10/11 conflicting with MediaType/MediaItem 10/11.
- Parallel init led to inconsistent registration checks and missing MediaItem adapter at save time.

Fix
- Change Rivet adapter IDs to 20/21/22.
- Regenerate adapters; fix keywords Set conversion.
- Add `_ensureMediaItemAdapter()` safety check before saving entries with media.
- Add logging to verify registration.

Files
- `lib/atlas/rivet/rivet_models.dart`
- `lib/atlas/rivet/rivet_storage.dart`
- `lib/atlas/rivet/rivet_models.g.dart`
- `lib/main/bootstrap.dart`
- `lib/arc/core/journal_repository.dart`

Verification
- All entries with photos import and save; no adapter ID conflicts.

References
- `docs/status/MEDIAITEM_ADAPTER_FIX_OCT_29_2025.md`


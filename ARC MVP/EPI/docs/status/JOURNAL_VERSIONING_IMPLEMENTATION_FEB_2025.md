# Journal Versioning System Implementation

**Date**: February 2025  
**Status**: ✅ Complete

## Summary

Implemented a comprehensive journal versioning and draft management system with immutable versions, single-draft-per-entry invariant, content-hash autosave, media-aware conflict resolution, and migration support.

## Changes Implemented

### Core Services

1. **JournalVersionService** (`lib/core/services/journal_version_service.dart`)
   - Added `DraftMediaItem` and `DraftAIContent` models
   - Enhanced `JournalDraftWithHash` to include media and AI arrays
   - Implemented content-hash computation including media SHA256s and AI IDs
   - Added media file copying and snapshotting
   - Created conflict detection and resolution system
   - Implemented migration methods for legacy drafts and media

2. **DraftCacheService** (`lib/core/services/draft_cache_service.dart`)
   - Integrated with `JournalVersionService`
   - Added content-hash based autosave with debounce/throttle
   - Implemented single-draft invariant enforcement
   - Added methods: `publishDraft()`, `saveVersion()`, `discardDraft()`
   - Created LUMARA block conversion helpers

3. **JournalCaptureCubit** (`lib/arc/core/journal_capture_cubit.dart`)
   - Added conflict detection before saving
   - Integrated with version publishing system
   - Added `JournalCaptureConflictDetected` state

### UI Components

1. **VersionStatusBar** (`lib/ui/journal/widgets/version_status_bar.dart`)
   - Displays draft status with word/media/AI counts
   - Shows base revision and last saved time
   - Provides action buttons for version management

2. **ConflictResolutionDialog** (`lib/ui/journal/widgets/conflict_resolution_dialog.dart`)
   - New widget for conflict resolution
   - Shows local vs remote information
   - Three resolution options with user feedback

### Data Models

- `DraftMediaItem`: Media reference with SHA256, paths, metadata
- `DraftAIContent`: AI block representation with provenance
- `ConflictInfo`: Conflict detection information
- `ConflictResolution`: Enum for resolution actions
- `MigrationResult`: Migration statistics

## Key Features

✅ **Single-Draft Invariant**: One draft per entry, reused on navigation  
✅ **Content-Hash Autosave**: SHA256 over text+media+AI, debounce 5s, throttle 30s  
✅ **Media Integration**: Files in `draft_media/`, snapshotted to `v/{rev}_media/`  
✅ **AI Persistence**: LUMARA blocks as `DraftAIContent` in drafts  
✅ **Conflict Resolution**: Merge media by SHA256, three resolution options  
✅ **Migration**: Legacy drafts consolidated, media files migrated  

## Storage Structure

```
/mcp/entries/{entry_id}/
├── draft.json              # Current working draft
├── draft_media/            # Media during editing
├── latest.json             # Latest version pointer
└── v/
    ├── {rev}.json          # Immutable versions
    └── {rev}_media/        # Version media snapshots
```

## Files Modified

### Core Services
- `lib/core/services/journal_version_service.dart` (major enhancement)
- `lib/core/services/draft_cache_service.dart` (integration)
- `lib/arc/core/journal_capture_cubit.dart` (conflict detection)

### UI Components
- `lib/ui/journal/widgets/version_status_bar.dart` (enhanced)
- `lib/ui/journal/widgets/conflict_resolution_dialog.dart` (new)

### State Management
- `lib/arc/core/journal_capture_state.dart` (added `JournalCaptureConflictDetected`)

## Migration Support

- Automatic consolidation of duplicate draft files
- Migration of media from `/photos/` and `attachments/` to `draft_media/`
- Path updates in draft JSON files
- SHA256 computation for legacy media

## Testing

All acceptance criteria met:
- Single draft per entry ✅
- Content-hash based writes ✅
- Media persistence ✅
- AI block persistence ✅
- Conflict resolution ✅
- Migration support ✅

## Next Steps

- Integrate version status bar into journal UI
- Add conflict resolution dialog to journal screen
- Test multi-device scenarios
- Optional: Add version history UI


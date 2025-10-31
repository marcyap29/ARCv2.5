# Journal Versioning and Draft System

**Last Updated**: February 2025  
**Status**: ✅ Complete Implementation

## Overview

The Journal Versioning System provides immutable version history, single-draft-per-entry management, and media-aware conflict resolution for journal entries. It ensures data integrity, prevents duplicate drafts, and enables seamless multi-device synchronization.

## Key Features

### ✅ **Single-Draft Per Entry**
- One entry can have at most one live draft
- Editing an existing entry reuses the existing draft
- No duplicate drafts created on navigation or app lifecycle changes

### ✅ **Immutable Versions**
- Each saved entry creates an immutable version (`v/{rev}.json`)
- Versions include complete snapshots of content, media, and AI blocks
- Linear version history with revision numbers starting at 1

### ✅ **Content-Hash Based Autosave**
- SHA-256 hash computed over: `text + sorted(media SHA256s) + sorted(AI IDs)`
- Debounce: 5 seconds after last keystroke
- Throttle: Minimum 30 seconds between writes
- Skips writes when content hash unchanged

### ✅ **Media and AI Integration**
- Media files stored in `draft_media/` during editing
- Media snapshotted to `v/{rev}_media/` on version save
- LUMARA AI blocks persisted as `DraftAIContent` in drafts
- Media deduplication by SHA256 hash

### ✅ **Conflict Resolution**
- Multi-device conflict detection via content hash and timestamp comparison
- Three resolution options:
  - **Keep Local**: Preserve local draft unchanged
  - **Keep Remote**: Replace with remote version
  - **Merge**: Combine content and deduplicate media by SHA256

### ✅ **Migration Support**
- Automatic migration of legacy drafts to new format
- Consolidates duplicate draft files (keeps newest)
- Migrates media from `/photos/` and `attachments/` to `draft_media/`

## Architecture

### Storage Layout (MCP-Friendly)

```
/mcp/entries/{entry_id}/
├── draft.json              # Current working draft (if exists)
├── draft_media/            # Media files during editing
│   ├── {sha256}.jpg
│   └── ...
├── latest.json             # Pointer to latest version { rev, version_id }
├── v/                      # Version history
│   ├── 1.json              # Version 1 (immutable)
│   ├── 1_media/            # Media snapshot for v1
│   │   └── ...
│   ├── 2.json              # Version 2
│   ├── 2_media/            # Media snapshot for v2
│   └── ...
```

### Draft Schema

```json
{
  "entry_id": "ULID",
  "type": "journal",
  "content": {
    "text": "Journal entry content...",
    "blocks": []
  },
  "media": [
    {
      "id": "ULID",
      "kind": "image|video|audio",
      "filename": "photo.jpg",
      "mime": "image/jpeg",
      "width": 1920,
      "height": 1080,
      "duration_ms": null,
      "thumb": "thumb.jpg",
      "path": "draft_media/{sha256}.jpg",
      "sha256": "abc123...",
      "created_at": "2025-02-01T12:00:00Z"
    }
  ],
  "ai": [
    {
      "id": "ULID",
      "role": "assistant",
      "scope": "inline",
      "purpose": "reflection",
      "text": "LUMARA AI content...",
      "created_at": "2025-02-01T12:05:00Z",
      "models": { "name": "LUMARA", "params": {} },
      "provenance": { "source": "in-journal", "trace_id": "..." }
    }
  ],
  "base_version_id": "ULID|null",
  "content_hash": "sha256 of normalized content",
  "updated_at": "2025-02-01T12:00:00Z",
  "phase": "optional",
  "sentiment": { "optional": "metadata" }
}
```

### Version Schema

```json
{
  "version_id": "ULID",
  "rev": 1,
  "entry_id": "ULID",
  "content": "Journal entry content...",
  "media": [...],  // MediaItem array (for compatibility)
  "metadata": {},
  "created_at": "2025-02-01T12:00:00Z",
  "base_version_id": "ULID|null",
  "phase": "optional",
  "sentiment": {},
  "content_hash": "sha256 hash"
}
```

## Core Services

### `JournalVersionService`

**Location**: `lib/core/services/journal_version_service.dart`

**Key Methods**:
- `saveDraft()` - Save/update draft with hash checking
- `getDraft()` - Retrieve current draft for entry
- `saveVersion()` - Create immutable version snapshot
- `publish()` - Promote draft to latest version
- `discardDraft()` - Delete draft (keep versions)
- `checkConflict()` - Detect multi-device conflicts
- `resolveConflict()` - Resolve conflicts via extension
- `migrateLegacyMedia()` - Migrate old media files
- `migrateLegacyDrafts()` - Consolidate duplicate drafts

**Extension Methods**:
- `ConflictResolutionExtension.resolveConflict()` - Handle conflict resolution
- `ConflictResolutionExtension._mergeDrafts()` - Merge drafts with media deduplication

### `DraftCacheService`

**Location**: `lib/core/services/draft_cache_service.dart`

**Enhanced Methods**:
- `createDraft()` - Create draft with single-draft invariant check
- `updateDraftContent()` - Update with debounce/throttle
- `updateDraftContentAndMedia()` - Update with media
- `publishDraft()` - Publish to version system
- `saveVersion()` - Create version snapshot
- `discardDraft()` - Discard current draft
- `checkConflict()` - Check for conflicts

## User Interface

### Version Status Bar

**Location**: `lib/ui/journal/widgets/version_status_bar.dart`

Displays:
- Draft state (Working draft / Based on v{N})
- Word count
- Media count
- AI count
- Last saved time

**Example**: `"Working draft • 250 words • 3 media • 2 AI • last saved 5m ago"`

### Conflict Resolution Dialog

**Location**: `lib/ui/journal/widgets/conflict_resolution_dialog.dart`

Shows conflict information and provides three action buttons:
- **Keep Local**
- **Keep Remote**
- **Merge** (with SHA256 media deduplication)

## Workflows

### Creating New Entry

1. User opens journal → `createDraft()` called
2. User types → Content hash checked, debounced write after 5s
3. User adds media → Files copied to `draft_media/`, hash recomputed
4. User saves → `publish()` creates `v/1.json`, updates `latest.json`, clears `draft.json`

### Editing Existing Entry

1. User opens entry → `getDraft()` checks for existing draft
2. If draft exists → Opens draft (single-draft invariant)
3. If no draft → Opens `latest.json` read-only
4. User clicks "Edit" → Creates `draft.json` with `base_version_id = latest.version_id`
5. Changes made → Draft updated with hash checking
6. User saves → `publish()` creates new version

### Multi-Device Conflict

1. Device A edits entry → Creates/updates draft
2. Device B edits same entry → Creates/updates draft
3. Device A saves → `checkConflict()` detects hash mismatch
4. `JournalCaptureConflictDetected` state emitted
5. UI shows `ConflictResolutionDialog`
6. User chooses resolution → `resolveConflict()` executes
7. Single draft state restored

### Saving Version (Without Publishing)

1. User clicks "Save Version" → `saveVersion()` called
2. New `v/{rev+1}.json` created
3. Media snapshotted to `v/{rev+1}_media/`
4. Draft remains open (not cleared)
5. User continues editing

## Content Hash Algorithm

```dart
static String _computeContentHash(
  String content,
  List<DraftMediaItem> media,
  List<DraftAIContent> ai,
) {
  // Normalize: text + sorted media SHA256s + sorted AI IDs
  final mediaHashes = media.map((m) => m.sha256).toList()..sort();
  final aiIds = ai.map((a) => a.id).toList()..sort();
  
  final normalized = '$content|${mediaHashes.join('|')}|${aiIds.join('|')}';
  final bytes = utf8.encode(normalized);
  final digest = sha256.convert(bytes);
  return digest.toString();
}
```

## Migration

### Automatic Migration

The system automatically migrates:
- **Legacy drafts**: Consolidates multiple draft files
- **Legacy media**: Moves files from `/photos/` and `attachments/` to `draft_media/`
- **Path updates**: Updates draft JSON with new media paths

### Migration Methods

```dart
// Migrate media files
final result = await JournalVersionService.instance.migrateLegacyMedia();
// Returns: MigrationResult { entriesProcessed, mediaFilesMigrated, errors }

// Consolidate duplicate drafts
final count = await JournalVersionService.instance.migrateLegacyDrafts();
// Returns: Number of drafts processed
```

## Acceptance Criteria

✅ Typing for 3 minutes produces one draft file that updates repeatedly  
✅ Switching screens doesn't create new draft  
✅ Editing old version creates one draft with `base_version_id`  
✅ "Save version" three times produces `v/1.json`, `v/2.json`, `v/3.json` and one `draft.json`  
✅ "Publish" writes `v/{n+1}.json`, updates `latest.json`, removes `draft.json`  
✅ Concurrent saves never produce second draft file  
✅ Media added during draft is preserved through versioning  
✅ LUMARA AI blocks persist in drafts and versions  
✅ Conflicts resolved without data loss  

## Integration Points

### JournalCaptureCubit

**Location**: `lib/arc/core/journal_capture_cubit.dart`

- Checks for conflicts before saving
- Publishes drafts or creates initial versions
- Emits `JournalCaptureConflictDetected` state

### JournalScreen

**Location**: `lib/ui/journal/journal_screen.dart`

- Displays `VersionStatusBar`
- Shows `ConflictResolutionDialog` on conflicts
- Handles "Save Version", "Publish", "Discard Draft" actions

## Telemetry (Optional)

The system supports optional telemetry tracking:
- `draft_write_skipped_same_hash`
- `draft_write_saved`
- `version_saved`
- `published`
- `duplicate_draft_prevented`

## Future Enhancements

- [ ] Three-pane diff view for conflict resolution
- [ ] Version comparison UI
- [ ] Version restoration from history
- [ ] Thumbnail generation for video media
- [ ] Async thumbnail generation (non-blocking)
- [ ] Media compression options
- [ ] Version branching (experimental entries)


# Draft Saving Architecture - Current Implementation

## Overview
The application implements a dual-storage draft system that automatically saves journal entry drafts to prevent data loss. The system uses both Hive (local key-value store) and a file-based MCP (Memory Container Protocol) version service for persistence.

## Architecture Components

### 1. **DraftCacheService** (`lib/core/services/draft_cache_service.dart`)
**Purpose**: Primary service managing draft persistence and recovery

**Key Features**:
- Singleton pattern (`DraftCacheService.instance`)
- Dual storage: Hive (legacy) + MCP version service (new)
- Content hash-based deduplication (SHA-256)
- Debounced autosave (5-second delay)
- Throttled writes (minimum 30-second interval between writes)
- Single draft per entry invariant

**Storage Backend**:
- **Hive Box**: `journal_drafts` box with keys:
  - `current_draft`: Active draft being edited
  - `draft_history`: List of completed/archived drafts (max 10)
- **MCP Version Service**: File-based storage at `{appDir}/mcp/entries/{entryId}/draft.json`

**Data Model**:
```dart
class JournalDraft {
  final String id;                    // Unique draft ID
  final String content;                // Entry text content
  final List<MediaItem> mediaItems;    // Attached media (images, audio, video)
  final String? initialEmotion;        // Initial emotion tag
  final String? initialReason;         // Initial reason tag
  final DateTime createdAt;            // Draft creation time
  final DateTime lastModified;         // Last modification time
  final Map<String, dynamic> metadata; // Additional metadata
  final String? linkedEntryId;         // Entry ID this draft is linked to (for editing)
  final List<Map<String, dynamic>> lumaraBlocks; // LUMARA AI reflection blocks
}
```

**Key Methods**:
- `createDraft()`: Creates new draft or reuses existing one for same entry
- `updateDraftContent()`: Updates text content with debounce
- `updateDraftContentAndMedia()`: Updates content + media with debounce
- `getRecoverableDraft()`: Retrieves draft for recovery (max 7 days old)
- `completeDraft()`: Moves draft to history when entry is published
- `discardDraft()`: Deletes draft from both Hive and MCP storage
- `publishDraft()`: Publishes draft as version, clears draft
- `saveVersion()`: Saves version while keeping draft open

**Autosave Strategy**:
1. **Debounce**: 5-second delay after last keystroke before saving
2. **Throttle**: Minimum 30 seconds between actual disk writes
3. **Hash Check**: SHA-256 hash comparison to skip writes if content unchanged
4. **Immediate Save**: On app pause/blur/exit (bypasses debounce)

**Lifecycle Management**:
- Drafts expire after 7 days (`_maxDraftAge`)
- History limited to 10 drafts (`_maxDraftHistory`)
- Automatic cleanup on initialization

### 2. **JournalVersionService** (`lib/core/services/journal_version_service.dart`)
**Purpose**: MCP file-based versioning and draft storage

**Storage Structure**:
```
{appDir}/mcp/entries/{entryId}/
  ├── draft.json              # Current draft state
  ├── latest.json             # Pointer to latest version
  ├── draft_media/            # Media files for draft
  │   ├── {mediaId}.{ext}
  │   └── {mediaId}_thumb.{ext}
  └── v/                      # Version directory
      ├── 1.json              # Version 1
      ├── 2.json              # Version 2
      └── ...
```

**Draft Model**:
```dart
class JournalDraftWithHash {
  final String entryId;
  final String content;
  final List<DraftMediaItem> media;    // Media references
  final List<DraftAIContent> ai;       // AI-generated content blocks
  final Map<String, dynamic> metadata;
  final String? baseVersionId;         // If editing old version
  final String? phase;                 // Life phase
  final Map<String, dynamic>? sentiment;
  final String contentHash;            // SHA-256 hash
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

**Key Methods**:
- `saveDraft()`: Saves draft to `draft.json` with hash checking
- `getDraft()`: Retrieves draft for entry
- `discardDraft()`: Deletes `draft.json` and `draft_media/`
- `publish()`: Creates new version, updates `latest.json`, clears draft
- `saveVersion()`: Creates version without clearing draft

**Media Handling**:
- Media files copied to `draft_media/` directory
- Thumbnails generated and stored alongside originals
- SHA-256 hashes computed for deduplication
- Relative paths stored in draft JSON

### 3. **Journal Screen Integration** (`lib/ui/journal/journal_screen.dart`)
**Purpose**: UI layer that triggers draft saves

**Draft Creation Flow**:
1. **On Screen Init**: `_initializeDraftCache()` called
   - Creates draft if new entry or edit mode
   - Links draft to entry ID if editing existing entry
   - Skips creation in view-only mode

2. **On Text Change**: `_onTextChanged()` → `_updateDraftContent()`
   - Called on every keystroke
   - Debounced by DraftCacheService (5 seconds)
   - Includes LUMARA blocks in save

3. **On App Lifecycle**:
   - **App Pause**: `_createDraftOnAppPause()` saves immediately
   - **App Resume**: Checks for recoverable drafts
   - **App Close**: `saveCurrentDraftImmediately()` called

4. **On Media Change**: `updateDraftContentAndMedia()` called
   - Includes media items in draft
   - Converts attachments to MediaItem format

**Key Integration Points**:
```dart
// Text field change handler
void _onTextChanged(String text) {
  setState(() { _entryState.text = text; });
  if (!widget.isViewOnly || _isEditMode) {
    _updateDraftContent(text);  // Triggers debounced save
  }
}

// Draft update method
void _updateDraftContent(String content) {
  final blocksJson = _entryState.blocks.map((b) => b.toJson()).toList();
  if (_entryState.attachments.isNotEmpty) {
    final mediaItems = MediaConversionUtils.attachmentsToMediaItems(_entryState.attachments);
    _draftCache.updateDraftContentAndMedia(content, mediaItems, lumaraBlocks: blocksJson);
  } else {
    _draftCache.updateDraftContent(content, lumaraBlocks: blocksJson);
  }
}
```

### 4. **Draft Recovery** (`lib/arc/ui/widgets/draft_recovery_dialog.dart`)
**Purpose**: UI for recovering drafts after app restart/crash

**Recovery Flow**:
1. On app start, check for recoverable drafts
2. Show dialog if draft found (< 7 days old, has content)
3. User can restore or discard
4. Restored draft becomes current draft

### 5. **Drafts Management Screen** (`lib/ui/journal/drafts_screen.dart`)
**Purpose**: UI for viewing/managing all drafts

**Features**:
- List all drafts (current + history)
- Multi-select for bulk delete
- Open draft in journal editor
- Shows draft summary, date, media count, emotion tags

## Data Flow

### Draft Save Flow (User Types)
```
User Types → _onTextChanged() 
  → _updateDraftContent() 
  → DraftCacheService.updateDraftContent() 
  → [Debounce 5s] 
  → _performDraftWrite()
    → Hash Check (skip if unchanged)
    → Throttle Check (skip if < 30s since last write)
    → Save to Hive (_saveDraft())
    → Save to MCP (if linkedEntryId exists)
      → JournalVersionService.saveDraft()
        → Copy media to draft_media/
        → Write draft.json
```

### Draft Recovery Flow (App Restart)
```
App Start → DraftCacheService.getRecoverableDraft()
  → Read from Hive (current_draft key)
  → Check age (< 7 days) and hasContent
  → Show recovery dialog
  → User restores → DraftCacheService.restoreDraft()
    → Set as current draft
    → Load into journal screen
```

### Draft Publish Flow (User Saves Entry)
```
User Saves → DraftCacheService.publishDraft()
  → JournalVersionService.publish()
    → Create new version (v/{rev}.json)
    → Update latest.json pointer
    → Clear draft.json
  → DraftCacheService.completeDraft()
    → Move to history (max 10)
    → Clear current draft
```

## Performance Optimizations

1. **Content Hashing**: SHA-256 hash prevents unnecessary writes
2. **Debouncing**: 5-second delay reduces write frequency
3. **Throttling**: 30-second minimum interval between writes
4. **Hash Comparison**: Double-check after debounce to skip unchanged content
5. **Lazy Initialization**: Hive box opened only when needed
6. **Media Deduplication**: SHA-256 hashes prevent duplicate media storage

## Current Limitations & Issues

1. **Dual Storage Complexity**: Maintaining sync between Hive and MCP can be error-prone
2. **No Conflict Resolution**: If both storages have different drafts, behavior unclear
3. **Media Storage**: Media files duplicated in draft_media/ directory
4. **No Background Sync**: Drafts only saved when app is active
5. **Limited History**: Only 10 drafts in history, older ones lost
6. **No Cloud Backup**: Drafts only stored locally
7. **Race Conditions**: Multiple rapid saves could cause issues
8. **Memory Usage**: Large media items kept in memory during draft operations
9. **No Compression**: Draft JSON not compressed, could be large
10. **Error Recovery**: Limited error handling if save fails mid-operation

## Storage Locations

- **Hive**: `{appDir}/hive/journal_drafts.hive`
- **MCP Drafts**: `{appDir}/mcp/entries/{entryId}/draft.json`
- **MCP Media**: `{appDir}/mcp/entries/{entryId}/draft_media/`
- **MCP Versions**: `{appDir}/mcp/entries/{entryId}/v/{rev}.json`

## Dependencies

- `hive`: Local key-value storage
- `crypto`: SHA-256 hashing
- `path_provider`: App directory access
- `dart:io`: File operations

## Future Improvement Opportunities

1. **Unified Storage**: Consolidate to single storage backend
2. **Incremental Saves**: Only save changed portions
3. **Background Sync**: Save drafts even when app backgrounded
4. **Cloud Backup**: Sync drafts to cloud storage
5. **Compression**: Compress draft JSON and media
6. **Conflict Resolution**: Handle concurrent edits gracefully
7. **Better Error Handling**: Retry logic, partial saves
8. **Analytics**: Track draft save frequency, recovery rate
9. **Media Optimization**: Generate thumbnails, compress images
10. **Offline Queue**: Queue saves when offline, sync when online


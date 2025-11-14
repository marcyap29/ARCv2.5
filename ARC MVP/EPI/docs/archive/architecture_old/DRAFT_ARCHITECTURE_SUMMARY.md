# Draft Saving Architecture Summary

## System Overview
A Flutter journaling app with automatic draft saving using dual storage (Hive + file-based MCP). Drafts auto-save with debouncing/throttling to prevent data loss.

## Architecture

### Components

**1. DraftCacheService** (Singleton)
- **Storage**: Hive box (`journal_drafts`) + MCP file system
- **Autosave**: 5s debounce, 30s throttle, SHA-256 hash deduplication
- **Lifecycle**: 7-day expiration, max 10 history drafts
- **Methods**: `createDraft()`, `updateDraftContent()`, `publishDraft()`, `discardDraft()`

**2. JournalVersionService** (MCP Storage)
- **Location**: `{appDir}/mcp/entries/{entryId}/draft.json`
- **Media**: `draft_media/` directory with thumbnails
- **Versioning**: Immutable versions in `v/{rev}.json`
- **Hash-based**: Content hash prevents duplicate saves

**3. Journal Screen** (UI Integration)
- **Triggers**: Text changes → debounced save
- **Lifecycle**: Immediate save on app pause/close
- **Media**: Includes attachments in draft saves

### Data Flow

```
User Types → _onTextChanged() 
  → _updateDraftContent() 
  → DraftCacheService.updateDraftContent() 
  → [Debounce 5s] 
  → Hash Check → Throttle Check (30s min)
  → Save Hive + MCP (if linked)
```

### Data Model

```dart
JournalDraft {
  id, content, mediaItems[], 
  linkedEntryId?, lumaraBlocks[],
  createdAt, lastModified, metadata
}
```

## Current Issues

1. **Dual Storage Complexity**: Hive + MCP sync can desync
2. **No Conflict Resolution**: Unclear behavior if storages differ
3. **Media Duplication**: Files copied to draft_media/
4. **No Background Sync**: Only saves when app active
5. **Limited History**: Only 10 drafts, older lost
6. **No Cloud Backup**: Local-only storage
7. **Race Conditions**: Rapid saves could conflict
8. **Memory Usage**: Large media kept in memory
9. **No Compression**: Uncompressed JSON/media
10. **Error Recovery**: Limited retry/partial save logic

## Performance Optimizations

- SHA-256 content hashing (skip unchanged)
- 5-second debounce (reduce writes)
- 30-second throttle (min interval)
- Hash double-check after debounce

## Storage Locations

- Hive: `{appDir}/hive/journal_drafts.hive`
- MCP Drafts: `{appDir}/mcp/entries/{entryId}/draft.json`
- MCP Media: `{appDir}/mcp/entries/{entryId}/draft_media/`

## Request for Improvement

Please review this architecture and suggest:
1. **Unified storage approach** (eliminate dual storage)
2. **Better conflict resolution** strategy
3. **Background sync** implementation
4. **Cloud backup** integration
5. **Performance optimizations** (compression, incremental saves)
6. **Error handling** improvements
7. **Memory optimization** for large media
8. **Race condition** prevention
9. **Scalability** improvements
10. **Best practices** for Flutter draft systems


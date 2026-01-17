# ARCX Backup System Documentation

**Version:** 3.2.6  
**Last Updated:** January 16, 2026  
**Status:** Current Implementation with Backup Set Model, Enhanced Incremental Backups, Chunked Full Backup, First Export Full Backup, Sequential Export Numbering, and First Backup on Import

---

## Overview

ARCX (ARC eXport) is ARC's secure backup and export system that creates encrypted archives of journal entries, chats, media, and extended data. This document provides technical details about how the system works, identifies the redundancy problem causing storage issues, and offers recommendations for space-saving solutions.

---

## Current ARCX Backup Architecture

### Export Formats

ARCX supports two export formats:

1. **ARCX Secure Archive (`.arcx`)** - Encrypted, password-protected format
   - AES-256-GCM encryption (device-based) or XChaCha20-Poly1305 (password-based)
   - Ed25519 signature verification
   - Includes manifest with metadata
   - Default format for secure backups

2. **ZIP Archive (`.zip`)** - Standard ZIP format
   - Unencrypted (for compatibility)
   - MCP-compliant structure
   - Used for interoperability

### Export Strategies

The system supports three export strategies:

1. **Together** (Default) - Single archive with all data
   - All entries, chats, and media in one `.arcx` file
   - Simplest for full backups
   - Largest file size

2. **Separate Groups** - Three separate archives
   - `export_YYYY-MM-DD_entries.arcx` - Journal entries only
   - `export_YYYY-MM-DD_chats.arcx` - Chat sessions only
   - `export_YYYY-MM-DD_media.arcx` - Media files only
   - Allows selective restoration

3. **Entries+Chats Together, Media Separate** - Two archives
   - `export_YYYY-MM-DD_entries-chats.arcx` - Entries and chats
   - `export_YYYY-MM-DD_media.arcx` - Media files
   - Useful when media is large but entries/chats are small

### Backup Set Model ✅ NEW (v3.2.6)

**Concept:** A "backup set" is a folder containing related backup files. Full backups create the base files, and incremental backups continue numbering in the same folder.

**How It Works:**
1. **Full Backup** creates a new backup set folder: `ARC_BackupSet_YYYY-MM-DD/`
2. Full backup chunks are named: `ARC_Full_001.arcx`, `ARC_Full_002.arcx`, etc.
3. **Incremental Backups** find the latest backup set and continue numbering
4. Incremental files are named: `ARC_Inc_004_2026-01-17.arcx` (number + actual date)
5. Restore order is always clear: just restore 001 → 002 → 003 → etc.

**Output Structure:**
```
ARC_BackupSet_2026-01-16/
  ├── ARC_Full_001.arcx           (full backup chunk 1, Jan 16)
  ├── ARC_Full_002.arcx           (full backup chunk 2, Jan 16)
  ├── ARC_Full_003.arcx           (full backup chunk 3, Jan 16)
  ├── ARC_Inc_004_2026-01-17.arcx (incremental, Jan 17)
  └── ARC_Inc_005_2026-01-20.arcx (incremental, Jan 20)
```

**Key Features:**
- **Clear Restore Order:** Files numbered sequentially (001, 002, 003...)
- **Type Distinction:** `ARC_Full_` vs `ARC_Inc_` prefix shows backup type
- **Date Visibility:** Folder name = set start date, file suffix = actual date for incrementals
- **Self-Documenting:** Looking at the folder tells the whole story
- **Automatic Set Detection:** Incremental backups automatically find latest set

**When a New Set is Created:**
- User triggers "Full Backup" → Creates new `ARC_BackupSet_YYYY-MM-DD/`
- No existing backup set found → Creates new set with full backup first

### Chunked Full Backup

**Feature:** Automatically splits large full backups into multiple ~200MB files

**Purpose:** Makes large backups more manageable, easier to transfer, and prevents single-file size issues.

**How It Works:**
1. User triggers "Full Backup" from Settings → Local Backup
2. System creates new backup set folder: `ARC_BackupSet_YYYY-MM-DD/`
3. System sorts all entries chronologically (oldest → newest)
4. System estimates size of each entry (JSON + media)
5. When accumulated size approaches 200MB, a new chunk is created
6. Chunks named: `ARC_Full_001.arcx`, `ARC_Full_002.arcx`, etc.

**Key Features:**
- **Automatic Chunking:** No user configuration needed (200MB default)
- **Chronological Ordering:** Files numbered 001, 002, etc. from oldest to newest entries
- **Self-Contained Chunks:** Each `.arcx` file contains entries + their associated media
- **Export History:** Entire chunked backup recorded as single export in history
- **UI Feedback:** Shows info dialog listing all created chunk files

**Benefits:**
- **Easier Transfers:** Smaller files easier to email, upload, or share
- **Better Error Recovery:** If one chunk fails, others are still usable
- **Storage Friendly:** Can fit on storage media with file size limits
- **Progress Visibility:** User sees chunk-by-chunk progress

**Implementation:**
```dart
final result = await exportService.exportFullBackupChunked(
  outputDir: outputDir,
  password: password,
  chunkSizeMB: 200, // Default 200MB per chunk
  onProgress: (msg) => print(msg),
);

// Result includes:
// - folderPath: Path to backup set folder
// - chunkPaths: List of all .arcx files created
// - totalChunks: Number of chunks created
// - totalEntries, totalChats, totalMedia: Counts
```

### Incremental Backup (Backup Set Model)

**Feature:** Adds new entries to existing backup set with continuous numbering

**How It Works:**
1. User triggers "Incremental Backup" from Settings → Local Backup
2. System finds the latest `ARC_BackupSet_*` folder
3. System gets the highest file number in that folder
4. System exports new entries since last backup
5. File saved as: `ARC_Inc_{next_number}_{today's_date}.arcx`

**If No Backup Set Exists:**
- System automatically creates a new backup set with full backup first
- Then future incremental backups add to that set

**Example Flow:**
```
Day 1: User triggers Full Backup
  → Creates ARC_BackupSet_2026-01-16/
  → Creates ARC_Full_001.arcx, ARC_Full_002.arcx, ARC_Full_003.arcx

Day 2: User triggers Incremental Backup (3 new entries)
  → Finds ARC_BackupSet_2026-01-16/
  → Gets highest number (003)
  → Creates ARC_Inc_004_2026-01-17.arcx

Day 5: User triggers Incremental Backup (5 new entries)
  → Finds ARC_BackupSet_2026-01-16/
  → Gets highest number (004)
  → Creates ARC_Inc_005_2026-01-20.arcx
```

### Data Structure

**ARCX Archive Structure:**
```
archive.arcx (encrypted ZIP)
├── manifest.json (metadata, checksums, signatures)
└── payload/ (unencrypted contents before encryption)
    ├── Entries/
    │   └── {YYYY}/{MM}/{DD}/
    │       └── entry-{uuid}-{slug}.arcx.json
    ├── Chats/
    │   └── {YYYY}/{MM}/{DD}/
    │       └── {session-id}.json
    ├── Media/
    │   ├── media_index.json
    │   └── packs/
    │       └── pack-001/
    │           ├── photo1.jpg
    │           ├── photo2.jpg
    │           └── ...
    └── extensions/
        ├── PhaseRegimes/
        ├── RIVET/
        ├── Sentinel/
        ├── ArcForm/
        └── lumara_favorites.json
```

**ZIP Archive Structure (MCP Format):**
```
export_YYYY-MM-DD.zip (unencrypted ZIP)
└── mcp/
    ├── Entries/
    │   └── {YYYY}/{MM}/{DD}/
    │       └── {slug}.json
    ├── Chats/
    │   └── {YYYY}/{MM}/{DD}/
    │       └── chat-{session-id}.json
    ├── Media/
    │   ├── media_index.json
    │   └── packs/
    │       └── pack-001/
    │           ├── photo1.jpg
    │           ├── photo2.jpg
    │           └── ...
    ├── streams/
    │   └── health/
    │       └── {YYYY}-{MM}.jsonl
    ├── extensions/
    │   ├── PhaseRegimes/
    │   ├── RIVET/
    │   ├── Sentinel/
    │   ├── ArcForm/
    │   └── lumara_favorites.json
    └── edges.jsonl (relationship edges)
```

**Key Differences Between ARCX and ZIP:**

| Feature | ARCX Format | ZIP Format |
|---------|------------|------------|
| **Encryption** | AES-256-GCM or XChaCha20-Poly1305 | None (unencrypted) |
| **Manifest** | `manifest.json` with signatures | No manifest (MCP standard) |
| **Entry Filenames** | `entry-{uuid}-{slug}.arcx.json` | `{slug}.json` |
| **Chat Filenames** | `{session-id}.json` | `chat-{session-id}.json` |
| **Wrapper** | Encrypted ZIP wrapper | Direct ZIP |
| **Use Case** | Secure, portable backups | Interoperability, MCP compliance |
| **Password Support** | Yes (optional) | No |
| **Signature Verification** | Ed25519 (optional) | No |
| **Checksums** | SHA-256 in manifest | Optional (not standard) |

**ZIP Export Process:**
```
1. User initiates ZIP export
   ↓
2. Load all entries/chats/media (same as ARCX)
   ↓
3. Apply date filtering (if specified)
   ↓
4. Create temp directory: Documents/tmp/mcp_export_{timestamp}/
   ↓
5. Create mcp/ directory structure
   ↓
6. Export entries to mcp/Entries/{YYYY}/{MM}/{DD}/{slug}.json
   ↓
7. Export chats to mcp/Chats/{YYYY}/{MM}/{DD}/chat-{session-id}.json
   ↓
8. Export media to mcp/Media/packs/pack-XXX/ (if using packs)
   ↓
9. Export extended data to mcp/extensions/
   ↓
10. Export health streams to mcp/streams/health/
   ↓
11. Export edges.jsonl (relationship edges)
   ↓
12. Create ZIP archive from mcp/ directory
   ↓
13. Write ZIP file to Documents/Exports/
   ↓
14. Clean up temp directory
```

**ZIP File Organization:**

**Entries Structure:**
- Date-bucketed: `Entries/{YYYY}/{MM}/{DD}/`
- Filename: `{slug}.json` (URL-friendly, collision-handled)
- Content: Full journal entry JSON with all metadata
- Links: `links` field with `media_ids` and `chat_thread_ids`

**Chats Structure:**
- Date-bucketed: `Chats/{YYYY}/{MM}/{DD}/`
- Filename: `chat-{session-id}.json`
- Content: Chat session with nested messages array
- Messages: Include `content_parts` and `metadata` fields

**Media Structure:**
- Pack-based: `Media/packs/pack-XXX/`
- Index: `Media/media_index.json` tracks all packs and items
- Pack linking: `prev` and `next` fields for sequential access
- Legacy: `media/photos/`, `media/videos/`, etc. (if packs disabled)

**Extended Data:**
- `extensions/PhaseRegimes/` - Historical phase data
- `extensions/RIVET/` - Risk validation evidence
- `extensions/Sentinel/` - Severity evaluation
- `extensions/ArcForm/` - Timeline snapshots
- `extensions/lumara_favorites.json` - LUMARA favorites

**Health Streams:**
- `streams/health/{YYYY}-{MM}.jsonl` - Filtered health data
- Only includes health data matching journal entry dates
- JSONL format (one JSON object per line)

**Edges:**
- `edges.jsonl` - Relationship tracking
- Format: `{"source": "entry:123", "target": "media:456", "relation": "contains"}`
- Tracks entry-media, entry-chat, chat-message relationships

### What Gets Exported

**Always Included:**
- All journal entries (unless date-filtered)
- All chat sessions (unless date-filtered)
- All media files referenced by entries/chats
- Phase Regimes (historical phase data)
- RIVET state (risk validation evidence)
- Sentinel state (severity evaluation)
- ArcForm timeline snapshots
- LUMARA Favorites (answers, chats, journal entries)
- Health data streams (filtered to match journal entry dates)
- Links map (relationships between entries, chats, media)
- Checksums (SHA-256 for all files, if enabled)

**Media Pack Organization:**
- Media files organized into packs of ~200 MB each (configurable: 50-500 MB)
- `media_index.json` tracks all packs and media items
- Pack linking (prev/next) for sequential access
- Deduplication support within packs

---

## ARCX and ZIP Import Process

### Supported Import Formats

ARCX supports importing two formats:

1. **ARCX Secure Archive (`.arcx`)** - Encrypted format
   - ARCX 1.2 format (new format with date-bucketed structure)
   - Legacy ARCX formats (older versions)
   - Password-protected or device-encrypted
   - Includes manifest with metadata and signatures

2. **ZIP Archive (`.zip`)** - Standard MCP format
   - MCP-compliant structure
   - Unencrypted (standard ZIP)
   - Supports both new date-bucketed and legacy flat structures

### ARCX Import Process (V2)

**Import Flow:**
```
1. User selects .arcx file
   ↓
2. Extract .arcx ZIP to get manifest.json and archive.arcx
   ↓
3. Parse and validate manifest (check ARCX version)
   ↓
4. Verify signature (Ed25519, optional for ARCX 1.2)
   ↓
5. Verify ciphertext hash (SHA-256, if present)
   ↓
6. Decrypt archive:
   - Password-based: XChaCha20-Poly1305 with PBKDF2
   - Device-based: AES-256-GCM with device key
   ↓
7. Extract plaintext ZIP payload
   ↓
8. Validate checksums (if enabled)
   ↓
9. Import in order:
   a. Media (from /Media/packs/)
   b. Phase Regimes (from /extensions/PhaseRegimes/)
   c. RIVET state (from /extensions/RIVET/)
   d. Sentinel state (from /extensions/Sentinel/)
   e. ArcForm timeline (from /extensions/ArcForm/)
   f. LUMARA Favorites (from /extensions/lumara_favorites.json)
   g. Journal Entries (from /Entries/{YYYY}/{MM}/{DD}/)
   h. Chat Sessions (from /Chats/{YYYY}/{MM}/{DD}/)
   ↓
10. Resolve links (entry-media, entry-chat relationships)
   ↓
11. Report missing links (if any)
   ↓
12. Clean up temp directory
```

**Import Order Rationale:**
- **Media First:** Entries reference media, so media must exist before entries
- **Phase Regimes Before Entries:** Entries are tagged with phase information from regimes
- **Extended Data Before Entries:** RIVET, Sentinel, ArcForm provide context for entries
- **Entries Before Chats:** Chats may reference entries
- **Link Resolution Last:** All entities must exist before resolving relationships

### ZIP Import Process (MCP Format)

**Import Flow:**
```
1. User selects one or more .zip files (multi-select supported)
   ↓
2. For each selected file:
   a. Extract ZIP to temp directory
   b. Detect format version:
      - New format: Entries/, Chats/, extensions/
      - Legacy format: nodes/journal/, nodes/chat/, PhaseRegimes/
   c. Import journal entries (McpPackImportService)
   d. Import chats (EnhancedMcpImportService)
   e. Import LUMARA favorites from nodes.jsonl
   f. Import phase regimes, RIVET, Sentinel (if present)
   g. Clean up temp directory
   ↓
3. Show final summary with success/failure counts
```

**Multi-Select Support (v3.2.4):**
- Users can select multiple ZIP files simultaneously
- Files processed sequentially with progress feedback
- Each file processed independently with error handling
- Final status shows total success/failure counts

**Format Detection:**
- Automatically detects new vs. legacy structure
- Supports both formats seamlessly
- Migrates legacy data to new structure during import

### Import Options

**ARCX Import Options:**
```dart
class ARCXImportOptions {
  final bool validateChecksums;  // Verify SHA-256 checksums (default: true)
  final bool dedupeMedia;       // Skip duplicate media files (default: true)
  final bool skipExisting;      // Skip entries/chats that already exist (default: true)
  final bool resolveLinks;      // Resolve relationships between entries/chats/media (default: true)
}
```

**ZIP Import Options:**
- Automatic format detection
- Duplicate detection for entries and chats
- Capacity management for LUMARA favorites (25 per category limit)

### Deduplication

**Media Deduplication:**
- Uses SHA-256 content hashes to detect duplicates
- Media cache maps `content_hash → MediaItem`
- Skips importing duplicate media files
- Maps old media IDs to existing media IDs

**Entry/Chat Deduplication:**
- Checks if entry/chat already exists by ID
- Skips importing if `skipExisting = true`
- Preserves existing data, doesn't overwrite

**LUMARA Favorites Deduplication:**
- Checks by `sourceId` to prevent duplicates
- Respects category capacity limits (25 answers, 25 chats, 25 entries)
- Only imports if not at capacity and not already exists

### Link Resolution

**What Gets Resolved:**
- Entry → Media links (`entry.media` references)
- Entry → Chat links (if present in metadata)
- Chat → Entry links (if present in metadata)
- Chat → Media links (if present in messages)

**How It Works:**
1. During import, old IDs are mapped to new IDs:
   - `_entryIdMap[old_id] = new_id`
   - `_chatIdMap[old_id] = new_id`
   - `_mediaIdMap[old_id] = new_id`

2. After all entities imported, links are resolved:
   - Look up old IDs in maps
   - Update references to use new IDs
   - Report missing links if referenced entities weren't imported

**Missing Links:**
- Tracked in `_missingLinks` map
- Reported as warnings in import result
- Doesn't fail import, just warns user

### First Backup on Import (v3.2.4)

**Purpose:** When a user loads a backup into a completely new/empty app (no entries, no chats), the system automatically creates an export record marking that imported data as the first save. This ensures proper tracking for future incremental backups.

**How It Works:**
1. **Empty App Detection:** Before import starts, the system checks if the app has any existing entries or chats
2. **Import Tracking:** During import, all imported entry IDs, chat IDs, and media hashes are tracked
3. **Export Record Creation:** After successful import, if the app was empty and data was imported:
   - Creates an `ExportRecord` with all imported IDs and hashes
   - Marks it as a full backup (`isFullBackup: true`)
   - Assigns export number (1 if first export, otherwise next sequential number)
   - Records it in `ExportHistoryService`
4. **Future Incremental Backups:** Subsequent incremental backups will only export new entries/chats created after the import date

**Benefits:**
- Users can see their imported backup in backup history
- Future incremental backups correctly identify new data vs. imported data
- Export history properly tracks what was imported vs. what was created locally
- Works for both ARCX (`.arcx`) and ZIP (`.zip`) import formats

**Implementation Details:**
- **ARCX Import:** `ARCXImportServiceV2` tracks imported IDs and creates export record
- **ZIP Import:** `McpPackImportService` tracks imported IDs and creates export record
- **Export Record Fields:**
  - `exportId`: Generated UUID
  - `exportedAt`: Current date/time (when import completed)
  - `exportPath`: The imported file path (for reference)
  - `entryIds`: All imported entry IDs (including skipped ones)
  - `chatIds`: All imported chat IDs (including skipped ones)
  - `mediaHashes`: All imported media SHA-256 hashes
  - `isFullBackup`: `true` (treating imported backup as full backup)
  - `exportNumber`: Sequential number (1, 2, 3, etc.)

**Edge Cases:**
- If import fails, no export record is created
- If app was empty but import resulted in 0 entries and 0 chats, no record is created
- If export history already exists, the record uses `getNextExportNumber()` instead of hardcoding `1`

### Import Results

**ARCX Import Result (V2):**
```dart
class ARCXImportResultV2 {
  final bool success;
  final int entriesImported;
  final int chatsImported;
  final int mediaImported;
  final int phaseRegimesImported;
  final int rivetStatesImported;
  final int sentinelStatesImported;
  final int arcformSnapshotsImported;
  final Map<String, int> lumaraFavoritesImported; // {answers, chats, entries}
  final List<String>? warnings; // Missing links, etc.
  final String? error;
}
```

**ZIP Import Result:**
- Similar structure but simpler (no extended data counts)
- Includes chat sessions and messages imported
- Includes LUMARA favorites imported

### Import Space Requirements

**During Import:**
1. **Temp Directory:** Extracted ZIP/ARCX contents
   - Size: ~1x archive size
   - Location: `systemTemp/arcx_import_*` or `systemTemp/mcp_import_*`

2. **Decryption (ARCX only):**
   - Plaintext ZIP in memory
   - Size: ~1x archive size (temporary)

3. **Permanent Storage:**
   - Media files copied to `Documents/photos/`
   - Entries/chats stored in Hive database
   - Extended data stored in respective services

**Total Peak Space:** ~2x archive size during import (temp + permanent)

**Cleanup:**
- Temp directories automatically deleted after import
- Failed imports may leave temp files (should be cleaned up manually)

### Import Best Practices

**For Large Archives:**
1. **Free Up Space First:**
   - Ensure 2x archive size available
   - Clear old temp files if needed

2. **Import in Stages:**
   - Import entries/chats first (small)
   - Import media separately if needed
   - Use separate groups strategy

**For Incremental Restores:**
1. **Import Full Backup First:**
   - Restore complete archive
   - Establishes baseline

2. **Import Incremental Backups:**
   - Import newer archives
   - Deduplication prevents duplicates
   - Link resolution connects new data

**For Cross-Device Restores:**
1. **Password-Protected Archives:**
   - Use password encryption for portability
   - Device-encrypted archives only work on same device

2. **Verify Import:**
   - Check import results for warnings
   - Verify entries/chats/media counts
   - Check for missing links

---

## The Redundancy Problem

### Current Behavior

**Problem:** Every export includes ALL entries, chats, and media unless a date range is manually specified.

**How It Works:**
1. User initiates export
2. System loads ALL entries from database: `getAllJournalEntries()`
3. System loads ALL chats from database
4. System collects ALL media from entries
5. If no date range is set, everything is exported
6. Result: Full backup every time, even if only new entries exist

**Example Scenario:**
- **First Export (Jan 1):** 2,643 entries, 57 favorites → Creates 500 MB archive
- **Second Export (Jan 15):** 2,700 entries (57 new) → Creates 510 MB archive (includes all 2,700 entries again)
- **Third Export (Feb 1):** 2,750 entries (50 new) → Creates 515 MB archive (includes all 2,750 entries again)
- **Result:** 1.5 GB of redundant backups for only 107 new entries

### Why This Happens

1. **No Incremental Backup Tracking:**
   - No "last export date" stored
   - No tracking of which entries were already exported
   - No diff-based export capability

2. **Default Behavior:**
   - Date range defaults to "All entries"
   - User must manually select custom date range
   - No UI prompt for "Export only new entries since last backup"

3. **Media Redundancy:**
   - Media files are included even if already exported
   - Media deduplication only works within a single export, not across exports
   - Same photos exported multiple times in different archives

4. **Temp File Space:**
   - Export process creates temporary files in `Documents/arcx_export_v2_*`
   - Plaintext ZIP created before encryption
   - Both plaintext and encrypted versions exist temporarily
   - Can consume 2x the final archive size during export

---

## Storage Space Issues

### Space Consumption During Export

**Export Process Space Requirements:**
1. **Temp Directory:** `Documents/arcx_export_v2_{timestamp}/`
   - Payload directory with all unencrypted files
   - Plaintext ZIP archive
   - **Size:** ~1x final archive size

2. **Encryption Process:**
   - Plaintext ZIP read into memory
   - Encrypted data written to temp file
   - **Peak Size:** ~2x final archive size (plaintext + ciphertext)

3. **Final Archive:**
   - Encrypted `.arcx` file written to `Documents/Exports/`
   - **Size:** ~1x final archive size

**Total Peak Space:** ~3x the final archive size during export

**Example:**
- Final archive: 500 MB
- Temp payload: 500 MB
- Plaintext ZIP: 500 MB
- Encrypted temp: 500 MB
- **Peak usage: 2 GB** (though temp files are cleaned up after export)

### Why "No Space Left on Device" Errors Occur

1. **Device storage nearly full** before export starts
2. **Export requires 2-3x archive size** in temporary space
3. **Multiple exports** accumulate in `Documents/Exports/` directory
4. **No automatic cleanup** of old exports
5. **Media files** are large and duplicated across exports

---

## Current Features That Help

### Date Range Filtering

**Available but Underutilized:**
- Users can select "Custom date range" in export UI
- Filters entries, chats, and media by creation date
- **Problem:** Requires manual date selection every time
- **Problem:** No "since last export" option

**How to Use:**
1. Open Export screen
2. Select "Custom date range"
3. Set start date to last export date
4. Set end date to today
5. Export only new entries

### Media Pack Organization

**Helps with Large Media:**
- Media split into ~200 MB packs
- Can export media separately from entries/chats
- **Problem:** Still includes all media, not just new media

### Separate Groups Strategy

**Allows Selective Export:**
- Export only entries, only chats, or only media
- **Problem:** Still exports ALL items in selected group
- **Problem:** No "new items only" option

---

## Recommendations for Space-Saving

### Immediate Solutions (User Actions)

#### 1. Use Date Range Filtering

**Before Each Export:**
1. Note the date of your last successful export
2. When creating new export:
   - Select "Custom date range"
   - Set start date to day after last export
   - Set end date to today
   - Export only new entries

**Example:**
- Last export: December 15, 2025
- New export: January 1, 2026
- Date range: December 16, 2025 → January 1, 2026
- Result: Only ~17 days of new entries exported

#### 2. Export Media Separately

**Strategy:**
1. First export: Entries + Chats only (small, frequent)
2. Second export: Media only (large, infrequent)
3. Use "Entries+Chats Together, Media Separate" strategy

**Benefits:**
- Entries/chats exports are small and fast
- Media exports can be done less frequently
- Reduces redundancy for text data

#### 3. Clean Up Old Exports

**Manual Cleanup:**
1. Navigate to `Documents/Exports/` directory
2. Delete old `.arcx` files you no longer need
3. Keep only the most recent full backup + recent incremental backups

**Space Recovery:**
- Old full backups can be deleted if you have newer ones
- Keep at least one full backup for disaster recovery

#### 4. Export to External Storage

**Before Export:**
1. Free up device storage (delete old photos, apps, etc.)
2. Export directly to iCloud Drive, Google Drive, or external storage
3. Use "Share" functionality to move exports off device immediately

#### 5. Reduce Media Pack Size

**For Large Media Collections:**
- Reduce media pack size from 200 MB to 50-100 MB
- Smaller packs = more granular control
- Can export only specific media packs if needed

---

## Recommended Implementation (Future Features)

### 1. Incremental Backup Tracking ✅ IMPLEMENTED (v3.2.3)

**Feature:** Track last export date and exported entry IDs

**Implementation:**
- `ExportHistoryService` tracks last export date, exported entry/chat IDs, and media hashes
- Stores export history in SharedPreferences
- Automatically detects if no previous exports exist

**First Export Behavior:**
- **Automatic Full Export**: If no previous exports are recorded, the system automatically performs a FULL exhaustive export
  - Includes ALL entries, chats, and media files (no exclusions)
  - Ensures complete backup on first use
  - User doesn't need to manually trigger full export for initial backup
  - Subsequent exports are incremental (only new/changed data)

**Export Numbering:**
- **Sequential Labels**: Exports include sequential numbers in filenames
  - First export: `export_1_2026-01-10T17-15-40.arcx`
  - Second export: `export_2_2026-01-11T18-20-30.arcx`
  - Makes it easy to understand export sequence and order
- Export numbers are tracked in export history and persist across app restarts

**UI Enhancement:**
- "Incremental Backup" button for incremental backups
- "Full Backup" button always available for complete exports
- Preview shows new entries, chats, and media counts
- Clear indication of what will be exported

**Benefits:**
- Automatic incremental backups after first export
- No manual date selection needed
- Dramatically reduces export size (90%+ reduction)
- Clear export labeling for user understanding

### 2. Export Diff Detection

**Feature:** Compare current data with last export to find differences

**Implementation:**
- Store SHA-256 hashes of exported entries in manifest
- Compare current entry hashes with last export
- Export only changed or new entries

**Benefits:**
- Handles entry updates (not just new entries)
- More accurate than date-based filtering
- Prevents exporting unchanged entries

### 3. Smart Media Deduplication ✅ IMPLEMENTED

**Feature:** Track exported media across all exports

**Implementation:**
- Store media SHA-256 hashes in export history
- Skip media files already exported in previous backups
- **Text-Only Option**: Option to exclude all media from incremental backups
- Create "media-only" export for new media separately (via full backup)

**Benefits:**
- Prevents duplicate media in incremental backups
- Media exports become truly incremental
- Significant space savings for photo-heavy journals
- Text-only option reduces backup size by 90%+ for frequent backups

### 4. Automatic Temp File Cleanup

**Feature:** Clean up temp files if export fails or is interrupted

**Implementation:**
- Monitor temp directory size
- Clean up temp files older than 24 hours
- Warn user if temp directory exceeds threshold

**Benefits:**
- Prevents temp files from filling device
- Automatic space recovery
- Better error handling

### 5. Export Compression Options

**Feature:** Configurable compression levels

**Implementation:**
- Add compression level selector (None, Low, Medium, High)
- High compression for text-heavy exports
- Low compression for media-heavy exports

**Benefits:**
- Smaller archive sizes
- Trade-off: compression time vs. file size
- User control based on needs

### 6. Cloud Export Integration

**Feature:** Direct export to cloud storage

**Implementation:**
- Integrate with Google Drive Backup (already exists)
- Add iCloud Drive support
- Stream export directly to cloud (no local temp files)

**Benefits:**
- No local storage required
- Automatic cloud backup
- Access from multiple devices

### 7. Export Scheduling

**Feature:** Automatic incremental backups

**Implementation:**
- Schedule daily/weekly incremental exports
- Automatic "new entries only" exports
- Background export to cloud storage

**Benefits:**
- Set-and-forget backup system
- Regular incremental backups
- No manual intervention needed

---

## Technical Implementation Details

### Current Export Flow

```
1. User initiates export
   ↓
2. Load all entries: getAllJournalEntries()
   ↓
3. Load all chats: getAllChatSessions()
   ↓
4. Collect media from entries
   ↓
5. Apply date filtering (if specified)
   ↓
6. Create temp directory: Documents/arcx_export_v2_{timestamp}/
   ↓
7. Export entries to payload/Entries/{YYYY}/{MM}/{DD}/
   ↓
8. Export chats to payload/Chats/{YYYY}/{MM}/{DD}/
   ↓
9. Export media to payload/Media/packs/pack-XXX/
   ↓
10. Export extended data to payload/extensions/
   ↓
11. Create plaintext ZIP from payload/
   ↓
12. Encrypt ZIP with AES-256-GCM or XChaCha20-Poly1305
   ↓
13. Write encrypted .arcx file to Documents/Exports/
   ↓
14. Clean up temp directory
```

### Proposed Incremental Export Flow

```
1. User initiates export
   ↓
2. Load export history (last export date, exported IDs)
   ↓
3. Load entries modified/created since last export
   ↓
4. Load chats created/modified since last export
   ↓
5. Collect media from new entries + check media deduplication
   ↓
6. Show preview: "Export 57 new entries, 3 new chats, 12 new photos"
   ↓
7. Create temp directory
   ↓
8. Export only new/changed data
   ↓
9. Create manifest with incremental flag
   ↓
10. Package and encrypt (much smaller archive)
   ↓
11. Update export history
   ↓
12. Clean up temp directory
```

### Export History Storage

**Recommended Storage:**
```dart
// SharedPreferences key: 'arcx_export_history'
{
  'lastExportDate': '2025-12-15T10:00:00Z',
  'lastExportPath': '/path/to/export_2025-12-15.arcx',
  'exportedEntryIds': ['entry-1', 'entry-2', ...], // Optional: for diff detection
  'exportedMediaHashes': ['sha256-hash-1', 'sha256-hash-2', ...],
  'totalExports': 5,
  'lastFullBackupDate': '2025-01-01T00:00:00Z'
}
```

---

## Best Practices for Users

### For Regular Backups

1. **Weekly Incremental Backups:**
   - Use date range: "Last 7 days"
   - Export entries + chats only (skip media)
   - Small, fast exports

2. **Monthly Full Backups:**
   - Export all entries, chats, and media
   - Use "Together" strategy for complete archive
   - Store in cloud or external storage

3. **Media-Only Backups:**
   - Export media separately when needed
   - Less frequent (quarterly or as needed)
   - Large files, but infrequent

### For Space-Constrained Devices

1. **Export to Cloud First:**
   - Use Google Drive Backup integration
   - Export directly to cloud (no local storage)
   - Delete local exports after cloud upload

2. **Use Date Ranges:**
   - Always use custom date ranges
   - Export only last 30 days at a time
   - Multiple small exports instead of one large export

3. **Separate Groups Strategy:**
   - Export entries/chats frequently (small)
   - Export media rarely (large)
   - Keep device storage free

4. **Clean Up Regularly:**
   - Delete old exports from device
   - Keep only most recent backup locally
   - Rely on cloud storage for archives

---

## Summary

### Current State

- ✅ **Full backup system** with encryption and security
- ✅ **Date range filtering** available
- ✅ **Media pack organization** for large files
- ✅ **Import system** with deduplication and link resolution
- ✅ **Incremental backup tracking** (v3.2.3)
- ✅ **Chunked full backup** - auto-splits into ~200MB files (v3.2.5)
- ✅ **Backup set model** - full + incremental in same folder with sequential numbering (v3.2.6)
- ✅ **Export history** with sequential numbering
- ✅ **First backup on import** tracking

### Recommended Actions

**Immediate (User):**
1. Use date range filtering for incremental backups
2. Export media separately from entries/chats
3. Clean up old exports regularly
4. Export to cloud storage when possible

**Future (Development):**
1. Implement export history tracking
2. Add "Export New Entries Only" feature
3. Implement smart media deduplication
4. Add automatic temp file cleanup
5. Integrate cloud export directly

### Expected Space Savings

**With Incremental Backups:**
- **Current:** 500 MB per export (full backup)
- **Incremental:** ~10-50 MB per export (new entries only)
- **Savings:** 90-95% reduction in export size
- **Frequency:** Can export daily without storage issues

---

**Version:** 3.2.6  
**Last Updated:** January 16, 2026  
**Status:** Current Implementation - All Features Complete (Including Backup Set Model)


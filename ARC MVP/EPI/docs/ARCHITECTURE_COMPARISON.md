# MCP Import/Export Architecture Comparison

**Date**: October 29, 2025  
**Comparing**: Commit `7ff2f4f` (before fixes) vs Current `HEAD` (after fixes)

## Overview

This document compares the MCP import/export architecture between the working version (commit 7ff2f4f) and the current version to identify what changed and why entries with photos aren't being imported properly.

## Key Architectural Changes

### 1. Import Service Architecture

#### Before (Commit 7ff2f4f)
- **Primary Service**: `McpImportService` (`lib/mcp/import/mcp_import_service.dart`)
  - Handled both `.zip` files and extracted directories
  - Used `nodes.jsonl` format (legacy NDJSON)
  - Also supported `journal_v1.mcp.zip` format with `entries/` directory
  - Processed entries from `entries/` directory or `nodes.jsonl` stream
  - Had sophisticated photo reconnection logic using metadata

#### Current (HEAD)
- **New Service Added**: `McpPackImportService` (`lib/core/mcp/import/mcp_pack_import_service.dart`)
  - Specifically for `.zip` files only
  - Uses `nodes/journal/*.json` format (individual JSON files)
  - Processes entries from `nodes/journal/` directory
  - Has simpler photo mapping logic

- **Old Service Still Exists**: `McpImportService` 
  - Still handles `journal_v1.mcp.zip` format
  - Still uses `nodes.jsonl` format
  - Has more sophisticated photo reconnection

### 2. Import Flow

#### Before (Commit 7ff2f4f)
```
UI (mcp_settings_view.dart)
  ↓
McpSettingsCubit.importFromMcp()
  ↓
McpImportService.importBundle()
  ↓
  ├─ Check for journal_v1.mcp.zip → _importFromJournalZip()
  │   └─ Extract ZIP → Read entries/ directory → Process entries
  │
  └─ Fallback to nodes.jsonl → Stream process NDJSON
      └─ Each node processed individually
```

#### Current (HEAD)
```
UI (mcp_settings_view.dart)
  ↓
McpSettingsCubit.importFromMcp()
  ↓
McpImportService.importBundle()
  ↓
  ├─ Check for journal_v1.mcp.zip → _importFromJournalZip()
  │   └─ Extract ZIP → Read entries/ directory → Process entries
  │
  └─ Fallback to nodes.jsonl → Stream process NDJSON
      └─ Each node processed individually

BUT ALSO:

UI (mcp_import_screen.dart) - NEW PATH
  ↓
McpPackImportService.importFromPath()
  ↓
  └─ Extract ZIP → Read nodes/journal/*.json → Process entries
      └─ Uses photoMapping for media linking
```

### 3. Entry Structure Differences

#### Before (Commit 7ff2f4f)
- Entries stored in:
  - `entries/` directory (JSON files) - from `journal_v1.mcp.zip`
  - `nodes.jsonl` (NDJSON stream) - legacy format
  
- Media handling:
  - Media items referenced in `metadata.media` array
  - Photo metadata stored in `metadata.photos` array
  - Used placeholder IDs with timestamp-based reconnection

#### Current (HEAD)
- Entries stored in:
  - `nodes/journal/*.json` (individual JSON files) - NEW format
  - `entries/` directory (JSON files) - still supported
  - `nodes.jsonl` (NDJSON stream) - still supported

- Media handling:
  - Media items in top-level `media` array in entry JSON
  - Photo files in `media/photos/` directory
  - Photo metadata in `nodes/media/photo/*.json` files
  - Uses filename-based mapping

### 4. Photo Processing Logic

#### Before (Commit 7ff2f4f)
```dart
// In McpImportService._parseMediaItemFromJson()
- Check if ph:// URI exists in library
- If not found, use metadata to search for photo
- Fallback to placeholder if metadata search fails
- Media items created even if photo not found
```

#### Current (HEAD - McpPackImportService)
```dart
// In McpPackImportService._createMediaItemFromJson()
- Build photoMapping from media/photos/ directory
- Match filename from entry media to photoMapping
- If not found, try originalPath fallback
- Return null if both fail (NEW - this was the bug!)
```

## Critical Issues Identified

### Issue 1: Missing Try-Catch Around Media Processing
**Before**: Media processing failures didn't prevent entry import  
**Current**: Exceptions in media processing could skip entire entries

**Fix Applied**: Added individual try-catch around each media item creation

### Issue 2: Null Return Without Fallback
**Before**: Always created MediaItem, even if photo not found  
**Current**: Returns `null` if photo mapping fails (without originalPath)

**Fix Applied**: Added `originalPath` fallback in `_createMediaItemFromJson`

### Issue 3: Different Import Paths
**Problem**: UI might be calling different import services for different file types
- Unencrypted `.zip` → Might use `McpPackImportService` (new)
- Encrypted `.arcx` → Uses `ARCXImportService` (different service)
- Extracted directories → Uses `McpImportService` (old)

**Solution Needed**: Verify which service is actually being called for unencrypted zip imports

## Critical Finding: Two Different Import Services

### The Problem

**Current State**: The UI (`mcp_import_screen.dart`) uses `McpPackImportService` for unencrypted `.zip` files, but this service expects `nodes/journal/*.json` format.

**Old State**: `McpImportService` handled entries differently:
- Used `_extractMediaFromPlaceholders()` to process media from placeholders
- Used `_processPhotoPlaceholders()` to handle media references
- Always imported entries even if media failed
- Had sophisticated photo reconnection logic

### The Architecture Mismatch

**Old Import Flow (Working)**:
```
UI → McpSettingsCubit → McpImportService.importBundle()
  → Checks for journal_v1.mcp.zip → _importFromJournalZip()
    → Reads entries/ directory → Creates McpNode → _convertMcpNodeToJournalEntry()
      → _extractMediaFromPlaceholders() → Always creates entry
```

**New Import Flow (Current)**:
```
UI → McpPackImportService.importFromPath()
  → Reads nodes/journal/*.json → Directly creates JournalEntry
    → _createMediaItemFromJson() → Returns null if photo mapping fails
      → Entry created with empty media (if no exceptions)
```

### Key Differences

1. **Media Processing**:
   - **Old**: Placeholder-based system with sophisticated reconnection
   - **New**: Filename-based mapping with simpler fallback

2. **Error Handling**:
   - **Old**: Always created entries, media failures were non-fatal
   - **New**: Media failures could cause exceptions that skip entries (FIXED in recent commits)

3. **Entry Structure**:
   - **Old**: Expected `entries/` directory OR `nodes.jsonl`
   - **New**: Expects `nodes/journal/*.json` format

## Recommendations

1. **Verify Import Path**: Check which service is actually being called when importing unencrypted zip files
2. **Unify Import Logic**: Consider consolidating photo handling logic between services
3. **Better Error Handling**: Ensure all import paths handle media failures gracefully (PARTIALLY FIXED)
4. **Add Comprehensive Logging**: Track which service handles which file type
5. **Consider**: Merge the robust error handling from `McpImportService` into `McpPackImportService`

## Files Changed

### New Files
- `lib/core/mcp/import/mcp_pack_import_service.dart` - NEW service for zip imports

### Modified Files
- `lib/mcp/import/mcp_import_service.dart` - Still exists, handles different formats
- `lib/arcx/services/arcx_export_service.dart` - Uses McpPackExportService
- `lib/arcx/services/arcx_import_service.dart` - Uses own import logic

### Key Differences
- Old: Single service handling all formats
- New: Multiple specialized services for different formats
- Risk: Inconsistency between services causing import failures


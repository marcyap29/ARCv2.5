# Phase Fields Export/Import Verification

## Overview
This document verifies that all new phase detection fields are properly exported and imported in both ARCX and MCP (ZIP) archive formats.

## New Phase Fields Added
1. `autoPhase` (String?) - Model-detected phase, authoritative
2. `autoPhaseConfidence` (double?) - Confidence score 0.0-1.0
3. `userPhaseOverride` (String?) - Manual override via dropdown
4. `isPhaseLocked` (bool) - If true, don't auto-overwrite
5. `legacyPhaseTag` (String?) - From old phase field or imports (reference only)
6. `importSource` (String?) - "NATIVE", "ARCHX", "ZIP", "OTHER"
7. `phaseInferenceVersion` (int?) - Version of inference pipeline used
8. `phaseMigrationStatus` (String?) - "PENDING", "DONE", "SKIPPED"

## Export Verification

### ARCX Export (`arcx_export_service_v2.dart`)
✅ **Status: COMPLETE**

All phase fields are exported in the entry JSON:
```dart
// Lines 937-944
'autoPhase': entry.autoPhase,
'autoPhaseConfidence': entry.autoPhaseConfidence,
'userPhaseOverride': entry.userPhaseOverride,
'isPhaseLocked': entry.isPhaseLocked,
'legacyPhaseTag': entry.legacyPhaseTag,
'importSource': entry.importSource,
'phaseInferenceVersion': entry.phaseInferenceVersion,
'phaseMigrationStatus': entry.phaseMigrationStatus,
```

### MCP Export - Pack Service (`mcp_pack_export_service.dart`)
✅ **Status: COMPLETE**

All phase fields are exported in the entry JSON:
```dart
// Lines 348-355
'autoPhase': entry.autoPhase,
'autoPhaseConfidence': entry.autoPhaseConfidence,
'userPhaseOverride': entry.userPhaseOverride,
'isPhaseLocked': entry.isPhaseLocked,
'legacyPhaseTag': entry.legacyPhaseTag,
'importSource': entry.importSource,
'phaseInferenceVersion': entry.phaseInferenceVersion,
'phaseMigrationStatus': entry.phaseMigrationStatus,
```

### MCP Export - Export Service (`mcp_export_service.dart`)
✅ **Status: COMPLETE**

All phase fields are exported in the entry JSON:
```dart
// Lines 294-301
'autoPhase': entry.autoPhase,
'autoPhaseConfidence': entry.autoPhaseConfidence,
'userPhaseOverride': entry.userPhaseOverride,
'isPhaseLocked': entry.isPhaseLocked,
'legacyPhaseTag': entry.legacyPhaseTag,
'importSource': entry.importSource,
'phaseInferenceVersion': entry.phaseInferenceVersion,
'phaseMigrationStatus': entry.phaseMigrationStatus,
```

## Import Verification

### ARCX Import (`arcx_import_service_v2.dart`)
✅ **Status: COMPLETE**

All phase fields are read from imported JSON and properly handled:

1. **Field Reading** (Lines 1222-1229):
   - All fields are read from JSON with proper type casting
   - Defaults are provided where appropriate (`isPhaseLocked: false`, `importSource: 'ARCHX'`)

2. **Migration Status Logic** (Lines 1235-1238):
   - Automatically sets `phaseMigrationStatus` to "PENDING" if:
     - `phaseInferenceVersion` is null OR
     - `phaseInferenceVersion < CURRENT_PHASE_INFERENCE_VERSION`
   - Preserves existing migration status if present

3. **Entry Creation** (Lines 1253-1260):
   - All phase fields are properly assigned to the JournalEntry
   - Legacy phase field is populated from `legacyPhaseTag` for backward compatibility

4. **Post-Import Inference** (Lines 1528-1568):
   - Entries with `phaseMigrationStatus == "PENDING"` automatically get phase inference
   - Updates `autoPhase`, `autoPhaseConfidence`, `phaseInferenceVersion`, and `phaseMigrationStatus`

### MCP Import (`mcp_pack_import_service.dart`)
✅ **Status: COMPLETE**

All phase fields are read from imported JSON and properly handled:

1. **Field Reading** (Lines 384-391):
   - All fields are read from JSON with proper type casting
   - Defaults are provided where appropriate (`isPhaseLocked: false`, `importSource: 'ZIP'`)

2. **Migration Status Logic** (Lines 394-397):
   - Automatically sets `phaseMigrationStatus` to "PENDING" if:
     - `phaseInferenceVersion` is null OR
     - `phaseInferenceVersion < CURRENT_PHASE_INFERENCE_VERSION`
   - Preserves existing migration status if present

3. **Entry Creation** (Lines 427-434):
   - All phase fields are properly assigned to the JournalEntry
   - Legacy phase field is populated from `legacyPhaseTag` for backward compatibility

4. **Post-Import Inference** (Lines 894-935):
   - Entries with `phaseMigrationStatus == "PENDING"` automatically get phase inference
   - Updates `autoPhase`, `autoPhaseConfidence`, `phaseInferenceVersion`, and `phaseMigrationStatus`

## Backward Compatibility

✅ **Status: MAINTAINED**

Both import services maintain backward compatibility:

1. **Legacy Phase Field**: The old `phase` field is preserved and used to populate `legacyPhaseTag` if not present
2. **Missing Fields**: All new fields are nullable and have defaults, so older archives import without errors
3. **Migration**: Older entries automatically get `phaseMigrationStatus = "PENDING"` and are processed with new inference

## Test Scenarios

### Scenario 1: Export New Entry
- Entry created with new phase system
- All 8 phase fields populated
- ✅ Exported correctly in ARCX format
- ✅ Exported correctly in MCP format

### Scenario 2: Import New Archive
- Archive exported from new version
- Contains all 8 phase fields
- ✅ All fields imported correctly
- ✅ Phase data preserved exactly

### Scenario 3: Import Old Archive
- Archive exported from old version
- Only contains legacy `phase` field
- ✅ Imports without errors
- ✅ `legacyPhaseTag` populated from `phase`
- ✅ `phaseMigrationStatus` set to "PENDING"
- ✅ Phase inference runs automatically

### Scenario 4: Round-Trip Export/Import
- Export entry → Import same archive
- ✅ All phase fields preserved
- ✅ User overrides maintained
- ✅ Migration status preserved

## ZIP Archive Verification

### MCP Pack Export (ZIP/.mcpkg format)
✅ **Status: COMPLETE**

The `McpPackExportService` creates ZIP archives (`.mcpkg` format) containing journal entries:

1. **ZIP Creation** (Lines 221-229):
   - Creates ZIP archive using `ZipEncoder`
   - Packages all entry JSON files into the ZIP
   - Entry JSON files contain all 8 phase fields (Lines 348-355)

2. **Entry JSON Structure**:
   ```dart
   // Lines 348-355 in mcp_pack_export_service.dart
   'autoPhase': entry.autoPhase,
   'autoPhaseConfidence': entry.autoPhaseConfidence,
   'userPhaseOverride': entry.userPhaseOverride,
   'isPhaseLocked': entry.isPhaseLocked,
   'legacyPhaseTag': entry.legacyPhaseTag,
   'importSource': entry.importSource,
   'phaseInferenceVersion': entry.phaseInferenceVersion,
   'phaseMigrationStatus': entry.phaseMigrationStatus,
   ```

### MCP Pack Import (ZIP/.mcpkg format)
✅ **Status: COMPLETE**

The `McpPackImportService` imports from ZIP archives (`.zip` or `.mcpkg` files):

1. **ZIP Detection** (Lines 42-52):
   - Explicitly checks for `.zip` file extension
   - Extracts ZIP archive to temporary directory
   - Processes all entry JSON files from the ZIP

2. **Phase Fields Reading** (Lines 384-391):
   - Reads all 8 phase fields from entry JSON
   - Handles missing fields with defaults
   - Sets migration status for older entries

3. **Entry Creation** (Lines 427-434):
   - Creates JournalEntry with all phase fields
   - Preserves user overrides and locked states
   - Sets importSource to 'ZIP'

4. **Post-Import Inference** (Lines 894-935):
   - Automatically runs phase inference for PENDING entries
   - Updates phase fields with new inference results

### ZIP Archive Format Structure

```
archive.zip (or archive.mcpkg)
├── manifest.json (contains metadata)
├── nodes/
│   └── journal/
│       ├── entry_0.json (contains all 8 phase fields)
│       ├── entry_1.json (contains all 8 phase fields)
│       └── ...
└── media/ (optional media files)
```

Each `entry_X.json` file contains:
```json
{
  "id": "...",
  "content": "...",
  "emotion": "...",
  "phase": "...",  // Legacy field
  "autoPhase": "...",
  "autoPhaseConfidence": 0.85,
  "userPhaseOverride": null,
  "isPhaseLocked": false,
  "legacyPhaseTag": "...",
  "importSource": "NATIVE",
  "phaseInferenceVersion": 1,
  "phaseMigrationStatus": "DONE",
  ...
}
```

## Conclusion

✅ **All export and import services are properly implemented and verified.**

- All 8 new phase fields are exported in both ARCX and MCP/ZIP formats
- All 8 new phase fields are imported and properly handled from ZIP archives
- ZIP archives (.zip/.mcpkg) fully support all phase fields
- Backward compatibility is maintained for older archives
- Automatic migration is implemented for entries needing phase inference
- User overrides and locked phases are preserved across export/import cycles

### Format Support Matrix

| Format | Export | Import | Phase Fields |
|--------|--------|--------|--------------|
| ARCX (.arcx) | ✅ | ✅ | All 8 fields |
| MCP ZIP (.zip/.mcpkg) | ✅ | ✅ | All 8 fields |
| Legacy Archives | N/A | ✅ | Auto-migrated |


# Export Phase Regimes Implementation

## Overview
Updated the ARCX export capability to include Phase Regimes of the user in exported archives.

## Changes Made

### 1. ARCXScope Model (`arcx_manifest.dart`)
**Added**: `phaseRegimesCount` field to track number of phase regimes exported

```dart
class ARCXScope {
  final int entriesCount;
  final int chatsCount;
  final int mediaCount;
  final int phaseRegimesCount;  // NEW
  final bool separateGroups;
  // ...
}
```

### 2. ARCXExportServiceV2 (`arcx_export_service_v2.dart`)
**Added**:
- `PhaseRegimeService?` parameter to constructor
- `_exportPhaseRegimes()` method to export phase regimes to `PhaseRegimes/phase_regimes.json`
- Phase regimes export in all export strategies:
  - `_exportTogether()` - includes phase regimes
  - `_exportSeparateGroups()` - includes phase regimes in Entries archive
  - `_exportEntriesChatsTogetherMediaSeparate()` - includes phase regimes in Entries+Chats archive
  - `_exportSingleGroup()` - includes phase regimes when `includePhaseRegimes=true`

**Export Location**: `payload/PhaseRegimes/phase_regimes.json`

**Format**: Uses `PhaseRegimeService.exportForMcp()` which returns:
```json
{
  "phase_regimes": [
    {
      "id": "regime_...",
      "label": "discovery|expansion|transition|consolidation|recovery|breakthrough",
      "start": "2024-01-01T00:00:00Z",
      "end": "2024-02-01T00:00:00Z" | null,
      "source": "user|rivet",
      "confidence": 0.85,  // if source=rivet
      "inferred_at": "2024-01-15T00:00:00Z",  // if source=rivet
      "anchors": ["entry_id_1", "entry_id_2"],
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  ],
  "exported_at": "2024-01-20T00:00:00Z",
  "version": "1.0"
}
```

### 3. Export Screen (`mcp_export_screen.dart`)
**Added**:
- Imports for `PhaseRegimeService`, `RivetSweepService`, `AnalyticsService`
- Initialization of `PhaseRegimeService` before export
- Passes `PhaseRegimeService` to `ARCXExportServiceV2` constructor

**Error Handling**: If PhaseRegimeService fails to initialize, export continues without phase regimes (graceful degradation)

## Export Behavior

### All-in-One Export (`together`)
- Phase regimes exported to `PhaseRegimes/phase_regimes.json`
- Included in manifest scope with count

### Separate Groups Export (`separateGroups`)
- Phase regimes included in **Entries** archive (logical grouping)
- Not included in Chats or Media archives

### Entries+Chats Together (`entriesChatsTogetherMediaSeparate`)
- Phase regimes included in **Entries+Chats** archive
- Not included in Media archive

## Manifest Updates

The manifest now includes phase regimes count in scope:
```json
{
  "scope": {
    "entries_count": 100,
    "chats_count": 50,
    "media_count": 200,
    "phase_regimes_count": 15,  // NEW
    "separate_groups": false
  }
}
```

## Backward Compatibility

- `phaseRegimesCount` defaults to `0` if not provided (backward compatible)
- Old exports without phase regimes will have `phase_regimes_count: 0`
- Import services can check for `phase_regimes_count > 0` to determine if phase regimes are present

## Testing Checklist

- [ ] Export with phase regimes → verify `PhaseRegimes/phase_regimes.json` exists
- [ ] Export without phase regimes → verify export succeeds (no error)
- [ ] Verify manifest includes `phase_regimes_count`
- [ ] Verify phase regimes included in correct archive (Entries or Entries+Chats)
- [ ] Test all export strategies (together, separateGroups, entriesChatsTogetherMediaSeparate)
- [ ] Verify phase regimes JSON structure matches expected format
- [ ] Test import of exported phase regimes

## Files Modified

1. `lib/polymeta/store/arcx/models/arcx_manifest.dart`
   - Added `phaseRegimesCount` to `ARCXScope`

2. `lib/polymeta/store/arcx/services/arcx_export_service_v2.dart`
   - Added `PhaseRegimeService?` parameter
   - Added `_exportPhaseRegimes()` method
   - Updated all export methods to include phase regimes
   - Updated manifest creation to include phase regimes count

3. `lib/ui/export_import/mcp_export_screen.dart`
   - Added imports for phase regime services
   - Initialize and pass `PhaseRegimeService` to export service

## Future Enhancements

1. **Date Range Filtering**: Filter phase regimes by date range (currently exports all)
2. **Selective Export**: Allow user to choose which phase regimes to export
3. **Import Support**: Update import service to restore phase regimes from export
4. **Validation**: Verify phase regimes reference valid entry IDs in export


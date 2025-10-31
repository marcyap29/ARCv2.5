# Health Tab Integration Guide

Complete guide to the Health Tab's integration with Apple HealthKit, including daily metrics import, MCP streaming, PRISM fusion, and ARCX export/import.

## Overview

The Health Tab provides comprehensive health data visualization and analysis by:
- Importing 30/60/90 days of health metrics from Apple Health
- Aggregating daily metrics (steps, energy, HR, HRV, sleep, workouts)
- Writing to MCP streams for PRISM fusion
- Providing detailed charts and insights
- Exporting/importing health data in ARCX format

## UI Structure

### Health Tab Layout
- **Header**: Title "Health" with two action icons:
  - **Info icon** (top-right): Shows overview dialog explaining Health Insights and Analytics tabs
  - **Settings icon** (top-right): Opens Health Settings dialog for data import

### Tabs
1. **Health Insights** (formerly "Summary")
   - Daily health summary card with 7-day overview
   - Chart icon to view detailed metrics over time
   - Info card with helpful tips

2. **Analytics**
   - Deep dive into health analytics, trends, and patterns

### Settings Dialog
Accessible via the Settings icon in the header, provides:
- **Import Health Data** section with three clear options:
  - **30 Days** button - "Last month"
  - **60 Days** button - "Last 2 months"  
  - **90 Days** button - "Last 3 months"
- Progress indicators during import
- Success/error status messages

## Health Metrics Imported

### Daily Metrics (per day)
- **Steps**: Total step count
- **Active Energy**: Active calories burned (kcal)
- **Resting Energy**: Basal/resting calories (kcal)
- **Exercise Minutes**: Total exercise time
- **Resting Heart Rate**: Lowest resting HR (bpm)
- **Average Heart Rate**: Daily average HR (bpm)
- **HRV SDNN**: Heart rate variability (ms)
- **Sleep**: Total sleep minutes
- **Weight**: Body mass (kg)
- **Workouts**: Array of workout details:
  - Type, duration, energy, distance, average HR
  - Distance from workouts contributes to daily distance metric

### Note on Distance
- `DISTANCE_DELTA` is not available on iOS/Apple Health
- Distance is captured from workout metadata when available
- Daily distance will be 0 if no workouts with distance data exist

### Metrics Not Available (health plugin v10.2.0)
- **VO2 Max**: Not supported in current health plugin version
- **Stand Time**: Not supported in current health plugin version

These metrics have been removed from the app UI and data models. If you need these metrics, you would need to upgrade to a newer version of the health plugin or implement custom native code to access them via HealthKit directly.

## Data Flow

### 1. Import Process
```
User taps "30d/60d/90d" in Settings
  ↓
Request HealthKit permissions (if not granted)
  ↓
HealthIngest.importDays() aggregates metrics
  ↓
Write to mcp/streams/health/YYYY-MM.jsonl
  ↓
Display success message
```

### 2. MCP Stream Format
Each day produces one JSONL line with type `health.timeslice.daily`:

```json
{
  "mcp_version": "1.0",
  "type": "health.timeslice.daily",
  "source": {
    "system": "healthkit",
    "platform": "ios",
    "collected_at": "2025-01-15T12:00:00Z"
  },
  "subject": {
    "user_id": "user_1234567890"
  },
  "timeslice": {
    "start": "2025-01-15T00:00:00Z",
    "end": "2025-01-15T23:59:59Z",
    "timezone_of_record": "UTC"
  },
  "metrics": {
    "steps": {"value": 8500, "unit": "count"},
    "active_energy": {"value": 450.5, "unit": "kcal"},
    "resting_energy": {"value": 1800.0, "unit": "kcal"},
    "exercise_minutes": {"value": 45, "unit": "min"},
    "resting_hr": {"value": 58, "unit": "bpm"},
    "avg_hr": {"value": 72, "unit": "bpm"},
    "hrv_sdnn": {"value": 42, "unit": "ms"},
    "cardio_recovery_1min": {"value": null, "unit": "bpm"},
    "sleep_total_minutes": 420,
    "weight": {"value": 75.5, "unit": "kg"},
    "workouts": [
      {
        "start": "2025-01-15T06:00:00Z",
        "end": "2025-01-15T07:00:00Z",
        "type": "running",
        "duration_min": 60,
        "energy_kcal": null,
        "distance_m": 10000,
        "avg_hr": 145
      }
    ]
  },
  "fusion_keys": {
    "day_key": "2025-01-15",
    "tags": ["health", "daily"]
  },
  "provenance": {
    "granularity": "daily",
    "aggregation": "sum/avg",
    "confidence": 0.97
  }
}
```

### 3. PRISM Joiner Integration
Health streams feed into PRISM Joiner (`lib/prism/pipelines/prism_joiner.dart`):
- Reads `mcp/streams/health/` JSONL files
- Merges with journal, keywords, phase, chrono data by `day_key`
- Computes enriched features:
  - `stress_hint`: Composite stress indicator (0-1)
  - `sleep_debt_min`: Sleep vs 7h target
  - `readiness_hint`: Recovery/readiness score (0-1)
  - `activity_balance`: Active vs resting energy ratio
  - `workout_count`, `workout_minutes`, `workout_energy_kcal`

### 4. ATLAS & VEIL Enrichment
PRISM Joiner enriches daily fusion with:
- **ATLAS Engine**: Phase detection (Breakthrough, Expansion, Recovery, Consolidation)
- **VEIL Edge Policy**: Journal cadence, prompt weights, coach nudges, safety flags

Outputs:
- `mcp/fusions/daily/YYYY-MM.jsonl` - Daily fusion with all features
- `mcp/policies/veil/YYYY-MM.jsonl` - VEIL policies for LUMARA

### 5. ARCX Export/Import (Filtered)
Health streams are included in ARCX archives with intelligent filtering:
- **Export**: Only exports health data for dates that have journal entries
- **Filtering**: Extracts entry dates and filters health JSONL files to include only relevant days
- **Associations**: Creates bidirectional links between journal entries and health metrics
- **Import**: Health streams restored to `Documents/mcp/streams/health/` in append mode
- **Benefits**: Reduces archive size and ensures only relevant health data is exported
- **Metrics**: Each journal entry includes a health association with:
  - Date of health data
  - Stream reference (path to JSONL file)
  - List of included metrics (steps, heart rate, sleep, etc.)
  - Association timestamp

## File Structure

### Dart Files
```
lib/
├── arc/ui/health/
│   ├── health_view.dart              # Main Health tab with tabs and settings
│   ├── health_detail_view.dart       # Health Insights body content
│   └── health_settings_dialog.dart   # Settings dialog with import controls
├── ui/health/
│   └── health_detail_screen.dart     # Detailed charts view
├── prism/
│   ├── models/
│   │   └── health_daily.dart         # Daily aggregation model
│   ├── services/
│   │   └── health_service.dart       # HealthIngest class + MCP writer
│   ├── pipelines/
│   │   └── prism_joiner.dart        # Daily fusion joiner
│   └── engines/
│       ├── atlas_engine.dart         # Phase detection
│       └── veil_edge_policy.dart    # Journal cadence policy
```

### iOS Files
```
ios/Runner/
├── HealthKitManager.swift           # HealthKit read types (expanded)
└── AppDelegate.swift                # MethodChannel registration
```

### MCP Files (Generated)
```
Documents/mcp/
├── streams/
│   └── health/
│       └── YYYY-MM.jsonl            # Daily health metrics
├── fusions/
│   └── daily/
│       └── YYYY-MM.jsonl            # Fused daily data with features
└── policies/
    └── veil/
        └── YYYY-MM.jsonl            # VEIL policies
```

## Usage

### Importing Health Data
1. Open Health tab
2. Tap Settings icon (gear) in header
3. Select desired import range:
   - **30 Days** for last month
   - **60 Days** for last 2 months
   - **90 Days** for last 3 months
4. Grant HealthKit permissions if prompted
5. Wait for import to complete (progress shown)
6. View imported data in Health Detail charts

### Viewing Detailed Charts
1. From Health Insights tab, tap chart icon on summary card
2. View time-series charts for:
   - Steps, Active/Basal Energy, Sleep
   - Resting HR, Average HR, HRV
3. Each chart includes:
   - Statistics (min, max, average)
   - Date labels on x-axis
   - Value tooltips on tap

### Running PRISM Joiner
```dart
import 'package:my_app/prism/pipelines/prism_joiner.dart';
import 'dart:io';

final joiner = PrismJoiner(Directory('Documents/mcp'));
await joiner.joinRange(daysBack: 30);
```

This creates:
- Daily fusion files with enriched features
- VEIL policies for journal cadence and prompts

## Technical Details

### NumericHealthValue Handling (FIXED)
The `health` package v10.2.0 wraps numeric values in `NumericHealthValue` objects with format: `"NumericHealthValue - numericValue: 877.0"`. 

The service uses `_getNumericValue()` helper to safely extract values:
1. Check if value is directly `num` (int/double)
2. Try direct parsing via `toString()` for backward compatibility  
3. **Parse NumericHealthValue format** using regex: `numericValue:\s*([\d.-]+)`
4. Try dynamic access to `numericValue` property as fallback
5. Return null if all extraction methods fail

**Key Fix (Jan 2025)**: Added regex parsing for the new NumericHealthValue format which resolved the issue where health data was silently failing to import despite HealthKit returning data.

### Error Handling
- Missing HealthKit types: Falls back to minimal set (steps, active energy, heart rate)
- Permission denied: Shows clear error message
- Import failures: Logged with detailed error info

### File Paths
- Uses `path_provider` for iOS sandbox compatibility
- MCP root: `Documents/mcp/`
- Health streams: `Documents/mcp/streams/health/`

## Dependencies

```yaml
dependencies:
  health: ^10.2.0        # HealthKit/Health Connect access
  collection: ^1.18.0    # sortedBy extension
  fl_chart: ^0.68.0      # Charts for Health Detail screen
  path_provider: ^2.1.4  # App documents directory
```

## iOS Setup

### HealthKit Capability
1. Open Xcode project
2. Select Runner target
3. Signing & Capabilities → + Capability → HealthKit
4. Ensure entitlements show `com.apple.developer.healthkit = true`

### Info.plist
Already configured with:
- `NSHealthShareUsageDescription`
- `NSHealthUpdateUsageDescription`

### HealthKitManager.swift
Expanded read types include:
- Steps, HR, HRV, Sleep
- Active/Basal Energy
- Exercise Time
- Distance (walking/running)
- Weight, Workouts
- VO₂max (iOS 17+)
- Heart Rate Recovery (iOS 17+)
- Stand Time (iOS 16+)

## Troubleshooting

### Import Error: "type 'NumericHealthValue' is not a subtype"
- **Fixed**: `_getNumericValue()` helper safely extracts values
- If persists, check `health` package version compatibility

### No Distance Data
- **Expected**: `DISTANCE_DELTA` not available on iOS
- Distance captured from workout metadata when available
- Check workouts array for distance values

### Health Detail Screen Shows "No health data yet"
- Verify import completed successfully
- Check `Documents/mcp/streams/health/` for JSONL files
- Ensure month key matches current month (YYYY-MM format)

### Charts Not Rendering
- Verify `fl_chart` dependency installed: `flutter pub get`
- Check console for chart rendering errors
- Ensure JSONL files contain valid `health.timeslice.daily` entries

### ARCX Import Missing Health Data
- Verify export included `streams/health/` directory
- Check ARCX payload structure in manifest
- Health streams import to append mode (preserves existing data)

## Recent Fixes (January 2025)

### NumericHealthValue Parsing Fix
- **Issue**: Health data import was silently failing with health plugin v10.2.0
- **Root Cause**: Plugin changed from returning raw numbers to `NumericHealthValue` objects with string format
- **Fix**: Added regex parsing to extract numeric values from format: `"NumericHealthValue - numericValue: 877.0"`
- **Impact**: All health metrics now import correctly from HealthKit

### VO2 Max and Stand Time Removal
- **Issue**: App referenced `HealthDataType.VO2_MAX` and `HealthDataType.APPLE_STAND_TIME` which don't exist in v10.2.0
- **Fix**: Removed all references from UI, data models, and export code
- **Impact**: App builds successfully and displays only supported metrics

### Filtered Health Export
- **Feature**: Health data now only exports for dates with journal entries
- **Implementation**: Extracts journal entry dates and filters health JSONL files accordingly
- **Benefits**: Reduced archive size, clearer data associations

## Future Enhancements

- [ ] VO₂max support (requires health plugin upgrade or custom native code)
- [ ] Stand time support (requires health plugin upgrade or custom native code)
- [ ] Heart rate recovery (1-minute) from workouts
- [ ] Enhanced workout metadata extraction
- [ ] Health trends and anomaly detection
- [ ] Export health summaries as PDF reports

## Related Documentation

- [PRISM VITAL Health Integration](./PRISM_VITAL_Health_Integration.md) - Original health integration spec
- [HealthKit Permissions Troubleshooting](./HealthKit_Permissions_Troubleshooting.md) - Permission setup guide
- [ARCX Export/Import](../../README_MCP_MEDIA.md) - ARCX format documentation


# ARCX Export Functionality Investigation Report

## Executive Summary

ARCX is a **secure archive format** for exporting ARC app data including journal entries, photos, and health data. It uses **AES-256-GCM encryption** and **Ed25519 digital signatures** to ensure data integrity and confidentiality. The export can be password-protected for portability or device-key encrypted for single-device security.

---

## 1. What is ARCX Export?

### Definition
ARCX (.arcx) is a secure, encrypted archive format that packages and protects the complete user data including:
- Journal entries with metadata
- Photo metadata and files
- Health metrics and streams
- MCP (Memory Bundle) manifest

### Format Structure
```
export_TIMESTAMP.arcx
├── archive.arcx (encrypted payload)
└── manifest.json (signed metadata)
```

The .arcx file is actually a ZIP containing:
1. **archive.arcx** - AES-256-GCM encrypted payload containing all user data
2. **manifest.json** - Digital signature and metadata about the export

### Encryption & Signing
- **Encryption**: AES-256-GCM (Authenticated Encryption with Associated Data)
- **Key Derivation**: 
  - Device-based: Uses iOS Keychain/Secure Enclave
  - Password-based: PBKDF2-SHA256 with 600,000 iterations + random salt
- **Signing**: Ed25519 digital signature
- **File Protection**: iOS-native file protection (NSFileProtectionComplete)

### Privacy Features
Users can configure before export:
- **Remove PII**: Strip names, emails, device IDs, IPs, locations from JSON
- **Include Photo Labels**: Toggle AI-generated photo descriptions
- **Date-Only Timestamps**: Reduce precision to YYYY-MM-DD (no time)
- **Password Encryption**: Create portable archives that work on any device

---

## 2. What Health Data is Included?

### Health Metrics Collected

The app collects **9 key health metrics** from Apple HealthKit:

1. **Steps** (count)
   - Daily step count aggregated from HealthKit

2. **Active Energy** (kcal)
   - Calories burned through active exercise
   - Data type: `ACTIVE_ENERGY_BURNED`

3. **Basal Energy** (kcal)
   - Resting metabolic energy
   - Data type: `BASAL_ENERGY_BURNED`

4. **Sleep** (minutes)
   - Total sleep duration
   - Data type: `SLEEP_ASLEEP`

5. **Resting Heart Rate** (bpm)
   - Morning/resting HR measurement
   - Data type: `RESTING_HEART_RATE`

6. **Average Heart Rate** (bpm)
   - Average HR during the day from samples
   - Computed from `HEART_RATE` samples

7. **Heart Rate Variability (HRV)** (ms)
   - SDNN metric for autonomic nervous system assessment
   - Data type: `HEART_RATE_VARIABILITY_SDNN`

8. **VO2 Max** (ml/(kg·min))
   - Cardiorespiratory fitness metric
   - Data type: `VO2_MAX`

9. **Stand Time** (minutes)
   - Time spent standing/moving (Apple Watch metric)
   - Data type: `APPLE_STAND_TIME`

### Additional Health Data
- **Exercise Time** (minutes) - `EXERCISE_TIME`
- **Weight** (kg) - `WEIGHT`
- **Workouts** - Complete workout data with duration, type, distance
- **Distance** (meters) - Walk/run distance from workouts

### Health Data Structure in Export

Health data is stored in ARCX exports in multiple formats:

```
payload/
├── health/
│   └── [health summary JSON files]
├── pointer/
│   └── health/
│       └── [health pointer JSON files]
└── streams/
    └── health/
        └── [YYYY-MM].jsonl (daily health timeslices)
```

Each health timeslice follows MCP format:
```json
{
  "type": "health.timeslice.daily",
  "timeslice": {
    "start": "2025-01-15T00:00:00Z",
    "end": "2025-01-15T23:59:59Z",
    "timezone_of_record": "UTC"
  },
  "metrics": {
    "steps": {"value": 8234, "unit": "count"},
    "distance_walk_run": {"value": 5234.5, "unit": "m"},
    "active_energy": {"value": 450.2, "unit": "kcal"},
    "resting_energy": {"value": 1680.5, "unit": "kcal"},
    "exercise_minutes": {"value": 45, "unit": "min"},
    "resting_hr": {"value": 62.0, "unit": "bpm"},
    "avg_hr": {"value": 75.5, "unit": "bpm"},
    "hrv_sdnn": {"value": 45.3, "unit": "ms"},
    "vo2max": {"value": 42.1, "unit": "ml/(kg·min)"},
    "sleep_total_minutes": 480,
    "stand_minutes": 12,
    "weight": {"value": 75.5, "unit": "kg"},
    "workouts": [...]
  }
}
```

---

## 3. What Timeframes are Supported?

### Export Timeframe Options (General)

The MCP export system supports these scopes defined in `McpExportScope` enum:
- **last-30-days** - Last 30 days
- **last-90-days** - Last 90 days  
- **last-year** - Last 365 days
- **all** - All data
- **custom** - Custom date range

### Health Data Import Timeframes

The Health Settings Dialog offers **specific 30/60/90 day options**:

```dart
// From HealthSettingsDialog (health_settings_dialog.dart)
_ImportButton(days: 30, label: '30 Days', description: 'Last month')
_ImportButton(days: 60, label: '60 Days', description: 'Last 2 months')
_ImportButton(days: 90, label: '90 Days', description: 'Last 3 months')
```

### Health Data Join/Fusion Constraints

The `PrismJoiner.joinRange()` function validates:
```dart
assert(daysBack >= 30 && daysBack <= 90);
```

**Supported ranges: 30-90 days minimum/maximum**

### Current Export Behavior

The current `McpExportScreen` exports **ALL journal entries and ALL health data** without timeframe selection:
- Loads all journal entries via `journalRepo.getAllJournalEntries()`
- Exports all photos associated with entries
- Includes all health streams from `streams/health/` directory

**Note**: The UI does NOT currently present timeframe options for export (unlike the CLI tool).

---

## 4. How Does ARCX Export Work?

### Export Process (10 Steps)

1. **Gather MCP Bundle**
   - Uses `McpPackExportService` to generate MCP structure
   - Collects journal entries, photos, and health data

2. **Apply Redaction (Optional)**
   - Remove PII if enabled (names, emails, device IDs, locations)
   - Strip photo labels if disabled
   - Clamp timestamps to date-only if enabled

3. **Package Payload**
   - Organize data into `payload/` directory structure:
     - `payload/journal/` - Journal entry JSON files
     - `payload/media/photo/` - Photo metadata
     - `payload/media/photos/` - Photo image files
     - `payload/health/` - Health summaries
     - `payload/pointer/health/` - Health pointers
     - `payload/streams/health/` - Health JSONL streams

4. **Archive Payload**
   - Create ZIP from `payload/` directory (in-memory)
   - Skip compression for already-compressed media files
   - Results in plaintext ZIP archive

5. **Encrypt Payload**
   - **Option A (Device-based)**: Encrypt with iOS Keychain key using AES-256-GCM
   - **Option B (Password-based)**: Generate salt, derive key via PBKDF2-SHA256 (600k iterations), encrypt with AES-256-GCM
   - Output: Ciphertext bytes

6. **Create Manifest**
   - Compute SHA-256 hash of ciphertext
   - Compute SHA-256 hash of MCP manifest
   - Generate report of redactions applied
   - Include counts: journal entries, photos, bytes
   - Include export timestamp and app version
   - Include signer public key fingerprint

7. **Sign Manifest**
   - Generate Ed25519 digital signature of manifest JSON
   - Prevents tampering with export metadata

8. **Build Final Archive**
   - Create new ZIP containing:
     - `archive.arcx` - Encrypted payload (ciphertext)
     - `manifest.json` - Signed manifest with metadata

9. **Write to File**
   - Save as `export_TIMESTAMP.arcx`
   - Set iOS file protection (NSFileProtectionComplete)
   - Located in app documents directory

10. **Cleanup**
    - Delete temporary directory
    - Return success result with manifest and stats

### File Organization

```
App Documents/
└── Exports/
    └── export_2025-01-30T14-32-45.arcx
        ├── archive.arcx (AES-256-GCM encrypted)
        └── manifest.json (Ed25519 signed)
```

### Data Flow Diagram

```
Journal Entries + Photos
        ↓
McpPackExportService (generates MCP structure)
        ↓
Health Streams (from mcp/streams/health/)
        ↓
Apply Redaction (PII removal, timestamp clamping, label stripping)
        ↓
Package into payload/ directory
        ↓
Zip payload/ → plaintext.zip
        ↓
AES-256-GCM Encrypt (device key OR password-derived key)
        ↓
Sign Manifest (Ed25519)
        ↓
Create Final Archive (.arcx)
   ├── archive.arcx (encrypted)
   └── manifest.json (signed)
        ↓
Write to Exports/ directory
```

### Redaction Report Included

The manifest includes redaction metadata:
```dart
ARCXRedactionService.computeRedactionReport(
  journalEntriesRedacted: entriesCount,
  photosRedacted: photosCount,
  dateOnly: dateOnlyTimestamps,
  includePhotoLabels: includePhotoLabels,
)
```

This allows import verification of what privacy options were applied.

---

## 5. File Locations and Implementation Details

### Key Implementation Files

| File | Purpose |
|------|---------|
| `lib/arcx/services/arcx_export_service.dart` | Main export orchestration (650+ lines) |
| `lib/arcx/models/arcx_manifest.dart` | Manifest structure & serialization |
| `lib/arcx/models/arcx_result.dart` | Result types for export/import |
| `lib/arcx/services/arcx_crypto_service.dart` | Encryption, signing, key management |
| `lib/arcx/services/arcx_redaction_service.dart` | Privacy/redaction policies |
| `lib/arcx/services/arcx_migration_service.dart` | Legacy .zip to .arcx migration |
| `lib/arcx/ui/arcx_import_progress_screen.dart` | Import progress UI |
| `lib/shared/ui/settings/arcx_settings_view.dart` | Settings UI for ARCX options |
| `lib/ui/export_import/mcp_export_screen.dart` | Export screen with format selection |
| `lib/prism/services/health_service.dart` | Health data collection from HealthKit |
| `lib/arc/ui/health/health_settings_dialog.dart` | Health import dialog (30/60/90 days) |
| `ios/ARCXCrypto.swift` | iOS native crypto helpers |
| `ios/ARCXFileProtection.swift` | iOS file protection |

### Health Data File Locations

- **Source**: `mcp/streams/health/YYYY-MM.jsonl` (JSONL format, one entry per line)
- **Export in ARCX**: Copied to `payload/streams/health/YYYY-MM.jsonl`
- **Manifest storage**: Health summaries in `payload/health/` and `payload/pointer/health/`

---

## 6. Supported Features

### Encryption Options
- ✅ Device-based encryption (iOS Keychain)
- ✅ Password-based encryption (portable between devices)
- ✅ AES-256-GCM (authenticated encryption)
- ✅ PBKDF2-SHA256 key derivation

### Data Included
- ✅ All journal entries
- ✅ Photo metadata and files
- ✅ All 9 health metrics + additional vitals
- ✅ Health data streams (JSONL format)
- ✅ Health pointers and summaries
- ✅ Workouts and exercise data
- ✅ MCP manifest with integrity hashes

### Privacy/Redaction Features
- ✅ PII removal (names, emails, device IDs, IPs, locations)
- ✅ Photo label exclusion (AI descriptions)
- ✅ Timestamp clamping (date-only: YYYY-MM-DD)
- ✅ Redaction report included in manifest
- ✅ Settings persistent in SharedPreferences

### File Management
- ✅ iOS file protection (NSFileProtectionComplete)
- ✅ Secure cleanup of temporary files
- ✅ Progress callbacks during export
- ✅ File size estimation
- ✅ Export to app documents directory

### Import/Migration
- ✅ ARCX import with signature verification
- ✅ Legacy .zip to .arcx migration
- ✅ Health stream import
- ✅ Photo re-import with file path recovery

---

## 7. Limitations & Notes

### Current Limitations

1. **No UI Timeframe Selection**
   - UI always exports ALL data, not respecting 30/60/90 day scopes
   - CLI tool supports scopes, but mobile UI does not

2. **Password Encryption Disabled**
   - Code shows password encryption temporarily disabled due to hangs with large files
   - Device-based encryption is the current recommended method

3. **Health Data Constraints**
   - Health import/join only supports 30-90 day ranges
   - Depends on Apple HealthKit availability (iOS only, not simulator)
   - No Android support yet (scaffolded with mock provider)

4. **VO2 Max Not in Collection**
   - While `VO2_MAX` is requested in some health queries, it's not always available from HealthKit
   - Code checks for availability but may return null

### Data Inclusion Confirmation

**All 9 health metrics ARE included in ARCX export**:
- Health streams containing daily metrics are copied to `payload/streams/health/`
- Health pointers and summaries are copied to `payload/pointer/health/` and `payload/health/`
- The MCP manifest tracks health item counts

### Verification Method

To verify what health data was exported:
1. Unzip the .arcx file
2. Extract `archive.arcx` and decrypt (requires password or device key)
3. Examine `streams/health/YYYY-MM.jsonl` files
4. Each line is a complete daily health record in MCP format

---

## 8. Settings and Configuration

### User Configurable Options

**Export Settings** (persistent via SharedPreferences):
- `arcx_remove_pii` - Remove PII from export (default: off)
- `arcx_include_photo_labels` - Include AI photo descriptions (default: off)
- `arcx_date_only_timestamps` - Date-only timestamps (default: off)
- `arcx_secure_delete_original` - Delete original .zip after migration (default: off)

**Health Settings**:
- Import 30 days, 60 days, or 90 days of historical data
- HealthKit permission request and authorization

---

## 9. Security Considerations

### Cryptographic Security
- **AES-256-GCM**: Industry-standard authenticated encryption
- **Ed25519**: Modern elliptic curve signature scheme
- **PBKDF2-SHA256**: 600,000 iterations for password stretching (sufficient against brute force)
- **SHA-256**: Hash verification for payload integrity

### Key Management
- Device-based: Uses iOS Keychain with Secure Enclave support
- Password-based: Random salt, 600k iteration KDF
- Keys not stored in plaintext
- Temporary plaintext zip deleted after encryption

### File Protection
- iOS NSFileProtectionComplete applied to .arcx files
- Exports only readable by app
- No cloud backup of encrypted data

### Privacy by Design
- Health JSON excludes personal identifiers
- Optional PII removal before encryption
- Timestamp precision control
- Photo label filtering

---

## Conclusion

ARCX is a **production-ready secure export system** that:
1. Encrypts all user data (journal, photos, health) with AES-256-GCM
2. Includes all 9 health metrics + additional vitals in daily timeslices
3. Supports 30, 60, 90+ day export ranges (via CLI; UI exports all)
4. Provides multiple privacy redaction options before encryption
5. Uses cryptographic signatures for tamper detection
6. Integrates with iOS Keychain for secure key management

The implementation is comprehensive, well-structured, and follows security best practices for handling sensitive personal health information.

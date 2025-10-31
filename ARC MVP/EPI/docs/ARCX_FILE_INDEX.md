# ARCX Export - Complete File Index

## Investigation Documents

### Main Report
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/docs/ARCX_Export_Investigation.md**
  - Comprehensive 350+ line investigation report
  - Answers all 4 research questions in detail
  - Includes code snippets, security analysis, and diagrams

## Core ARCX Export Services

### Main Export Orchestration
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/arcx/services/arcx_export_service.dart**
  - 650+ lines, production code
  - Implements 10-step export process
  - Handles MCP bundle generation, redaction, encryption, signing

### Cryptographic Operations
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/arcx/services/arcx_crypto_service.dart**
  - AES-256-GCM encryption/decryption
  - PBKDF2-SHA256 key derivation
  - Ed25519 signing
  - iOS Keychain integration

### Privacy & Redaction
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/arcx/services/arcx_redaction_service.dart**
  - PII removal from JSON
  - Photo label stripping
  - Timestamp clamping
  - Redaction report generation

### Import Functionality
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/arcx/services/arcx_import_service.dart**
  - Signature verification
  - ARCX decryption
  - Health stream import
  - Photo path recovery

### Legacy Migration
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/arcx/services/arcx_migration_service.dart**
  - Converts legacy .zip to .arcx format
  - Data integrity preservation

## Data Models

### Manifest
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/arcx/models/arcx_manifest.dart**
  - ARCXManifest class
  - ARCXPayloadMeta class
  - JSON serialization/deserialization

### Result Types
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/arcx/models/arcx_result.dart**
  - ARCXExportResult
  - ARCXImportResult
  - ARCXMigrationResult
  - ARCXExportStats

## User Interface

### Export Screen
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/ui/export_import/mcp_export_screen.dart**
  - Format selection (legacy .zip vs secure .arcx)
  - Redaction options UI
  - Progress dialogs
  - Export statistics
  - File sharing integration

### Settings
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/shared/ui/settings/arcx_settings_view.dart**
  - ARCX configuration screen
  - PII removal toggle
  - Photo label toggle
  - Timestamp precision control
  - Legacy archive migration UI
  - About ARCX information

### Import Progress
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/arcx/ui/arcx_import_progress_screen.dart**
  - Import progress display

## Health Data Integration

### Health Service (Main)
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/prism/services/health_service.dart**
  - HealthService class: high-level API
  - HealthIngest class: batch import with 30/60/90 day options
  - Metric aggregation and normalization
  - MCP JSON format export
  - 9 health metrics + additional vitals

### Health Settings Dialog
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/arc/ui/health/health_settings_dialog.dart**
  - 30, 60, 90 day import buttons
  - HealthKit permission request
  - Import status feedback
  - Health data validation

### Health Detail View
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/arc/ui/health/health_detail_view.dart**
  - Loads from mcp/streams/health/ files
  - Aggregates last 7 days
  - Displays metrics in UI

### Health Data Models
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/prism/models/health_daily.dart**
  - HealthDaily model
  - Contains: steps, activeKcal, basalKcal, sleepMin, restingHr, avgHr, hrvSdnn, vo2max, standMin, weightKg, workouts, distance

### Health Summaries
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/prism/models/health_summary.dart**
  - HealthSummary and HealthMetrics classes

### Health Joiner/Fusion
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/prism/pipelines/prism_joiner.dart**
  - joinRange(daysBack: 30-90)
  - Fuses health with journal, keywords, phase, chrono
  - Validates 30-90 day constraint

## MCP Export Services

### MCP Pack Export
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/core/mcp/export/mcp_pack_export_service.dart**
  - Generates MCP bundle structure
  - Creates directory layout
  - Copies health streams
  - Builds ZIP packages

### MCP Schemas
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/core/mcp/models/mcp_schemas.dart**
  - McpExportScope enum (last-30-days, last-90-days, last-year, all, custom)
  - McpNode, McpEdge, McpPointer definitions
  - MCP manifest structures

## Supporting Utilities

### MCP File System
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/mcp/mcp_fs.dart**
  - healthMonth(monthKey) convenience function
  - Paths to mcp/streams/health/ files

### Health Stream Writer
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/lib/prism/services/health_service.dart**
  - writeHealthStream() function (JSONL format)

## Documentation

### Health Integration Guide
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/docs/guides/PRISM_VITAL_Health_Integration.md**
  - File map and schema details
  - PRISM-VITAL pipeline description
  - iOS HealthKit setup instructions
  - Privacy and redaction policies
  - ARCX export/import information

### Bug Tracker
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/docs/bugtracker/Bug_Tracker.md**
  - ARCX bug fixes and status
  - ARCX Image Loading Fix (January 30, 2025)

### Changelog
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/docs/changelog/CHANGELOG.md**
  - ARCX feature history
  - Health streams in ARCX exports
  - Integration milestones

## iOS Native Code

### Crypto Operations
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/ios/ARCXCrypto.swift**
  - AES-GCM encryption/decryption
  - Key management with Keychain
  - Signature verification

- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/ios/Runner/ARCXCrypto.swift**
  - Runner target copy

### File Protection
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/ios/ARCXFileProtection.swift**
  - NSFileProtectionComplete setup
  - File protection for exports

- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/ios/Runner/ARCXFileProtection.swift**
  - Runner target copy

## Configuration Files

### iOS Entitlements
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/ios/Runner/Runner.entitlements**
  - HealthKit capability configuration
  - File protection settings

### Info.plist
- Health usage descriptions (configured in app)

## Test Files

### ARCX Round-trip Test
- **/Users/mymac/Software Development/ARC/ARC MVP/EPI/test/prism_vital/prism_vital_arcx_roundtrip_test.dart**
  - Placeholder for full integration tests
  - Deferred to device environment

## Health Data Storage Locations

### Source Files (Before Export)
```
App Documents/
└── mcp/streams/health/
    ├── 2025-01.jsonl  (daily health records)
    ├── 2025-02.jsonl
    └── ...
```

### In ARCX Export
```
export_TIMESTAMP.arcx (ZIP)
├── archive.arcx (AES-256-GCM encrypted payload)
│   └── payload/
│       ├── streams/health/YYYY-MM.jsonl  (daily records)
│       ├── health/*.json                   (summaries)
│       └── pointer/health/*.json           (pointers)
└── manifest.json (Ed25519 signed metadata)
```

## Quick Reference

### Files Count
- Total ARCX-related Dart files: 20+
- Total health integration files: 8+
- iOS native files: 4
- Documentation files: 3+

### Core Implementation
- Main export service: **arcx_export_service.dart** (650+ lines)
- Key encryption service: **arcx_crypto_service.dart**
- Health integration: **health_service.dart**

### Most Important Files for Understanding Export Flow
1. arcx_export_service.dart - See 10-step export process
2. arcx_crypto_service.dart - See encryption/signing
3. health_service.dart - See health metrics collection
4. mcp_export_screen.dart - See user-facing UI
5. ARCX_Export_Investigation.md - See full analysis

---

Generated: January 30, 2025
Investigation Level: Very Thorough
Total Files Analyzed: 40+

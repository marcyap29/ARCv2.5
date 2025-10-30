# Timeline Ordering & Timestamp Inconsistencies

Date: 2025-01-21
Status: Resolved ✅
Area: Import/Export, Timeline sorting

Summary
- Inconsistent timestamp formats led to incorrect ordering on timeline and import/export issues.

Impact
- Entries out of order; parsing failures for malformed timestamps.

Root Cause
- Mixed timestamp formats; missing 'Z' UTC suffix in some exports.

Fix
- Standardize to ISO 8601 UTC with 'Z' in export (`_formatTimestamp`).
- Robust import parser with fallbacks (`_parseTimestamp`).

Files
- `lib/arcx/services/arcx_export_service.dart`
- `lib/arcx/services/arcx_import_service.dart`

Verification
- Timeline orders correctly; exports valid; imports handle legacy data.

References
- `docs/bugtracker/Bug_Tracker.md` (Timeline Ordering & Timestamp Fixes)


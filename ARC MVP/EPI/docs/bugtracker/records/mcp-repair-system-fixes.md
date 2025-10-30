# MCP Repair System Issues Resolved

Date: 2025-01-17
Status: Resolved ✅
Area: MCP export/repair

Summary
- Multiple MCP repair defects: chat/journal separation, over-aggressive duplicate removal, schema/manifest errors, checksum mismatches.

Impact
- Corrupted/merged data, lost legitimate entries, failing validations, unreliable share artifacts.

Fix
- Proper chat vs journal separation.
- Duplicate detection logic corrected (aggressiveness reduced from 84% → 0.6%).
- Schema and manifest validations corrected; checksums repaired.
- Unified repair UI with detailed share sheet summary.
- iOS file saving fixed to accessible Documents directory.

Verification
- Repaired packages validate; entries restored correctly; share sheet shows accurate repair summary.

References
- `docs/bugtracker/Bug_Tracker.md` (MCP Repair System Issues Resolved)


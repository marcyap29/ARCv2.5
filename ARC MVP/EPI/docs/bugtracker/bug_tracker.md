# EPI MVP - Bug Tracker

**Version:** 3.2.2  
**Last Updated:** January 31, 2026  
**Record count:** 28 individual bug records in [records/](records/). Index below matches all files in records/.

---

## How to use this tracker

- **Index:** Use the sections below to find bugs by category (LUMARA, Timeline & UI, Export/Import, etc.). Each entry links to a detailed record in `records/`.
- **Recent code changes:** Table derived from repo and [CHANGELOG.md](../CHANGELOG.md) – use it to see which fixes have bug records and which might need new records.
- **Archive:** Legacy bug tracker files (Bug_Tracker-1.md through Bug_Tracker-9.md) are in [archive/](archive/).

---

## Bug Tracker Index

This bug tracker has been split into parts for easier navigation:

| Part | Coverage | Description |
|------|----------|-------------|
| **[bug_tracker_part1.md](bug_tracker_part1.md)** | Dec 2025 | v2.1.43 - v2.1.60 (Recent) |
| **[bug_tracker_part2.md](bug_tracker_part2.md)** | Nov 2025 | v2.1.27 - v2.1.42 |
| **[bug_tracker_part3.md](bug_tracker_part3.md)** | Jan-Oct 2025 | v2.0.0 - v2.1.26 & Earlier |

---

## Individual Bug Records

Detailed bug reports are available in the [records/](records/) directory:

### LUMARA Issues
- [lumara-temporal-context-incorrect-dates.md](records/lumara-temporal-context-incorrect-dates.md) - **HIGH:** Incorrect date references in reflections (v3.2.2) ✅ RESOLVED
- [gemini-api-empty-user-string.md](records/gemini-api-empty-user-string.md) - **CRITICAL:** Empty user string rejection in journal reflections (v3.2.2) ✅ RESOLVED
- [lumara-user-prompt-override.md](records/lumara-user-prompt-override.md) - **CRITICAL:** User prompt overriding master prompt constraints (v3.0) ✅ RESOLVED
- [lumara-response-cutoff.md](records/lumara-response-cutoff.md) - Response truncation issues
- [lumara-subject-drift-and-repetitive-endings.md](records/lumara-subject-drift-and-repetitive-endings.md) - Subject focus and ending phrase issues
- [lumara-integration-formatting.md](records/lumara-integration-formatting.md) - Formatting and integration bugs
- [lumara-settings-refresh-loop.md](records/lumara-settings-refresh-loop.md) - Settings refresh issues

### Timeline & UI Issues
- [timeline-infinite-rebuild-loop.md](records/timeline-infinite-rebuild-loop.md) - Timeline rebuild performance
- [timeline-ordering-timestamps.md](records/timeline-ordering-timestamps.md) - Entry ordering issues
- [timeline-overflow-empty-state.md](records/timeline-overflow-empty-state.md) - Empty state display
- [ui-ux-critical-fixes-jan-08-2025.md](records/ui-ux-critical-fixes-jan-08-2025.md) - Critical UI/UX fixes
- [ui-ux-fixes-jan-2025.md](records/ui-ux-fixes-jan-2025.md) - General UI/UX improvements
- [lumara-ui-overlap-stripe-auth-fixes.md](records/lumara-ui-overlap-stripe-auth-fixes.md) - LUMARA UI overlap and Stripe auth fixes

### Export/Import Issues
- [arcx-export-photo-directory-mismatch.md](records/arcx-export-photo-directory-mismatch.md) - Photo directory structure
- [arcx-import-date-preservation.md](records/arcx-import-date-preservation.md) - Date preservation during import
- [ios-folder-verification-permission-error.md](records/ios-folder-verification-permission-error.md) - **HIGH:** iOS folder verification permission error (v3.2.2) ✅ RESOLVED
- [mcp-repair-system-fixes.md](records/mcp-repair-system-fixes.md) - MCP repair system issues

### Data & Storage Issues
- [hive-initialization-order.md](records/hive-initialization-order.md) - Hive initialization problems
- [mediaitem-adapter-registration-conflict.md](records/mediaitem-adapter-registration-conflict.md) - MediaItem adapter conflicts
- [photo-duplication-view-entry.md](records/photo-duplication-view-entry.md) - Photo duplication bugs

### API & Integration Issues
- [gemini-api-empty-user-string.md](records/gemini-api-empty-user-string.md) - **CRITICAL:** Empty user string rejection in journal reflections ✅ RESOLVED
- [vision-api-integration-ios.md](records/vision-api-integration-ios.md) - Vision API iOS integration
- [wispr-flow-cache-issue.md](records/wispr-flow-cache-issue.md) - **MEDIUM:** Wispr Flow API key cached; new key not used until restart ✅ RESOLVED

### Subscription & Payment Issues
- [stripe-checkout-unauthenticated.md](records/stripe-checkout-unauthenticated.md) - **CRITICAL:** Cloud Run IAM blocking Stripe checkout ✅ RESOLVED
- [stripe-subscription-critical-fixes.md](records/stripe-subscription-critical-fixes.md) - Stripe subscription critical fixes

### Feature-Specific Issues
- [constellation-zero-stars-display.md](records/constellation-zero-stars-display.md) - Constellation visualization
- [draft-creation-unwanted-drafts.md](records/draft-creation-unwanted-drafts.md) - Draft management
- [journal-editor-issues.md](records/journal-editor-issues.md) - Journal editor bugs
- [phase-analysis-integration-bugs.md](records/phase-analysis-integration-bugs.md) - Phase analysis integration
- [rivet-deterministic-recompute.md](records/rivet-deterministic-recompute.md) - RIVET computation issues
- [vision-api-integration-ios.md](records/vision-api-integration-ios.md) - Vision API iOS integration

---

## Recent code changes (reference for bug tracker)

This section is derived from the repo and [CHANGELOG.md](../CHANGELOG.md) to keep the bug tracker aligned with recent fixes. Use it for triage and to add new records when appropriate.

| Fix / change | Version | Bug record | Notes |
|--------------|---------|------------|--------|
| iOS folder verification permission error | v3.3.13 | [ios-folder-verification-permission-error.md](records/ios-folder-verification-permission-error.md) ✅ | Security-scoped resource access on iOS for VerifyBackupScreen |
| Phase Quiz result not persisting; Phase tab mismatch | v3.3.13 | — | Quiz result now persisted via UserPhaseService; Phase tab uses quiz phase when no regimes. See CHANGELOG [3.3.13] "Phase Quiz result matches Phase tab". |
| llama.xcframework build / simulator | recent | — | Link llama static library directly; device build search paths; simulator stubs; exclude xcframework from simulator. Build/config fixes. |
| Import status bar, mini bar, per-file status | v3.3.13 | — | Feature; not a bug. See CHANGELOG. |
| Wispr Flow cache – new API key not used until restart | v3.3.13 | [wispr-flow-cache-issue.md](records/wispr-flow-cache-issue.md) ✅ | WisprConfigService cached key; fix: clearCache() on save in Settings. |

**Source:** `git log --oneline`, [CHANGELOG.md](../CHANGELOG.md). Last synced: 2026-01-31.

---

## Archive

Historical bug tracker files are archived in [archive/](archive/):
- Legacy bug tracker files (Bug_Tracker-1.md through Bug_Tracker-9.md)
- Older bug tracker versions

Individual bug records stay in [records/](records/); only the legacy multi-part tracker files are in archive.

---

**Status**: ✅ Active - All resolved issues documented  
**Last Updated**: January 31, 2026

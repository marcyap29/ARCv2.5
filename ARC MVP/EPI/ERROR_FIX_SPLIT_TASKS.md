# Error Fix Task Split - 310 Remaining Errors

## Current Status
- **Total Errors**: 310
- **Started from**: 322 errors
- **Fixed so far**: 12 errors
- **Target**: ~200 errors (halfway point)

## Task Distribution

### Agent 1: Test Files (Priority: High)
**Focus**: Fix errors in test files (~150+ errors)

**Primary Files** (highest error counts):
1. `test/mira/memory/enhanced_memory_test_suite.dart` - 37 errors
2. `test/mcp/chat_mcp_test.dart` - 34 errors
3. `test/integration/mcp_photo_roundtrip_test.dart` - 23 errors
4. `test/mira/memory/security_red_team_tests.dart` - 17 errors
5. `test/mcp/phase_regime_mcp_test.dart` - 12 errors
6. `test/mcp/export/chat_exporter_test.dart` - 11 errors
7. `test/rivet/validation/rivet_storage_test.dart` - 10 errors
8. `test/mira/memory/run_memory_tests.dart` - 10 errors
9. `test/data/models/arcform_snapshot_test.dart` - 9 errors
10. `test/services/phase_regime_service_test.dart` - 6 errors
11. `test/mcp/cli/mcp_import_cli_test.dart` - 6 errors
12. `test/mcp/chat_journal_separation_test.dart` - 6 errors
13. `test/integration/aurora_integration_test.dart` - 6 errors
14. `test/veil_edge/rivet_policy_circadian_test.dart` - 5 errors
15. `test/mira/memory/memory_system_integration_test.dart` - 5 errors
16. `test/mcp/integration/mcp_integration_test.dart` - 5 errors

**Common Issues to Fix**:
- Import path corrections (`prism/mcp/...` → `core/mcp/...`)
- `McpNode` constructor calls (need `DateTime` timestamp, `McpProvenance`)
- `JournalEntry` constructor calls (need `updatedAt`, `tags`)
- `ChatMessage`/`ChatSession` API updates
- Mock implementations for `ChatRepo` and other interfaces
- Type mismatches in test data

**Commands**:
```bash
cd "/Users/mymac/Software Development/ARC/ARC MVP/EPI"
dart analyze test/ 2>&1 | grep "error -" | head -30
```

---

### Agent 2: Core Library Files (Priority: High)
**Focus**: Fix errors in lib/ directory (~100+ errors)

**Primary Files**:
1. `lib/ui/import/import_bottom_sheet.dart` - 8 errors
2. `lib/ui/journal/journal_screen.dart` - 7 errors
3. `lib/ui/widgets/mcp_export_dialog.dart` - 5 errors
4. `lib/core/mcp/models/media_pack_metadata.dart` - Fix null-safety for `lastAccessedAt`
5. `lib/echo/config/echo_config.dart` - Fix `currentProvider` final assignment
6. `lib/epi_module.dart` - Fix ambiguous `RivetConfig` export
7. `lib/lumara/chat/multimodal_chat_service.dart` - Fix provenance type (Map vs String), ambiguous imports
8. `lib/lumara/llm/providers/rule_based_provider.dart` - Fix `ruleBased` enum constant
9. `lib/lumara/llm/testing/lumara_test_harness.dart` - Fix `isModelAvailable` method
10. `lib/lumara/ui/widgets/download_progress_dialog.dart` - Fix null-safety
11. `lib/lumara/ui/widgets/memory_notification_widget.dart` - Fix `Icons.cycle` (use `Icons.refresh` or similar)
12. `lib/lumara/veil_edge/services/veil_edge_service.dart` - Fix `Future.toJson()` (need await)
13. `lib/policy/transition_integration_service.dart` - Fix `JournalEntryData` vs `ReflectiveEntryData`
14. `lib/prism/processors/import/media_import_service.dart` - Fix `WhisperStubTranscribeService` method
15. `lib/services/media_pack_tracking_service.dart` - Already fixed `getPacksOlderThan` Duration issue
16. `lib/shared/ui/settings/mcp_bundle_health_view_old.dart` - Check for remaining issues
17. `lib/shared/ui/settings/mcp_bundle_health_view_updated.dart` - Check for issues
18. `lib/shared/ui/settings/mcp_settings_cubit.dart` - Check for issues
19. `lib/ui/export_import/mcp_import_screen.dart` - Check for issues
20. `lib/ui/journal/widgets/enhanced_lumara_suggestion_sheet.dart` - Check for issues
21. `lib/ui/settings/storage_profile_settings.dart` - Check for issues
22. `lib/ui/widgets/ai_enhanced_text_field.dart` - Check for issues

**Common Issues to Fix**:
- Type mismatches (`Map<String, dynamic>?` vs `String?` for provenance)
- Ambiguous imports (use `as` prefix or hide)
- Missing enum constants
- Final variable assignments
- Null-safety issues
- Missing methods/getters

**Commands**:
```bash
cd "/Users/mymac/Software Development/ARC/ARC MVP/EPI"
dart analyze lib/ 2>&1 | grep "error -" | head -30
```

---

### Agent 3: Generated Files & Coordination (Current Agent)
**Focus**: Fix generated files and coordinate remaining fixes (~60+ errors)

**Tasks**:
1. Fix remaining generated file issues (`.g.dart` files)
2. Fix `lib/core/mcp/models/media_pack_metadata.dart` - null-safety for `lastAccessedAt` in `getPacksOlderThan`
3. Coordinate with other agents on shared fixes
4. Handle any remaining high-priority blockers
5. Verify fixes don't break other parts

**Note**: Generated files (`.g.dart`) may need regeneration with `dart run build_runner build` after fixing source files.

---

## Shared Context & Recent Fixes

### Already Fixed:
- ✅ Removed duplicate `MediaStore`/`MediaSanitizer` classes from `photo_relink_prompt.dart`
- ✅ Fixed `CircadianContext.isRhythmFragmented` getter
- ✅ Added `MediaPackRegistry.activePacks`, `archivedPacks`, `getPacksOlderThan` methods
- ✅ Added `ChatMessage.create` factory method
- ✅ Fixed `EvidenceSource` enum switch cases in generated file
- ✅ Fixed `chat_analysis_service.dart` null-safety for `contentParts`
- ✅ Fixed `VeilAuroraScheduler.stop()` void return issue

### Key APIs to Reference:
- `ChatMessage.create()` - Factory accepts `sessionId`, `role`, `contentParts`, `provenance` (String?), `metadata`
- `MediaPackMetadata.lastAccessedAt` - DateTime? (nullable)
- `CircadianContext.isRhythmFragmented` - bool getter (available)
- `EvidenceSource` enum - includes: `draft`, `lumaraChat`, `journal`, `chat`, `media`, `arcform`, `phase`, `system`

---

## Progress Tracking

### Agent 1 Progress:
- [ ] Enhanced memory test suite
- [ ] Chat MCP tests
- [ ] Photo roundtrip tests
- [ ] Other test files

### Agent 2 Progress:
- [ ] UI files (import_bottom_sheet, journal_screen, etc.)
- [ ] Core service files
- [ ] Configuration files
- [ ] Widget files

### Agent 3 Progress:
- [x] Initial fixes completed
- [ ] Media pack metadata null-safety
- [ ] Generated file coordination
- [ ] Final verification

---

## Verification

After fixes, run:
```bash
cd "/Users/mymac/Software Development/ARC/ARC MVP/EPI"
dart analyze 2>&1 | grep -c "error -"
```

Target: Reduce from 310 to ~200 errors (halfway point).


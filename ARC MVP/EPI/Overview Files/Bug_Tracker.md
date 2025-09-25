# Bug Tracker Notes

## 2025-09-24 — Insights System Fix Complete ✅
- ✅ **Critical Issue Resolved**: Fixed insights system showing "No insights yet" despite having journal data
- ✅ **Keyword Extraction Fix**: Fixed McpNode.fromJson to extract keywords from content.keywords field instead of top-level keywords
- ✅ **Rule Evaluation Fix**: Corrected mismatch between rule IDs (R1_TOP_THEMES) and template keys (TOP_THEMES) in switch statements
- ✅ **Template Parameter Fix**: Fixed _createCardFromRule switch statement to use templateKey instead of rule.id
- ✅ **Rule Thresholds**: Lowered insight rule thresholds for better triggering with small datasets
- ✅ **Missing Rules**: Added missing rule definitions for TOP_THEMES and STUCK_NUDGE
- ✅ **Null Safety**: Fixed null safety issues in arc_llm.dart and llm_bridge_adapter.dart
- ✅ **MCP Schema**: Updated MCP schema constructors with required parameters
- ✅ **Test Files**: Fixed test files to use correct JournalEntry and MediaItem constructors
- ✅ **Result**: Insights tab now shows 3 actual insight cards with real data instead of placeholders
- ✅ **Your Patterns**: Submenu displays all imported keywords correctly in circular pattern

**Key Files Modified:**
- `lib/mcp/models/mcp_schemas.dart` - Fixed keyword extraction from content.keywords
- `lib/insights/insight_service.dart` - Fixed rule evaluation and template parameter logic
- `lib/core/arc_llm.dart` - Fixed null safety issues
- `lib/services/llm_bridge_adapter.dart` - Fixed null safety issues
- `test/mcp/import/mcp_import_service_test.dart` - Updated test constructors
- `test/mcp_exporter_golden_test.dart` - Fixed JournalEntry and MediaItem constructors

**Architecture:** Insights system now properly extracts keywords from MCP import data, evaluates rules correctly, and generates actual insight cards with real data instead of placeholders.

## 2025-09-24 — MIRA Insights Implementation Complete ✅
- ✅ **Mixed-Version MCP Support**: Created golden bundle (`mcp_chats_2025-09_mixed_versions`) with node.v1 journals + node.v2 chat records
- ✅ **Chat Ingestion Layer**: Implemented `ChatIngest` and `ChatGraphBuilder` for converting chat models to MIRA nodes
- ✅ **Enhanced MCP Adapter**: Completed `MiraToMcpAdapter` supporting both node.v1 (legacy) and node.v2 (chat) formats with proper routing
- ✅ **Chat Metrics Integration**: Built `ChatMetricsService` and `EnhancedInsightService` wiring chat activity into the Insights system
- ✅ **Comprehensive Testing**: Added `mixed_version_test.dart` with AJV-ready validation for both schema versions - **ALL TESTS PASSING (6/6)**
- ✅ **Node Compatibility Fixed**: Resolved ChatSessionNode, ChatMessageNode, and ContainsEdge to properly extend MiraNode/MiraEdge classes
- ✅ **Repository Recovery**: Successfully repaired git corruption and restored all development work

**Key Components Added:**
- `lib/mcp/adapters/to_mcp.dart` - Full mixed-version adapter
- `lib/mira/insights/chat_metrics_service.dart` - Chat analytics
- `lib/mira/insights/enhanced_insight_service.dart` - Combined journal+chat insights
- `test/mcp/integration/mixed_version_test.dart` - Validation suite

**Architecture:** MIRA now supports both legacy journal entries (node.v1) and modern chat sessions (node.v2) in the same export bundles, maintaining backward compatibility while enabling rich chat-based insights.

## 2025-09-25 — LUMARA Context Provider Phase Detection Fix ✅
- ✅ **Critical Issue Resolved**: Fixed LUMARA reporting "Based on 1 entries" instead of showing all 3 journal entries with correct phases
- ✅ **Root Cause Analysis**: Journal entries had phases detected by Timeline content analysis but NOT stored in entry.metadata['phase']
- ✅ **Content Analysis Integration**: Added same phase analysis logic used by Timeline to LUMARA context provider
- ✅ **Fallback Strategy**: Updated context provider to check entry.metadata['phase'] first, then analyze from content using _determinePhaseFromContent()
- ✅ **Phase History Fix**: Updated phase history extraction to process ALL entries using content analysis instead of filtering for metadata-only
- ✅ **Enhanced Debug Logging**: Added logging to show whether phases come from metadata vs content analysis
- ✅ **Timeline Integration**: Confirmed Timeline already correctly persists user manual phase updates to entry.metadata['phase']
- ✅ **Result**: LUMARA now correctly reports "Based on 3 entries" with accurate phase history (Transition, Discovery, Breakthrough)

**Key Files Modified:**
- `lib/lumara/data/context_provider.dart` - Added content analysis methods and updated phase detection logic
- `lib/features/home/home_view.dart` - Removed const from ContextProvider
- `lib/app/app.dart` - Removed const from ContextProvider

**Technical Details:**
- Added _determinePhaseFromContent(entry) and _determinePhaseFromText(content) methods
- Updated phase detection: entry.metadata?['phase'] ?? _determinePhaseFromContent(entry)
- Phase history now processes all entries instead of filtering for metadata-only
- Same phase analysis logic as Timeline: Discovery, Expansion, Transition, Consolidation, Recovery, Breakthrough

**Architecture:** LUMARA context provider now has full access to journal entries and phases through both metadata (user manual updates) and content analysis fallback (automatic detection), ensuring accurate phase history reporting.

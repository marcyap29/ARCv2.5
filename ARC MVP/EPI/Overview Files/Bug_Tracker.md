# Bug Tracker Notes

## 2025-09-25 — Gemini API Integration Fix Complete ✅
- ✅ **Deprecated Model Update**: Updated from deprecated `gemini-1.5-flash` to current `gemini-1.5-pro` model
- ✅ **Debug Logging System**: Added comprehensive debug logging for API troubleshooting and monitoring
- ✅ **LUMARA Integration**: Fixed LUMARA assistant Gemini API connectivity
- ✅ **Error Resolution**: Resolved 404 "model not found" errors that were causing fallback to rule-based responses
- ✅ **Rate Limit Handling**: Graceful handling of API rate limits with proper fallback mechanism
- ✅ **API Key Validation**: Verified API key format and access permissions are working correctly

**Root Cause Analysis:**
- **Issue**: Application was using deprecated `gemini-1.5-flash` model causing 404 errors
- **Symptom**: LUMARA always falling back to rule-based responses instead of using Gemini
- **Debug Process**: Added comprehensive logging to track API calls, requests, and responses
- **Solution**: Updated to `gemini-1.5-pro` model with enhanced error handling

**Key Files Modified:**
- `lib/services/gemini_send.dart` - Updated model endpoint and added debug logging system

**Technical Implementation:**
- Updated endpoint from `gemini-1.5-flash` to `gemini-1.5-pro`
- Added debug logging for API key validation, request/response tracking, and error analysis
- Enhanced error messages with detailed HTTP status codes and response bodies
- Maintained graceful fallback to rule-based responses when API limits are exceeded

**Integration Status:**
- ✅ **API Integration Working**: Gemini API now successfully connects and processes requests
- ✅ **Rate Limiting Handled**: Proper 429 error handling with fallback to rule-based responses
- ✅ **Debug Capabilities**: Comprehensive logging for future API troubleshooting
- ✅ **LUMARA Functional**: Assistant now uses Gemini when API quota allows
- ✅ **Production Ready**: Robust error handling ensures app continues working during API limits

## 2025-09-25 — RIVET Phase Change Interface Simplification Complete ✅
- ✅ **UI/UX Simplification**: Redesigned Phase Change Safety Check with intuitive single progress ring interface
- ✅ **Simplified Language**: Replaced technical jargon ("ALIGN", "TRACE") with user-friendly "Phase Change Readiness" terminology
- ✅ **Single Progress Ring**: Combined 4 complex metrics into one clear readiness percentage (0-100%)
- ✅ **Clear Status Messages**: Intuitive status indicators - "Ready to explore a new phase", "Almost ready", "Keep journaling"
- ✅ **Color-Coded Feedback**: Green (Ready 80%+), Orange (Almost 60-79%), Red (Not Ready <60%) for instant understanding
- ✅ **Comprehensive Refresh Mechanism**: Multi-trigger refresh system for real-time RIVET state updates
- ✅ **MCP Import Integration**: Added RIVET event creation for imported journal entries to update progress
- ✅ **Enhanced Debugging**: Extensive logging system for troubleshooting RIVET state and refresh issues

**Key Features Implemented:**
- Simplified _RivetCard with single progress ring and clear status messaging
- Weighted scoring system combining ALIGN (30%), TRACE (30%), sustainment (25%), independence (15%)
- GlobalKey-based refresh mechanism for parent-child communication
- MCP import service integration with _createRivetEventForEntry() method
- Comprehensive debug logging for RIVET state loading and refresh tracking

**User Experience Improvements:**
- **1-3 Second Understanding**: Users immediately grasp their phase change readiness
- **Reduced Cognitive Load**: One metric instead of 4 complex technical indicators
- **Intuitive Language**: No technical jargon, clear actionable messages
- **Real-time Updates**: RIVET progress reflects latest journal entries and imports
- **Encouraging Tone**: Motivates continued journaling with positive messaging

**Files Modified:**
- `lib/features/home/home_view.dart` - Simplified RIVET card UI, refresh mechanism, GlobalKey communication
- `lib/mcp/import/mcp_import_service.dart` - RIVET event creation for imported entries
- `lib/core/i18n/copy.dart` - Updated copy with user-friendly terminology

**Architecture:** Transformed technical RIVET safety check into intuitive Phase Change Readiness interface with real-time updates, simplified metrics, and clear user guidance for phase transitions.

**Integration Status:**
- ✅ **Simplified UI Active**: Clean, intuitive progress ring interface replacing complex dual dials
- ✅ **Real-time Updates**: RIVET progress reflects MCP imports and new journal entries
- ✅ **Enhanced Debugging**: Comprehensive logging system for troubleshooting
- ✅ **User-friendly Copy**: Accessible language replacing technical terminology
- ✅ **Production Ready**: All functionality tested with extensive debug capabilities

## 2025-09-25 — UI/UX Update with Roman Numeral 1 Tab Bar Complete ✅
- ✅ **Starting Screen Optimization**: Changed default tab from Journal to Phase for immediate access to core functionality
- ✅ **Journal Tab Redesign**: Replaced Journal tab with "+" icon for intuitive "add new entry" action
- ✅ **Roman Numeral 1 Shape**: Created elevated "+" button above tab bar for prominent primary action
- ✅ **Tab Bar Optimization**: Reduced height, padding, and icon sizes for better space utilization
- ✅ **Your Patterns Priority**: Moved Your Patterns card to top of Insights tab for better visibility
- ✅ **Mini Radial Icon**: Added custom mini radial visualization icon to Your Patterns card
- ✅ **Phase-Based Flow Logic**: Implemented smart flow: no phase → phase quiz, has phase → main menu
- ✅ **Perfect Positioning**: Elevated button with optimal spacing and no screen edge cropping
- ✅ **Enhanced Usability**: Larger tap targets, better visual hierarchy, cleaner interface
- ✅ **Production Ready**: All functionality tested, no breaking changes, seamless integration

**Key Features Implemented:**
- CustomTabBar with elevatedTabIndex parameter for roman numeral 1 shape
- _buildRomanNumeralOneShape() method with elevated circular button above main tab bar
- Phase-based startup flow logic in startup_view.dart
- MiniRadialPainter for Your Patterns card visual recognition
- Optimized tab sizing and spacing for perfect UI/UX balance

**Files Modified:**
- `lib/features/home/home_view.dart` - Tab reordering, Your Patterns priority, mini radial icon
- `lib/shared/tab_bar.dart` - Roman numeral 1 shape implementation with elevated button
- `lib/features/startup/startup_view.dart` - Phase-based flow logic

**Architecture:** UI/UX update creates intuitive navigation with prominent primary action button, optimized space usage, and enhanced user experience through better visual hierarchy and flow logic.

**Integration Status:**
- ✅ **Live in Production**: All UI/UX improvements active and functional
- ✅ **Zero Breaking Changes**: Seamless integration with existing functionality
- ✅ **Optimized Performance**: Reduced bottom bar height for better space utilization
- ✅ **Enhanced Usability**: Better tap targets and visual hierarchy
- ✅ **Documentation Complete**: All overview files updated with implementation details

## 2025-09-25 — Your Patterns Visualization System Complete ✅
- ✅ **Comprehensive Visualization System**: Implemented 4 distinct visualization views (Word Cloud, Network Graph, Timeline, Radial)
- ✅ **Force-Directed Network Graph**: Integrated graphview package with FruchtermanReingoldAlgorithm for physics-based layout
- ✅ **Curved Edges Implementation**: Custom Bezier curve painter with arrowheads, weight indicators, and smooth transitions
- ✅ **Phase Icons & Selection**: Added ATLAS phase icons (Discovery, Expansion, Transition, etc.) with interactive selection highlighting
- ✅ **MIRA Integration**: Co-occurrence matrix adapter converts semantic memory data to visualization nodes and edges
- ✅ **Interactive Filtering**: Dynamic filtering by emotion, phase, and time range with real-time data updates
- ✅ **Visual Enhancements**: Emotion-based color coding, dynamic node sizing, neighbor opacity filtering, animated containers
- ✅ **Testing & Compilation**: Full analysis passed with only minor deprecation warnings, ready for production

**Key Features Implemented:**
- InteractiveViewer with zoom/pan navigation and boundary constraints
- CustomPainter for curved edges with quadratic Bezier curves and control points
- Neighbor highlighting with opacity-based filtering and selection states
- Sparkline trend visualization in detailed keyword analysis sheets
- MockData generator with comprehensive keyword relationships and time series
- CoOccurrenceMatrixAdapter for seamless MIRA semantic data integration

**Files Created:**
- `lib/features/insights/your_patterns_view.dart` - Complete visualization system (1200+ lines)

**Dependencies Added:**
- `graphview: ^1.2.0` - Force-directed graph layouts and physics simulation

**Architecture:** Your Patterns provides rich, interactive exploration of keyword patterns with multiple visualization paradigms, semantic memory integration, and comprehensive filtering capabilities.

**Integration Status:**
- ✅ **Live in Insights Tab**: "Your Patterns" card navigates to new comprehensive visualization system
- ✅ **Legacy Code Cleanup**: Removed deprecated MiraGraphView and InsightsScreen (965+ lines of unused code)
- ✅ **Zero Breaking Changes**: Seamless integration with existing UI and navigation flow
- ✅ **Production Ready**: All functionality tested and fully operational
- ✅ **Documentation Complete**: All overview files updated with implementation details

## 2025-09-25 — Phase Selector Redesign Complete ✅
- ✅ **Phase Geometry Display Issues**: Fixed nodes not recreating with correct geometry when changing phases
- ✅ **Geometry Pattern Conflicts**: Resolved conflicts between different phase layouts (spiral, flower, branch, weave, glowCore, fractal)
- ✅ **Edge Generation Fix**: Corrected edge generation to match specific geometry patterns instead of generic cross-connections
- ✅ **Phase Cache Synchronization**: Fixed phase cache refresh to maintain sync between displayed phase and geometry
- ✅ **UI/UX Redesign**: Replaced old Change Phase dialog with interactive 3D geometry selector
- ✅ **Live Preview System**: Implemented phase preview functionality - click phase names to see geometry previews instantly
- ✅ **Save Confirmation**: Added "Save this phase?" button that appears when phase is selected for preview
- ✅ **Success Message Fix**: Fixed success message to show actual phase name instead of "null"
- ✅ **Hidden Geometry Box**: 3D Arcform Geometry box now hidden by default, only appears when "Change" button is clicked

**Key Files Modified:**
- `lib/features/arcforms/arcform_renderer_cubit.dart` - Fixed geometry recreation in changeGeometry, explorePhaseGeometry, and changePhaseAndGeometry methods
- `lib/features/arcforms/arcform_renderer_view.dart` - Replaced old dialog with new phase selector system
- `lib/features/arcforms/widgets/simple_3d_arcform.dart` - Added conditional geometry selector with preview functionality

**Architecture:** Phase selector now provides intuitive way to explore different phase geometries before committing to change, with proper visual previews and confirmation flow.

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

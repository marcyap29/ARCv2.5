ate# EPI MVP Install Guide (Main MVP – Gemini API)

This guide installs and runs the full MVP. The app uses Gemini via the LLMRegistry. If no key is provided (or the API fails), it falls back to the rule‑based client.

## 🌟 New Features (January 22, 2025)

### RIVET Sweep Phase System
- **Timeline-Based Phases**: Phases are now timeline segments rather than entry-level labels
- **Automated Phase Detection**: RIVET Sweep algorithm automatically detects phase transitions
- **MCP Phase Export/Import**: Full compatibility with phase regimes in MCP bundles
- **Chat History Support**: LUMARA chat histories fully supported in MCP bundles
- **Phase Timeline UI**: Visual timeline interface for phase management and editing
- **Backward Compatibility**: Legacy phase fields preserved during migration
- **Build System**: All compilation errors resolved, iOS build successful
- **Production Ready**: Complete implementation with comprehensive testing

### SENTINEL UI Integration (January 22, 2025)
- **SENTINEL Analysis Tab**: New 4th tab in Phase Analysis View for emotional risk detection
- **Risk Level Visualization**: Color-coded risk assessment with circular progress indicators
- **Pattern Detection Cards**: Expandable cards showing detected emotional patterns
- **Time Window Selection**: 7-day, 14-day, 30-day, and 90-day analysis windows
- **Actionable Recommendations**: Contextual suggestions based on risk analysis
- **Safety Disclaimers**: Clear medical disclaimers and professional help guidance
- **Comprehensive Help System**: Dedicated RIVET and SENTINEL explanation tabs
- **Privacy-First Design**: All analysis happens on-device with no data transmission

### 3D Constellation ARCForms Enhancement (January 22, 2025)
- **Constellation Display Fix**: Fixed critical "0 Stars" issue - constellations now properly display after phase analysis
- **Static Constellation Display**: Fixed spinning issue - constellations now appear as stable star formations
- **Manual 3D Controls**: Users can manually rotate and explore 3D space with intuitive gestures
- **Phase-Specific Layouts**: Different 3D arrangements for each phase (Discovery helix, Recovery cluster, etc.)
- **Sentiment Colors**: Warm/cool colors based on emotional valence with deterministic variations
- **Connected Stars**: All nodes connected with lines forming real constellation patterns
- **Individual Star Twinkling**: Each star twinkles at different times (10-second cycle, 15% size variation)
- **Keyword Labels**: Keywords visible above each star with white text and dark background
- **Colorful Connecting Lines**: Lines blend colors of connected stars based on sentiment
- **Enhanced Glow Effects**: Outer, middle, and inner glow layers for realistic star appearance
- **Smooth Rotation**: Reduced rotation sensitivity for better control and user experience
- **Performance Optimized**: Removed unnecessary animations and calculations

## Prerequisites
- Flutter 3.35+ (stable)
- Xcode (iOS) and/or Android SDK
- Gemini API key from Google AI Studio

## One‑time setup
```bash
cd "/Users/mymac/Software Development/EPI/ARC MVP/EPI"
flutter clean
flutter pub get
flutter doctor
```

## Run the full MVP

### **With On-Device LLM (Migration In Progress)**
> **Status:** llama.cpp + Metal + GGUF integration migrated from MLX but has critical issues blocking inference. App builds and runs but falls back to rule-based responses.

- **Debug (runs with llama.cpp issues + Gemini 2.5 Flash cloud fallback)**:
```bash
flutter run -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY
```
- **Without API key (on-device only - currently falls back to rule-based responses)**:
```bash
flutter run -d DEVICE_ID
```
  **⚠️ NOTE**: Currently falls back to Enhanced LUMARA API with rule-based responses due to llama.cpp initialization issues. On-device inference not working yet.

### **Enhanced Model Download Features** ✅ **NEW**
- **Comprehensive macOS Compatibility**: Enhanced model download system with automatic exclusion of all macOS metadata files (`_MACOSX`, `.DS_Store`, `._*`)
- **Proactive Cleanup**: Removes existing metadata before downloads to prevent conflicts
- **Conflict Prevention**: Prevents file conflicts that cause "file already exists" errors
- **Automatic Cleanup**: Removes all macOS metadata files (`_MACOSX`, `.DS_Store`, `._*`) automatically
- **Model Management**: `clearAllModels()` and `clearModelDirectory()` methods for comprehensive cleanup
- **In-App Deletion**: Enhanced cleanup when models are deleted through the app interface
- **Reliable Extraction**: Robust ZIP extraction process with comprehensive error handling
- **Progress Tracking**: Real-time download progress with detailed status messages

### **Provider Selection Features** ✅ **NEW**
- **Manual Provider Selection**: Go to LUMARA Settings → AI Provider Selection to manually choose providers
- **Visual Provider Status**: Clear indicators showing which providers are available and selected
- **Automatic Selection**: Option to let LUMARA automatically choose the best available provider
- **Model Activation**: Download models and manually activate them for on-device inference
- **Consistent Detection**: Unified model detection across all systems

### **On-Device LLM Features** ✅ **NEW**
- **Real Qwen3-1.7B Model**: 914MB model bundled in app, loads with progress reporting
- **Privacy-First**: All inference happens locally, no data sent to external servers
- **Fallback System**: On-Device → Cloud API → Rule-Based responses
- **Progress UI**: Real-time loading progress (0% → 100%) during model initialization
- **Metal Acceleration**: Native iOS Metal support for optimal performance

### **Journal Features** ✅ **NEW**
- **Automatic Text Clearing**: Journal text field automatically clears after saving entry to timeline
- **Draft Management**: Auto-save drafts with 2-second delay, manual draft management
- **Keyword Analysis**: Real-time keyword extraction and manual keyword addition
- **Comprehensive Media Integration**: 
  - **Images**: Photo gallery storage with OCR scanning and accessibility support
  - **Videos**: Photo gallery storage with adaptive screenshot extraction (5-60s intervals based on duration)
  - **Audio**: Files folder storage with transcription support
  - **PDFs**: Files folder storage with OCR text extraction per page
  - **Word Docs**: Files folder storage with text extraction and word count
  - **MCP Export/Import**: Complete media metadata preservation across export/import cycles
- **Phase Integration**: Automatic phase detection and celebration on phase changes
- **Timeline Integration**: Seamless entry saving with immediate timeline refresh

### **Legacy API-Only Mode**
- **Debug (API only, no on-device model)**:
```bash
flutter run -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY
```

- Full Install to Phone
```bash
flutter clean 
flutter pub get
flutter devices
flutter build ios --release
flutter install -d YOUR_DEVICE_ID

```

## Run and Debug on Simulator
- Debug (full app):
```bash
flutter clean && flutter pub get && flutter devices
flutter run -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY
```

- If you omit `GEMINI_API_KEY`, the app will fall back to Rule‑Based unless you set the key in‑app via Lumara → AI Models → Gemini API → Configure → Activate.

## iOS device install (release)
```bash
flutter build ios --release --dart-define=GEMINI_API_KEY=YOUR_KEY
flutter install -d YOUR_DEVICE_ID
```
- Find device ID: `flutter devices`
- The key is compiled into this build; rebuild to rotate/change it.

## Android build (release)
```bash
flutter build apk --dart-define=GEMINI_API_KEY=YOUR_KEY
```

## Use Gemini in the Main MVP
- The chat/assistant in Lumara uses `LLMRegistry`.
- Priority: dart‑define key > stored key (SharedPreferences) > rule‑based fallback.
- To set the key at runtime:
  1) Open Lumara → AI Models → Gemini API (Cloud)
  2) Tap "Configure API Key" and paste your key
  3) Tap "Activate" to switch immediately
‑ If the API errors, the app falls back to Rule‑Based.

## Secure key handling
- Pass via `--dart-define=GEMINI_API_KEY=...` at run/build time
- Do not store the key in source files
- Optional shell env:
```bash
export GEMINI_API_KEY='YOUR_KEY'
flutter run -d DEVICE_ID --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

## Troubleshooting
- If it falls back, check network/quota/key validity
- Ensure model path is `gemini-1.5-flash` (v1beta)
- If Send does nothing, confirm logs show HTTP 200 and text chunks; otherwise check the key
- iOS: enable Developer Mode, trust the device in Xcode

## MCP Export/Import (Files app)
- **Export**: Settings → MCP Export & Import → Export to MCP. Exports with high fidelity (maximum capability) - complete data with all details preserved. After export completes, a Files share sheet opens to save the `.zip` where you want.
- **Import**: Settings → MCP qExport & Import → Import from MCP. Pick the `.zip` from Files; the app extracts it and imports automatically. If the ZIP has a top‑level folder, the app detects the bundle root.
- **Quality**: Always exports at high fidelity for maximum data preservation and AI ecosystem compatibility.

## What’s in this MVP
- `lib/llm/*`: LLMClient, GeminiClient (streaming), RuleBasedClient, LLMRegistry
- Startup selection via `LLMRegistry.initialize()` in `lib/main.dart` with `GEMINI_API_KEY`
- Tests in `test/llm/*` with a fake HTTP client for streaming parsing

# EPI MVP Install Guide (Main MVP – Gemini API)

This guide installs and runs the full MVP. The app uses Gemini via the LLMRegistry with a rule-based fallback if no key is provided or the API fails.

## Prerequisites
- Flutter 3.35+ (stable)
- Xcode (iOS) and/or Android SDK
- Gemini API key from Google AI Studio

## One-time setup
```bash
cd "/Users/mymac/Software Development/EPI/ARC MVP/EPI"
flutter pub get
flutter doctor
```

## Run the full MVP
- Debug (full app):
```bash
flutter run -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY
```

- Profile (recommended for perf testing):
```bash
flutter run --profile -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY
```

- Release (no debugging):
```bash
flutter run --release -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY
```

- If you omit `GEMINI_API_KEY`, the app will fall back to Rule-Based unless you set the key in‑app via Lumara → AI Models → Gemini API → Configure → Activate.

## iOS device install (release)
```bash
flutter build ios --release
flutter install -d YOUR_DEVICE_ID
```
For local debug or profile on a device, use the commands in "Run the full MVP".

## iPhone install with API key (release build)
Embed the key at build time, then install:
```bash
flutter build ios --release --dart-define=GEMINI_API_KEY=YOUR_KEY
flutter install -d YOUR_DEVICE_ID
```
- Find device ID: `flutter devices`
- The key is compiled into this build; rebuild to rotate/change it.

## Android build (release)
```bash
flutter build apk --dart-define=GEMINI_API_KEY=YOUR_KEY
```

## Secure key handling
- Pass via `--dart-define=GEMINI_API_KEY=...` at run/build time
- Do not store the key in source files
- Optional shell env:
```bash
export GEMINI_API_KEY='YOUR_KEY'
flutter run --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY --route=/llm-demo
```

## Use Gemini in the Main MVP
- The chat/assistant in Lumara uses `LLMRegistry`.
- Priority: dart-define key > stored key (SharedPreferences) > rule-based fallback.
- To set the key at runtime:
  1) Open Lumara → AI Models → Gemini API (Cloud)
  2) Tap "Configure API Key" and paste your key
  3) Tap "Activate" to switch immediately
‑ If the API errors, the app falls back to Rule‑Based.

## Troubleshooting
- If it falls back, check network/quota/key validity
- Ensure model path is `gemini-1.5-flash` for v1beta
- If Send does nothing, confirm logs show status 200 and text chunks; otherwise check the key
- iOS: enable Developer Mode, trust the device in Xcode

## MCP Export/Import (Files app)
- **Export**: Always uses high fidelity (maximum capability) - no quality selection needed
- **Media Preservation**: Photos, videos, audio, and documents maintain original URIs including `ph://` references
- **Import**: Automatically detects and reconstructs media items from exported MCP bundles
- **Compatibility**: Supports both new root-level media format and legacy metadata format
- **Timestamped Files**: MCP exports include readable date/time in filename format: `mcp_YYYYMMDD_HHMMSS.zip`

## MCP Bundle Health & Cleanup ✅ **NEW**
- **Health Analysis**: Go to Settings → MCP Bundle Health to analyze MCP files for issues
- **Orphan Detection**: Automatically identifies orphan nodes and unused keywords
- **Duplicate Detection**: Finds duplicate entries, pointers, and edges in MCP bundles
- **One-Click Cleanup**: Remove orphans and duplicates with configurable options
- **Custom Save Locations**: Choose where to save cleaned files using native file picker
- **Size Optimization**: Clean bundles can reduce file size by 30%+ by removing duplicates
- **Batch Processing**: Analyze and clean multiple MCP files simultaneously
- **Progress Tracking**: Real-time feedback during analysis and cleanup operations
- **Skip Options**: Cancel individual file cleaning if needed

## What's in this MVP
- `lib/llm/*`: LLMClient, GeminiClient (streaming), RuleBasedClient, LLMRegistry
- Startup selection via `LLMRegistry.initialize()` in `lib/main.dart` with `GEMINI_API_KEY`
- Tests in `test/llm/*` with a fake HTTP client for JSONL parsing

## Known Issues

### Phase Transfer Issue
**Status**: ✅ FIXED - Implemented RIVET Sweep Phase System

The phase transfer issue has been resolved with the implementation of the new RIVET Sweep phase system:

1. ✅ **Phase Timeline System**: Phases are now managed as timeline regimes rather than per-entry labels
2. ✅ **PhaseRegime Model**: New data model for phase periods with start/end times
3. ✅ **PhaseIndex Service**: Efficient timeline resolution for phase lookups
4. ✅ **MCP Export/Import**: Full support for phase regime data in MCP bundles
5. ✅ **RIVET Sweep**: Automated phase detection and segmentation
6. ✅ **Phase Timeline UI**: Visual timeline with phase bands and edit controls
7. ✅ **Migration Support**: Automatic migration from legacy per-entry phases

**New Features**:
- **Timeline-based Phases**: Phases are now periods on a timeline, not individual entry labels
- **RIVET Sweep**: Automated phase detection using topic shift, emotion delta, and tempo analysis
- **Phase Timeline UI**: Visual timeline with colored bands for easy phase management
- **User Override**: Users can always override RIVET suggestions
- **MCP Integration**: Full phase regime support in MCP export/import
- **Migration**: Automatic conversion from legacy phase system

**Usage**:
- Phases are now managed at the timeline level
- Use the Phase Timeline UI to view and edit phase periods
- RIVET Sweep automatically detects phase changes in your journal
- MCP exports now include complete phase timeline data

### UI/UX Improvements (January 24, 2025)

**Clean Timeline Design**:
- Write (+) and Calendar buttons moved to Timeline app bar
- Better information architecture with logical button placement
- More screen space with simplified bottom navigation

**Simplified Navigation**:
- Removed elevated Write tab from bottom navigation
- Clean 4-tab design: Phase, Timeline, Insights, Settings
- Flat bottom navigation design for better content visibility
- Fixed tab arrangement to ensure proper page routing

### Journal Editor & ARCForm Integration (January 25, 2025)

**Full-Featured Journal Editor**:
- Complete JournalScreen integration with all modern capabilities
- Media support: camera, gallery, voice recording
- Location picker for adding location data to entries
- Phase editing for existing journal entries
- LUMARA in-journal assistance and suggestions
- OCR text extraction from photos
- Keyword discovery and management
- Metadata editing: date, time, location, phase
- Draft management with auto-save and recovery
- Smart save behavior (only prompts when changes detected)

**ARCForm Keyword Integration**:
- ARCForms now update with real keywords from journal entries
- MCP bundle integration displays actual user keywords
- Phase regime detection from MCP bundles
- Journal entry filtering by phase regime date ranges
- Real keyword display from user's actual writing
- Fallback system to recent entries if no phase regime found
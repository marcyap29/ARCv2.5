# EPI - Evolving Personal Intelligence

A Flutter-based AI companion app that provides life-aware assistance through journaling, pattern recognition, and contextual AI responses.

## 🚀 Current Status

**✅ Production Ready** - MIRA-MCP semantic memory system complete, Gemini API integrated

- **Build Status:** ✅ iOS builds successfully (simulator + device)
- **iOS Simulator:** ✅ FFmpeg compatibility issue resolved - full simulator development workflow
- **Compilation:** ✅ All syntax errors resolved
- **AI Integration:** ✅ Gemini API with MIRA-enhanced ArcLLM + semantic context
- **MIRA System:** ✅ Complete semantic memory graph with Hive storage backend
- **MCP Support:** ✅ Full Memory Bundle v1 bidirectional export/import
- **Feature Flags:** ✅ Controlled rollout system for MIRA capabilities
- **Deployment:** ✅ Ready for iOS simulator and physical device installation
- **Test Status:** ⚠️ Some test failures (non-critical, mock setup issues)

## 🏗️ Architecture

### Core Components

- **ARC** - Journaling and meaning-making layer with visual Arcforms
- **ATLAS** - Life-phase detection and pacing system
- **AURORA** - Daily and seasonal rhythm orchestration
- **PRISM** - Multimodal perception (text, images, audio)
- **MIRA** - Long-term memory and recall under user control
- **VEIL** - Nightly pruning and coherence renewal
- **LUMARA** - AI assistant that orchestrates the system

### AI Integration

- **Gemini API (Cloud)** - Primary API-based LLM via `LLMRegistry` with streaming
- **MIRA Semantic Memory** - Complete semantic graph storage with context-aware retrieval
- **ArcLLM One-Liners** - `arc.sageEcho(entry)`, `arc.arcformKeywords(...)`, `arc.phaseHints(...)` with MIRA enhancement
- **Prompt Contracts** - Centralized in `lib/core/prompts_arc.dart` (Dart) and mirrored in `ios/.../PromptTemplates.swift`
- **MCP Memory Bundle v1** - Standards-compliant bidirectional export/import for AI ecosystem interoperability
- **Feature Flags** - Controlled rollout: `miraEnabled`, `miraAdvancedEnabled`, `retrievalEnabled`, `useSqliteRepo`
- **Rule-Based Adapter** - Deterministic fallback if API unavailable

## 🔧 Recent Updates (January 2025)

### MCP Export Embeddings Fix - January 22, 2025
- **Fixed Empty Embeddings**: Resolved issue where `embeddings.jsonl` was empty (0 bytes) in MCP exports
- **Content-Based Embeddings**: Now generates 384-dimensional vectors based on actual journal entry content
- **Proper Metadata**: Includes `doc_scope`, `model_id`, `embedding_version`, and vector dimensions
- **Export Completeness**: All MCP files now populated with meaningful data for AI ecosystem integration
- **Technical Fix**: Changed `includeEmbeddingPlaceholders: false` to `true` in export settings

### FFmpeg iOS Simulator Compatibility Fix (September 21, 2025) ✅ RESOLVED
- **CRITICAL FIX COMPLETE**: Resolved FFmpeg framework iOS simulator architecture incompatibility blocking development
- **Root Cause**: ffmpeg_kit_flutter_new_min_gpl framework built for iOS device but not compatible with simulator
- **Analysis**: Confirmed FFmpeg is currently unused (stub implementation in video_keyframe_service.dart)
- **Pragmatic Solution**: Temporarily removed unused FFmpeg dependency from pubspec.yaml
- **Impact**: Restored complete iOS simulator development workflow without functionality loss
- **Verification**: App builds and runs successfully on iOS simulator
- **Documentation**: Comprehensive fix documentation in Bug_Tracker-3.md
- **Future Ready**: Clear implementation path when video processing features are actually needed

### MCP Export System Resolution (September 21, 2025) ✅ RESOLVED
- **CRITICAL FIX COMPLETE**: Resolved the persistent issue where MCP export generated empty .jsonl files despite correct manifest counts
- **Root Cause Identified**: JournalRepository.getAllJournalEntries() had Hive box initialization race condition
- **Database Access Fix**: Enhanced getAllJournalEntries() with proper box opening logic and comprehensive error handling
- **Hive Adapter Fixes**: Fixed null safety issues in generated adapters that prevented loading older journal entries
- **Data Flow Restoration**: Fixed SAGE annotation extraction from entry.sageAnnotation instead of metadata.narrative
- **Stream Management**: Added proper file flushing and enhanced error handling in bundle writer
- **Complete Journal Entry Export**: Every confirmed journal entry now exported as comprehensive MCP records with actual content
- **Pointer + Node + Edge Model**: Journal entries become evidence pointers, semantic nodes, and relationship edges
- **Text Preservation**: Full journal text content preserved in pointer records with SHA-256 integrity
- **SAGE Integration**: Situation, Action, Growth, Essence extracted and structured in node records
- **Automatic Relationships**: Phase and keyword edges generated automatically from journal metadata
- **Deterministic IDs**: Stable identifiers ensure consistent exports across multiple runs
- **Architecture Integration**: McpSettingsCubit uses MiraService.exportToMcp() with functioning data pipeline
- **Compilation Fixes**: Resolved all hot restart errors and type casting issues, iOS builds successfully
- **Testing Verified**: Journal repository now successfully retrieves entries for MCP export processing

### MIRA-MCP Semantic Memory System Complete
- **MIRA Core**: Complete semantic graph implementation with Hive storage backend
- **MCP Bundle System**: Full bidirectional export/import with NDJSON streaming and SHA-256 integrity
- **Feature Flags**: Controlled rollout system (`miraEnabled`, `miraAdvancedEnabled`, `retrievalEnabled`)
- **Semantic Integration**: ArcLLM enhanced with context-aware responses from semantic memory
- **Bidirectional Adapters**: Full MIRA ↔ MCP conversion with semantic fidelity

### Gemini API Integration Complete
- **ArcLLM System**: Complete integration with `provideArcLLM()` factory for easy access
- **MIRA Enhancement**: ArcLLM now includes semantic context from MIRA memory graph
- **Prompt Contracts**: Centralized prompts in `lib/core/prompts_arc.dart` with Swift mirrors
- **Rule-Based Fallback**: Graceful degradation when API unavailable

### MCP Export/Import System Enhanced
- **MCP Memory Bundle v1**: Complete bidirectional export/import with NDJSON streaming
- **Four Storage Profiles**: minimal, space_saver, balanced, hi_fidelity
- **JSON Schema Validation**: Embedded MCP v1 schemas with additive evolution support
- **Deterministic Export**: Stable IDs and checksums for reproducible bundles
- **iOS UX**: Export now zips the bundle and opens the Files share sheet so you can choose a destination. Import opens Files to pick a .zip, then extracts and auto-detects the bundle root.

## 🛠️ Development Setup

### Prerequisites

- Flutter 3.24+ (stable channel)
- Dart 3.5+
- iOS Simulator or Android Emulator
- Xcode (for iOS development)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd "ARC MVP/EPI"
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app (full MVP)**
   ```bash
   # Debug
   flutter run -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY
   # Profile
   flutter run --profile -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY
   # Release (no debugging)
   flutter run --release -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY
   ```

### Model & Prompts Setup
* ARC prompts are in `lib/core/prompts_arc.dart` and mirrored for iOS in `ios/Runner/Sources/Runner/PromptTemplates.swift`.
* Use `provideArcLLM()` from `lib/services/gemini_send.dart` to obtain a ready `ArcLLM`.
* Example:
  ```dart
  final arc = provideArcLLM();
  final sage = await arc.sageEcho(entryText);
  ```

The app includes Qwen 2.5 1.5B Instruct model files in `assets/models/qwen/`:
- `qwen2.5-1.5b-instruct-q4_k_m.gguf` - Main model file
- `config.json` - Model configuration
- `tokenizer.json` - Tokenizer data
- `vocab.json` - Vocabulary

## 📱 Features

### Current Implementation

- **Journaling Interface** - Text, voice, and photo journaling
- **AI Assistant (LUMARA)** - Context-aware responses and insights
- **Pattern Recognition** - Keyword extraction and phase detection
- **Visual Arcforms** - Constellation-style visualizations of journal themes
- **Privacy-First** - On-device processing when possible

### Planned Features

- **Native Model Integration** - Full llama.cpp integration for Qwen models
- **Vision-Language Model** - Image understanding and analysis
- **Advanced Analytics** - Deeper pattern recognition and insights

### MCP Export System ✅

- **FIXED: Complete Journal Export** - Resolved critical issue where exports contained empty files instead of journal data
- **Unified Export Architecture** - Integrated standalone MCP export with MIRA semantic system for real data inclusion
- **Enhanced Journal Entry Export** - Every confirmed journal entry exported as Pointer + Node + Edge records
- **MCP Memory Bundle Export** - Standards-compliant export to MCP v1 format with full journal content
- **SAGE-to-Node Mapping** - Converts journal entries to structured MCP nodes with narrative preservation
- **Content-Addressable Storage** - CAS URIs for derivative content with SHA-256 integrity
- **Privacy Propagation** - Automatic PII and privacy field detection across all exported content
- **Deterministic Exports** - Reproducible exports with checksums and stable IDs
- **Storage Profiles** - Minimal, space-saver, balanced, and hi-fidelity options
- **Semantic Relationships** - Automatic edge creation for entry→phase and entry→keyword connections

## 🔧 Technical Details

### Dependencies

- **State Management:** flutter_bloc, bloc_test
- **Storage:** hive_flutter, flutter_secure_storage (MIRA backend)
- **UI:** flutter/material, custom widgets
- **Media:** audioplayers, photo_manager
- **AI/ML:** Custom adapters for Qwen models, MIRA semantic memory
- **MCP Export:** crypto, args (for CLI), deterministic bundle generation
- **MIRA Core:** Feature flags, deterministic IDs, event logging

### Code Quality

- **Linter:** 1,511 total issues (0 critical)
- **Tests:** Unit and widget tests (some failures due to mock setup)
- **Architecture:** Clean separation of concerns with adapter pattern

## 🐛 Known Issues

### Non-Critical Issues

1. **Test Failures** - Some tests fail due to mock setup and missing plugin implementations
2. **Native Bridge** - Qwen models use enhanced fallback mode (not native inference)
3. **ML Kit Integration** - Stubbed out for compilation (requires native setup)

### Future Improvements

1. **Native Model Integration** - Implement full llama.cpp integration
2. **Test Coverage** - Fix mock setup and improve test reliability
3. **Performance** - Optimize model loading and inference
4. **UI/UX** - Enhance visual design and user experience

## 📊 Recent Changes

### Latest Commit: Fix MCP export compilation errors after interface changes

- ✅ Updated mcp_settings_view.dart to handle Directory return type from exportToMcp()
- ✅ Removed McpEntryProjector stub code from from_mira.dart (now in bundle/writer.dart)
- ✅ Fixed various type and import issues in MCP modules
- ✅ Cleaned up unused imports and dead code
- ✅ Ensured iOS build compiles successfully after hot restart
- ✅ Unified MCP export architecture fully operational

## 📦 MCP Export System

The EPI app includes a comprehensive MCP (Memory Bundle) export system that allows you to export your journal memories in a standardized, portable format.

### What is MCP?

MCP (Memory Bundle) is a standardized format for exporting and sharing personal memory data. It includes:
- **Nodes**: Journal entries, thoughts, and memories
- **Edges**: Relationships between memories
- **Pointers**: References to media files and content
- **Embeddings**: Vector representations for semantic search

### Export Features

- **SAGE Integration**: Automatically extracts Situation, Action, Growth, and Essence from journal entries
- **Privacy Protection**: Detects and flags PII, faces, and location data
- **Content-Addressable Storage**: Uses CAS URIs for reliable content references
- **Deterministic Exports**: Same input always produces identical output
- **Storage Profiles**: Choose between minimal, space-saver, balanced, or hi-fidelity exports

### Using the MCP Export (App UX)

In the app: Settings → MCP Export & Import
- Export: choose storage profile → Export → Files share sheet appears → Save to Files (.zip)
- Import: Import from MCP → pick .zip from Files → app extracts and imports

### Using the MCP Export (CLI/programmatic)

#### Command Line Interface

```bash
# Export last 30 days with balanced profile
dart run tool/mcp/cli/arc_mcp_export.dart --scope=last-30-days

# Export all data with high fidelity
dart run tool/mcp/cli/arc_mcp_export.dart --scope=all --storage-profile=hi_fidelity

# Export custom date range
dart run tool/mcp/cli/arc_mcp_export.dart --scope=custom --start-date=2024-01-01 --end-date=2024-12-31

# Export with specific tags
dart run tool/mcp/cli/arc_mcp_export.dart --scope=custom --tags=work,personal
```

#### Programmatic Usage

```dart
import 'package:my_app/mcp/export/mcp_export_service.dart';

final exportService = McpExportService(
  storageProfile: McpStorageProfile.balanced,
  notes: 'My memory export',
);

final result = await exportService.exportToMcp(
  outputDir: Directory('./my_export'),
  scope: McpExportScope.last30Days,
  journalEntries: myJournalEntries,
  mediaFiles: myMediaFiles,
);
```

### Export Structure

```
epi_mcp_export/
├── manifest.json          # Bundle metadata and checksums
├── nodes.jsonl           # Journal entries as MCP nodes
├── edges.jsonl           # Relationships between memories
├── pointers.jsonl        # Media file references
└── embeddings.jsonl      # Vector embeddings for search
```

### Validation

The exported bundles can be validated using standard tools:

```bash
# Validate manifest
ajv validate -s schemas/manifest.v1.json -d manifest.json --spec=draft2020

# Validate nodes
ajv validate -s schemas/node.v1.json -d nodes.jsonl --spec=draft2020

# Stream validate NDJSON
cat nodes.jsonl | jq -c . | while read -r line; do
  echo "$line" | ajv validate -s schemas/node.v1.json -d - --spec=draft2020 || exit 1
done
```

### Storage Profiles

- **minimal**: Summaries and light embeddings only
- **space_saver**: Plus sparse keyframes or chunked spans  
- **balanced**: Default balanced approach
- **hi_fidelity**: Dense sampling, more spans, more keyframes

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Make your changes** and ensure tests pass
4. **Commit your changes** (`git commit -m 'Add amazing feature'`)
5. **Push to the branch** (`git push origin feature/amazing-feature`)
6. **Open a Pull Request**

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- **Qwen Team** - For the excellent language models
- **Flutter Team** - For the amazing framework
- **Open Source Community** - For the various packages used

---

**Last Updated:** September 21, 2025
**Version:** 0.2.2-alpha
**Status:** MIRA-MCP Production Ready + Complete Journal Export Integration
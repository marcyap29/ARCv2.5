# EPI - Evolving Personal Intelligence

A Flutter-based AI companion app that provides life-aware assistance through journaling, pattern recognition, and contextual AI responses.

## 🚀 Current Status

**✅ Ready for Development** - All critical errors resolved, app compiles successfully

- **Linter Status:** 1,511 total issues (0 critical errors)
- **Build Status:** ✅ Compiles successfully
- **Qwen Integration:** ✅ Working with enhanced fallback responses
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
- **ArcLLM One-Liners** - `arc.sageEcho(entry)`, `arc.arcformKeywords(...)`, `arc.phaseHints(...)`, `arc.rivetLite(...)`
- **Prompt Contracts** - Centralized in `lib/core/prompts_arc.dart` (Dart) and mirrored in `ios/.../PromptTemplates.swift`
- **On-Device Ready** - Same contracts usable by iOS bridge later
- **Rule-Based Adapter** - Deterministic fallback if API unavailable

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

- **MCP Memory Bundle Export** - Standards-compliant export to MCP v1 format
- **SAGE-to-Node Mapping** - Converts journal entries to structured MCP nodes
- **Content-Addressable Storage** - CAS URIs for derivative content
- **Privacy Propagation** - Automatic PII and privacy field detection
- **Deterministic Exports** - Reproducible exports with checksums
- **Storage Profiles** - Minimal, space-saver, balanced, and hi-fidelity options

## 🔧 Technical Details

### Dependencies

- **State Management:** flutter_bloc, bloc_test
- **Storage:** hive, flutter_secure_storage
- **UI:** flutter/material, custom widgets
- **Media:** audioplayers, photo_manager
- **AI/ML:** Custom adapters for Qwen models
- **MCP Export:** crypto, args (for CLI)

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

### Latest Commit: Fix critical linter errors and improve Qwen integration

- ✅ Fixed 202 critical linter errors
- ✅ Removed GemmaAdapter references
- ✅ Added missing math imports
- ✅ Fixed type conversion issues
- ✅ Stubbed ML Kit classes
- ✅ Enhanced Qwen integration
- ✅ Improved error handling

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

### Using the MCP Export

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

**Last Updated:** December 2024  
**Version:** 0.1.0-alpha  
**Status:** Development Ready
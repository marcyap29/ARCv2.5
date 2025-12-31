# EPI v1.0.0 - Evolving Personal Intelligence

A Flutter-based AI companion app that provides life-aware assistance through journaling, pattern recognition, and contextual AI responses.

## 🚀 Current Status

**🎉 MVP FULLY OPERATIONAL** - Version 1.0.0 Production Ready (January 2025)

### **Version Information**

- **Application Version**: 1.0.0+1
- **Architecture Version**: 2.2 (Consolidated 5-Module Architecture)
- **Flutter SDK**: >=3.22.3
- **Dart SDK**: >=3.0.3 <4.0.0
- **Last Updated**: December 29, 2025
- **Status**: ✅ Production Ready

### **Latest Major Achievement: Engagement Discipline System** ✅ **COMPLETE** (v2.1.75)

- **User-Controlled Engagement Modes**: Reflect (minimal), Explore (moderate), Integrate (deep synthesis)
- **Cross-Domain Synthesis Controls**: Toggle synthesis between life domains (Faith & Work, Relationships & Work, etc.)
- **Response Discipline Settings**: Control temporal connections, question limits, and language boundaries
- **Integration with LUMARA Control State**: Seamless integration with existing LUMARA system
- **Advanced Settings UI**: Black background, white text, purple accents - consistent with other Advanced Settings

### **Previous Major Achievement: Complete MVP Implementation** ✅ **COMPLETE**

- **5-Module Architecture**: Consolidated from 8+ modules for maintainability
- **LUMARA MCP Memory System**: Persistent conversational memory across sessions
- **On-Device AI Integration**: Qwen models with llama.cpp and Metal acceleration
- **MCP Export/Import System**: Standards-compliant data portability
- **Comprehensive Bug Fixes**: All critical issues resolved
- **Status**: ✅ **FULLY IMPLEMENTED** - Production-ready MVP

## 📚 Documentation

### Version-Controlled Documentation

All documentation is version-controlled and located in `ARC MVP/EPI/docs/`:

- **Architecture**: `docs/ARCHITECTURE.md` - Comprehensive architecture documentation
- **Features**: `docs/FEATURES.md` - Complete feature documentation
- **UI/UX**: `docs/UI_UX.md` - UI/UX design documentation
- **Backend**: `docs/backend.md` - Backend architecture and setup
- **Engagement Discipline**: `docs/Engagement_Discipline.md` - Engagement Discipline system documentation
- **Changelog**: `docs/CHANGELOG.md` - Version history and changes
- **Bug Tracker**: `docs/bugtracker/bug_tracker.md` - Comprehensive bug tracking

### Archive

Historical documentation is archived in `docs/archive/`:
- Old architecture documents
- Legacy bug tracker files
- Deprecated guides and reports

## 🏗️ Architecture

### Core Components (5-Module Architecture)

- **ARC** - Core journaling interface and meaning-making layer with visual Arcforms
- **PRISM** - Multimodal perception engine (text, images, audio, biometric streams) with ATLAS integration
- **POLYMETA** - Memory graph, recall, encryption, and data container (MIRA + MCP + ARCX)
- **AURORA** - Daily and seasonal rhythm orchestration with circadian alignment (includes VEIL)
- **ECHO** - Expressive response layer with safety and privacy (voice of LUMARA, provider-agnostic LLM interfaces)

### AI Integration

- **On-Device Qwen Models** - Qwen 2.5 1.5B Instruct, Qwen2.5-VL-3B, Qwen3-Embedding-0.6B via llama.cpp
- **Gemini API (Cloud)** - Primary API-based LLM via `LLMRegistry` with streaming (fallback)
- **POLYMETA Semantic Memory** - Complete semantic graph storage with context-aware retrieval
- **MCP Memory Bundle v1** - Standards-compliant bidirectional export/import for AI ecosystem interoperability
- **Feature Flags** - Controlled rollout: `miraEnabled`, `miraAdvancedEnabled`, `retrievalEnabled`, `useSqliteRepo`
- **Rule-Based Adapter** - Deterministic fallback if API unavailable

## 🛠️ Development Setup

### Prerequisites

- Flutter 3.22.3+ (stable channel)
- Dart 3.0.3+ <4.0.0
- iOS Simulator or Android Emulator
- Xcode (for iOS development)
- Gemini API key from Google AI Studio (optional, for cloud fallback)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd ARCv.03
   ```

2. **Navigate to the main project**
   ```bash
   cd "ARC MVP/EPI"
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the app (full MVP)**
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

## 📱 Features

### Current Implementation

- **Journaling Interface** - Text, voice, and photo journaling with OCR
- **AI Assistant (LUMARA)** - Context-aware responses and insights with persistent chat memory
- **Pattern Recognition** - Keyword extraction and phase detection
- **Visual Arcforms** - 3D constellation-style visualizations of journal themes
- **Chat Memory System** - Persistent chat sessions with 30-day auto-archive policy and search
- **Privacy-First** - On-device processing when possible with PII detection and redaction
- **MCP Export System** - Standards-compliant export/import for AI ecosystem interoperability
- **On-Device AI** - Qwen models with llama.cpp and Metal acceleration
- **Phase Detection** - Real-time phase detection with RIVET and SENTINEL
- **Health Integration** - HealthKit integration for health data

### Planned Features

- **Vision-Language Model** - Enhanced image understanding and analysis
- **Advanced Analytics** - Deeper pattern recognition and insights
- **Additional On-Device Models** - Llama and other model support

## 🔧 Technical Details

### Dependencies

- **State Management:** flutter_bloc, bloc_test
- **Storage:** hive_flutter, flutter_secure_storage (POLYMETA backend)
- **UI:** flutter/material, custom widgets
- **Media:** audioplayers, photo_manager, image_picker
- **AI/ML:** Custom adapters for Qwen models, POLYMETA semantic memory, llama.cpp
- **MCP Export:** crypto, args (for CLI), deterministic bundle generation
- **POLYMETA Core:** Feature flags, deterministic IDs, event logging

### Code Quality

- **Linter:** Minor warnings (deprecated methods, unused imports) - 0 critical
- **Tests:** Unit and widget tests (some failures due to mock setup - non-critical)
- **Architecture:** Clean separation of concerns with 5-module consolidated architecture

## 📦 MCP Export System

The EPI app includes a comprehensive MCP (Memory Container Protocol) export system that allows you to export your journal memories in a standardized, portable format.

### What is MCP?

MCP (Memory Container Protocol) is a standardized format for exporting and sharing personal memory data. It includes:
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
- **ARCX Encryption**: Optional AES-256-GCM + Ed25519 encryption layer

### Using the MCP Export (App UX)

In the app: Settings → MCP Export & Import
- Export: choose storage profile → Export → Files share sheet appears → Save to Files (.zip)
- Import: Import from MCP → pick .zip from Files → app extracts and imports

## 📖 Version History

### Version 2.1.17 (January 2025)
- **Voiceover Mode**: AI responses can be spoken aloud with TTS integration
- **Favorites UI Improvements**: Simplified interaction, manual addition, and better UX
- **Export/Import**: Confirmed LUMARA Favorites are fully supported in MCP bundles

### Version 1.0.0 (January 2025)
- **Status**: Production Ready
- **Key Features**:
  - Complete 5-module architecture consolidation
  - LUMARA MCP Memory System
  - On-device AI integration (Qwen models)
  - MCP export/import system
  - Comprehensive bug fixes
  - Enhanced ARCForm 3D visualizations
  - Real-time phase detection

### Version 0.2.6-alpha (September 2025)
- LUMARA Chat Memory + Repository Hygiene
- MIRA-MCP Architecture
- Clean Git Workflow
- Insights System Fixed

### Version 0.2.5-alpha (September 2025)
- MCP Integration
- Memory Container Protocol implementation

### Version 0.2.4-alpha (August 2025)
- Initial MVP release

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

**Last Updated:** November 2025
**Version:** 1.0.0
**Status:** Production Ready - Complete MVP Implementation with 5-Module Architecture

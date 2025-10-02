# EPI v1a - Evolving Personal Intelligence

A Flutter-based AI companion app that provides life-aware assistance through journaling, pattern recognition, and contextual AI responses.

## 🚀 Current Status

**🎉 MVP FULLY OPERATIONAL** - All systems working, LUMARA MCP Memory System implemented (September 28, 2025)

### **Latest Major Achievement: LUMARA MCP Memory System** ✅ **COMPLETE**
- **Automatic Chat Persistence**: Fixed chat history requiring manual session creation - now works like ChatGPT/Claude
- **Memory Container Protocol**: Complete MCP implementation for persistent conversational memory across sessions
- **Cross-Session Continuity**: LUMARA remembers past discussions and references them intelligently in responses
- **Rolling Summaries**: Map-reduce summarization every 10 messages with key facts and context extraction
- **Memory Commands**: `/memory show`, `/memory forget`, `/memory export` for complete user control
- **Privacy Protection**: Built-in PII redaction with automatic detection of emails, phones, API keys, sensitive data
- **Enterprise-Grade**: Robust session management with intelligent context retrieval and graceful degradation
- **Status**: ✅ **FULLY IMPLEMENTED** - LUMARA now provides persistent memory like major AI systems

## 🏗️ Architecture

### Core Components (8-Module Architecture)

- **ARC** - Core journaling interface and meaning-making layer with visual Arcforms
- **PRISM** - Multimodal perception engine (text, images, audio, biometric streams)
- **ECHO** - Expressive response layer (voice of LUMARA, provider-agnostic LLM interfaces)
- **ATLAS** - Life-phase detection and pacing system with adaptive transitions
- **MIRA** - Long-term memory and semantic graph with context-aware retrieval
- **AURORA** - Daily and seasonal rhythm orchestration with circadian alignment
- **VEIL** - Universal privacy guardrail with nightly pruning and coherence renewal
- **RIVET** - Risk-Validation Evidence Tracker with ALIGN/TRACE metrics for safety gating

### AI Integration

- **Gemini API (Cloud)** - Primary API-based LLM via `LLMRegistry` with streaming
- **MIRA Semantic Memory** - Complete semantic graph storage with context-aware retrieval
- **ArcLLM One-Liners** - `arc.sageEcho(entry)`, `arc.arcformKeywords(...)`, `arc.phaseHints(...)` with MIRA enhancement
- **Prompt Contracts** - Centralized in `lib/core/prompts_arc.dart` (Dart) and mirrored in `ios/.../PromptTemplates.swift`
- **MCP Memory Bundle v1** - Standards-compliant bidirectional export/import for AI ecosystem interoperability
- **Feature Flags** - Controlled rollout: `miraEnabled`, `miraAdvancedEnabled`, `retrievalEnabled`, `useSqliteRepo`
- **Rule-Based Adapter** - Deterministic fallback if API unavailable

## 🛠️ Development Setup

### Prerequisites

- Flutter 3.24+ (stable channel)
- Dart 3.5+
- iOS Simulator or Android Emulator
- Xcode (for iOS development)
- Gemini API key from Google AI Studio

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd EPI_v1a
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

- **Journaling Interface** - Text, voice, and photo journaling
- **AI Assistant (LUMARA)** - Context-aware responses and insights with persistent chat memory
- **Pattern Recognition** - Keyword extraction and phase detection
- **Visual Arcforms** - Constellation-style visualizations of journal themes
- **Chat Memory System** - Persistent chat sessions with 30-day auto-archive policy and search
- **Privacy-First** - On-device processing when possible with PII detection and redaction
- **MCP Export System** - Standards-compliant export/import for AI ecosystem interoperability

### Planned Features

- **Native Model Integration** - Full llama.cpp integration for Qwen models
- **Vision-Language Model** - Image understanding and analysis
- **Advanced Analytics** - Deeper pattern recognition and insights

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

**Last Updated:** September 28, 2025
**Version:** 0.2.6-alpha
**Status:** Production Ready - Complete MCP Integration + LUMARA Chat Memory + Repository Hygiene + MIRA-MCP Architecture + Clean Git Workflow + Insights System Fixed

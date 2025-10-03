# ARC MVP — Project Brief for Cursor

## Overview
ARC is the **core journaling module of EPI (Evolving Personal Intelligence)**, built using a new 8-module architecture. It is a journaling app that treats reflection as a **sacred act**. The experience should feel like the *Blessed* app: calming, atmospheric, and emotionally resonant. Journaling is the entry point, but the core differentiation is that each entry generates a **visual Arcform** — a glowing, constellation-like structure that evolves with the user's story.

This MVP now implements **modular architecture** with RIVET (safety validation) and ECHO (expressive response layer) modules migrated to their proper locations, providing a foundation for the complete 8-module system: ARC→PRISM→ECHO→ATLAS→MIRA→AURORA→VEIL→RIVET.

## 🌟 **LATEST ENHANCEMENT: Qwen Tokenizer Fix** (2025-10-02) ✅

**🎯 Major Achievement**: Resolved critical tokenizer mismatch issue that was causing garbled "Ġout" output, implementing proper Qwen-3 BPE tokenization with comprehensive validation and cleanup systems.

**✨ Qwen Tokenizer Fix Features**:
- **Tokenizer Mismatch Resolved**: Fixed garbled "Ġout" output by replacing `SimpleTokenizer` with proper `QwenTokenizer`
- **BPE Tokenization**: Implemented proper Byte-Pair Encoding instead of word-level tokenization
- **Special Token Handling**: Added support for Qwen-3 chat template tokens (`<|im_start|>`, `<|im_end|>`, etc.)
- **Validation & Cleanup**: Added tokenizer validation and GPT-2/RoBERTa marker cleanup
- **Enhanced Generation**: Structured token generation with proper stop string handling
- **Comprehensive Logging**: Added sanity test logging for debugging tokenizer issues

**🎯 Technical Implementation**:
- **QwenTokenizer Class**: Complete rewrite with proper BPE-like tokenization
- **Special Token Support**: Added support for `<|im_start|>`, `<|im_end|>`, `<|pad|>`, `<|unk|>` from `tokenizer_config.json`
- **Tokenizer Validation**: Added roundtrip testing to catch GPT-2/RoBERTa markers early
- **Cleanup Guards**: Added `cleanTokenizationSpaces()` to remove `Ġ` and `▁` markers
- **Enhanced Generation**: Structured token generation with proper stop string handling
- **Error Handling**: Graceful degradation with clear error messages for tokenizer issues

**📱 User Experience**:
- **Clean Responses**: No more garbled "Ġout" or single glyph responses
- **Proper LUMARA Tone**: Coherent, contextually appropriate responses
- **Reliable Generation**: Consistent text generation with proper tokenization
- **Debug Visibility**: Comprehensive logging for troubleshooting tokenizer issues

**🏆 Current Status**: Qwen model now generates clean, coherent LUMARA responses with proper tokenization. The tokenizer validation catches issues early and provides clear error messages for debugging.

## 🌟 **PREVIOUS ENHANCEMENT: MLX On-Device LLM Integration** (2025-10-02) ✅

**🎯 Major Achievement**: Complete implementation of on-device LLM processing using Qwen3-1.7B model with MLX Swift framework integration, providing privacy-first AI responses with type-safe Pigeon bridge communication and proper provider switching.

**✨ MLX On-Device LLM Features**:
- **Pigeon Bridge**: Type-safe Flutter ↔ Swift communication with auto-generated code
- **MLX Swift Packages**: Complete integration of MLX, MLXNN, MLXOptimizers, MLXRandom
- **Safetensors Parser**: Full safetensors format support with F32/F16/BF16/I32/I16/I8 data types
- **Model Loading Pipeline**: Real model weight loading from .safetensors files to MLXArrays
- **Qwen3-1.7B Support**: On-device model integration with privacy-first inference
- **Privacy-First Processing**: All AI responses generated locally on device when model available
- **Intelligent Fallback**: Three-tier fallback system: On-Device → Cloud API → Rule-Based responses
- **Provider Switching**: Fixed provider selection logic to properly switch between on-device Qwen and Google Gemini
- **Metal Acceleration**: Native iOS Metal support for optimal performance on Apple Silicon

**🎯 Technical Implementation**:
- **Pigeon Bridge**: Type-safe communication eliminating runtime casting errors
- **Model Registry**: JSON-based model management at `~/Library/Application Support/Models/`
- **Safetensors Parser**: Real-time conversion of model weights to MLXArrays
- **Model Lifecycle**: Proper initialization, loading, and disposal of MLX models
- **Error Handling**: Graceful degradation through multiple fallback layers
- **Build Integration**: Successful iOS build with Metal Toolchain support

**📱 User Experience**:
- **Complete Privacy**: No data leaves device when using on-device model
- **Consistent Quality**: Maintains LUMARA's tone and ARC contract compliance
- **Reliable Responses**: Multiple fallback layers ensure responses always available
- **Performance Optimized**: Designed for 4GB RAM devices with efficient memory usage

**🏆 Current Status**: EPI offers complete privacy-first AI processing with fully operational on-device LLM capabilities. Provider switching works correctly between on-device Qwen and Google Gemini, with macOS app running successfully.

---

## 🌟 **PREVIOUS ENHANCEMENT: LUMARA Streaming & UX Improvements** (2025-09-30) ✅

**🎯 Major Achievement**: Implemented streaming responses, double confirmation for destructive actions, and fixed repetitive fallback messages - significantly improving LUMARA's user experience.

**✨ Key Enhancements**:
- **Streaming Responses**: Real-time text generation using Gemini API's Server-Sent Events (SSE) for progressive UI updates
- **Clear History Protection**: Two-step confirmation dialog prevents accidental chat deletion with escalating warnings
- **Response Variety**: Fixed repetitive fallback messages by adding timestamp-based seed for response rotation
- **Attribution Integration**: Streaming responses now properly retrieve attribution traces after completion
- **Graceful Fallback**: Automatic fallback to non-streaming when API unavailable with comprehensive error handling

**🎯 Technical Implementation**:
- **geminiSendStream()**: Complete SSE streaming implementation with chunk processing and error recovery
- **Conditional Streaming Logic**: Automatic API key detection with streaming/non-streaming path selection
- **Double Confirmation UI**: Cascading AlertDialogs with red button styling and mounted state checks
- **Timestamp-Based Seeding**: Time-based variety ensures same query gets different response variants
- **Progressive UI Updates**: Real-time message updates as text chunks arrive from streaming API

**📱 User Experience**:
- **ChatGPT-like Streaming**: Responses appear word-by-word creating engaging, modern AI interaction
- **Accidental Deletion Prevention**: Clear History now requires two explicit confirmations with strong warnings
- **Dynamic Conversations**: Fallback responses rotate through variants preventing repetitive interactions
- **Professional Error Handling**: Graceful degradation with user-friendly messaging when streaming unavailable

**🏆 Result**: LUMARA now delivers a modern, polished conversational experience with streaming responses, protective confirmations for destructive actions, and varied fallback responses that maintain user engagement.

---

## 🌟 **PREVIOUS ENHANCEMENT: LUMARA MCP Memory System** (2025-09-28) ✅

**🎯 Major Achievement**: Complete implementation of Memory Container Protocol (MCP) enabling LUMARA to automatically record, persist, and intelligently retrieve all conversations like major AI systems (ChatGPT, Claude, etc.).

**✨ MCP Memory System Features**:
- **Automatic Chat Persistence**: Every message automatically saved without manual intervention - fixes chat history issue
- **Session Management**: Conversations organized into persistent sessions with automatic resume across app restarts
- **Rolling Summaries**: Map-reduce summarization every 10 messages with intelligent key facts extraction
- **Memory Indexing**: Topics, entities, and open loops automatically tracked and searchable across sessions
- **PII Protection**: Built-in redaction of emails, phones, API keys, and sensitive data before storage
- **Memory Commands**: `/memory show`, `/memory forget`, `/memory export` for user control and transparency

**🎯 Technical Implementation**:
- **McpMemoryService**: Core conversation persistence and session management with JSON storage
- **MemoryIndexService**: Global index for topics, entities, and open loops tracking across conversations
- **SummaryService**: Map-reduce pattern for intelligent conversation summarization and context building
- **PiiRedactionService**: Comprehensive privacy protection with redaction manifests and secure storage
- **Enhanced LumaraAssistantCubit**: Fully integrated automatic memory recording and context retrieval

**📱 User Experience**:
- **Transparent Operation**: All conversations automatically preserved without user intervention
- **Cross-Session Continuity**: LUMARA remembers past discussions intelligently and references them naturally
- **Memory Commands**: Users can inspect, manage, and export their complete conversation history
- **Smart Context**: Responses informed by relevant conversation history, summaries, and identified patterns
- **Privacy Control**: Built-in PII redaction with user visibility into what data is stored

**🏆 Result**: LUMARA now provides persistent, intelligent conversational memory that builds context over time while maintaining privacy and user sovereignty. Chat history works seamlessly like major AI systems without requiring manual session creation.

---

## 🌟 **PREVIOUS ENHANCEMENT: LUMARA Advanced API Management** (2025-09-28) ✅

**🎯 Major Achievement**: Complete implementation of advanced API management system for LUMARA with intelligent provider selection and enhanced user experience.

**✨ Advanced API Management Features**:
- **Multi-Provider Support**: Unified interface for Gemini, OpenAI, Anthropic, and internal models (Llama, Qwen)
- **Intelligent Fallback**: Automatic fallback from external APIs to rule-based responses when providers unavailable
- **Dynamic API Key Detection**: Real-time detection of configured API keys with contextual user messaging
- **Provider Priority System**: Preference order favoring internal models → external APIs → rule-based responses
- **Configuration Management**: Centralized API configuration with persistent storage and security masking

**🎯 Technical Implementation**:
- **LumaraAPIConfig**: Singleton configuration manager with environment variable detection
- **Enhanced Provider Detection**: Automatic availability checking for all configured providers
- **Smart Response Routing**: Direct Gemini API integration with enhanced LUMARA API fallback
- **Settings UI**: Complete API key management interface with provider status indicators
- **Security-First Design**: API key masking, secure storage, and environment variable priority

**📱 User Experience**:
- **Contextual Messaging**: Clear feedback when running in basic mode vs full AI mode
- **Seamless Provider Switching**: Automatic provider selection without user intervention required
- **Configuration Transparency**: Clear provider status and configuration state in settings
- **Graceful Degradation**: System never fails - always provides meaningful responses

**🏆 Result**: LUMARA now provides a robust, enterprise-grade API management system that ensures reliable service regardless of external provider availability while maintaining security best practices and optimal user experience.

---

## 🌟 **PREVIOUS ENHANCEMENT: ECHO Module Implementation** (2025-09-27) ✅

**🎯 Major Achievement**: Complete implementation of ECHO (Expressive Contextual Heuristic Output) - the dignified response generation layer for LUMARA.

**✨ ECHO System Features**:
- **Phase-Aware Responses**: Adapts to all 6 ATLAS phases with appropriate tone and pacing
- **Safety by Design**: Built-in dignity protection and manipulation detection through RIVET-lite validation
- **Memory Grounding**: Contextual responses based on user's actual experiences via MIRA integration
- **Voice Consistency**: Maintains LUMARA's authentic, reflective voice across all interactions
- **Graceful Degradation**: Multiple fallback layers ensure system never fails silently
- **Emotional Intelligence**: Context-aware emotional resonance and support

**🎯 Technical Implementation**:
- **Core ECHO Service**: Complete 8-step response generation pipeline with safety validation
- **ATLAS Phase Integration**: Real-time phase detection with transition handling and stability scoring
- **MIRA Memory Grounding**: Semantic concept extraction and memory retrieval simulation
- **RIVET-lite Validator**: Dignity violation detection, manipulation blocking, contradiction analysis
- **Phase Templates**: Detailed guidance for all 6 ATLAS phases with emotional resonance prompts
- **Integration Layer**: Drop-in enhancement for existing LUMARA system with backward compatibility

**📱 User Experience**:
- **Dignified Interactions**: All responses maintain respect for user sovereignty and experience
- **Developmental Appropriateness**: Responses match user's current life phase and emotional state
- **Safety Assurance**: Automatic blocking of dismissive, manipulative, or harmful language patterns
- **Contextual Awareness**: Responses grounded in user's actual journal entries and patterns

**🏆 Result**: LUMARA now has a sophisticated response generation system that externalizes safety and dignity concerns from the language model, ensuring every interaction embodies the sacred, reflective nature of the journaling experience while maintaining technical excellence.

---

## 🌟 **PREVIOUS ENHANCEMENT: Home Icon Navigation Fix** (2025-09-27) ✅

**🎯 Problem Solved**: Fixed duplicate scan document icons in advanced writing page and improved navigation with proper home icon.

**✨ Duplicate Icon Resolution**:
- **Removed Duplicate**: Fixed duplicate scan document icons in advanced writing interface
- **Home Icon Navigation**: Changed upper right scan icon to home icon for better navigation
- **Clear Functionality**: Upper right provides home navigation, lower left provides scan functionality
- **User Experience**: Eliminated confusion from duplicate icons and improved navigation clarity
- **LUMARA Cleanup**: Removed redundant home icon from LUMARA Assistant screen since bottom navigation provides home access

---

## 🌟 **PREVIOUS ENHANCEMENT: Elevated Write Button Redesign** (2025-09-27) ✅

**🎯 Problem Solved**: Replaced floating action button design with elegant elevated tab design to eliminate content blocking and improve visual hierarchy.

**✨ Elevated Tab Design Implementation**:
- **Smaller Write Button**: Replaced floating action button with elegant elevated tab design
- **Above Navigation Positioning**: Write button now positioned as elevated circular button above navigation tabs
- **Thicker Navigation Bar**: Increased bottom navigation height to 100px to accommodate elevated design
- **Perfect Integration**: Seamless integration with existing CustomTabBar elevated tab functionality

**🎯 Technical Improvements**:
- **CustomTabBar Enhancement**: Utilized existing elevated tab functionality with `elevatedTabIndex: 2`
- **Clean Architecture**: Removed custom FloatingActionButton location in favor of built-in elevated tab
- **Write Action Handler**: Proper `_onWritePressed()` method with session cache clearing
- **Page Structure**: Updated pages array to accommodate Write as action rather than navigation

**📱 User Experience**:
- **Bottom Navigation**: Phase → Timeline → **Write (Elevated)** → LUMARA → Insights → Settings
- **Visual Hierarchy**: Write button prominently elevated above other navigation options
- **No Content Blocking**: Eliminated FAB interference with content across all tabs
- **Consistent Design**: Matches user's exact specification for smaller elevated button design
- **Perfect Flow**: Complete emotion → reason → writing → keyword analysis flow maintained

**🏆 Result**: Users now have an elegantly designed elevated Write button that provides prominent access to journaling while eliminating all content blocking issues. The design perfectly matches the user's specification for a smaller button positioned above the navigation tabs with a thicker overall bar structure.

---

## Tools & Setup
- **Code tools**: Cursor (connected to GitHub), GitHub repo up to date, local clone active.
- **Framework**: Flutter (cross-platform, iOS/Android).
- **Simulator**: iPhone 16 (iOS).
- **Architecture**: Offline-first, encrypted local storage, cloud sync stubbed (Firebase/Supabase later).

---

## Core Flows (MVP)
1. **Onboarding (Reflective Scaffolding)**  
   - Gentle, 3-step flow: why you’re here, journaling tone, preferred rhythm.  
   - Data saved under `user_profiles/{uid}/onboarding`.

2. **Journal Capture**  
   - Minimalist text input (voice optional).  
   - Auto-save drafts.  
   - Save creates `JournalEntry` JSON object.  

3. **SAGE Echo (post-processing)**  
   - After save, entry is annotated with Situation, Action, Growth, Essence.  
   - User can review/edit.  

4. **Keyword Extraction & Review**  
   - 5–10 keywords suggested, user can edit.  
   - Stored on `JournalEntry`.  

5. **Arcform Renderer**  
   - Uses keywords to render constellation/radial layout.  
   - Geometry mapped to ATLAS phase hint (spiral, flower, branch, weave, glow core, fractal).  
   - Emotional colors: warm = growth, cool = recovery.
   - **Enhanced**: Interactive phase selector with live geometry previews
   - **Fixed**: Proper geometry recreation when changing phases, correct edge generation patterns  

6. **Timeline View**  
   - Chronological scroll of entries + Arcform snapshots.  
   - Cards show excerpt + Arcform thumbnail.  

7. **Insights & Your Patterns Visualization**
   - Graph view of keywords (nodes) and co-occurrences (edges).
   - Tap node to see linked entries.
   - **Fixed**: Insight cards now generate properly with real data instead of placeholders
   - **Enhanced**: Comprehensive Your Patterns visualization system with 4 views:
     - Word Cloud: Frequency-based keyword layout with emotion coloring
     - Network Graph: Force-directed physics layout with curved Bezier edges
     - Timeline: Chronological keyword trends with sparkline visualization
     - Radial: Central theme with spoke connections to related concepts
   - **Interactive Features**: Phase filtering, emotion filtering, time range selection
   - **MIRA Integration**: Co-occurrence matrix adapter for semantic memory data
   - **Visual Enhancements**: Phase icons, selection highlighting, neighbor filtering
   - **Full Integration**: "Your Patterns" card in Insights tab opens comprehensive visualization
   - **Production Ready**: 1200+ lines of new visualization code, legacy code cleaned up

8. **UI/UX with Roman Numeral 1 Tab Bar** ✅ COMPLETE
   - **Starting Screen**: Phase tab as default for immediate access to core functionality
   - **Journal Tab Redesign**: "+" icon for intuitive "add new entry" action
   - **Roman Numeral 1 Shape**: Elevated "+" button above tab bar for prominent primary action
   - **Tab Optimization**: Reduced height, padding, and icon sizes for better space utilization
   - **Your Patterns Priority**: Moved to top of Insights tab for better visibility
   - **Mini Radial Icon**: Custom visualization icon for Your Patterns card recognition
   - **Phase-Based Flow**: Smart startup logic - no phase → quiz, has phase → main menu
   - **Perfect Positioning**: Elevated button with optimal spacing and no screen edge cropping  

---

## Current Development State
- **Production Ready**: All core features implemented and stable ✅
- **Complete MVP Implementation**: Journal capture, arcforms, timeline, insights, onboarding, export functionality
- **First Responder Mode**: Complete specialized tools for emergency responders (P27-P34)
- **Coach Mode**: Complete coaching tools and fitness tracking system (P27, P27.1-P27.3)
- **MCP Export System**: Standards-compliant data export for AI ecosystem interoperability
- **Accessibility & Performance**: Full WCAG compliance with screen reader support and performance monitoring
- **Settings & Privacy**: Complete privacy controls, data management, and personalization
- **Critical Issues Resolved**: All startup, database, and navigation issues fixed

---

## Current Feature Set

### Core Features ✅
- **Journal Capture**: Text and multi-modal journaling with audio, camera, gallery, and OCR
- **Arcforms**: 2D and 3D visualization with phase detection and emotional mapping
- **Timeline**: Chronological entry management with editing and phase tracking
- **Insights**: Pattern analysis, phase recommendations, and emotional insights (Fixed: Now generates actual insight cards with real data)
- **Onboarding**: Reflective 3-step flow with mood selection and personalization

### Specialized Modes ✅
- **First Responder Mode**: Incident capture, debrief coaching, recovery planning, privacy protection
- **Coach Mode**: Coaching tools, fitness tracking, progress monitoring, client sharing

### Technical Features ✅
- **ECHO Response System**: Complete dignified response generation layer
  - Phase-aware response adaptation for all 6 ATLAS phases
  - RIVET-lite safety validation with dignity protection
  - MIRA memory grounding with semantic concept extraction
  - Emotional intelligence with context-aware resonance
  - Voice consistency maintaining LUMARA's authentic tone
  - Graceful fallback mechanisms ensuring system reliability
- **MIRA Semantic Memory System**: Complete semantic memory graph with mixed-version MCP support
  - Chat analytics with ChatMetricsService and EnhancedInsightService
  - Combined journal+chat insights with 60/40 weighting
  - Mixed schema exports (node.v1 legacy + node.v2 chat sessions)
  - Golden bundle validation with comprehensive test suite (6/6 tests passing)
- **MCP Export/Import System**: Complete MCP Memory Bundle v1 format support for AI ecosystem interoperability
  - Export with four storage profiles (minimal, space_saver, balanced, hi_fidelity)
  - Import with validation and error handling
  - Settings integration with dedicated MCP Export/Import buttons
  - Automatic data conversion between app's JournalEntry model and MCP format
  - Progress tracking and real-time status updates
  - Mixed-version exports with AJV-ready JSON validation
- **Settings & Privacy**: Complete privacy controls, data management, and personalization
- **Accessibility**: Full WCAG compliance with screen reader support and performance monitoring
- **Export**: PNG and JSON data export with share functionality
- **Error Recovery**: Comprehensive force-quit recovery and startup resilience

### Data Models
- **JournalEntry**  
```json
{
  "id": "...",
  "createdAt": "...",
  "text": "...",
  "audioUri": null,
  "sage": { "situation": "", "action": "", "growth": "", "essence": "" },
  "keywords": ["..."],
  "emotion": { "valence": 0, "arousal": 0 },
  "phaseHint": "Discovery"
}
```

- **ArcformSnapshot**  
```json
{
  "id": "...",
  "entryId": "...",
  "createdAt": "...",
  "keywords": ["..."],
  "geometry": "Spiral",
  "colorMap": { "keyword": "#hex" },
  "edges": [[0,1,0.8]]
}
```

- **UserProfile**  
```json
{
  "uid": "...",
  "onboarding": { "intent": "growth", "tone": "calm", "rhythm": "daily" },
  "prefs": {}
}
```

---

## Engineering Priorities
1. **Production Deployment**: App is ready for production deployment with all core features stable ✅
2. **MIRA Insights Complete**: Mixed-version MCP analytics with chat integration fully implemented ✅
3. **Feature Enhancement**: Continue developing advanced features like enhanced MIRA graph visualization and cloud sync
4. **Performance Optimization**: Monitor and optimize performance across all platforms
5. **User Experience**: Refine UI/UX based on user feedback and testing
6. **Platform Expansion**: Ensure compatibility across iOS, Android, and other platforms  

---

## Design Goals
- **Atmosphere**: journaling should feel sacred, calm, and meaningful.  
- **Visuals**: glowing constellations, soft gradients, motion inspired by nature.  
- **Dignity**: no harsh errors, language is always supportive.  
- **Performance**: 60 fps animations, smooth iOS feel.  

---

This is the **ARC MVP brief for Cursor**.
The project is now **production-ready** with:
1. ✅ All startup and navigation issues resolved - app boots reliably and flows work end-to-end
2. ✅ Complete data pipeline (journal entry → keywords → Arcform snapshot) implemented and tested
3. ✅ Reflective, humane tone maintained throughout the UI with sacred journaling experience
4. ✅ Production-ready features: First Responder Mode, Coach Mode, MCP Export/Import, Accessibility, Settings
5. ✅ MCP Memory Bundle v1 integration for AI ecosystem interoperability with Settings UI
6. ✅ MIRA Insights Complete: Mixed-version MCP support with chat analytics and combined insights (ALL TESTS PASSING)
7. ✅ Insights System Fixed: Keyword extraction, rule evaluation, and template rendering now working properly
8. ✅ LUMARA Prompts Complete: Universal system prompt with MCP Bundle Doctor validation and CLI tools
9. ✅ LUMARA Context Provider Fixed: Phase detection now works with content analysis fallback for accurate journal entry processing
10. ✅ ECHO Module Complete: Dignified response generation layer with phase-awareness, safety validation, and voice consistency
11. ✅ Comprehensive testing, documentation, and error handling implemented  

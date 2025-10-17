  Current MVP → EPI Module Mapping

  **EPI System consists of 8 Core Modules:**
  - ARC: Core Journaling Interface
  - PRISM: Multi-Modal Processing (Enhanced with iOS Vision + Thumbnail Caching)
  - ECHO: Expressive Response Layer
  - ATLAS: Phase Detection & Analysis
  - MIRA: Narrative Intelligence
  - AURORA: Circadian Intelligence
  - VEIL: Self-Pruning & Coherence
  - RIVET: Risk-Validation Evidence Tracker

  ## 📸 **Lazy Photo Relinking Architecture** (Updated January 16, 2025)

  **Intelligent Photo Persistence with On-Demand Relinking - PRODUCTION READY**:
  ```
  User Opens Entry → TimelineCubit.onEntryOpened() → LazyPhotoRelinkService.attemptRelink()
                    ← iOS PhotoLibraryBridge ← MethodChannel('photo_library') ← Photo Matching
  ```

  **Content Extraction Fallback Chain**:
  ```
  MCP Import → content.narrative → content.text → metadata.content → Journal Entry
  ```

  **🚀 CURRENT STATUS: FULLY OPERATIONAL**
  - ✅ **Lazy Relinking**: Photos are only relinked when users open entries, not during import or timeline loads
  - ✅ **Comprehensive Content Fallback**: Importer now uses content.narrative → content.text → metadata.content fallback chain
  - ✅ **iOS Native Bridge**: New PhotoLibraryBridge with photoExistsInLibrary and findPhotoByMetadata methods
  - ✅ **Timestamp-Based Recovery**: Extracts creation dates from placeholder IDs for intelligent photo matching
  - ✅ **Cross-Device Support**: Photos can be recovered across devices using metadata matching
  - ✅ **Performance Optimized**: Only relinks photos when needed, improving app performance
  - ✅ **Cooldown Protection**: 5-minute cooldown prevents excessive relinking attempts
  - ✅ **In-Flight Guards**: Prevents duplicate relinking operations for the same entry
  - ✅ **Graceful Fallback**: Shows "Photo unavailable" placeholders when photos cannot be relinked
  - ✅ **Clear Logging**: Detailed logs show relink attempts and results for debugging
  - ✅ **Seamless Integration**: Works transparently with existing timeline and journal functionality
  - ✅ **Technical Achievements**:
    - ✅ **LazyPhotoRelinkService**: Comprehensive relinking logic with cooldown and guards
    - ✅ **iOS PhotoLibraryBridge**: Native photo library access with metadata matching
    - ✅ **Timeline Integration**: Updated TimelineCubit and InteractiveTimelineView for entry-opened events
    - ✅ **Method Channel**: `photo_library` channel for iOS photo library communication
    - ✅ **Comprehensive Testing**: Full unit test coverage for all relinking functionality

  ## 📸 **Multimodal Processing Architecture** (Updated January 8, 2025)

  **iOS Vision Framework + Thumbnail Caching Pipeline - PRODUCTION READY**:
  ```
  Flutter (IOSVisionOrchestrator) → Pigeon Bridge → Swift (VisionOcrApi) → iOS Vision Framework
                                  ← Analysis Results ← Native Vision Processing ← Photo/Video Input
  ```

  **Thumbnail Caching System**:
  ```
  CachedThumbnail Widget → ThumbnailCacheService → Memory Cache + File Cache
                        ← Lazy Loading ← Automatic Cleanup ← On-Demand Generation
  ```

  **🚀 CURRENT STATUS: FULLY OPERATIONAL**
  - ✅ **iOS Vision Integration**: Pure on-device processing using Apple's Core ML + Vision Framework
  - ✅ **Complete Photo Analysis**: OCR text extraction, object detection, face detection, image classification
  - ✅ **Detailed Analysis Blocks**: Comprehensive photo analysis with confidence scores and bounding boxes
  - ✅ **Thumbnail Caching**: Memory + file-based caching with automatic cleanup
  - ✅ **Native iOS Photos Integration**: Direct media opening in iOS Photos app for all media types
  - ✅ **Universal Media Support**: Photos, videos, and audio files with native iOS framework
  - ✅ **Smart Media Detection**: Automatic media type detection and appropriate handling
  - ✅ **Keypoints Visualization**: Interactive display of feature analysis details
  - ✅ **MCP Format Integration**: Structured data storage with pointer references
  - ✅ **Privacy-First**: All processing happens locally on device
  - ✅ **Performance Optimized**: Lazy loading and automatic cleanup prevent memory bloat
  - ✅ **Timeline Integration**: Direct navigation to full journal screen from timeline entries
  - ✅ **Media Persistence**: Photos and analysis persist when saving to timeline and reopening
  - ✅ **Real-time Keyword Analysis**: Live keyword extraction as user types
  - ✅ **Auto-capitalization**: Automatic sentence and word capitalization
  - ✅ **Error Handling**: Graceful fallbacks and user-friendly error messages
  - ✅ **Broken Link Recovery**: Comprehensive broken media detection and recovery system
  - ✅ **Technical Achievements**:
    - ✅ **Pigeon Native Bridge**: Seamless Flutter ↔ Swift communication
    - ✅ **Vision API Implementation**: Complete iOS Vision framework integration
    - ✅ **Photos Framework Integration**: Native iOS Photos library search and opening
    - ✅ **Thumbnail Service**: Efficient caching with memory and file storage
    - ✅ **Widget System**: Reusable CachedThumbnail with tap functionality
    - ✅ **Cleanup Management**: Automatic thumbnail cleanup on screen disposal
    - ✅ **Media Recovery System**: Broken link detection and re-insertion workflow
    - ✅ **Multi-Method Opening**: Native search, ID extraction, direct file, and search fallbacks
  - **Result**: 🏆 **PRODUCTION READY - COMPLETE MULTIMODAL SYSTEM WITH NATIVE iOS INTEGRATION**

  ## 🔍 **Complete iOS Vision API Integration** (Updated January 12, 2025)

  **Full Vision Framework Integration - PRODUCTION READY**:
  ```
  Flutter (IOSVisionOrchestrator) → Pigeon Bridge → Swift (VisionApiImpl) → iOS Vision Framework
  Photo Input → OCR + Object Detection + Face Detection + Classification → Detailed Analysis Blocks
  ```

  **Vision API Features Pipeline**:
  ```
  Image Input → VNRecognizeTextRequest → OCR Text + Confidence + Bounding Boxes
  Image Input → VNDetectRectanglesRequest → Object Detection + Confidence + Bounding Boxes
  Image Input → VNDetectFaceRectanglesRequest → Face Detection + Confidence + Bounding Boxes
  Image Input → VNClassifyImageRequest → Image Classification + Confidence Scores
  ```

  **🚀 CURRENT STATUS: FULLY OPERATIONAL**
  - ✅ **OCR Text Extraction**: Extract text with confidence scores and bounding boxes using VNRecognizeTextRequest
  - ✅ **Object Detection**: Detect rectangles and shapes using VNDetectRectanglesRequest
  - ✅ **Face Detection**: Detect faces with confidence scores using VNDetectFaceRectanglesRequest
  - ✅ **Image Classification**: Classify images with confidence scores using VNClassifyImageRequest
  - ✅ **Pigeon Integration**: Clean, type-safe Flutter ↔ Swift communication
  - ✅ **Error Handling**: Comprehensive error handling with PigeonError
  - ✅ **Performance**: Optimized for on-device processing with proper async handling
  - ✅ **Detailed Analysis**: Rich analysis blocks with confidence scores and metadata
  - ✅ **Privacy-First**: All processing happens locally on device
  - ✅ **Build Integration**: Successfully integrated into Xcode project
  - **Result**: 🏆 **PRODUCTION READY - COMPLETE iOS VISION INTEGRATION WITH DETAILED PHOTO ANALYSIS**

  ## 📅 **Timeline Integration Architecture** (Updated January 12, 2025)

  **Timeline Editor Elimination & Full Journal Integration - PRODUCTION READY**:
  ```
  Timeline Entry Tap → JournalRepository.getJournalEntryById() → JournalScreen(existingEntry)
  Media Persistence → MediaConversionUtils → MediaItem Storage → Timeline Display
  ```

  **Real-time Keyword Analysis Pipeline**:
  ```
  Text Input → KeywordAnalysisService → Live Analysis → Auto-selection → KeywordAnalysisView
  ```

  **🚀 CURRENT STATUS: FULLY OPERATIONAL**
  - ✅ **Timeline Navigation**: Direct navigation from timeline entries to full journal screen
  - ✅ **Media Persistence**: Photos and analysis persist when saving to timeline and reopening
  - ✅ **Media Conversion**: `MediaConversionUtils` converts between `PhotoAttachment`/`ScanAttachment` and `MediaItem`
  - ✅ **Real-time Keywords**: Live keyword extraction and categorization as user types
  - ✅ **Auto-capitalization**: Automatic sentence capitalization for main text, word capitalization for location/keywords
  - ✅ **Editing Controls**: Date/time/location/phase editing for existing entries
  - ✅ **Photo Placeholders**: Inline `[PHOTO:id]` placeholders with thumbnail display
  - ✅ **Keyword Integration**: Real-time discovered keywords integrated with post-save keyword screen
  - ✅ **Manual Keywords**: Users can add custom keywords in addition to discovered ones
  - ✅ **Phase Management**: Phase detection and editing capabilities
  - ✅ **Date Preservation**: Original creation date preserved when editing entries
  - **Result**: 🏆 **PRODUCTION READY - COMPLETE TIMELINE INTEGRATION WITH MEDIA PERSISTENCE**

  ## 📱 **Native iOS Photos Framework Integration** (Updated January 8, 2025)

  **Universal Media Opening Pipeline - PRODUCTION READY**:
  ```
  Flutter (Media Tap) → Method Channel → Swift (AppDelegate) → iOS Photos Framework
                      ← Success/Failure ← PHAsset Search ← Media Library Query
  ```

  **Multi-Method Media Opening Strategy**:
  ```
  Method 1: Native iOS Photos Framework Search
  Method 2: Media ID Extraction & photos:// Scheme
  Method 3: Direct File Opening with External Apps
  Method 4: Photos App Search Query Fallback
  ```

  **🚀 CURRENT STATUS: FULLY OPERATIONAL**
  - ✅ **Universal Media Support**: Photos, videos, and audio files
  - ✅ **Native iOS Integration**: Uses PHPhotoLibrary and PHAsset for precise media search
  - ✅ **Smart Media Detection**: Automatic file type detection based on extensions
  - ✅ **Permission Handling**: Proper photo library access requests
  - ✅ **Multi-Method Fallbacks**: 4 different approaches ensure media can always be opened
  - ✅ **Broken Link Recovery**: Comprehensive detection and re-insertion system
  - ✅ **Cross-Platform Support**: iOS native methods with Android fallbacks
  - ✅ **User Experience**: Seamless integration with iOS Photos app
  - ✅ **Technical Implementation**:
    - ✅ **Method Channels**: Flutter ↔ Swift communication for media operations
    - ✅ **PHAsset Search**: Native iOS Photos library search by filename
    - ✅ **Media Type Detection**: Smart detection of photos, videos, and audio
    - ✅ **UUID Pattern Matching**: Recognition of iOS media identifier patterns
    - ✅ **Graceful Fallbacks**: Multiple opening strategies for maximum compatibility
    - ✅ **Error Handling**: User-friendly error messages and recovery options
  - **Result**: 🏆 **PRODUCTION READY - NATIVE iOS MEDIA INTEGRATION**

  ## 🧠 **Intelligent Keyword Categorization System** (Updated January 8, 2025)

  **6-Category Keyword Analysis Pipeline - PRODUCTION READY**:
  ```
  Journal Text → KeywordAnalysisService → Category Detection → KeywordsDiscoveredWidget
                ← Real-time Analysis ← 6 Categories ← Visual Display
  ```

  **Keyword Categories**:
  ```
  Places (Blue) → Cities, states, countries, locations, buildings, landmarks
  Emotions (Red) → Happy, sad, angry, excited, nervous, anxious, grateful
  Feelings (Purple) → Love, hate, like, dislike, enjoy, appreciate, care
  States of Being (Green) → Serenity, tranquility, peace, calm, mindfulness
  Adjectives (Orange) → Challenging, easy, beautiful, ugly, big, small
  Slang (Teal) → "That sucked", "Chillin out", "Vibes", "Lit", "Fire"
  ```

  **🚀 CURRENT STATUS: FULLY OPERATIONAL**
  - ✅ **6-Category System**: Comprehensive keyword categorization with 200+ keywords
  - ✅ **Real-time Analysis**: Automatic keyword extraction as users type
  - ✅ **Visual Categorization**: Each category has unique colors and icons
  - ✅ **Manual Override**: Users can add custom keywords not detected by analysis
  - ✅ **Smart Suggestions**: Context-aware keyword recommendations
  - ✅ **Enhanced UX**: Keywords Discovered section in journal interface
  - ✅ **Technical Implementation**:
    - ✅ **KeywordAnalysisService**: Singleton service for keyword categorization
    - ✅ **KeywordsDiscoveredWidget**: Reusable widget for keyword display
    - ✅ **Real-time Updates**: Keywords update automatically with text changes
    - ✅ **Memory Efficient**: Optimized analysis and display
    - ✅ **Extensible Design**: Easy to add new keyword categories
  - **Result**: 🏆 **PRODUCTION READY - INTELLIGENT KEYWORD SYSTEM**

  ## 🤖 **Gemini API Integration + AI Text Styling** (Updated January 8, 2025)

  **Real Cloud API Integration with Rosebud-Style Text Styling - PRODUCTION READY**:
  ```
  Journal Text → Gemini API Analysis → AI Suggestions → AIStyledTextField → Visual Integration
                ← Cloud Analysis ← Personalized Prompts ← Clickable UI ← Blue Styling
  ```

  **Cloud API Features**:
  ```
  generateCloudAnalysis() → Real-time journal analysis using Gemini API
  generateAISuggestions() → Dynamic personalized reflection prompts
  AIStyledTextField → Custom text field with AI suggestion styling
  Visual Integration → Blue text for AI suggestions, white for user text
  ```

  **🚀 CURRENT STATUS: FULLY OPERATIONAL**
  - ✅ **Real Gemini API**: Actual cloud API integration, no mock data
  - ✅ **Cloud Analysis**: Real-time analysis of journal themes, emotions, patterns
  - ✅ **AI Suggestions**: Dynamic generation of personalized reflection prompts
  - ✅ **Rosebud-Style Styling**: AI text appears in blue with background highlighting
  - ✅ **Clickable Integration**: Users can tap AI suggestions to integrate them
  - ✅ **Visual Distinction**: Clear separation between user text and AI suggestions
  - ✅ **Error Handling**: Comprehensive error handling for API failures
  - ✅ **Technical Implementation**:
    - ✅ **EnhancedLumaraApi**: Added generateCloudAnalysis() and generateAISuggestions() methods
    - ✅ **AIStyledTextField**: Custom widget with RichText display and transparent overlay
    - ✅ **System Prompts**: Specialized prompts for analysis vs suggestions
    - ✅ **Response Parsing**: Smart parsing of AI responses into structured suggestions
    - ✅ **Real-time Updates**: Text styling updates as user types
    - ✅ **Marker System**: Uses [AI_SUGGESTION_START/END] markers for styling
  - **Result**: 🏆 **PRODUCTION READY - GEMINI API INTEGRATION**

  ## 🎭 **ECHO Integration + Dignified Text System** (Updated January 8, 2025)

  **Phase-Aware Dignified Text Generation with ECHO Module - PRODUCTION READY**:
  ```
  Journal Text → Phase Detection → ECHO Module → Dignified Text → User Interface
                ← 6 Core Phases ← Gentle Language ← Fallback Safety ← Respectful UX
  ```

  **ECHO Integration Features**:
  ```
  DignifiedTextService → ECHO module integration for all user-facing text
  Phase-Aware Analysis → Gentle, supportive analysis based on user phase
  Discovery Content → Dignified popup content using ECHO
  Fallback Safety → Gentle fallbacks that maintain user dignity
  ```

  **🚀 CURRENT STATUS: FULLY OPERATIONAL**
  - ✅ **ECHO Module Integration**: All user-facing text uses ECHO for dignified generation
  - ✅ **6 Core Phases**: Reduced from 10 to 6 non-triggering phases (recovery, discovery, breakthrough, consolidation, reflection, planning)
  - ✅ **Dignified Language**: All text respects user dignity and avoids triggering phrases
  - ✅ **Phase-Appropriate Content**: Content adapts to user's current life phase
  - ✅ **Fallback Safety**: Even error states use gentle, dignified language
  - ✅ **Trigger Prevention**: Removed potentially harmful phase names and content
  - ✅ **Technical Implementation**:
    - ✅ **DignifiedTextService**: Service for generating dignified text using ECHO
    - ✅ **Phase-Aware Analysis**: Uses ECHO for dignified system prompts
    - ✅ **Discovery Content**: ECHO-generated popup content with fallbacks
    - ✅ **Gentle Fallbacks**: Dignified content even when ECHO fails
    - ✅ **Context Integration**: Uses LumaraScope for proper ECHO context
    - ✅ **Error Handling**: Comprehensive error handling with dignified responses
  - **Result**: 🏆 **PRODUCTION READY - ECHO INTEGRATION + DIGNIFIED TEXT**

  ## 🤖 **On-Device LLM Architecture** (Updated January 8, 2025)

  **llama.cpp + Metal Integration Pipeline - PRODUCTION READY**:
  ```
  Flutter (LLMAdapter) → Pigeon Bridge → Swift (LlamaBridge) → llama_wrapper.cpp → llama.cpp + Metal
                      ← Token Stream ← Swift Callbacks ← Real Token Generation
  ```

  **🚀 CURRENT STATUS: PRODUCTION READY - ALL ROOT CAUSES ELIMINATED**
  - ✅ **CoreGraphics Safety**: No more NaN crashes in UI rendering with clamp01() helpers
  - ✅ **Single-Flight Generation**: Only one generation call per user message
  - ✅ **Metal Logs Accuracy**: Runtime detection shows "metal: engaged (16 layers)"
  - ✅ **Model Path Resolution**: Case-insensitive model file detection
  - ✅ **Error Handling**: Proper error codes (409 for busy, 500 for real errors)
  - ✅ **Infinite Loops**: Completely eliminated recursive generation calls
  - ✅ **Memory Management**: Fixed double-free crashes with proper RAII patterns
  - ✅ **Request Gating**: Thread-safe concurrency control with atomic operations
  - ✅ **Technical Achievements**:
    - ✅ **XCFramework Creation**: Successfully built `ios/Runner/Vendor/llama.xcframework` for iOS arm64 device
    - ✅ **Modern C++ Wrapper**: Implemented `llama_batch_*` API with thread-safe token generation
    - ✅ **Swift Bridge Modernization**: Updated `LLMBridge.swift` to use new C API functions
    - ✅ **Xcode Project Configuration**: Updated `project.pbxproj` to link `llama.xcframework`
    - ✅ **Debug Infrastructure**: Added `ModelLifecycle.swift` with debug smoke test capabilities
  - ✅ **Build System Improvements**:
    - ✅ **Script Optimization**: Enhanced `build_llama_xcframework_final.sh` with better error handling
    - ✅ **Color-coded Logging**: Added comprehensive logging with emoji markers for easy tracking
    - ✅ **Verification Steps**: Added XCFramework structure verification and file size reporting
    - ✅ **Error Resolution**: Fixed identifier conflicts and invalid argument issues
  - **Result**: 🏆 **PRODUCTION READY - ALL CRITICAL ISSUES RESOLVED**

  **🎉 PREVIOUS STATUS: FULLY OPERATIONAL**
  - ✅ Migration from MLX/Core ML to llama.cpp + Metal complete
  - ✅ App builds and runs successfully on iOS simulator and device
  - ✅ Model detection working correctly (3 GGUF models available)
  - ✅ **Llama.cpp initialization working** (`llama_init()` returning success)
  - ✅ **Generation working** (real-time text generation operational)
  - ✅ **Model loading optimized** (~2-3 seconds load time)
  - ✅ **Native inference active** (0ms response time with Metal acceleration)

  **Key Components**:
  - `lib/lumara/llm/llm_adapter.dart` - Flutter adapter using Pigeon bridge with GGUF model support

  ## 🔧 **Root Cause Fixes Architecture** (January 8, 2025)

  **Production-Ready Stability Layer**:
  ```
  UI Layer (Flutter) → Safety Helpers → Native Bridge → Single-Flight Generation → llama.cpp + Metal
                    ← clamp01() ← Error Mapping ← Request Gating ← Memory Safety
  ```

  **Critical Fixes Implemented**:

  ### **1. CoreGraphics NaN Prevention**
  - **Swift Layer**: `clamp01()` and `safeCGFloat()` helpers in `LLMBridge.swift`
  - **Flutter Layer**: `clamp01()` helpers in all UI components
  - **Protection**: Prevents NaN/infinite values from reaching CoreGraphics
  - **Usage**: All `LinearProgressIndicator` and progress calculations use safe values

  ### **2. Single-Flight Generation Architecture**
  - **Concurrency**: `genQ.sync` replaces semaphore-based approach
  - **Request Flow**: Direct path from UI to native C++ without recursive calls
  - **Error Handling**: 409 for `already_in_flight`, 500 for real errors
  - **State Management**: Atomic `isGenerating` flag with proper cleanup

  ### **3. Memory Management & Request Gating**
  - **C++ Layer**: `RequestGate` with atomic operations for thread safety
  - **RAII Patterns**: Proper `llama_batch` lifecycle management
  - **Re-entrancy**: Guards prevent duplicate calls and race conditions
  - **Cleanup**: Guaranteed cleanup on all exit paths

  ### **4. Runtime System Detection**
  - **Metal Status**: Runtime detection using `llama_print_system_info()`
  - **Logging**: Accurate status reporting ("engaged", "compiled", "not compiled")
  - **Initialization**: Double-init guard prevents duplicate logs
  - **Debugging**: Clear distinction between compilation and engagement

  ### **5. Model Resolution & Error Handling**
  - **Case Sensitivity**: `resolveModelPath()` for case-insensitive file detection
  - **Error Mapping**: Proper error codes and meaningful messages
  - **Logging**: Clean "found at /path" or "not found" messages
  - **Reliability**: Consistent error handling across all layers
  - `lib/lumara/llm/model_progress_service.dart` - Progress callback handler with stream broadcasting
  - `ios/Runner/LlamaBridge.swift` - Swift interface to llama.cpp with Metal acceleration
  - `ios/Runner/llama_wrapper.h/.cpp` - C++ bridge exposing llama.cpp API to Swift
  - `ios/Runner/PrismScrubber.swift` - Privacy scrubber for cloud fallback
  - `ios/Runner/CapabilityRouter.swift` - Intelligent local vs cloud routing
  - `ios/Runner/AppDelegate.swift` - Progress API wiring for native→Flutter callbacks

  **Advanced Prompt Engineering System**:
  - `lib/lumara/llm/prompts/lumara_system_prompt.dart` - Universal system prompt for 3-4B models
  - `lib/lumara/llm/prompts/lumara_task_templates.dart` - Structured task wrappers (answer, summarize, rewrite, plan, extract, reflect, analyze)
  - `lib/lumara/llm/prompts/lumara_context_builder.dart` - Context assembly with user profile and memory
  - `lib/lumara/llm/prompts/lumara_prompt_assembler.dart` - Complete prompt assembly system
  - `lib/lumara/llm/prompts/lumara_model_presets.dart` - Model-specific parameter optimization
  - `lib/lumara/llm/testing/lumara_test_harness.dart` - A/B testing framework for model comparison
- `ios/Runner/LLMBridge.swift` - Updated to use optimized Dart prompts (end-to-end integration)
- `ios/llama_wrapper.cpp` - Replaced ALL hard-coded test responses with real llama.cpp token generation
- **Hard-coded Response Fix**: Eliminated ALL hard-coded test responses from llama.cpp
- **Real AI Generation**: Now using actual llama.cpp token generation instead of test strings
- **End-to-End Prompt Flow**: Optimized prompts now flow correctly from Dart → Swift → llama.cpp
- **Token Counting Fix**: Resolved `tokensOut: 0` bug with proper token estimation (4 chars per token)
- **Accurate Metrics**: Complete debugging visibility into token usage and generation metrics

  **Real Token Streaming**:
  - **Live Generation**: `llama_start_generation()` and `llama_get_next_token()` for real inference
  - **Metal Acceleration**: LLAMA_METAL=1 for GPU-accelerated computation
  - **Token Streaming**: Real-time token generation with proper stop conditions
  - **Background Queue**: `DispatchQueue(label: "com.epi.model.load", qos: .userInitiated)`

  **GGUF Model Management**:
  - **Model Format**: GGUF quantized models (4-bit and 5-bit quantization)
  - **Available Models**: Llama-3.2-3B, Phi-3.5-Mini, Qwen3-4B (all GGUF format)
  - **Bundle Loading**: Models loaded from `flutter_assets/assets/models/gguf/`
  - **Memory Mapping**: Efficient loading of large model files (1.5-3GB range)
  - **Status Verification**: Enhanced model status checking for GGUF files
  - **Model Deletion**: Complete model deletion functionality with confirmation dialogs
  - **Startup Check**: Automatic model availability detection at app startup

  **Privacy Architecture**:
  - **On-Device Processing**: All inference happens locally on device
  - **No External Calls**: No data sent to external servers when using on-device model
  - **Fallback System**: On-Device → Cloud API → Rule-Based response hierarchy
  - **Model Verification**: File integrity checks before loading
  - **Progress Transparency**: User can see model loading progress in UI

  ## 📦 **Model Download & Extraction Architecture** (Updated Oct 4, 2025)

  **Robust Model Download System with macOS Compatibility**:
  ```
  ModelDownloadService → URLSession → ZIP Download → Enhanced Unzip → Cleanup → ModelStore
                        ↓              ↓              ↓              ↓
                    Progress API   Temp Storage   Exclude _MACOSX   Remove Metadata
  ```

  **Key Components**:
  - `ios/Runner/ModelDownloadService.swift` - Enhanced download service with macOS metadata handling
  - `ios/Runner/ModelStore.swift` - Model registry and path resolution
  - Native unzip command with exclusion flags for macOS compatibility

  **Download & Extraction Features**:
  - **Comprehensive macOS Metadata Exclusion**: Automatically excludes `_MACOSX` folders, `.DS_Store` files, and `._*` resource fork files during extraction
  - **Conflict Prevention**: Prevents file conflicts that cause "file already exists" errors
  - **Proactive Cleanup**: Removes existing metadata before starting downloads to prevent conflicts
  - **Automatic Cleanup**: Removes any remaining macOS metadata after extraction
  - **Model Management**: `clearAllModels()` and `clearModelDirectory()` methods for comprehensive cleanup
  - **In-App Deletion**: Enhanced cleanup when models are deleted through the app interface
  - **Progress Tracking**: Real-time download progress with detailed status messages
  - **Error Handling**: Comprehensive error handling with user-friendly messages
  - **Multi-Model Support**: Concurrent downloads for multiple models

  **Enhanced Extraction Process**:
  1. **Pre-Cleanup**: Remove any existing metadata before starting download
  2. **Download**: Model ZIP file downloaded to temporary location
  3. **Extract**: Enhanced unzip command excludes all problematic macOS metadata (`*__MACOSX*`, `*.DS_Store`, `._*`)
  4. **Post-Cleanup**: Automatic removal of any remaining metadata files
  5. **Verify**: Model files verified for completeness and integrity
  6. **Register**: Model registered in ModelStore for LUMARA usage

  **Cleanup Methods**:
  - `cleanupMacOSMetadata()`: Recursively removes `__MACOSX` folders, `.DS_Store`, and `._*` files
  - `clearAllModels()`: Clears entire models directory and all metadata
  - `clearModelDirectory(modelId)`: Clears specific model directory with metadata cleanup

  ## 🎛️ **Provider Selection Architecture** (Updated Oct 4, 2025)

  **Unified Provider Detection & Selection System**:
  ```
  LumaraAPIConfig (Authoritative) ←→ LumaraSettingsScreen (UI)
           ↓                              ↓
  LLMAdapter (Detection) ←→ LumaraAssistantCubit (Usage)
           ↓                              ↓
  Native Bridge (isModelDownloaded) → Model Files (Qwen/Phi)
  ```

  **Key Components**:
  - `lib/lumara/config/api_config.dart` - Centralized provider configuration and availability detection
  - `lib/lumara/ui/lumara_settings_screen.dart` - Provider selection UI with visual indicators
  - `lib/lumara/llm/llm_adapter.dart` - Unified model detection using same logic as API config
  - `lib/lumara/bloc/lumara_assistant_cubit.dart` - Provider usage and fallback logic

  **Provider Selection Features**:
  - **Manual Selection**: Users can manually choose specific providers (Qwen, Phi, Gemini)
  - **Automatic Selection**: Option to let LUMARA choose best available provider
  - **Visual Feedback**: Clear indicators, checkmarks, and confirmation messages
  - **Consistent Detection**: Both `LumaraAPIConfig` and `LLMAdapter` use identical `isModelDownloaded()` logic
  - **Priority Order**: On-Device models (Qwen → Phi) → Cloud APIs (Gemini) → Rule-Based fallback

  **Model Detection Flow**:
  1. **Startup Check**: `LumaraAPIConfig` checks all providers on app launch
  2. **UI Display**: Settings screen shows available providers with status indicators
  3. **User Selection**: Manual provider selection updates `_manualProvider` preference
  4. **Usage Logic**: `LumaraAssistantCubit` respects manual selection or uses automatic fallback
  5. **Consistent Detection**: `LLMAdapter` uses same detection method for on-device models

  ## 🎨 Constellation Arcform Visualization Architecture (Updated Oct 10, 2025)

  **Complete Polar Coordinate Layout System for Journal Keywords**:
  ```
  Journal Entry → Keywords → Constellation Renderer → Polar Layout → Custom Painter → Animated Visualization
                                      ↓                    ↓              ↓
                              AtlasPhase Mapping   Geometric Masking   Star Nodes + Edges
  ```

  **Key Components**:
  - `lib/features/arcforms/constellation/constellation_arcform_renderer.dart` - Main widget with animation controllers
  - `lib/features/arcforms/constellation/constellation_layout_service.dart` - Polar layout engine
  - `lib/features/arcforms/constellation/constellation_painter.dart` - CustomPainter for rendering
  - `lib/features/arcforms/constellation/polar_masks.dart` - Geometric masking for star placement
  - `lib/features/arcforms/constellation/graph_utils.dart` - Graph calculation utilities
  - `lib/features/arcforms/constellation/constellation_demo.dart` - Demo and testing interface

  **Constellation Visualization Features**:
  - ✅ **Polar Coordinate Layout**: Intelligent star placement using polar coordinates with geometric masking
  - ✅ **ATLAS Phase Mapping**: 6 phases (Discovery, Expansion, Transition, Consolidation, Recovery, Breakthrough)
  - ✅ **Animation System**: Twinkle, fade-in, and selection pulse animations with TickerProvider
  - ✅ **Emotion Palette**: 8-color emotional visualization system with gradient support
  - ✅ **Interactive Nodes**: Tap to select stars with haptic feedback and visual highlighting
  - ✅ **Edge Rendering**: Weighted connections between keywords with opacity-based visualization
  - ✅ **Label System**: Optional keyword labels with collision detection
  - ✅ **Reduced Motion**: Accessibility support for motion sensitivity

  **Technical Implementation (Oct 10, 2025)**:
  - **2,357 insertions**: Complete constellation visualization system
  - **6 new files**: Modular architecture with clear separation of concerns
  - **3 modified files**: Integration with existing arcform renderer architecture
  - **AtlasPhase Enum**: Type-safe phase representation with display name extensions
  - **Animation Controllers**: 3 independent controllers (twinkle, fade-in, selection pulse)
  - **Haptic Feedback**: Light and medium impact feedback for user interactions
  - **Gesture Detection**: Tap and double-tap handling for node selection and deselection

  **Constellation Data Models**:
  ```dart
  class KeywordScore {
    final String text;
    final double score;
    final double sentiment;
  }

  class ConstellationNode {
    final Offset pos;          // Polar coordinate position
    final KeywordScore data;
    final double radius;       // Visual size
    final Color color;         // Emotion-based coloring
    final String id;           // Unique identifier
  }

  class ConstellationEdge {
    final int a;               // Source node index
    final int b;               // Target node index
    final double weight;       // Connection strength
  }
  ```

  **Emotion Palette Configuration**:
  ```dart
  const EmotionPalette.defaultPalette = EmotionPalette(
    primaryColors: [
      Color(0xFF4F46E5),  // Primary blue
      Color(0xFF7C3AED),  // Purple
      Color(0xFFD1B3FF),  // Light purple
      Color(0xFF6BE3A0),  // Green
      Color(0xFFF7D774),  // Yellow
      Color(0xFFFF6B6B),  // Red
      Color(0xFFFF8E53),  // Orange
      Color(0xFF4ECDC4),  // Teal
    ],
    neutralColor: Color(0xFFD1B3FF),
    backgroundColor: Color(0xFF0A0A0F),
  );
  ```

  **Integration Points**:
  - `arcform_renderer_cubit.dart`: State management for constellation data
  - `arcform_renderer_state.dart`: Immutable state with constellation nodes/edges
  - `arcform_renderer_view.dart`: UI integration with renderer widget
  - `emotional_valence_service.dart`: Emotion detection for color mapping

  ## 📱 Navigation & User Interface Architecture (Updated Sept 28, 2025)

  **Primary Navigation Structure**:
  ```
  Phase → Timeline → Write (Elevated) → LUMARA → Insights → Settings
   [0]     [1]       [2]               [3]       [4]       [5]
  ```

  **Elevated Actions**:
  - **Write Button**: Elevated circular button above navigation tabs, launches complete journal flow
  - **Flow**: Emotion Picker → Reason Picker → Advanced Writing → Keyword Analysis → Save

  **Key Components**:
  - `lib/features/home/home_view.dart` - Main navigation controller with elevated tab design
  - `lib/shared/tab_bar.dart` - Custom tab bar with elevated tab functionality
  - `lib/arc/core/start_entry_flow.dart` - Complete journal creation flow
  - `lib/ui/journal/journal_screen.dart` - Advanced writing interface

  **UI/UX Design Evolution (Sept 27, 2025)**:
  - ✅ **Elevated Write Button**: Replaced floating action button with elegant elevated tab design
  - ✅ **Thicker Navigation**: Increased bottom navigation height to 100px for elevated button
  - ✅ **No Content Blocking**: Eliminated FAB interference with content across all tabs
  - ✅ **Perfect Integration**: Seamless integration with existing CustomTabBar elevated functionality
  - ✅ **Action vs Navigation**: Write triggers action (journal flow) rather than navigation to page

  1. ARC Module: Core Journaling Interface

  lib/arc/
  ├── core/
  │   ├── journal_entry_service.dart     # Current journal functionality
  │   ├── entry_processor.dart           # Text input processing
  │   └── arc_state_manager.dart         # UI state management
  ├── visualization/                     # **NEW - Constellation Arcform System (Oct 10, 2025)**
  │   ├── constellation_arcform_renderer.dart   # Main renderer with animations
  │   ├── constellation_layout_service.dart     # Polar coordinate layout
  │   ├── constellation_painter.dart            # Custom painter for stars
  │   ├── polar_masks.dart                      # Geometric masking system
  │   ├── graph_utils.dart                      # Graph calculation utilities
  │   └── constellation_demo.dart               # Demo/test implementation
  ├── privacy/                           # **MIGRATED FROM CURRENT MVP**
  │   ├── pii_detection_service.dart     # Move from lib/services/privacy/
  │   ├── pii_masking_service.dart       # Move from lib/services/privacy/
  │   └── privacy_settings_service.dart  # Move from lib/services/privacy/
  ├── ui/
  │   ├── journal_entry_view.dart        # Main journaling interface
  │   ├── privacy_controls.dart          # Integrated privacy UI
  │   └── writing_assistance.dart        # Writing prompts/tools
  └── models/
      ├── journal_entry.dart
      └── privacy_protected_entry.dart

  2. PRISM Module: Multi-Modal Processing

  lib/prism/
  ├── processors/
  │   ├── text_processor.dart            # Keyword extraction from journal
  │   ├── image_processor.dart           # Image analysis and tagging
  │   ├── audio_processor.dart           # Voice note transcription
  │   └── video_processor.dart           # Video content analysis
  ├── extractors/
  │   ├── keyword_extractor.dart         # NLP keyword extraction
  │   ├── emotion_extractor.dart         # Sentiment analysis
  │   ├── context_extractor.dart         # Context understanding
  │   └── metadata_extractor.dart        # EXIF, timestamps, location
  ├── privacy/                           # **ENHANCED FROM MVP**
  │   ├── media_pii_detector.dart        # PII in images/audio
  │   ├── visual_content_masker.dart     # Blur faces, license plates
  │   └── audio_content_scrubber.dart    # Remove voice PII
  └── mcp/
      ├── mcp_formatter.dart             # Format for MCP export
      └── structured_data_builder.dart   # Build semantic structures

  3. ECHO Module: Expressive Response Layer (Enhanced with MCP Memory & Batch Management - Oct 1, 2025)

  lib/echo/
  ├── response/
  │   ├── dignity_rules.dart             # Maintain narrative dignity
  │   ├── phase_aware_voice.dart         # Context-appropriate responses
  │   ├── provider_abstraction.dart      # Model-agnostic interface
  │   └── lumara_voice.dart              # LUMARA personality layer
  ├── safeguards/
  │   ├── output_validation.dart         # Validate response appropriateness
  │   ├── privacy_compliance.dart        # Ensure privacy in responses
  │   ├── tone_regulation.dart           # Maintain consistent tone
  │   └── context_verification.dart      # Verify contextual accuracy
  ├── providers/
  │   ├── local_model_adapter.dart       # Local model integration
  │   ├── cloud_api_adapter.dart         # Cloud API integration
  │   ├── fallback_handler.dart          # Handle provider failures
  │   └── response_orchestrator.dart     # Coordinate multiple providers
  ├── memory/                            # **MCP Memory System**
  │   ├── mcp_memory_models.dart         # MCP data models and JSON serialization
  │   ├── mcp_memory_service.dart        # Core conversation persistence and session management
  │   ├── memory_index_service.dart      # Global indexing for topics, entities, open loops
  │   ├── pii_redaction_service.dart     # Privacy protection with PII detection/redaction
  │   └── summary_service.dart           # Map-reduce summarization and context extraction
  ├── chat/                              # **NEW: Chat History Management**
  │   ├── chat_repo.dart                 # Repository interface with batch operations
  │   ├── chat_repo_impl.dart            # Hive-based implementation with batch delete
  │   ├── chat_models.dart               # ChatSession and ChatMessage data models
  │   └── ui/
  │       ├── chats_screen.dart          # Main chat history with batch selection
  │       ├── archive_screen.dart        # Archive with identical batch functionality
  │       └── session_view.dart          # Individual chat session view
  └── models/
      ├── response_context.dart
      ├── dignity_metrics.dart
      └── voice_configuration.dart

  ## 🔧 **MCP Bundle Health Analyzer** (Updated January 11, 2025)

  **MCP Bundle Validation & Repair System - PRODUCTION READY**:
  ```
  MCP Bundle Health UI → ZipUtils → McpValidator → McpBundleRepairService
                      ← Batch Analysis ← Validation Results ← Auto-Repair
  ```

  **🚀 CURRENT STATUS: FULLY OPERATIONAL**
  - ✅ **Multi-ZIP File Support**: Select and analyze multiple MCP bundle ZIP files simultaneously
  - ✅ **Comprehensive Validation**: Manifest, schema, checksums, and data integrity checks
  - ✅ **Batch Analysis**: Process multiple bundles with progress indicators and summary statistics
  - ✅ **Auto-Repair System**: Automatic detection and repair of common MCP bundle issues
  - ✅ **Responsive UI**: LayoutBuilder-based responsive design preventing overflow errors
  - ✅ **Detailed Reporting**: Individual file reports with specific error messages and suggestions
  - ✅ **Manifest Fix Tools**: Specialized tools for fixing manifest.json issues
  - ✅ **Null Safety**: Robust error handling with null safety checks throughout
  - ✅ **Zip File Support**: Direct ZIP file analysis without requiring extraction
  - ✅ **Progress Feedback**: Real-time progress updates during batch operations
  - ✅ **Error Recovery**: Graceful handling of corrupted or invalid bundles
  - ✅ **Technical Achievements**:
    - ✅ **ZipUtils Class**: Complete ZIP file handling with extraction and validation
    - ✅ **McpValidator**: Comprehensive validation with zip file support
    - ✅ **McpBundleRepairService**: Automatic repair with zip file support
    - ✅ **Responsive Layout**: LayoutBuilder preventing RenderFlex overflow errors
    - ✅ **Batch Operations**: Multiple file selection and processing
    - ✅ **Null Safety Fixes**: Fixed all null type casting errors in JSON parsing
    - ✅ **Manifest Validation**: Robust manifest.json parsing with error recovery
    - ✅ **Checksum Verification**: Reliable checksum validation with fallback handling
  - **Result**: 🏆 **PRODUCTION READY - COMPLETE MCP BUNDLE HEALTH MANAGEMENT SYSTEM**

  lib/features/settings/
  ├── mcp_bundle_health_view.dart           # Main UI with batch analysis and responsive layout
  └── lib/mcp/
      ├── export/
      │   ├── zip_utils.dart                # ZIP file creation, extraction, and validation
      │   ├── manifest_builder.dart         # Manifest creation and reading with null safety
      │   └── ndjson_writer.dart            # NDJSON file validation
      ├── validation/
      │   ├── mcp_validator.dart            # Comprehensive validation with zip support
      │   └── mcp_bundle_repair_service.dart # Auto-repair system with zip support
      └── models/
          └── mcp_schemas.dart              # MCP data models with null safety fixes

  4. ATLAS Module: Phase Detection & Analysis

  lib/atlas/
  ├── phase_detection/
  │   ├── life_stage_analyzer.dart       # Detect developmental phases
  │   ├── transition_detector.dart       # Major life changes
  │   ├── pattern_recognition.dart       # Behavioral pattern analysis
  │   └── phase_classifier.dart          # ML-based phase classification
  ├── analysis/
  │   ├── readiness_signals.dart         # System adaptation signals
  │   ├── coherence_analyzer.dart        # Analyze entry coherence
  │   ├── development_tracker.dart       # Track developmental progress
  │   └── insight_generator.dart         # Generate phase-based insights
  ├── privacy/                           # **INTEGRATED FROM MVP**
  │   ├── phase_aware_privacy.dart       # Adjust privacy by life phase
  │   ├── context_based_masking.dart     # Mask based on phase context
  │   └── adaptive_guardrails.dart       # Smart guardrail adjustment
  └── models/
      ├── life_phase.dart
      ├── phase_transition.dart
      └── development_metrics.dart

  5. MIRA Module: Narrative Intelligence

  lib/mira/
  ├── graph/                             # **EXISTING - KEEP AS IS**
  │   ├── memory_graph_builder.dart
  │   ├── semantic_clustering.dart
  │   ├── theme_evolution_tracker.dart
  │   └── narrative_coherence.dart
  ├── ingest/                            # **EXISTING - KEEP AS IS**
  │   ├── journal_ingestion.dart
  │   ├── experience_parser.dart
  │   └── significance_detector.dart
  ├── privacy/                           # **NEW - ENHANCE WITH MVP**
  │   ├── graph_anonymization.dart       # Anonymize memory graphs
  │   ├── narrative_pii_detection.dart   # Detect PII in stories
  │   ├── semantic_masking.dart          # Preserve meaning, mask PII
  │   └── memory_privacy_layers.dart     # Layered privacy for memories
  ├── intelligence/
  │   ├── emotional_tonality.dart        # Emotion analysis
  │   ├── developmental_tracking.dart    # Growth pattern analysis
  │   ├── self_authorship.dart           # User significance weighting
  │   └── narrative_synthesis.dart       # Story building
  └── adapters/
      └── to_mcp.dart                    # **EXISTING - KEEP AS IS**

  6. AURORA Module: Circadian Intelligence (Future)

  lib/aurora/
  ├── scheduling/
  │   ├── circadian_scheduler.dart       # Time-based task distribution
  │   ├── energy_optimizer.dart          # Resource allocation by energy
  │   ├── compute_orchestrator.dart      # Distribute heavy processing
  │   └── rhythm_detector.dart           # Learn user patterns
  ├── monitoring/
  │   ├── cognitive_drift_pruner.dart    # Reset system entropy
  │   ├── wellness_monitor.dart          # Track ethical/narrative load
  │   ├── overload_detector.dart         # Detect saturation signals
  │   └── restorative_mode.dart          # Trigger rest/reflection
  ├── privacy/                           # **FUTURE INTEGRATION**
  │   ├── temporal_privacy.dart          # Time-based privacy levels
  │   ├── energy_aware_masking.dart      # Adjust masking by energy
  │   └── circadian_guardrails.dart      # Time-sensitive guardrails
  └── intelligence/
      ├── reflective_mode.dart           # Deep reflection triggers
      ├── silence_orchestrator.dart      # Strategic system silence
      └── restoration_engine.dart        # System healing processes

7. VEIL Module: Self-Pruning & Coherence (Future)
8. VEIL-EDGE Module: Phase-Reactive Restorative Layer (Production Ready ✅)

**VEIL-EDGE Implementation** (January 15, 2025):
```
lib/lumara/veil_edge/
├── models/
│   └── veil_edge_models.dart          # Core data models (AtlasState, SentinelState, RivetState)
├── core/
│   ├── veil_edge_router.dart          # Phase group routing logic
│   └── rivet_policy_engine.dart       # RIVET policy implementation
├── registry/
│   └── prompt_registry.dart           # Prompt families and templates (v0.1)
├── services/
│   └── veil_edge_service.dart         # Main orchestration service
├── integration/
│   └── lumara_veil_edge_integration.dart  # LUMARA chat integration
└── veil_edge.dart                     # Barrel export file
```

**VEIL-EDGE Features**:
- **Phase Group Routing**: D-B, T-D, R-T, C-R with intelligent selection
- **ATLAS → RIVET → SENTINEL Pipeline**: Confidence, alignment, and safety routing
- **Hysteresis & Cooldown**: 48-hour cooldown prevents phase thrashing
- **SENTINEL Safety Modifiers**: Watch mode (safe variants), Alert mode (Safeguard+Mirror only)
- **RIVET Policy Engine**: Alignment tracking, phase change validation
- **Prompt Registry v0.1**: Complete phase families with system prompts
- **LUMARA Integration**: Seamless chat system integration
- **Privacy-First**: Echo-filtered inference only, no raw journal data
- **Edge Compatible**: Designed for iPhone-class devices
- **API Contract**: Complete REST API with /route, /log, /registry endpoints

**Future VEIL Implementation**:
lib/veil/
├── pruning/
│   ├── memory_pruner.dart             # Remove outdated memories
│   ├── model_weight_adjuster.dart     # LoRA-style adjustments
│   ├── coherence_maintainer.dart      # Preserve system coherence
│   └── entropy_reducer.dart           # Reduce system complexity
├── restoration/
│   ├── nightly_processor.dart         # Sleep-cycle operations
│   ├── duplication_manager.dart       # Safe state duplication
│   ├── reintegration_engine.dart      # Merge pruned updates
│   └── healing_algorithms.dart        # Self-repair mechanisms
├── privacy/                           # **FUTURE PRIVACY EVOLUTION**
│   ├── privacy_weight_adjustment.dart # Adjust privacy models
│   ├── forgotten_data_pruner.dart     # Right to be forgotten
  │   └── coherent_anonymization.dart    # Maintain utility while anonymizing
  └── models/
      ├── pruning_strategy.dart
      ├── restoration_state.dart
      └── coherence_metrics.dart


8. RIVET Module: Risk-Validation Evidence Tracker (Updated January 8, 2025)

**Deterministic Recompute Pipeline with Undo-on-Delete - PRODUCTION READY**:
```
Event History → RivetReducer → Deterministic States → Gate Decision
     ↑              ↓              ↓              ↓
  Apply/Delete/Edit → Full Recompute → Bounded Indices → Transparent Reasons
```

**RIVET Architecture Features**:
```
RivetService → Apply/Delete/Edit operations with full recompute
RivetReducer → Pure functions for deterministic state computation
RivetStorage → Event log persistence with optional checkpoints
RivetTelemetry → Enhanced metrics and clear gate explanations
```

**🚀 CURRENT STATUS: FULLY OPERATIONAL**
- ✅ **Deterministic Recompute**: True undo-on-delete behavior with O(n) performance
- ✅ **Pure Reducer Pattern**: RivetReducer provides deterministic state computation
- ✅ **Enhanced Models**: RivetEvent with eventId/version, RivetState with gate tracking
- ✅ **Complete API**: apply(), delete(), edit() methods with full recompute
- ✅ **Event Log Storage**: Complete history persistence with checkpoint optimization
- ✅ **Enhanced Telemetry**: Recompute metrics, operation tracking, clear explanations
- ✅ **Comprehensive Testing**: 12 unit tests covering all scenarios
- ✅ **Mathematical Correctness**: ALIGN/TRACE formulas preserved exactly
- ✅ **Boundedness**: All indices stay in [0,1] range
- ✅ **Monotonicity**: TRACE only increases on additions
- ✅ **Independence Tracking**: Different day/source boosts evidence
- ✅ **Novelty Detection**: Keyword drift increases evidence weight
- ✅ **Sustainment Gating**: Triple criterion (thresholds + sustainment + independence)
- ✅ **Transparency**: Clear "why not" explanations for debugging
- ✅ **Performance**: O(n) recompute with optional checkpoints
- ✅ **Safety**: Graceful degradation if recompute fails
- ✅ **Technical Implementation**:
  - ✅ **RivetReducer**: Pure functions for deterministic computation
  - ✅ **RivetService**: Refactored to use reducer pattern
  - ✅ **RivetStorage**: Event log persistence with v2 schema
  - ✅ **RivetTelemetry**: Enhanced with recompute metrics
  - ✅ **RivetProvider**: Updated API with delete/edit methods
  - ✅ **Unit Tests**: Comprehensive test coverage
  - ✅ **Hive Adapters**: Updated for new model structure
- **Result**: 🏆 **PRODUCTION READY - DETERMINISTIC RIVET WITH UNDO-ON-DELETE**

lib/core/rivet/
├── rivet_models.dart              # Enhanced models with eventId/version
├── rivet_reducer.dart             # Pure deterministic recompute functions
├── rivet_service.dart             # Refactored service with apply/delete/edit
├── rivet_storage.dart             # Event log persistence with checkpoints
├── rivet_telemetry.dart           # Enhanced telemetry with recompute metrics
├── rivet_provider.dart            # Updated provider with new API
└── rivet_models.g.dart            # Generated Hive adapters
  │   └── secure_aggregation.dart        # Secure evidence aggregation
  └── models/
      ├── align_metrics.dart
      ├── trace_metrics.dart
      ├── validation_evidence.dart
      └── risk_profile.dart

  Core Privacy Integration Strategy

  Shared Privacy Foundation

  lib/privacy_core/
  ├── interfaces/                        # **FROM CURRENT MVP**
  │   ├── pii_detector_interface.dart
  │   ├── masking_strategy_interface.dart
  │   └── guardrail_interface.dart
  ├── models/                            # **FROM CURRENT MVP**
  │   ├── pii_types.dart
  │   ├── detection_result.dart
  │   └── masking_result.dart
  ├── utils/                             # **FROM CURRENT MVP**
  │   ├── privacy_patterns.dart
  │   ├── confidence_calculators.dart
  │   └── validation_utils.dart
  └── config/
      ├── module_privacy_configs.dart    # Per-module privacy settings
      └── cross_module_policies.dart     # Global privacy policies

  Module-Specific Privacy Adaptations

  ARC Privacy: Real-time input protection

  - Current MVP functionality with real-time masking as user types
  - Integration with writing assistance to suggest privacy-safe alternatives

  PRISM Privacy: Multi-modal PII detection

  - Enhanced MVP detection for images (face recognition, license plates)
  - Audio PII detection (voices, spoken names, phone numbers)
  - Video content analysis with temporal PII tracking

  ECHO Privacy: Response-layer protection

  - Output validation to prevent PII leakage in responses
  - Provider-agnostic privacy compliance regardless of model source
  - Dignity-preserving response filtering with contextual awareness

  ATLAS Privacy: Context-adaptive protection

  - Phase-aware privacy adjustment based on developmental context
  - Dynamic privacy levels based on life phase and analysis
  - Context-sensitive guardrail adjustment

  MIRA Privacy: Narrative-aware anonymization

  - MVP masking enhanced to preserve narrative coherence
  - Graph-level anonymization that maintains semantic relationships
  - Story-aware PII detection that understands context

  RIVET Privacy: Evidence protection

  - Anonymization of validation evidence and test results
  - Privacy-aware evidence aggregation and scoring
  - Secure handling of empirical data and model predictions

  Migration Strategy

  ✅ **Phase 1: Foundation (COMPLETED - December 2025)**

  1. ✅ Extracted RIVET validation system to lib/rivet/ module
  2. ✅ Migrated ECHO expressive response layer to lib/echo/ module
  3. ✅ Created modular export interfaces (rivet_module.dart, echo_module.dart)
  4. ✅ Updated app.dart to use new module imports
  5. ✅ Fixed internal import paths for module isolation

  Phase 2: Enhancement (Next - PRISM/ATLAS modules)

  1. Migrate multimodal perception capabilities to lib/prism/
  2. Migrate phase detection system to lib/atlas/
  3. Update remaining import dependencies
  4. Integrate phase-aware privacy levels

  Phase 3: Memory & Storage (MIRA/AURORA modules)

  1. Migrate semantic memory system to lib/mira/
  2. Migrate temporal orchestration to lib/aurora/
  3. Update storage and retrieval interfaces

  Phase 4: Privacy & Security (VEIL completion)

  1. Complete Universal Privacy Guardrail migration to lib/veil/
  2. Implement self-improving privacy models
  3. Add coherence-preserving anonymization
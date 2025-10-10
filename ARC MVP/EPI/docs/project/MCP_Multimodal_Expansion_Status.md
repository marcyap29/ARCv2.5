# MCP Multimodal Expansion - Status Update for ChatGPT

## 🎯 **Project Overview**

**EPI (Enhanced Personal Intelligence)** is a Flutter-based personal AI assistant app that implements a sophisticated **Memory Container Protocol (MCP)** for sovereign, portable, and auditable memory storage. The app is currently on the `multimodal` branch and needs expansion to handle **multimodal messages** (text + images/audio/video) within the MCP framework.

## 🏗️ **Current Architecture**

### **Core Technologies**
- **Framework**: Flutter 3.22.3+ with Dart 3.0.3+
- **Storage**: Hive (NoSQL) for local data persistence
- **AI Stack**: On-device LLMs via llama.cpp (GGUF models)
- **Models**: Llama 3.2 3B Instruct + Qwen3 4B Instruct
- **Platform**: iOS (primary), with Android support

### **MCP Implementation Status**
✅ **Fully Implemented**:
- Complete MCP v1.0 bundle format with manifest, nodes, edges, pointers, embeddings
- Export/Import services with SAGE narrative mapping (Situation, Action, Growth, Essence)
- Privacy-preserving data handling with PII detection
- CLI tools for bundle validation and management
- Integration with journal entries and chat sessions
- Comprehensive test suite with golden contract tests

### **Current Multimodal Capabilities**
✅ **Partially Implemented**:
- **MediaItem Model**: Supports audio, image, video, file types with metadata
- **Journal Integration**: Journal entries can contain multiple media attachments
- **UI Components**: Media strip display for different media types
- **File Handling**: Image picker, audio recording, file selection
- **Transcription**: Audio transcript support
- **OCR**: Text extraction from images

❌ **Missing for Chat Messages**:
- Chat messages are currently text-only (`ChatMessage.content` is String)
- No multimodal content support in chat sessions
- No MCP export/import of multimodal chat content
- No integration with llama.cpp multimodal capabilities

## 🔧 **Technical Implementation Details**

### **Current Data Models**

#### **JournalEntry** (Multimodal Ready)
```dart
class JournalEntry {
  final String content;           // Text content
  final List<MediaItem> media;   // ✅ Multimodal attachments
  final String? audioUri;        // Legacy audio support
  // ... other fields
}
```

#### **ChatMessage** (Text Only)
```dart
class ChatMessage {
  final String content;          // ❌ Text only
  // Missing: List<MediaItem> attachments
  // Missing: multimodal content handling
}
```

#### **MediaItem** (Complete)
```dart
class MediaItem {
  final String uri;              // File path/URI
  final MediaType type;          // audio, image, video, file
  final Duration? duration;      // For audio/video
  final String? transcript;      // Audio transcription
  final String? ocrText;        // Image text extraction
  final int? sizeBytes;          // File size
}
```

### **MCP Schema Support**
The MCP implementation already supports multimodal content through:

#### **McpPointer** (Media References)
```dart
class McpPointer {
  final String mediaType;        // audio, image, video, file
  final String? sourceUri;       // Original file path
  final McpDescriptor descriptor; // Metadata, MIME type, size
  final McpIntegrity integrity;  // Checksums, validation
  final McpPrivacy privacy;     // PII detection, sharing policy
  final McpSamplingManifest samplingManifest; // Spans, keyframes
}
```

#### **McpNode** (Content Entities)
```dart
class McpNode {
  final String? pointerRef;      // Links to McpPointer for media
  final String? contentSummary;  // Text content
  final McpNarrative? narrative; // SAGE structure
  // ... other fields
}
```

## 🚀 **Required Multimodal Expansion**

### **1. Chat Message Model Enhancement**
**Priority**: HIGH
```dart
class ChatMessage {
  final String content;                    // Text content
  final List<MediaItem> attachments;       // NEW: Multimodal content
  final Map<String, dynamic>? metadata;    // NEW: Additional context
  // ... existing fields
}
```

### **2. MCP Export/Import Enhancement**
**Priority**: HIGH
- Extend `McpExportService` to handle chat message attachments
- Create pointers for chat media content
- Map chat attachments to MCP nodes with proper relationships
- Ensure privacy controls for sensitive media

### **3. llama.cpp Multimodal Integration**
**Priority**: MEDIUM
- Integrate with llama.cpp multimodal capabilities
- Support image and audio input processing
- Handle multimodal model responses
- Implement proper model selection for content type

### **4. UI/UX Enhancements**
**Priority**: MEDIUM
- Chat input with media attachment support
- Display multimodal content in chat bubbles
- Media preview and playback controls
- Progress indicators for media processing

## 📋 **Implementation Plan**

### **Phase 1: Core Data Model Updates**
1. **Extend ChatMessage model** to support attachments
2. **Update chat repository** to handle multimodal content
3. **Migrate existing chat data** to new format
4. **Update UI components** for attachment display

### **Phase 2: MCP Integration**
1. **Enhance MCP export service** for chat attachments
2. **Update MCP import service** to restore multimodal chats
3. **Extend MCP schemas** if needed for chat-specific content
4. **Add validation** for multimodal MCP bundles

### **Phase 3: AI Integration**
1. **Integrate llama.cpp multimodal** capabilities
2. **Implement media preprocessing** (resize, compress, transcode)
3. **Add multimodal prompt handling** in LLM adapter
4. **Support multimodal responses** from AI models

### **Phase 4: Advanced Features**
1. **Media analysis** (OCR, transcription, object detection)
2. **Privacy controls** for sensitive media
3. **Performance optimization** for large media files
4. **Cross-platform compatibility** testing

## 🔍 **Key Technical Considerations**

### **Storage & Performance**
- **File Management**: Media files stored in app documents directory
- **Compression**: Automatic image/video compression for storage efficiency
- **Caching**: Thumbnail generation and caching for UI performance
- **Cleanup**: Automatic cleanup of orphaned media files

### **Privacy & Security**
- **PII Detection**: Automatic detection of faces, text, locations in media
- **Encryption**: Optional encryption for sensitive media content
- **Access Control**: Granular permissions for media sharing
- **Audit Trail**: Complete tracking of media access and usage

### **MCP Compliance**
- **Schema Evolution**: Maintain backward compatibility with existing bundles
- **Validation**: Comprehensive validation of multimodal MCP bundles
- **Migration**: Smooth migration path for existing data
- **Documentation**: Updated MCP specification for multimodal content

## 🧪 **Testing Strategy**

### **Unit Tests**
- Chat message model with attachments
- MCP export/import with multimodal content
- Media processing and validation
- Privacy controls and PII detection

### **Integration Tests**
- End-to-end multimodal chat workflows
- MCP bundle round-trip testing
- Cross-platform compatibility
- Performance with large media files

### **Golden Tests**
- Multimodal MCP bundle format stability
- Schema version compatibility
- Real-world multimodal data samples

## 📊 **Success Metrics**

### **Functional Requirements**
- ✅ Chat messages support text + media attachments
- ✅ MCP bundles include multimodal content
- ✅ AI models can process multimodal input
- ✅ Privacy controls work for sensitive media

### **Performance Requirements**
- ✅ Media processing completes within 5 seconds
- ✅ MCP bundles with media export/import within 30 seconds
- ✅ UI remains responsive during media operations
- ✅ Storage usage optimized with compression

### **Quality Requirements**
- ✅ 100% backward compatibility with existing data
- ✅ Comprehensive test coverage (>90%)
- ✅ Zero data loss during migration
- ✅ Privacy controls prevent data leakage

## 🎯 **Next Steps**

1. **Review and approve** this implementation plan
2. **Prioritize features** based on user needs
3. **Set up development environment** for multimodal testing
4. **Begin Phase 1 implementation** with ChatMessage model updates
5. **Create comprehensive test suite** for multimodal functionality

## 📚 **Resources**

### **Documentation**
- MCP Specification: `docs/archive/Archive/Reference Documents/MCP_Memory_Container_Protocol.md`
- Current Implementation: `lib/mcp/` directory
- Test Examples: `test/mcp/` directory
- Golden Data: `mcp/golden/` directory

### **Key Files**
- Chat Models: `lib/lumara/chat/chat_models.dart`
- Media Models: `lib/data/models/media_item.dart`
- MCP Export: `lib/mcp/export/mcp_export_service.dart`
- MCP Import: `lib/mcp/import/mcp_import_service.dart`
- Journal Model: `lib/models/journal_entry_model.dart`

### **Dependencies**
- llama.cpp multimodal: `third_party/llama.cpp/docs/multimodal.md`
- Flutter packages: `pubspec.yaml` (image_picker, audioplayers, etc.)
- Hive storage: Already configured for data persistence

---

**Status**: Ready for implementation
**Branch**: `multimodal`
**Priority**: High
**Estimated Timeline**: 2-3 weeks for core functionality

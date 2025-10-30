# Multimodal MCP Orchestrator

A comprehensive Flutter implementation of the Multimodal MCP Orchestrator system for the EPI app, enabling privacy-first multimodal content handling with MCP (Memory Container Protocol) compliance.

## 🎯 Overview

The Multimodal MCP Orchestrator converts user actions (adding photos, videos, audio) into structured command sequences that:

1. **Analyze** media content via OCP (Optical Character Processing)
2. **Create MCP records** with text + metadata + pointers (never raw media)
3. **Render inline UX** with safe thumbnails and rich popups
4. **Scrub caches** immediately after MCP commit

## 🏗️ Architecture

### Core Components

```
lib/mcp/orchestrator/
├── multimodal_orchestrator_commands.dart    # Command models and enums
├── multimodal_mcp_orchestrator.dart         # Main orchestrator service
├── multimodal_orchestrator_bloc.dart        # BLoC state management
├── orchestrator_command_mapper.dart         # Command-to-implementation mapping
├── ocp_services.dart                        # OCP analysis services
├── mcp_pointer_service.dart                 # Pointer management
├── ui/
│   └── multimodal_ui_components.dart        # UI components
└── examples/
    └── journal_entry_integration.dart       # Integration examples
```

### Command Flow

```
User Action → Orchestrator → Command Generation → BLoC Execution → UI Update
     ↓              ↓              ↓              ↓              ↓
Photo Tap → processUserIntent() → Commands → executeCommands() → Thumbnails
```

## 🚀 Quick Start

### 1. Basic Integration

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:epi/mcp/orchestrator/multimodal_orchestrator_bloc.dart';

class MyJournalWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MultimodalOrchestratorBloc(),
      child: Column(
        children: [
          // Your journal content
          Expanded(child: TextField(...)),
          
          // Multimodal toolbar
          Row(
            children: [
              IconButton(
                onPressed: () => context.read<MultimodalOrchestratorBloc>()
                    .add(const UserTappedPhotoIcon()),
                icon: Icon(Icons.photo_camera),
              ),
              // ... other media buttons
            ],
          ),
          
          // Status indicator
          BlocBuilder<MultimodalOrchestratorBloc, MultimodalOrchestratorState>(
            builder: (context, state) {
              if (state is MultimodalOrchestratorExecuting) {
                return LinearProgressIndicator(value: state.progress);
              }
              return SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
```

### 2. Custom Command Execution

```dart
// Create custom command envelope
final envelope = OrchestratorCommandEnvelope(
  commands: [
    RequestPermissionsCommand(target: 'photos'),
    OpenPickerCommand(kind: 'photo', multi: true),
    RunOcpImageCommand(uri: 'selected_photo_uri'),
    CreatePointerCommand(
      uri: 'photo_uri',
      mediaType: 'image',
      descriptor: {'mime': 'image/jpeg', 'sizeBytes': 1024},
      integrity: {'sha256': 'hash'},
      privacy: {'scope': 'user-library'},
    ),
    CommitMcpNodeCommand(node: {...}),
    CacheScrubCommand(uris: ['temp_files']),
  ],
);

// Execute commands
context.read<MultimodalOrchestratorBloc>()
    .add(ExecuteCommandEnvelope(envelope: envelope));
```

## 📋 Command Reference

### Permission Commands
```dart
RequestPermissionsCommand(target: 'photos' | 'microphone' | 'files')
```

### Media Picker Commands
```dart
OpenPickerCommand(
  kind: 'photo' | 'video' | 'audio',
  multi: true | false,
)
```

### Analysis Commands
```dart
RunOcpImageCommand(uri: 'image_path')
RunOcpVideoCommand(
  uri: 'video_path',
  keyframePolicy: {
    'short_s': 2,
    'medium_s': 4,
    'long_s': 8,
    'thresholds': {'short_lt_s': 60, 'long_gt_s': 300}
  },
)
RunSttCommand(
  uri: 'audio_path',
  modelHint: 'fast' | 'balanced' | 'accurate',
)
```

### MCP Commands
```dart
CreatePointerCommand(
  uri: 'media_path',
  mediaType: 'image' | 'video' | 'audio',
  descriptor: {'mime': 'image/jpeg', 'sizeBytes': 1024},
  integrity: {'sha256': 'hash'},
  privacy: {'scope': 'user-library'},
  samplingManifest: {'keyframes': [...], 'thumbnails': [...]},
)

CommitMcpNodeCommand(
  node: {
    'kind': 'photo' | 'video' | 'voice',
    'pointers': [{'ref': 'pointer_id', 'role': 'primary'}],
    'text': 'analysis_summary',
    'meta': {
      'source': 'OCP',
      'exif': {...},
      'gps': {...},
      'objects': [...],
      'ocr': 'extracted_text',
      'sage': {'S': '...', 'A': '...', 'G': '...', 'E': '...'},
    }
  },
)
```

### UI Commands
```dart
RenderInlineThumbnailCommand(
  pointerRef: 'pointer_id',
  size: 'mini' | 'small' | 'medium',
)

EnableEmbedPopupCommand(
  pointerRef: 'pointer_id',
  behavior: 'openPopup',
  with: 'extractedData',
)

BuildGalleryCommand(pointerRefs: ['id1', 'id2', ...])
```

### Cleanup Commands
```dart
CacheScrubCommand(uris: ['temp_file1', 'temp_file2'])
```

## 🎨 UI Components

### Inline Thumbnail
```dart
InlineThumbnail(
  pointer: mcpPointer,
  size: 'mini', // 48x48
  onTap: () => showPopup(),
  onLongPress: () => showOptions(),
)
```

### Rich Popup
```dart
McpPointerPopup(
  pointer: mcpPointer,
  extractedData: {
    'ocrText': 'extracted text',
    'objects': [...],
    'sage': {...},
  },
)
```

### Gallery View
```dart
McpPointerGallery(
  pointers: [pointer1, pointer2, ...],
  size: 'small', // 72x72
)
```

## 🔧 Configuration

### OCP Services
The OCP services provide placeholder implementations for:
- **Image Analysis**: OCR, object detection, EXIF extraction
- **Video Analysis**: Keyframe extraction, scene analysis
- **Audio Analysis**: Speech-to-text, prosody analysis

### MCP Pointer Service
Handles:
- **Pointer Creation**: Unique IDs, integrity hashing, metadata
- **Pointer Resolution**: File access, integrity verification
- **Thumbnail Generation**: Platform-specific thumbnail creation
- **Cache Management**: Temporary file cleanup

### Privacy Controls
- **PII Detection**: Automatic detection of sensitive information
- **Scope Management**: User-library, user-files, private scopes
- **Retention Policies**: Indefinite, time-based, user-controlled
- **Sharing Policies**: Private, friends, public

## 🧪 Testing

### Unit Tests
```dart
// Test command execution
test('should execute photo flow commands', () async {
  final orchestrator = MultimodalMcpOrchestrator();
  final envelope = await orchestrator.processUserIntent('user tapped photo icon');
  
  expect(envelope.commands.length, greaterThan(0));
  expect(envelope.commands.first, isA<RequestPermissionsCommand>());
});

// Test BLoC state transitions
blocTest<MultimodalOrchestratorBloc, MultimodalOrchestratorState>(
  'emits processing then success when photo icon tapped',
  build: () => MultimodalOrchestratorBloc(),
  act: (bloc) => bloc.add(const UserTappedPhotoIcon()),
  expect: () => [
    isA<MultimodalOrchestratorProcessing>(),
    isA<MultimodalOrchestratorCommandsReady>(),
    isA<MultimodalOrchestratorExecuting>(),
    isA<MultimodalOrchestratorSuccess>(),
  ],
);
```

### Integration Tests
```dart
// Test full photo flow
testWidgets('should handle photo attachment flow', (tester) async {
  await tester.pumpWidget(MyJournalWidget());
  
  // Tap photo button
  await tester.tap(find.byIcon(Icons.photo_camera));
  await tester.pump();
  
  // Verify processing state
  expect(find.text('Processing: user tapped photo icon'), findsOneWidget);
  
  // Wait for completion
  await tester.pumpAndSettle();
  
  // Verify success
  expect(find.text('Success:'), findsOneWidget);
});
```

## 🔒 Security & Privacy

### Data Flow
1. **Media Selection**: User selects media via platform pickers
2. **Temporary Analysis**: OCP analysis on temporary files
3. **MCP Creation**: Only pointers and metadata stored in MCP
4. **Cache Cleanup**: All temporary files immediately deleted
5. **Pointer Resolution**: Media accessed only when needed

### Privacy Features
- **No Raw Media Storage**: Only pointers stored in MCP
- **PII Detection**: Automatic detection and redaction
- **Scope Controls**: Granular privacy scopes
- **Audit Trail**: Complete tracking of all operations
- **User Control**: Full user control over data sharing

## 🚀 Advanced Usage

### Custom Analysis Pipeline
```dart
// Create custom analysis command
final customCommand = RunOcpImageCommand(uri: 'custom_image');
final result = await OrchestratorCommandMapper.executeCommand(customCommand);

// Extract analysis data
final analysis = result.results.first.data['analysis'];
final ocrText = analysis['ocrText'];
final objects = analysis['objects'];
final sage = analysis['sage'];
```

### Batch Processing
```dart
// Process multiple media items
final commands = <OrchestratorCommand>[];
for (final uri in selectedUris) {
  commands.addAll([
    RunOcpImageCommand(uri: uri),
    CreatePointerCommand(...),
    CommitMcpNodeCommand(...),
  ]);
}
commands.add(CacheScrubCommand(uris: tempUris));

final envelope = OrchestratorCommandEnvelope(commands: commands);
context.read<MultimodalOrchestratorBloc>()
    .add(ExecuteCommandEnvelope(envelope: envelope));
```

### Error Handling
```dart
BlocListener<MultimodalOrchestratorBloc, MultimodalOrchestratorState>(
  listener: (context, state) {
    if (state is MultimodalOrchestratorFailure) {
      // Handle failure
      showErrorDialog(state.error);
      
      // Cleanup on failure
      if (state.partialResult != null) {
        // Handle partial results
        processPartialResults(state.partialResult!);
      }
    }
  },
  child: YourWidget(),
);
```

## 📚 Examples

See `examples/journal_entry_integration.dart` for complete integration examples including:
- Basic journal entry with multimodal toolbar
- Advanced integration with existing journal system
- Custom UI components and error handling
- State management and progress tracking

## 🔄 Migration Guide

### From Existing Media System
1. **Replace MediaItem usage** with McpPointer
2. **Update UI components** to use InlineThumbnail
3. **Integrate BLoC** for command orchestration
4. **Update storage** to use MCP format
5. **Add privacy controls** for sensitive content

### Backward Compatibility
- Existing MediaItem models remain supported
- Gradual migration path available
- MCP pointers can reference existing media files
- No data loss during migration

## 🤝 Contributing

1. **Follow MCP Principles**: Privacy-first, pointer-only storage
2. **Maintain Command Contract**: All commands must be JSON-serializable
3. **Add Tests**: Unit and integration tests required
4. **Document Changes**: Update this README for new features
5. **Respect Privacy**: Never store raw media in MCP

## 📄 License

This implementation follows the EPI project's privacy-first, user-sovereign principles. All media content remains under user control with no cloud dependencies.


# LUMARA Integration Guide

## Overview

This guide shows you how to integrate the complete LUMARA system into your existing ARC MVP app.

## ✅ **What's Already Implemented**

### Core Architecture
- ✅ Enhanced LLM Architecture with `lib/llm/` directory
- ✅ `ModelAdapter` interface with `RuleBasedAdapter` and `GeminiAdapter`
- ✅ ArcLLM System with `provideArcLLM()` factory
- ✅ Centralized prompt contracts in `lib/core/prompts_arc.dart`
- ✅ Native bridges for Android (Kotlin) and iOS (Swift)
- ✅ Gemini API integration with streaming support

### UI Components
- ✅ `LumaraAssistantScreen` - Main chat interface with persistent memory
- ✅ `ChatsScreen` - Chat history with search, filter, and archive access
- ✅ `ArchiveScreen` - Dedicated view for archived chat sessions
- ✅ `SessionView` - Individual chat session display with message history
- ✅ `LumaraNavItem` - Bottom navigation item
- ✅ `LumaraQuickPalette` - Quick action suggestions
- ✅ `LumaraConsentSheet` - Privacy settings
- ✅ `LumaraMessage` - Message data model
- ✅ `LumaraScope` - Privacy scope configuration

### State Management
- ✅ `LumaraAssistantCubit` - BLoC for chat state
- ✅ `LumaraAssistantState` - State classes
- ✅ `ChatRepo` & `ChatRepoImpl` - Repository pattern for persistent chat storage
- ✅ Scope toggling and message handling
- ✅ Chat session management with auto-archive policy

## 🔧 **Integration Steps**

### 1. Add LUMARA to Bottom Navigation

Update your bottom navigation to include LUMARA:

```dart
// In your bottom navigation widget
LumaraNavItem(
  isSelected: currentIndex == lumaraIndex,
  onTap: () => setState(() => currentIndex = lumaraIndex),
  onLongPress: () => _showQuickPalette(),
)
```

### 2. Add LUMARA Route

Add the LUMARA screen to your app router:

```dart
// In your app router
GoRoute(
  path: '/lumara',
  builder: (context, state) => BlocProvider(
    create: (context) => LumaraAssistantCubit(
      contextProvider: context.read<ContextProvider>(),
    ),
    child: const LumaraAssistantScreen(),
  ),
)
```

### 3. Initialize LUMARA Service

In your app initialization:

```dart
// In your main.dart or bootstrap.dart
await GemmaService.initialize();
```

### 4. Add LUMARA to App Shell

Update your app shell to include the LUMARA tab:

```dart
// In your app shell
BottomNavigationBar(
  items: [
    // ... existing items
    BottomNavigationBarItem(
      icon: Icon(Icons.psychology),
      label: 'LUMARA',
    ),
  ],
)
```

## 🎯 **Key Features**

### 1. **Privacy-First Design**
- Scope toggles for Journal, Phase, Arcforms, Voice, Media
- All data stays on device with local Hive storage
- PII detection and redaction for export security
- No external API calls for chat storage

### 2. **Smart Response Generation**
- Gemini API via `LLMRegistry` (primary)
- ArcLLM one-liners for consistent contracts
- Rule-based fallback when API unavailable

### 3. **Quick Actions**
- Weekly summary
- Rising patterns
- Phase analysis
- Period comparison
- Prompt suggestions

### 4. **Contextual Insights & Prompts**
- Uses your actual data (journal entries, phase history, etc.)
- Provides source citations
- Maintains conversation history with persistent sessions
- Prompts centralized: `lib/core/prompts_arc.dart` (Dart) and `ios/Runner/Sources/Runner/PromptTemplates.swift` (Swift)

### 5. **Chat Memory System**
- Persistent chat sessions with stable ULID identifiers
- 30-day auto-archive for non-pinned sessions (non-destructive)
- Search and filter chat history by subject or tags
- Archive management with lazy loading for performance
- MCP export integration for AI ecosystem interoperability

## 🔄 **Current Status**

### Working Now
- ✅ Gemini API streaming via ArcLLM
- ✅ Rule-based responses as fallback
- ✅ Privacy scope management
- ✅ Chat interface with persistent message history
- ✅ Chat session management with archive system
- ✅ Quick action palette
- ✅ Device capability detection
- ✅ MCP export for chat sessions and messages
- ✅ MIRA graph integration for semantic memory

- 🔄 On-device engines via iOS bridge using the same prompt contracts
- 🔄 Voice input support
- 🔄 Media analysis capabilities
- 🔄 Advanced pattern recognition

## 🚀 **Testing the Implementation**

1. **Build and run** the app
2. **Navigate to LUMARA** tab
3. **Try quick actions** from the palette
4. **Test scope toggles** in settings
5. **Send custom messages** to test responses

## 📱 **User Experience**

### First Time Users
1. App shows consent sheet for data access
2. User can toggle which data LUMARA can access
3. Quick suggestions help users get started
4. Clear privacy messaging throughout

### Regular Users
1. Quick access to common queries
2. Contextual insights based on their data
3. Persistent conversation history across sessions
4. Source citations for transparency
5. Chat archive management and search capabilities
6. Export chat data for AI ecosystem integration

## 🔧 **Customization**

### Adding New Quick Actions
```dart
// In LumaraQuickPalette
_buildQuickAction(
  context,
  icon: Icons.your_icon,
  title: 'Your Action',
  subtitle: 'Description',
  onTap: () => _sendQuery(context, 'Your query'),
)
```

### Adding New Scope Types
```dart
// In LumaraScope
final bool yourNewScope;

// In LumaraConsentSheet
_buildScopeToggle(
  'Your New Scope',
  'Description',
  _scope.yourNewScope,
  (value) => setState(() {
    _scope = _scope.copyWith(yourNewScope: value);
  }),
  Icons.your_icon,
)
```

## 🎉 **Next Steps**

1. **Test the current implementation** with rule-based responses
2. **Customize the UI** to match your app's design
3. **Add LUMARA to your navigation** structure
4. **Download Gemma model files** when ready for AI inference
5. **Enable MediaPipe dependencies** for full AI capabilities

The LUMARA system is now ready to provide intelligent insights about your users' data while maintaining complete privacy and control!

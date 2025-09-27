# Journal Screen with Integrated LUMARA

This directory contains the new journaling experience that keeps users in the journal while providing a living LUMARA companion and OCR scanning capabilities.

## 🎯 Key Features

### **Inline LUMARA Reflections**
- Floating LUMARA FAB with idle animations and nudge effects
- Bottom sheet with 5 reflection options (ideas, think, perspective, next, analyze)
- Inline reflection blocks that appear within the journal entry
- Phase-aware responses (Recovery, Discovery, Breakthrough, Consolidation)
- Action buttons: Regenerate, Soften tone, More depth, Continue with LUMARA

### **Page Scanning (Bring Your Own Journal)**
- Scan physical journal pages with OCR
- Extract text using platform-specific services (Apple Vision/Google ML Kit)
- Preview and insert scanned text into entries
- Store both image and parsed text as attachments

### **Privacy & Safety**
- PII scrubbing before external API calls
- Deterministic placeholders for sensitive data
- User data sovereignty compliance
- ECHO guardrail integration

### **Session Persistence**
- 24-hour journal session restoration
- Save progress across app switches/crashes
- Restore emotion, reason, text, and media selections

## 📁 File Structure

```
lib/ui/journal/
├── journal_screen.dart              # Main journal screen
├── journal_demo.dart                # Demo integration example
├── README.md                        # This file
└── widgets/
    ├── lumara_fab.dart              # Floating LUMARA button
    ├── lumara_suggestion_sheet.dart # Bottom sheet with options
    └── inline_reflection_block.dart # Inline reflection display
```

## 🔧 Integration

### Basic Usage

```dart
import 'package:my_app/ui/journal/journal_screen.dart';

// Navigate to journal screen
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const JournalScreen(),
  ),
);
```

### Feature Flags

Control features via `FeatureFlags`:

```dart
// Enable/disable features
FeatureFlags.inlineLumara = true;    // LUMARA reflections
FeatureFlags.scanPage = true;        // Page scanning
FeatureFlags.phaseAwareLumara = true; // Phase-aware responses
FeatureFlags.piiScrubbing = true;    // PII protection
FeatureFlags.analytics = true;       // Telemetry
```

### State Management

The journal uses `JournalEntryState` for managing:

```dart
class JournalEntryState {
  String text = '';                    // User's journal text
  String? phase;                       // Current life phase
  List<InlineBlock> blocks = [];       // LUMARA reflections
  List<ScanAttachment> attachments = []; // OCR attachments
}
```

## 🎨 UI Components

### LUMARA FAB
- Idle pulse animation every 6-8 seconds
- Nudge animation when user types ≥30 characters
- Respects "Reduce Motion" accessibility setting

### Suggestion Sheet
- 5 reflection options with icons
- Clean bottom sheet design
- Drag handle for dismissal

### Inline Reflection Block
- Styled with left border and subtle background
- Phase indicator badge
- 4 action buttons for interaction
- Responsive to theme (light/dark mode)

## 🔌 Services

### LUMARA Inline API
```dart
final api = LumaraInlineApi(analytics);

// Generate reflection
final reflection = await api.generatePromptedReflection(
  entryText: userText,
  intent: 'ideas',
  phase: 'Discovery',
);

// Softer tone
final gentle = await api.generateSofterReflection(
  entryText: userText,
  intent: 'think',
  phase: 'Recovery',
);
```

### OCR Service
```dart
final ocr = StubOcrService(analytics); // Use platform-specific implementation

// Extract text from image
final text = await ocr.extractText(imageFile);
```

### PII Scrubbing
```dart
// Scrub sensitive data
final clean = PiiScrubber.rivetScrub(userText);

// Check for PII
final hasPii = PiiScrubber.containsPii(userText);
```

## 📊 Analytics

Track user interactions:

```dart
// Journal events
analytics.logJournalEvent('opened');
analytics.logJournalEvent('continue_pressed', data: {
  'text_length': 150,
  'reflection_count': 2,
});

// LUMARA events
analytics.logLumaraEvent('fab_tapped');
analytics.logLumaraEvent('suggestion_selected', data: {
  'intent': 'ideas',
});

// Scan events
analytics.logScanEvent('started');
analytics.logScanEvent('completed', data: {
  'text_length': 200,
});
```

## 🎯 Phase-Aware Responses

LUMARA adapts its tone based on the user's current phase:

- **Recovery**: Gentle, self-compassionate language
- **Discovery**: Curious, exploratory approach
- **Breakthrough**: Excited, possibility-focused
- **Consolidation**: Focused, synthesis-oriented

## 🔒 Privacy Implementation

All external API calls are protected:

1. **PII Scrubbing**: Names, emails, phones, addresses redacted
2. **Metadata Headers**: Origin, mode, PII status included
3. **Fallback Responses**: Safe defaults when uncertainty is high
4. **User Consent**: Opt-in required for external processing

## 🚀 Future Enhancements

- **Real AI Integration**: Replace stub responses with actual AI provider
- **Camera Integration**: Native camera scanning flow
- **Voice Input**: Speech-to-text for journaling
- **Export Options**: Share reflections and scanned content
- **Offline Mode**: Full functionality without internet

## 🧪 Testing

Use the demo screen to test functionality:

```dart
import 'package:my_app/ui/journal/journal_demo.dart';

// Show demo
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const JournalDemo(),
  ),
);
```

## 📱 Accessibility

- All icons have text labels for screen readers
- Minimum 44x44 tap targets
- Respects "Reduce Motion" OS setting
- Dark mode support
- High contrast compatibility

## 🔄 Migration from Old Journal

The new journal screen is designed to replace the existing journal flow while maintaining the sacred feel of writing. Key differences:

- **Inline LUMARA**: No separate chat screen by default
- **Scan Integration**: OCR built into the writing experience
- **Session Persistence**: Automatic progress saving
- **Phase Awareness**: Contextual responses based on life phase

This creates a more integrated, thoughtful journaling experience that keeps users focused on their writing while providing helpful AI companionship.

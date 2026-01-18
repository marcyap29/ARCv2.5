# Voice Mode Usage Guide

## Activation

Voice mode is activated via **long-press** on the + (QuickJournalEntry) floating action button.

- **Tap** = Open journal entry panel (existing behavior)
- **Long-press** = Launch voice mode

## Integration

### Step 1: Update Your QuickJournalEntryWidget Usage

To enable voice mode, pass the required services to `QuickJournalEntryWidget`:

```dart
import 'package:my_app/arc/ui/quick_journal_entry_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/arc/chat/services/enhanced_lumara_api.dart';
import 'package:my_app/arc/internal/echo/prism_adapter.dart';

// In your screen (e.g., HomeView, TimelineView)
@override
Widget build(BuildContext context) {
  final currentUser = FirebaseAuth.instance.currentUser;
  
  return Scaffold(
    body: YourContent(),
    
    // Floating action button
    floatingActionButton: QuickJournalEntryWidget(
      onNewEntryPressed: _handleNewEntry,
      
      // Add these for voice mode support:
      userId: currentUser?.uid,
      lumaraApi: EnhancedLumaraApi(/* your config */),
      prism: PrismAdapter(),
    ),
  );
}
```

### Step 2: Voice Mode Services (if not already available)

If you don't have these services initialized in your screen, here's how to set them up:

```dart
class _YourScreenState extends State<YourScreen> {
  late EnhancedLumaraApi _lumaraApi;
  late PrismAdapter _prismAdapter;
  
  @override
  void initState() {
    super.initState();
    _lumaraApi = EnhancedLumaraApi(
      // Your existing LUMARA API config
    );
    _prismAdapter = PrismAdapter();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: YourContent(),
      floatingActionButton: QuickJournalEntryWidget(
        onNewEntryPressed: _handleNewEntry,
        userId: FirebaseAuth.instance.currentUser?.uid,
        lumaraApi: _lumaraApi,
        prism: _prismAdapter,
      ),
    );
  }
}
```

## User Experience

### Discovery

Voice mode uses **direct interaction** - no tooltips or intermediate prompts:

- **Visual Hint**: Small mic icon (🎤) in bottom-right corner of + button
- **Long-Press**: Hold the button to immediately launch voice mode
- **No Tutorial**: The mic icon is the only visual cue

### Haptic Feedback

- **Light tap** - When long-press starts
- **Medium impact** - After 300ms (confirms "keep holding")
- **Medium impact** - On voice mode launch

### Visual Indicators

A small mic icon (🎤) appears in the bottom-right corner of the + button when:
- Voice services are configured
- Panel is closed
- Subtle hint that long-press activates voice mode

## Voice Mode Workflow

Once activated:

1. **Initializing** - Fetches Wispr API key from Cloud Functions
2. **Permission Check** - Requests microphone access
3. **Voice Screen** - Shows animated LUMARA sigil
4. **Listening** - User speaks naturally
5. **Smart Endpoint** - Detects when user finishes (phase-adaptive)
6. **Processing** - Transcripts scrubbed via PRISM
7. **LUMARA Response** - Spoken via TTS
8. **Continue** - User can keep conversing
9. **Finish** - Session saved to timeline

## Disabling Voice Mode

To disable voice mode (button will only show journal panel):

```dart
QuickJournalEntryWidget(
  onNewEntryPressed: _handleNewEntry,
  // Don't pass userId, lumaraApi, or prism
)
```

## Troubleshooting

### "Voice mode not configured"
- Make sure you've set the Wispr API key: `firebase functions:secrets:set WISPR_FLOW_API_KEY`
- Deploy the function: `firebase deploy --only functions:getWisprApiKey`

### No mic icon showing
- Verify `userId`, `lumaraApi`, and `prism` are all provided
- Check that services are not null

### Long-press not working
- Make sure you're holding for ~300ms
- iOS may have different long-press thresholds

## Requirements

- Firebase Functions secret `WISPR_FLOW_API_KEY` configured
- Cloud Function `getWisprApiKey` deployed
- Microphone permissions granted
- User authenticated (Firebase Auth)

## Dependencies

```yaml
dependencies:
  cloud_functions: ^4.5.0
  web_socket_channel: ^2.4.0
  record: ^5.0.0
  uuid: ^4.3.3
  flutter_tts: ^4.0.2
  shared_preferences: ^2.2.2
  firebase_core: ^3.11.0
  cloud_firestore: ^5.6.3
  firebase_auth: ^5.4.2
```

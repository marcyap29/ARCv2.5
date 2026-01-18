# Voice Mode Implementation TODOs

These are the remaining implementation tasks to make voice mode fully functional.

## Critical API Mismatches (Preventing Compilation)

### 1. VoiceSessionService Missing Properties
- [ ] Add `onSessionError` callback setter
- [ ] Expose `endpointDetector` (or remove direct access from UI)

### 2. TtsJournalClient Missing Callback Setters
- [ ] Add `onStart` setter
- [ ] Add `onComplete` setter  
- [ ] Add `onError` setter

Or use the existing callback pattern in the constructor.

### 3. VoiceSessionBuilder Missing Methods
- [ ] Add `_sessionId` getter (or use `sessionId`)
- [ ] Add `turns` getter to access conversation turns

### 4. EnhancedLumaraApi Missing sendMessage
- [ ] Implement `sendMessage()` method for voice conversations
- [ ] Or adapt voice code to use existing `geminiSend()` method

### 5. JournalRepository Method Signatures
- [ ] Fix `addEntry()` method signature
- [ ] Fix `getEntry()` method signature
- [ ] Fix `getAllEntries()` method signature
- [ ] Fix `updateEntry()` method signature
- [ ] Fix `deleteEntry()` method signature

## Next Steps
1. Comment out problematic code to get compilation
2. Implement missing APIs one by one
3. Test voice mode end-to-end

# On-Device LLM Testing Checklist

## Overview

Comprehensive testing checklist for verifying the on-device LLM implementation is fully functional with the security-first architecture.

---

## Pre-Testing Requirements

### Prerequisites ✓

- [ ] llama.cpp xcframework built successfully (`build-apple/llama.xcframework` exists)
- [ ] Framework linked to Xcode project (appears in "Frameworks, Libraries, and Embedded Content")
- [ ] llama.cpp function calls uncommented in QwenBridge.swift
- [ ] Qwen3-1.7B Q4_K_M model file downloaded (1.1GB)
- [ ] Model file placed in `~/Library/Application Support/Models/Qwen3-1.7B.Q4_K_M.gguf`
- [ ] App builds without Swift compiler errors
- [ ] Gemini API key configured (for fallback testing)

### Verify Model File

```bash
# Check model exists and has correct size
ls -lh ~/Library/Application\ Support/Models/Qwen3-1.7B.Q4_K_M.gguf

# Expected output:
# -rw-r--r--  1 mymac  staff   1.1G  Sep 30 12:00 Qwen3-1.7B.Q4_K_M.gguf

# If not there, create directory and move file:
mkdir -p ~/Library/Application\ Support/Models/
mv /path/to/Qwen3-1.7B.Q4_K_M.gguf ~/Library/Application\ Support/Models/
```

---

## Phase 1: Build Verification

### 1.1 Clean Build ✓

```bash
cd "/Users/mymac/Software Development/EPI/ARC MVP/EPI"
flutter clean
rm -rf ios/Pods
cd ios && pod install && cd ..
flutter pub get
```

**Expected**: All commands succeed without errors

- [ ] flutter clean completed
- [ ] Pods installed
- [ ] Dependencies resolved

### 1.2 iOS Build ✓

```bash
flutter build ios --no-codesign
```

**Expected**:
```
Building for iOS...
Xcode build done.
✓ Built build/ios/iphoneos/Runner.app
```

**Verify NO Errors**:
- [ ] No "Cannot find 'llama_init' in scope"
- [ ] No "Cannot find 'llama_generate' in scope"
- [ ] No "Cannot find 'llama_is_loaded' in scope"
- [ ] No "Cannot find 'llama_cleanup' in scope"
- [ ] No "Undefined symbol: _llama_*"
- [ ] No framework linking errors

### 1.3 Simulator Launch ✓

```bash
flutter run -d "iPhone 16 Pro"
```

**Expected**:
```
Launching lib/main.dart on iPhone 16 Pro...
Running Xcode build...
✓ Built build/ios/iphonesimulator/Runner.app
Syncing files to device iPhone 16 Pro...
Flutter run key commands.
```

**Verify**:
- [ ] App launches without crashes
- [ ] No dyld library loading errors
- [ ] Main screen displays correctly

---

## Phase 2: Native Bridge Registration

### 2.1 QwenBridge Registration ✓

**Action**: Launch app and check console logs

**Expected Logs**:
```
[AppDelegate] QwenBridge.register() via registrar ✅
[QwenBridge] register() called ✅
```

**Verify**:
- [ ] Registration log appears
- [ ] No "ERROR: registrar(forPlugin:) returned nil"
- [ ] Method channel established

### 2.2 Ping Test ✓

**Expected Logs**:
```
[LumaraAssistantCubit] invoking QwenAdapter.initialize(...)
[LumaraNative] ping -> pong
```

**Verify**:
- [ ] Ping succeeds
- [ ] Dart-Swift communication working
- [ ] No timeout errors

### 2.3 Self Test ✓

**Expected Logs**:
```
[LumaraNative] selfTest -> {
  registered: true,
  metalAvailable: true,
  modelLoaded: false,
  version: "1.0.0"
}
```

**Verify**:
- [ ] `registered: true`
- [ ] `metalAvailable: true` (on real device) or `false` (simulator)
- [ ] No errors in selfTest
- [ ] All diagnostics return valid data

---

## Phase 3: Model Loading

### 3.1 Model Initialization ✓

**Action**: App startup automatically calls `QwenAdapter.initialize()`

**Expected Logs**:
```
[LumaraAssistantCubit] invoking QwenAdapter.initialize(...)
[QwenAdapter] Starting initialization...
[LumaraNative] initModel("/Users/mymac/Library/Application Support/Models/Qwen3-1.7B.Q4_K_M.gguf")
[QwenBridge] Attempting to load model from: .../Qwen3-1.7B.Q4_K_M.gguf
[QwenBridge] Model loaded successfully
[LumaraNative] initModel -> { ok: true }
[QwenAdapter] initModel -> true
[QwenAdapter] Initialization complete: isAvailable=true, reason=ok
```

**Verify**:
- [ ] Model path is correct
- [ ] llama_init() returns 1 (success)
- [ ] No "file_not_found" error
- [ ] No "invalid_format" error
- [ ] No memory allocation errors
- [ ] `isAvailable=true`
- [ ] `reason=ok`

### 3.2 Model Ready Check ✓

**Action**: After initialization, run selfTest again

**Expected Logs**:
```
[LumaraNative] selfTest -> {
  registered: true,
  metalAvailable: true,
  modelReady: true,
  modelLoaded: true
}
```

**Verify**:
- [ ] `modelReady: true`
- [ ] `modelLoaded: true`
- [ ] llama_is_loaded() returns 1

### 3.3 Model Loading Failure Tests ✓

**Test A: Missing Model File**

**Setup**: Temporarily rename model file
```bash
mv ~/Library/Application\ Support/Models/Qwen3-1.7B.Q4_K_M.gguf ~/Library/Application\ Support/Models/Qwen3-1.7B.Q4_K_M.gguf.backup
```

**Expected Logs**:
```
[LumaraNative] initModel -> { ok: false, error: "file_not_found" }
[QwenAdapter] initModel -> false
[QwenAdapter] isAvailable: false, reason: init_failed
```

**Verify**:
- [ ] Graceful error handling
- [ ] No app crash
- [ ] Clear error message
- [ ] Falls back to cloud API

**Cleanup**: Restore model file
```bash
mv ~/Library/Application\ Support/Models/Qwen3-1.7B.Q4_K_M.gguf.backup ~/Library/Application\ Support/Models/Qwen3-1.7B.Q4_K_M.gguf
```

---

## Phase 4: Provider Status & Security-First Architecture

### 4.1 Provider Status Summary ✓

**Action**: Open LUMARA chat and send any message

**Expected Logs**:
```
LUMARA Debug: Provider Status Summary:
LUMARA Debug:   - On-Device (Qwen): AVAILABLE ✓
LUMARA Debug:   - Cloud API (Gemini): AVAILABLE ✓
LUMARA Debug: Security-first fallback chain: On-Device → Cloud API → Rule-Based
```

**Verify**:
- [ ] Both providers shown
- [ ] On-Device status correct
- [ ] Cloud API status correct
- [ ] Fallback chain displayed

### 4.2 Priority 1: On-Device Processing ✓

**Action**: Send simple message "hello" in LUMARA chat

**Expected Logs**:
```
LUMARA Debug: [Priority 1] Attempting on-device QwenAdapter...
LUMARA Debug: [On-Device] QwenAdapter available! Using on-device processing.
[LumaraNative] generate() called with context
[QwenBridge] Generating response for prompt (length: 234)
[QwenBridge] Generation complete, length: 142
LUMARA Debug: [On-Device] SUCCESS - Response length: 142
LUMARA Debug: [On-Device] On-device processing complete - skipping cloud API
```

**Verify**:
- [ ] On-device attempted FIRST
- [ ] Generation succeeds
- [ ] Response generated (non-empty)
- [ ] Cloud API is NOT called
- [ ] Early return works (skips Priority 2)
- [ ] Response appears in chat UI
- [ ] Response makes sense contextually

### 4.3 Privacy Verification ✓

**Verify NO Cloud API Calls When On-Device Succeeds**:

**Should NOT See**:
- [ ] ❌ "[Cloud API] Using streaming"
- [ ] ❌ "[Priority 2] Falling back to Cloud API"
- [ ] ❌ Any Gemini API requests in network traffic
- [ ] ❌ Any HTTP requests to googleapis.com

**This is CRITICAL**: When on-device succeeds, user data NEVER leaves the device.

---

## Phase 5: Fallback Chain Testing

### 5.1 Fallback to Cloud API ✓

**Test**: Temporarily disable on-device model

**Setup**: Comment out model initialization in QwenAdapter or remove model file temporarily

**Action**: Send message in LUMARA

**Expected Logs**:
```
Provider Status Summary:
  - On-Device (Qwen): Not Available (init_failed)
  - Cloud API (Gemini): AVAILABLE ✓
[Priority 1] Attempting on-device QwenAdapter...
[On-Device] QwenAdapter not available, reason: init_failed
[Priority 2] Falling back to Cloud API...
[Cloud API] Using streaming (Gemini API available)
[Cloud API] SUCCESS - Response length: 347
```

**Verify**:
- [ ] On-device attempted first
- [ ] Failure detected gracefully
- [ ] Falls back to Priority 2 (Cloud API)
- [ ] Cloud API response succeeds
- [ ] Response appears in chat

### 5.2 Fallback to Rule-Based ✓

**Test**: Disable both on-device and cloud API

**Setup**:
- Disable model (remove file)
- Unset GEMINI_API_KEY environment variable

**Action**: Send message in LUMARA

**Expected Logs**:
```
Provider Status Summary:
  - On-Device (Qwen): Not Available (init_failed)
  - Cloud API (Gemini): Not Available (no API key)
[Priority 1] Attempting on-device QwenAdapter...
[On-Device] Failed: init_failed
[Priority 2] Falling back to Cloud API...
[Cloud API] No API key - using non-streaming approach
[Priority 3] Falling back to rule-based...
[Rule-Based] Using fallback adapter...
```

**Verify**:
- [ ] All three priorities attempted
- [ ] Clear logging of each failure
- [ ] Rule-based generates response
- [ ] No app crash
- [ ] User gets some response (even if basic)

### 5.3 Complete Fallback Chain ✓

**Verify**: Full chain works: On-Device → Cloud API → Rule-Based → Error Message

---

## Phase 6: Response Quality Testing

### 6.1 Chat Task ✓

**Test Messages**:

**Message 1**: "hello"
- [ ] On-device generates response
- [ ] Response is coherent
- [ ] Response matches LUMARA's tone
- [ ] Response length reasonable (~50-200 words)

**Message 2**: "how are you?"
- [ ] Contextual response
- [ ] Maintains conversation context
- [ ] No repetition

**Message 3**: "I'm feeling anxious today"
- [ ] Empathetic response
- [ ] Appropriate tone
- [ ] Offers support/reflection

### 6.2 SAGE Echo Task ✓

**Setup**: Open journal entry and ask for SAGE reflection

**Expected**: On-device generates SAGE-style response with emotional context

**Verify**:
- [ ] Response follows SAGE format
- [ ] Emotional intelligence present
- [ ] Reflective tone maintained
- [ ] Relevant to journal entry

### 6.3 Arcform Keywords Task ✓

**Setup**: Request keyword extraction from journal entry

**Expected**: On-device generates relevant keywords

**Verify**:
- [ ] Keywords extracted correctly
- [ ] Format matches expected output
- [ ] Relevant to entry content

### 6.4 Phase Hints Task ✓

**Setup**: Request ATLAS phase detection

**Expected**: On-device provides phase analysis

**Verify**:
- [ ] Phase detected reasonably
- [ ] Hints provided
- [ ] Format correct

### 6.5 Response Time ✓

**Measure**: Time from message send to response complete

**Expected**:
- On-Device (Simulator): 5-15 seconds
- On-Device (Device with Metal): 2-8 seconds
- Cloud API: 1-3 seconds (for comparison)

**Verify**:
- [ ] Response time acceptable for on-device
- [ ] Metal acceleration improves performance (test on real device)
- [ ] No timeouts

---

## Phase 7: Edge Cases & Error Handling

### 7.1 Very Long Prompts ✓

**Test**: Send very long message (500+ words)

**Verify**:
- [ ] On-device handles long input
- [ ] No crash or hang
- [ ] Response generated or graceful error
- [ ] Falls back if input too long

### 7.2 Special Characters ✓

**Test**: Message with emojis, newlines, special chars: "Hello 👋\nHow are you?\nI'm 100% fine! 😊"

**Verify**:
- [ ] Characters handled correctly
- [ ] No encoding issues
- [ ] Response generated

### 7.3 Empty/Invalid Input ✓

**Test**: Send empty message

**Verify**:
- [ ] Graceful handling
- [ ] No crash
- [ ] Appropriate error or simple response

### 7.4 Rapid Messages ✓

**Test**: Send 5 messages quickly in succession

**Verify**:
- [ ] All messages processed
- [ ] No race conditions
- [ ] Responses appear in order
- [ ] No crashes or hangs

### 7.5 Memory Management ✓

**Test**: Send 20-30 messages over time

**Verify**:
- [ ] Memory usage stable
- [ ] No memory leaks
- [ ] App remains responsive
- [ ] Model stays loaded

---

## Phase 8: Real Device Testing (Metal Acceleration)

### 8.1 Deploy to Real Device ✓

```bash
# Build for real device
flutter build ios --release

# Or run directly
flutter run -d "Your iPhone Name"
```

**Verify**:
- [ ] App installs on real device
- [ ] Signing/provisioning works
- [ ] App launches without crash

### 8.2 Metal Acceleration ✓

**Expected Logs**:
```
[LumaraNative] selfTest -> {
  metalAvailable: true,
  ...
}
[QwenBridge] Metal GPU available: true
```

**Verify**:
- [ ] Metal available on real device
- [ ] Performance improved vs simulator
- [ ] Response time faster (2-8 seconds vs 5-15)

### 8.3 Performance Comparison ✓

**Measure response times**:
- Simulator (no Metal): ____ seconds
- Real Device (with Metal): ____ seconds
- Cloud API (baseline): ____ seconds

**Verify**:
- [ ] Real device significantly faster than simulator
- [ ] Acceptable performance for user experience

---

## Phase 9: Attribution System Integration

### 9.1 Attribution with On-Device ✓

**Test**: Send message that should trigger memory retrieval

**Verify**:
- [ ] On-device processing works
- [ ] Attribution traces still created (if applicable)
- [ ] Attribution UI displays correctly
- [ ] Memory integration works

### 9.2 Attribution with Fallback ✓

**Test**: Disable on-device, verify cloud API attribution still works

**Verify**:
- [ ] Cloud API provides attributions
- [ ] Attribution UI displays
- [ ] Fallback doesn't break attribution system

---

## Phase 10: User Experience Verification

### 10.1 UI Responsiveness ✓

**Verify**:
- [ ] UI remains responsive during generation
- [ ] Loading indicator shows (if applicable)
- [ ] User can scroll/interact while waiting
- [ ] No UI freezes

### 10.2 Error Messages ✓

**Verify**:
- [ ] User-friendly error messages
- [ ] No technical jargon in user-facing errors
- [ ] Clear guidance on what went wrong
- [ ] Graceful degradation messaging

### 10.3 Privacy Communication ✓

**Verify**:
- [ ] User knows when on-device is used
- [ ] User knows when falling back to cloud
- [ ] Privacy benefits communicated
- [ ] Settings/info available about providers

---

## Phase 11: Cleanup & Disposal

### 11.1 Model Cleanup on App Termination ✓

**Test**: Close app completely (force quit)

**Expected Logs** (before termination):
```
[QwenBridge] dispose() called
[QwenBridge] Cleaning up llama.cpp resources
[QwenBridge] Disposed resources
```

**Verify**:
- [ ] llama_cleanup() called
- [ ] Resources freed
- [ ] No memory leaks
- [ ] Clean termination

### 11.2 Model Cleanup on Adapter Disposal ✓

**Test**: If QwenAdapter can be disposed/reinitialized

**Verify**:
- [ ] Proper cleanup
- [ ] Can reinitialize after disposal
- [ ] No dangling pointers

---

## Phase 12: Final Production Readiness

### 12.1 All Tests Pass ✓

- [ ] All Phase 1-11 tests passed
- [ ] No outstanding errors
- [ ] No crashes or hangs
- [ ] Performance acceptable

### 12.2 Documentation Complete ✓

- [ ] Bug_Tracker.md updated
- [ ] CHANGELOG.md updated
- [ ] ON_DEVICE_IMPLEMENTATION_SOLUTION.md complete
- [ ] LLAMA_CPP_LINKING_INSTRUCTIONS.md complete
- [ ] UNCOMMENT_LLAMA_INSTRUCTIONS.md complete
- [ ] This testing checklist used

### 12.3 Production Deployment ✓

- [ ] Code reviewed
- [ ] All stubs removed (actual llama.cpp calls active)
- [ ] Model file location confirmed
- [ ] Privacy policy updated (if needed)
- [ ] Release notes prepared

---

## Test Results Summary

### Date: _____________

### Tester: _____________

### Build Version: _____________

### Test Results:

| Phase | Tests | Passed | Failed | Notes |
|-------|-------|--------|--------|-------|
| 1. Build Verification | 3 | ___ | ___ | |
| 2. Native Bridge | 3 | ___ | ___ | |
| 3. Model Loading | 3 | ___ | ___ | |
| 4. Provider Status | 3 | ___ | ___ | |
| 5. Fallback Chain | 3 | ___ | ___ | |
| 6. Response Quality | 5 | ___ | ___ | |
| 7. Edge Cases | 5 | ___ | ___ | |
| 8. Real Device | 3 | ___ | ___ | |
| 9. Attribution | 2 | ___ | ___ | |
| 10. User Experience | 3 | ___ | ___ | |
| 11. Cleanup | 2 | ___ | ___ | |
| 12. Production Ready | 3 | ___ | ___ | |

### Overall Status: ⬜ PASS ⬜ FAIL ⬜ NEEDS WORK

### Critical Issues Found:

1.
2.
3.

### Performance Metrics:

- **On-Device Response Time (Simulator)**: ___ seconds
- **On-Device Response Time (Real Device)**: ___ seconds
- **Cloud API Response Time (Baseline)**: ___ seconds
- **Model Loading Time**: ___ seconds
- **Memory Usage**: ___ MB

### Sign-Off:

**Security-First Architecture Verified**: ⬜ YES ⬜ NO

**Privacy Protection Confirmed**: ⬜ YES ⬜ NO

**Production Ready**: ⬜ YES ⬜ NO

---

## Quick Test Commands

```bash
# Full clean and rebuild
cd "/Users/mymac/Software Development/EPI/ARC MVP/EPI"
flutter clean && cd ios && pod install && cd .. && flutter run -d "iPhone 16 Pro"

# Check build output
flutter build ios --no-codesign 2>&1 | grep -i "error\|warning\|llama"

# Monitor logs for LUMARA/On-Device
flutter run -d "iPhone 16 Pro" 2>&1 | grep -E "(LUMARA|On-Device|QwenBridge|Priority)"

# Check model file
ls -lh ~/Library/Application\ Support/Models/*.gguf

# Verify xcframework
ls -la third_party/llama.cpp/build-apple/llama.xcframework/
```

---

**Remember**: The goal is to verify that on-device LLM provides maximum privacy protection by processing user data locally whenever possible, with transparent fallback to cloud only when necessary.

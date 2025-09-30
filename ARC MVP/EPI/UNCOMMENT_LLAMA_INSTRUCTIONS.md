# Uncommenting llama.cpp Function Calls in QwenBridge.swift

## Overview

After successfully linking the llama.cpp xcframework to your Xcode project, you need to uncomment the actual function calls that were temporarily stubbed out to allow compilation.

---

## Prerequisites

**Before uncommenting**:
1. ✅ llama.cpp xcframework built successfully
2. ✅ Framework linked to Xcode project (see `LLAMA_CPP_LINKING_INSTRUCTIONS.md`)
3. ✅ Project builds without "Cannot find 'llama_*'" errors

**Verify Framework Linked**:
```bash
# Build should succeed
cd "/Users/mymac/Software Development/EPI/ARC MVP/EPI"
flutter build ios --no-codesign

# Should see: ✓ Built build/ios/iphoneos/Runner.app
```

---

## File to Edit

**File**: `ios/Runner/QwenBridge.swift`

**Locations**: 4 places need to be uncommented (lines ~147, ~185, ~487, ~556)

---

## Location 1: initModel Method (Line ~147-150)

### Find This Section:

```swift
// Inside the initModel method
do {
    // Attempt to load the model via llama.cpp
    // let success = llama_init(modelPath)
    let success = 0  // Stub: llama.cpp not yet built
    print("QwenBridge: [STUB] llama.cpp framework not yet integrated")

    if success == 1 {
        self.chatModelLoaded = true
        print("QwenBridge: Model loaded successfully")
```

### Change To:

```swift
// Inside the initModel method
do {
    // Attempt to load the model via llama.cpp
    let success = llama_init(modelPath)
    // let success = 0  // Stub: llama.cpp not yet built
    // print("QwenBridge: [STUB] llama.cpp framework not yet integrated")

    if success == 1 {
        self.chatModelLoaded = true
        print("QwenBridge: Model loaded successfully")
```

**Changes**:
- Uncomment: `let success = llama_init(modelPath)`
- Comment out: `let success = 0` and the stub print statement

---

## Location 2: generate Method (Line ~185-187)

### Find This Section:

```swift
// Inside the generate method
do {
    // Call llama.cpp to generate response
    // let response = llama_generate(prompt, self.temperature, self.topP, Int32(self.maxTokens))
    let response: UnsafePointer<CChar>? = nil  // Stub: llama.cpp not yet built

    if let response = response {
        let responseString = String(cString: response)
```

### Change To:

```swift
// Inside the generate method
do {
    // Call llama.cpp to generate response
    let response = llama_generate(prompt, self.temperature, self.topP, Int32(self.maxTokens))
    // let response: UnsafePointer<CChar>? = nil  // Stub: llama.cpp not yet built

    if let response = response {
        let responseString = String(cString: response)
```

**Changes**:
- Uncomment: `let response = llama_generate(...)`
- Comment out: `let response: UnsafePointer<CChar>? = nil`

---

## Location 3: selfTest Method (Line ~487-489)

### Find This Section:

```swift
// Inside the selfTest method
// Check if model is loaded
var ready = false
// ready = chatModelLoaded && (llama_is_loaded() == 1)
ready = chatModelLoaded  // Stub: llama.cpp not yet built

result["modelReady"] = ready
```

### Change To:

```swift
// Inside the selfTest method
// Check if model is loaded
var ready = false
ready = chatModelLoaded && (llama_is_loaded() == 1)
// ready = chatModelLoaded  // Stub: llama.cpp not yet built

result["modelReady"] = ready
```

**Changes**:
- Uncomment: `ready = chatModelLoaded && (llama_is_loaded() == 1)`
- Comment out: `ready = chatModelLoaded`

---

## Location 4: cleanup/dispose Method (Line ~556-558)

### Find This Section:

```swift
// Inside the dispose or cleanup method
// Clean up llama.cpp resources
// llama_cleanup()
print("QwenBridge: [STUB] Skipping llama_cleanup (llama.cpp not integrated)")

self.chatModelLoaded = false
print("QwenBridge: Disposed resources")
```

### Change To:

```swift
// Inside the dispose or cleanup method
// Clean up llama.cpp resources
llama_cleanup()
// print("QwenBridge: [STUB] Skipping llama_cleanup (llama.cpp not integrated)")

self.chatModelLoaded = false
print("QwenBridge: Disposed resources")
```

**Changes**:
- Uncomment: `llama_cleanup()`
- Comment out: stub print statement

---

## Quick Edit Commands

If you prefer to use sed or manual find/replace:

### Using Text Editor

**Find**: `// let success = llama_init(modelPath)`
**Replace**: `let success = llama_init(modelPath)`

**Find**: `let success = 0  // Stub: llama.cpp not yet built`
**Replace**: `// let success = 0  // Stub: llama.cpp not yet built`

**Find**: `// let response = llama_generate(`
**Replace**: `let response = llama_generate(`

**Find**: `let response: UnsafePointer<CChar>? = nil  // Stub`
**Replace**: `// let response: UnsafePointer<CChar>? = nil  // Stub`

**Find**: `// ready = chatModelLoaded && (llama_is_loaded() == 1)`
**Replace**: `ready = chatModelLoaded && (llama_is_loaded() == 1)`

**Find**: `ready = chatModelLoaded  // Stub: llama.cpp not yet built`
**Replace**: `// ready = chatModelLoaded  // Stub: llama.cpp not yet built`

**Find**: `// llama_cleanup()`
**Replace**: `llama_cleanup()`

**Find**: `print("QwenBridge: [STUB] Skipping llama_cleanup`
**Replace**: `// print("QwenBridge: [STUB] Skipping llama_cleanup`

---

## Verification After Uncommenting

### 1. Build Test

```bash
cd "/Users/mymac/Software Development/EPI/ARC MVP/EPI"
flutter clean
cd ios && pod install && cd ..
flutter build ios --no-codesign
```

**Expected**: ✓ Build succeeds without errors

**Should NOT See**:
- ❌ "Cannot find 'llama_init' in scope"
- ❌ "Cannot find 'llama_generate' in scope"
- ❌ "Cannot find 'llama_is_loaded' in scope"
- ❌ "Cannot find 'llama_cleanup' in scope"

### 2. Code Review

Open `ios/Runner/QwenBridge.swift` and verify:

**Line ~147**: ✓ `let success = llama_init(modelPath)` is active
**Line ~185**: ✓ `let response = llama_generate(...)` is active
**Line ~487**: ✓ `ready = chatModelLoaded && (llama_is_loaded() == 1)` is active
**Line ~556**: ✓ `llama_cleanup()` is active

**All [STUB] print statements should be commented out**

---

## What These Functions Do

### llama_init(modelPath)

**Purpose**: Initialize llama.cpp and load the GGUF model file

**Returns**:
- `1` = success (model loaded)
- `0` = failure (file not found, invalid format, insufficient memory)

**When Called**: When QwenAdapter initializes, typically at app startup

**Log Output**:
```
[LumaraNative] initModel("/path/to/model.gguf") -> { ok: true }
[QwenAdapter] Model loaded successfully
```

### llama_generate(prompt, temp, topP, maxTokens)

**Purpose**: Generate text response from the loaded model

**Parameters**:
- `prompt`: String - the input text with system/user context
- `temperature`: Float - sampling temperature (0.7 default)
- `topP`: Float - nucleus sampling threshold (0.9 default)
- `maxTokens`: Int32 - maximum tokens to generate (512 default)

**Returns**:
- `UnsafePointer<CChar>` - C-style string with generated text
- `nil` - generation failed

**When Called**: Every time user sends a message to LUMARA and on-device is available

**Log Output**:
```
[LumaraNative] generate() called with context
[QwenBridge] Generation complete, length: 142
```

### llama_is_loaded()

**Purpose**: Check if model is currently loaded in memory

**Returns**:
- `1` = model loaded and ready
- `0` = model not loaded

**When Called**: In selfTest() to verify system status

**Log Output**:
```
[LumaraNative] selfTest -> { registered: true, modelReady: true, metalAvailable: true }
```

### llama_cleanup()

**Purpose**: Free memory and clean up llama.cpp resources

**Returns**: void

**When Called**: When app terminates or QwenAdapter is disposed

**Log Output**:
```
[QwenBridge] Cleaning up llama.cpp resources
[QwenBridge] Disposed resources
```

---

## Common Issues After Uncommenting

### Issue 1: Build Fails with "Undefined symbol: _llama_init"

**Cause**: Framework not properly linked

**Solution**:
1. Verify xcframework is in "Frameworks, Libraries, and Embedded Content"
2. Verify "Embed & Sign" is selected
3. Clean derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*`
4. Rebuild

### Issue 2: Runtime Crash "dyld: Symbol not found: _llama_generate"

**Cause**: Framework not embedded in app bundle

**Solution**:
1. In Xcode, select Runner target → General
2. Find llama.xcframework in frameworks list
3. Change from "Do Not Embed" to "Embed & Sign"
4. Clean and rebuild

### Issue 3: Model Loading Fails

**Symptom**: `llama_init()` returns 0

**Cause**: Model file not found or invalid

**Solution**:
1. Verify model file location:
   ```bash
   ls -lh ~/Library/Application\ Support/Models/Qwen3-1.7B.Q4_K_M.gguf
   ```
2. Check file size (should be ~1.1GB)
3. Check permissions: `chmod 644 ~/Library/Application\ Support/Models/*.gguf`
4. Check QwenBridge.swift uses correct model path

### Issue 4: Generation Returns nil

**Symptom**: `llama_generate()` returns nil pointer

**Causes**:
1. Model not loaded (init failed)
2. Invalid prompt format
3. Insufficient memory
4. Metal GPU issues

**Solution**:
1. Check logs for model loading errors
2. Verify model is loaded: `llama_is_loaded() == 1`
3. Try simpler prompt to test
4. Check available memory (model needs ~2GB)

---

## Testing After Uncommenting

### Phase 1: Build Verification

```bash
flutter clean
cd ios && pod install && cd ..
flutter build ios --no-codesign
```

✓ Build succeeds

### Phase 2: Model Loading Test

```bash
flutter run -d "iPhone 16 Pro"
```

**Check Logs**:
```
[AppDelegate] QwenBridge.register() via registrar ✅
[LumaraAssistantCubit] invoking QwenAdapter.initialize(...)
[LumaraNative] ping -> pong
[LumaraNative] selfTest -> { registered: true, metalAvailable: true, modelReady: false }
[LumaraNative] initModel(".../Qwen3-1.7B.Q4_K_M.gguf") -> { ok: true }
[QwenAdapter] Model loaded successfully
[QwenAdapter] isAvailable: true, reason: ok
```

✓ Model loads successfully

### Phase 3: Generation Test

**Action**: Send message "hello" in LUMARA chat

**Expected Logs**:
```
Provider Status Summary:
  - On-Device (Qwen): AVAILABLE ✓
  - Cloud API (Gemini): AVAILABLE ✓
[Priority 1] Attempting on-device QwenAdapter...
[On-Device] QwenAdapter available! Using on-device processing.
[LumaraNative] generate() called with context
[QwenBridge] Generation complete, length: 142
[On-Device] SUCCESS - Response length: 142
[On-Device] On-device processing complete - skipping cloud API
```

✓ On-device generation works

### Phase 4: Privacy Verification

**Verify**: Cloud API is NOT called when on-device succeeds

**Expected**: No log lines mentioning Gemini API or cloud processing after on-device success

✓ Privacy-first architecture working

---

## Rollback Instructions

If you need to revert to stub implementation:

### Re-comment the Functions

Change back to stub implementations:

**Line ~147**:
```swift
// let success = llama_init(modelPath)
let success = 0  // Stub: llama.cpp not yet built
```

**Line ~185**:
```swift
// let response = llama_generate(...)
let response: UnsafePointer<CChar>? = nil  // Stub
```

**Line ~487**:
```swift
// ready = chatModelLoaded && (llama_is_loaded() == 1)
ready = chatModelLoaded  // Stub
```

**Line ~556**:
```swift
// llama_cleanup()
print("QwenBridge: [STUB] Skipping llama_cleanup")
```

This allows the app to compile and run, falling back to cloud API.

---

## Reference Files

- **Linking Guide**: `LLAMA_CPP_LINKING_INSTRUCTIONS.md`
- **Testing Checklist**: `ON_DEVICE_TESTING_CHECKLIST.md`
- **Build Script**: `third_party/llama.cpp/build-xcframework.sh`
- **Swift Bridge**: `ios/Runner/QwenBridge.swift`
- **Solution Doc**: `ON_DEVICE_IMPLEMENTATION_SOLUTION.md`

---

## Next Steps

After uncommenting and verifying:

1. ✅ Test on iOS simulator
2. ✅ Test on real iOS device (for Metal acceleration)
3. ✅ Measure response time and quality
4. ✅ Tune sampling parameters (temperature, top_p)
5. ✅ Test all LUMARA task types (chat, SAGE, Arcform, Phase)
6. ✅ Document performance metrics

**Congratulations! Once these functions are uncommented and working, your on-device LLM system is fully operational with maximum privacy protection.**

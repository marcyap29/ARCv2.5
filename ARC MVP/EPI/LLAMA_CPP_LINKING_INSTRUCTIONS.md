# llama.cpp XCFramework Linking Instructions

## Overview

After the llama.cpp xcframework build completes, you need to link it to your Xcode project so QwenBridge.swift can access the native functions.

---

## Prerequisites

**Status Check**:
```bash
# Verify xcframework was built successfully
ls -la "third_party/llama.cpp/build-apple/llama.xcframework"

# Should show:
# llama.xcframework/
#   ├── Info.plist
#   ├── ios-arm64/
#   ├── ios-arm64_x86_64-simulator/
#   ├── macos-arm64_x86_64/
#   └── ... (other platforms)
```

---

## Method 1: Xcode GUI (Recommended)

### Step 1: Open Project

```bash
cd "/Users/mymac/Software Development/EPI/ARC MVP/EPI"
open ios/Runner.xcworkspace
```

**Important**: Open `.xcworkspace`, NOT `.xcodeproj` (to preserve CocoaPods integration)

### Step 2: Add Framework to Project

1. In Xcode's **Project Navigator** (left sidebar), select **Runner** project (blue icon at top)
2. Select **Runner** target (not the project)
3. Go to **General** tab
4. Scroll down to **Frameworks, Libraries, and Embedded Content** section
5. Click the **"+"** button

### Step 3: Add XCFramework

**Option A: Add Files Method (Recommended)**
1. In the popup, click **"Add Other..."** → **"Add Files..."**
2. Navigate to: `/Users/mymac/Software Development/EPI/ARC MVP/EPI/third_party/llama.cpp/build-apple/`
3. Select `llama.xcframework`
4. Click **"Open"**

**Option B: Drag and Drop Method**
1. In Finder, navigate to `third_party/llama.cpp/build-apple/`
2. Drag `llama.xcframework` into Xcode's "Frameworks, Libraries, and Embedded Content" section
3. Ensure "Copy items if needed" is **UNCHECKED** (we want to reference it in place)

### Step 4: Configure Embedding

After adding the framework, you should see it listed as:
```
llama.xcframework    Embed & Sign
```

**Verify Settings**:
- Framework Status: **Embed & Sign** (NOT "Do Not Embed")
- This ensures the framework is both linked and embedded in your app bundle

### Step 5: Verify Build Settings

1. With **Runner** target selected, go to **Build Settings** tab
2. Search for "Framework Search Paths"
3. Verify it includes (Xcode should add this automatically):
   ```
   $(inherited)
   $(PROJECT_DIR)/../third_party/llama.cpp/build-apple
   ```

4. Search for "Runpath Search Paths"
5. Verify it includes:
   ```
   $(inherited)
   @executable_path/Frameworks
   @loader_path/Frameworks
   ```

### Step 6: Clean and Build

1. Product → **Clean Build Folder** (⇧⌘K)
2. Product → **Build** (⌘B)
3. Watch for any linker errors

**Expected Result**: Build succeeds without "Cannot find 'llama_*'" errors

---

## Method 2: Manual project.pbxproj Edit (Advanced)

If you prefer to edit the Xcode project file directly:

### Step 1: Close Xcode

Make sure Xcode is completely closed before editing project files.

### Step 2: Backup Project File

```bash
cd "/Users/mymac/Software Development/EPI/ARC MVP/EPI"
cp ios/Runner.xcodeproj/project.pbxproj ios/Runner.xcodeproj/project.pbxproj.backup
```

### Step 3: Add Framework Reference

You would need to add:
1. PBXFileReference for llama.xcframework
2. PBXBuildFile entry
3. Add to PBXFrameworksBuildPhase
4. Update Framework Search Paths

**Note**: This is error-prone and not recommended. Use Method 1 instead.

---

## Verification Steps

### 1. Visual Verification in Xcode

**Project Navigator Check**:
- Expand **Runner** project
- Look under **Frameworks** folder
- Verify `llama.xcframework` appears (may be in red if path issues)

**General Tab Check**:
- Select Runner target → General
- Scroll to "Frameworks, Libraries, and Embedded Content"
- Verify `llama.xcframework` is listed with "Embed & Sign"

### 2. Build Verification

```bash
cd "/Users/mymac/Software Development/EPI/ARC MVP/EPI"
flutter clean
cd ios && pod install && cd ..
flutter build ios --no-codesign
```

**Expected Output**:
```
Building for iOS...
Xcode build...
✓ Built build/ios/iphoneos/Runner.app
```

**No Errors About**:
- ❌ "Cannot find 'llama_init' in scope"
- ❌ "Cannot find 'llama_generate' in scope"
- ❌ "Cannot find 'llama_is_loaded' in scope"
- ❌ "Cannot find 'llama_cleanup' in scope"
- ❌ "Undefined symbol: _llama_*"

### 3. Runtime Verification

After linking, you still need to uncomment the stub code in QwenBridge.swift (see next section).

---

## Common Issues and Solutions

### Issue 1: "Framework not found llama"

**Symptom**: Linker error about missing framework

**Solution**:
1. Check Framework Search Paths includes correct path
2. Verify xcframework exists at specified location
3. Try cleaning derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
   ```

### Issue 2: "dyld: Library not loaded"

**Symptom**: Runtime crash with library loading error

**Solution**:
1. Change embedding from "Do Not Embed" to "Embed & Sign"
2. Verify Runpath Search Paths includes `@executable_path/Frameworks`
3. Clean and rebuild

### Issue 3: Framework appears red/missing in Xcode

**Symptom**: llama.xcframework shows in red in Project Navigator

**Solution**:
1. Select the framework in Project Navigator
2. Open File Inspector (⌥⌘1)
3. Check "Location" shows correct path
4. If wrong, click folder icon and reselect xcframework

### Issue 4: "Undefined symbol: _llama_init" etc.

**Symptom**: Linker errors about undefined symbols

**Causes**:
1. Framework not properly linked
2. Wrong architecture (simulator vs device)
3. Framework search paths incorrect

**Solution**:
1. Verify framework is in "Frameworks, Libraries, and Embedded Content"
2. Verify "Embed & Sign" is selected
3. Clean derived data and rebuild
4. Check you're building for correct platform (simulator/device)

### Issue 5: Bitcode-related errors

**Symptom**: "Could not find or use auto-linked framework 'llama'"

**Solution**:
Bitcode is deprecated in Xcode 14+, but if you see this:
1. Build Settings → Search "bitcode"
2. Set "Enable Bitcode" to **NO**
3. Clean and rebuild

---

## After Linking: Next Steps

Once the framework is linked successfully:

### 1. Uncomment llama.cpp Function Calls

Edit `ios/Runner/QwenBridge.swift` and restore the actual function calls:

**Location 1 (line ~147-150)**:
```swift
// Change FROM:
let success = 0  // Stub: llama.cpp not yet built

// TO:
let success = llama_init(modelPath)
```

**Location 2 (line ~185-187)**:
```swift
// Change FROM:
let response: UnsafePointer<CChar>? = nil  // Stub

// TO:
let response = llama_generate(prompt, self.temperature, self.topP, Int32(self.maxTokens))
```

**Location 3 (line ~487-489)**:
```swift
// Change FROM:
ready = chatModelLoaded  // Stub

// TO:
ready = chatModelLoaded && (llama_is_loaded() == 1)
```

**Location 4 (line ~556-558)**:
```swift
// Change FROM:
print("QwenBridge: [STUB] Skipping llama_cleanup")

// TO:
llama_cleanup()
```

See `UNCOMMENT_LLAMA_INSTRUCTIONS.md` for detailed guidance.

### 2. Place Model File

Ensure Qwen3-1.7B Q4_K_M model is in correct location:

```bash
# Check if model exists
ls -lh ~/Library/Application\ Support/Models/Qwen3-1.7B.Q4_K_M.gguf

# If not, move it there
mkdir -p ~/Library/Application\ Support/Models/
mv /path/to/Qwen3-1.7B.Q4_K_M.gguf ~/Library/Application\ Support/Models/
```

### 3. Test End-to-End

1. Clean and rebuild app
2. Run on simulator or device
3. Open LUMARA chat
4. Send a message
5. Check logs for on-device processing:

```
Provider Status Summary:
  - On-Device (Qwen): AVAILABLE ✓
  - Cloud API (Gemini): AVAILABLE ✓
[Priority 1] Attempting on-device QwenAdapter...
[On-Device] QwenAdapter available! Using on-device processing.
[On-Device] SUCCESS - Response length: 142
```

---

## Troubleshooting Build After Linking

### Clean Build Process

If you encounter issues after linking:

```bash
# Full clean
cd "/Users/mymac/Software Development/EPI/ARC MVP/EPI"
flutter clean
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*

# Rebuild
cd ios && pod install && cd ..
flutter pub get
flutter build ios --no-codesign

# Or run on simulator
flutter run -d "iPhone 16 Pro"
```

### Check Framework Architecture

Verify xcframework includes correct architectures:

```bash
cd third_party/llama.cpp/build-apple

# Check iOS simulator slice
xcodebuild -xcframework llama.xcframework -show-build-settings | grep ARCHS

# List all slices
xcodebuild -xcframework llama.xcframework -show-slices
```

**Expected Output**:
```
ios-arm64 (device)
ios-arm64_x86_64-simulator (simulator)
macos-arm64_x86_64 (macOS)
...
```

---

## Reference Files

- **Build Script**: `third_party/llama.cpp/build-xcframework.sh`
- **Swift Bridge**: `ios/Runner/QwenBridge.swift`
- **Next Steps**: `UNCOMMENT_LLAMA_INSTRUCTIONS.md`
- **Testing Guide**: `ON_DEVICE_TESTING_CHECKLIST.md`
- **Solution Doc**: `ON_DEVICE_IMPLEMENTATION_SOLUTION.md`

---

## Questions?

If you encounter issues:

1. Check Xcode's **Issue Navigator** (⌘5) for specific errors
2. Review **Build Log** for linker/framework errors
3. Verify xcframework path is correct
4. Ensure you're using `.xcworkspace` not `.xcodeproj`
5. Try the clean build process above

**The linking step is critical - all llama.cpp native functions depend on this framework being properly linked to your app.**

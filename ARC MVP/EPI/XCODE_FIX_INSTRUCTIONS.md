# Xcode Project Fix: Add QwenBridge.swift to Build Target

## Problem
`QwenBridge.swift` exists in `ios/Runner/` but is **not included in the Xcode project**. This causes:
- Swift compiler error: "Cannot find 'QwenBridge' in scope"
- Native bridge registration fails
- On-device LLM unavailable

## Solution: Add File to Xcode Project (GUI Method - Recommended)

### Step 1: Open Project in Xcode
```bash
cd "/Users/mymac/Software Development/EPI/ARC MVP/EPI"
open ios/Runner.xcworkspace
```
**Important**: Open `.xcworkspace`, NOT `.xcodeproj` (to preserve CocoaPods)

### Step 2: Add QwenBridge.swift to Project

1. In Xcode's **Project Navigator** (left sidebar), right-click the **Runner** group (yellow folder icon)
2. Select **Add Files to "Runner"...**
3. Navigate to and select: `ios/Runner/QwenBridge.swift`
4. In the dialog that appears:
   - ✅ **"Add to targets: Runner"** - MUST be checked
   - ✅ **"Create groups"** (NOT "Create folder references")
   - ❌ **"Copy items if needed"** - Leave UNCHECKED (file already in project)
5. Click **Add**

### Step 3: Verify Target Membership

1. Select `QwenBridge.swift` in the Project Navigator
2. Open **File Inspector** (⌥⌘1 or View → Inspectors → File)
3. Under **Target Membership**, ensure **Runner** is **checked**

### Step 4: Verify Build Phases

1. Select **Runner** project (blue icon at top of navigator)
2. Select **Runner** target
3. Go to **Build Phases** tab
4. Expand **Compile Sources**
5. Verify `QwenBridge.swift` is listed
   - If missing: Click **+**, add it manually

### Step 5: Clean and Build

1. Product → **Clean Build Folder** (⇧⌘K)
2. Product → **Build** (⌘B)
3. Watch for Swift compiler errors - should now compile successfully

## Expected Result

After adding the file, you should see:
- ✅ No Swift compiler errors
- ✅ `QwenBridge.swift` visible in Runner group
- ✅ File listed in Compile Sources
- ✅ Target membership shows "Runner" checked

## Next Steps After Fix

Once QwenBridge compiles successfully:

### 1. Re-enable Registration in AppDelegate

Edit `ios/Runner/AppDelegate.swift` and uncomment lines 17-22:

```swift
// Before (commented out):
// if let registrar = self.registrar(forPlugin: "QwenBridge") {
//   QwenBridge.register(with: registrar)
//   NSLog("[AppDelegate] QwenBridge.register() via registrar ✅")
// } else {
//   NSLog("[AppDelegate] ERROR: registrar(forPlugin:) returned nil")
// }

// After (active):
if let registrar = self.registrar(forPlugin: "QwenBridge") {
  QwenBridge.register(with: registrar)
  NSLog("[AppDelegate] QwenBridge.register() via registrar ✅")
} else {
  NSLog("[AppDelegate] ERROR: registrar(forPlugin:) returned nil")
}
```

### 2. Rebuild and Test

```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter run -d "iPhone 16 Pro"
```

### 3. Verify Logs

Look for these log messages on app startup:

```
[AppDelegate] QwenBridge.register() via registrar ✅
[QwenBridge] register() called ✅
[LumaraAssistantCubit] invoking QwenAdapter.initialize(...)
[LumaraNative] ping -> pong
[LumaraNative] selfTest -> { registered: true, ... }
[LumaraNative] initModel(".../Qwen3-1.7B.Q4_K_M.gguf") -> { ok: true }
[QwenAdapter] initModel -> true
```

## Troubleshooting

### If file appears greyed out in Xcode:
- The file reference is broken
- Delete it from project (select → Delete → "Remove Reference")
- Re-add using steps above

### If file shows as blue folder (not yellow group):
- This is a "folder reference" (wrong)
- Delete and re-add as "Create groups" (step 2.4)

### If still getting "Cannot find 'QwenBridge' in scope":
1. Check **Swift Language Version** in Build Settings (should be Swift 5)
2. Check **Excluded Source File Names** - ensure QwenBridge.swift isn't excluded
3. Try **Product → Clean Build Folder** then rebuild

### If registration logs don't appear:
- Native bridge was added to build but registration code is still commented
- Uncomment the registration code in AppDelegate.swift
- Do a full rebuild (not just hot reload)

## Alternative: Command Line (if xcodeproj gem available)

If you have xcodeproj gem installed:

```bash
cd "/Users/mymac/Software Development/EPI/ARC MVP/EPI"
ruby add_qwen_to_xcode.rb
```

Then proceed to Step 5 (Clean and Build).

## Files to Download

You mentioned you have the `.gguf` file. Ensure it's in the correct location:

```bash
# Check if model file exists
ls -lh ~/Library/Application\ Support/Models/Qwen3-1.7B.Q4_K_M.gguf

# If not, move it there:
mkdir -p ~/Library/Application\ Support/Models/
mv /path/to/your/Qwen3-1.7B.Q4_K_M.gguf ~/Library/Application\ Support/Models/
```

## Success Criteria

✅ QwenBridge.swift compiles without errors
✅ Registration logs appear on app startup
✅ ping/selfTest methods succeed
✅ initModel succeeds and loads .gguf file
✅ QwenAdapter.isAvailable == true
✅ On-device LLM responses working in LUMARA

## Questions?

If you encounter any issues:
1. Check the exact Swift compiler error message
2. Verify the file is in the correct location
3. Ensure Target Membership is set correctly
4. Try the clean build process
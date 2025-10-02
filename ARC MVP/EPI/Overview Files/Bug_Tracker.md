# Bug Tracker - EPI ARC MVP

## Active Issues

### Model Registry Reporting Zero Models - October 2, 2025
**Status:** = **INVESTIGATING**
**Priority:** Medium
**Component:** MLX On-Device LLM

**Issue:**
Model registry returns 0 installed models despite bundled Qwen3-1.7B-MLX-4bit model in flutter_assets.

**Expected Behavior:**
- `availableModels()` should return 1 model from auto-created registry
- `createDefaultRegistry()` should create registry on first launch if missing
- Model should be detected from `flutter_assets/assets/models/MLX/Qwen3-1.7B-MLX-4bit/`

**Actual Behavior:**
```
[LLMAdapter] Found 0 installed models
```

**Root Cause Investigation:**
- Registry file may exist from previous implementation
- Bundle path resolution may need verification
- File existence checks may not find bundled assets

**Next Steps:**
1. Clear Application Support directory to trigger registry recreation
2. Verify bundle path resolution with logging
3. Add file existence verification in Swift code
4. Test with fresh app install

**Workaround:**
System gracefully falls back to Cloud API ’ Rule-Based responses.

---

## Recently Resolved

### SocketException from Localhost Health Checks - October 2, 2025  **RESOLVED**
**Resolution Date:** October 2, 2025
**Component:** Legacy Provider System

**Issue:**
SocketException errors when QwenProvider attempted health checks to localhost:65007 and localhost:65009.

**Root Cause:**
Legacy QwenProvider and LlamaProvider performing HTTP health checks to local servers that don't exist.

**Fix Applied:**
- **QwenProvider.isAvailable()**: Return `false` immediately, no HTTP requests
- **api_config.dart _checkInternalModelAvailability()**: Disabled localhost health checks
- Added deprecation comments directing to LLMAdapter for native inference

**Files Modified:**
- `lib/lumara/llm/providers/qwen_provider.dart`
- `lib/lumara/config/api_config.dart`

**Verification:**
No more SocketException errors in logs after changes deployed.

---

## Implementation Notes

### MLX On-Device LLM Integration - October 2, 2025
**Component:** Complete Async Model Loading System

**What Was Implemented:**
1. **Pigeon Progress API**
   - Added `@FlutterApi()` for native’Flutter callbacks
   - Type-safe communication eliminates runtime casting errors
   - Progress streaming with 6 milestone updates (0%, 10%, 30%, 60%, 90%, 100%)

2. **Swift Async Bundle Loading**
   - `ModelLifecycle.start()` with completion handlers
   - Background queue processing: `DispatchQueue(label: "com.epi.model.load")`
   - Memory-mapped I/O via `SafetensorsLoader.load()`
   - Bundle path resolution: `flutter_assets/assets/models/MLX/`

3. **AppDelegate Progress Wiring**
   - Created `LumaraNativeProgress` instance
   - Connected to `LLMBridge` via `setProgressApi()`

4. **Dart Progress Service**
   - `ModelProgressService` implements `LumaraNativeProgress`
   - `waitForCompletion()` with 2-minute timeout
   - StreamController broadcasts to Flutter UI

5. **Bootstrap Integration**
   - Registered `ModelProgressService` in app initialization
   - Completes native’Flutter callback chain

**Files Modified:**
- `tool/bridge.dart`
- `ios/Runner/LLMBridge.swift`
- `ios/Runner/AppDelegate.swift`
- `lib/lumara/llm/model_progress_service.dart`
- `lib/main/bootstrap.dart`
- `lib/lumara/llm/providers/qwen_provider.dart`
- `lib/lumara/config/api_config.dart`

**Build Status:**
 iOS app compiles successfully
 Bridge self-test passes
 No SocketException errors
ó Model registry needs troubleshooting

---

## Historical Issues (Resolved)

### FFmpeg iOS Simulator Compatibility - September 21, 2025  **RESOLVED**
Removed unused FFmpeg dependency that blocked simulator development.

### MCP Export Empty Files - September 21, 2025  **RESOLVED**
Fixed Hive box initialization race condition in JournalRepository.getAllJournalEntries().

### Import Path Inconsistencies - September 27, 2025  **RESOLVED**
Fixed 7,576+ compilation errors through systematic import path corrections.

---

**Last Updated:** October 2, 2025 by Claude Sonnet 4.5

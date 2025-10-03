# Bug Tracker - EPI ARC MVP

## Active Issues

### Bundle Path Resolution Issue - IN PROGRESS 🔍 **DEBUGGING** - October 2, 2025
**Status:** 🔍 **IN PROGRESS**
**Priority:** High
**Component:** MLX On-Device LLM

**Current Issue:**
Model files not found in bundle despite being properly located in assets directory.

**Error Message:**
```
[ModelProgress] qwen3-1.7b-mlx-4bit: 0% - failed: Model files not found in bundle for: qwen3-1.7b-mlx-4bit
```

**Progress Made:**
- ✅ Model files properly bundled in `assets/models/MLX/Qwen3-1.7B-MLX-4bit/`
- ✅ All required files present: config.json, tokenizer.json, model.safetensors (914MB)
- ✅ Swift compilation errors resolved
- ✅ Pigeon bridge setup fixed
- ✅ Duplicate ModelStore.swift removed
- ✅ Debug logging added to bundle path resolution
- ✅ macOS app running successfully

**Current Status:**
- App builds and runs successfully on macOS
- Model registry finds 1 installed model
- Bundle path resolution debugging in progress
- Multiple fallback paths implemented in Swift code

**Next Steps:**
1. Test bundle path resolution with debug logging
2. Fix bundle path based on actual Flutter asset structure
3. Verify model loading on device/simulator


System gracefully falls back to Cloud API � Rule-Based responses.

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
   - Added `@FlutterApi()` for native�Flutter callbacks
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
   - Completes native�Flutter callback chain

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
� Model registry needs troubleshooting

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

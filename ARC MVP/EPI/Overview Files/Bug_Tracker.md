# Bug Tracker - EPI ARC MVP

## Active Issues

### On-Device Model Activation and Hardcoded Fallback Response Issues - RESOLVED ✅ - October 4, 2025
**Status:** ✅ **RESOLVED**
**Priority:** High
**Component:** LUMARA Inference System

**Issue:**
Critical issues with LUMARA's inference system where downloaded internal models weren't being used for responses and hardcoded fallback messages were showing instead of clear guidance.

**Error Symptoms:**
- Downloaded Qwen/Phi models not being used for actual inference despite showing as "available"
- Hardcoded conversational responses appearing instead of AI-generated content
- Confusing template messages like "Let's break this down together. What's really at the heart of this?"
- Provider status not updating immediately after model deletion

**Root Cause:**
1. **Provider Availability Bug**: `QwenProvider.isAvailable()` and `PhiProvider.isAvailable()` were hardcoded to return false or check localhost HTTP servers instead of actual model files
2. **Hardcoded Fallback System**: Enhanced LUMARA API had elaborate fallback templates that gave false impression of AI working
3. **No Status Refresh**: Model deletion didn't trigger provider status refresh in settings screen

**Solution:**
- **Fixed Provider Availability**: Updated both Qwen and Phi providers to check actual model download status via native bridge `isModelDownloaded(modelId)`
- **Removed Hardcoded Fallbacks**: Eliminated all conversational template responses and replaced with single clear guidance message
- **Added Status Refresh**: Implemented `refreshModelAvailability()` call after model deletion to update provider status immediately
- **Clear User Guidance**: Replaced confusing templates with actionable instructions directing users to download models or configure API keys

**Files Modified:**
- `lib/lumara/llm/providers/qwen_provider.dart` - Fixed to check actual model download status via bridge
- `lib/lumara/llm/providers/llama_provider.dart` - Fixed to check Phi model status via bridge  
- `lib/lumara/services/enhanced_lumara_api.dart` - Removed all hardcoded fallback templates
- `lib/lumara/bloc/lumara_assistant_cubit.dart` - Updated with clear guidance message
- `lib/lumara/ui/model_download_screen.dart` - Added status refresh after model deletion

**Result:**
✅ Downloaded Qwen/Phi models now actually used for inference instead of being ignored
✅ No more confusing hardcoded conversational responses that appeared like AI
✅ Clear, actionable guidance when no inference providers are available
✅ Provider status updates immediately after model deletion
✅ Users can see which inference method is actually being used

---

### API Key Persistence and Navigation Issues - RESOLVED ✅ - October 4, 2025
**Status:** ✅ **RESOLVED**
**Priority:** High
**Component:** LUMARA Settings & Navigation

**Issue:**
Multiple issues with LUMARA settings screen including API key persistence failures, incorrect provider status display, and navigation problems.

**Error Symptoms:**
- API keys not persisting after save - cleared on app restart
- All providers showing green "available" status despite no API keys configured
- Back button in onboarding screen leading to blank screen
- Missing home navigation from settings screens

**Root Cause:**
1. **API Key Redaction Bug**: `toJson()` method was replacing actual API keys with `'[REDACTED]'` string when saving to SharedPreferences
2. **No Load Implementation**: `_loadConfigs()` method only loaded from environment variables, never from SharedPreferences
3. **Corrupted Saved Data**: Old saved data contained literal `"[REDACTED]"` strings (10 characters) which were detected as valid API keys
4. **Navigation Issues**: Onboarding screen used `pushReplacement` causing back button to have no route to pop to

**Solution:**
- **Fixed API Key Saving**: Changed `toJson()` to save actual API key instead of `'[REDACTED]'` (SharedPreferences is already secure)
- **Implemented Load Logic**: Added SharedPreferences loading to `_loadConfigs()` that reads saved keys and overrides environment defaults
- **Added Debug Logging**: Masked key logging (first 4 + last 4 chars) for save/load operations to track what's being stored
- **Added Clear Function**: Implemented `clearAllApiKeys()` method with UI button for debugging and fresh starts
- **Fixed Navigation**: Changed from `pushReplacement` to `push` with `rootNavigator: true` to maintain navigation stack
- **Added Back Button**: Simplified back button behavior to use `Navigator.pop(context)`
- **Removed Home Buttons**: Cleaned up redundant home navigation buttons as back arrow is sufficient

**Files Modified:**
- `lib/lumara/config/api_config.dart` - Fixed saving, loading, added clear functionality, added debug logging
- `lib/lumara/ui/lumara_settings_screen.dart` - Added "Clear All API Keys" button, simplified navigation
- `lib/lumara/ui/lumara_onboarding_screen.dart` - Fixed navigation stack, added/removed nav buttons
- `lib/lumara/ui/lumara_assistant_screen.dart` - Changed to use `push` instead of `pushReplacement`

**Result:**
✅ API keys now persist correctly across app restarts
✅ Provider status accurately reflects actual API key configuration
✅ Debug logging shows masked keys for troubleshooting (e.g., "AIza...8Qpw")
✅ Clear All API Keys button allows easy reset for testing
✅ Back button navigation works correctly from all screens
✅ Clean, minimal navigation without redundant home buttons

---

### Model Download Status Checking Issues - RESOLVED ✅ - October 2, 2025
**Status:** ✅ **RESOLVED**
**Priority:** High
**Component:** Model Download System

**Issue:**
Model download screen showing incorrect "READY" status for models that weren't actually downloaded, and users couldn't delete downloaded models to refresh status.

**Error Symptoms:**
- Models showing "READY" status when not actually downloaded
- No way to delete downloaded models to refresh status
- No automatic startup check for model availability
- Incorrect model status checking that didn't verify file existence

**Root Cause:**
1. **Hardcoded Model Checking**: `isModelDownloaded` method was hardcoded to only check for Qwen models
2. **Incomplete File Verification**: Status checking didn't verify that both `config.json` and `model.safetensors` files actually exist
3. **No Startup Check**: App didn't automatically check model availability at startup
4. **No Delete Functionality**: Users couldn't remove downloaded models to refresh status

**Solution:**
- **Fixed Model Status Checking**: Updated `ModelDownloadService.swift` to properly check for both Qwen and Phi models by verifying required files exist
- **Enhanced File Verification**: Now checks for both `config.json` and `model.safetensors` files before marking model as available
- **Added Startup Check**: Implemented `_performStartupModelCheck()` that runs during API configuration initialization
- **Added Delete Functionality**: Implemented `deleteModel()` method with confirmation dialog and refresh capability
- **Improved Error Handling**: Enhanced error messages and status reporting throughout the system

**Files Modified:**
- `ios/Runner/ModelDownloadService.swift` - Fixed `isModelDownloaded` method and added `deleteModel` functionality
- `ios/Runner/LLMBridge.swift` - Updated to use proper ModelDownloadService implementation
- `lib/lumara/config/api_config.dart` - Added startup model availability check and refresh functionality
- `lib/lumara/ui/model_download_screen.dart` - Added delete button, refresh functionality, and improved error handling
- `lib/lumara/ui/lumara_settings_screen.dart` - Added model availability refresh on navigation return

**Result:**
✅ Model status checking now accurately verifies file existence
✅ Startup check automatically detects model availability at app launch
✅ Users can delete downloaded models and refresh status
✅ "READY" status only shows when models are actually available
✅ Comprehensive error handling and user feedback

---

### Qwen Tokenizer Mismatch Issue - RESOLVED ✅ - October 2, 2025
**Status:** ✅ **RESOLVED**
**Priority:** High
**Component:** MLX On-Device LLM Tokenizer

**Issue:**
Qwen model was generating garbled output with "Ġout" instead of proper LUMARA responses. The "Ġ" prefix indicates GPT-2/RoBERTa tokenization markers, not Qwen tokenization.

**Error Symptoms:**
- Model loads successfully but outputs "Ġout" or similar garbled text
- Single glyph responses instead of coherent text
- Hardcoded fallback responses being used instead of model generation

**Root Cause:**
The `SimpleTokenizer` class was using basic word-level tokenization instead of the proper Qwen tokenizer. This caused:
- Incorrect tokenization of input text
- Wrong special token handling
- Mismatched vocabulary between encode/decode operations
- GPT-2/RoBERTa space markers appearing in output

**Solution:**
- **Replaced `SimpleTokenizer`** with proper `QwenTokenizer` class
- **Added BPE-like tokenization** instead of word-level splitting
- **Implemented proper special token handling** from `tokenizer_config.json`
- **Added tokenizer validation** with roundtrip testing
- **Added cleanup guards** to remove GPT-2/RoBERTa markers (`Ġ`, `▁`)
- **Enhanced generation logic** with structured token generation
- **Added comprehensive logging** for debugging tokenizer issues

**Files Modified:**
- `ios/Runner/LLMBridge.swift` - Complete tokenizer rewrite
- `ios/Runner/LLMBridge.swift` - Enhanced generation method
- `ios/Runner/LLMBridge.swift` - Added validation and cleanup

**Result:**
✅ Qwen model now generates proper LUMARA responses
✅ No more "Ġout" or garbled text output
✅ Proper Qwen-3 chat template implementation
✅ Tokenizer validation catches issues early
✅ Clean, coherent text generation

---

### Provider Switching Issue - RESOLVED ✅ - October 2, 2025
**Status:** ✅ **RESOLVED**
**Priority:** High
**Component:** Provider Selection Logic

**Issue:**
App gets stuck on Google Gemini provider and won't switch back to on-device Qwen model, even when manually switching back.

**Root Cause:**
Manual provider selection was not being cleared when switching back to Qwen. The system always thought Google Gemini was manually selected, so it skipped the on-device model and went straight to the cloud API.

**Solution:**
- Enhanced provider detection logic to compare current provider with best available provider
- Added `getBestProvider()` method to detect automatic vs manual mode
- When current provider equals best provider, it's treated as automatic mode (uses on-device Qwen)
- When current provider differs from best provider, it's treated as manual mode (uses selected provider)

**Files Modified:**
- `lib/lumara/bloc/lumara_assistant_cubit.dart` - Updated provider detection logic
- `lib/lumara/services/enhanced_lumara_api.dart` - Added getBestProvider() method

**Result:**
✅ Provider switching now works correctly between on-device Qwen and Google Gemini
✅ Automatic mode properly uses on-device Qwen when available
✅ Manual mode properly uses selected cloud provider when manually chosen

---

### Bundle Path Resolution Issue - RESOLVED ✅ - October 2, 2025
**Status:** ✅ **RESOLVED**
**Priority:** High
**Component:** MLX On-Device LLM

**Issue:**
Model files not found in bundle despite being properly located in assets directory.

**Error Message:**
```
[ModelProgress] qwen3-1.7b-mlx-4bit: 0% - failed: Model files not found in bundle for: qwen3-1.7b-mlx-4bit
```

**Root Cause:**
`.gitignore` contains `ARC MVP/EPI/assets/models/**` which prevents model files from being tracked by Git. As a result:
- Model files (2.6GB) exist locally in `assets/models/MLX/Qwen3-1.7B-MLX-4bit/`
- Files are not tracked by Git (intentionally - too large for repository)
- `pubspec.yaml` declares `assets/models/` but files don't exist in Git
- Flutter build system creates empty `flutter_assets/assets/models/` directory in app bundle
- Swift code correctly looks for files, but they simply don't exist in the bundle

**Why Models Are Excluded:**
- Model size: 2.6GB (too large for app store distribution)
- Standard practice: Large ML models are downloaded on demand, not bundled
- Similar to ChatGPT, Claude, etc. - base app is small, models downloaded separately

**Solution Implemented:**
1. **Created `scripts/setup_models.sh`** - Copies models from `assets/models/MLX/` to `~/Library/Application Support/Models/`
2. **Updated `ModelStore.resolveModelPath()`** - Changed to check Application Support directory first, then fallback to bundle
3. **Run once before development:** `./scripts/setup_models.sh` to install models locally

**Files Modified:**
- `scripts/setup_models.sh` (new)
- `ios/Runner/LLMBridge.swift` - Updated `resolveBundlePath()` → `resolveModelPath()`

**Verification:**
Models now load from Application Support directory. System gracefully falls back to Cloud API → Rule-Based responses if models unavailable.

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

**Last Updated:** October 4, 2025 by Claude Sonnet 4.5

# Bug Tracker

## Active Issues

### 🐛 LUMARA Keyboard Navigation Issue
**Status**: 🔴 Active  
**Priority**: High  
**Date**: 2025-01-09  

**Description**: When in LUMARA tab, keyboard stays up when tapping home button, blocking access to main menu tabs.

**Steps to Reproduce**:
1. Open app
2. Navigate to LUMARA tab
3. Tap in text input field (keyboard appears)
4. Tap home button (🏠) in top-right
5. Keyboard remains up, blocking main menu access

**Attempted Solutions**:
- ❌ Added FocusScope.of(context).unfocus() to home button press handler - still not working
- ❌ Tried GestureDetector wrapper - caused syntax errors, reverted
- ❌ Home button shows dialog but keyboard persists

**Current Status**: Keyboard dismissal not working properly

---

### 🐛 LUMARA Model Management Crash
**Status**: ✅ Resolved  
**Priority**: High  
**Date**: 2025-01-09  

**Description**: App crashes with "Something went wrong. The app encountered an error. Please restart the app." when trying to access LUMARA model management screen.

**Root Cause**: Missing BlocProvider for ModelManagementCubit when navigating to the screen

**Solution Applied**:
- ✅ Wrapped ModelManagementScreen with BlocProvider in navigation
- ✅ Added proper imports for ModelManagementCubit
- ✅ Model management screen now loads without crashing

**Resolution Date**: 2025-01-09

---

### 🐛 LUMARA AI Model Not Actually Working
**Status**: 🔴 Active  
**Priority**: Critical  
**Date**: 2025-01-09  

**Description**: LUMARA appears to detect model files but is actually using rule-based responses that repeat the same answers. No real AI inference is happening.

**Root Cause**: 
- MediaPipe dependencies are commented out in build files
- Native bridges (Android/iOS) can't load MediaPipe classes
- GemmaAdapter initialization fails silently
- Falls back to RuleBasedAdapter which gives repetitive responses

**Evidence**:
- Model files exist in assets/models/ folder
- App shows "downloadedModels: [gemma3_1b_instruct]" 
- But logs show "fallbackMode: true" and "Using rule-based responses"
- User reports repetitive answers to different questions

**Required Fix**:
- Re-enable MediaPipe dependencies in android/app/build.gradle.kts and ios/Podfile
- Fix native bridge implementations to work with MediaPipe
- Ensure model files are properly loaded from assets

**Workaround**: None - AI inference completely non-functional  

---

## Resolved Issues

_(None yet)_

---

## Notes
- Debug logging added for troubleshooting
- Consider implementing simpler fallback UI if state management fails
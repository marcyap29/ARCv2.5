# Wispr Flow Cache Issue

Date: 2026-01-31
Status: Resolved ✅
Area: Voice Transcription, Wispr Flow, Settings
Severity: Medium

## Summary
Wispr Flow API key was cached in `WisprConfigService`. After saving a new or updated API key in **LUMARA Settings → External Services**, voice mode could still use the previous cached key until the app was restarted. New key was not picked up on the next voice session without a restart.

## Impact
- **User Experience**: Admin users (Wispr Flow is admin-only) who updated their Wispr API key had to restart the app for voice transcription to use the new key.
- **Functionality**: `WisprConfigService.getApiKey()` and `isAvailable()` returned cached values; preferences were only read once and then cached.
- **Scope**: Wispr Flow backend only (voice transcription). Apple On-Device transcription unaffected.

## Root Cause
`WisprConfigService` caches the API key in memory (`_cachedApiKey`, `_hasCheckedPrefs`) for performance. When the user saved a new key in `lumara_settings_screen.dart`, preferences were updated but the service cache was not cleared, so the next call to `getApiKey()` or `isAvailable()` during transcription initialization returned the old cached value.

### Technical Details
- **File**: `lib/arc/chat/voice/config/wispr_config_service.dart`
- `getApiKey()` returns cached key if `_hasCheckedPrefs && _cachedApiKey != null`
- Settings screen writes to SharedPreferences (`wispr_flow_api_key`) but did not originally clear the WisprConfigService cache after save
- UnifiedTranscriptionService calls `_wisprConfigService.isAvailable()` and `getApiKey()` at startup; if cache was stale, old key was used

## Fix
Call `WisprConfigService.instance.clearCache()` after successfully saving the Wispr API key in LUMARA Settings, so the next voice session loads the new key from preferences.

### 1. `lib/arc/chat/ui/lumara_settings_screen.dart`
- In `_saveWisprApiKey()`: after `prefs.setString(_wisprApiKeyPrefKey, key)`, add:
  - `WisprConfigService.instance.clearCache();`
- Ensures new key is used on next voice mode session without app restart.

### 2. `lib/arc/chat/voice/config/wispr_config_service.dart`
- `clearCache()` already existed: sets `_cachedApiKey = null`, `_hasCheckedPrefs = false`.
- `refreshApiKey()` also available for force-refresh from preferences.

## Verification
- Save new Wispr API key in Settings → External Services.
- Without restarting app, start a voice session; UnifiedTranscriptionService should call `isAvailable()` / `getApiKey()` and get the new key from preferences (cache was cleared).
- Voice transcription should use the new key.

## Related
- **Wispr Flow**: Admin-only voice transcription backend (wisprflow.ai). Fallback: Apple On-Device.
- **Config**: `WisprConfigService` – API key from SharedPreferences, cached for performance; clear cache on save.
- **CHANGELOG**: Document in [3.3.13] or next version as "Fix: Wispr Flow cache – new API key used after save without restart."

## Version
v3.3.13 (doc); fix applied in code (clearCache on save).

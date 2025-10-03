ate# EPI MVP Install Guide (Main MVP – Gemini API)

This guide installs and runs the full MVP. The app uses Gemini via the LLMRegistry. If no key is provided (or the API fails), it falls back to the rule‑based client.

## Prerequisites
- Flutter 3.35+ (stable)
- Xcode (iOS) and/or Android SDK
- Gemini API key from Google AI Studio

## One‑time setup
```bash
cd "/Users/mymac/Software Development/EPI/ARC MVP/EPI"
flutter pub get
flutter doctor
```

## Run the full MVP

### **With On-Device LLM (Recommended)**
- **Debug (full app with MLX on-device model)**:
```bash
flutter run -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY
```
- **Without API key (on-device only)**:
```bash
flutter run -d DEVICE_ID
```

### **On-Device LLM Features** ✅ **NEW**
- **Real Qwen3-1.7B Model**: 914MB model bundled in app, loads with progress reporting
- **Privacy-First**: All inference happens locally, no data sent to external servers
- **Fallback System**: On-Device → Cloud API → Rule-Based responses
- **Progress UI**: Real-time loading progress (0% → 100%) during model initialization
- **Metal Acceleration**: Native iOS Metal support for optimal performance

### **Legacy API-Only Mode**
- **Debug (API only, no on-device model)**:
```bash
flutter run -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY
```

- Full Install to Phone
```bash
flutter clean 
flutter pub get
flutter devices
-Choose Device
-Build and Install:
flutter build ios --release --dart-define=GEMINI_API_KEY=YOUR_KEY
flutter install -d YOUR_DEVICE_ID

```

## Run and Debug on Simulator
- Debug (full app):
```bash
flutter clean && flutter pub get && flutter devices
flutter run -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY
```

- If you omit `GEMINI_API_KEY`, the app will fall back to Rule‑Based unless you set the key in‑app via Lumara → AI Models → Gemini API → Configure → Activate.

## iOS device install (release)
```bash
flutter build ios --release --dart-define=GEMINI_API_KEY=YOUR_KEY
flutter install -d YOUR_DEVICE_ID
```
- Find device ID: `flutter devices`
- The key is compiled into this build; rebuild to rotate/change it.

## Android build (release)
```bash
flutter build apk --dart-define=GEMINI_API_KEY=YOUR_KEY
```

## Use Gemini in the Main MVP
- The chat/assistant in Lumara uses `LLMRegistry`.
- Priority: dart‑define key > stored key (SharedPreferences) > rule‑based fallback.
- To set the key at runtime:
  1) Open Lumara → AI Models → Gemini API (Cloud)
  2) Tap "Configure API Key" and paste your key
  3) Tap "Activate" to switch immediately
‑ If the API errors, the app falls back to Rule‑Based.

## Secure key handling
- Pass via `--dart-define=GEMINI_API_KEY=...` at run/build time
- Do not store the key in source files
- Optional shell env:
```bash
export GEMINI_API_KEY='YOUR_KEY'
flutter run -d DEVICE_ID --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

## Troubleshooting
- If it falls back, check network/quota/key validity
- Ensure model path is `gemini-1.5-flash` (v1beta)
- If Send does nothing, confirm logs show HTTP 200 and text chunks; otherwise check the key
- iOS: enable Developer Mode, trust the device in Xcode

## MCP Export/Import (Files app)
- Export: Settings → MCP Export & Import → Export to MCP. After export completes, a Files share sheet opens to save the `.zip` where you want.
- Import: Settings → MCP Export & Import → Import from MCP. Pick the `.zip` from Files; the app extracts it and imports automatically. If the ZIP has a top‑level folder, the app detects the bundle root.

## What’s in this MVP
- `lib/llm/*`: LLMClient, GeminiClient (streaming), RuleBasedClient, LLMRegistry
- Startup selection via `LLMRegistry.initialize()` in `lib/main.dart` with `GEMINI_API_KEY`
- Tests in `test/llm/*` with a fake HTTP client for streaming parsing

# EPI MVP Install Guide (Main MVP – Gemini API)

This guide installs and runs the full MVP. The app uses Gemini via the LLMRegistry with a rule-based fallback if no key is provided or the API fails.

## Prerequisites
- Flutter 3.35+ (stable)
- Xcode (iOS) and/or Android SDK
- Gemini API key from Google AI Studio

## One-time setup
```bash
cd "/Users/mymac/Software Development/EPI/ARC MVP/EPI"
flutter pub get
flutter doctor
```

## Run the full MVP
- Debug (full app):
```bash
flutter run -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY
```

- Profile (recommended for perf testing):
```bash
flutter run --profile -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY
```

- Release (no debugging):
```bash
flutter run --release -d DEVICE_ID --dart-define=GEMINI_API_KEY=YOUR_KEY
```

- If you omit `GEMINI_API_KEY`, the app will fall back to Rule-Based unless you set the key in‑app via Lumara → AI Models → Gemini API → Configure → Activate.

## iOS device install (release)
```bash
flutter build ios --release
flutter install -d YOUR_DEVICE_ID
```
For local debug or profile on a device, use the commands in "Run the full MVP".

## iPhone install with API key (release build)
Embed the key at build time, then install:
```bash
flutter build ios --release --dart-define=GEMINI_API_KEY=YOUR_KEY
flutter install -d YOUR_DEVICE_ID
```
- Find device ID: `flutter devices`
- The key is compiled into this build; rebuild to rotate/change it.

## Android build (release)
```bash
flutter build apk --dart-define=GEMINI_API_KEY=YOUR_KEY
```

## Secure key handling
- Pass via `--dart-define=GEMINI_API_KEY=...` at run/build time
- Do not store the key in source files
- Optional shell env:
```bash
export GEMINI_API_KEY='YOUR_KEY'
flutter run --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY --route=/llm-demo
```

## Use Gemini in the Main MVP
- The chat/assistant in Lumara uses `LLMRegistry`.
- Priority: dart-define key > stored key (SharedPreferences) > rule-based fallback.
- To set the key at runtime:
  1) Open Lumara → AI Models → Gemini API (Cloud)
  2) Tap "Configure API Key" and paste your key
  3) Tap "Activate" to switch immediately
‑ If the API errors, the app falls back to Rule‑Based.

## Troubleshooting
- If it falls back, check network/quota/key validity
- Ensure model path is `gemini-1.5-flash` for v1beta
- If Send does nothing, confirm logs show status 200 and text chunks; otherwise check the key
- iOS: enable Developer Mode, trust the device in Xcode

## What’s in this MVP
- `lib/llm/*`: LLMClient, GeminiClient (streaming), RuleBasedClient, LLMRegistry
- Startup selection via `LLMRegistry.initialize()` in `lib/main.dart` with `GEMINI_API_KEY`
- Tests in `test/llm/*` with a fake HTTP client for JSONL parsing



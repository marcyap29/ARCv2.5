# LUMARA Gemma 3 Setup Guide

## Overview

This guide will help you set up **LUMARA** with **Gemma 3 4B-Instruct** for on-device AI inference. The implementation follows the adapter pattern you specified, supporting:

- **Option A**: Rule-based responses (no LLM) - **Currently Active**
- **Option B**: On-device mini model (Gemma 3 4B-Instruct) - **Ready to Enable**
- **Option C**: Cloud model (future implementation)

## Current Status

✅ **Implemented**:
- Adapter pattern with `ModelAdapter` interface
- `RuleBasedAdapter` (currently active)
- `GemmaAdapter` with native MediaPipe integration
- Native bridges for Android (Kotlin) and iOS (Swift)
- Streaming response interface
- Device capability detection (RAM, model selection)

🔄 **Next Steps**:
- Download actual Gemma model files
- Test native bridge integration
- Enable Gemma adapter

## Architecture

```
LUMARA Assistant
├── ModelAdapter (interface)
│   ├── RuleBasedAdapter (templates, no LLM)
│   ├── GemmaAdapter (on-device Gemma 3)
│   └── CloudAdapter (future)
├── Native Bridges
│   ├── Android: GemmaEdgeBridge.kt
│   └── iOS: GemmaEdgeBridge.swift
└── MediaPipe Tasks
    ├── Gemma 3 4B-Instruct (chat/reasoning)
    ├── Gemma 3 VLM 4B (vision)
    └── EmbeddingGemma (embeddings)
```

## Model Files Required

To enable real AI inference, you need to download these model files:

### 1. Gemma 3 4B-Instruct (Primary)
- **File**: `gemma3_4b_instruct.int4`
- **Size**: ~2.5GB
- **Purpose**: Chat, reasoning, summarization
- **Location**: `assets/models/gemma3_4b_instruct.int4`

### 2. Gemma 3 1B-Instruct (Fallback)
- **File**: `gemma3_1b_instruct.int4`
- **Size**: ~700MB
- **Purpose**: Fallback for devices with <8GB RAM
- **Location**: `assets/models/gemma3_1b_instruct.int4`

### 3. Gemma 3 VLM 4B (Vision)
- **File**: `gemma3_vlm_4b.int4`
- **Size**: ~2.5GB
- **Purpose**: Image analysis and captions
- **Location**: `assets/models/gemma3_vlm_4b.int4`

### 4. EmbeddingGemma (Embeddings)
- **File**: `embeddinggemma_mrl_512.tflite`
- **Size**: ~100MB
- **Purpose**: Text embeddings for retrieval
- **Location**: `assets/models/embeddinggemma_mrl_512.tflite`

## Download Sources

1. **Google AI Studio**: https://aistudio.google.com/
2. **Hugging Face**: https://huggingface.co/google/gemma-2-9b-it
3. **MediaPipe Model Hub**: https://developers.google.com/mediapipe/solutions/genai

## Setup Instructions

### Step 1: Download Model Files

1. Create the models directory:
   ```bash
   mkdir -p "ARC MVP/EPI/assets/models"
   ```

2. Download the required model files to `assets/models/`

### Step 2: Update Asset Configuration

Add to `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/models/
```

### Step 3: Test the Implementation

1. **Run the app**:
   ```bash
   cd "ARC MVP/EPI"
   flutter run -d "YOUR_DEVICE_ID"
   ```

2. **Check logs** for:
   - "Native bridges registered successfully"
   - "GemmaAdapter: Using 4B model for capable device" (or 1B for limited devices)
   - "Chat model initialized successfully"

### Step 4: Enable Gemma Adapter

The app will automatically try to use Gemma if model files are available. If not, it falls back to rule-based responses.

## Testing

### Test Rule-Based Responses (Current)
1. Open LUMARA assistant
2. Ask: "Summarize my last 7 days"
3. Should get template-based response with streaming effect

### Test Gemma Responses (After Setup)
1. Ensure model files are in place
2. Restart the app
3. Ask the same question
4. Should get AI-generated response with better phrasing

## Device Requirements

### Minimum Requirements
- **RAM**: 4GB (uses 1B model)
- **Storage**: 1GB free space
- **OS**: Android 8.0+ / iOS 16.0+

### Recommended Requirements
- **RAM**: 8GB+ (uses 4B model)
- **Storage**: 5GB free space
- **OS**: Android 10+ / iOS 17.0+

## Troubleshooting

### Common Issues

1. **"Model not initialized"**
   - Check if model files exist in `assets/models/`
   - Verify file permissions
   - Check device RAM requirements

2. **"Native bridge not found"**
   - Ensure MediaPipe dependencies are installed
   - Run `flutter clean && flutter pub get`
   - Rebuild the app

3. **"Insufficient RAM"**
   - App will automatically fall back to 1B model
   - Close other apps to free memory

### Debug Commands

```bash
# Check device capabilities
flutter run --verbose

# Clean and rebuild
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter run
```

## Performance Expectations

### Rule-Based (Current)
- **Latency**: <100ms
- **Quality**: Good templates, consistent
- **Privacy**: 100% local

### Gemma 3 4B (Target)
- **Latency**: 1-3 seconds
- **Quality**: Excellent, natural language
- **Privacy**: 100% local
- **Memory**: ~2.5GB RAM usage

## Next Steps

1. **Download model files** from the sources above
2. **Test the implementation** with the current rule-based system
3. **Enable Gemma** by placing model files in the correct location
4. **Monitor performance** and adjust model selection based on device capabilities

## Support

If you encounter issues:
1. Check the logs for specific error messages
2. Verify model files are in the correct location
3. Ensure device meets minimum requirements
4. Try the fallback 1B model if 4B fails

The implementation is designed to gracefully degrade from AI to rule-based responses, ensuring the app always works regardless of model availability.

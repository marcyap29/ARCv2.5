# Gemma Model Download Guide

## 🚀 **Quick Start**

### Option 1: Use the Download Script (Recommended)
```bash
# Make the script executable
chmod +x download_models.py

# Run the download script
python3 download_models.py
```

### Option 2: Manual Download

## 📥 **Manual Download Steps**

### 1. **Gemma 3 1B-Instruct** (Recommended for most devices)
- **Size**: ~700MB
- **Source**: [Hugging Face - Gemma 2 9B IT](https://huggingface.co/google/gemma-2-9b-it)
- **File**: Download `model.safetensors`
- **Rename to**: `gemma3_1b_instruct.safetensors`
- **Place in**: `assets/models/`

### 2. **Gemma 3 4B-Instruct** (Best performance)
- **Size**: ~2.5GB
- **Source**: [Hugging Face - Gemma 2 9B IT](https://huggingface.co/google/gemma-2-9b-it)
- **File**: Download `model.safetensors`
- **Rename to**: `gemma3_4b_instruct.safetensors`
- **Place in**: `assets/models/`

### 3. **EmbeddingGemma** (For text embeddings)
- **Size**: ~100MB
- **Source**: [Hugging Face - Embedding Gecko](https://huggingface.co/google/embedding-gecko-003)
- **File**: Download `model.tflite`
- **Rename to**: `embeddinggemma_mrl_512.tflite`
- **Place in**: `assets/models/`

## 🔧 **After Downloading Models**

### 1. **Update Dependencies**
```bash
flutter pub get
```

### 2. **Enable MediaPipe Dependencies**

**Android** (`android/app/build.gradle.kts`):
```kotlin
dependencies {
    // Uncomment these lines
    implementation("com.google.mediapipe:tasks-genai:0.10.14")
    implementation("com.google.mediapipe:tasks-text:0.10.14")
}
```

**iOS** (`ios/Podfile`):
```ruby
target 'Runner' do
  use_frameworks! :linkage => :static
  
  # Uncomment these lines
  pod 'MediaPipeTasksGenAI', '~> 0.10.14'
  pod 'MediaPipeTasksGenAIC', '~> 0.10.14'
  pod 'MediaPipeTasksText', '~> 0.10.14'
  
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end
```

### 3. **Update Native Bridges**

**Android** (`android/app/src/main/java/com/example/my_app/GemmaEdgeBridge.kt`):
```kotlin
// Uncomment the MediaPipe imports
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import com.google.mediapipe.tasks.genai.llminference.LlmInferenceOptions
import com.google.mediapipe.tasks.text.embedder.TextEmbedder
import com.google.mediapipe.tasks.text.embedder.TextEmbedderOptions
```

**iOS** (`ios/Runner/GemmaEdgeBridge.swift`):
```swift
// Uncomment the MediaPipe imports
import MediaPipeTasksGenAI
import MediaPipeTasksText
```

### 4. **Rebuild and Test**
```bash
# Clean and rebuild
flutter clean
flutter pub get

# For iOS
cd ios && pod install && cd ..
flutter build ios --release

# For Android
flutter build apk --release
```

## 📱 **Testing the Models**

1. **Run the app**: `flutter run`
2. **Open LUMARA**: Navigate to the LUMARA tab
3. **Test AI responses**: Ask "Summarize my last 7 days"
4. **Check logs**: Look for "GemmaAdapter: Using 4B model" or "Using 1B model"

## 🔍 **Troubleshooting**

### Model Not Loading
- Check file names match exactly
- Verify files are in `assets/models/`
- Check file permissions
- Look for error messages in logs

### Build Errors
- Ensure MediaPipe dependencies are uncommented
- Run `flutter clean && flutter pub get`
- For iOS: `cd ios && pod install && cd ..`

### Performance Issues
- Try 1B model instead of 4B
- Check device RAM (need 4GB+ for 1B, 8GB+ for 4B)
- Close other apps to free memory

## 📊 **Model Comparison**

| Model | Size | RAM Required | Performance | Use Case |
|-------|------|--------------|-------------|----------|
| 1B | ~700MB | 4GB+ | Good | Most devices |
| 4B | ~2.5GB | 8GB+ | Excellent | High-end devices |
| Embeddings | ~100MB | 2GB+ | Fast | Text search |

## 🎯 **Next Steps**

1. **Download models** using the script or manually
2. **Enable MediaPipe** dependencies
3. **Test the implementation** with real AI responses
4. **Customize prompts** for your specific use case
5. **Monitor performance** and adjust model selection

## 💡 **Pro Tips**

- Start with 1B model for testing
- Use 4B model for production if device supports it
- Monitor memory usage during inference
- Test with different query types
- Keep models updated for best performance

The LUMARA system will automatically detect and use the best available model for your device!

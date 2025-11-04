# LUMARA Prompt Profiles Implementation

## Overview

This implementation updates the on-device LLM prompts system to use a new profile-based approach that provides different prompt configurations for different models and contexts.

## Files Created/Modified

### New Files
- `lumara_prompt_profiles.json` - JSON configuration containing prompt profiles and model mappings
- `prompt_profile_manager.dart` - Manager class for handling profile selection and prompt assembly
- `README_PROMPT_PROFILES.md` - This documentation file

### Modified Files
- `ondevice_prompt_service.dart` - Updated to use the new profile system
- `lumara_system_prompt.dart` - Updated to integrate with the new profile system (with deprecation warnings)
- `qwen_provider.dart` - Updated to use the new prompt system
- `llama_provider.dart` - Updated to use the new prompt system
- `ios/Runner/Sources/Runner/PromptTemplates.swift` - Updated to use the new mobile profile

## Prompt Profiles

The system now supports four distinct prompt profiles:

### 1. Core Profile
- **Purpose**: Baseline "Local Reflection Core"
- **Use Case**: General on-device processing
- **Characteristics**: Short, supportive, JSON-only output
- **Output Format**: `{intent, emotion, phase, insight}`

### 2. Mobile Profile
- **Purpose**: Lowest latency processing
- **Use Case**: Quick tap-and-journal interactions
- **Characteristics**: One-line insight, token budget constrained (max 25 tokens)
- **Output Format**: `{intent, emotion, phase, insight}` with strict word limits

### 3. Offline Profile
- **Purpose**: Balanced warmth and clarity when no cloud is available
- **Use Case**: Offline or local-only processing
- **Characteristics**: Richer tone, 3 sentences maximum
- **Output Format**: `{intent, emotion, phase, insight}`

### 4. Phase Profile
- **Purpose**: Emphasizes ATLAS phase inference
- **Use Case**: Phase quality priority, MIRA training
- **Characteristics**: Returns confidence estimate
- **Output Format**: `{intent, emotion, phase, confidence, insight}`

## Model Mappings

Each model has a default profile and specific generation settings:

| Model | Default Profile | Max Tokens | Temperature | Use Case |
|-------|----------------|------------|-------------|----------|
| `llama-3.2-3b-instruct-q4_k_m` | mobile | 128 | 0.5 | Fastest path on iPhone |
| `llama-3.2-3b-instruct-q6_k` | mobile | 128 | 0.5 | Higher quant quality |
| `qwen3-4b-instruct-2507-q4_k_m` | offline | 160 | 0.6 | Richer tone when offline |
| `qwen3-4b-instruct-2507-q5_k_m` | offline | 160 | 0.6 | Same as above with 5-bit quant |
| `qwen3-1.7b-instruct-q4_k_m` | mobile | 96 | 0.6 | Very small model, brief outputs |

## Usage

### Basic Usage

```dart
// Initialize the prompt service
await OnDevicePromptService.initialize();

// Create a system prompt for a specific model and context
final systemPrompt = OnDevicePromptService.createSystemPrompt(
  'qwen3-4b-instruct-2507-q4_k_m',
  isOffline: true,
  isFastMode: false,
  isPhaseFocus: false,
  isLowLatency: false,
);

// Get generation settings for a model
final settings = OnDevicePromptService.getGenerationSettings('qwen3-4b-instruct-2507-q4_k_m');
```

### Context Selection

The system automatically selects the best profile based on context flags:

- **Phase Focus**: Uses "phase" profile for ATLAS phase inference
- **Fast Mode**: Uses "mobile" profile for quick responses
- **Offline**: Uses "offline" profile when cloud is unavailable
- **Low Latency**: Uses "mobile" profile for minimal response time

### JSON Response Parsing

```dart
// Parse JSON response from the new prompt system
final jsonResponse = OnDevicePromptService.parseJsonResponse(modelOutput);
if (jsonResponse != null) {
  final intent = jsonResponse['intent'] as String?;
  final emotion = jsonResponse['emotion'] as String?;
  final phase = jsonResponse['phase'] as String?;
  final insight = jsonResponse['insight'] as String?;
}
```

## Migration Guide

### For Existing Code

1. **Replace direct system prompt usage**:
   ```dart
   // Old way
   final prompt = LumaraSystemPrompt.universal;
   
   // New way
   final prompt = OnDevicePromptService.createSystemPrompt(modelId);
   ```

2. **Update LLM provider calls**:
   ```dart
   // Add context flags to your context map
   final context = {
     'userPrompt': userInput,
     'isOffline': true,
     'isFastMode': false,
     'isPhaseFocus': false,
     'isLowLatency': false,
   };
   ```

3. **Handle JSON responses**:
   ```dart
   // Parse structured responses
   final jsonData = OnDevicePromptService.parseJsonResponse(response);
   ```

## Benefits

1. **Model-Specific Optimization**: Each model gets prompts and settings optimized for its capabilities
2. **Context-Aware Selection**: Different profiles for different use cases
3. **Consistent JSON Output**: All profiles enforce structured JSON responses
4. **Easy Configuration**: JSON-based configuration makes it easy to add new models or profiles
5. **Backward Compatibility**: Legacy methods still work with deprecation warnings

## Future Enhancements

1. **Dynamic Profile Loading**: Load profiles from remote configuration
2. **A/B Testing**: Support for multiple profiles per model for testing
3. **Custom Profiles**: Allow runtime creation of custom profiles
4. **Metrics Integration**: Track which profiles perform best for different use cases

## Troubleshooting

### Common Issues

1. **Profile not found**: Check that the model ID exists in the JSON configuration
2. **JSON parsing fails**: Ensure the model is returning valid JSON format
3. **Wrong profile selected**: Verify context flags are set correctly

### Debug Information

Enable debug logging to see which profile is selected:
```dart
debugPrint('Selected profile: ${profile} for model: ${modelId}');
```

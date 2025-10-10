/// LUMARA Model Presets for On-Device LLMs
/// 
/// Optimized inference parameters for different model types

class LumaraModelPresets {
  /// Llama 3.2 3B (Q4_K_M) preset - iPhone 16 Pro optimized
  /// Based on ChatGPT LUMARA-on-mobile recommendations
  static const Map<String, dynamic> llama32_3b = {
    'temperature': 0.7,
    'top_p': 0.9,   // Standard nucleus sampling
    // Disabled for speed: top_k, min_p, typical_p, penalties
    'max_new_tokens': 80,  // Mobile-optimized default
    'stop_tokens': ['[END]', '</s>', '<|eot_id|>'],  // [END] is primary stop
  };

  /// Phi-3.5-Mini Instruct (Q4_K_M) preset - iPhone 16 Pro optimized
  static const Map<String, dynamic> phi35_mini = {
    'temperature': 0.7,
    'top_p': 0.9,
    'max_new_tokens': 80,
    'stop_tokens': ['[END]', '</s>'],
  };

  /// Qwen-3/2.5 4B Instruct (Q5_K_M or Q4_K_M) preset - iPhone 16 Pro optimized
  static const Map<String, dynamic> qwen3_4b = {
    'temperature': 0.7,
    'top_p': 0.9,
    'max_new_tokens': 80,
    'stop_tokens': ['[END]', '<|im_end|>', '</s>'],
  };

  /// Get preset by model name
  static Map<String, dynamic> getPreset(String modelName) {
    final name = modelName.toLowerCase();
    
    if (name.contains('llama') && name.contains('3.2')) {
      return Map<String, dynamic>.from(llama32_3b);
    } else if (name.contains('phi') && name.contains('3.5')) {
      return Map<String, dynamic>.from(phi35_mini);
    } else if (name.contains('qwen')) {
      return Map<String, dynamic>.from(qwen3_4b);
    } else {
      // Default to Llama 3.2 3B settings
      return Map<String, dynamic>.from(llama32_3b);
    }
  }

  /// Get model-specific stop tokens
  static List<String> getStopTokens(String modelName) {
    final preset = getPreset(modelName);
    return List<String>.from(preset['stop_tokens'] ?? []);
  }

  /// Get model-specific max tokens
  static int getMaxTokens(String modelName) {
    final preset = getPreset(modelName);
    return preset['max_new_tokens'] ?? 256;
  }

  /// Get model-specific temperature
  static double getTemperature(String modelName) {
    final preset = getPreset(modelName);
    return (preset['temperature'] ?? 0.7).toDouble();
  }

  /// Get model-specific top_p
  static double getTopP(String modelName) {
    final preset = getPreset(modelName);
    return (preset['top_p'] ?? 0.9).toDouble();
  }

  /// Get model-specific top_k
  static int getTopK(String modelName) {
    final preset = getPreset(modelName);
    return preset['top_k'] ?? 40;
  }

  /// Get model-specific repeat penalty
  static double getRepeatPenalty(String modelName) {
    final preset = getPreset(modelName);
    return (preset['repeat_penalty'] ?? 1.1).toDouble();
  }

  /// Adjust parameters for better quality (if outputs are too fluffy)
  static Map<String, dynamic> adjustForQuality(String modelName, {
    bool reduceFluff = false,
    bool increasePrecision = false,
  }) {
    final preset = Map<String, dynamic>.from(getPreset(modelName));
    
    if (reduceFluff) {
      preset['temperature'] = (preset['temperature'] as double) - 0.1;
      preset['repeat_penalty'] = (preset['repeat_penalty'] as double) + 0.02;
    }
    
    if (increasePrecision) {
      preset['top_p'] = (preset['top_p'] as double) - 0.05;
      preset['top_k'] = (preset['top_k'] as int) + 10;
    }
    
    return preset;
  }

  /// Adjust parameters for more creativity (if outputs are too terse)
  static Map<String, dynamic> adjustForCreativity(String modelName) {
    final preset = Map<String, dynamic>.from(getPreset(modelName));
    
    preset['temperature'] = (preset['temperature'] as double) + 0.1;
    preset['top_p'] = (preset['top_p'] as double) + 0.05;
    preset['top_k'] = (preset['top_k'] as int) + 10;
    
    return preset;
  }
}

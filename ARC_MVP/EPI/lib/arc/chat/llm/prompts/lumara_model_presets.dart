/// LUMARA Model Presets for On-Device LLMs
/// 
/// Optimized inference parameters for different model types
library;

class LumaraModelPresets {

  /// Phi-3.5-Mini Instruct (Q4_K_M) preset - iPhone 16 Pro optimized
  static const Map<String, dynamic> phi35_mini = {
    'temperature': 0.7,
    'top_p': 0.9,
    'max_new_tokens': 80,
    'stop_tokens': ['[END]', '</s>'],
  };

  /// Llama 3.2 3B Instruct (Q4_K_M) preset - Recommended model
  static const Map<String, dynamic> llama32_3b = {
    'temperature': 0.7,   // Balanced for good quality
    'top_p': 0.9,
    'top_k': 40,
    'max_new_tokens': 128,
    'repeat_penalty': 1.05,
    'stop_tokens': ['<|eot_id|>', '<|end_of_text|>', '</s>'],
  };

  /// Qwen3 4B Instruct (Q4_K_S) preset - High quality multilingual model
  static const Map<String, dynamic> qwen3_4b_q4k_s = {
    'temperature': 0.7,   // Good balance for reasoning
    'top_p': 0.9,
    'top_k': 50,
    'max_new_tokens': 256,
    'repeat_penalty': 1.05,
    'stop_tokens': ['<|eot_id|>', '<|im_end|>', '<|end_of_text|>'],
  };

  /// Get preset by model name
  static Map<String, dynamic> getPreset(String modelName) {
    final name = modelName.toLowerCase();
    
    if (name.contains('llama') && name.contains('3.2') && name.contains('3b')) {
      return Map<String, dynamic>.from(llama32_3b);
    } else if (name.contains('qwen3') && name.contains('4b')) {
      return Map<String, dynamic>.from(qwen3_4b_q4k_s);
    } else if (name.contains('llama') && name.contains('3.2')) {
      return Map<String, dynamic>.from(llama32_3b);
    } else if (name.contains('phi') && name.contains('3.5')) {
      return Map<String, dynamic>.from(phi35_mini);
    } else if (name.contains('qwen')) {
      return Map<String, dynamic>.from(qwen3_4b_q4k_s);
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

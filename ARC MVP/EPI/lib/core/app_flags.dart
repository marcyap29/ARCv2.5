/// Feature flags for the application
class AppFlags {
  static const enableLumara = true;

  // Qwen-only local stack
  static const enableQwenChat = true;       // Qwen3-4B-Instruct or Qwen3-1.7B-Instruct fallback
  static const enableQwenVLM  = true;       // Qwen2.5-VL-3B or Qwen2-VL-2B fallback
  static const enableQwenEmb  = true;       // Qwen3-Embedding-0.6B

  // Remote is compiled but OFF (opt-in)
  static const allowRemoteLLM = false;

  // Keep Gemma/Mistral flags hidden for future A/B
  static const enableGemma = false;
  static const enableMistral = false;
  
  // Runtime preference
  static const preferLlamaCpp = true;       // Default to llama.cpp over MLC LLM
  
  // Model size thresholds
  static const minRamForQwen4B = 8;         // 8GB RAM required for Qwen3-4B
  static const minRamForQwenVL3B = 6;       // 6GB RAM required for Qwen2.5-VL-3B
  
  // Performance targets
  static const maxFirstTokenLatencyMs = 1500;  // <1.5s for first token
  static const maxTokensPerSecond = 10;        // Minimum acceptable generation speed
  
  // Development flags
  static const bool enableDebugLogging = true;
  static const bool enableTelemetry = true;
  
  // Model management flags
  static const bool enableModelDownloads = true;
  static const bool enableModelPauseResume = true;
  static const bool enableModelChecksum = true;
  
  // UI flags
  static const bool enableSlidingWindowChat = true;
  static const bool enableCitationChips = true;
  static const bool enableRivetBanner = true;
  
  // Safety flags
  static const bool enableRedaction = true;
  static const bool enableRivetGuardrails = true;
  
  /// Check if LUMARA is enabled
  static bool get isLumaraEnabled => enableLumara;
  
  /// Check if any Qwen models are enabled
  static bool get isQwenEnabled => enableQwenChat || enableQwenVLM || enableQwenEmb;
  
  /// Check if remote LLM is allowed
  static bool get isRemoteLLMAllowed => allowRemoteLLM;
  
  /// Get enabled model types
  static List<String> get enabledModelTypes {
    final types = <String>[];
    if (enableQwenChat) types.add('qwen_chat');
    if (enableQwenVLM) types.add('qwen_vlm');
    if (enableQwenEmb) types.add('qwen_embedding');
    return types;
  }
}

enum LlmRuntime { 
  llamacpp,   // GGUF models via llama.cpp
  mlc         // MLC LLM runtime
}

const LlmRuntime activeRuntime = LlmRuntime.llamacpp; // default

enum QwenModel {
  // Chat models
  qwen3_4b_instruct,    // Primary chat model for capable devices
  qwen3_1p7b_instruct,  // Fallback chat model for memory-constrained devices
  qwen2p5_1p5b_instruct, // Available Qwen 2.5 1.5B model
  
  // Vision models  
  qwen2p5_vl_3b_instruct,  // Primary VLM model
  qwen2_vl_2b_instruct,    // Fallback VLM model
  
  // Embedding models
  qwen3_embedding_0p6b,    // Compact embedding model for on-device RAG
}

class ModelConfig {
  final String filename;
  final String displayName;
  final int estimatedSizeMB;
  final int minRamGB;
  final String description;
  final bool isDefault;
  
  const ModelConfig({
    required this.filename,
    required this.displayName,
    required this.estimatedSizeMB,
    required this.minRamGB,
    required this.description,
    this.isDefault = false,
  });
}

const Map<QwenModel, ModelConfig> modelConfigs = {
  QwenModel.qwen3_4b_instruct: ModelConfig(
    filename: 'qwen3_4b_instruct_q4_k_m.gguf',
    displayName: 'Qwen3 4B Instruct',
    estimatedSizeMB: 2500,
    minRamGB: 8,
    description: 'Primary chat model with excellent reasoning capabilities',
    isDefault: false,
  ),
  
  QwenModel.qwen3_1p7b_instruct: ModelConfig(
    filename: 'qwen3_1p7b_instruct_q4_k_m.gguf',
    displayName: 'Qwen3 1.7B Instruct',
    estimatedSizeMB: 1100,
    minRamGB: 4,
    description: 'Lightweight chat model for memory-constrained devices',
  ),
  
  QwenModel.qwen2p5_1p5b_instruct: ModelConfig(
    filename: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
    displayName: 'Qwen 2.5 1.5B Instruct',
    estimatedSizeMB: 950,
    minRamGB: 3,
    description: 'Available Qwen 2.5 model with good performance',
    isDefault: true, // Set as default since this is what we have
  ),
  
  QwenModel.qwen2p5_vl_3b_instruct: ModelConfig(
    filename: 'qwen2p5_vl_3b_instruct_q5_k_m.gguf',
    displayName: 'Qwen2.5-VL 3B Instruct',
    estimatedSizeMB: 2000,
    minRamGB: 6,
    description: 'Vision-language model for image understanding',
    isDefault: true,
  ),
  
  QwenModel.qwen2_vl_2b_instruct: ModelConfig(
    filename: 'qwen2_vl_2b_instruct_q6_k_l.gguf',
    displayName: 'Qwen2-VL 2B Instruct',
    estimatedSizeMB: 1600,
    minRamGB: 4,
    description: 'Compact vision-language model',
  ),
  
  QwenModel.qwen3_embedding_0p6b: ModelConfig(
    filename: 'qwen3_embedding_0p6b_int4.gguf',
    displayName: 'Qwen3 Embedding 0.6B',
    estimatedSizeMB: 400,
    minRamGB: 2,
    description: 'Compact embedding model for semantic search and RAG',
    isDefault: true,
  ),
};

class GenParams {
  final double temperature;
  final double topP;
  final double repeatPenalty;
  final int maxTokens;
  final int contextLength;
  final int seed;
  
  const GenParams({
    this.temperature = 0.6,
    this.topP = 0.9,
    this.repeatPenalty = 1.1,
    this.maxTokens = 256,
    this.contextLength = 4096,
    this.seed = 101, // deterministic for dev
  });
  
  Map<String, dynamic> toMap() => {
    'temperature': temperature,
    'top_p': topP,
    'repeat_penalty': repeatPenalty,
    'max_tokens': maxTokens,
    'context_length': contextLength,
    'seed': seed,
  };
}
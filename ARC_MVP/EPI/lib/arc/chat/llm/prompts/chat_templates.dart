/// Chat templates optimized for tiny models (Qwen3-1.7B, Llama-3.2-1B)
/// Uses proper control tokens and ASCII-only formatting

class ChatTemplates {
  /// Qwen3 chat template - uses llama.cpp control tokens
  static String qwenTemplate({
    required String systemMessage,
    required String userMessage,
  }) {
    return "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n"
        "$systemMessage\n"
        "<|eot_id|><|start_header_id|>user<|end_header_id|>\n"
        "$userMessage\n"
        "<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n";
  }

  /// Llama 3.2 Instruct template - uses llama.cpp control tokens
  static String llamaTemplate({
    required String systemMessage,
    required String userMessage,
  }) {
    return "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n"
        "$systemMessage\n"
        "<|eot_id|><|start_header_id|>user<|end_header_id|>\n"
        "$userMessage\n"
        "<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n";
  }

  /// Get the appropriate template for a model
  static String getTemplate(String modelName, {
    required String systemMessage,
    required String userMessage,
  }) {
    final name = modelName.toLowerCase();
    
    if (name.contains('qwen3') && name.contains('1.7b')) {
      return qwenTemplate(systemMessage: systemMessage, userMessage: userMessage);
    } else if (name.contains('llama') && name.contains('3.2') && name.contains('1b')) {
      return llamaTemplate(systemMessage: systemMessage, userMessage: userMessage);
    } else if (name.contains('qwen')) {
      return qwenTemplate(systemMessage: systemMessage, userMessage: userMessage);
    } else {
      // Default to Qwen template
      return qwenTemplate(systemMessage: systemMessage, userMessage: userMessage);
    }
  }

  /// Convert text to ASCII-only to avoid mojibake on tiny models
  static String toAscii(String text) {
    return text
        .replaceAll("'", "'")
        .replaceAll(""", '"')
        .replaceAll(""", '"')
        .replaceAll("–", "-")
        .replaceAll("—", "-")
        .replaceAll(RegExp(r"[^\x00-\x7F]"), "");
  }

  /// Clip text to specified length for tiny model prompts
  static String clip(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength).trimRight() + "...";
  }
}

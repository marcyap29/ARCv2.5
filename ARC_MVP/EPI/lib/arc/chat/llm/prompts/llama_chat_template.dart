/// Llama Chat Template Formatter
/// 
/// Formats prompts according to Llama-3.2-Instruct chat template specification
library;

class LlamaChatTemplate {
  static const String bosToken = "<|begin_of_text|>";
  static const String eotToken = "<|eot_id|>";
  static const String eomToken = "<|eom_id|>";
  static const String startHeaderId = "<|start_header_id|>";
  static const String endHeaderId = "<|end_header_id|>";
  
  /// Format a conversation for Llama-3.2-Instruct
  static String formatConversation({
    required String systemMessage,
    required String userMessage,
    bool addGenerationPrompt = true,
  }) {
    final buffer = StringBuffer();
    
    // Begin of text
    buffer.write(bosToken);
    
    // System message
    buffer.write(startHeaderId);
    buffer.write("system");
    buffer.write(endHeaderId);
    buffer.writeln();
    buffer.writeln(systemMessage);
    buffer.write(eotToken);
    
    // User message
    buffer.write(startHeaderId);
    buffer.write("user");
    buffer.write(endHeaderId);
    buffer.writeln();
    buffer.writeln(userMessage);
    buffer.write(eotToken);
    
    // Assistant header (for generation)
    if (addGenerationPrompt) {
      buffer.write(startHeaderId);
      buffer.write("assistant");
      buffer.write(endHeaderId);
      buffer.writeln();
      // Note: No eot_id here - this is where the model should start generating
    }
    
    return buffer.toString();
  }
  
  /// Format a simple user message with system prompt
  static String formatSimple({
    required String systemMessage,
    required String userMessage,
  }) {
    return formatConversation(
      systemMessage: systemMessage,
      userMessage: userMessage,
      addGenerationPrompt: true,
    );
  }
  
  /// Check if a token is an EOS token
  static bool isEosToken(int tokenId) {
    // Llama-3.2-Instruct uses 128009 as EOT token
    return tokenId == 128009;
  }
  
  /// Check if a token is an EOM token  
  static bool isEomToken(int tokenId) {
    // Llama-3.2-Instruct uses 128008 as EOM token
    return tokenId == 128008;
  }
}


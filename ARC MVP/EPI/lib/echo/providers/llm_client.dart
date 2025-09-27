abstract class LLMClient {
  Stream<String> streamChat(String prompt, {Map<String, dynamic>? opts});
}



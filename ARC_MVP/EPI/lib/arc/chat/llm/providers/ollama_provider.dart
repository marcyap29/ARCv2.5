// lib/arc/chat/llm/providers/ollama_provider.dart
// Ollama Cloud (e.g. nemotron-3-super) via Firebase proxyOllama

import '../llm_provider.dart';
import '../../config/api_config.dart';
import 'package:my_app/services/firebase_service.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/services/ollama_send.dart';

/// Ollama Cloud provider — uses Firebase proxyOllama (no client API key).
class OllamaProvider extends LLMProviderBase {
  OllamaProvider(LumaraAPIConfig apiConfig) : super(apiConfig, 'Ollama (Cloud)', false);

  @override
  LLMProvider getProviderType() => LLMProvider.ollama;

  @override
  Future<bool> isAvailable() async {
    final firebaseReady = await FirebaseService.instance.ensureReady();
    final signedIn = FirebaseAuthService.instance.isSignedIn;
    return firebaseReady && signedIn;
  }

  @override
  Future<String> generateResponse(Map<String, dynamic> context) async {
    final systemPrompt = context['systemPrompt'] as String? ?? '';
    final userPrompt = context['userPrompt'] as String;
    return ollamaSend(
      user: userPrompt,
      system: systemPrompt.isNotEmpty ? systemPrompt : null,
      temperature: 0.7,
    );
  }
}

// lib/arc/chat/llm/providers/groq_provider.dart
// Groq API provider (Llama 3.3 70B / Mixtral) for LUMARA
// Uses Firebase proxy when available; otherwise client-side API key

import '../llm_provider.dart';
import '../../config/api_config.dart';
import '../../services/groq_service.dart';
import 'package:my_app/services/firebase_service.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/services/groq_send.dart';

/// Groq API provider - primary for LUMARA
class GroqProvider extends LLMProviderBase {
  GroqProvider(LumaraAPIConfig apiConfig) : super(apiConfig, 'Groq (Llama 3.3 70B / Mixtral)', false);

  @override
  LLMProvider getProviderType() => LLMProvider.groq;

  @override
  Future<bool> isAvailable() async {
    final config = getConfig();
    if (config?.isAvailable == true && config?.apiKey?.isNotEmpty == true) {
      return true;
    }
    final firebaseReady = await FirebaseService.instance.ensureReady();
    final signedIn = FirebaseAuthService.instance.isSignedIn;
    return firebaseReady && signedIn;
  }

  @override
  Future<String> generateResponse(Map<String, dynamic> context) async {
    final systemPrompt = context['systemPrompt'] as String? ?? '';
    final userPrompt = context['userPrompt'] as String;
    final chatId = context['chatId'] as String?;
    final entryId = context['entryId'] as String?;

    final firebaseReady = await FirebaseService.instance.ensureReady();
    final signedIn = FirebaseAuthService.instance.isSignedIn;

    if (firebaseReady && signedIn) {
      return groqSend(
        user: userPrompt,
        system: systemPrompt.isNotEmpty ? systemPrompt : null,
        temperature: 0.7,
        chatId: chatId,
        entryId: entryId,
      );
    }

    final config = getConfig();
    if (config?.apiKey == null || config!.apiKey!.isEmpty) {
      throw StateError(
        'Groq not available: sign in for Firebase proxy or add a Groq API key in LUMARA settings',
      );
    }

    final groq = GroqService(apiKey: config.apiKey!);
    return groq.generateContent(
      prompt: userPrompt,
      systemPrompt: systemPrompt.isNotEmpty ? systemPrompt : null,
      model: GroqModel.llama33_70b,
      temperature: 0.7,
      fallbackToMixtral: true,
    );
  }
}

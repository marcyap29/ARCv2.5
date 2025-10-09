// File: lib/lumara/chat/quickanswers_router.dart
//
// Drop-in pre-LLM gate for basic MIRA questions with optional polish.
// Call handleUserMessage(...) from your existing chat handler.

import 'dart:async';
import '../../mira/mira_basics.dart';
import '../llm/llm_adapter.dart';

class QuickAnswersRouter {
  final MiraBasicsProvider basicsProvider;
  final LLMAdapter llm;

  QuickAnswersRouter({
    required this.basicsProvider,
    required this.llm,
  });

  /// Returns a final response string.
  /// 1) Uses QuickAnswers to handle phase/themes/streak/recency instantly.
  /// 2) If LLM is ready, lightly polishes using MMCO to improve tone.
  /// 3) Falls back to the base QuickAnswers text if polish fails or model unavailable.
  Future<String?> handleUserMessage(String userText) async {
    // Ensure MMCO is loaded
    if (basicsProvider.mmco == null) {
      await basicsProvider.refresh();
    }
    final mmco = basicsProvider.mmco;
    if (mmco == null) {
      // Nothing to work with. Let your existing path handle it.
      return null;
    }

    final qa = QuickAnswers(mmco);
    if (!qa.canAnswer(userText)) {
      // Not a basic question. Let your existing LLM path handle it.
      return null;
    }

    // Instant base answer without the LLM
    final base = qa.answer(userText);

    // Optional polish if on-device is ready
    final ready = await _safeIsReady();
    if (!ready) return base;

    try {
      final polished = await _polishWithLLM(
        userText: userText,
        mmco: mmco,
        baseAnswer: base,
        maxTokens: 64,
      );
      // Use polished if non-empty and sane
      if (polished != null && polished.trim().isNotEmpty) {
        return polished.trim();
      }
    } catch (_) {
      // Ignore polish failures
    }
    return base;
  }

  Future<bool> _safeIsReady() async {
    try {
      return LLMAdapter.isReady;
    } catch (_) {
      return false;
    }
  }

  /// Very small polish pass. Keep it cheap and deterministic.
  Future<String?> _polishWithLLM({
    required String userText,
    required MMCO mmco,
    required String baseAnswer,
    int maxTokens = 64,
  }) async {
    // Build a compact prompt. We provide MMCO as ground truth.
    final system = [
      "You are LUMARA, a helpful mobile assistant.",
      "Treat the MMCO JSON as ground truth.",
      "Answer briefly in a steady tone. No em dashes.",
      "Do not claim you lack access to context provided in MMCO.",
    ].join(" ");

    final user = [
      "<MMCO>",
      _compactJson(mmco.toJson()),
      "</MMCO>",
      "User asked: \"$userText\"",
      "",
      "Here is a draft answer:", 
      baseAnswer,
      "",
      "Polish the draft to be clear and concise.",
      "Keep any concrete facts from MMCO.",
      "Limit to 3–5 sentences.",
    ].join("\n");

    // Minimal generation call using your existing adapter's thin wrapper.
    // Replace with your actual call signature if different.
    final prompt = _qwenChatTemplate(system: system, user: user);

    // These settings mirror your fast path
    const temperature = 0.3;
    const topP = 0.9;
    const repeatPenalty = 1.1;

    // Example native call you likely already have wired:
    // return await llm.generateText(prompt, maxTokens: maxTokens, temp: temperature, topP: topP, repeatPenalty: repeatPenalty);
    //
    // If your adapter takes a param object, adapt accordingly:
    try {
      // You may have llm.generateChat(params) or similar. Adjust here.
      final text = await _generateMinimal(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: topP,
        repeatPenalty: repeatPenalty,
      );
      return text;
    } catch (e) {
      return null;
    }
  }

  // Stub for your adapter call. Replace with your actual implementation.
  Future<String> _generateMinimal({
    required String prompt,
    required int maxTokens,
    required double temperature,
    required double topP,
    required double repeatPenalty,
  }) async {
    // Use the existing LLMAdapter's realize method with minimal context
    final responseStream = llm.realize(
      task: "chat",
      facts: {}, // Empty facts for minimal context
      snippets: [], // No snippets for minimal context
      chat: [
        {"role": "user", "content": prompt}
      ],
    );
    
    // Collect the streamed response
    String response = '';
    await for (final word in responseStream) {
      response += word;
    }
    
    return response;
  }

  // Qwen-style chat template. Keep it tiny and deterministic.
  String _qwenChatTemplate({required String system, required String user}) {
    return "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n"
        "$system\n"
        "<|eot_id|><|start_header_id|>user<|end_header_id|>\n"
        "$user\n"
        "<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n";
  }

  // Compact JSON to keep prompt short
  String _compactJson(Map<String, dynamic> json) {
    return json.toString(); // quick and compact for small objects
  }
}

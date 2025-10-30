// File: lib/lumara/chat/quickanswers_router.dart
//
// Drop-in pre-LLM gate for basic MIRA questions with optional polish.
// Call handleUserMessage(...) from your existing chat handler.

import 'dart:async';
import 'package:my_app/mira/mira_basics.dart';
import '../llm/llm_adapter.dart';

class _PromptPack {
  final String prompt;
  final double temperature;
  final double topP;
  final double repeatPenalty;
  final int? maxTokens;
  final List<String> stops;
  _PromptPack({
    required this.prompt,
    required this.temperature,
    required this.topP,
    required this.repeatPenalty,
    this.maxTokens,
    this.stops = const [],
  });
}

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
    final modelName = LLMAdapter.activeModelName?.toLowerCase() ?? "";

    // Ultra-short, ASCII-only system prompt.
    const system = "You are LUMARA. Use MMCO as ground truth. "
        "Answer briefly, steady tone, plain ASCII. "
        "Do not say you lack context if MMCO provides it.";

    final user = [
      "<MMCO>",
      _compactJson(mmco.toJson()),
      "</MMCO>",
      'User asked: "${_ascii(userText)}"',
      "",
      "Draft answer:",
      _ascii(baseAnswer),
      "",
      "Polish for clarity. Keep facts. Limit to 3-5 short sentences."
    ].join("\n");

    final _PromptPack p = _selectPromptPack(modelName, system, user);

    try {
      final text = await _generateMinimal(
        prompt: p.prompt,
        maxTokens: p.maxTokens ?? maxTokens,
        temperature: p.temperature,
        topP: p.topP,
        repeatPenalty: p.repeatPenalty,
        // If your adapter supports stop strings, pass p.stops.
        // stops: p.stops,
      );
      return _ascii(text);
    } catch (_) {
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


  // Compact JSON to keep prompt short
  String _compactJson(Map<String, dynamic> json) {
    return json.toString(); // quick and compact for small objects
  }

  String _ascii(String s) => s
      .replaceAll("'", "'")
      .replaceAll(""", '"')
      .replaceAll(""", '"')
      .replaceAll("–", "-")
      .replaceAll("—", "-")
      .replaceAll(RegExp(r"[^\x00-\x7F]"), "");

  // ---- prompt pack & model selection ----

  _PromptPack _selectPromptPack(String modelName, String system, String user) {
    final isQwen4B = modelName.contains("qwen3-4b") ||
        (modelName.contains("qwen3") && modelName.contains("4b"));
    final isLlama3B = modelName.contains("llama-3.2-3b") ||
        (modelName.contains("llama 3.2") && modelName.contains("3b"));

    // Qwen3-4B-Instruct-2507-Q4_K_S.gguf
    if (isQwen4B) {
      final prompt = _qwenChatTemplate(system: system, user: user);
      return _PromptPack(
        prompt: prompt,
        temperature: 0.40,   // slightly warmer than 1–2B; still stable
        topP: 0.90,
        repeatPenalty: 1.07,
        maxTokens: 96,
        stops: const ["<|eot_id|>", "<|im_end|>"],
      );
    }

    // Llama-3.2-3B-Instruct-Q4_K_M.gguf
    if (isLlama3B) {
      final prompt = _llamaChatTemplate(system: system, user: user);
      return _PromptPack(
        prompt: prompt,
        temperature: 0.30,   // conservative to avoid drift
        topP: 0.88,
        repeatPenalty: 1.10,
        maxTokens: 80,
        stops: const ["<|eot_id|>", "<|end_of_text|>", "</s>"],
      );
    }

    // Fallback (Qwen-style headers)
    final prompt = _qwenChatTemplate(system: system, user: user);
    return _PromptPack(
      prompt: prompt,
      temperature: 0.35,
      topP: 0.90,
      repeatPenalty: 1.08,
      maxTokens: 64,
      stops: const ["<|eot_id|>"],
    );
  }

  // Qwen3 headers (works with llama.cpp Qwen GGUF)
  String _qwenChatTemplate({required String system, required String user}) {
    return "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n"
        "$system\n"
        "<|eot_id|><|start_header_id|>user<|end_header_id|>\n"
        "$user\n"
        "<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n";
  }

  // Llama 3.2 Instruct uses the same header tokens in recent llama.cpp builds
  String _llamaChatTemplate({required String system, required String user}) {
    return "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n"
        "$system\n"
        "<|eot_id|><|start_header_id|>user<|end_header_id|>\n"
        "$user\n"
        "<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n";
  }
}

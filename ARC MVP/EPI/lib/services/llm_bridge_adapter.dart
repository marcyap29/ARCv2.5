// lib/services/llm_bridge_adapter.dart
// One-liner façade for ARC prompts, built atop an injected send() call.
// This keeps UI/view models clean and future-proofs for on-device engines.

import 'package:my_app/core/prompts_arc.dart';

typedef LLMInvocation = Future<String> Function({
  required String system,
  required String user,
  bool jsonExpected,
});

class ArcLLM {
  final LLMInvocation send;

  ArcLLM({required this.send});

  Future<String> chat({
    required String userIntent,
    String entryText = '',
    String? phaseHintJson,
    String? lastKeywordsJson,
  }) {
    final userPrompt = ArcPrompts.chat
        .replaceAll('{{user_intent}}', userIntent)
        .replaceAll('{{entry_text}}', entryText)
        .replaceAll('{{phase_hint?}}', phaseHintJson ?? 'null')
        .replaceAll('{{keywords?}}', lastKeywordsJson ?? 'null');

    return send(
      system: ArcPrompts.system,
      user: userPrompt,
      jsonExpected: false,
    );
  }

  Future<String> sageEcho(String entryText) {
    final userPrompt = ArcPrompts.sageEcho.replaceAll('{{entry_text}}', entryText);
    return send(
      system: ArcPrompts.system,
      user: userPrompt,
      jsonExpected: true,
    );
  }

  Future<String> arcformKeywords({
    required String entryText,
    String? sageJson,
  }) {
    final userPrompt = ArcPrompts.arcformKeywords
        .replaceAll('{{entry_text}}', entryText)
        .replaceAll('{{sage_json}}', sageJson ?? 'null');
    return send(
      system: ArcPrompts.system,
      user: userPrompt,
      jsonExpected: true,
    );
  }

  Future<String> phaseHints({
    required String entryText,
    String? sageJson,
    String? keywordsJson,
  }) {
    final userPrompt = ArcPrompts.phaseHints
        .replaceAll('{{entry_text}}', entryText)
        .replaceAll('{{sage_json}}', sageJson ?? 'null')
        .replaceAll('{{keywords}}', keywordsJson ?? 'null');
    return send(
      system: ArcPrompts.system,
      user: userPrompt,
      jsonExpected: true,
    );
  }

  Future<String> rivetLite({
    required String targetName,
    required String targetContent,
    required String contractSummary,
  }) {
    final userPrompt = ArcPrompts.rivetLite
        .replaceAll('{{target_name}}', targetName)
        .replaceAll('{{target_content}}', targetContent)
        .replaceAll('{{contract_summary}}', contractSummary);
    return send(
      system: ArcPrompts.system,
      user: userPrompt,
      jsonExpected: true,
    );
  }

  String get fallbackRules => ArcPrompts.fallbackRules;
}

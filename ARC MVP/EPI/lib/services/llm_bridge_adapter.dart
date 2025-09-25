// lib/services/llm_bridge_adapter.dart
// One-liner façade for ARC prompts, built atop an injected send() call.
// This keeps UI/view models clean and future-proofs for on-device engines.
// Now with MIRA semantic memory integration.

import 'dart:convert';
import 'package:my_app/core/prompts_arc.dart';
import 'package:my_app/lumara/llm/prompt_templates.dart';
import '../mira/mira_service.dart';

typedef LLMInvocation = Future<String> Function({
  required String system,
  required String user,
  bool jsonExpected,
});

class ArcLLM {
  final LLMInvocation send;
  final MiraService? _miraService;

  ArcLLM({required this.send, MiraService? miraService})
      : _miraService = miraService;

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

    // Use LUMARA's comprehensive system prompt for chat interactions
    return send(
      system: PromptTemplates.systemPrompt,
      user: userPrompt,
      jsonExpected: false,
    );
  }

  Future<String> sageEcho(String entryText) async {
    final userPrompt = ArcPrompts.sageEcho.replaceAll('{{entry_text}}', entryText);
    final result = await send(
      system: ArcPrompts.system,
      user: userPrompt,
      jsonExpected: true,
    );

    // Store SAGE Echo result in MIRA if available
    if (_miraService != null && _miraService!.flags.miraEnabled) {
      try {
        await _miraService!.addSemanticData(
          entryText: entryText,
          sagePhases: {'sage_echo': result},
          metadata: {'source': 'sage_echo_bridge', 'timestamp': DateTime.now().toIso8601String()},
        );
      } catch (e) {
        // Continue if MIRA storage fails
      }
    }

    return result;
  }

  Future<String> arcformKeywords({
    required String entryText,
    String? sageJson,
  }) async {
    final userPrompt = ArcPrompts.arcformKeywords
        .replaceAll('{{entry_text}}', entryText)
        .replaceAll('{{sage_json}}', sageJson ?? 'null');
    final result = await send(
      system: ArcPrompts.system,
      user: userPrompt,
      jsonExpected: true,
    );

    // Store keywords in MIRA if available
    if (_miraService != null && _miraService!.flags.miraEnabled) {
      try {
        final keywordsList = _parseKeywordsFromJson(result);
        await _miraService!.addSemanticData(
          entryText: entryText,
          keywords: keywordsList,
          metadata: {'source': 'arcform_keywords_bridge', 'timestamp': DateTime.now().toIso8601String()},
        );
      } catch (e) {
        // Continue if MIRA storage fails
      }
    }

    return result;
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

  /// Helper to parse keywords from JSON response
  List<String> _parseKeywordsFromJson(String jsonResult) {
    try {
      final decoded = jsonDecode(jsonResult);
      if (decoded is Map && decoded.containsKey('keywords')) {
        final keywords = decoded['keywords'];
        if (keywords is List) {
          return keywords.map((k) => k.toString()).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}



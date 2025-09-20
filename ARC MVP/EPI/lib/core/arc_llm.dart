// lib/core/arc_llm.dart
// One-liner facade to assemble ARC prompts and call the underlying LLM client.
// Now with MIRA semantic memory integration for context-aware responses.

import 'dart:convert';
import 'prompts_arc.dart';
import '../mira/mira_service.dart';

typedef ArcSendFn = Future<String> Function({
  required String system,
  required String user,
  bool jsonExpected,
});

class ArcLLM {
  final ArcSendFn send;
  final MiraService? _miraService;

  ArcLLM({required this.send, MiraService? miraService})
      : _miraService = miraService;

  Future<String> chat({
    required String userIntent,
    String entryText = "",
    String? phaseHintJson,
    String? lastKeywordsJson,
  }) async {
    // Enhance with MIRA context if available
    String enhancedKeywords = lastKeywordsJson ?? 'null';
    if (_miraService != null && _miraService!.flags.retrievalEnabled) {
      try {
        final contextKeywords = await _miraService!.searchNarratives(userIntent, limit: 5);
        if (contextKeywords.isNotEmpty) {
          enhancedKeywords = '{"context": ${contextKeywords.map((k) => '"$k"').join(', ')}, "last": $lastKeywordsJson}';
        }
      } catch (e) {
        // Fall back to original keywords if MIRA fails
      }
    }

    final userPrompt = ArcPrompts.chat
        .replaceAll('{{user_intent}}', userIntent)
        .replaceAll('{{entry_text}}', entryText)
        .replaceAll('{{phase_hint?}}', phaseHintJson ?? 'null')
        .replaceAll('{{keywords?}}', enhancedKeywords);

    return send(system: ArcPrompts.system, user: userPrompt, jsonExpected: false);
  }

  Future<String> sageEcho(String entryText) async {
    final userPrompt = ArcPrompts.sageEcho.replaceAll('{{entry_text}}', entryText);
    final result = await send(system: ArcPrompts.system, user: userPrompt, jsonExpected: true);

    // Store SAGE Echo result in MIRA if available
    if (_miraService != null && _miraService!.flags.miraEnabled) {
      try {
        await _miraService!.addSemanticData(
          entryText: entryText,
          sagePhases: {'sage_echo': result},
          metadata: {'source': 'sage_echo', 'timestamp': DateTime.now().toIso8601String()},
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
    final result = await send(system: ArcPrompts.system, user: userPrompt, jsonExpected: true);

    // Store keywords in MIRA if available
    if (_miraService != null && _miraService!.flags.miraEnabled) {
      try {
        // Parse keywords from JSON result
        final keywordsList = _parseKeywordsFromJson(result);
        await _miraService!.addSemanticData(
          entryText: entryText,
          keywords: keywordsList,
          metadata: {'source': 'arcform_keywords', 'timestamp': DateTime.now().toIso8601String()},
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
    return send(system: ArcPrompts.system, user: userPrompt, jsonExpected: true);
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
    return send(system: ArcPrompts.system, user: userPrompt, jsonExpected: true);
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



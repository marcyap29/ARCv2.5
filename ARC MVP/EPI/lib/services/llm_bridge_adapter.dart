// lib/services/llm_bridge_adapter.dart
// One-liner façade for ARC prompts, built atop an injected send() call.
// This keeps UI/view models clean and future-proofs for on-device engines.
// Now with MIRA semantic memory integration.

import 'dart:convert';
import 'package:my_app/core/prompts_arc.dart';
import 'package:my_app/mira/mira_service.dart';

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
    bool isContinuation = false,
    String? previousAssistantReply,
  }) {
    print('ArcLLM Bridge: ===== CHAT REQUEST =====');
    print('ArcLLM Bridge: User intent: $userIntent');
    print('ArcLLM Bridge: Entry text length: ${entryText.length}');
    print('ArcLLM Bridge: Phase hint: $phaseHintJson');
    print('ArcLLM Bridge: Keywords: $lastKeywordsJson');
    
    try {
      print('ArcLLM Bridge: Building user prompt...');
      
      // Check if this is a Bible question and prioritize it
      final isBibleQuestion = userIntent.contains('[BIBLE_CONTEXT]') || userIntent.contains('[BIBLE_VERSE_CONTEXT]');
      
      var userPrompt = ArcPrompts.chat
          .replaceAll('{{user_intent}}', userIntent)
          .replaceAll('{{entry_text}}', entryText)
          .replaceAll('{{phase_hint?}}', phaseHintJson ?? 'null')
          .replaceAll('{{keywords?}}', lastKeywordsJson ?? 'null');
      
      // If Bible question, add explicit instruction at the top
      if (isBibleQuestion) {
        userPrompt = '''⚠️ CRITICAL BIBLE QUESTION DETECTED ⚠️

This is a Bible-related question. You MUST respond directly to the Bible topic mentioned in the [BIBLE_CONTEXT] block below.

DO NOT:
- Give a generic introduction like "I'm ready to assist you" or "I'm LUMARA"
- Ignore the Bible question
- Restate your role or purpose

DO:
- Read the [BIBLE_CONTEXT] block carefully
- Respond directly about the Bible topic mentioned (e.g., if it says "User is asking about Habakkuk", respond about Habakkuk)
- Use Google Search if needed to find information about the Bible topic
- Provide specific information about the Bible topic

$userPrompt''';
        print('ArcLLM Bridge: ⚠️ Bible question detected - adding critical instructions');
      }
      if (isContinuation && previousAssistantReply != null && previousAssistantReply.trim().isNotEmpty) {
        userPrompt += '''

Continuation request:
The previous assistant reply ended mid-thought. Resume exactly where it stopped without restating earlier paragraphs.

Previous assistant text:
"""
$previousAssistantReply
"""

Only write the missing continuation (2–3 sentences). No recap, no new bullet list.
''';
      }

      
      // Removed brevity constraint - EnhancedLumaraApi handles response length appropriately
      // if (isInJournalReflection) {
      //   userPrompt += '\n\nCRITICAL: This is an in-journal reflection. Respond with 1-2 sentences maximum (150 characters total). Be profound but brief.';
      //   print('ArcLLM Bridge: Added in-journal brevity constraint');
      // }
      
      print('ArcLLM Bridge: Calling send() function...');
      // Use ArcPrompts.system which includes Bible retrieval instructions
      final result = send(
        system: ArcPrompts.system,
        user: userPrompt,
        jsonExpected: false,
      );
      
      result.then((response) {
        print('ArcLLM Bridge: ✓ Send completed');
        print('ArcLLM Bridge: Response length: ${response.length}');
        print('ArcLLM Bridge: Response preview: ${response.substring(0, response.length > 100 ? 100 : response.length)}...');
      });
      
      return result;
    } catch (e) {
      print('ArcLLM Bridge: ✗✗✗ EXCEPTION in chat ✗✗✗');
      print('ArcLLM Bridge: Exception type: ${e.runtimeType}');
      print('ArcLLM Bridge: Exception: $e');
      rethrow;
    }
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



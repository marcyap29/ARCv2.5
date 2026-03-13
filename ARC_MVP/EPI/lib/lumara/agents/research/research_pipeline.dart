// lib/lumara/agents/research/research_pipeline.dart
//
// Phase 3 Research Pipeline: brave-search → semantic-scholar → gemini-flash synthesis.
// All plugin calls via PrismService.authoriseAndCall(). Returns ContentBrief.
// Graceful degradation when search plugins fail.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:my_app/services/swarmspace/prism_service.dart';
import 'package:my_app/services/swarmspace/swarmspace_client.dart';

import 'content_brief.dart';
import 'research_models.dart';

/// User-friendly message when the full pipeline fails.
const String kPipelineFailureMessage =
    "Couldn't complete research. Try a different query or check your connection.";

/// Callback for per-stage progress (UI: "Searching web...", etc.).
typedef PipelineStageCallback = void Function(String stage);

/// For tests: inject a custom invoker. If null, uses [PrismService.instance.authoriseAndCall].
typedef PipelineInvoker = Future<PrismCallResult> Function(
  String pluginId,
  Map<String, dynamic> params,
);

/// Runs the three-stage research pipeline and returns a [ContentBrief].
/// All plugin calls go through [PrismService.authoriseAndCall] unless [invoker] is provided (for tests).
/// Returns null on total failure; if [errorOut] is provided, sets errorOut[0] to a user-friendly message.
Future<ContentBrief?> runResearchPipeline({
  required String query,
  BuildContext? context,
  PipelineStageCallback? onStage,
  List<String>? errorOut,
  PipelineInvoker? invoker,
  /// Optional context from a scanned document (Phase 4); prepended to synthesis.
  String? documentContext,
}) async {
  void setError(String msg) {
    if (errorOut != null) {
      errorOut.clear();
      errorOut.add(msg);
    }
  }

  Future<PrismCallResult> callPlugin(String pluginId, Map<String, dynamic> params) {
    if (invoker != null) return invoker!(pluginId, params);
    return PrismService.instance.authoriseAndCall(
      pluginId: pluginId,
      params: params,
      context: context,
    );
  }

  List<SearchSnippet> webSnippets = [];
  List<SourceRef> academicSources = [];

  // ── Step 1: Brave Search ─────────────────────────────────────────────────
  onStage?.call('Searching web...');
  final braveResult = await callPlugin('brave-search', {'query': query, 'count': 8});
  if (!braveResult.isDenied && braveResult.result != null && braveResult.result!.success) {
    final data = braveResult.result!.data;
    if (data != null) {
      final webResults = data['web']?['results'] as List<dynamic>? ??
          data['results'] as List<dynamic>? ??
          [];
      for (final r in webResults) {
        final map = r as Map<String, dynamic>;
        webSnippets.add(SearchSnippet(
          title: map['title'] as String? ?? '',
          snippet: map['description'] as String? ?? '',
          url: map['url'] as String? ?? '',
          domain: 'web',
        ));
      }
    }
  }

  // ── Step 2: Semantic Scholar ─────────────────────────────────────────────
  onStage?.call('Checking academic sources...');
  final scholarResult = await callPlugin('semantic-scholar', {'query': query, 'limit': 5});
  if (!scholarResult.isDenied && scholarResult.result != null && scholarResult.result!.success) {
    final data = scholarResult.result!.data;
    if (data != null) {
      final papers = data['data'] as List<dynamic>? ??
          data['results'] as List<dynamic>? ??
          data['papers'] as List<dynamic>? ??
          [];
      for (final p in papers) {
        final map = p as Map<String, dynamic>;
        final title = map['title'] as String? ?? map['paperId'] as String? ?? '';
        final url = map['url'] as String? ??
            (map['paperId'] != null
                ? 'https://www.semanticscholar.org/paper/${map['paperId']}'
                : '');
        if (title.isNotEmpty || url.isNotEmpty) {
          academicSources.add(SourceRef(
            title: title,
            url: url,
            domain: 'semanticscholar',
          ));
        }
      }
    }
  }

  // ── Step 3: Gemini Flash synthesis ───────────────────────────────────────
  onStage?.call('Synthesising...');
  final contextForSynthesis = _buildSynthesisContext(
    query: query,
    webSnippets: webSnippets,
    academicSources: academicSources,
    documentContext: documentContext,
  );

  final geminiResult = await callPlugin('gemini-flash', {
    'system': _synthesisSystemPrompt,
    'user': contextForSynthesis,
    'max_tokens': 1500,
    'temperature': 0.4,
  });

  if (geminiResult.isDenied || geminiResult.result == null || !geminiResult.result!.success) {
    final specificError = geminiResult.result?.error;
    setError(
      (specificError != null && specificError.trim().isNotEmpty)
          ? specificError
          : kPipelineFailureMessage,
    );
    return null;
  }

  final geminiData = geminiResult.result!.data;
  final rawText = geminiData?['text'] as String? ??
      geminiData?['content'] as String? ??
      _extractTextFromCandidates(geminiData) ??
      '';

  final brief = _parseSynthesisToBrief(
    query: query,
    rawText: rawText.trim(),
    webSnippets: webSnippets,
    academicSources: academicSources,
  );
  if (brief != null) return brief;

  // Fallback: minimal brief from query only
  return ContentBrief(
    title: query,
    summary: rawText.isNotEmpty
        ? rawText
        : 'No synthesis could be generated. Try rephrasing your question.',
    keyPoints: [],
    sources: [
      ...webSnippets.map((s) => SourceRef(title: s.title, url: s.url, domain: s.domain ?? '')),
      ...academicSources,
    ],
    createdAt: DateTime.now(),
    query: query,
  );
}


String _buildSynthesisContext({
  required String query,
  required List<SearchSnippet> webSnippets,
  required List<SourceRef> academicSources,
  String? documentContext,
}) {
  final buf = StringBuffer();
  buf.writeln('Research question: $query');
  buf.writeln();
  if (documentContext != null && documentContext.trim().isNotEmpty) {
    buf.writeln('Additional context from user\'s scanned document:');
    buf.writeln(documentContext.trim());
    buf.writeln();
  }
  if (webSnippets.isNotEmpty) {
    buf.writeln('Web snippets:');
    for (final s in webSnippets.take(12)) {
      buf.writeln('- ${s.title}: ${s.snippet} (${s.url})');
    }
    buf.writeln();
  }
  if (academicSources.isNotEmpty) {
    buf.writeln('Academic sources:');
    for (final a in academicSources.take(8)) {
      buf.writeln('- ${a.title} (${a.url})');
    }
  }
  if (webSnippets.isEmpty && academicSources.isEmpty) {
    buf.writeln('No search results available. Provide a short summary and 1–2 key points based on general knowledge.');
  }
  buf.writeln();
  buf.writeln(
    'Respond with a JSON object only (no markdown, no code fence), with keys: "summary" (string), "keyPoints" (array of strings), "title" (string, short title for the brief). Use the "sources" from the snippets above; you may include a "sources" array of objects with "title", "url", "domain".');
  return buf.toString();
}

const String _synthesisSystemPrompt = '''
You are a research synthesizer. Given a research question and web/academic snippets, produce a brief JSON object:
- title: short title for the brief (one line)
- summary: 2–4 sentence summary
- keyPoints: array of 3–6 bullet points (strings)
- sources: array of { "title", "url", "domain" } from the provided snippets (include at least the most relevant). Output only valid JSON, no markdown.''';

String? _extractTextFromCandidates(Map<String, dynamic>? data) {
  if (data == null) return null;
  final candidates = data['candidates'] as List?;
  if (candidates == null || candidates.isEmpty) return null;
  final first = candidates.first as Map<String, dynamic>?;
  final content = first?['content'] as Map<String, dynamic>?;
  final parts = content?['parts'] as List?;
  if (parts == null || parts.isEmpty) return null;
  final part = parts.first as Map<String, dynamic>?;
  return part?['text'] as String?;
}

ContentBrief? _parseSynthesisToBrief({
  required String query,
  required String rawText,
  required List<SearchSnippet> webSnippets,
  required List<SourceRef> academicSources,
}) {
  String? summary;
  List<String> keyPoints = [];
  String title = query;
  List<SourceRef> sources = [...academicSources];
  sources.addAll(
    webSnippets.map((s) => SourceRef(title: s.title, url: s.url, domain: s.domain ?? '')),
  );

  // Try to parse JSON from the response (may be wrapped in markdown)
  String jsonStr = rawText.trim();
  final codeBlock = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
  final match = codeBlock.firstMatch(jsonStr);
  if (match != null) jsonStr = match.group(1)?.trim() ?? jsonStr;

  try {
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>?;
    if (decoded != null) {
      summary = decoded['summary'] as String?;
      title = decoded['title'] as String? ?? query;
      final kp = decoded['keyPoints'] as List<dynamic>?;
      if (kp != null) keyPoints = kp.map((e) => e.toString()).toList();
      final src = decoded['sources'] as List<dynamic>?;
      if (src != null && src.isNotEmpty) {
        sources = src
            .map((e) => SourceRef.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }
  } catch (_) {
    summary = rawText;
  }

  if (summary == null || summary.isEmpty) return null;
  return ContentBrief(
    title: title,
    summary: summary,
    keyPoints: keyPoints,
    sources: sources,
    createdAt: DateTime.now(),
    query: query,
  );
}

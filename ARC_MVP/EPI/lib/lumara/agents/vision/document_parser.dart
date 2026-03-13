// lib/lumara/agents/vision/document_parser.dart
//
// Phase 4: OCR (vision-ocr) + structured extraction (gemini-flash).
// All plugin calls via PrismService.authoriseAndCall().

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/services/swarmspace/prism_service.dart';

import 'parsed_document.dart';

/// User-friendly message when document parsing fails.
const String kDocumentParserFailureMessage =
    "Couldn't read the document. Try a clearer image or a different file.";

/// Optional invoker for tests (same pattern as research_pipeline).
typedef DocumentParserInvoker = Future<PrismCallResult> Function(
  String pluginId,
  Map<String, dynamic> params,
);

/// Runs OCR on [image] then extracts structured fields via Gemini.
/// Returns [ParsedDocument]. On failure returns a document with empty rawText and keyFields.
/// [context] required for PRISM (vision-ocr is STRUCTURED_PERSONAL).
Future<ParsedDocument> parseDocument({
  required XFile image,
  required BuildContext context,
  DocumentParserInvoker? invoker,
  List<String>? errorOut,
}) async {
  void setError(String msg) {
    if (errorOut != null) {
      errorOut.clear();
      errorOut.add(msg);
    }
  }

  Future<PrismCallResult> callPlugin(String pluginId, Map<String, dynamic> params) {
    if (invoker != null) return invoker(pluginId, params);
    return PrismService.instance.authoriseAndCall(
      pluginId: pluginId,
      params: params,
      context: context,
    );
  }

  final bytes = await image.readAsBytes();
  final imageB64 = base64Encode(bytes);

  // Step 1: vision-ocr with mode 'ocr'
  final ocrResult = await callPlugin('vision-ocr', {
    'image_b64': imageB64,
    'mode': 'ocr',
  });

  String rawText = '';
  if (!ocrResult.isDenied && ocrResult.result != null && ocrResult.result!.success) {
    final data = ocrResult.result!.data;
    rawText = (data?['text'] as String?)?.trim() ?? '';
  }

  if (rawText.isEmpty) {
    return ParsedDocument(
      rawText: '',
      keyFields: const [],
      createdAt: DateTime.now(),
    );
  }

  // Step 2: gemini-flash for structured JSON
  const systemPrompt = '''
You are a document structure extractor. Given raw OCR text from a document or screenshot, output a JSON object with:
- title: string or null (document title if evident)
- date: string or null (date if evident, any format)
- keyFields: array of { "label": string, "value": string } for important fields (e.g. "Name", "Date", "Amount")
- rawText: the original OCR text (pass through)
Output only valid JSON, no markdown.''';

  final userPrompt = 'Extract structure from this OCR text:\n\n$rawText';

  final geminiResult = await callPlugin('gemini-flash', {
    'system': systemPrompt,
    'user': userPrompt,
    'max_tokens': 1500,
    'temperature': 0.2,
  });

  if (geminiResult.isDenied || geminiResult.result == null || !geminiResult.result!.success) {
    setError(kDocumentParserFailureMessage);
    return ParsedDocument(rawText: rawText, keyFields: const [], createdAt: DateTime.now());
  }

  final data = geminiResult.result!.data;
  final rawResponse = data?['text'] as String? ??
      data?['content'] as String? ??
      _extractTextFromCandidates(data) ??
      '';

  final parsed = _parseStructuredResponse(rawResponse.trim(), rawText);
  return parsed ?? ParsedDocument(rawText: rawText, keyFields: const [], createdAt: DateTime.now());
}

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

ParsedDocument? _parseStructuredResponse(String raw, String fallbackRawText) {
  String jsonStr = raw;
  final codeBlock = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
  final match = codeBlock.firstMatch(jsonStr);
  if (match != null) jsonStr = match.group(1)?.trim() ?? jsonStr;

  try {
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>?;
    if (decoded == null) return null;
    final keyFieldsRaw = decoded['keyFields'] as List<dynamic>? ?? [];
    final keyFields = keyFieldsRaw
        .map((e) => DocumentField.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return ParsedDocument(
      title: decoded['title'] as String?,
      date: decoded['date'] as String?,
      keyFields: keyFields,
      rawText: decoded['rawText'] as String? ?? fallbackRawText,
      createdAt: DateTime.now(),
    );
  } catch (_) {
    return null;
  }
}

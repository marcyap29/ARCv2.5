// lib/arc/outputs/output_tagging.dart
//
// Phase 5a: Document type classifier and auto-tag generation (path + content).

import 'package:my_app/arc/outputs/outputs_models.dart';
import 'package:my_app/lumara/agents/research/content_brief.dart';
import 'package:my_app/lumara/agents/vision/parsed_document.dart';

/// Detected document type from ParsedDocument (keyword-based, no API).
String detectDocumentType(ParsedDocument doc) {
  final text = _fieldsText(doc).toLowerCase();
  final labels = doc.keyFields.map((f) => f.label.toLowerCase()).join(' ');
  final combined = '$text $labels';

  if (_matches(combined, ['receipt', 'subtotal', 'tax', 'paid'])) return 'receipt';
  if (_matches(combined, ['total', 'amount', 'invoice', 'due date'])) return 'invoice';
  if (_matches(combined, ['name', 'email', 'phone', 'title', 'company'])) return 'business_card';
  if (_matches(combined, ['agreement', 'party', 'clause', 'signature', 'term'])) return 'contract';
  if (_matches(combined, ['patient', 'diagnosis', 'medication', 'physician'])) return 'medical';
  if (_matches(combined, ['form', 'checkbox', 'field', 'please complete'])) return 'form';
  return 'unknown';
}

String _fieldsText(ParsedDocument doc) {
  return doc.keyFields.map((f) => '${f.label} ${f.value}').join(' ').toLowerCase();
}

bool _matches(String text, List<String> keywords) {
  return keywords.any((k) => text.contains(k));
}

const Set<String> _stopwords = {
  'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'from',
  'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did',
  'will', 'would', 'could', 'should', 'may', 'might', 'must', 'can', 'this', 'that', 'these', 'those',
  'it', 'its', 'as', 'so', 'if', 'when', 'what', 'which', 'who', 'how', 'why',
};

/// Path-derived auto-tags from agentKey + folderKey (lowercase, no spaces).
/// Scanner items always use ["scanner", "scans"].
List<String> pathTags(String agentKey, String folderKey) {
  final a = agentKey.toLowerCase().trim();
  if (a.isEmpty) return [];
  if (a == 'scanner') return ['scanner', 'scans'];
  final f = folderKey.toLowerCase().trim();
  if (f.isEmpty || f == a) return [a];
  return [a, f];
}

/// Content-derived auto-tags for Research: up to 3 topic keywords from ContentBrief.title.
List<String> contentTagsFromBrief(ContentBrief brief) {
  final words = brief.title
      .toLowerCase()
      .split(RegExp(r'[\s,;.!?\-:]+'))
      .where((w) => w.length > 1 && !_stopwords.contains(w))
      .toList();
  return words.take(3).toList();
}

/// Content-derived auto-tags for Scanner: company/org from ParsedDocument fields.
List<String> contentTagsFromParsedDocument(ParsedDocument doc, String documentType) {
  final tags = <String>[];
  if (documentType != 'unknown') tags.add(documentType);
  for (final f in doc.keyFields) {
    final label = f.label.toLowerCase();
    if (label.contains('company') || label.contains('from') ||
        label.contains('vendor') || label.contains('employer')) {
      final v = f.value.trim();
      if (v.isNotEmpty && v.length <= 50) tags.add(v.toLowerCase().replaceAll(RegExp(r'\s+'), '-'));
    }
  }
  return tags;
}

/// Normalise user tag input: lowercase, spaces → hyphens, max length 30.
String normaliseUserTag(String input) {
  var s = input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
  if (s.length > 30) s = s.substring(0, 30);
  return s;
}

const int maxUserTagsPerItem = 20;

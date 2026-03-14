// lib/lumara/agents/vision/parsed_document.dart
//
// Phase 4: Result of document parser (OCR + structured extraction).

/// A single key-value field extracted from a document.
class DocumentField {
  final String label;
  final String value;

  const DocumentField({required this.label, required this.value});

  Map<String, dynamic> toJson() => {'label': label, 'value': value};

  factory DocumentField.fromJson(Map<String, dynamic> json) {
    return DocumentField(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }
}

/// Parsed document: title, date, key fields, raw OCR text.
class ParsedDocument {
  final String? title;
  final String? date;
  final List<DocumentField> keyFields;
  final String rawText;
  final DateTime createdAt;

  const ParsedDocument({
    this.title,
    this.date,
    this.keyFields = const [],
    required this.rawText,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'date': date,
        'key_fields': keyFields.map((f) => f.toJson()).toList(),
        'raw_text': rawText,
        'created_at': createdAt.toIso8601String(),
      };

  factory ParsedDocument.fromJson(Map<String, dynamic> json) {
    final fieldsRaw = json['key_fields'] as List<dynamic>? ?? [];
    return ParsedDocument(
      title: json['title'] as String?,
      date: json['date'] as String?,
      keyFields: fieldsRaw
          .map((e) => DocumentField.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      rawText: json['raw_text'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Parses lines like "Label: value" or "Label:" from [rawText] into keyFields.
  /// Use when OCR returns plain text (e.g. form scan) so "Use to fill form" can work.
  static List<DocumentField> parseKeyFieldsFromRawText(String rawText) {
    final fields = <DocumentField>[];
    final linePattern = RegExp(r'^\s*(.+?)\s*:\s*(.*)\s*$');
    for (final line in rawText.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final match = linePattern.firstMatch(trimmed);
      if (match != null) {
        final label = match.group(1)?.trim() ?? '';
        if (label.isNotEmpty) {
          fields.add(DocumentField(
            label: label,
            value: match.group(2)?.trim() ?? '',
          ));
        }
      }
    }
    return fields;
  }
}

/// Minimal DOCX export using archive package (no new dependencies).
/// Generates OOXML-compliant .docx that Word, Google Docs, LibreOffice can open.
library;

import 'dart:convert';

import 'package:archive/archive.dart';

import 'package:my_app/lumara/agents/models/research_models.dart';

/// Build DOCX bytes from a research report. Uses archive 3.x for ZIP creation.
List<int> buildDocxBytes(ResearchReport report) {
  final body = _buildDocumentBody(report);
  final archive = Archive();

  void addFile(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  addFile('[Content_Types].xml', _contentTypes);
  addFile('_rels/.rels', _rels);
  addFile('word/_rels/document.xml.rels', _documentRels);
  addFile('word/document.xml', _documentXml(body));
  addFile('docProps/core.xml', _coreXml(report));
  addFile('docProps/app.xml', _appXml);
  addFile('word/styles.xml', _stylesXml);

  return ZipEncoder().encode(archive) ?? [];
}

String _xmlEscape(String s) {
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

String _paragraph(String text) {
  if (text.trim().isEmpty) return '';
  final escaped = _xmlEscape(text);
  return '<w:p><w:r><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>';
}

String _heading(String text, int level) {
  final escaped = _xmlEscape(text);
  final style = level == 1 ? 'Heading1' : (level == 2 ? 'Heading2' : 'Heading3');
  return '<w:p><w:pPr><w:pStyle w:val="$style"/></w:pPr><w:r><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>';
}

String _buildDocumentBody(ResearchReport report) {
  final buf = StringBuffer();
  final dateStr = _formatDate(report.generatedAt);

  buf.write(_heading(report.query, 1));
  buf.write(_paragraph('$dateStr · ${report.phase.name} Phase'));
  buf.write(_paragraph(''));

  buf.write(_heading('Summary', 2));
  buf.write(_paragraph(report.summary));
  buf.write(_paragraph(''));

  if (report.detailedFindings.trim().isNotEmpty) {
    buf.write(_heading('Detailed Findings', 2));
    for (final line in report.detailedFindings.split('\n')) {
      buf.write(_paragraph(line));
    }
    buf.write(_paragraph(''));
  }

  if (report.strategicImplications.trim().isNotEmpty) {
    buf.write(_heading('Strategic Implications', 2));
    for (final line in report.strategicImplications.split('\n')) {
      buf.write(_paragraph(line));
    }
    buf.write(_paragraph(''));
  }

  if (report.keyInsights.isNotEmpty) {
    buf.write(_heading('Key Insights', 2));
    for (var i = 0; i < report.keyInsights.length; i++) {
      final k = report.keyInsights[i];
      buf.write(_paragraph('${i + 1}. ${k.statement}'));
      buf.write(_paragraph(k.evidence));
    }
    buf.write(_paragraph(''));
  }

  if (report.nextSteps.isNotEmpty) {
    buf.write(_heading('Recommended Next Steps', 2));
    for (final s in report.nextSteps) {
      buf.write(_paragraph('• $s'));
    }
    buf.write(_paragraph(''));
  }

  if (report.citations.isNotEmpty) {
    buf.write(_heading('Sources', 2));
    for (final c in report.citations) {
      buf.write(_paragraph('[${c.id}] ${c.title} — ${c.source}'));
      if (c.url.isNotEmpty) buf.write(_paragraph('  ${c.url}'));
    }
  }

  return buf.toString();
}

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

const String _contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>''';

const String _rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''';

const String _documentRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

String _documentXml(String body) {
  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
$body
<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr>
</w:body>
</w:document>''';
}

String _coreXml(ResearchReport report) {
  final created = report.generatedAt.toUtc().toIso8601String();
  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties">
<dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">${_xmlEscape(report.query)}</dc:title>
<dcterms:created xmlns:dcterms="http://purl.org/dc/terms/">$created</dcterms:created>
</cp:coreProperties>''';
}

String _coreXmlForTitle(String title, DateTime createdAt) {
  final created = createdAt.toUtc().toIso8601String();
  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties">
<dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">${_xmlEscape(title)}</dc:title>
<dcterms:created xmlns:dcterms="http://purl.org/dc/terms/">$created</dcterms:created>
</cp:coreProperties>''';
}

String _stripInlineMd(String s) {
  var o = s;
  o = o.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1)!);
  o = o.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m.group(1)!);
  o = o.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1)!);
  return o;
}

/// Map markdown-ish lines to Word paragraphs/headings (## / ### / bullets).
String _documentBodyFromMarkdown(String markdown) {
  final buf = StringBuffer();
  final heading = RegExp(r'^(#{1,6})\s+(.+)$');
  for (final rawLine in markdown.split('\n')) {
    final line = rawLine.trimRight();
    final t = _stripInlineMd(line.trimLeft());
    if (t.isEmpty) {
      buf.write(_paragraph(''));
      continue;
    }
    final m = heading.firstMatch(t);
    if (m != null) {
      final level = m.group(1)!.length;
      final text = _stripInlineMd(m.group(2)!.trim());
      final h = level <= 1 ? 1 : (level == 2 ? 2 : 3);
      buf.write(_heading(text, h));
      continue;
    }
    if (t.startsWith('> ')) {
      final quoted = _stripInlineMd(t.substring(2).trim());
      buf.write(_paragraph(quoted));
      continue;
    }
    if (t.startsWith('- ') || t.startsWith('* ')) {
      buf.write(_paragraph('• ${_stripInlineMd(t.substring(2).trim())}'));
      continue;
    }
    buf.write(_paragraph(t));
  }
  return buf.toString();
}

/// DOCX from a workflow research markdown body (headings and bullets preserved).
/// When [prependTitleAndDate] is false, [markdown] should include its own title (e.g. `# Research report`).
List<int> buildDocxFromMarkdownExport({
  required String title,
  required DateTime createdAt,
  required String markdown,
  bool prependTitleAndDate = true,
}) {
  final body = StringBuffer();
  if (prependTitleAndDate) {
    body.write(_heading(title, 1));
    body.write(_paragraph(_formatDate(createdAt)));
    body.write(_paragraph(''));
  }
  body.write(_documentBodyFromMarkdown(markdown));

  final archive = Archive();

  void addFile(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  addFile('[Content_Types].xml', _contentTypes);
  addFile('_rels/.rels', _rels);
  addFile('word/_rels/document.xml.rels', _documentRels);
  addFile('word/document.xml', _documentXml(body.toString()));
  addFile('docProps/core.xml', _coreXmlForTitle(title, createdAt));
  addFile('docProps/app.xml', _appXml);
  addFile('word/styles.xml', _stylesXml);

  return ZipEncoder().encode(archive) ?? [];
}

const String _appXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
<Application>LUMARA</Application>
</Properties>''';

const String _stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/></w:rPr></w:rPrDefault></w:docDefaults>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="Heading 1"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="240"/></w:pPr><w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="Heading 2"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:before="120"/></w:pPr><w:rPr><w:b/><w:sz w:val="24"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="Heading 3"/><w:basedOn w:val="Normal"/><w:rPr><w:b/><w:sz w:val="22"/></w:rPr></w:style>
</w:styles>''';

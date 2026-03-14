/// Export completed forms (Outputs → Completed Forms) as PDF or DOCX.
/// Uses same PDF/DOCX approach as report_export_service for consistency.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// One form field (label + value).
class FormFieldExport {
  final String label;
  final String value;

  const FormFieldExport({required this.label, required this.value});
}

enum CompletedFormExportFormat { pdf, docx }

class CompletedFormExportService {
  CompletedFormExportService._();
  static final CompletedFormExportService instance = CompletedFormExportService._();

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _safeFileName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').replaceAll(RegExp(r'\s+'), '_');
  }

  /// Build PDF bytes for a completed form.
  Future<List<int>> toPdfBytes({
    required String title,
    required DateTime createdAt,
    required List<FormFieldExport> fields,
  }) async {
    final doc = pw.Document();
    final widgets = <pw.Widget>[
      pw.Header(
        level: 0,
        child: pw.Text(
          title,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Paragraph(
        text: _formatDate(createdAt),
        style: const pw.TextStyle(fontSize: 10),
      ),
      pw.SizedBox(height: 16),
    ];
    for (final f in fields) {
      widgets.add(pw.Paragraph(
        text: f.label,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
      ));
      widgets.add(pw.Paragraph(text: f.value.isEmpty ? '—' : f.value));
      widgets.add(pw.SizedBox(height: 10));
    }
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => widgets,
      ),
    );
    return doc.save();
  }

  static String _xmlEscape(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _paragraph(String text) {
    if (text.trim().isEmpty) return '';
    final escaped = _xmlEscape(text);
    return '<w:p><w:r><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>';
  }

  static String _heading(String text, int level) {
    final escaped = _xmlEscape(text);
    final style = level == 1 ? 'Heading1' : (level == 2 ? 'Heading2' : 'Heading3');
    return '<w:p><w:pPr><w:pStyle w:val="$style"/></w:pPr><w:r><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>';
  }

  /// Build DOCX bytes for a completed form (OOXML, same structure as docx_export_helper).
  List<int> toDocxBytes({
    required String title,
    required DateTime createdAt,
    required List<FormFieldExport> fields,
  }) {
    final buf = StringBuffer();
    buf.write(_heading(title, 1));
    buf.write(_paragraph(_formatDate(createdAt)));
    buf.write(_paragraph(''));
    for (final f in fields) {
      buf.write(_paragraph(f.label));
      buf.write(_paragraph(f.value.isEmpty ? '—' : f.value));
      buf.write(_paragraph(''));
    }
    final body = buf.toString();
    const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>''';
    const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''';
    const documentRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
$body
<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr>
</w:body>
</w:document>''';
    final created = createdAt.toUtc().toIso8601String();
    final coreXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties">
<dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">${_xmlEscape(title)}</dc:title>
<dcterms:created xmlns:dcterms="http://purl.org/dc/terms/">$created</dcterms:created>
</cp:coreProperties>''';
    const appXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
<Application>LUMARA</Application>
</Properties>''';
    const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/></w:rPr></w:rPrDefault></w:docDefaults>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="Heading 1"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="240"/></w:pPr><w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="Heading 2"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:before="120"/></w:pPr><w:rPr><w:b/><w:sz w:val="24"/></w:rPr></w:style>
</w:styles>''';
    final archive = Archive();
    void addFile(String p, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(p, bytes.length, bytes));
    }
    addFile('[Content_Types].xml', contentTypes);
    addFile('_rels/.rels', rels);
    addFile('word/_rels/document.xml.rels', documentRels);
    addFile('word/document.xml', documentXml);
    addFile('docProps/core.xml', coreXml);
    addFile('docProps/app.xml', appXml);
    addFile('word/styles.xml', stylesXml);
    return ZipEncoder().encode(archive) ?? [];
  }

  /// Export to file and return path; then caller can share. Returns null on failure.
  Future<String?> exportToFile({
    required String title,
    required DateTime createdAt,
    required List<FormFieldExport> fields,
    required CompletedFormExportFormat format,
  }) async {
    try {
      final base = _safeFileName(title);
      final baseName = base.length > 60 ? base.substring(0, 57) : base;
      final dir = await getTemporaryDirectory();
      if (format == CompletedFormExportFormat.pdf) {
        final bytes = await toPdfBytes(title: title, createdAt: createdAt, fields: fields);
        final file = File(path.join(dir.path, '$baseName.pdf'));
        await file.writeAsBytes(bytes);
        return file.path;
      } else {
        final bytes = toDocxBytes(title: title, createdAt: createdAt, fields: fields);
        final file = File(path.join(dir.path, '$baseName.docx'));
        await file.writeAsBytes(bytes);
        return file.path;
      }
    } catch (_) {
      return null;
    }
  }

  /// Export and open system share sheet. Returns true if share was triggered.
  Future<bool> exportAndShare({
    required String title,
    required DateTime createdAt,
    required List<FormFieldExport> fields,
    required CompletedFormExportFormat format,
  }) async {
    final filePath = await exportToFile(
      title: title,
      createdAt: createdAt,
      fields: fields,
      format: format,
    );
    if (filePath == null) return false;
    final ext = format == CompletedFormExportFormat.pdf ? 'pdf' : 'docx';
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: title,
      text: 'Completed form exported as .$ext',
    );
    return true;
  }
}

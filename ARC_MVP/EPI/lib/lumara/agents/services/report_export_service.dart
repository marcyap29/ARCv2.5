/// Report Export Service
///
/// Exports research reports and writings as .md, .pdf. Supports save to device,
/// share (email, Dropbox via system share), and Google Drive upload.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:my_app/lumara/agents/models/research_models.dart';
import 'package:my_app/lumara/agents/research/content_brief.dart';
import 'package:my_app/lumara/agents/services/docx_export_helper.dart';
import 'package:my_app/services/google_drive_service.dart';

/// Format for export.
enum ReportExportFormat { markdown, pdf, docx, plainText }

/// Destination for export.
enum ReportExportDestination { device, share, googleDrive }

class ReportExportService {
  ReportExportService._();
  static final ReportExportService instance = ReportExportService._();

  /// Build an ATLAS [ResearchReport] from a saved [ContentBrief] (Outputs tab) for export/share.
  /// Full detailed findings are not stored in the brief; key points map to abstract bullets.
  ResearchReport reportFromContentBrief(ContentBrief brief, {required String id}) {
    final query = brief.query.trim().isNotEmpty ? brief.query : brief.title;
    final citations = <ResearchCitation>[];
    for (var i = 0; i < brief.sources.length; i++) {
      final s = brief.sources[i];
      citations.add(ResearchCitation(
        id: i + 1,
        title: s.title.isNotEmpty ? s.title : s.url,
        source: s.domain.isNotEmpty ? s.domain : 'web',
        url: s.url,
      ));
    }
    return ResearchReport(
      id: id,
      query: query,
      abstractBullets: List<String>.from(brief.keyPoints),
      summary: brief.summary,
      detailedFindings: '',
      keyInsights: const [],
      citations: citations,
      generatedAt: brief.createdAt,
    );
  }

  /// Build markdown string from report (saves space; used as base for .md export).
  String toMarkdown(ResearchReport report) {
    final buf = StringBuffer();
    buf.writeln('# ${report.query}');
    buf.writeln();
    buf.writeln('*${_formatDate(report.generatedAt)}*');
    buf.writeln();
    if (report.abstractBullets.isNotEmpty) {
      buf.writeln('## Abstract');
      buf.writeln();
      for (final b in report.abstractBullets) {
        buf.writeln('- $b');
      }
      buf.writeln();
    }
    buf.writeln('## Summary');
    buf.writeln();
    buf.writeln(report.summary);
    if (report.detailedFindings.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('## Detailed Findings');
      buf.writeln();
      buf.writeln(report.detailedFindings);
    }
    if (report.strategicImplications.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('## Strategic Implications');
      buf.writeln();
      buf.writeln(report.strategicImplications);
    }
    if (report.keyInsights.isNotEmpty) {
      buf.writeln();
      buf.writeln('## Key Insights');
      buf.writeln();
      for (var i = 0; i < report.keyInsights.length; i++) {
        final k = report.keyInsights[i];
        buf.writeln('### ${i + 1}. ${k.statement}');
        buf.writeln();
        buf.writeln(k.evidence);
        if (k.citationIds.isNotEmpty) {
          buf.writeln('*Citations: ${k.citationIds.map((id) => '[$id]').join(', ')}*');
        }
        buf.writeln();
      }
    }
    if (report.nextSteps.isNotEmpty) {
      buf.writeln('## Recommended Next Steps');
      buf.writeln();
      for (final s in report.nextSteps) {
        buf.writeln('- $s');
      }
    }
    if (report.citations.isNotEmpty) {
      buf.writeln();
      buf.writeln('## Sources');
      buf.writeln();
      for (final c in report.citations) {
        buf.writeln('- **[${c.id}]** ${c.title} — ${c.source}');
        if (c.url.isNotEmpty) buf.writeln('  ${c.url}');
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

  /// Prepare workflow markdown for export (matches on-screen Markdown preview more closely).
  String normalizeWorkflowMarkdownForExport(String markdown) {
    var t = markdown.trim();
    t = t.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    t = t.replaceAll(RegExp(r'</p>\s*<p[^>]*>', caseSensitive: false), '\n\n');
    t = t.replaceAll(RegExp(r'<[^>]+>'), '');
    final fence = RegExp(
      r'^```(?:\w+)?\s*\r?\n([\s\S]*?)\r?\n```\s*$',
      multiLine: false,
    );
    final m = fence.firstMatch(t);
    if (m != null) {
      t = m.group(1)!.trim();
    }
    return t;
  }

  /// Structured markdown: original question (blockquote) + normalized report — for .md / PDF / DOCX / share.
  String composeResearchWorkflowMarkdown({
    required String userQuestion,
    required String reportMarkdown,
    required DateTime createdAt,
  }) {
    final report = normalizeWorkflowMarkdownForExport(reportMarkdown);
    final qLines = userQuestion.trim().split('\n');
    final buf = StringBuffer();
    buf.writeln('# Research report');
    buf.writeln();
    buf.writeln('*${_formatDate(createdAt)}*');
    buf.writeln();
    buf.writeln('## Your question');
    buf.writeln();
    if (qLines.isEmpty || (qLines.length == 1 && qLines.first.trim().isEmpty)) {
      buf.writeln('> _No question text._');
    } else {
      for (final line in qLines) {
        buf.writeln('> $line');
      }
    }
    buf.writeln();
    buf.writeln('## Report');
    buf.writeln();
    buf.writeln(report.isEmpty ? '_No report body._' : report);
    return buf.toString();
  }

  /// Inserts soft breaks in very long tokens (URLs) so PDF layout does not overflow.
  String softBreakLongWords(String s, int maxChunk) {
    final words = s.split(RegExp(r'\s+'));
    final out = StringBuffer();
    for (final w in words) {
      if (w.isEmpty) continue;
      if (w.length <= maxChunk) {
        out.write('$w ');
        continue;
      }
      for (var i = 0; i < w.length; i += maxChunk) {
        final end = math.min(i + maxChunk, w.length);
        out.write(w.substring(i, end));
        if (end < w.length) out.write('\u200B');
      }
      out.write(' ');
    }
    return out.toString().trim();
  }

  /// Remove common inline markdown markers for PDF/DOCX plain rendering.
  String stripInlineMarkdownForExportLine(String line) {
    var s = line;
    s = s.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1)!);
    s = s.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m.group(1)!);
    s = s.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1)!);
    return s;
  }

  /// Sanitize filename (remove invalid chars).
  String _safeFileName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').replaceAll(RegExp(r'\s+'), '_');
  }

  /// Create a temporary file with the given content and extension.
  Future<File> _writeToTempFile(String content, String ext) async {
    final dir = await getTemporaryDirectory();
    final base = _safeFileName(DateTime.now().millisecondsSinceEpoch.toString());
    final file = File(path.join(dir.path, '$base.$ext'));
    await file.writeAsString(content, encoding: utf8);
    return file;
  }

  /// Create PDF bytes from report.
  Future<List<int>> toPdfBytes(ResearchReport report) async {
    final doc = pw.Document();
    final body = _toPdfBody(report);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => body,
      ),
    );
    return doc.save();
  }

  pw.Widget _pdfBulletBlock(List<String> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items.map((text) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 14,
                child: pw.Text('•', style: const pw.TextStyle(fontSize: 11)),
              ),
              pw.Expanded(
                child: pw.Text(text, style: const pw.TextStyle(fontSize: 11)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Renders workflow research markdown (## headings, bullets, blockquotes) into PDF widgets.
  List<pw.Widget> _pdfWidgetsFromMarkdown(String markdown) {
    final out = <pw.Widget>[];
    final lines = markdown.split('\n');
    final heading = RegExp(r'^(#{1,6})\s+(.+)$');
    var i = 0;
    while (i < lines.length) {
      final rawLine = lines[i];
      final t = stripInlineMarkdownForExportLine(rawLine.trimLeft());
      if (t.isEmpty) {
        out.add(pw.SizedBox(height: 6));
        i++;
        continue;
      }
      final m = heading.firstMatch(t);
      if (m != null) {
        final level = m.group(1)!.length;
        final text = stripInlineMarkdownForExportLine(m.group(2)!.trim());
        final int pdfLevel = level <= 1 ? 0 : (level == 2 ? 1 : 2);
        out.add(
          pw.Header(
            level: pdfLevel,
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: level <= 2 ? 14.0 : 12.0,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        );
        i++;
        continue;
      }
      if (t.startsWith('> ')) {
        final quoteLines = <String>[];
        while (i < lines.length) {
          final lt = stripInlineMarkdownForExportLine(lines[i].trimLeft());
          if (lt.startsWith('> ')) {
            quoteLines.add(stripInlineMarkdownForExportLine(lt.substring(2).trim()));
            i++;
          } else if (lt.isEmpty) {
            i++;
            break;
          } else {
            break;
          }
        }
        out.add(
          pw.Container(
            padding: const pw.EdgeInsets.only(left: 10, top: 2, bottom: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.grey700, width: 2),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: quoteLines
                  .map(
                    (q) => pw.Text(
                      q,
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey800,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
        continue;
      }
      if (t.startsWith('- ') || (t.startsWith('* ') && t.length > 2)) {
        final bullets = <String>[];
        while (i < lines.length) {
          final lt = stripInlineMarkdownForExportLine(lines[i].trimLeft());
          if (lt.startsWith('- ') || (lt.startsWith('* ') && lt.length > 2)) {
            bullets.add(stripInlineMarkdownForExportLine(lt.substring(2).trim()));
            i++;
          } else if (lt.isEmpty) {
            i++;
            break;
          } else {
            break;
          }
        }
        out.add(_pdfBulletBlock(bullets));
        continue;
      }
      out.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Text(
            softBreakLongWords(t, 80),
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.25),
          ),
        ),
      );
      i++;
    }
    return out;
  }

  /// PDF from markdown. If [markdownContainsFullDocument] is true, [markdown] includes title and date (e.g. from [composeResearchWorkflowMarkdown]).
  Future<List<int>> toPdfBytesFromMarkdown({
    required String markdown,
    String? title,
    DateTime? createdAt,
    bool markdownContainsFullDocument = false,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => markdownContainsFullDocument
            ? _pdfWidgetsFromMarkdown(markdown)
            : [
                if (title != null && title.isNotEmpty) ...[
                  pw.Header(
                    level: 0,
                    child: pw.Text(
                      title,
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  if (createdAt != null)
                    pw.Paragraph(
                      text: _formatDate(createdAt),
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  pw.SizedBox(height: 12),
                ],
                ..._pdfWidgetsFromMarkdown(markdown),
              ],
      ),
    );
    return doc.save();
  }

  List<pw.Widget> _toPdfBody(ResearchReport report) {
    final widgets = <pw.Widget>[];

    widgets.add(pw.Header(
      level: 0,
      child: pw.Text(
        report.query,
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
    ));
    widgets.add(pw.Paragraph(
      text: _formatDate(report.generatedAt),
      style: const pw.TextStyle(fontSize: 10),
    ));
    widgets.add(pw.SizedBox(height: 12));

    if (report.abstractBullets.isNotEmpty) {
      widgets.add(pw.Header(level: 1, child: pw.Text('Abstract', style: pw.TextStyle(fontSize: 14))));
      for (final b in report.abstractBullets) {
        widgets.add(pw.Paragraph(text: '• $b'));
      }
      widgets.add(pw.SizedBox(height: 8));
    }

    widgets.add(pw.Header(level: 1, child: pw.Text('Summary', style: pw.TextStyle(fontSize: 14))));
    widgets.add(pw.Paragraph(text: report.summary));
    widgets.add(pw.SizedBox(height: 8));

    if (report.detailedFindings.trim().isNotEmpty) {
      widgets.add(pw.Header(level: 1, child: pw.Text('Detailed Findings', style: pw.TextStyle(fontSize: 14))));
      widgets.add(pw.Paragraph(text: report.detailedFindings));
      widgets.add(pw.SizedBox(height: 8));
    }
    if (report.strategicImplications.trim().isNotEmpty) {
      widgets.add(pw.Header(level: 1, child: pw.Text('Strategic Implications', style: pw.TextStyle(fontSize: 14))));
      widgets.add(pw.Paragraph(text: report.strategicImplications));
      widgets.add(pw.SizedBox(height: 8));
    }
    if (report.keyInsights.isNotEmpty) {
      widgets.add(pw.Header(level: 1, child: pw.Text('Key Insights', style: pw.TextStyle(fontSize: 14))));
      for (var i = 0; i < report.keyInsights.length; i++) {
        final k = report.keyInsights[i];
        widgets.add(pw.Paragraph(text: '${i + 1}. ${k.statement}'));
        widgets.add(pw.Paragraph(text: k.evidence));
      }
      widgets.add(pw.SizedBox(height: 8));
    }
    if (report.nextSteps.isNotEmpty) {
      widgets.add(pw.Header(level: 1, child: pw.Text('Recommended Next Steps', style: pw.TextStyle(fontSize: 14))));
      for (final s in report.nextSteps) {
        widgets.add(pw.Paragraph(text: '• $s'));
      }
    }
    if (report.citations.isNotEmpty) {
      widgets.add(pw.Header(level: 1, child: pw.Text('Sources', style: pw.TextStyle(fontSize: 14))));
      for (final c in report.citations) {
        widgets.add(pw.Paragraph(text: '[${c.id}] ${c.title} — ${c.source}'));
      }
    }

    return widgets;
  }

  /// Parent folder for LUMARA backups (same as .arcx and .zip backups).
  static const String lumaraBackupsFolderName = 'LUMARA_Backups';
  /// Folder for research and writing exports at app documents root (no LUMARA_Backups wrapper).
  static const String lumaraOutputsFolderName = 'LUMARA_Outputs';

  /// Returns the LUMARA Backups directory (same folder as .arcx/.zip), creating it if needed.
  Future<Directory> getLumaraBackupsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(appDir.path, lumaraBackupsFolderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Returns [lumaraOutputsFolderName] under the app documents directory (not nested in backups).
  Future<Directory> getLumaraOutputsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(appDir.path, lumaraOutputsFolderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Export report to a file in LUMARA_Outputs (or temp for share). Returns the file path, or null on failure.
  Future<String?> exportToFile(
    ResearchReport report, {
    required ReportExportFormat format,
    String? suggestedName,
  }) async {
    try {
      final base = suggestedName ?? _safeFileName(report.query);
      final baseName = base.length > 60 ? base.substring(0, 57) : base;
      final lumaraDir = await getLumaraOutputsDirectory();

      if (format == ReportExportFormat.markdown) {
        final md = toMarkdown(report);
        final dest = File(path.join(lumaraDir.path, '$baseName.md'));
        await dest.writeAsString(md, encoding: utf8);
        return dest.path;
      }

      if (format == ReportExportFormat.plainText) {
        final text = toPlainText(report);
        final dest = File(path.join(lumaraDir.path, '$baseName.txt'));
        await dest.writeAsString(text, encoding: utf8);
        return dest.path;
      }

      if (format == ReportExportFormat.pdf) {
        final bytes = await toPdfBytes(report);
        final dest = File(path.join(lumaraDir.path, '$baseName.pdf'));
        await dest.writeAsBytes(bytes);
        return dest.path;
      }

      if (format == ReportExportFormat.docx) {
        final bytes = buildDocxBytes(report);
        final dest = File(path.join(lumaraDir.path, '$baseName.docx'));
        await dest.writeAsBytes(bytes);
        return dest.path;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Save workflow research markdown to `LUMARA_Outputs` as .md / .pdf / .docx.
  /// When [userQuestion] is set, builds structured markdown (question + report) for all formats.
  Future<String?> exportWorkflowMarkdownToFile({
    required String title,
    required String markdown,
    required ReportExportFormat format,
    required DateTime createdAt,
    String? userQuestion,
    String? fileBaseName,
  }) async {
    try {
      final qTrim = userQuestion?.trim() ?? '';
      final structured = qTrim.isNotEmpty;
      final md = structured
          ? composeResearchWorkflowMarkdown(
              userQuestion: qTrim,
              reportMarkdown: markdown,
              createdAt: createdAt,
            )
          : normalizeWorkflowMarkdownForExport(markdown);
      final base = _safeFileName(fileBaseName ?? title);
      final baseName = base.length > 60 ? base.substring(0, 57) : base;
      final lumaraDir = await getLumaraOutputsDirectory();
      if (format == ReportExportFormat.markdown) {
        final dest = File(path.join(lumaraDir.path, '$baseName.md'));
        await dest.writeAsString(md, encoding: utf8);
        return dest.path;
      }
      if (format == ReportExportFormat.pdf) {
        final bytes = await toPdfBytesFromMarkdown(
          markdown: md,
          markdownContainsFullDocument: structured,
          title: structured ? null : title,
          createdAt: structured ? null : createdAt,
        );
        final dest = File(path.join(lumaraDir.path, '$baseName.pdf'));
        await dest.writeAsBytes(bytes);
        return dest.path;
      }
      if (format == ReportExportFormat.docx) {
        final bytes = buildDocxFromMarkdownExport(
          title: 'Research report',
          createdAt: createdAt,
          markdown: md,
          prependTitleAndDate: !structured,
        );
        final dest = File(path.join(lumaraDir.path, '$baseName.docx'));
        await dest.writeAsBytes(bytes);
        return dest.path;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Share workflow research via system sheet; optionally copies to LUMARA_Outputs.
  Future<bool> shareWorkflowMarkdown({
    required String title,
    required String markdown,
    required ReportExportFormat format,
    required DateTime createdAt,
    String? userQuestion,
    String? fileBaseName,
    bool alsoSaveToLumaraOutputs = true,
  }) async {
    try {
      final qTrim = userQuestion?.trim() ?? '';
      final structured = qTrim.isNotEmpty;
      final md = structured
          ? composeResearchWorkflowMarkdown(
              userQuestion: qTrim,
              reportMarkdown: markdown,
              createdAt: createdAt,
            )
          : normalizeWorkflowMarkdownForExport(markdown);
      final base = _safeFileName(fileBaseName ?? title);
      final baseName = base.length > 60 ? base.substring(0, 57) : base;
      final tmpDir = await getTemporaryDirectory();
      late final File file;
      if (format == ReportExportFormat.markdown) {
        file = File(path.join(tmpDir.path, '$baseName.md'));
        await file.writeAsString(md, encoding: utf8);
      } else if (format == ReportExportFormat.pdf) {
        final bytes = await toPdfBytesFromMarkdown(
          markdown: md,
          markdownContainsFullDocument: structured,
          title: structured ? null : title,
          createdAt: structured ? null : createdAt,
        );
        file = File(path.join(tmpDir.path, '$baseName.pdf'));
        await file.writeAsBytes(bytes);
      } else if (format == ReportExportFormat.docx) {
        final bytes = buildDocxFromMarkdownExport(
          title: 'Research report',
          createdAt: createdAt,
          markdown: md,
          prependTitleAndDate: !structured,
        );
        file = File(path.join(tmpDir.path, '$baseName.docx'));
        await file.writeAsBytes(bytes);
      } else {
        file = File(path.join(tmpDir.path, '$baseName.txt'));
        await file.writeAsString(md, encoding: utf8);
      }
      if (!await file.exists()) return false;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: structured ? 'Research report' : title,
        ),
      );
      if (alsoSaveToLumaraOutputs) {
        try {
          final lumaraDir = await getLumaraOutputsDirectory();
          await file.copy(path.join(lumaraDir.path, path.basename(file.path)));
        } catch (_) {}
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Plain text version (no markdown); used for .txt export.
  String toPlainText(ResearchReport report) {
    final buf = StringBuffer();
    buf.writeln(report.query);
    buf.writeln();
    buf.writeln(_formatDate(report.generatedAt));
    buf.writeln();
    if (report.abstractBullets.isNotEmpty) {
      buf.writeln('Abstract');
      buf.writeln();
      for (final b in report.abstractBullets) {
        buf.writeln('• $b');
      }
      buf.writeln();
    }
    buf.writeln('Summary');
    buf.writeln(report.summary);
    if (report.detailedFindings.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('Detailed Findings');
      buf.writeln(report.detailedFindings);
    }
    if (report.keyInsights.isNotEmpty) {
      buf.writeln();
      buf.writeln('Key Insights');
      for (var i = 0; i < report.keyInsights.length; i++) {
        buf.writeln('${i + 1}. ${report.keyInsights[i].statement}');
        buf.writeln(report.keyInsights[i].evidence);
      }
    }
    if (report.nextSteps.isNotEmpty) {
      buf.writeln();
      buf.writeln('Recommended Next Steps');
      for (final s in report.nextSteps) {
        buf.writeln('- $s');
      }
    }
    if (report.citations.isNotEmpty) {
      buf.writeln();
      buf.writeln('Sources');
      for (final c in report.citations) {
        buf.writeln('[${c.id}] ${c.title} — ${c.source}');
        if (c.url.isNotEmpty) buf.writeln(c.url);
      }
    }
    return buf.toString();
  }

  /// Export and share via system share sheet (user picks app: Email, Dropbox, Google Drive, etc.).
  /// If [alsoSaveToLumaraOutputs] is true, also writes a copy to the LUMARA_Outputs folder.
  Future<bool> exportAndShare(
    ResearchReport report, {
    required ReportExportFormat format,
    String? suggestedName,
    bool alsoSaveToLumaraOutputs = true,
  }) async {
    try {
      final base = suggestedName ?? _safeFileName(report.query);
      final baseName = base.length > 60 ? base.substring(0, 57) : base;
      final tmpDir = await getTemporaryDirectory();
      final ext = format == ReportExportFormat.markdown
          ? 'md'
          : format == ReportExportFormat.plainText
              ? 'txt'
              : format == ReportExportFormat.pdf
                  ? 'pdf'
                  : 'docx';
      final fileName = '$baseName.$ext';
      File file;

      if (format == ReportExportFormat.markdown) {
        final md = toMarkdown(report);
        file = File(path.join(tmpDir.path, fileName));
        await file.writeAsString(md, encoding: utf8);
      } else if (format == ReportExportFormat.plainText) {
        final text = toPlainText(report);
        file = File(path.join(tmpDir.path, fileName));
        await file.writeAsString(text, encoding: utf8);
      } else if (format == ReportExportFormat.pdf) {
        final bytes = await toPdfBytes(report);
        file = File(path.join(tmpDir.path, fileName));
        await file.writeAsBytes(bytes);
      } else if (format == ReportExportFormat.docx) {
        final bytes = buildDocxBytes(report);
        file = File(path.join(tmpDir.path, fileName));
        await file.writeAsBytes(bytes);
      } else {
        return false;
      }

      if (!await file.exists()) return false;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: report.query,
          subject: 'Research Report: ${report.query}',
        ),
      );

      if (alsoSaveToLumaraOutputs) {
        final lumaraDir = await getLumaraOutputsDirectory();
        final dest = File(path.join(lumaraDir.path, fileName));
        await file.copy(dest.path);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Export and upload to Google Drive. Returns Drive file ID or null on failure.
  Future<String?> exportToGoogleDrive(
    ResearchReport report, {
    required ReportExportFormat format,
    String? suggestedName,
  }) async {
    try {
      final gd = GoogleDriveService.instance;
      if (!gd.isSignedIn) {
        final email = await gd.signIn();
        if (email == null || !gd.isSignedIn) return null;
      }

      final base = suggestedName ?? _safeFileName(report.query);
      final baseName = base.length > 60 ? base.substring(0, 57) : base;
      final ext = format == ReportExportFormat.markdown
          ? 'md'
          : format == ReportExportFormat.plainText
              ? 'txt'
              : format == ReportExportFormat.pdf
                  ? 'pdf'
                  : 'docx';
      final nameOverride = '$baseName.$ext';
      File file;

      if (format == ReportExportFormat.markdown) {
        final md = toMarkdown(report);
        file = await _writeToTempFile(md, 'md');
      } else if (format == ReportExportFormat.plainText) {
        final text = toPlainText(report);
        file = await _writeToTempFile(text, 'txt');
      } else if (format == ReportExportFormat.pdf) {
        final bytes = await toPdfBytes(report);
        final tmpDir = await getTemporaryDirectory();
        file = File(path.join(tmpDir.path, nameOverride));
        await file.writeAsBytes(bytes);
      } else if (format == ReportExportFormat.docx) {
        final bytes = buildDocxBytes(report);
        final tmpDir = await getTemporaryDirectory();
        file = File(path.join(tmpDir.path, nameOverride));
        await file.writeAsBytes(bytes);
      } else {
        return null;
      }

      if (!await file.exists()) return null;
      final folderId = await gd.getOrCreateAppFolder();
      final fileId = await gd.uploadFile(
        localFile: file,
        nameOverride: nameOverride,
        folderId: folderId,
      );
      return fileId;
    } catch (e) {
      return null;
    }
  }
}

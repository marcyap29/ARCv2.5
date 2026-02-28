/// Report Export Service
///
/// Exports research reports and writings as .md, .pdf. Supports save to device,
/// share (email, Dropbox via system share), and Google Drive upload.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:my_app/lumara/agents/models/research_models.dart';
import 'package:my_app/services/google_drive_service.dart';

/// Format for export.
enum ReportExportFormat { markdown, pdf }

/// Destination for export.
enum ReportExportDestination { device, share, googleDrive }

class ReportExportService {
  ReportExportService._();
  static final ReportExportService instance = ReportExportService._();

  /// Build markdown string from report (saves space; used as base for .md export).
  String toMarkdown(ResearchReport report) {
    final buf = StringBuffer();
    buf.writeln('# ${report.query}');
    buf.writeln();
    buf.writeln('*${_formatDate(report.generatedAt)} · ${report.phase.name} Phase*');
    buf.writeln();
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
      text: '${_formatDate(report.generatedAt)} · ${report.phase.name} Phase',
      style: const pw.TextStyle(fontSize: 10),
    ));
    widgets.add(pw.SizedBox(height: 12));

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

  /// Export report to a file. Returns the file path, or null on failure.
  Future<String?> exportToFile(
    ResearchReport report, {
    required ReportExportFormat format,
    String? suggestedName,
  }) async {
    try {
      final base = suggestedName ?? _safeFileName(report.query);
      final baseName = base.length > 60 ? base.substring(0, 57) : base;

      if (format == ReportExportFormat.markdown) {
        final md = toMarkdown(report);
        final file = await _writeToTempFile(md, 'md');
        final destDir = await getApplicationDocumentsDirectory();
        final dest = File(path.join(destDir.path, '$baseName.md'));
        await file.copy(dest.path);
        return dest.path;
      }

      if (format == ReportExportFormat.pdf) {
        final bytes = await toPdfBytes(report);
        final dir = await getApplicationDocumentsDirectory();
        final dest = File(path.join(dir.path, '$baseName.pdf'));
        await dest.writeAsBytes(bytes);
        return dest.path;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Export and share via system share sheet (email, Dropbox, etc.).
  Future<bool> exportAndShare(
    ResearchReport report, {
    required ReportExportFormat format,
    String? suggestedName,
  }) async {
    try {
      final base = suggestedName ?? _safeFileName(report.query);
      final baseName = base.length > 60 ? base.substring(0, 57) : base;

      if (format == ReportExportFormat.markdown) {
        final md = toMarkdown(report);
        final file = await _writeToTempFile(md, 'md');
        await Share.shareXFiles(
          [XFile(file.path)],
          text: report.query,
          subject: 'Research Report: ${report.query}',
        );
        return true;
      }

      if (format == ReportExportFormat.pdf) {
        final bytes = await toPdfBytes(report);
        final dir = await getTemporaryDirectory();
        final file = File(path.join(dir.path, '$baseName.pdf'));
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: report.query,
          subject: 'Research Report: ${report.query}',
        );
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  /// Export and upload to Google Drive. Returns Drive file ID or null.
  Future<String?> exportToGoogleDrive(
    ResearchReport report, {
    required ReportExportFormat format,
    String? suggestedName,
  }) async {
    try {
      final gd = GoogleDriveService.instance;
      if (!gd.isSignedIn) {
        final _ = await gd.signIn();
        if (!gd.isSignedIn) return null;
      }

      final base = suggestedName ?? _safeFileName(report.query);
      final baseName = base.length > 60 ? base.substring(0, 57) : base;

      if (format == ReportExportFormat.markdown) {
        final md = toMarkdown(report);
        final file = await _writeToTempFile(md, 'md');
        final fileId = await gd.uploadFile(
          localFile: file,
          nameOverride: '$baseName.md',
          folderId: await gd.getOrCreateAppFolder(),
        );
        return fileId;
      }

      if (format == ReportExportFormat.pdf) {
        final bytes = await toPdfBytes(report);
        final dir = await getTemporaryDirectory();
        final file = File(path.join(dir.path, '$baseName.pdf'));
        await file.writeAsBytes(bytes);
        final fileId = await gd.uploadFile(
          localFile: file,
          nameOverride: '$baseName.pdf',
          folderId: await gd.getOrCreateAppFolder(),
        );
        return fileId;
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}

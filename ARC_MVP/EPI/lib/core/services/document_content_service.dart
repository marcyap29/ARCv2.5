import 'dart:io';

import 'package:docx_to_text/docx_to_text.dart';

import 'pdf_content_service.dart';

/// Extracts plain text from PDF, DOCX, TXT, and MD files.
/// Used for on-demand extraction (e.g. DOCX in-app preview). Journal flow inserts
/// extracted text into the entry body with [Extracted text from "Document title"].
class DocumentContentService {
  DocumentContentService._();

  /// Extract text from a document file. Supports .pdf, .docx, .doc, .txt, .md.
  /// Returns empty string if file missing, unsupported, or on error.
  static Future<String> extractTextFromPath(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return '';
      final path = file.path.replaceFirst(RegExp(r'^file://'), '');
      final ext = path.split('.').last.toLowerCase();
      if (ext == 'pdf') {
        final result = await PdfContentService.extractForChronicle(
          path,
          includePageImageAnalysis: false,
        );
        String text = result.text.trim();
        if (result.pageImageInsights.trim().isNotEmpty) {
          text += '${text.isEmpty ? '' : '\n\n'}[From PDF pages]\n${result.pageImageInsights.trim()}';
        }
        return text;
      }
      if (ext == 'docx' || ext == 'doc') {
        final bytes = await file.readAsBytes();
        return docxToText(bytes).trim();
      }
      if (ext == 'txt' || ext == 'md') {
        return (await file.readAsString()).trim();
      }
      return '';
    } catch (_) {
      return '';
    }
  }
}

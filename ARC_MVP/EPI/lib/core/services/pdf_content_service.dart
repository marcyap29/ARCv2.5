import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:read_pdf_text/read_pdf_text.dart';

import '../../mira/store/mcp/orchestrator/ocp_services.dart';

/// Result of extracting content from a PDF for LUMARA/Chronicle.
class PdfExtractionResult {
  /// Extracted text from all pages (native extraction when available).
  final String text;

  /// Keywords/labels from document text and from analyzing rendered page images.
  final List<String> keywords;

  /// OCR/description text from rendered page images (when image analysis is run).
  final String pageImageInsights;

  const PdfExtractionResult({
    this.text = '',
    this.keywords = const [],
    this.pageImageInsights = '',
  });

  bool get hasContent =>
      text.trim().isNotEmpty ||
      keywords.isNotEmpty ||
      pageImageInsights.trim().isNotEmpty;
}

/// Service for LUMARA to read text from PDFs and analyze images within PDFs
/// (rendered pages) for chronicle inference.
///
/// - Text: uses [read_pdf_text] on iOS/Android; no-op on other platforms.
/// - Images: uses [pdfx] to render pages to images, then [OcpImageService]
///   for OCR and object detection so LUMARA can "look at" PDF content.
class PdfContentService {
  PdfContentService._();

  static const int _maxPagesForImageAnalysis = 20;

  /// Extract text from a PDF file using native APIs (iOS PDFKit, Android PDFbox).
  /// Returns empty string on unsupported platforms or on error.
  static Future<String> extractText(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return '';
      final path = file.path;
      final text = await ReadPdfText.getPDFtext(path);
      return text.trim();
    } catch (_) {
      return '';
    }
  }

  /// Render PDF pages to images and run OCP analysis (OCR + object detection)
  /// to infer content for chronicle. Caps at [maxPages] to avoid cost.
  static Future<({
    String ocrAggregate,
    List<String> objectLabels,
  })> extractInsightsFromRenderedPages(
    String filePath, {
    int maxPages = _maxPagesForImageAnalysis,
  }) async {
    String ocrAggregate = '';
    final objectLabels = <String>{};

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return (ocrAggregate: ocrAggregate, objectLabels: objectLabels.toList());
      }
      final path = file.path.replaceFirst(RegExp(r'^file://'), '');

      final document = await PdfDocument.openFile(path);
      try {
        final count = document.pagesCount;
        final toProcess = count > maxPages ? maxPages : count;
        final tempDir = await getTemporaryDirectory();

        for (int i = 1; i <= toProcess; i++) {
          final page = await document.getPage(i);
          try {
            final pageImage = await page.render(
              width: page.width,
              height: page.height,
              format: PdfPageImageFormat.jpeg,
              quality: 85,
            );
            if (pageImage == null) continue;

            final ext = pageImage.format == PdfPageImageFormat.jpeg ? 'jpg' : 'png';
            final tempFile = File(
              '${tempDir.path}/lumara_pdf_page_${DateTime.now().millisecondsSinceEpoch}_$i.$ext',
            );
            await tempFile.writeAsBytes(pageImage.bytes);
            try {
              final result = await OcpImageService.analyzeImage(tempFile.path);
              if (result.ocrText.trim().isNotEmpty) {
                ocrAggregate += '${ocrAggregate.isEmpty ? '' : '\n\n'}Page $i: ${result.ocrText.trim()}';
              }
              for (final obj in result.objects) {
                objectLabels.add(obj.label);
              }
            } finally {
              try {
                await tempFile.delete();
              } catch (_) {}
            }
          } finally {
            await page.close();
          }
        }
      } finally {
        await document.close();
      }
    } catch (e) {
      // Non-fatal: return what we have
    }

    return (
      ocrAggregate: ocrAggregate,
      objectLabels: objectLabels.toList(),
    );
  }

  /// Full extraction: native text + image-based insights from rendered pages.
  /// Use this for chronicle and chat so LUMARA can read PDF text and infer
  /// from images/diagrams in the PDF.
  static Future<PdfExtractionResult> extractForChronicle(
    String filePath, {
    bool includePageImageAnalysis = true,
    int maxPagesForImages = _maxPagesForImageAnalysis,
  }) async {
    final text = await extractText(filePath);
    final keywords = <String>[];

    if (text.trim().isNotEmpty) {
      final words = text
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 2 && w.length < 30)
          .take(100);
      final stop = {
        'the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can', 'had',
        'her', 'his', 'was', 'one', 'our', 'out', 'has', 'have', 'this', 'that',
      };
      for (final w in words) {
        final lower = w.replaceAll(RegExp(r'[^\w\-]'), '').toLowerCase();
        if (lower.length > 2 && !stop.contains(lower) && keywords.length < 30) {
          keywords.add(lower);
        }
      }
    }

    String pageImageInsights = '';
    if (includePageImageAnalysis) {
      final insights = await extractInsightsFromRenderedPages(
        filePath,
        maxPages: maxPagesForImages,
      );
      pageImageInsights = insights.ocrAggregate;
      for (final label in insights.objectLabels) {
        if (label.length > 1 && keywords.length < 50) {
          keywords.add(label);
        }
      }
    }

    final fileName = filePath.split(RegExp(r'[/\\]')).last;
    if (fileName.isNotEmpty) {
      final stem = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      if (stem.length > 1 && !keywords.contains(stem)) {
        keywords.insert(0, stem);
      }
    }

    return PdfExtractionResult(
      text: text,
      keywords: keywords.take(50).toList(),
      pageImageInsights: pageImageInsights,
    );
  }
}

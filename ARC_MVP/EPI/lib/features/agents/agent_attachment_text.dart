import 'dart:io';

import 'package:my_app/core/services/document_content_service.dart';
import 'package:my_app/core/services/pdf_content_service.dart';
import 'package:my_app/features/agents/agents_data.dart';

const int _maxCharsPerFile = 18000;
const int _maxCharsTotal = 100000;

/// Reads PDF / plain-text attachments into `{name, text}` maps for the workflow Worker.
Future<List<Map<String, String>>> extractSourceDocumentsForWorker(
  List<AgentAttachment> attachments,
) async {
  if (attachments.isEmpty) return [];

  final out = <Map<String, String>>[];
  var total = 0;

  for (final a in attachments) {
    final path = a.path;
    if (path == null || path.isEmpty) continue;

    String text = '';
    final ext = a.extension.toLowerCase();

    if (ext == 'pdf') {
      final r = await PdfContentService.extractForChronicle(
        path,
        includePageImageAnalysis: false,
      );
      text = r.text.trim();
      if (text.isEmpty && r.pageImageInsights.trim().isNotEmpty) {
        text = r.pageImageInsights.trim();
      }
    } else if (ext == 'docx' || ext == 'doc') {
      text = (await DocumentContentService.extractTextFromPath(path)).trim();
    } else if (ext == 'txt' || ext == 'md' || ext == 'markdown') {
      try {
        text = (await File(path).readAsString()).trim();
      } catch (_) {
        text = '';
      }
    } else {
      continue;
    }

    if (text.isEmpty) continue;

    var slice = text.length > _maxCharsPerFile
        ? text.substring(0, _maxCharsPerFile)
        : text;
    final room = _maxCharsTotal - total;
    if (room <= 0) break;
    if (slice.length > room) {
      slice = slice.substring(0, room);
    }
    if (slice.isEmpty) break;

    out.add({'name': a.fileName, 'text': slice});
    total += slice.length;
  }

  return out;
}

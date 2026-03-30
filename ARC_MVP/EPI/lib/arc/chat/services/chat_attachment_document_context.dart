import 'package:my_app/core/services/document_content_service.dart';

/// Total chars of extracted attachment text passed into [ResearchAgent.documentContext]
/// (aligned with research agent clamp).
const int kChatAttachmentDocumentContextMaxTotalChars = 12000;

const int _maxCharsPerFile = 8000;

/// Builds a single document-context string from chat file paths (PDF, DOCX, TXT, MD).
/// Returns null if nothing could be extracted.
Future<String?> buildDocumentContextFromChatAttachments(
  List<({String path, String fileName})> files,
) async {
  if (files.isEmpty) return null;

  final buf = StringBuffer();
  var total = 0;

  for (final f in files) {
    final path = f.path.replaceFirst(RegExp(r'^file://'), '');
    if (path.isEmpty) continue;

    var text = await DocumentContentService.extractTextFromPath(path);
    text = text.trim();
    if (text.isEmpty) continue;

    var slice = text.length > _maxCharsPerFile
        ? '${text.substring(0, _maxCharsPerFile)}\n\n[Attachment truncated…]'
        : text;
    final header = '### Reference: ${f.fileName}\n\n';
    final room = kChatAttachmentDocumentContextMaxTotalChars - total - header.length;
    if (room <= 0) break;
    if (slice.length > room) {
      slice = '${slice.substring(0, room)}\n\n[Attachment truncated…]';
    }
    buf.write(header);
    buf.writeln(slice);
    buf.writeln();
    total += header.length + slice.length + 1;
    if (total >= kChatAttachmentDocumentContextMaxTotalChars) break;
  }

  final out = buf.toString().trim();
  return out.isEmpty ? null : out;
}

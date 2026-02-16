// Lightweight model for the Writing Agent tab list (drafts from CHRONICLE).
// Full draft content lives in Writing subsystem / WritingScreen.

class ContentDraft {
  final String id;
  final String title;
  final String preview;
  final DateTime updatedAt;
  final String? contentType; // e.g. 'linkedIn', 'substack', 'technical'

  const ContentDraft({
    required this.id,
    required this.title,
    required this.preview,
    required this.updatedAt,
    this.contentType,
  });
}

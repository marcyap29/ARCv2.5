// Lightweight model for the Writing Agent tab list (drafts from CHRONICLE).
// Full draft content lives in Writing subsystem / WritingScreen.

/// Status for list filtering and display.
enum ContentDraftStatus { draft, finished }

class ContentDraft {
  final String id;
  final String title;
  final String preview;
  final DateTime updatedAt;
  final String? contentType; // e.g. 'linkedIn', 'substack', 'technical'
  /// When the draft was first created.
  final DateTime? createdAt;
  final ContentDraftStatus status;
  final bool archived;
  final DateTime? archivedAt;
  final int wordCount;

  const ContentDraft({
    required this.id,
    required this.title,
    required this.preview,
    required this.updatedAt,
    this.contentType,
    this.createdAt,
    this.status = ContentDraftStatus.draft,
    this.archived = false,
    this.archivedAt,
    this.wordCount = 0,
  });
}

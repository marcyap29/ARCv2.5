// lib/chronicle/dual/services/lumara_comments_loader.dart
//
// Optional loader for LUMARA's prior comments (reflections + chats) to speed
// inference and relationship context. App layer provides an implementation
// when it has access to journal and chat repos.

/// Interface for loading recent LUMARA comments from the timeline (journal
/// lumaraBlocks and chat assistant messages). Set via DualChronicleServices
/// so the agentic loop can use it when available.
abstract class LumaraCommentsLoader {
  /// Returns a string of recent LUMARA comments (and user replies) for context.
  /// Empty string if none or on error. Caller may cap length before passing to the loop.
  Future<String> load(String userId);
}

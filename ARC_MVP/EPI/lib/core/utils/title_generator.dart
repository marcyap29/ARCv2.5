/// Shared Title Generator Utility
/// 
/// Consolidates title generation logic from content across import services and journal capture
library;

/// Generate title from content
/// Uses first line as title, max 50 chars (with ellipsis if truncated)
/// Default fallback: 'Imported Entry' or 'Untitled Entry' based on context
class TitleGenerator {
  /// Generate title from content with default fallback
  static String generate(String content, {String defaultTitle = 'Imported Entry'}) {
    if (content.isEmpty) return defaultTitle;
    
    // Use first line as title, max 50 chars
    final firstLine = content.split('\n').first.trim();
    if (firstLine.isEmpty) return defaultTitle;
    
    if (firstLine.length > 50) {
      return '${firstLine.substring(0, 47)}...';
    }
    return firstLine;
  }

  /// Generate title for journal entries (default: 'Untitled Entry')
  static String forJournalEntry(String content) {
    return generate(content, defaultTitle: 'Untitled Entry');
  }

  /// Generate title for imported entries (default: 'Imported Entry')
  static String forImportedEntry(String content) {
    return generate(content, defaultTitle: 'Imported Entry');
  }
}


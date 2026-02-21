// lib/services/lumara_comments_context_loader.dart
//
// Loads LUMARA's prior comments from journal entries (lumaraBlocks) and
// optionally from chat (assistant messages) for agentic loop context.

import 'package:my_app/chronicle/dual/services/lumara_comments_loader.dart';
import 'package:my_app/models/journal_entry_model.dart';

/// Default max length for the combined context string.
const int kLumaraCommentsContextMaxLength = 8000;

/// Implementation that gathers LUMARA comments from journal entries (lumaraBlocks).
/// Inject [getRecentEntries] so this service does not depend on JournalRepository directly.
class LumaraCommentsContextLoader implements LumaraCommentsLoader {
  LumaraCommentsContextLoader({
    required Future<List<JournalEntry>> Function() getRecentEntries,
    Future<List<String>> Function()? getRecentAssistantMessages,
  })  : _getRecentEntries = getRecentEntries,
        _getRecentAssistantMessages = getRecentAssistantMessages;

  final Future<List<JournalEntry>> Function() _getRecentEntries;
  final Future<List<String>> Function()? _getRecentAssistantMessages;

  @override
  Future<String> load(String userId) async {
    final buffer = StringBuffer();
    try {
      final entries = await _getRecentEntries();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final recent = entries.take(50).toList();
      for (final entry in recent) {
        if (entry.lumaraBlocks.isEmpty) continue;
        for (final block in entry.lumaraBlocks) {
          if (block.content.trim().isNotEmpty) {
            buffer.writeln('[LUMARA]: ${block.content.trim()}');
          }
          if (block.userComment != null && block.userComment!.trim().isNotEmpty) {
            buffer.writeln('[You]: ${block.userComment!.trim()}');
          }
        }
      }
      if (_getRecentAssistantMessages != null) {
        final assistantMessages = await _getRecentAssistantMessages!();
        for (final msg in assistantMessages.take(30)) {
          if (msg.trim().isNotEmpty) {
            buffer.writeln('[LUMARA chat]: $msg');
          }
        }
      }
    } catch (e) {
      return '';
    }
    final s = buffer.toString().trim();
    if (s.length > kLumaraCommentsContextMaxLength) {
      return s.substring(0, kLumaraCommentsContextMaxLength);
    }
    return s;
  }
}

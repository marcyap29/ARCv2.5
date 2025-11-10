enum IntentType { journalNew, journalAppend, journalQuery, chat, fileSearch, fileSummarize, unknown }

class IntentResult {
  final IntentType type;
  final DateTime? targetDate;
  final String? query;

  IntentResult(this.type, {this.targetDate, this.query});
}

class IntentRouter {
  // Heuristic first; you can swap to LLM intent later.
  static IntentResult detect(String text) {
    final t = text.toLowerCase();
    if (t.contains('new journal') || t.contains('start a journal')) {
      return IntentResult(IntentType.journalNew);
    }
    if (t.contains('add to') || t.contains('append') || t.contains('update journal')) {
      return IntentResult(IntentType.journalAppend);
    }
    if (t.contains('summarize') && t.contains('journal')) {
      return IntentResult(IntentType.journalQuery, query: text);
    }
    if (t.contains('search') && t.contains('file')) {
      return IntentResult(IntentType.fileSearch, query: text);
    }
    if (t.contains('summarize') && (t.contains('paper') || t.contains('doc') || t.contains('file'))) {
      return IntentResult(IntentType.fileSummarize, query: text);
    }
    // Default to chat
    return IntentResult(IntentType.chat);
  }
}


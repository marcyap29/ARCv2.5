class ContextMemory {
  String? journalEntryId;      // last touched
  String? chatSessionId;       // main chat session
  String? lastFileId;          // last referenced file

  Map<String, dynamic> toCtx() => {
    'journalEntryId': journalEntryId,
    'chatSessionId': chatSessionId,
    'lastFileId': lastFileId,
  };
}


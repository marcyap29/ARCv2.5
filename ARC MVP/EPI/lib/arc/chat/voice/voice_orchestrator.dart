import 'intent_router.dart';
import 'context_memory.dart';
import '../../journal/journal_manager.dart';
import '../main_chat_manager.dart';
import '../../files/file_manager.dart';
import 'voice_chat_pipeline.dart';

class VoiceOrchestrator {
  final VoiceChatPipeline pipeline;
  final ContextMemory memory;
  final JournalManager journal;
  final MainChatManager chat;
  final FileManager files;

  VoiceOrchestrator({
    required this.pipeline,
    required this.memory,
    required this.journal,
    required this.chat,
    required this.files,
  });

  Future<void> process(String userText, {bool confirmDestructive = true}) async {
    final intent = IntentRouter.detect(userText);

    // Mode A: Scrub PII first, then route
    String processedText = userText;
    if (pipeline is ModeAPipeline) {
      final modeAPipeline = pipeline as ModeAPipeline;
      processedText = await modeAPipeline.scrubPII(userText);
    }

    switch (intent.type) {
      case IntentType.journalNew:
        memory.journalEntryId = await journal.createEntry(processedText);
        await pipeline.speak("Created a new journal entry.");
        return;

      case IntentType.journalAppend:
        await journal.appendToToday(processedText);
        await pipeline.speak("Added that to today's journal.");
        return;

      case IntentType.journalQuery:
        final sum = await journal.summarize(query: intent.query);
        await pipeline.speak(sum);
        return;

      case IntentType.fileSearch:
        final results = await files.search(intent.query ?? '');
        final msg = results.isEmpty
            ? "I did not find matching files."
            : "I found ${results.length} items. Say 'summarize the first one' to continue.";
        await pipeline.speak(msg);
        return;

      case IntentType.fileSummarize:
        // TODO: map phrase to a fileId (e.g., last search result)
        final sum2 = await files.summarize(memory.lastFileId ?? '');
        await pipeline.speak(sum2);
        return;

      case IntentType.chat:
      default:
        memory.chatSessionId ??= await chat.ensureSession();
        final reply = await chat.replyWithContext(processedText, memory.toCtx());
        await pipeline.speak(reply);
        await chat.persistTurn(user: processedText, assistant: reply);
        return;
    }
  }
}


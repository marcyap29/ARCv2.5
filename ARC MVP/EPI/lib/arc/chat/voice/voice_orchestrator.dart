import 'context_memory.dart';
import '../../journal/journal_manager.dart';
import '../main_chat_manager.dart';
import '../../files/file_manager.dart';
import 'voice_chat_pipeline.dart';

// VoiceContext enum - shared between service and orchestrator
enum VoiceContext { chat, journal }

class VoiceOrchestrator {
  final VoiceChatPipeline pipeline;
  final ContextMemory memory;
  final JournalManager journal;
  final MainChatManager chat;
  final FileManager files;
  final VoiceContext context;
  final Function(String)? onTextWritten; // Callback to write text to journal view

  VoiceOrchestrator({
    required this.pipeline,
    required this.memory,
    required this.journal,
    required this.chat,
    required this.files,
    this.context = VoiceContext.chat,
    this.onTextWritten,
  });

  Future<void> process(String userText, {bool confirmDestructive = true}) async {
    // Mode A: Scrub PII first
    String processedText = userText;
    if (pipeline is ModeAPipeline) {
      final modeAPipeline = pipeline as ModeAPipeline;
      processedText = await modeAPipeline.scrubPII(userText);
    }

    // Route based on context (journal vs chat) instead of intent detection
    if (context == VoiceContext.journal) {
      // Journal context: Write user text and get LUMARA response, then write to journal view
      // Write user's text to journal view
      final userTextFormatted = '**You:** $processedText\n\n';
      onTextWritten?.call(userTextFormatted);
      
      // Get LUMARA's response
      // Try using chat manager first, but fall back to pipeline API if cubit isn't available
      String reply;
      try {
        memory.chatSessionId ??= await chat.ensureSession();
        reply = await chat.replyWithContext(processedText, memory.toCtx());
        
        // Check if we got a fallback message (cubit not initialized)
        if (reply.contains('requires LumaraAssistantCubit') || reply.contains("I'm processing")) {
          // Fall back to using pipeline API directly
          reply = await pipeline.callLLMText(processedText, ctx: memory.toCtx());
        }
      } catch (e) {
        // If chat manager fails, use pipeline API directly
        reply = await pipeline.callLLMText(processedText, ctx: memory.toCtx());
      }
      
      // Write LUMARA's response to journal view
      final lumaraTextFormatted = '**LUMARA:** $reply\n\n';
      onTextWritten?.call(lumaraTextFormatted);
      
      // Speak the response
      await pipeline.speak(reply);
      
      // Note: Don't save yet - text is written to view, user can save manually
      return;
    } else {
      // Chat context: Always go to chat
      memory.chatSessionId ??= await chat.ensureSession();
      final reply = await chat.replyWithContext(processedText, memory.toCtx());
      await pipeline.speak(reply);
      await chat.persistTurn(user: processedText, assistant: reply);
      return;
    }
  }
}

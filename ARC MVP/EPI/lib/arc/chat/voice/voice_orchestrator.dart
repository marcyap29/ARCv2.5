import 'package:flutter/foundation.dart';
import 'context_memory.dart';
import '../../journal/journal_manager.dart';
import '../main_chat_manager.dart';
import '../../files/file_manager.dart';
import 'voice_chat_pipeline.dart';
import '../../../mira/memory/enhanced_memory_schema.dart';
import '../services/enhanced_lumara_api.dart';

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
  final VoidCallback? onSpeakingStart; // Callback when TTS starts
  final VoidCallback? onSpeakingDone; // Callback when TTS completes
  
  // Store attribution traces for each LUMARA response (keyed by response text hash or index)
  final Map<String, List<AttributionTrace>> _attributionTracesMap = {};

  VoiceOrchestrator({
    required this.pipeline,
    required this.memory,
    required this.journal,
    required this.chat,
    required this.files,
    this.context = VoiceContext.chat,
    this.onTextWritten,
    this.onSpeakingStart,
    this.onSpeakingDone,
  });
  
  /// Get attribution traces for a LUMARA response
  List<AttributionTrace>? getAttributionTraces(String responseText) {
    // Use a simple hash of the response text as key
    final key = responseText.hashCode.toString();
    return _attributionTracesMap[key];
  }
  
  /// Store attribution traces for a LUMARA response
  void storeAttributionTraces(String responseText, List<AttributionTrace> traces) {
    final key = responseText.hashCode.toString();
    _attributionTracesMap[key] = traces;
  }

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
      
      // Get LUMARA's response with attribution traces
      // Try using chat manager first, but fall back to pipeline API if cubit isn't available
      String reply;
      List<AttributionTrace>? attributionTraces;
      
      try {
        memory.chatSessionId ??= await chat.ensureSession();
        reply = await chat.replyWithContext(processedText, memory.toCtx());
        
        // Check if we got a fallback message (cubit not initialized)
        if (reply.contains('requires LumaraAssistantCubit') || reply.contains("I'm processing")) {
          // Fall back to using pipeline API directly with attribution traces
          final result = await _getLumaraResponseWithAttribution(processedText, memory.toCtx());
          reply = result.reply;
          attributionTraces = result.attributionTraces;
        } else {
          // Try to get attribution traces from chat manager if available
          // (Note: MainChatManager may not provide traces, so we'll get them from pipeline as fallback)
          try {
            final result = await _getLumaraResponseWithAttribution(processedText, memory.toCtx());
            attributionTraces = result.attributionTraces;
          } catch (e) {
            // If we can't get traces, continue without them
            debugPrint('Could not get attribution traces: $e');
          }
        }
      } catch (e) {
        // If chat manager fails, use pipeline API directly with attribution traces
        final result = await _getLumaraResponseWithAttribution(processedText, memory.toCtx());
        reply = result.reply;
        attributionTraces = result.attributionTraces;
      }
      
      // Store attribution traces for this response
      if (attributionTraces != null && attributionTraces.isNotEmpty) {
        storeAttributionTraces(reply, attributionTraces);
      }
      
      // Write LUMARA's response to journal view FIRST (creates inline box immediately)
      // This ensures the response appears in the UI before TTS starts
      final lumaraTextFormatted = '**LUMARA:** $reply\n\n';
      onTextWritten?.call(lumaraTextFormatted);
      
      // Small delay to ensure UI has time to update and render the inline box
      await Future.delayed(const Duration(milliseconds: 100));
      
      // THEN speak the response (TTS the LUMARA reply content)
      // This ensures the inline box is created and visible before audio starts
      try {
        // Notify that speaking is starting (updates UI to grayed out state)
        onSpeakingStart?.call();
        await pipeline.speak(reply);
        // Notify that speaking is done (updates UI back to ready state)
        onSpeakingDone?.call();
      } catch (e) {
        debugPrint('Error speaking LUMARA response: $e');
        // Even if TTS fails, notify that speaking is done so UI can return to ready state
        onSpeakingDone?.call();
        // Continue even if TTS fails - the text is already displayed
      }
      
      // Note: Don't save yet - text is written to view, user can save manually
      return;
    } else {
      // Chat context: Always go to chat
        memory.chatSessionId ??= await chat.ensureSession();
        final reply = await chat.replyWithContext(processedText, memory.toCtx());
        
        // Notify that speaking is starting
        onSpeakingStart?.call();
        await pipeline.speak(reply);
        // Notify that speaking is done
        onSpeakingDone?.call();
        
        await chat.persistTurn(user: processedText, assistant: reply);
        return;
    }
  }
  
  /// Get LUMARA response with attribution traces
  /// Uses EnhancedLumaraApi directly to get both reply and attribution traces
  Future<({String reply, List<AttributionTrace>? attributionTraces})> _getLumaraResponseWithAttribution(
    String processedText,
    Map<String, dynamic> ctx,
  ) async {
    // If pipeline is ModeAPipeline, we can access the API directly
    if (pipeline is ModeAPipeline) {
      final modeAPipeline = pipeline as ModeAPipeline;
      try {
        // Access the EnhancedLumaraApi from the pipeline
        final result = await modeAPipeline.getReflectionWithAttribution(
          processedText,
          ctx: ctx,
        );
        return (reply: result.reflection, attributionTraces: result.attributionTraces);
      } catch (e) {
        debugPrint('Error getting reflection with attribution: $e');
        // Fallback to regular call
        final reply = await pipeline.callLLMText(processedText, ctx: ctx);
        return (reply: reply, attributionTraces: null);
      }
    } else {
      // Fallback for other pipeline types
      final reply = await pipeline.callLLMText(processedText, ctx: ctx);
      return (reply: reply, attributionTraces: null);
    }
  }
}

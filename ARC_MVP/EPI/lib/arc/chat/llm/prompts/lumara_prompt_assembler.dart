/// LUMARA Prompt Assembler for On-Device LLMs
/// 
/// Assembles complete prompts using the optimized system, context, and task templates
/// 
/// NOTE: This is for on-device LLMs only. Cloud API uses the master prompt system.
/// This assembler is kept for backward compatibility with on-device models.
library;

import 'lumara_system_prompt.dart';
import 'lumara_task_templates.dart';
import 'lumara_context_builder.dart';

class LumaraPromptAssembler {
  final LumaraContextBuilder contextBuilder;
  final bool includeFewShotExamples;
  final bool includeQualityGuardrails;

  LumaraPromptAssembler({
    required this.contextBuilder,
    this.includeFewShotExamples = true,
    this.includeQualityGuardrails = true,
  });

  /// Assemble a complete prompt for the LLM
  String assemblePrompt({
    required String userMessage,
    String? customTaskType,
    bool useFewShot = true,
  }) {
    final buffer = StringBuffer();
    
    // 1. System Prompt
    buffer.writeln('<<SYSTEM>>');
    buffer.writeln(LumaraSystemPrompt.universal);
    buffer.writeln();
    
    // 2. Mode-specific addendums (ultra-terse or code-task)
    // Disabled few-shot examples for mobile speed optimization
    
    // 3. Context Block
    buffer.writeln('<<CONTEXT>>');
    buffer.writeln(contextBuilder.buildContextBlock());
    buffer.writeln();
    
    // 4. Task Wrapper
    buffer.writeln('<<TASK>>');
    final taskType = customTaskType ?? LumaraTaskTemplates.detectTaskType(userMessage);
    final taskTemplate = LumaraTaskTemplates.getTaskTemplate(taskType);
    buffer.writeln(taskTemplate);
    buffer.writeln();
    
    // 5. Quality Guardrails - Disabled for mobile speed optimization
    
    // 6. User Message
    buffer.writeln('<<USER>>');
    buffer.writeln(userMessage);
    
    return buffer.toString();
  }

  /// Assemble a minimal prompt (system + user message only)
  String assembleMinimalPrompt(String userMessage) {
    final buffer = StringBuffer();
    
    buffer.writeln('<<SYSTEM>>');
    buffer.writeln(LumaraSystemPrompt.universal);
    buffer.writeln();
    
    buffer.writeln('<<USER>>');
    buffer.writeln(userMessage);
    
    return buffer.toString();
  }

  /// Assemble a prompt with specific task type
  String assemblePromptWithTask({
    required String userMessage,
    required String taskType,
  }) {
    return assemblePrompt(
      userMessage: userMessage,
      customTaskType: taskType,
    );
  }

  /// Create a context builder with user data
  static LumaraContextBuilder createContextBuilder({
    required String userName,
    required String currentPhase,
    List<String> recentKeywords = const [],
    List<String> memorySnippets = const [],
    List<String> journalExcerpts = const [],
    List<String> favoriteExamples = const [],
  }) {
    return LumaraContextBuilder(
      userName: userName,
      currentPhase: currentPhase,
      recentKeywords: recentKeywords,
      memorySnippets: memorySnippets,
      journalExcerpts: journalExcerpts,
      favoriteExamples: favoriteExamples,
    );
  }
}

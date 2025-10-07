/// LUMARA Prompt Assembler for On-Device LLMs
/// 
/// Assembles complete prompts using the optimized system, context, and task templates

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
    
    // 2. Few-Shot Examples (optional)
    if (useFewShot && includeFewShotExamples) {
      buffer.writeln('<<FEWSHOT>>');
      buffer.writeln(LumaraSystemPrompt.fewShotExample1);
      buffer.writeln();
      buffer.writeln(LumaraSystemPrompt.fewShotExample2);
      buffer.writeln();
    }
    
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
    
    // 5. Quality Guardrails (optional)
    if (includeQualityGuardrails) {
      buffer.writeln(LumaraSystemPrompt.qualityGuardrails);
      buffer.writeln();
    }
    
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
  }) {
    return LumaraContextBuilder(
      userName: userName,
      currentPhase: currentPhase,
      recentKeywords: recentKeywords,
      memorySnippets: memorySnippets,
      journalExcerpts: journalExcerpts,
    );
  }
}

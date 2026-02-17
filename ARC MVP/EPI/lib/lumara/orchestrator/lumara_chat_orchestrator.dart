// lib/lumara/orchestrator/lumara_chat_orchestrator.dart
// Chat-based agent orchestration: classify intent → route to Research/Writing/Reflection.

import 'package:my_app/lumara/agents/research/research_agent.dart';
import 'package:my_app/lumara/agents/research/research_models.dart' as agent_models;
import 'package:my_app/lumara/agents/writing/writing_agent.dart';
import 'package:my_app/lumara/agents/writing/writing_models.dart';
import 'package:my_app/lumara/orchestrator/chat_intent_classifier.dart';
import 'package:my_app/lumara/orchestrator/orchestration_violation_checker.dart';
import 'package:my_app/lumara/orchestrator/research_report_adapter.dart';

/// Response type from the chat orchestrator.
enum ChatResponseType {
  /// Use normal LUMARA reflection path (streaming in cubit).
  useReflectionPath,
  /// Research agent finished; message has summary + metadata.reportId.
  researchComplete,
  /// Writing agent finished; message has preview + metadata.draftId.
  writingComplete,
  /// Ask user to clarify intent.
  clarification,
  /// Feature not yet implemented (e.g. pattern).
  notImplemented,
}

/// Response from [LumaraChatOrchestrator.handleMessage].
class ChatOrchestratorResponse {
  final ChatResponseType type;
  final String message;
  final Map<String, dynamic> metadata;

  const ChatOrchestratorResponse({
    required this.type,
    required this.message,
    this.metadata = const {},
  });
}

/// Cache for the latest draft from chat so Agents tab can open it by id.
class ChatDraftCache {
  ChatDraftCache._();
  static final ChatDraftCache instance = ChatDraftCache._();

  final Map<String, ComposedContent> _byId = {};

  void put(String draftId, ComposedContent content) {
    _byId[draftId] = content;
  }

  ComposedContent? get(String draftId) => _byId[draftId];
}

/// Orchestrates LUMARA chat: classify intent, run Research/Writing agents, or delegate to reflection.
class LumaraChatOrchestrator {
  final ChatIntentClassifier _classifier;
  final ResearchAgent _researchAgent;
  final WritingAgent _writingAgent;

  LumaraChatOrchestrator({
    required ChatIntentClassifier classifier,
    required ResearchAgent researchAgent,
    required WritingAgent writingAgent,
  })  : _classifier = classifier,
        _researchAgent = researchAgent,
        _writingAgent = writingAgent;

  /// Classify intent only (for branching before full handleMessage).
  Future<UserIntent> classifyIntent(String message) {
    return _classifier.classifyIntent(message);
  }

  /// Handle a user message. For research/writing, [onProgressUpdate] is called with status text.
  Future<ChatOrchestratorResponse> handleMessage({
    required String userId,
    required String message,
    required void Function(String) onProgressUpdate,
  }) async {
    final intent = await _classifier.classifyIntent(message);

    if (intent.confidence < 0.6) {
      return ChatOrchestratorResponse(
        type: ChatResponseType.clarification,
        message: _generateClarification(),
      );
    }

    switch (intent.type) {
      case ChatIntentType.research:
        return await _handleResearch(
          userId: userId,
          intent: intent,
          onProgressUpdate: onProgressUpdate,
        );
      case ChatIntentType.writing:
        return await _handleWriting(
          userId: userId,
          intent: intent,
          onProgressUpdate: onProgressUpdate,
        );
      case ChatIntentType.pattern:
        return const ChatOrchestratorResponse(
          type: ChatResponseType.notImplemented,
          message: "Pattern analysis coming soon! For now, I can help with research and writing.",
        );
      case ChatIntentType.journaling:
      case ChatIntentType.reflection:
        return const ChatOrchestratorResponse(
          type: ChatResponseType.useReflectionPath,
          message: '',
        );
    }
  }

  Future<ChatOrchestratorResponse> _handleResearch({
    required String userId,
    required UserIntent intent,
    required void Function(String) onProgressUpdate,
  }) async {
    onProgressUpdate(
      "Starting research session with Research Agent. "
      "This may take several minutes to run searches and synthesize findings.\n\n"
      "🔍 Initializing...",
    );

    try {
      final result = await _researchAgent.conductResearch(
        userId: userId,
        query: intent.originalMessage,
        onProgress: (p) {
          onProgressUpdate(
            "🔍 ${p.status}\nProgress: ${p.currentStep}/${p.totalSteps}",
          );
        },
      );

      final uiReport = toUiReport(result.report, result.sessionId);
      var completionMessage = _formatResearchCompletion(result.report);
      completionMessage = _validateAndSanitizeAgentOutput(
        completionMessage,
        agentName: 'ResearchAgent',
      );

      return ChatOrchestratorResponse(
        type: ChatResponseType.researchComplete,
        message: completionMessage,
        metadata: {
          'reportId': result.sessionId,
          'report': uiReport,
          'navigateTo': 'agents/research/${result.sessionId}',
        },
      );
    } catch (e) {
      onProgressUpdate(
        "Research encountered an error: $e\n\n"
        "You can try rephrasing your question or ask me to reflect on the topic instead.",
      );
      return ChatOrchestratorResponse(
        type: ChatResponseType.useReflectionPath,
        message: '',
      );
    }
  }

  Future<ChatOrchestratorResponse> _handleWriting({
    required String userId,
    required UserIntent intent,
    required void Function(String) onProgressUpdate,
  }) async {
    onProgressUpdate(
      "Switching to Writing Agent...",
    );

    try {
      final contentType = _parseContentType(
        intent.parameters['content_type']?.toString(),
      );

      final composed = await _writingAgent.composeContent(
        userId: userId,
        prompt: intent.originalMessage,
        type: contentType,
        onProgress: onProgressUpdate,
      );

      final draftId = 'DRAFT-${DateTime.now().millisecondsSinceEpoch}';
      ChatDraftCache.instance.put(draftId, composed);

      var completionMessage = _formatWritingCompletion(composed);
      completionMessage = _validateAndSanitizeAgentOutput(
        completionMessage,
        agentName: 'WritingAgent',
      );
      return ChatOrchestratorResponse(
        type: ChatResponseType.writingComplete,
        message: completionMessage,
        metadata: {
          'draftId': draftId,
          'composedContent': composed,
          'navigateTo': 'agents/writing/$draftId',
        },
      );
    } catch (e) {
      onProgressUpdate(
        "Writing encountered an error: $e\n\n"
        "You can try again or ask me to reflect on the topic.",
      );
      return ChatOrchestratorResponse(
        type: ChatResponseType.useReflectionPath,
        message: '',
      );
    }
  }

  String _formatResearchCompletion(agent_models.ResearchReport report) {
    final insights = report.keyInsights.take(3).map((i) => '• ${i.statement}').join('\n');
    return '''
Research complete! 📊

**${report.query}**

${report.summary}

**Key Findings:**
$insights

**Sources:** ${report.citations.length} analyzed
**Insights:** ${report.keyInsights.length} identified
**Phase:** ${report.phase.name}

[View Full Report in Agents Tab →]
''';
  }

  String _formatWritingCompletion(ComposedContent composed) {
    final d = composed.draft;
    final voicePct = d.voiceScore != null ? (d.voiceScore! * 100).toInt() : 0;
    final themePct = d.themeAlignment != null ? (d.themeAlignment! * 100).toInt() : 0;
    final preview = d.content.split('\n').take(3).join('\n');
    return '''
Content draft ready! ✍️

**Draft**

Voice match: ${voicePct}%
Theme alignment: ${themePct}%
Word count: ${d.metadata.wordCount}

Preview:
$preview
...

[View & Edit Draft in Agents Tab →]
''';
  }

  ContentType _parseContentType(String? type) {
    if (type == null) return ContentType.linkedIn;
    switch (type.toLowerCase()) {
      case 'substack':
        return ContentType.substack;
      case 'technical':
        return ContentType.technical;
      default:
        return ContentType.linkedIn;
    }
  }

  String _generateClarification() {
    return "I'm not quite sure what you'd like me to do. Could you clarify:\n"
        "• **Research** something? (e.g., \"Research SBIR requirements\")\n"
        "• **Write** content? (e.g., \"Write a LinkedIn post about X\")\n"
        "• **Reflect** on something? (e.g., \"Help me think through this\")";
  }

  /// Validates agent output for orchestration violations; returns sanitized message.
  String _validateAndSanitizeAgentOutput(String message, {required String agentName}) {
    final result = checkAndSanitize(
      agentOutput: message,
      agentName: agentName,
      onViolation: (agent, violation, snippet) {
        logOrchestrationViolation(
          agent: agent,
          violation: violation,
          responseSnippet: snippet,
        );
      },
    );
    return result.sanitized;
  }
}

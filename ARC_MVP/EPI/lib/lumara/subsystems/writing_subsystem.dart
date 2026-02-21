import 'package:my_app/lumara/agents/writing/writing_agent.dart';
import 'package:my_app/lumara/agents/writing/writing_models.dart';
import 'package:my_app/lumara/models/command_intent.dart';
import 'package:my_app/lumara/models/subsystem_result.dart';
import 'package:my_app/lumara/models/intent_type.dart';
import 'package:my_app/lumara/subsystems/subsystem.dart';

/// LUMARA subsystem that handles content-generation intents (LinkedIn, Substack, technical).
///
/// Delegates to [WritingAgent]; returns draft and scores in [SubsystemResult.data].
class WritingSubsystem implements Subsystem {
  final WritingAgent _agent;

  WritingSubsystem({required WritingAgent agent}) : _agent = agent;

  @override
  String get name => 'WRITING';

  @override
  bool canHandle(CommandIntent intent) {
    return intent.type == IntentType.contentGeneration;
  }

  @override
  Future<SubsystemResult> query(CommandIntent intent) async {
    if (intent.userId == null || intent.userId!.isEmpty) {
      return SubsystemResult.error(
        source: name,
        message: 'WRITING requires userId',
      );
    }
    try {
      final contentType = _contentTypeFromIntent(intent);
      final composed = await _agent.composeContent(
        userId: intent.userId!,
        prompt: intent.rawQuery,
        type: contentType,
        maxCritiqueIterations: 2,
      );
      return SubsystemResult(
        source: name,
        data: {
          'draft': composed.draft.content,
          'voiceScore': composed.voiceScore,
          'themeAlignment': composed.themeAlignment,
          'suggestedEdits': composed.suggestedEdits,
          'wordCount': composed.draft.metadata.wordCount,
          'phase': composed.draft.metadata.phase,
        },
        metadata: {
          'contentType': contentType.name,
          'wordCount': composed.draft.metadata.wordCount,
        },
      );
    } catch (e) {
      return SubsystemResult.error(
        source: name,
        message: 'WRITING failed: $e',
      );
    }
  }

  ContentType _contentTypeFromIntent(CommandIntent intent) {
    final domain = intent.domain?.toLowerCase();
    if (domain == 'substack') return ContentType.substack;
    if (domain == 'technical') return ContentType.technical;
    return ContentType.linkedIn;
  }
}

// lib/chronicle/dual/intelligence/interrupt/interrupt_decision_engine.dart
//
// Decides whether to interrupt with a clarifying question.

import '../../models/chronicle_models.dart';
import '../gap/gap_classifier.dart';

class InterruptDecision {
  final bool shouldInterrupt;
  final String? question;
  final String? gapId;

  const InterruptDecision({
    required this.shouldInterrupt,
    this.question,
    this.gapId,
  });
}

/// Modality of the biographical content that triggered the loop.
enum AgenticModality { reflect, chat, voice }

class AgenticContext {
  final String currentPhase;
  final double readinessScore;
  final String? seekingType;
  /// Modality that triggered the loop: reflect (primary), chat, or voice.
  final AgenticModality modality;

  const AgenticContext({
    this.currentPhase = 'unknown',
    this.readinessScore = 0.5,
    this.seekingType,
    this.modality = AgenticModality.chat,
  });
}

/// Decides if we should interrupt; modality-aware (more permissive in reflect/voice).
class InterruptDecisionEngine {
  /// Reflect: more permissive (deepening opportunity). Chat: standard. Voice: similar to reflect.
  Future<InterruptDecision> shouldInterrupt(
    AgenticContext context,
    ClassifiedGaps classified,
  ) async {
    if (classified.clarificationGaps.isEmpty) {
      return const InterruptDecision(shouldInterrupt: false);
    }

    final gap = classified.clarificationGaps.first;

    switch (context.modality) {
      case AgenticModality.reflect:
        return _evaluateReflectInterrupt(context, gap);
      case AgenticModality.voice:
        return _evaluateVoiceInterrupt(context, gap);
      case AgenticModality.chat:
        return _evaluateChatInterrupt(context, classified);
    }
  }

  InterruptDecision _evaluateReflectInterrupt(AgenticContext context, Gap gap) {
    if (gap.severity == GapSeverity.high && context.readinessScore > 0.3) {
      return InterruptDecision(
        shouldInterrupt: true,
        question: _buildDeepeningQuestion(gap),
        gapId: gap.id,
      );
    }
    return const InterruptDecision(shouldInterrupt: false);
  }

  InterruptDecision _evaluateVoiceInterrupt(AgenticContext context, Gap gap) {
    if (gap.severity == GapSeverity.high && context.readinessScore > 0.35) {
      return InterruptDecision(
        shouldInterrupt: true,
        question: _buildDeepeningQuestion(gap),
        gapId: gap.id,
      );
    }
    return const InterruptDecision(shouldInterrupt: false);
  }

  InterruptDecision _evaluateChatInterrupt(
    AgenticContext context,
    ClassifiedGaps classified,
  ) {
    // Skip interrupt for Reflection, Research, and Writing — those have their own flows
    if (context.seekingType == 'Reflection' ||
        context.seekingType == 'Research' ||
        context.seekingType == 'Writing') {
      return const InterruptDecision(shouldInterrupt: false);
    }
    if (context.currentPhase == 'Recovery' && context.readinessScore < 0.4) {
      return const InterruptDecision(shouldInterrupt: false);
    }
    final gap = classified.clarificationGaps.first;
    final value = _calculateInterruptValue(gap);
    if (value > 0.6) {
      return InterruptDecision(
        shouldInterrupt: true,
        question: _buildClarifyingQuestion(gap),
        gapId: gap.id,
      );
    }
    return const InterruptDecision(shouldInterrupt: false);
  }

  String _buildDeepeningQuestion(Gap gap) {
    switch (gap.type) {
      case GapType.causal_gap:
        return 'What specifically about that makes you feel this way?';
      case GapType.motivation_gap:
        return 'What matters most to you about that?';
      case GapType.relationship_gap:
        return 'When you mention them, who specifically comes to mind?';
      default:
        return 'Want to explore that thought deeper?';
    }
  }

  String _buildClarifyingQuestion(Gap gap) {
    switch (gap.type) {
      case GapType.causal_gap:
        return 'Before I respond, help me understand — what specifically triggered this?';
      case GapType.temporal_gap:
        return 'Quick clarification — when did this start?';
      default:
        return 'To give you a better answer — ${gap.description}';
    }
  }

  double _calculateInterruptValue(Gap gap) {
    double value = 0.0;
    if (gap.severity == GapSeverity.high) value += 0.4;
    if (gap.severity == GapSeverity.medium) value += 0.2;
    if (gap.type == GapType.causal_gap) value += 0.3;
    value += (gap.priority / 10) * 0.2;
    return value > 1.0 ? 1.0 : value;
  }
}

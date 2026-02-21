import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/models/reflection_session.dart';
import 'package:my_app/arc/chat/reflection/reflection_pattern_analyzer.dart';
import 'package:my_app/arc/chat/reflection/reflection_emotional_analyzer.dart';

/// Risk signals for reflection sessions.
enum RiskSignal {
  prolongedSession, // >5 exchanges
  rumination, // stuck on same themes
  emotionalDependence, // seeking validation
  avoidancePattern, // avoiding real conversations
}

/// Risk level for intervention decisions.
enum RiskLevel {
  none, // No concerning signals
  low, // 1 signal - notice only
  moderate, // 2 signals - redirect
  high, // 3+ signals - pause required
}

/// Intervention type.
enum InterventionType {
  notice,
  redirect,
  pause,
}

/// Intervention response with message and action.
class InterventionResponse {
  final String message;
  final InterventionType type;
  final Duration? duration;

  InterventionResponse.notice({required this.message})
      : type = InterventionType.notice,
        duration = null;

  InterventionResponse.redirect({required this.message})
      : type = InterventionType.redirect,
        duration = null;

  InterventionResponse.pause({
    required this.message,
    required this.duration,
  }) : type = InterventionType.pause;

  bool get shouldPause => type == InterventionType.pause;
}

/// AURORA service for reflection session monitoring.
class AuroraReflectionService {
  final ReflectionPatternAnalyzer _patternAnalyzer;
  final ReflectionEmotionalAnalyzer _emotionalAnalyzer;

  AuroraReflectionService({
    required ReflectionPatternAnalyzer patternAnalyzer,
    required ReflectionEmotionalAnalyzer emotionalAnalyzer,
  })  : _patternAnalyzer = patternAnalyzer,
        _emotionalAnalyzer = emotionalAnalyzer;

  /// Assess reflection session risk and generate intervention if needed.
  Future<InterventionResponse?> assessReflectionRisk(
    JournalEntry entry,
    ReflectionSession session,
  ) async {
    final signals = <RiskSignal>[];

    if (session.exchanges.length > 5) {
      signals.add(RiskSignal.prolongedSession);
    }

    final isRuminating = await _patternAnalyzer.detectRumination(session);
    if (isRuminating) {
      signals.add(RiskSignal.rumination);
    }

    final validationRatio =
        _emotionalAnalyzer.calculateValidationRatio(session);
    if (validationRatio > 0.5) {
      signals.add(RiskSignal.emotionalDependence);
    }

    final avoidance =
        _emotionalAnalyzer.detectAvoidancePattern(entry, session);
    if (avoidance) {
      signals.add(RiskSignal.avoidancePattern);
    }

    final riskLevel = _calculateRiskLevel(signals);
    return _generateIntervention(signals, riskLevel);
  }

  RiskLevel _calculateRiskLevel(List<RiskSignal> signals) {
    if (signals.isEmpty) return RiskLevel.none;
    if (signals.length == 1) return RiskLevel.low;
    if (signals.length == 2) return RiskLevel.moderate;
    return RiskLevel.high;
  }

  InterventionResponse? _generateIntervention(
    List<RiskSignal> signals,
    RiskLevel riskLevel,
  ) {
    if (riskLevel == RiskLevel.none) return null;

    if (riskLevel == RiskLevel.low) {
      return InterventionResponse.notice(
        message: '''
Quick check: Are you looking for patterns I can help identify? 
Or working up courage for a conversation?

If it's the second, maybe it's time to have that conversation 
rather than rehearse it here.
''',
      );
    }

    if (riskLevel == RiskLevel.moderate) {
      if (signals.contains(RiskSignal.emotionalDependence)) {
        return InterventionResponse.redirect(
          message: '''
These questions are seeking reassurance, not analysis.

Try asking:
- "What does CHRONICLE show about this pattern?"
- "When did I last face something similar?"
- "What helped me decide then?"

I can help you see patterns. I can't tell you what's right for you.
''',
        );
      }

      if (signals.contains(RiskSignal.rumination)) {
        return InterventionResponse.redirect(
          message: '''
You're circling the same questions without moving forward.

Let's try a different approach:
- Check CHRONICLE for when you've faced this before
- Look at what actually worked then
- Or take a break and come back with fresh perspective
''',
        );
      }
    }

    if (riskLevel == RiskLevel.high) {
      if (signals.contains(RiskSignal.avoidancePattern)) {
        return InterventionResponse.pause(
          message: '''
You wrote about needing to talk to someone, then spent several
follow-ups asking me what you should do instead.

Reflection paused for 2 hours—go have that conversation.
''',
          duration: const Duration(hours: 2),
        );
      }
    }

    return null;
  }
}

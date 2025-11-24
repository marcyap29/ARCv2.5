// lib/arc/chat/models/reflective_query_models.dart
// Data models for reflective query requests and structured responses

import 'package:my_app/models/journal_entry_model.dart';

/// Result for Query 1: "Show me three times I handled something hard"
class HandledHardResult {
  final DateTime when;
  final String context;
  final String userWords; // Direct quote from entry (≤20 words)
  final String howHandled; // Clear, concrete action taken
  final String outcome; // How it shifted (grounded, not romanticized)
  final String phase; // ATLAS phase at that time
  final JournalEntry entry; // Reference to original entry

  const HandledHardResult({
    required this.when,
    required this.context,
    required this.userWords,
    required this.howHandled,
    required this.outcome,
    required this.phase,
    required this.entry,
  });

  Map<String, dynamic> toJson() => {
    'when': when.toIso8601String(),
    'context': context,
    'userWords': userWords,
    'howHandled': howHandled,
    'outcome': outcome,
    'phase': phase,
    'entryId': entry.id,
  };
}

/// Result for Query 2: "What was I struggling with around this time last year?"
class TemporalStruggleResult {
  final String theme;
  final String userWords; // Direct quote from entry
  final String phase; // ATLAS phase at that time
  final String? howResolved; // How it resolved (if available)
  final DateTime date;
  final JournalEntry entry; // Reference to original entry

  const TemporalStruggleResult({
    required this.theme,
    required this.userWords,
    required this.phase,
    this.howResolved,
    required this.date,
    required this.entry,
  });

  Map<String, dynamic> toJson() => {
    'theme': theme,
    'userWords': userWords,
    'phase': phase,
    'howResolved': howResolved,
    'date': date.toIso8601String(),
    'entryId': entry.id,
  };
}

/// Result for Query 3: "Which themes have softened in the last six months?"
class ThemeSofteningResult {
  final String theme;
  final int pastIntensity; // Frequency in 3-6 month window
  final int recentIntensity; // Frequency in 0-3 month window
  final String userWordsThen; // Quote from past period
  final String userWordsNow; // Quote from recent period
  final String phaseDynamics; // Phase context explanation
  final JournalEntry? pastEntry; // Example entry from past period
  final JournalEntry? recentEntry; // Example entry from recent period

  const ThemeSofteningResult({
    required this.theme,
    required this.pastIntensity,
    required this.recentIntensity,
    required this.userWordsThen,
    required this.userWordsNow,
    required this.phaseDynamics,
    this.pastEntry,
    this.recentEntry,
  });

  Map<String, dynamic> toJson() => {
    'theme': theme,
    'pastIntensity': pastIntensity,
    'recentIntensity': recentIntensity,
    'userWordsThen': userWordsThen,
    'userWordsNow': userWordsNow,
    'phaseDynamics': phaseDynamics,
    'pastEntryId': pastEntry?.id,
    'recentEntryId': recentEntry?.id,
  };
}

/// Complete result for Query 1
class HandledHardQueryResult {
  final List<HandledHardResult> entries;
  final bool hasTraumaContent;
  final String? safetyMessage;

  const HandledHardQueryResult({
    required this.entries,
    this.hasTraumaContent = false,
    this.safetyMessage,
  });

  Map<String, dynamic> toJson() => {
    'entries': entries.map((e) => e.toJson()).toList(),
    'hasTraumaContent': hasTraumaContent,
    'safetyMessage': safetyMessage,
  };
}

/// Complete result for Query 2
class TemporalStruggleQueryResult {
  final List<TemporalStruggleResult> themes;
  final bool isGriefAnniversary;
  final String? groundingPreface;

  const TemporalStruggleQueryResult({
    required this.themes,
    this.isGriefAnniversary = false,
    this.groundingPreface,
  });

  Map<String, dynamic> toJson() => {
    'themes': themes.map((t) => t.toJson()).toList(),
    'isGriefAnniversary': isGriefAnniversary,
    'groundingPreface': groundingPreface,
  };
}

/// Complete result for Query 3
class ThemeSofteningQueryResult {
  final List<ThemeSofteningResult> themes;
  final bool hasFalsePositives;
  final String? note;

  const ThemeSofteningQueryResult({
    required this.themes,
    this.hasFalsePositives = false,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'themes': themes.map((t) => t.toJson()).toList(),
    'hasFalsePositives': hasFalsePositives,
    'note': note,
  };
}


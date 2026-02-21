// lib/arc/chat/services/reflective_query_formatter.dart
// Formats structured reflective query results into LUMARA's conversational style

import 'package:my_app/arc/chat/models/reflective_query_models.dart';
import 'package:intl/intl.dart';

/// Formats reflective query results into LUMARA's conversational style
class ReflectiveQueryFormatter {
  final DateFormat _dateFormat = DateFormat('MMMM d, yyyy');

  /// Format Query 1: "Show me three times I handled something hard"
  Future<String> formatHandledHard(HandledHardQueryResult result) async {
    if (result.entries.isEmpty) {
      return 'I couldn\'t find specific examples of times you handled difficult situations. '
          'This might mean you haven\'t journaled about those moments yet, or they\'re in entries '
          'that don\'t have the right tags. Would you like to reflect on a recent challenge?';
    }

    final buffer = StringBuffer();
    
    if (result.hasTraumaContent && result.safetyMessage != null) {
      buffer.writeln(result.safetyMessage);
      buffer.writeln();
    }

    buffer.writeln('Here are three times you handled something hard:');
    buffer.writeln();

    for (int i = 0; i < result.entries.length; i++) {
      final entry = result.entries[i];
      buffer.writeln('**Entry ${i + 1}:**');
      buffer.writeln();
      buffer.writeln('*When:* ${_dateFormat.format(entry.when)} — ${entry.phase} phase');
      buffer.writeln();
      buffer.writeln('*Context:* ${entry.context}');
      buffer.writeln();
      buffer.writeln('*Your words:* "${entry.userWords}"');
      buffer.writeln();
      buffer.writeln('*How you handled it:* ${entry.howHandled}');
      buffer.writeln();
      buffer.writeln('*Outcome:* ${entry.outcome}');
      buffer.writeln();
      
      if (i < result.entries.length - 1) {
        buffer.writeln('---');
        buffer.writeln();
      }
    }

    buffer.writeln('Do you want to see the Arcform changes around these times, or extract a common strength across these moments?');

    return buffer.toString();
  }

  /// Format Query 2: "What was I struggling with around this time last year?"
  Future<String> formatTemporalStruggle(TemporalStruggleQueryResult result) async {
    if (result.themes.isEmpty) {
      return result.groundingPreface ?? 
          'There is not much here from around this time in your past entries. '
          'Would you like to start a new reflection for this season of your life?';
    }

    final buffer = StringBuffer();
    
    if (result.isGriefAnniversary && result.groundingPreface != null) {
      buffer.writeln(result.groundingPreface);
      buffer.writeln();
    }

    buffer.writeln('Around this time last year...');
    buffer.writeln();

    for (int i = 0; i < result.themes.length; i++) {
      final theme = result.themes[i];
      buffer.writeln('**Theme ${i + 1}: ${theme.theme}**');
      buffer.writeln();
      buffer.writeln('*Your words:* "${theme.userWords}"');
      buffer.writeln();
      buffer.writeln('*Phase:* This was during ${theme.phase}.');
      
      if (theme.howResolved != null) {
        buffer.writeln();
        buffer.writeln('*How it resolved:* ${theme.howResolved}');
      }
      
      buffer.writeln();
      
      if (i < result.themes.length - 1) {
        buffer.writeln('---');
        buffer.writeln();
      }
    }

    buffer.writeln('Would you like to see what softened since then, or a side-by-side Arcform comparison from last year to now?');

    return buffer.toString();
  }

  /// Format Query 3: "Which themes have softened in the last six months?"
  Future<String> formatThemeSoftening(ThemeSofteningQueryResult result) async {
    if (result.themes.isEmpty) {
      return 'I couldn\'t identify clear themes that have softened in the last six months. '
          'This might mean your journaling patterns have changed, or the themes are still present. '
          'Would you like to explore what themes are currently active?';
    }

    final buffer = StringBuffer();

    if (result.hasFalsePositives && result.note != null) {
      buffer.writeln(result.note);
      buffer.writeln();
    }

    buffer.writeln('Here are themes that have softened in the last six months:');
    buffer.writeln();

    for (int i = 0; i < result.themes.length; i++) {
      final theme = result.themes[i];
      buffer.writeln('**Theme ${i + 1}: "${theme.theme}"**');
      buffer.writeln();
      buffer.writeln('*Past intensity:* Appeared ${theme.pastIntensity} times in the prior 3-6 month window.');
      buffer.writeln('*Recent intensity:* Appeared ${theme.recentIntensity} times in the last 3 months.');
      buffer.writeln();
      buffer.writeln('*Your words (then):* "${theme.userWordsThen}"');
      buffer.writeln();
      buffer.writeln('*Your words (now):* "${theme.userWordsNow}"');
      buffer.writeln();
      buffer.writeln('*Phase dynamics:* ${theme.phaseDynamics}');
      buffer.writeln();
      
      if (i < result.themes.length - 1) {
        buffer.writeln('---');
        buffer.writeln();
      }
    }

    buffer.writeln('Would you like to see which themes strengthened, or help crystallizing what supported this softening?');

    return buffer.toString();
  }
}


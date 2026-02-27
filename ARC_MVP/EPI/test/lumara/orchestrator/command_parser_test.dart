import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/models/intent_type.dart';
import 'package:my_app/lumara/orchestrator/command_parser.dart';

void main() {
  late CommandParser parser;

  setUp(() {
    parser = CommandParser();
  });

  group('CommandParser', () {
    group('Enterprise commands', () {
      test('RETRIEVE ... FROM ... → temporalQuery', () {
        final intent = parser.parse('RETRIEVE CHRONICLE FROM JANUARY');
        expect(intent.type, IntentType.temporalQuery);
        expect(intent.rawQuery, 'RETRIEVE CHRONICLE FROM JANUARY');
      });

      test('retrieve topic from timeframe → temporalQuery', () {
        final intent = parser.parse('retrieve themes from last month');
        expect(intent.type, IntentType.temporalQuery);
      });

      test('SHOW CURRENT PHASE → recentContext', () {
        final intent = parser.parse('SHOW CURRENT PHASE');
        expect(intent.type, IntentType.recentContext);
      });

      test('SHOW USAGE PATTERNS → usagePatterns', () {
        final intent = parser.parse('Show usage patterns');
        expect(intent.type, IntentType.usagePatterns);
      });

      test('SHOW ... AGGREGATION → temporalQuery', () {
        final intent = parser.parse('Show monthly aggregation');
        expect(intent.type, IntentType.temporalQuery);
      });

      test('DECISION SUPPORT FOR ... → decisionSupport', () {
        final intent = parser.parse('Decision support for launch');
        expect(intent.type, IntentType.decisionSupport);
      });

      test('ANALYZE ... ACROSS ... → patternAnalysis', () {
        final intent = parser.parse('Analyze themes across 2024');
        expect(intent.type, IntentType.patternAnalysis);
      });

      test('COMPARE ... AND ... → comparison', () {
        final intent = parser.parse('Compare January and February');
        expect(intent.type, IntentType.comparison);
      });

      test('COMPARE ... VS ... → comparison', () {
        final intent = parser.parse('Compare 2024 vs 2025');
        expect(intent.type, IntentType.comparison);
      });

      test('optimal timing → optimalTiming', () {
        final intent = parser.parse('When is optimal time for reflection?');
        expect(intent.type, IntentType.optimalTiming);
      });
    });

    group('Natural language temporal', () {
      test('tell me about my month → temporalQuery', () {
        final intent = parser.parse('Tell me about my month');
        expect(intent.type, IntentType.temporalQuery);
      });

      test('last year → temporalQuery', () {
        final intent = parser.parse('What happened last year?');
        expect(intent.type, IntentType.temporalQuery);
      });

      test('january → temporalQuery', () {
        final intent = parser.parse('Summarize January');
        expect(intent.type, IntentType.temporalQuery);
      });
    });

    group('Natural language pattern / comparison', () {
      test('pattern wording → patternAnalysis', () {
        final intent = parser.parse('What patterns do you see?');
        expect(intent.type, IntentType.patternAnalysis);
      });

      test('compare wording → comparison', () {
        final intent = parser.parse('What is the difference between then and now?');
        expect(intent.type, IntentType.comparison);
      });
    });

    group('Default', () {
      test('generic question → recentContext', () {
        final intent = parser.parse('How am I doing?');
        expect(intent.type, IntentType.recentContext);
      });

      test('empty string → recentContext', () {
        final intent = parser.parse('');
        expect(intent.type, IntentType.recentContext);
        expect(intent.rawQuery, '');
      });

      test('whitespace-only → recentContext', () {
        final intent = parser.parse('   ');
        expect(intent.type, IntentType.recentContext);
      });
    });

    group('rawQuery preservation', () {
      test('trims and preserves content', () {
        final intent = parser.parse('  RETRIEVE CHRONICLE FROM JANUARY  ');
        expect(intent.rawQuery, 'RETRIEVE CHRONICLE FROM JANUARY');
      });
    });
  });
}

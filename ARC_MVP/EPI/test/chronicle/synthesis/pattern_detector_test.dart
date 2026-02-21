import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/chronicle/synthesis/pattern_detector.dart';
import 'package:my_app/chronicle/storage/raw_entry_schema.dart';

void main() {
  group('PatternDetector', () {
    late PatternDetector detector;

    setUp(() {
      detector = PatternDetector();
    });

    test('extractThemes returns empty list for empty entries', () async {
      final themes = await detector.extractThemes(entries: []);
      expect(themes, isEmpty);
    });

    test('extractThemes identifies dominant themes', () async {
      final entries = [
        RawEntrySchema(
          entryId: 'entry1',
          timestamp: DateTime(2025, 1, 1),
          content: 'Test content 1',
          metadata: RawEntryMetadata(wordCount: 10),
          analysis: RawEntryAnalysis(
            extractedThemes: ['career', 'anxiety'],
            keywords: ['work', 'stress'],
          ),
        ),
        RawEntrySchema(
          entryId: 'entry2',
          timestamp: DateTime(2025, 1, 2),
          content: 'Test content 2',
          metadata: RawEntryMetadata(wordCount: 10),
          analysis: RawEntryAnalysis(
            extractedThemes: ['career', 'motivation'],
            keywords: ['work', 'goal'],
          ),
        ),
        RawEntrySchema(
          entryId: 'entry3',
          timestamp: DateTime(2025, 1, 3),
          content: 'Test content 3',
          metadata: RawEntryMetadata(wordCount: 10),
          analysis: RawEntryAnalysis(
            extractedThemes: ['career'],
            keywords: ['work'],
          ),
        ),
      ];

      final themes = await detector.extractThemes(entries: entries, maxThemes: 3);

      expect(themes.length, greaterThan(0));
      expect(themes.first.name, 'career'); // Most frequent
      expect(themes.first.frequency, 1.0); // Appears in all 3 entries
      expect(themes.first.entryIds.length, 3);
    });

    test('calculatePhaseDistribution returns correct distribution', () {
      final entries = [
        RawEntrySchema(
          entryId: 'entry1',
          timestamp: DateTime(2025, 1, 1),
          content: 'Test',
          metadata: RawEntryMetadata(wordCount: 10),
          analysis: RawEntryAnalysis(
            atlasPhase: 'Expansion',
            extractedThemes: [],
          ),
        ),
        RawEntrySchema(
          entryId: 'entry2',
          timestamp: DateTime(2025, 1, 2),
          content: 'Test',
          metadata: RawEntryMetadata(wordCount: 10),
          analysis: RawEntryAnalysis(
            atlasPhase: 'Expansion',
            extractedThemes: [],
          ),
        ),
        RawEntrySchema(
          entryId: 'entry3',
          timestamp: DateTime(2025, 1, 3),
          content: 'Test',
          metadata: RawEntryMetadata(wordCount: 10),
          analysis: RawEntryAnalysis(
            atlasPhase: 'Consolidation',
            extractedThemes: [],
          ),
        ),
      ];

      final distribution = detector.calculatePhaseDistribution(entries);

      expect(distribution['Expansion'], closeTo(0.667, 0.01));
      expect(distribution['Consolidation'], closeTo(0.333, 0.01));
    });

    test('calculateSentinelTrend calculates average and trend', () {
      final entries = [
        RawEntrySchema(
          entryId: 'entry1',
          timestamp: DateTime(2025, 1, 1),
          content: 'Test',
          metadata: RawEntryMetadata(wordCount: 10),
          analysis: RawEntryAnalysis(
            sentinelScore: SentinelScore(
              emotionalIntensity: 0.5,
              frequency: 0.6,
              density: 0.3,
            ),
            extractedThemes: [],
          ),
        ),
        RawEntrySchema(
          entryId: 'entry2',
          timestamp: DateTime(2025, 1, 2),
          content: 'Test',
          metadata: RawEntryMetadata(wordCount: 10),
          analysis: RawEntryAnalysis(
            sentinelScore: SentinelScore(
              emotionalIntensity: 0.7,
              frequency: 0.8,
              density: 0.5,
            ),
            extractedThemes: [],
          ),
        ),
      ];

      final trend = detector.calculateSentinelTrend(entries);

      expect(trend.average, closeTo(0.4, 0.01)); // (0.3 + 0.5) / 2
      expect(trend.peak, 0.5);
      expect(trend.low, 0.3);
    });

    test('identifySignificantEvents detects phase transitions', () {
      final entries = [
        RawEntrySchema(
          entryId: 'entry1',
          timestamp: DateTime(2025, 1, 1),
          content: 'Test',
          metadata: RawEntryMetadata(wordCount: 10),
          analysis: RawEntryAnalysis(
            atlasPhase: 'Expansion',
            extractedThemes: [],
          ),
        ),
        RawEntrySchema(
          entryId: 'entry2',
          timestamp: DateTime(2025, 1, 2),
          content: 'Test',
          metadata: RawEntryMetadata(wordCount: 10),
          analysis: RawEntryAnalysis(
            atlasPhase: 'Consolidation',
            extractedThemes: [],
          ),
        ),
      ];

      final events = detector.identifySignificantEvents(entries);

      expect(events.length, greaterThan(0));
      expect(events.any((e) => e.type == EventType.phaseTransition), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/arcforms/phase_recommender.dart';

void main() {
  group('PhaseRecommender Integration', () {
    test('should maintain backward compatibility with recommend() method', () {
      final recommendation = PhaseRecommender.recommend(
        emotion: 'excited',
        reason: 'learning',
        text: 'I am excited to learn new things',
        selectedKeywords: ['curious', 'learning'],
      );

      expect(recommendation, isNotNull);
      expect(recommendation, isA<String>());
      expect(['Discovery', 'Expansion', 'Transition', 'Consolidation', 'Recovery', 'Breakthrough'], 
             contains(recommendation));
    });

    test('should provide score() method that returns scores for all phases', () {
      final scores = PhaseRecommender.score(
        emotion: 'excited',
        reason: 'learning',
        text: 'I am excited to learn new things',
        selectedKeywords: ['curious', 'learning'],
      );

      // Should have scores for all 6 phases
      expect(scores.length, equals(6));
      expect(scores.keys, containsAll([
        'Discovery', 'Expansion', 'Transition', 
        'Consolidation', 'Recovery', 'Breakthrough'
      ]));

      // All scores should be between 0 and 1
      for (final score in scores.values) {
        expect(score, greaterThanOrEqualTo(0.0));
        expect(score, lessThanOrEqualTo(1.0));
      }
    });

    test('should provide consistent results between recommend() and score()', () {
      final emotion = 'excited';
      final reason = 'learning';
      final text = 'I am excited to learn new things';
      final keywords = ['curious', 'learning'];

      final recommendation = PhaseRecommender.recommend(
        emotion: emotion,
        reason: reason,
        text: text,
        selectedKeywords: keywords,
      );

      final scores = PhaseRecommender.score(
        emotion: emotion,
        reason: reason,
        text: text,
        selectedKeywords: keywords,
      );

      // The recommended phase should be the highest scoring phase
      final highestScoringPhase = PhaseRecommender.getHighestScoringPhase(scores);
      expect(highestScoringPhase, equals(recommendation));
    });

    test('should handle null keywords gracefully in score() method', () {
      final scores = PhaseRecommender.score(
        emotion: 'happy',
        reason: 'work',
        text: 'I feel good today',
        selectedKeywords: null,
      );

      // Should still return valid scores
      expect(scores.length, equals(6));
      for (final score in scores.values) {
        expect(score, greaterThanOrEqualTo(0.0));
        expect(score, lessThanOrEqualTo(1.0));
      }
    });

    test('should handle empty keywords gracefully in score() method', () {
      final scores = PhaseRecommender.score(
        emotion: 'happy',
        reason: 'work',
        text: 'I feel good today',
        selectedKeywords: [],
      );

      // Should still return valid scores
      expect(scores.length, equals(6));
      for (final score in scores.values) {
        expect(score, greaterThanOrEqualTo(0.0));
        expect(score, lessThanOrEqualTo(1.0));
      }
    });

    test('getHighestScoringPhase should return the phase with highest score', () {
      final scores = {
        'Discovery': 0.1,
        'Expansion': 0.8,
        'Transition': 0.2,
        'Consolidation': 0.3,
        'Recovery': 0.1,
        'Breakthrough': 0.4,
      };

      final highest = PhaseRecommender.getHighestScoringPhase(scores);
      expect(highest, equals('Expansion'));
    });

    test('getScoringSummary should format scores correctly', () {
      final scores = {
        'Discovery': 0.1,
        'Expansion': 0.8,
        'Transition': 0.2,
      };

      final summary = PhaseRecommender.getScoringSummary(scores);
      expect(summary, contains('Expansion: 0.800'));
      expect(summary, contains('Transition: 0.200'));
      expect(summary, contains('Discovery: 0.100'));
    });

    test('should give high score to Recovery for negative emotions', () {
      final scores = PhaseRecommender.score(
        emotion: 'stressed',
        reason: 'work',
        text: 'I am feeling overwhelmed and anxious',
        selectedKeywords: ['stressed', 'anxious'],
      );

      expect(scores['Recovery']!, greaterThan(0.5));
      expect(scores['Recovery']!, greaterThan(scores['Discovery']!));
    });

    test('should give high score to Discovery for curious emotions', () {
      final scores = PhaseRecommender.score(
        emotion: 'excited',
        reason: 'learning',
        text: 'I am curious about new possibilities',
        selectedKeywords: ['curious', 'new'],
      );

      expect(scores['Discovery']!, greaterThan(0.5));
    });

    test('should give high score to Breakthrough for insight keywords', () {
      final scores = PhaseRecommender.score(
        emotion: 'amazed',
        reason: 'reflection',
        text: 'I suddenly realized the truth about my situation',
        selectedKeywords: ['clarity', 'insight', 'breakthrough'],
      );

      expect(scores['Breakthrough']!, greaterThan(0.5));
    });
  });
}


/// Tests for AURORA Circadian Context Models
/// 
/// Tests for CircadianContext and CircadianProfile models
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/aurora/models/circadian_context.dart';

void main() {
  group('CircadianContext', () {
    test('should create with valid parameters', () {
      const context = CircadianContext(
        window: 'morning',
        chronotype: 'morning',
        rhythmScore: 0.75,
      );

      expect(context.window, 'morning');
      expect(context.chronotype, 'morning');
      expect(context.rhythmScore, 0.75);
    });

    test('should identify time windows correctly', () {
      const morningContext = CircadianContext(
        window: 'morning',
        chronotype: 'balanced',
        rhythmScore: 0.5,
      );

      const afternoonContext = CircadianContext(
        window: 'afternoon',
        chronotype: 'balanced',
        rhythmScore: 0.5,
      );

      const eveningContext = CircadianContext(
        window: 'evening',
        chronotype: 'balanced',
        rhythmScore: 0.5,
      );

      expect(morningContext.isMorning, true);
      expect(morningContext.isAfternoon, false);
      expect(morningContext.isEvening, false);

      expect(afternoonContext.isMorning, false);
      expect(afternoonContext.isAfternoon, true);
      expect(afternoonContext.isEvening, false);

      expect(eveningContext.isMorning, false);
      expect(eveningContext.isAfternoon, false);
      expect(eveningContext.isEvening, true);
    });

    test('should identify chronotypes correctly', () {
      const morningPerson = CircadianContext(
        window: 'morning',
        chronotype: 'morning',
        rhythmScore: 0.5,
      );

      const eveningPerson = CircadianContext(
        window: 'evening',
        chronotype: 'evening',
        rhythmScore: 0.5,
      );

      const balancedPerson = CircadianContext(
        window: 'afternoon',
        chronotype: 'balanced',
        rhythmScore: 0.5,
      );

      expect(morningPerson.isMorningPerson, true);
      expect(morningPerson.isEveningPerson, false);
      expect(morningPerson.isBalanced, false);

      expect(eveningPerson.isMorningPerson, false);
      expect(eveningPerson.isEveningPerson, true);
      expect(eveningPerson.isBalanced, false);

      expect(balancedPerson.isMorningPerson, false);
      expect(balancedPerson.isEveningPerson, false);
      expect(balancedPerson.isBalanced, true);
    });

    test('should identify rhythm coherence correctly', () {
      const fragmentedRhythm = CircadianContext(
        window: 'evening',
        chronotype: 'balanced',
        rhythmScore: 0.3,
      );

      const coherentRhythm = CircadianContext(
        window: 'morning',
        chronotype: 'morning',
        rhythmScore: 0.7,
      );

      expect(fragmentedRhythm.isFragmented, true);
      expect(fragmentedRhythm.isCoherent, false);

      expect(coherentRhythm.isFragmented, false);
      expect(coherentRhythm.isCoherent, true);
    });

    test('should serialize and deserialize correctly', () {
      const original = CircadianContext(
        window: 'evening',
        chronotype: 'evening',
        rhythmScore: 0.65,
      );

      final json = original.toJson();
      final restored = CircadianContext.fromJson(json);

      expect(restored.window, original.window);
      expect(restored.chronotype, original.chronotype);
      expect(restored.rhythmScore, original.rhythmScore);
    });

    test('should implement equality correctly', () {
      const context1 = CircadianContext(
        window: 'morning',
        chronotype: 'morning',
        rhythmScore: 0.8,
      );

      const context2 = CircadianContext(
        window: 'morning',
        chronotype: 'morning',
        rhythmScore: 0.8,
      );

      const context3 = CircadianContext(
        window: 'evening',
        chronotype: 'morning',
        rhythmScore: 0.8,
      );

      expect(context1, equals(context2));
      expect(context1, isNot(equals(context3)));
    });
  });

  group('CircadianProfile', () {
    test('should create with valid parameters', () {
      final hourlyActivity = List.generate(24, (i) => i / 24.0);
      final profile = CircadianProfile(
        chronotype: 'morning',
        hourlyActivity: hourlyActivity,
        rhythmScore: 0.8,
        lastUpdated: DateTime.now(),
        entryCount: 15,
      );

      expect(profile.chronotype, 'morning');
      expect(profile.hourlyActivity.length, 24);
      expect(profile.rhythmScore, 0.8);
      expect(profile.entryCount, 15);
    });

    test('should calculate peak hour correctly', () {
      final hourlyActivity = List.filled(24, 0.0);
      hourlyActivity[14] = 0.8; // Peak at 2 PM
      hourlyActivity[6] = 0.6;  // Secondary peak at 6 AM

      final profile = CircadianProfile(
        chronotype: 'balanced',
        hourlyActivity: hourlyActivity,
        rhythmScore: 0.7,
        lastUpdated: DateTime.now(),
        entryCount: 10,
      );

      expect(profile.peakHour, 14);
    });

    test('should get activity for specific hour', () {
      final hourlyActivity = List.generate(24, (i) => i / 24.0);
      final profile = CircadianProfile(
        chronotype: 'evening',
        hourlyActivity: hourlyActivity,
        rhythmScore: 0.6,
        lastUpdated: DateTime.now(),
        entryCount: 8,
      );

      expect(profile.getActivityForHour(12), 0.5); // 12/24
      expect(profile.getActivityForHour(0), 0.0);  // 0/24
      expect(profile.getActivityForHour(23), 23/24); // 23/24
    });

    test('should identify reliable profiles', () {
      final reliableProfile = CircadianProfile(
        chronotype: 'morning',
        hourlyActivity: List.filled(24, 0.04),
        rhythmScore: 0.7,
        lastUpdated: DateTime.now(),
        entryCount: 12,
      );

      final unreliableProfile = CircadianProfile(
        chronotype: 'balanced',
        hourlyActivity: List.filled(24, 0.04),
        rhythmScore: 0.5,
        lastUpdated: DateTime.now(),
        entryCount: 5,
      );

      expect(reliableProfile.isReliable, true);
      expect(unreliableProfile.isReliable, false);
    });

    test('should serialize and deserialize correctly', () {
      final hourlyActivity = List.generate(24, (i) => i / 24.0);
      final original = CircadianProfile(
        chronotype: 'evening',
        hourlyActivity: hourlyActivity,
        rhythmScore: 0.9,
        lastUpdated: DateTime.now(),
        entryCount: 20,
      );

      final json = original.toJson();
      final restored = CircadianProfile.fromJson(json);

      expect(restored.chronotype, original.chronotype);
      expect(restored.hourlyActivity, original.hourlyActivity);
      expect(restored.rhythmScore, original.rhythmScore);
      expect(restored.entryCount, original.entryCount);
    });
  });
}

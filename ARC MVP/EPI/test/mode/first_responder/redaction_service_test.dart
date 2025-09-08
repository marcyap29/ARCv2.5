import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/mode/first_responder/redaction/redaction_service.dart';
import 'package:my_app/mode/first_responder/fr_settings.dart';

void main() {
  group('RedactionService', () {
    late RedactionService redactionService;
    late FRSettings settings;

    setUp(() {
      redactionService = RedactionService();
      settings = FRSettings.defaults();
    });

    group('Name Redaction', () {
      test('should redact proper names', () async {
        const text = 'Spoke with Maria Alvarez at the hospital.';
        final result = await redactionService.redact(
          entryId: 'test-1',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        expect(result, contains('[Name-1]'));
        expect(result, isNot(contains('Maria')));
        expect(result, isNot(contains('Alvarez')));
      });

      test('should not redact common words that match name pattern', () async {
        const text = 'It was Monday and we went to the Hospital.';
        final result = await redactionService.redact(
          entryId: 'test-2',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        expect(result, contains('Monday'));
        expect(result, contains('Hospital')); // Should be redacted as location, not name
      });

      test('should not redact medical abbreviations', () async {
        const text = 'Patient needed CPR and ALS interventions.';
        final result = await redactionService.redact(
          entryId: 'test-3',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        expect(result, contains('CPR'));
        expect(result, contains('ALS'));
      });
    });

    group('Location Redaction', () {
      test('should redact street addresses', () async {
        const text = 'We arrived at 221B Baker St for the emergency.';
        final result = await redactionService.redact(
          entryId: 'test-4',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        expect(result, contains('[Location-1]'));
        expect(result, isNot(contains('221B Baker St')));
      });

      test('should redact intersections', () async {
        const text = 'Accident at Main St and Oak Ave.';
        final result = await redactionService.redact(
          entryId: 'test-5',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        expect(result, contains('[Location-1]'));
        expect(result, isNot(contains('Main St and Oak Ave')));
      });

      test('should redact hospital facilities', () async {
        const text = 'Transported to St. Joseph Hospital.';
        final result = await redactionService.redact(
          entryId: 'test-6',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        expect(result, contains('[Location-1]'));
        expect(result, isNot(contains('St. Joseph Hospital')));
      });
    });

    group('Unit/Callsign Redaction', () {
      test('should redact emergency units', () async {
        const text = 'Medic 12 responded with Engine 7.';
        final result = await redactionService.redact(
          entryId: 'test-7',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        expect(result, contains('[Unit-1]'));
        expect(result, contains('[Unit-2]'));
        expect(result, isNot(contains('Medic 12')));
        expect(result, isNot(contains('Engine 7')));
      });
    });

    group('Time Redaction', () {
      test('should redact time stamps', () async {
        const text = 'Call received at 03:42 AM.';
        final result = await redactionService.redact(
          entryId: 'test-8',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        expect(result, contains('[Time-1]'));
        expect(result, isNot(contains('03:42')));
      });

      test('should redact dates', () async {
        const text = 'Incident occurred on 7/14/2025.';
        final result = await redactionService.redact(
          entryId: 'test-9',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        expect(result, contains('[Time-1]'));
        expect(result, isNot(contains('7/14/2025')));
      });
    });

    group('Contact Information Redaction', () {
      test('should redact phone numbers', () async {
        const text = 'Call me at (415) 555-0199 for updates.';
        final result = await redactionService.redact(
          entryId: 'test-10',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        expect(result, contains('[Contact-1]'));
        expect(result, isNot(contains('(415) 555-0199')));
      });

      test('should redact email addresses', () async {
        const text = 'Send report to john.doe@hospital.org.';
        final result = await redactionService.redact(
          entryId: 'test-11',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        expect(result, contains('[Contact-1]'));
        expect(result, isNot(contains('john.doe@hospital.org')));
      });
    });

    group('GPS Coordinates Redaction', () {
      test('should redact GPS coordinates', () async {
        const text = 'Location was 37.7749, -122.4194.';
        final result = await redactionService.redact(
          entryId: 'test-12',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        expect(result, contains('[Geo-1]'));
        expect(result, isNot(contains('37.7749, -122.4194')));
      });
    });

    group('Stable Placeholders', () {
      test('should use same placeholder for same content', () async {
        const text = 'Maria called, then Maria arrived at scene.';
        final result = await redactionService.redact(
          entryId: 'test-13',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        // Should have only [Name-1] for both instances of Maria
        expect('[Name-1]'.allMatches(result).length, equals(2));
        expect(result, isNot(contains('[Name-2]')));
      });

      test('should use different placeholders for different content', () async {
        const text = 'Maria and John both responded to the call.';
        final result = await redactionService.redact(
          entryId: 'test-14',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        expect(result, contains('[Name-1]'));
        expect(result, contains('[Name-2]'));
        expect(result, isNot(contains('Maria')));
        expect(result, isNot(contains('John')));
      });
    });

    group('Complex Scenarios', () {
      test('should handle complex first responder text', () async {
        const text = '''We arrived 03:42 near 221B Baker St. Medic 12 with Chief 3.
        Spoke with Maria Alvarez at St. Joseph Hospital, 7/14/2025.
        Call me at (415) 555-0199 or john@orbital.ai for follow-up.''';
        
        final result = await redactionService.redact(
          entryId: 'test-15',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        // Should contain various placeholder types
        expect(result, contains('[Time-'));
        expect(result, contains('[Location-'));
        expect(result, contains('[Unit-'));
        expect(result, contains('[Name-'));
        expect(result, contains('[Contact-'));
        
        // Should not contain original sensitive data
        expect(result, isNot(contains('03:42')));
        expect(result, isNot(contains('Baker St')));
        expect(result, isNot(contains('Maria')));
        expect(result, isNot(contains('415')));
      });

      test('should respect temporary allowlist', () async {
        const text = 'Maria called about the incident.';
        final allowlist = {'Maria'};
        
        final result = await redactionService.redact(
          entryId: 'test-16',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
          temporaryAllowlist: allowlist,
        );

        expect(result, contains('Maria'));
        expect(result, isNot(contains('[Name-')));
      });
    });

    group('Edge Cases', () {
      test('should handle empty text', () async {
        const text = '';
        final result = await redactionService.redact(
          entryId: 'test-17',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        expect(result, equals(''));
      });

      test('should handle text with no sensitive content', () async {
        const text = 'The weather was nice today.';
        final result = await redactionService.redact(
          entryId: 'test-18',
          originalText: text,
          createdAt: DateTime.now(),
          settings: settings,
        );

        expect(result, equals(text));
      });

      test('should handle redaction disabled', () async {
        const text = 'Maria called at (415) 555-0199.';
        final disabledSettings = FRSettings.defaults().copyWith(redactionEnabled: false);
        
        final result = await redactionService.redact(
          entryId: 'test-19',
          originalText: text,
          createdAt: DateTime.now(),
          settings: disabledSettings,
        );

        expect(result, equals(text));
      });
    });
  });
}
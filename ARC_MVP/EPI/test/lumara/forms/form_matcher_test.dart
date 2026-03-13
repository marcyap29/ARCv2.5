// test/lumara/forms/form_matcher_test.dart
// Phase 6: FormMatcher unit tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/agents/vision/parsed_document.dart';
import 'package:my_app/lumara/agents/forms/form_matcher.dart';

void main() {
  group('FormMatcher', () {
    test('correct profileKey matched for common labels', () async {
      final doc = ParsedDocument(
        keyFields: const [
          DocumentField(label: 'Full name', value: ''),
          DocumentField(label: 'Email address', value: ''),
          DocumentField(label: 'Phone', value: ''),
          DocumentField(label: 'City', value: ''),
        ],
        rawText: '',
        createdAt: DateTime.now(),
      );
      final profile = {
        'full_name': 'Jane Doe',
        'email': 'jane@example.com',
        'phone': '555-1234',
        'address_city': 'Sydney',
      };
      final matches = FormMatcher.match(doc, profile);
      expect(matches.length, 4);
      expect(matches[0].profileKey, 'full_name');
      expect(matches[0].proposedValue, 'Jane Doe');
      expect(matches[1].profileKey, 'email');
      expect(matches[1].proposedValue, 'jane@example.com');
      expect(matches[2].profileKey, 'phone');
      expect(matches[3].profileKey, 'address_city');
    });

    test('confidence 1.0 for exact match, 0.75 for contains', () async {
      final doc = ParsedDocument(
        keyFields: const [
          DocumentField(label: 'email', value: ''),
          DocumentField(label: 'Your email address', value: ''),
        ],
        rawText: '',
        createdAt: DateTime.now(),
      );
      final profile = {'email': 'a@b.com'};
      final matches = FormMatcher.match(doc, profile);
      expect(matches[0].confidence, 1.0);
      expect(matches[1].confidence, 0.75);
    });

    test('sensitive fields flagged correctly', () async {
      final doc = ParsedDocument(
        keyFields: const [
          DocumentField(label: 'Health insurance number', value: ''),
        ],
        rawText: '',
        createdAt: DateTime.now(),
      );
      final profile = {'health_insurance_number': '12345'};
      final matches = FormMatcher.match(doc, profile);
      expect(matches.length, 1);
      expect(matches[0].isSensitive, true);
      expect(matches[0].profileKey, 'health_insurance_number');
    });

    test('unmatched labels return confidence 0.0', () async {
      final doc = ParsedDocument(
        keyFields: const [
          DocumentField(label: 'Random field', value: ''),
        ],
        rawText: '',
        createdAt: DateTime.now(),
      );
      final matches = FormMatcher.match(doc, {});
      expect(matches.length, 1);
      expect(matches[0].confidence, 0.0);
      expect(matches[0].profileKey, isNull);
      expect(matches[0].proposedValue, isNull);
    });
  });
}

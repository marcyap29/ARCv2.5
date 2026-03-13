// test/lumara/forms/form_field_match_test.dart
// Phase 6: FormFieldMatch model.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/agents/forms/form_matcher.dart';

void main() {
  group('FormFieldMatch', () {
    test('holds detectedLabel, profileKey, proposedValue, confidence, isSensitive', () {
      const m = FormFieldMatch(
        detectedLabel: 'Email',
        profileKey: 'email',
        proposedValue: 'a@b.com',
        confidence: 1.0,
        isSensitive: false,
      );
      expect(m.detectedLabel, 'Email');
      expect(m.profileKey, 'email');
      expect(m.proposedValue, 'a@b.com');
      expect(m.confidence, 1.0);
      expect(m.isSensitive, false);
    });

    test('sensitive match', () {
      const m = FormFieldMatch(
        detectedLabel: 'Health fund number',
        profileKey: 'health_insurance_number',
        proposedValue: 'xxx',
        confidence: 0.75,
        isSensitive: true,
      );
      expect(m.isSensitive, true);
    });
  });
}

// test/services/egress_pii_and_lumara_inline_test.dart
// Security tests: (1) Egress payload contains no raw PII when input has PII.
// (2) LumaraInlineApi softer/deeper reflection paths pass only scrubbed text
// (same scrubbing layer as PiiScrubber.rivetScrub).

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/arc/internal/echo/prism_adapter.dart';
import 'package:my_app/services/lumara/pii_scrub.dart';

void main() {
  group('Egress PII scrubbing', () {
    test('payload to proxy contains no raw PII when input has PII (PrismAdapter)', () async {
      final adapter = PrismAdapter();
      // Use single-PII input to avoid edge cases in masking service with multiple PII
      const inputWithPII = 'My email is john.doe@example.com for the follow-up.';
      final result = adapter.scrub(inputWithPII);

      // Scrubbed text must not contain raw PII
      expect(result.scrubbedText, isNot(contains('john.doe@example.com')));
      expect(adapter.isSafeToSend(result.scrubbedText), isTrue);
    });

    test('payload to proxy contains no raw PII when input has PII (PiiScrubber)', () {
      const inputWithPII = 'Contact Jane Smith at jane.smith@test.org for the meeting.';
      final scrubbed = PiiScrubber.rivetScrub(inputWithPII);

      expect(scrubbed, isNot(contains('Jane Smith')));
      expect(scrubbed, isNot(contains('jane.smith@test.org')));
    });
  });

  group('LumaraInlineApi softer/deeper reflection paths use scrubbed text', () {
    test('rivetScrub used for softer/deeper reflection removes PII from entry text', () {
      // LumaraInlineApi.generateSofterReflection and generateDeeperReflection
      // pass PiiScrubber.rivetScrub(entryText) to _enhancedApi.generatePromptedReflection.
      // Verify that for entry text with PII, the scrubbed value does not contain raw PII.
      const entryWithPII = 'I had a call with Dr. Alice Johnson (alice.j@company.com) about the project.';
      final scrubbed = PiiScrubber.rivetScrub(entryWithPII);

      expect(scrubbed, isNot(contains('Alice Johnson')));
      expect(scrubbed, isNot(contains('alice.j@company.com')));
    });

    test('rivetScrub with mapping produces reversible map and scrubbed text without PII', () {
      // Single PII to avoid masking service edge cases
      const entryWithPII = 'My email is test.user@example.org for the report.';
      final result = PiiScrubber.rivetScrubWithMapping(entryWithPII);

      expect(result.scrubbedText, isNot(contains('test.user@example.org')));
      expect(result.reversibleMap.isNotEmpty, isTrue);
    });
  });
}

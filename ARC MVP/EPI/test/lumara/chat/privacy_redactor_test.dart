import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/lumara/chat/privacy_redactor.dart';

void main() {
  group('ChatPrivacyRedactor Tests', () {
    group('PII Detection', () {
      test('should detect email addresses', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: false);
        const content = 'My email is john.doe@example.com for contact';

        final result = redactor.processContent(content);

        expect(result.containsPii, true);
        expect(result.detectedPatterns.length, 1);
        expect(result.detectedPatterns.first, 'john.doe@example.com');
      });

      test('should detect phone numbers', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: false);

        // Test various phone formats
        final testCases = [
          '555-123-4567',
          '555.123.4567',
          '5551234567',
          '(555) 123-4567',
        ];

        for (final phone in testCases) {
          final result = redactor.processContent('Call me at $phone');
          expect(result.containsPii, true, reason: 'Failed to detect: $phone');
        }
      });

      test('should detect SSN pattern', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: false);
        const content = 'SSN: 123-45-6789';

        final result = redactor.processContent(content);

        expect(result.containsPii, true);
        expect(result.detectedPatterns.first, '123-45-6789');
      });

      test('should detect credit card numbers', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: false);
        const content = 'Card: 4532-1234-5678-9012';

        final result = redactor.processContent(content);

        expect(result.containsPii, true);
        expect(result.detectedPatterns.first, '4532-1234-5678-9012');
      });

      test('should detect IP addresses', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: false);
        const content = 'Server IP: 192.168.1.100';

        final result = redactor.processContent(content);

        expect(result.containsPii, true);
        expect(result.detectedPatterns.first, '192.168.1.100');
      });

      test('should detect multiple PII types in single message', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: false);
        const content = 'Contact: john@test.com or 555-1234 at IP 10.0.0.1';

        final result = redactor.processContent(content);

        expect(result.containsPii, true);
        expect(result.detectedPatterns.length, 3);
        expect(result.detectedPatterns, contains('john@test.com'));
        expect(result.detectedPatterns, contains('555-1234'));
        expect(result.detectedPatterns, contains('10.0.0.1'));
      });

      test('should not detect false positives', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: false);
        const content = 'The version is 1.2.3 and the score was 98.7';

        final result = redactor.processContent(content);

        expect(result.containsPii, false);
        expect(result.detectedPatterns, isEmpty);
      });
    });

    group('Content Redaction', () {
      test('should mask PII when maskPii is enabled', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: true);
        const content = 'Email me at test@example.com';

        final result = redactor.processContent(content);

        expect(result.content, 'Email me at [REDACTED-1]');
        expect(result.containsPii, true);
      });

      test('should preserve original content when maskPii is disabled', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: false);
        const content = 'Email me at test@example.com';

        final result = redactor.processContent(content);

        expect(result.content, content);
        expect(result.containsPii, true);
      });

      test('should redact multiple instances with incremental numbering', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: true);
        const content = 'Call 555-1234 or 555-5678 for help';

        final result = redactor.processContent(content);

        expect(result.content, 'Call [REDACTED-1] or [REDACTED-2] for help');
        expect(result.detectedPatterns.length, 2);
      });

      test('should handle content with no PII', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: true);
        const content = 'This is a normal message without any sensitive data';

        final result = redactor.processContent(content);

        expect(result.content, content);
        expect(result.containsPii, false);
        expect(result.detectedPatterns, isEmpty);
      });

      test('should handle empty content', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: true);
        const content = '';

        final result = redactor.processContent(content);

        expect(result.content, '');
        expect(result.containsPii, false);
        expect(result.detectedPatterns, isEmpty);
      });
    });

    group('Hash Generation', () {
      test('should generate hash when preserveHashes is enabled', () {
        const redactor = ChatPrivacyRedactor(
          enabled: true,
          preserveHashes: true,
          maskPii: false,
        );
        const content = 'Test content for hashing';

        final result = redactor.processContent(content);

        expect(result.originalHash, isNotNull);
        expect(result.originalHash!.length, 64); // SHA-256 hex length
      });

      test('should not generate hash when preserveHashes is disabled', () {
        const redactor = ChatPrivacyRedactor(
          enabled: true,
          preserveHashes: false,
          maskPii: false,
        );
        const content = 'Test content without hashing';

        final result = redactor.processContent(content);

        expect(result.originalHash, isNull);
      });

      test('should generate consistent hashes for same content', () {
        const redactor = ChatPrivacyRedactor(
          enabled: true,
          preserveHashes: true,
          maskPii: false,
        );
        const content = 'Consistent content';

        final result1 = redactor.processContent(content);
        final result2 = redactor.processContent(content);

        expect(result1.originalHash, equals(result2.originalHash));
      });

      test('should generate different hashes for different content', () {
        const redactor = ChatPrivacyRedactor(
          enabled: true,
          preserveHashes: true,
          maskPii: false,
        );

        final result1 = redactor.processContent('Content A');
        final result2 = redactor.processContent('Content B');

        expect(result1.originalHash, isNot(equals(result2.originalHash)));
      });
    });

    group('Privacy Result Metadata', () {
      test('should generate privacy metadata for PII content', () {
        const redactor = ChatPrivacyRedactor(
          enabled: true,
          maskPii: true,
          preserveHashes: true,
        );
        const content = 'Contact: test@example.com or 555-1234';

        final result = redactor.processContent(content);
        final metadata = result.getPrivacyMetadata();

        expect(metadata['contains_pii'], true);
        expect(metadata['redacted_fields'], ['content']);
        expect(metadata['detected_patterns'], 2);
        expect(metadata['original_hash'], isNotNull);
      });

      test('should generate privacy metadata for clean content', () {
        const redactor = ChatPrivacyRedactor(
          enabled: true,
          maskPii: true,
          preserveHashes: true,
        );
        const content = 'This is clean content';

        final result = redactor.processContent(content);
        final metadata = result.getPrivacyMetadata();

        expect(metadata['contains_pii'], false);
        expect(metadata['redacted_fields'], isEmpty);
        expect(metadata['detected_patterns'], 0);
        expect(metadata['original_hash'], isNotNull);
      });
    });

    group('Redactor Configuration', () {
      test('should bypass processing when disabled', () {
        const redactor = ChatPrivacyRedactor(enabled: false);
        const content = 'Email: test@example.com, Phone: 555-1234';

        final result = redactor.processContent(content);

        expect(result.content, content);
        expect(result.containsPii, false);
        expect(result.detectedPatterns, isEmpty);
      });

      test('should preserve hash even when disabled', () {
        const redactor = ChatPrivacyRedactor(
          enabled: false,
          preserveHashes: true,
        );
        const content = 'Test content';

        final result = redactor.processContent(content);

        expect(result.originalHash, isNotNull);
      });

      test('should not preserve hash when disabled and preserveHashes is false', () {
        const redactor = ChatPrivacyRedactor(
          enabled: false,
          preserveHashes: false,
        );
        const content = 'Test content';

        final result = redactor.processContent(content);

        expect(result.originalHash, isNull);
      });
    });

    group('Edge Cases', () {
      test('should handle special characters in content', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: true);
        const content = 'Special chars: ñáéíóú and email test@domain.co.uk';

        final result = redactor.processContent(content);

        expect(result.content, 'Special chars: ñáéíóú and email [REDACTED-1]');
        expect(result.containsPii, true);
      });

      test('should handle very long content', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: true);
        final longContent = 'A' * 10000 + ' test@example.com ' + 'B' * 10000;

        final result = redactor.processContent(longContent);

        expect(result.containsPii, true);
        expect(result.content, contains('[REDACTED-1]'));
        expect(result.content.length, lessThan(longContent.length));
      });

      test('should handle content with only PII', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: true);
        const content = 'test@example.com';

        final result = redactor.processContent(content);

        expect(result.content, '[REDACTED-1]');
        expect(result.containsPii, true);
      });

      test('should handle repeated PII patterns', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: true);
        const content = 'test@example.com and test@example.com again';

        final result = redactor.processContent(content);

        expect(result.content, '[REDACTED-1] and [REDACTED-2] again');
        expect(result.detectedPatterns.length, 2);
        expect(result.detectedPatterns.every((p) => p == 'test@example.com'), true);
      });

      test('should handle malformed patterns that might match partially', () {
        const redactor = ChatPrivacyRedactor(enabled: true, maskPii: false);
        const content = 'Almost phone: 555-12-34567 and almost email: test@';

        final result = redactor.processContent(content);

        // Should not detect malformed patterns
        expect(result.containsPii, false);
        expect(result.detectedPatterns, isEmpty);
      });
    });
  });
}
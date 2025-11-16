// test/arc/arcform/share/arcform_share_test.dart
// Unit tests for Arcform sharing system

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/arc/arcform/share/arcform_share_models.dart';
import 'package:my_app/arc/arcform/share/lumara_share_service.dart';

void main() {
  group('ArcformSharePayload', () {
    test('should create payload with required fields', () {
      final payload = ArcformSharePayload(
        shareMode: ArcShareMode.social,
        arcformId: 'test-id',
        phase: 'Discovery',
        keywords: ['growth', 'insight'],
      );

      expect(payload.shareMode, ArcShareMode.social);
      expect(payload.arcformId, 'test-id');
      expect(payload.phase, 'Discovery');
      expect(payload.keywords, ['growth', 'insight']);
    });

    test('should prioritize user message over system message for direct share', () {
      final payload = ArcformSharePayload(
        shareMode: ArcShareMode.direct,
        arcformId: 'test-id',
        phase: 'Discovery',
        keywords: ['growth'],
        systemMessage: 'System message',
        userMessage: 'User message',
      );

      expect(payload.getFinalMessage(), 'User message');
    });

    test('should fall back to system message if no user message for direct share', () {
      final payload = ArcformSharePayload(
        shareMode: ArcShareMode.direct,
        arcformId: 'test-id',
        phase: 'Discovery',
        keywords: ['growth'],
        systemMessage: 'System message',
      );

      expect(payload.getFinalMessage(), 'System message');
    });

    test('should prioritize user caption over system caption for social share', () {
      final payload = ArcformSharePayload(
        shareMode: ArcShareMode.social,
        arcformId: 'test-id',
        phase: 'Discovery',
        keywords: ['growth'],
        systemCaptionShort: 'System caption',
        userCaption: 'User caption',
      );

      expect(payload.getFinalMessage(), 'User caption');
    });

    test('should get selected system caption by preference', () {
      final payload = ArcformSharePayload(
        shareMode: ArcShareMode.social,
        arcformId: 'test-id',
        phase: 'Discovery',
        keywords: ['growth'],
        systemCaptionShort: 'Short caption',
        systemCaptionReflective: 'Reflective caption',
        systemCaptionTechnical: 'Technical caption',
      );

      expect(payload.getSelectedSystemCaption('short'), 'Short caption');
      expect(payload.getSelectedSystemCaption('reflective'), 'Reflective caption');
      expect(payload.getSelectedSystemCaption('technical'), 'Technical caption');
      expect(payload.getSelectedSystemCaption(null), 'Short caption');
    });

    test('should copy with new values', () {
      final payload = ArcformSharePayload(
        shareMode: ArcShareMode.direct,
        arcformId: 'test-id',
        phase: 'Discovery',
        keywords: ['growth'],
      );

      final updated = payload.copyWith(
        shareMode: ArcShareMode.social,
        userMessage: 'New message',
      );

      expect(updated.shareMode, ArcShareMode.social);
      expect(updated.userMessage, 'New message');
      expect(updated.arcformId, 'test-id'); // Unchanged
    });
  });

  group('LumaraShareService - Privacy Rules', () {
    test('should validate payload without journal content patterns', () {
      final service = LumaraShareService();
      final payload = ArcformSharePayload(
        shareMode: ArcShareMode.social,
        arcformId: 'test-id',
        phase: 'Discovery',
        keywords: ['growth'],
        userCaption: 'Sharing my Discovery phase journey',
      );

      expect(service.validatePrivacyRules(payload), true);
    });

    test('should reject payload with journal content patterns', () {
      final service = LumaraShareService();
      final payload = ArcformSharePayload(
        shareMode: ArcShareMode.social,
        arcformId: 'test-id',
        phase: 'Discovery',
        keywords: ['growth'],
        userCaption: 'I wrote in my journal today about growth',
      );

      expect(service.validatePrivacyRules(payload), false);
    });

    test('should reject payload with inferred personal attributes', () {
      final service = LumaraShareService();
      final payload = ArcformSharePayload(
        shareMode: ArcShareMode.social,
        arcformId: 'test-id',
        phase: 'Discovery',
        keywords: ['growth'],
        userCaption: 'My medical diagnosis shows growth',
      );

      expect(service.validatePrivacyRules(payload), false);
    });
  });
}


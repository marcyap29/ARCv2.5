import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/services/lazy_photo_relink_service.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';

void main() {
  group('LazyPhotoRelinkService', () {
    group('hasPlaceholders', () {
      test('returns true when text contains photo placeholders', () {
        const text = 'This is a test [PHOTO:photo_1234567890123] with placeholder';
        expect(LazyPhotoRelinkService.hasPlaceholders(text), true);
      });

      test('returns false when text has no placeholders', () {
        const text = 'This is a test without placeholders';
        expect(LazyPhotoRelinkService.hasPlaceholders(text), false);
      });

      test('returns false when text is null', () {
        expect(LazyPhotoRelinkService.hasPlaceholders(null), false);
      });
    });

    group('hasRealMedia', () {
      test('returns true when entry has real media', () {
        final entry = JournalEntry(
          id: 'test',
          title: 'Test',
          content: 'Test content',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          emotion: 'neutral',
          tags: const [],
          mood: 'neutral',
          media: [
            MediaItem(
              id: 'media1',
              type: MediaType.image,
              uri: 'ph://real-photo-id',
              createdAt: DateTime.now(),
            ),
          ],
        );
        expect(LazyPhotoRelinkService.hasRealMedia(entry), true);
      });

      test('returns false when entry has only placeholder media', () {
        final entry = JournalEntry(
          id: 'test',
          title: 'Test',
          content: 'Test content',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          emotion: 'neutral',
          tags: const [],
          mood: 'neutral',
          media: [
            MediaItem(
              id: 'media1',
              type: MediaType.image,
              uri: 'placeholder://photo_123',
              createdAt: DateTime.now(),
            ),
          ],
        );
        expect(LazyPhotoRelinkService.hasRealMedia(entry), false);
      });

      test('returns false when entry has no media', () {
        final entry = JournalEntry(
          id: 'test',
          title: 'Test',
          content: 'Test content',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          emotion: 'neutral',
          tags: const [],
          mood: 'neutral',
          media: const [],
        );
        expect(LazyPhotoRelinkService.hasRealMedia(entry), false);
      });
    });

    group('extractPhotoIds', () {
      test('extracts photo IDs from text with multiple placeholders', () {
        const text = 'Photo 1 [PHOTO:photo_1234567890123] and photo 2 [PHOTO:photo_4567890123456]';
        final ids = LazyPhotoRelinkService.extractPhotoIds(text);
        expect(ids, ['photo_1234567890123', 'photo_4567890123456']);
      });

      test('returns empty list when no placeholders found', () {
        const text = 'No placeholders here';
        final ids = LazyPhotoRelinkService.extractPhotoIds(text);
        expect(ids, []);
      });

      test('returns empty list when text is null', () {
        final ids = LazyPhotoRelinkService.extractPhotoIds(null);
        expect(ids, []);
      });
    });

    group('metaFromPlaceholder', () {
      test('extracts timestamp from valid placeholder ID', () {
        final meta = LazyPhotoRelinkService.metaFromPlaceholder('photo_1760654962279');
        expect(meta['placeholder_id'], 'photo_1760654962279');
        expect(meta['creation_date'], isA<String>());
        expect(meta['creation_date'], contains('2025'));
      });

      test('handles invalid placeholder ID', () {
        final meta = LazyPhotoRelinkService.metaFromPlaceholder('invalid_id');
        expect(meta['placeholder_id'], 'invalid_id');
        expect(meta['creation_date'], isNull);
      });
    });

    group('mergeMedia', () {
      test('replaces placeholders with real media', () {
        final current = [
          MediaItem(
            id: 'photo_123',
            type: MediaType.image,
            uri: 'placeholder://photo_123',
            createdAt: DateTime.now(),
          ),
        ];
        final real = [
          MediaItem(
            id: 'photo_123',
            type: MediaType.image,
            uri: 'ph://real-photo-id',
            createdAt: DateTime.now(),
          ),
        ];
        final merged = LazyPhotoRelinkService.mergeMedia(current, real);
        expect(merged.length, 1);
        expect(merged.first.uri, 'ph://real-photo-id');
      });

      test('keeps existing real media when new is placeholder', () {
        final current = [
          MediaItem(
            id: 'photo_123',
            type: MediaType.image,
            uri: 'ph://real-photo-id',
            createdAt: DateTime.now(),
          ),
        ];
        final real = [
          MediaItem(
            id: 'photo_123',
            type: MediaType.image,
            uri: 'placeholder://photo_123',
            createdAt: DateTime.now(),
          ),
        ];
        final merged = LazyPhotoRelinkService.mergeMedia(current, real);
        expect(merged.length, 1);
        expect(merged.first.uri, 'ph://real-photo-id');
      });
    });

    group('shouldAttemptRelink', () {
      test('returns true when entry needs relinking', () {
        final entry = JournalEntry(
          id: 'test',
          title: 'Test',
          content: 'Test [PHOTO:photo_1234567890123] content',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          emotion: 'neutral',
          tags: const [],
          mood: 'neutral',
          media: [
            MediaItem(
              id: 'photo_1234567890123',
              type: MediaType.image,
              uri: 'placeholder://photo_1234567890123',
              createdAt: DateTime.now(),
            ),
          ],
        );
        expect(LazyPhotoRelinkService.shouldAttemptRelink(entry), true);
      });

      test('returns false when entry has no placeholders', () {
        final entry = JournalEntry(
          id: 'test',
          title: 'Test',
          content: 'Test content without placeholders',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          emotion: 'neutral',
          tags: const [],
          mood: 'neutral',
          media: const [],
        );
        expect(LazyPhotoRelinkService.shouldAttemptRelink(entry), false);
      });

      test('returns false when entry already has real media', () {
        final entry = JournalEntry(
          id: 'test',
          title: 'Test',
          content: 'Test [PHOTO:photo_1234567890123] content',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          emotion: 'neutral',
          tags: const [],
          mood: 'neutral',
          media: [
            MediaItem(
              id: 'photo_1234567890123',
              type: MediaType.image,
              uri: 'ph://real-photo-id',
              createdAt: DateTime.now(),
            ),
          ],
        );
        expect(LazyPhotoRelinkService.shouldAttemptRelink(entry), false);
      });
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/services/lazy_photo_relink_service.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';

void main() {
  group('LazyPhotoRelinkService Tests', () {
    test('hasPlaceholders detects photo placeholders correctly', () {
      expect(LazyPhotoRelinkService.hasPlaceholders('No photos here'), false);
      expect(LazyPhotoRelinkService.hasPlaceholders('[PHOTO:photo_1760654962279]'), true);
      expect(LazyPhotoRelinkService.hasPlaceholders('Text with [PHOTO:photo_1760654962279] and [PHOTO:photo_1760654963373]'), true);
      expect(LazyPhotoRelinkService.hasPlaceholders(null), false);
    });

    test('hasRealMedia detects real media vs placeholders', () {
      final entryWithRealMedia = JournalEntry(
        id: 'test1',
        title: 'Test Entry',
        content: 'Test content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mood: 'neutral',
        tags: [],
        media: [
          MediaItem(
            id: 'photo1',
            uri: 'ph://real-photo-id',
            type: MediaType.image,
            createdAt: DateTime.now(),
          ),
        ],
      );

      final entryWithPlaceholders = JournalEntry(
        id: 'test2',
        title: 'Test Entry 2',
        content: 'Test content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mood: 'neutral',
        tags: [],
        media: [
          MediaItem(
            id: 'photo1',
            uri: 'placeholder://photo_1760654962279',
            type: MediaType.image,
            createdAt: DateTime.now(),
          ),
        ],
      );

      final entryWithNoMedia = JournalEntry(
        id: 'test3',
        title: 'Test Entry 3',
        content: 'Test content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mood: 'neutral',
        tags: [],
        media: [],
      );

      expect(LazyPhotoRelinkService.hasRealMedia(entryWithRealMedia), true);
      expect(LazyPhotoRelinkService.hasRealMedia(entryWithPlaceholders), false);
      expect(LazyPhotoRelinkService.hasRealMedia(entryWithNoMedia), false);
    });

    test('extractPhotoIds extracts photo IDs from text', () {
      final text = 'Text with [PHOTO:photo_1760654962279] and [PHOTO:photo_1760654963373] photos';
      final ids = LazyPhotoRelinkService.extractPhotoIds(text);
      
      expect(ids.length, 2);
      expect(ids, contains('photo_1760654962279'));
      expect(ids, contains('photo_1760654963373'));
    });

    test('extractPhotoIds handles empty or null text', () {
      expect(LazyPhotoRelinkService.extractPhotoIds(null), isEmpty);
      expect(LazyPhotoRelinkService.extractPhotoIds(''), isEmpty);
      expect(LazyPhotoRelinkService.extractPhotoIds('No photos here'), isEmpty);
    });

    test('metaFromPlaceholder creates metadata from timestamp', () {
      final placeholderId = 'photo_1760654962279';
      final metadata = LazyPhotoRelinkService.metaFromPlaceholder(placeholderId);
      
      expect(metadata['placeholder_id'], equals(placeholderId));
      expect(metadata['creation_date'], isNotNull);
      
      // Verify the timestamp is correct
      final expectedDate = DateTime.fromMillisecondsSinceEpoch(1760654962279, isUtc: true);
      final actualDate = DateTime.parse(metadata['creation_date'] as String);
      expect(actualDate, equals(expectedDate));
    });

    test('metaFromPlaceholder handles invalid placeholder IDs', () {
      final invalidId = 'invalid_photo_id';
      final metadata = LazyPhotoRelinkService.metaFromPlaceholder(invalidId);
      
      expect(metadata['placeholder_id'], equals(invalidId));
      expect(metadata.length, equals(1)); // Only placeholder_id should be present
    });

    test('mergeMedia replaces placeholders with real URIs', () {
      final current = [
        MediaItem(
          id: 'photo1',
          uri: 'placeholder://photo_1760654962279',
          type: MediaType.image,
          createdAt: DateTime.now(),
        ),
        MediaItem(
          id: 'photo2',
          uri: 'ph://real-photo-id',
          type: MediaType.image,
          createdAt: DateTime.now(),
        ),
      ];

      final real = [
        MediaItem(
          id: 'photo1',
          uri: 'ph://resolved-photo-id',
          type: MediaType.image,
          createdAt: DateTime.now(),
        ),
        MediaItem(
          id: 'photo3',
          uri: 'ph://new-photo-id',
          type: MediaType.image,
          createdAt: DateTime.now(),
        ),
      ];

      final merged = LazyPhotoRelinkService.mergeMedia(current, real);
      
      expect(merged.length, 3);
      
      final photo1 = merged.firstWhere((m) => m.id == 'photo1');
      expect(photo1.uri, equals('ph://resolved-photo-id')); // Should be replaced
      
      final photo2 = merged.firstWhere((m) => m.id == 'photo2');
      expect(photo2.uri, equals('ph://real-photo-id')); // Should remain unchanged
      
      final photo3 = merged.firstWhere((m) => m.id == 'photo3');
      expect(photo3.uri, equals('ph://new-photo-id')); // Should be added
    });

    test('shouldAttemptRelink respects cooldown and in-flight guards', () {
      final now = DateTime.now();
      final entry = JournalEntry(
        id: 'test',
        title: 'Test Entry',
        content: 'Test content',
        createdAt: now,
        updatedAt: now,
        mood: 'neutral',
        tags: [],
        media: [],
        metadata: {
          'last_relink_attempt': now.millisecondsSinceEpoch - 1000, // 1 second ago
        },
      );

      // Should not attempt if too soon (cooldown)
      expect(LazyPhotoRelinkService.shouldAttemptRelink(entry), false);
    });

    test('shouldAttemptRelink allows relinking after cooldown', () {
      final now = DateTime.now();
      final entry = JournalEntry(
        id: 'test',
        title: 'Test Entry',
        content: 'Test content',
        createdAt: now,
        updatedAt: now,
        mood: 'neutral',
        tags: [],
        media: [],
        metadata: {
          'last_relink_attempt': now.millisecondsSinceEpoch - 400000, // 6+ minutes ago
        },
      );

      // Should attempt if cooldown has passed
      expect(LazyPhotoRelinkService.shouldAttemptRelink(entry), true);
    });
  });
}

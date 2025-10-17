import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/services/lazy_photo_relink_service.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';

void main() {
  group('Photo Relink Integration Tests', () {
    group('Complete Relink Flow', () {
      test('reconstructs media from text with placeholders', () async {
        const text = 'This is a test [PHOTO:photo_1234567890] with placeholder';
        final nodeMetadata = {
          'photos': [
            {
              'placeholder_id': 'photo_1234567890',
              'local_identifier': 'ph://real-photo-id',
              'creation_date': '2024-01-01T12:00:00.000Z',
            },
          ],
        };

        final mediaItems = await LazyPhotoRelinkService.reconstructMediaFromText(
          text: text,
          nodeMetadata: nodeMetadata,
        );

        expect(mediaItems.length, 1);
        expect(mediaItems.first.id, 'photo_1234567890');
        expect(mediaItems.first.type, MediaType.image);
        // Note: In a real test, you'd mock the PhotoLibraryService calls
        // and verify the URI resolution
      });

      test('handles missing metadata gracefully', () async {
        const text = 'This is a test [PHOTO:photo_1234567890] with placeholder';
        final nodeMetadata = <String, dynamic>{};

        final mediaItems = await LazyPhotoRelinkService.reconstructMediaFromText(
          text: text,
          nodeMetadata: nodeMetadata,
        );

        expect(mediaItems.length, 1);
        expect(mediaItems.first.id, 'photo_1234567890');
        expect(mediaItems.first.uri, startsWith('placeholder://'));
      });

      test('handles multiple photo placeholders', () async {
        const text = 'Photo 1 [PHOTO:photo_1] and photo 2 [PHOTO:photo_2]';
        final nodeMetadata = {
          'photos': [
            {
              'placeholder_id': 'photo_1',
              'local_identifier': 'ph://real-photo-1',
            },
            {
              'placeholder_id': 'photo_2',
              'local_identifier': 'ph://real-photo-2',
            },
          ],
        };

        final mediaItems = await LazyPhotoRelinkService.reconstructMediaFromText(
          text: text,
          nodeMetadata: nodeMetadata,
        );

        expect(mediaItems.length, 2);
        expect(mediaItems.map((m) => m.id).toList(), ['photo_1', 'photo_2']);
      });
    });

    group('Media Merging', () {
      test('merges new media with existing media', () {
        final current = [
          MediaItem(
            id: 'photo_1',
            type: MediaType.image,
            uri: 'placeholder://photo_1',
            createdAt: DateTime.now(),
          ),
          MediaItem(
            id: 'photo_2',
            type: MediaType.image,
            uri: 'ph://real-photo-2',
            createdAt: DateTime.now(),
          ),
        ];

        final real = [
          MediaItem(
            id: 'photo_1',
            type: MediaType.image,
            uri: 'ph://real-photo-1',
            createdAt: DateTime.now(),
          ),
          MediaItem(
            id: 'photo_2',
            type: MediaType.image,
            uri: 'placeholder://photo_2',
            createdAt: DateTime.now(),
          ),
        ];

        final merged = LazyPhotoRelinkService.mergeMedia(current, real);

        expect(merged.length, 2);
        expect(merged.firstWhere((m) => m.id == 'photo_1').uri, 'ph://real-photo-1');
        expect(merged.firstWhere((m) => m.id == 'photo_2').uri, 'ph://real-photo-2');
      });
    });

    group('Error Handling', () {
      test('handles malformed placeholder IDs', () async {
        const text = 'This is a test [PHOTO:invalid_id] with placeholder';
        final nodeMetadata = <String, dynamic>{};

        final mediaItems = await LazyPhotoRelinkService.reconstructMediaFromText(
          text: text,
          nodeMetadata: nodeMetadata,
        );

        expect(mediaItems.length, 1);
        expect(mediaItems.first.id, 'invalid_id');
        expect(mediaItems.first.uri, startsWith('placeholder://'));
      });

      test('handles empty text', () async {
        const text = '';
        final nodeMetadata = <String, dynamic>{};

        final mediaItems = await LazyPhotoRelinkService.reconstructMediaFromText(
          text: text,
          nodeMetadata: nodeMetadata,
        );

        expect(mediaItems.length, 0);
      });

      test('handles null metadata', () async {
        const text = 'This is a test [PHOTO:photo_123] with placeholder';

        final mediaItems = await LazyPhotoRelinkService.reconstructMediaFromText(
          text: text,
          nodeMetadata: null,
        );

        expect(mediaItems.length, 1);
        expect(mediaItems.first.uri, startsWith('placeholder://'));
      });
    });
  });
}

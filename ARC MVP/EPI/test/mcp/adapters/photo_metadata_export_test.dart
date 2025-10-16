import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/mcp/adapters/journal_entry_projector.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/data/models/photo_metadata.dart';

void main() {
  group('Photo Metadata Export Tests', () {
    test('_extractPhotoMetadataFromContent extracts placeholders correctly', () async {
      // Test content with photo placeholders
      final content = 'This is a test entry with [PHOTO:photo_1760654962279] and [PHOTO:photo_1760654963373] photos.';
      
      // Create mock media items
      final mediaItems = [
        MediaItem(
          id: 'photo_1760654962279',
          uri: 'ph://test-local-id-1',
          type: MediaType.image,
          createdAt: DateTime.now(),
        ),
        MediaItem(
          id: 'photo_1760654963373',
          uri: 'ph://test-local-id-2',
          type: MediaType.image,
          createdAt: DateTime.now(),
        ),
      ];

      final result = await McpEntryProjector._extractPhotoMetadataFromContent(content, mediaItems);

      expect(result.length, equals(2));
      
      // Check first photo
      final firstPhoto = result.firstWhere((p) => p['placeholder_id'] == 'photo_1760654962279');
      expect(firstPhoto['placeholder_id'], equals('photo_1760654962279'));
      expect(firstPhoto['local_identifier'], isNull); // Will be null in test since we can't call PhotoLibraryService
      expect(firstPhoto['creation_date'], isNull);
      expect(firstPhoto['pixel_width'], isNull);
      expect(firstPhoto['pixel_height'], isNull);
      expect(firstPhoto['filename'], isNull);
      expect(firstPhoto['uniform_type_identifier'], isNull);
      expect(firstPhoto['perceptual_hash'], isNull);

      // Check second photo
      final secondPhoto = result.firstWhere((p) => p['placeholder_id'] == 'photo_1760654963373');
      expect(secondPhoto['placeholder_id'], equals('photo_1760654963373'));
      expect(secondPhoto['local_identifier'], isNull);
    });

    test('_extractPhotoMetadataFromContent handles content without placeholders', () async {
      final content = 'This is a test entry without any photos.';
      final mediaItems = <MediaItem>[];

      final result = await McpEntryProjector._extractPhotoMetadataFromContent(content, mediaItems);

      expect(result.length, equals(0));
    });

    test('_extractPhotoMetadataFromContent handles mismatched media items', () async {
      final content = 'This is a test entry with [PHOTO:photo_1760654962279] photo.';
      
      // Create media item with different ID
      final mediaItems = [
        MediaItem(
          id: 'different_photo_id',
          uri: 'ph://test-local-id',
          type: MediaType.image,
          createdAt: DateTime.now(),
        ),
      ];

      final result = await McpEntryProjector._extractPhotoMetadataFromContent(content, mediaItems);

      expect(result.length, equals(1));
      expect(result.first['placeholder_id'], equals('photo_1760654962279'));
      expect(result.first['local_identifier'], isNull); // Should be null since no matching media item
    });

    test('_extractPhotoMetadataFromContent handles non-ph:// URIs', () async {
      final content = 'This is a test entry with [PHOTO:photo_1760654962279] photo.';
      
      // Create media item with file:// URI instead of ph://
      final mediaItems = [
        MediaItem(
          id: 'photo_1760654962279',
          uri: 'file:///path/to/photo.jpg',
          type: MediaType.image,
          createdAt: DateTime.now(),
        ),
      ];

      final result = await McpEntryProjector._extractPhotoMetadataFromContent(content, mediaItems);

      expect(result.length, equals(1));
      expect(result.first['placeholder_id'], equals('photo_1760654962279'));
      expect(result.first['local_identifier'], isNull); // Should be null since not ph:// URI
    });

    test('_extractPhotoMetadataFromContent handles duplicate placeholders', () async {
      final content = 'This is a test entry with [PHOTO:photo_1760654962279] and [PHOTO:photo_1760654962279] duplicate photos.';
      
      final mediaItems = [
        MediaItem(
          id: 'photo_1760654962279',
          uri: 'ph://test-local-id',
          type: MediaType.image,
          createdAt: DateTime.now(),
        ),
      ];

      final result = await McpEntryProjector._extractPhotoMetadataFromContent(content, mediaItems);

      expect(result.length, equals(2)); // Should create entries for both placeholders
      expect(result.every((p) => p['placeholder_id'] == 'photo_1760654962279'), isTrue);
    });

    test('_extractPhotoMetadataFromContent handles malformed placeholders', () async {
      final content = 'This is a test entry with [PHOTO:] and [PHOTO:photo_1760654962279] photos.';
      
      final mediaItems = <MediaItem>[];

      final result = await McpEntryProjector._extractPhotoMetadataFromContent(content, mediaItems);

      expect(result.length, equals(1)); // Only the valid placeholder should be extracted
      expect(result.first['placeholder_id'], equals('photo_1760654962279'));
    });
  });
}

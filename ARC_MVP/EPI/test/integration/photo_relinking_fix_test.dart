import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/services/lazy_photo_relink_service.dart';
import 'package:my_app/data/models/photo_metadata.dart';

void main() {
  group('Photo Relinking Fix Tests', () {
    test('metaFromPlaceholder includes timestampMs', () {
      // Test that metaFromPlaceholder extracts timestampMs correctly
      const placeholderId = 'photo_1760666100393';
      final metadata = LazyPhotoRelinkService.metaFromPlaceholder(placeholderId);
      
      expect(metadata['placeholder_id'], equals(placeholderId));
      expect(metadata['creation_date'], isNotNull);
      expect(metadata['timestampMs'], equals(1760666100393));
      
      // Verify the timestamp is correct
      final expectedDate = DateTime.fromMillisecondsSinceEpoch(1760666100393, isUtc: true);
      final actualDate = DateTime.parse(metadata['creation_date']);
      expect(actualDate, equals(expectedDate));
    });

    test('PhotoMetadata includes timestampMs in JSON', () {
      // Test that PhotoMetadata properly serializes timestampMs
      final metadata = PhotoMetadata(
        localIdentifier: 'test-id',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1760666100393, isUtc: true),
        filename: 'test.jpg',
        pixelWidth: 1920,
        pixelHeight: 1080,
        timestampMs: 1760666100393,
      );
      
      final json = metadata.toJson();
      expect(json['timestampMs'], equals(1760666100393));
      expect(json['creation_date'], equals('2025-10-17T01:55:00.393Z'));
      expect(json['filename'], equals('test.jpg'));
      expect(json['pixel_width'], equals(1920));
      expect(json['pixel_height'], equals(1080));
    });

    test('PhotoMetadata fromJson includes timestampMs', () {
      // Test that PhotoMetadata properly deserializes timestampMs
      final json = {
        'local_identifier': 'test-id',
        'creation_date': '2025-10-17T01:55:00.393Z',
        'filename': 'test.jpg',
        'pixel_width': 1920,
        'pixel_height': 1080,
        'timestampMs': 1760666100393,
      };
      
      final metadata = PhotoMetadata.fromJson(json);
      expect(metadata.timestampMs, equals(1760666100393));
      expect(metadata.creationDate, equals(DateTime.parse('2025-10-17T01:55:00.393Z')));
      expect(metadata.filename, equals('test.jpg'));
      expect(metadata.pixelWidth, equals(1920));
      expect(metadata.pixelHeight, equals(1080));
    });

    test('PhotoMetadata copyWith includes timestampMs', () {
      // Test that PhotoMetadata copyWith properly handles timestampMs
      final original = PhotoMetadata(
        localIdentifier: 'test-id',
        creationDate: DateTime.fromMillisecondsSinceEpoch(1760666100393, isUtc: true),
        filename: 'test.jpg',
        timestampMs: 1760666100393,
      );
      
      final updated = original.copyWith(
        filename: 'updated.jpg',
        timestampMs: 1760666101234,
      );
      
      expect(updated.localIdentifier, equals('test-id'));
      expect(updated.filename, equals('updated.jpg'));
      expect(updated.timestampMs, equals(1760666101234));
      expect(updated.creationDate, equals(original.creationDate));
    });

    test('placeholder ID parsing handles various formats', () {
      // Test various placeholder ID formats
      final testCases = [
        ('photo_1760666100393', 1760666100393),
        ('photo_1234567890123', 1234567890123),
        ('photo_9999999999999', 9999999999999),
      ];
      
      for (final (placeholderId, expectedMs) in testCases) {
        final metadata = LazyPhotoRelinkService.metaFromPlaceholder(placeholderId);
        expect(metadata['timestampMs'], equals(expectedMs));
        
        final expectedDate = DateTime.fromMillisecondsSinceEpoch(expectedMs, isUtc: true);
        final actualDate = DateTime.parse(metadata['creation_date']);
        expect(actualDate, equals(expectedDate));
      }
    });

    test('placeholder ID parsing handles invalid formats gracefully', () {
      // Test invalid placeholder ID formats
      final invalidCases = [
        'photo_invalid',
        'not_photo_1234567890123',
        'photo_',
        'photo_abc123',
        '',
        'photo_12345678901234567890', // Too long
      ];
      
      for (final invalidId in invalidCases) {
        final metadata = LazyPhotoRelinkService.metaFromPlaceholder(invalidId);
        expect(metadata['placeholder_id'], equals(invalidId));
        expect(metadata['creation_date'], isNull);
        expect(metadata['timestampMs'], isNull);
      }
    });

    test('metadata extraction with timestampMs from node metadata', () {
      // Test that timestampMs is properly extracted from node metadata
      final nodeMetadata = {
        'photos': [
          {
            'placeholder_id': 'photo_1760666100393',
            'local_identifier': 'ABC123-DEF456',
            'creation_date': '2025-10-17T01:55:00.393Z',
            'filename': 'IMG_1234.JPG',
            'pixel_width': 1920,
            'pixel_height': 1080,
            'timestampMs': 1760666100393,
          }
        ]
      };
      
      const placeholderId = 'photo_1760666100393';
      final photos = (nodeMetadata['photos'] as List).cast<Map<String, dynamic>>();
      final found = photos.firstWhere(
        (m) => m['placeholder_id'] == placeholderId,
        orElse: () => {},
      );
      
      expect(found['timestampMs'], equals(1760666100393));
      expect(found['local_identifier'], equals('ABC123-DEF456'));
      expect(found['filename'], equals('IMG_1234.JPG'));
    });
  });
}

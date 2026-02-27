import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/data/models/photo_metadata.dart';

void main() {
  group('PhotoMetadata', () {
    late PhotoMetadata testMetadata;
    late Map<String, dynamic> testJson;

    setUp(() {
      testMetadata = PhotoMetadata(
        localIdentifier: 'ABC123-DEF456-GHI789',
        creationDate: DateTime(2025, 1, 15, 10, 30, 0),
        modificationDate: DateTime(2025, 1, 15, 11, 45, 0),
        filename: 'IMG_1234.JPG',
        fileSize: 2456789,
        pixelWidth: 3024,
        pixelHeight: 4032,
        perceptualHash: 'a1b2c3d4e5f6',
      );

      testJson = {
        'local_identifier': 'ABC123-DEF456-GHI789',
        'creation_date': '2025-01-15T10:30:00.000',
        'modification_date': '2025-01-15T11:45:00.000',
        'filename': 'IMG_1234.JPG',
        'file_size': 2456789,
        'pixel_width': 3024,
        'pixel_height': 4032,
        'perceptual_hash': 'a1b2c3d4e5f6',
      };
    });

    test('toJson converts all fields correctly', () {
      final json = testMetadata.toJson();
      
      expect(json['local_identifier'], 'ABC123-DEF456-GHI789');
      expect(json['creation_date'], '2025-01-15T10:30:00.000');
      expect(json['modification_date'], '2025-01-15T11:45:00.000');
      expect(json['filename'], 'IMG_1234.JPG');
      expect(json['file_size'], 2456789);
      expect(json['pixel_width'], 3024);
      expect(json['pixel_height'], 4032);
      expect(json['perceptual_hash'], 'a1b2c3d4e5f6');
    });

    test('fromJson parses all fields correctly', () {
      final metadata = PhotoMetadata.fromJson(testJson);
      
      expect(metadata.localIdentifier, 'ABC123-DEF456-GHI789');
      expect(metadata.creationDate, DateTime(2025, 1, 15, 10, 30, 0));
      expect(metadata.modificationDate, DateTime(2025, 1, 15, 11, 45, 0));
      expect(metadata.filename, 'IMG_1234.JPG');
      expect(metadata.fileSize, 2456789);
      expect(metadata.pixelWidth, 3024);
      expect(metadata.pixelHeight, 4032);
      expect(metadata.perceptualHash, 'a1b2c3d4e5f6');
    });

    test('handles null optional fields', () {
      final minimalJson = {
        'local_identifier': 'ABC123-DEF456-GHI789',
      };
      
      final metadata = PhotoMetadata.fromJson(minimalJson);
      
      expect(metadata.localIdentifier, 'ABC123-DEF456-GHI789');
      expect(metadata.creationDate, isNull);
      expect(metadata.modificationDate, isNull);
      expect(metadata.filename, isNull);
      expect(metadata.fileSize, isNull);
      expect(metadata.pixelWidth, isNull);
      expect(metadata.pixelHeight, isNull);
      expect(metadata.perceptualHash, isNull);
    });

    test('roundtrip toJson -> fromJson preserves data', () {
      final json = testMetadata.toJson();
      final reconstructed = PhotoMetadata.fromJson(json);
      
      expect(reconstructed, equals(testMetadata));
      expect(reconstructed.hashCode, equals(testMetadata.hashCode));
    });

    test('handles partial JSON data', () {
      final partialJson = {
        'local_identifier': 'ABC123-DEF456-GHI789',
        'creation_date': '2025-01-15T10:30:00.000',
        'filename': 'IMG_1234.JPG',
        'file_size': 2456789,
        // Missing: modification_date, pixel_width, pixel_height, perceptual_hash
      };
      
      final metadata = PhotoMetadata.fromJson(partialJson);
      
      expect(metadata.localIdentifier, 'ABC123-DEF456-GHI789');
      expect(metadata.creationDate, DateTime(2025, 1, 15, 10, 30, 0));
      expect(metadata.filename, 'IMG_1234.JPG');
      expect(metadata.fileSize, 2456789);
      expect(metadata.modificationDate, isNull);
      expect(metadata.pixelWidth, isNull);
      expect(metadata.pixelHeight, isNull);
      expect(metadata.perceptualHash, isNull);
    });

    test('hasMinimumData returns true when enough data present', () {
      final metadataWithMinData = PhotoMetadata(
        localIdentifier: 'ABC123',
        creationDate: DateTime.now(),
      );
      
      expect(metadataWithMinData.hasMinimumData, isTrue);
    });

    test('hasMinimumData returns true with filename', () {
      const metadataWithFilename = PhotoMetadata(
        localIdentifier: 'ABC123',
        filename: 'IMG_1234.JPG',
      );
      
      expect(metadataWithFilename.hasMinimumData, isTrue);
    });

    test('hasMinimumData returns true with fileSize', () {
      const metadataWithFileSize = PhotoMetadata(
        localIdentifier: 'ABC123',
        fileSize: 1234567,
      );
      
      expect(metadataWithFileSize.hasMinimumData, isTrue);
    });

    test('hasMinimumData returns false with only identifier', () {
      const metadataWithOnlyId = PhotoMetadata(
        localIdentifier: 'ABC123',
      );
      
      expect(metadataWithOnlyId.hasMinimumData, isFalse);
    });

    test('hasMinimumData returns false with empty identifier', () {
      final metadataWithEmptyId = PhotoMetadata(
        localIdentifier: '',
        creationDate: DateTime.now(),
      );
      
      expect(metadataWithEmptyId.hasMinimumData, isFalse);
    });

    test('description includes all available fields', () {
      final description = testMetadata.description;
      
      expect(description, contains('ID: ABC123-DEF456-GHI789'));
      expect(description, contains('File: IMG_1234.JPG'));
      expect(description, contains('Created: 2025-01-15T10:30:00.000'));
      expect(description, contains('Size: 2456789 bytes'));
      expect(description, contains('Dimensions: 3024x4032'));
    });

    test('description handles minimal data', () {
      const minimalMetadata = PhotoMetadata(
        localIdentifier: 'ABC123',
      );
      
      final description = minimalMetadata.description;
      expect(description, equals('ID: ABC123'));
    });

    test('copyWith updates specified fields', () {
      final updated = testMetadata.copyWith(
        filename: 'NEW_IMAGE.JPG',
        fileSize: 3000000,
      );
      
      expect(updated.localIdentifier, testMetadata.localIdentifier);
      expect(updated.creationDate, testMetadata.creationDate);
      expect(updated.filename, 'NEW_IMAGE.JPG');
      expect(updated.fileSize, 3000000);
      expect(updated.pixelWidth, testMetadata.pixelWidth);
    });

    test('copyWith preserves original when no changes', () {
      final unchanged = testMetadata.copyWith();
      
      expect(unchanged, equals(testMetadata));
    });

    test('equality works correctly', () {
      final identicalMetadata = PhotoMetadata(
        localIdentifier: 'ABC123-DEF456-GHI789',
        creationDate: DateTime(2025, 1, 15, 10, 30, 0),
        modificationDate: DateTime(2025, 1, 15, 11, 45, 0),
        filename: 'IMG_1234.JPG',
        fileSize: 2456789,
        pixelWidth: 3024,
        pixelHeight: 4032,
        perceptualHash: 'a1b2c3d4e5f6',
      );
      
      expect(testMetadata, equals(identicalMetadata));
      expect(testMetadata.hashCode, equals(identicalMetadata.hashCode));
    });

    test('toString includes description', () {
      final string = testMetadata.toString();
      
      expect(string, contains('PhotoMetadata'));
      expect(string, contains('ID: ABC123-DEF456-GHI789'));
    });
  });
}

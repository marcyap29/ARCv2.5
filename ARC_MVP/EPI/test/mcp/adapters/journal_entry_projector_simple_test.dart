import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/data/models/photo_metadata.dart';

void main() {
  group('Photo Metadata Export (Simple)', () {
    test('PhotoMetadata serialization works correctly', () {
      // Test that PhotoMetadata can be serialized and deserialized
      final metadata = PhotoMetadata(
        localIdentifier: 'test-photo-id',
        creationDate: DateTime(2025, 1, 15, 10, 30, 0),
        modificationDate: DateTime(2025, 1, 15, 11, 45, 0),
        filename: 'IMG_1234.JPG',
        fileSize: 2456789,
        pixelWidth: 3024,
        pixelHeight: 4032,
        perceptualHash: 'a1b2c3d4e5f6',
      );
      
      // Test toJson
      final json = metadata.toJson();
      expect(json['local_identifier'], 'test-photo-id');
      expect(json['filename'], 'IMG_1234.JPG');
      expect(json['file_size'], 2456789);
      expect(json['pixel_width'], 3024);
      expect(json['pixel_height'], 4032);
      expect(json['perceptual_hash'], 'a1b2c3d4e5f6');
      
      // Test fromJson
      final reconstructed = PhotoMetadata.fromJson(json);
      expect(reconstructed.localIdentifier, 'test-photo-id');
      expect(reconstructed.filename, 'IMG_1234.JPG');
      expect(reconstructed.fileSize, 2456789);
      expect(reconstructed.pixelWidth, 3024);
      expect(reconstructed.pixelHeight, 4032);
      expect(reconstructed.perceptualHash, 'a1b2c3d4e5f6');
      
      // Test equality
      expect(reconstructed, equals(metadata));
    });
    
    test('PhotoMetadata handles minimal data', () {
      const minimalMetadata = PhotoMetadata(
        localIdentifier: 'minimal-id',
      );
      
      expect(minimalMetadata.hasMinimumData, isFalse);
      expect(minimalMetadata.description, 'ID: minimal-id');
    });
    
    test('PhotoMetadata hasMinimumData works correctly', () {
      // Test with creation date
      final withDate = PhotoMetadata(
        localIdentifier: 'test-id',
        creationDate: DateTime.now(),
      );
      expect(withDate.hasMinimumData, isTrue);
      
      // Test with filename
      const withFilename = PhotoMetadata(
        localIdentifier: 'test-id',
        filename: 'test.jpg',
      );
      expect(withFilename.hasMinimumData, isTrue);
      
      // Test with file size
      const withFileSize = PhotoMetadata(
        localIdentifier: 'test-id',
        fileSize: 123456,
      );
      expect(withFileSize.hasMinimumData, isTrue);
      
      // Test with only identifier
      const onlyId = PhotoMetadata(
        localIdentifier: 'test-id',
      );
      expect(onlyId.hasMinimumData, isFalse);
    });
    
    test('PhotoMetadata JSON roundtrip preserves all data', () {
      final original = PhotoMetadata(
        localIdentifier: 'roundtrip-test-id',
        creationDate: DateTime(2025, 1, 15, 10, 30, 0),
        modificationDate: DateTime(2025, 1, 15, 11, 45, 0),
        filename: 'ROUNDTRIP_TEST.JPG',
        fileSize: 9876543,
        pixelWidth: 1920,
        pixelHeight: 1080,
        perceptualHash: 'f1e2d3c4b5a6',
      );
      
      // Convert to JSON and back
      final json = original.toJson();
      final reconstructed = PhotoMetadata.fromJson(json);
      
      // Verify all fields are preserved
      expect(reconstructed.localIdentifier, original.localIdentifier);
      expect(reconstructed.creationDate, original.creationDate);
      expect(reconstructed.modificationDate, original.modificationDate);
      expect(reconstructed.filename, original.filename);
      expect(reconstructed.fileSize, original.fileSize);
      expect(reconstructed.pixelWidth, original.pixelWidth);
      expect(reconstructed.pixelHeight, original.pixelHeight);
      expect(reconstructed.perceptualHash, original.perceptualHash);
      
      // Verify equality
      expect(reconstructed, equals(original));
      expect(reconstructed.hashCode, equals(original.hashCode));
    });
    
    test('PhotoMetadata handles null values correctly', () {
      final jsonWithNulls = {
        'local_identifier': 'null-test-id',
        'creation_date': null,
        'modification_date': null,
        'filename': null,
        'file_size': null,
        'pixel_width': null,
        'pixel_height': null,
        'perceptual_hash': null,
      };
      
      final metadata = PhotoMetadata.fromJson(jsonWithNulls);
      
      expect(metadata.localIdentifier, 'null-test-id');
      expect(metadata.creationDate, isNull);
      expect(metadata.modificationDate, isNull);
      expect(metadata.filename, isNull);
      expect(metadata.fileSize, isNull);
      expect(metadata.pixelWidth, isNull);
      expect(metadata.pixelHeight, isNull);
      expect(metadata.perceptualHash, isNull);
    });
    
    test('PhotoMetadata copyWith works correctly', () {
      final original = PhotoMetadata(
        localIdentifier: 'copy-test-id',
        creationDate: DateTime(2025, 1, 15, 10, 30, 0),
        filename: 'ORIGINAL.JPG',
        fileSize: 1000000,
      );
      
      final updated = original.copyWith(
        filename: 'UPDATED.JPG',
        fileSize: 2000000,
        pixelWidth: 1920,
        pixelHeight: 1080,
      );
      
      // Verify updated fields
      expect(updated.filename, 'UPDATED.JPG');
      expect(updated.fileSize, 2000000);
      expect(updated.pixelWidth, 1920);
      expect(updated.pixelHeight, 1080);
      
      // Verify unchanged fields
      expect(updated.localIdentifier, original.localIdentifier);
      expect(updated.creationDate, original.creationDate);
      
      // Verify original is unchanged
      expect(original.filename, 'ORIGINAL.JPG');
      expect(original.fileSize, 1000000);
      expect(original.pixelWidth, isNull);
      expect(original.pixelHeight, isNull);
    });
  });
}

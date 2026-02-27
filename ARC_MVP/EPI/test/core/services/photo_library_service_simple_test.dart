import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/data/models/photo_metadata.dart';

void main() {
  group('PhotoLibraryService Metadata (Simple)', () {
    test('PhotoMetadata model works correctly', () {
      // Test that PhotoMetadata can be created and serialized
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
      
      // Test fromJson
      final reconstructed = PhotoMetadata.fromJson(json);
      expect(reconstructed.localIdentifier, 'test-photo-id');
      expect(reconstructed.filename, 'IMG_1234.JPG');
      expect(reconstructed.fileSize, 2456789);
      
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
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/data/models/photo_metadata.dart';

void main() {
  group('Photo Metadata Integration', () {
    test('PhotoMetadata can be used in MCP export/import cycle', () {
      // Simulate the metadata that would be stored in MCP export
      final originalMetadata = PhotoMetadata(
        localIdentifier: 'ABC123-DEF456-GHI789',
        creationDate: DateTime(2025, 1, 15, 10, 30, 0),
        modificationDate: DateTime(2025, 1, 15, 11, 45, 0),
        filename: 'IMG_1234.JPG',
        fileSize: 2456789,
        pixelWidth: 3024,
        pixelHeight: 4032,
        perceptualHash: 'a1b2c3d4e5f6',
      );
      
      // Simulate MCP export: convert to JSON
      final exportJson = originalMetadata.toJson();
      
      // Verify export contains all necessary fields
      expect(exportJson['local_identifier'], 'ABC123-DEF456-GHI789');
      expect(exportJson['creation_date'], '2025-01-15T10:30:00.000');
      expect(exportJson['filename'], 'IMG_1234.JPG');
      expect(exportJson['file_size'], 2456789);
      expect(exportJson['pixel_width'], 3024);
      expect(exportJson['pixel_height'], 4032);
      expect(exportJson['perceptual_hash'], 'a1b2c3d4e5f6');
      
      // Simulate MCP import: convert back from JSON
      final importedMetadata = PhotoMetadata.fromJson(exportJson);
      
      // Verify all data is preserved
      expect(importedMetadata.localIdentifier, originalMetadata.localIdentifier);
      expect(importedMetadata.creationDate, originalMetadata.creationDate);
      expect(importedMetadata.modificationDate, originalMetadata.modificationDate);
      expect(importedMetadata.filename, originalMetadata.filename);
      expect(importedMetadata.fileSize, originalMetadata.fileSize);
      expect(importedMetadata.pixelWidth, originalMetadata.pixelWidth);
      expect(importedMetadata.pixelHeight, originalMetadata.pixelHeight);
      expect(importedMetadata.perceptualHash, originalMetadata.perceptualHash);
      
      // Verify equality
      expect(importedMetadata, equals(originalMetadata));
      
      // Verify metadata has enough data for matching
      expect(importedMetadata.hasMinimumData, isTrue);
      
      // Verify description is useful for debugging
      final description = importedMetadata.description;
      expect(description, contains('ABC123-DEF456-GHI789'));
      expect(description, contains('IMG_1234.JPG'));
      expect(description, contains('2025-01-15T10:30:00.000'));
      expect(description, contains('2456789 bytes'));
      expect(description, contains('3024x4032'));
    });
    
    test('PhotoMetadata handles missing data gracefully', () {
      // Simulate metadata with some missing fields
      const partialMetadata = PhotoMetadata(
        localIdentifier: 'PARTIAL-ID',
        filename: 'PARTIAL.JPG',
        // Missing: creationDate, fileSize, dimensions, hash
      );
      
      // Should still be valid for matching
      expect(partialMetadata.hasMinimumData, isTrue);
      
      // Export should work
      final json = partialMetadata.toJson();
      expect(json['local_identifier'], 'PARTIAL-ID');
      expect(json['filename'], 'PARTIAL.JPG');
      expect(json['creation_date'], isNull);
      expect(json['file_size'], isNull);
      
      // Import should work
      final imported = PhotoMetadata.fromJson(json);
      expect(imported.localIdentifier, 'PARTIAL-ID');
      expect(imported.filename, 'PARTIAL.JPG');
      expect(imported.creationDate, isNull);
      expect(imported.fileSize, isNull);
    });
    
    test('PhotoMetadata file size is much smaller than base64 data', () {
      // Simulate a 2MB photo
      const photoSizeBytes = 2 * 1024 * 1024; // 2MB
      
      const metadata = PhotoMetadata(
        localIdentifier: 'LARGE-PHOTO-ID',
        filename: 'LARGE_PHOTO.JPG',
        fileSize: photoSizeBytes,
        pixelWidth: 4000,
        pixelHeight: 3000,
        perceptualHash: 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6',
      );
      
      // Convert to JSON and measure size
      final json = metadata.toJson();
      final jsonString = json.toString();
      final metadataSizeBytes = jsonString.length;
      
      // Metadata should be much smaller than the original photo
      expect(metadataSizeBytes, lessThan(photoSizeBytes ~/ 100)); // At least 100x smaller
      
      print('Photo size: $photoSizeBytes bytes');
      print('Metadata size: $metadataSizeBytes bytes');
      print('Compression ratio: ${photoSizeBytes / metadataSizeBytes}x');
      
      // Should be under 1KB for metadata
      expect(metadataSizeBytes, lessThan(1024));
    });
    
    test('PhotoMetadata supports copyWith for updates', () {
      const original = PhotoMetadata(
        localIdentifier: 'ORIGINAL-ID',
        filename: 'ORIGINAL.JPG',
        fileSize: 1000000,
      );
      
      // Simulate finding a better match with more metadata
      final updated = original.copyWith(
        creationDate: DateTime(2025, 1, 15, 10, 30, 0),
        pixelWidth: 1920,
        pixelHeight: 1080,
        perceptualHash: 'better-hash',
      );
      
      // Verify updated fields
      expect(updated.creationDate, DateTime(2025, 1, 15, 10, 30, 0));
      expect(updated.pixelWidth, 1920);
      expect(updated.pixelHeight, 1080);
      expect(updated.perceptualHash, 'better-hash');
      
      // Verify original fields preserved
      expect(updated.localIdentifier, 'ORIGINAL-ID');
      expect(updated.filename, 'ORIGINAL.JPG');
      expect(updated.fileSize, 1000000);
      
      // Verify original unchanged
      expect(original.creationDate, isNull);
      expect(original.pixelWidth, isNull);
      expect(original.pixelHeight, isNull);
      expect(original.perceptualHash, isNull);
    });
  });
}

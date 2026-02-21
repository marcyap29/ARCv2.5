import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/services/photo_library_service.dart';
import 'package:my_app/data/models/photo_metadata.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('PhotoLibraryService Metadata', () {
    late MethodChannel mockChannel;
    
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });
    
    setUp(() {
      mockChannel = MethodChannel('photo_library_service');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getPhotoMetadata':
            final photoId = methodCall.arguments['photoId'] as String;
            if (photoId == 'ph://valid-photo-id') {
              return {
                'local_identifier': 'valid-photo-id',
                'creation_date': '2025-01-15T10:30:00.000Z',
                'modification_date': '2025-01-15T11:45:00.000Z',
                'filename': 'IMG_1234.JPG',
                'file_size': 2456789,
                'pixel_width': 3024,
                'pixel_height': 4032,
                'perceptual_hash': 'a1b2c3d4e5f6',
              };
            } else if (photoId == 'ph://missing-photo-id') {
              throw PlatformException(
                code: 'PHOTO_NOT_FOUND',
                message: 'Photo not found in library',
              );
            } else {
              return null;
            }
            
          case 'findPhotoByMetadata':
            final metadata = methodCall.arguments['metadata'] as Map<String, dynamic>;
            final filename = metadata['filename'] as String?;
            if (filename == 'IMG_1234.JPG') {
              return 'ph://found-photo-id';
            } else {
              return null;
            }
            
          case 'findPhotoByPerceptualHash':
            final hash = methodCall.arguments['hash'] as String;
            if (hash == 'a1b2c3d4e5f6') {
              return 'ph://found-photo-by-hash';
            } else {
              return null;
            }
            
          default:
            return null;
        }
      });
    });
    
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, null);
    });
    
    test('getPhotoMetadata returns valid metadata for existing photo', () async {
      final metadata = await PhotoLibraryService.getPhotoMetadata('ph://valid-photo-id');
      
      expect(metadata, isNotNull);
      expect(metadata!.localIdentifier, 'valid-photo-id');
      expect(metadata.creationDate, DateTime.parse('2025-01-15T10:30:00.000Z'));
      expect(metadata.modificationDate, DateTime.parse('2025-01-15T11:45:00.000Z'));
      expect(metadata.filename, 'IMG_1234.JPG');
      expect(metadata.fileSize, 2456789);
      expect(metadata.pixelWidth, 3024);
      expect(metadata.pixelHeight, 4032);
      expect(metadata.perceptualHash, 'a1b2c3d4e5f6');
    });
    
    test('getPhotoMetadata returns null for invalid photo ID', () async {
      final metadata = await PhotoLibraryService.getPhotoMetadata('ph://invalid-photo-id');
      
      expect(metadata, isNull);
    });
    
    test('getPhotoMetadata handles missing photo gracefully', () async {
      final metadata = await PhotoLibraryService.getPhotoMetadata('ph://missing-photo-id');
      
      expect(metadata, isNull);
    });
    
    test('findPhotoByMetadata finds exact match', () async {
      final searchMetadata = PhotoMetadata(
        localIdentifier: 'search-photo-id',
        creationDate: DateTime(2025, 1, 15, 10, 30, 0),
        filename: 'IMG_1234.JPG',
        fileSize: 2456789,
        pixelWidth: 3024,
        pixelHeight: 4032,
        perceptualHash: 'a1b2c3d4e5f6',
      );
      
      final foundId = await PhotoLibraryService.findPhotoByMetadata(searchMetadata);
      
      expect(foundId, 'ph://found-photo-id');
    });
    
    test('findPhotoByMetadata finds similar metadata', () async {
      final searchMetadata = PhotoMetadata(
        localIdentifier: 'search-photo-id',
        filename: 'IMG_1234.JPG', // This should match
        fileSize: 1000000, // Different size
      );
      
      final foundId = await PhotoLibraryService.findPhotoByMetadata(searchMetadata);
      
      expect(foundId, 'ph://found-photo-id');
    });
    
    test('findPhotoByMetadata returns null when no match', () async {
      final searchMetadata = PhotoMetadata(
        localIdentifier: 'search-photo-id',
        filename: 'NONEXISTENT.JPG',
      );
      
      final foundId = await PhotoLibraryService.findPhotoByMetadata(searchMetadata);
      
      expect(foundId, isNull);
    });
    
    test('findPhotoByPerceptualHash finds exact match', () async {
      final foundId = await PhotoLibraryService.findPhotoByPerceptualHash('a1b2c3d4e5f6');
      
      expect(foundId, 'ph://found-photo-by-hash');
    });
    
    test('findPhotoByPerceptualHash returns null when no match', () async {
      final foundId = await PhotoLibraryService.findPhotoByPerceptualHash('nonexistent-hash');
      
      expect(foundId, isNull);
    });
    
    test('handles permission denied gracefully', () async {
      // Mock permission denied scenario
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'PERMISSION_DENIED',
          message: 'Photo library permission not granted',
        );
      });
      
      final metadata = await PhotoLibraryService.getPhotoMetadata('ph://any-photo-id');
      expect(metadata, isNull);
      
      final foundId = await PhotoLibraryService.findPhotoByMetadata(
        PhotoMetadata(localIdentifier: 'test'),
      );
      expect(foundId, isNull);
      
      final foundByHash = await PhotoLibraryService.findPhotoByPerceptualHash('test-hash');
      expect(foundByHash, isNull);
    });
    
    test('handles network errors gracefully', () async {
      // Mock network error scenario
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'NETWORK_ERROR',
          message: 'Network request failed',
        );
      });
      
      final metadata = await PhotoLibraryService.getPhotoMetadata('ph://any-photo-id');
      expect(metadata, isNull);
      
      final foundId = await PhotoLibraryService.findPhotoByMetadata(
        PhotoMetadata(localIdentifier: 'test'),
      );
      expect(foundId, isNull);
      
      final foundByHash = await PhotoLibraryService.findPhotoByPerceptualHash('test-hash');
      expect(foundByHash, isNull);
    });
  });
}

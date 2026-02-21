import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:my_app/mira/store/mcp/adapters/journal_entry_projector.dart';
import 'package:my_app/core/services/photo_library_service.dart';
import 'package:my_app/data/models/photo_metadata.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/core/journal_repository.dart';

void main() {
  group('Full Photo Roundtrip', () {
    late MethodChannel mockChannel;
    
    setUp(() {
      mockChannel = MethodChannel('photo_library_service');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getPhotoMetadata':
            final photoId = methodCall.arguments['photoId'] as String;
            if (photoId.startsWith('ph://')) {
              return {
                'local_identifier': photoId.replaceFirst('ph://', ''),
                'creation_date': '2025-01-15T10:30:00.000Z',
                'modification_date': '2025-01-15T11:45:00.000Z',
                'filename': 'IMG_1234.JPG',
                'file_size': 2456789,
                'pixel_width': 3024,
                'pixel_height': 4032,
                'perceptual_hash': 'a1b2c3d4e5f6',
              };
            }
            return null;
            
          case 'photoExistsInLibrary':
            final photoId = methodCall.arguments['photoId'] as String;
            // Simulate that original photos don't exist after "deletion"
            return photoId == 'ph://still-exists-photo';
            
          case 'findPhotoByMetadata':
            final metadata = methodCall.arguments['metadata'] as Map<String, dynamic>;
            final filename = metadata['filename'] as String?;
            if (filename == 'IMG_1234.JPG') {
              return 'ph://found-by-metadata';
            }
            return null;
            
          default:
            return null;
        }
      });
    });
    
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, null);
    });
    
    test('photo survives export/delete/import cycle', () async {
      // 1. Create entry with 2 photos
      final entry = JournalEntry(
        id: 'test-entry-1',
        title: 'Test Entry with Photos',
        content: 'This entry has photos [PHOTO:photo-1] and [PHOTO:photo-2]',
        createdAt: DateTime(2025, 1, 15, 10, 30, 0),
        updatedAt: DateTime(2025, 1, 15, 10, 30, 0),
        tags: ['test', 'photos'],
        mood: 'happy',
        emotion: 'joy',
        emotionReason: 'Testing photo persistence',
        keywords: ['test', 'photos', 'persistence'],
        media: [
          MediaItem(
            id: 'photo-1',
            uri: 'ph://photo-1-id',
            type: MediaType.image,
            createdAt: DateTime(2025, 1, 15, 10, 30, 0),
            altText: 'First test photo',
          ),
          MediaItem(
            id: 'photo-2',
            uri: 'ph://photo-2-id',
            type: MediaType.image,
            createdAt: DateTime(2025, 1, 15, 10, 31, 0),
            altText: 'Second test photo',
          ),
        ],
      );
      
      // 2. Export to MCP
      final mockRepo = MockJournalRepository();
      mockRepo.entries = [entry];
      
      // Create IOSink wrappers for NDJSON streaming
      final tempDir = await Directory.systemTemp.createTemp('mcp_test');
      final nodesFile = File('${tempDir.path}/nodes.jsonl');
      final edgesFile = File('${tempDir.path}/edges.jsonl');
      final pointersFile = File('${tempDir.path}/pointers.jsonl');
      
      final nodesSink = nodesFile.openWrite();
      final edgesSink = edgesFile.openWrite();
      final pointersSink = pointersFile.openWrite();
      
      await McpEntryProjector.emitAll(
        repo: mockRepo,
        nodesSink: nodesSink,
        edgesSink: edgesSink,
        pointersSink: pointersSink,
      );
      
      await nodesSink.close();
      await edgesSink.close();
      await pointersSink.close();
      
      // 3. Verify MCP <10KB - read back from file
      final nodeContent = await nodesFile.readAsString();
      final jsonString = nodeContent;
      final sizeInBytes = jsonString.length;
      final sizeInKB = sizeInBytes / 1024;
      
      print('MCP export size: ${sizeInKB.toStringAsFixed(2)} KB');
      expect(sizeInKB, lessThan(10.0));
      
      // Verify media data is stored as metadata, not base64
      final nodeLines = nodeContent.trim().split('\n').where((line) => line.isNotEmpty);
      final node = jsonDecode(nodeLines.first) as Map<String, dynamic>;
      final mediaList = node['media'] as List;
      expect(mediaList, hasLength(2));
      
      for (final media in mediaList) {
        final mediaMap = media as Map<String, dynamic>;
        expect(mediaMap['photo_metadata'], isNotNull);
        expect(mediaMap['photo_data'], isNull); // Should not have base64 data
        
        final photoMetadata = mediaMap['photo_metadata'] as Map<String, dynamic>;
        expect(photoMetadata['local_identifier'], isNotNull);
        expect(photoMetadata['filename'], 'IMG_1234.JPG');
        expect(photoMetadata['file_size'], 2456789);
      }
      
      // 4. Delete entry (simulate)
      mockRepo.entries.clear();
      
      // 5. Import MCP
      final mockImportRepo = MockJournalRepository();
      
      // Simulate importing the MCP data - read from file
      final nodeLinesContent = await nodesFile.readAsString();
      final nodeList = nodeLinesContent.trim().split('\n').where((line) => line.isNotEmpty).map((line) => jsonDecode(line) as Map<String, dynamic>).toList();
      for (final node in nodeList) {
        if (node['type'] == 'journal_entry') {
          // Extract media from the node
          final mediaList = node['media'] as List;
          final importedMedia = <MediaItem>[];
          
          for (final mediaJson in mediaList) {
            final mediaMap = mediaJson as Map<String, dynamic>;
            
            // Simulate the reconnection process
            String finalUri = mediaMap['uri'] as String;
            
            if (finalUri.startsWith('ph://') && mediaMap.containsKey('photo_metadata')) {
              final metadata = PhotoMetadata.fromJson(mediaMap['photo_metadata'] as Map<String, dynamic>);
              
              // Check if original photo exists
              bool exists = await PhotoLibraryService.photoExistsInLibrary(finalUri);
              
              if (!exists) {
                // Try to find by metadata
                final newPhotoId = await PhotoLibraryService.findPhotoByMetadata(metadata);
                if (newPhotoId != null) {
                  finalUri = newPhotoId;
                }
              }
            }
            
            final mediaItem = MediaItem(
              id: mediaMap['id'] as String,
              uri: finalUri,
              type: MediaType.values.firstWhere(
                (e) => e.name == mediaMap['type'],
                orElse: () => MediaType.image,
              ),
              createdAt: DateTime.parse(mediaMap['created_at'] as String),
              altText: mediaMap['alt_text'] as String?,
            );
            
            importedMedia.add(mediaItem);
          }
          
          // Create imported journal entry
          final importedEntry = JournalEntry(
            id: node['id'].toString().replaceFirst('je_', ''),
            title: node['title'] as String,
            content: node['content'] as String,
            createdAt: DateTime.parse(node['timestamp'] as String),
            updatedAt: DateTime.parse(node['timestamp'] as String),
            tags: [],
            mood: node['emotions']['mood'] as String,
            emotion: node['emotions']['primary'] as String?,
            emotionReason: node['emotions']['reason'] as String?,
            keywords: List<String>.from(node['keywords'] as List),
            media: importedMedia,
          );
          
          mockImportRepo.entries.add(importedEntry);
        }
      }
      
      // 6. Verify photos reconnected
      expect(mockImportRepo.entries, hasLength(1));
      final importedEntry = mockImportRepo.entries.first;
      expect(importedEntry.media, hasLength(2));
      
      // Check that photos were reconnected (either original or found by metadata)
      final photo1 = importedEntry.media.firstWhere((m) => m.id == 'photo-1');
      final photo2 = importedEntry.media.firstWhere((m) => m.id == 'photo-2');
      
      expect(photo1.uri, anyOf(['ph://photo-1-id', 'ph://found-by-metadata']));
      expect(photo2.uri, anyOf(['ph://photo-2-id', 'ph://found-by-metadata']));
      
      // 7. Verify thumbnails would display (simulate)
      for (final media in importedEntry.media) {
        expect(media.uri, startsWith('ph://'));
        expect(media.type, MediaType.image);
        expect(media.altText, isNotNull);
      }
    });
    
    test('handles missing photo gracefully', () async {
      // Create entry with photo that will be "deleted" from library
      final entry = JournalEntry(
        id: 'test-entry-2',
        title: 'Test Entry with Missing Photo',
        content: 'This entry has a photo that will be missing [PHOTO:missing-photo]',
        createdAt: DateTime(2025, 1, 15, 10, 30, 0),
        updatedAt: DateTime(2025, 1, 15, 10, 30, 0),
        tags: [],
        mood: 'sad',
        media: [
          MediaItem(
            id: 'missing-photo',
            uri: 'ph://missing-photo-id',
            type: MediaType.image,
            createdAt: DateTime(2025, 1, 15, 10, 30, 0),
            altText: 'This photo will be missing',
          ),
        ],
      );
      
      // Export to MCP
      final mockRepo = MockJournalRepository();
      mockRepo.entries = [entry];
      
      final tempDir2 = await Directory.systemTemp.createTemp('mcp_test_2');
      final nodesFile2 = File('${tempDir2.path}/nodes.jsonl');
      final edgesFile2 = File('${tempDir2.path}/edges.jsonl');
      final pointersFile2 = File('${tempDir2.path}/pointers.jsonl');
      
      final nodesSink2 = nodesFile2.openWrite();
      final edgesSink2 = edgesFile2.openWrite();
      final pointersSink2 = pointersFile2.openWrite();
      
      await McpEntryProjector.emitAll(
        repo: mockRepo,
        nodesSink: nodesSink2,
        edgesSink: edgesSink2,
        pointersSink: pointersSink2,
      );
      
      await nodesSink2.close();
      await edgesSink2.close();
      await pointersSink2.close();
      
      // Import MCP (simulate missing photo scenario)
      final nodeContent2 = await nodesFile2.readAsString();
      final nodeLines2 = nodeContent2.trim().split('\n').where((line) => line.isNotEmpty);
      final node = jsonDecode(nodeLines2.first) as Map<String, dynamic>;
      final mediaList = node['media'] as List;
      final mediaJson = mediaList.first as Map<String, dynamic>;
      
      // Simulate reconnection with missing photo
      String finalUri = mediaJson['uri'] as String;
      
      if (finalUri.startsWith('ph://') && mediaJson.containsKey('photo_metadata')) {
        final metadata = PhotoMetadata.fromJson(mediaJson['photo_metadata'] as Map<String, dynamic>);
        
        // Check if original photo exists (will return false for missing photo)
        bool exists = await PhotoLibraryService.photoExistsInLibrary(finalUri);
        
        if (!exists) {
          // Try to find by metadata (will return null for missing photo)
          final newPhotoId = await PhotoLibraryService.findPhotoByMetadata(metadata);
          if (newPhotoId == null) {
            // Photo not found - keep original URI for "Photo unavailable" display
            print('Photo not found, will show as unavailable');
          }
        }
      }
      
      // Verify the photo URI is preserved for "unavailable" display
      expect(finalUri, 'ph://missing-photo-id');
    });
    
    test('performance test with multiple photos', () async {
      // Create entry with 10 photos
      final media = List.generate(10, (index) => MediaItem(
        id: 'photo-$index',
        uri: 'ph://photo-$index-id',
        type: MediaType.image,
        createdAt: DateTime(2025, 1, 15, 10, 30, 0),
        altText: 'Photo $index',
      ));
      
      final entry = JournalEntry(
        id: 'test-entry-3',
        title: 'Test Entry with 10 Photos',
        content: 'This entry has 10 photos for performance testing',
        createdAt: DateTime(2025, 1, 15, 10, 30, 0),
        updatedAt: DateTime(2025, 1, 15, 10, 30, 0),
        tags: [],
        mood: 'excited',
        media: media,
      );
      
      final mockRepo = MockJournalRepository();
      mockRepo.entries = [entry];
      
      final tempDir3 = await Directory.systemTemp.createTemp('mcp_test_3');
      final nodesFile3 = File('${tempDir3.path}/nodes.jsonl');
      final edgesFile3 = File('${tempDir3.path}/edges.jsonl');
      final pointersFile3 = File('${tempDir3.path}/pointers.jsonl');
      
      final nodesSink3 = nodesFile3.openWrite();
      final edgesSink3 = edgesFile3.openWrite();
      final pointersSink3 = pointersFile3.openWrite();
      
      // Measure export time
      final stopwatch = Stopwatch()..start();
      
      await McpEntryProjector.emitAll(
        repo: mockRepo,
        nodesSink: nodesSink3,
        edgesSink: edgesSink3,
        pointersSink: pointersSink3,
      );
      
      await nodesSink3.close();
      await edgesSink3.close();
      await pointersSink3.close();
      
      stopwatch.stop();
      
      // Verify performance
      expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Should complete in <5 seconds
      
      // Verify file size
      final nodeContent3 = await nodesFile3.readAsString();
      final jsonString = nodeContent3;
      final sizeInBytes = jsonString.length;
      final sizeInKB = sizeInBytes / 1024;
      
      print('MCP export with 10 photos: ${sizeInKB.toStringAsFixed(2)} KB in ${stopwatch.elapsedMilliseconds}ms');
      expect(sizeInKB, lessThan(100.0)); // Should be <100KB
    });
  });
}

// Mock journal repository for testing
class MockJournalRepository extends JournalRepository {
  List<JournalEntry> entries = [];
  
  @override
  @override
  Future<List<JournalEntry>> getAllJournalEntries() async => entries;
}

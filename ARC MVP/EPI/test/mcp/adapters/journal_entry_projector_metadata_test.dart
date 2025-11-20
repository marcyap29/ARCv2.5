import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/mira/store/mcp/adapters/journal_entry_projector.dart';
import 'package:my_app/core/services/photo_library_service.dart';
import 'package:my_app/data/models/photo_metadata.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/arc/core/journal_repository.dart' as arc;
import 'package:my_app/arc/ui/timeline/timeline_state.dart';
import 'package:flutter/services.dart';

void main() {
  group('MCP Export with Photo Metadata', () {
    late MethodChannel mockChannel;
    
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });
    
    setUp(() {
      mockChannel = MethodChannel('photo_library_service');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'getPhotoMetadata') {
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
          } else {
            return null;
          }
        }
        return null;
      });
    });
    
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, null);
    });
    
    test('stores photo metadata instead of base64 data', () async {
      // Create a journal entry with a photo
      final entry = JournalEntry(
        id: 'test-entry-1',
        title: 'Test Entry',
        content: 'This is a test entry with a photo [PHOTO:photo-1]',
        createdAt: DateTime(2025, 1, 15, 10, 30, 0),
        updatedAt: DateTime(2025, 1, 15, 10, 30, 0),
        tags: [],
        mood: 'happy',
        emotion: 'joy',
        emotionReason: 'Testing the system',
        keywords: ['test', 'photo'],
        media: [
          MediaItem(
            id: 'photo-1',
            uri: 'ph://valid-photo-id',
            type: MediaType.image,
            createdAt: DateTime(2025, 1, 15, 10, 30, 0),
            altText: 'Test photo',
          ),
        ],
      );
      
      // Mock the journal repository
      final mockRepo = MockJournalRepository();
      mockRepo.entries = [entry];
      
      // Create mock sinks
      final nodeSinkIO = MockIOSink();
      final edgeSinkIO = MockIOSink();
      final pointerSinkIO = MockIOSink();
      
      // Export the entry
      await McpEntryProjector.emitAll(
        repo: mockRepo,
        nodesSink: nodeSinkIO,
        edgesSink: edgeSinkIO,
        pointersSink: pointerSinkIO,
      );
      
      // Verify the node was created
      expect(nodeSinkIO.writtenData, isNotEmpty);
      final node = nodeSinkIO.writtenData.first;
      
      // Verify it's a journal entry node
      expect(node['type'], 'journal_entry');
      expect(node['id'], 'je_test-entry-1');
      
      // Verify media data exists
      expect(node['media'], isA<List>());
      final mediaList = node['media'] as List;
      expect(mediaList, hasLength(1));
      
      final media = mediaList.first as Map<String, dynamic>;
      expect(media['id'], 'photo-1');
      expect(media['uri'], 'ph://valid-photo-id');
      expect(media['type'], 'image');
      
      // Verify photo metadata is stored instead of base64 data
      expect(media['photo_metadata'], isNotNull);
      expect(media['photo_data'], isNull); // Should not have base64 data
      
      final photoMetadata = media['photo_metadata'] as Map<String, dynamic>;
      expect(photoMetadata['local_identifier'], 'valid-photo-id');
      expect(photoMetadata['filename'], 'IMG_1234.JPG');
      expect(photoMetadata['file_size'], 2456789);
      expect(photoMetadata['pixel_width'], 3024);
      expect(photoMetadata['pixel_height'], 4032);
      expect(photoMetadata['perceptual_hash'], 'a1b2c3d4e5f6');
    });
    
    test('includes localIdentifier in metadata', () async {
      final entry = JournalEntry(
        id: 'test-entry-2',
        title: 'Test Entry 2',
        content: 'Another test entry',
        createdAt: DateTime(2025, 1, 15, 10, 30, 0),
        updatedAt: DateTime(2025, 1, 15, 10, 30, 0),
        tags: [],
        mood: 'happy',
        media: [
          MediaItem(
            id: 'photo-2',
            uri: 'ph://valid-photo-id',
            type: MediaType.image,
            createdAt: DateTime(2025, 1, 15, 10, 30, 0),
          ),
        ],
      );
      
      final mockRepo = MockJournalRepository();
      mockRepo.entries = [entry];
      
      final nodeSinkIO = MockIOSink();
      
      await McpEntryProjector.emitAll(
        repo: mockRepo,
        nodesSink: nodeSinkIO,
        edgesSink: MockIOSink(),
        pointersSink: MockIOSink(),
      );
      
      final media = (nodeSinkIO.writtenData.first['media'] as List).first as Map<String, dynamic>;
      final photoMetadata = media['photo_metadata'] as Map<String, dynamic>;
      
      expect(photoMetadata['local_identifier'], 'valid-photo-id');
    });
    
    test('includes creation date in metadata', () async {
      final entry = JournalEntry(
        id: 'test-entry-3',
        title: 'Test Entry 3',
        content: 'Another test entry',
        createdAt: DateTime(2025, 1, 15, 10, 30, 0),
        updatedAt: DateTime(2025, 1, 15, 10, 30, 0),
        tags: [],
        mood: 'happy',
        media: [
          MediaItem(
            id: 'photo-3',
            uri: 'ph://valid-photo-id',
            type: MediaType.image,
            createdAt: DateTime(2025, 1, 15, 10, 30, 0),
          ),
        ],
      );
      
      final mockRepo = MockJournalRepository();
      mockRepo.entries = [entry];
      
      final nodeSinkIO = MockIOSink();
      
      await McpEntryProjector.emitAll(
        repo: mockRepo,
        nodesSink: nodeSinkIO,
        edgesSink: MockIOSink(),
        pointersSink: MockIOSink(),
      );
      
      final media = (nodeSinkIO.writtenData.first['media'] as List).first as Map<String, dynamic>;
      final photoMetadata = media['photo_metadata'] as Map<String, dynamic>;
      
      expect(photoMetadata['creation_date'], '2025-01-15T10:30:00.000Z');
    });
    
    test('MCP file size is <10KB with 5 photos', () async {
      // Create 5 journal entries with photos
      final entries = List.generate(5, (index) => JournalEntry(
        id: 'test-entry-$index',
        title: 'Test Entry $index',
        content: 'Test entry $index with photo [PHOTO:photo-$index]',
        createdAt: DateTime(2025, 1, 15, 10, 30, 0),
        updatedAt: DateTime(2025, 1, 15, 10, 30, 0),
        tags: [],
        mood: 'happy',
        media: [
          MediaItem(
            id: 'photo-$index',
            uri: 'ph://valid-photo-id',
            type: MediaType.image,
            createdAt: DateTime(2025, 1, 15, 10, 30, 0),
          ),
        ],
      ));
      
      final mockRepo = MockJournalRepository();
      mockRepo.entries = entries;
      
      final nodeSinkIO = MockIOSink();
      
      await McpEntryProjector.emitAll(
        repo: mockRepo,
        nodesSink: nodeSinkIO,
        edgesSink: MockIOSink(),
        pointersSink: MockIOSink(),
      );
      
      // Convert to JSON and measure size
      final jsonString = nodeSinkIO.writtenData.map((node) => node.toString()).join('\n');
      final sizeInBytes = jsonString.length;
      final sizeInKB = sizeInBytes / 1024;
      
      print('MCP export size with 5 photos: ${sizeInKB.toStringAsFixed(2)} KB');
      expect(sizeInKB, lessThan(10.0)); // Should be well under 10KB
    });
    
    test('handles photo with missing metadata gracefully', () async {
      // Mock a photo that returns null metadata
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, (MethodCall methodCall) async {
        return null; // Simulate missing metadata
      });
      
      final entry = JournalEntry(
        id: 'test-entry-4',
        title: 'Test Entry 4',
        content: 'Test entry with missing metadata photo',
        createdAt: DateTime(2025, 1, 15, 10, 30, 0),
        updatedAt: DateTime(2025, 1, 15, 10, 30, 0),
        tags: [],
        mood: 'happy',
        media: [
          MediaItem(
            id: 'photo-4',
            uri: 'ph://missing-metadata-photo',
            type: MediaType.image,
            createdAt: DateTime(2025, 1, 15, 10, 30, 0),
          ),
        ],
      );
      
      final mockRepo = MockJournalRepository();
      mockRepo.entries = [entry];
      
      final nodeSinkIO = MockIOSink();
      
      // Should not throw an exception
      await McpEntryProjector.emitAll(
        repo: mockRepo,
        nodesSink: nodeSinkIO,
        edgesSink: MockIOSink(),
        pointersSink: MockIOSink(),
      );
      
      // Verify the entry was still exported
      expect(nodeSinkIO.writtenData, isNotEmpty);
      final media = (nodeSinkIO.writtenData.first['media'] as List).first as Map<String, dynamic>;
      
      // Should not have photo_metadata field
      expect(media['photo_metadata'], isNull);
      expect(media['uri'], 'ph://missing-metadata-photo'); // Original URI preserved
    });
  });
}

// Mock journal repository for testing
class MockJournalRepository implements arc.JournalRepository {
  List<JournalEntry> entries = [];
  
  @override
  List<JournalEntry> getAllJournalEntries() => entries;
  
  @override
  List<JournalEntry> getAllJournalEntriesSync() => entries;
  
  @override
  Future<void> createJournalEntry(JournalEntry entry) async {
    entries.add(entry);
  }
  
  @override
  Future<void> saveJournalEntry(JournalEntry entry) async {
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      entries[index] = entry;
    } else {
      entries.add(entry);
    }
  }
  
  @override
  Future<void> deleteJournalEntry(String id) async {
    entries.removeWhere((e) => e.id == id);
  }
  
  @override
  Future<void> deleteAllEntries() async {
    entries.clear();
  }
  
  @override
  Future<JournalEntry?> getJournalEntry(String id) async {
    return getJournalEntryById(id);
  }
  
  @override
  JournalEntry? getJournalEntryById(String id) {
    try {
      return entries.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }
  
  @override
  JournalEntry? getJournalEntryByIdSync(String id) {
    return getJournalEntryById(id);
  }
  
  @override
  Future<void> updateJournalEntry(JournalEntry entry) async {
    await saveJournalEntry(entry);
  }
  
  @override
  Future<List<JournalEntry>> searchJournalEntries(String query) async => [];
  
  @override
  Future<void> clearAllEntries() async {
    entries.clear();
  }
  
  @override
  Future<void> close() async {}
  
  @override
  Future<int> getEntryCount() async => entries.length;
  
  @override
  List<JournalEntry> getEntriesPaginatedSync({
    required int page,
    required int pageSize,
    TimelineFilter? filter,
  }) {
    final start = page * pageSize;
    final end = start + pageSize;
    return entries.length > start ? entries.sublist(start, end > entries.length ? entries.length : end) : [];
  }
  
  @override
  Future<List<JournalEntry>> getEntriesPaginated({
    required int page,
    required int pageSize,
    TimelineFilter? filter,
  }) async {
    return getEntriesPaginatedSync(page: page, pageSize: pageSize, filter: filter);
  }
}

// Mock IOSink for testing
class MockIOSink implements IOSink {
  final List<Map<String, dynamic>> writtenData = [];
  
  @override
  void write(Object? object) {
    if (object is String) {
      try {
        // Try to parse as JSON
        final json = jsonDecode(object) as Map<String, dynamic>;
        writtenData.add(json);
      } catch (e) {
        // If not JSON, just add as string
        writtenData.add({'data': object});
      }
    }
  }
  
  @override
  void writeln([Object? obj = ""]) => write(obj);
  
  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    for (final obj in objects) {
      write(obj);
      if (separator.isNotEmpty && obj != objects.last) {
        write(separator);
      }
    }
  }
  
  @override
  void writeCharCode(int charCode) {
    write(String.fromCharCode(charCode));
  }
  
  @override
  Encoding get encoding => utf8;
  
  @override
  set encoding(Encoding value) {}
  
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      write(String.fromCharCodes(data));
    }
  }
  
  @override
  Future<void> add(List<int> data) async {
    write(String.fromCharCodes(data));
  }
  
  @override
  Future<void> addError(Object error, [StackTrace? stackTrace]) async {}
  
  @override
  Future<void> flush() async {}
  
  @override
  Future<void> close() async {}
  
  @override
  Future get done => Future.value();
}
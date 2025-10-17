import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/data/models/media_item.dart';

void main() {
  group('MCP Import/Export Cycle Integration Tests', () {
    group('Media Persistence', () {
      test('media items maintain consistency through export/import cycle', () {
        // Create a journal entry with media
        final originalEntry = JournalEntry(
          id: 'test-entry',
          title: 'Test Entry',
          content: 'This is a test [PHOTO:photo_123] with media',
          createdAt: DateTime.now(),
          emotion: 'neutral',
          tags: ['test'],
          mood: 'neutral',
          media: [
            MediaItem(
              id: 'photo_123',
              type: MediaType.image,
              uri: 'ph://real-photo-id',
              createdAt: DateTime.now(),
              analysisData: {
                'width': 1920,
                'height': 1080,
                'fileSize': 1024000,
              },
            ),
          ],
        );

        // Simulate export process - convert to MCP format
        final exportedMetadata = {
          'media': originalEntry.media.map((media) => {
            'id': media.id,
            'type': media.type.name,
            'uri': media.uri,
            'createdAt': media.createdAt.toIso8601String(),
            'analysisData': media.analysisData,
          }).toList(),
        };

        // Simulate import process - reconstruct from MCP format
        final importedMedia = exportedMetadata['media'] as List;
        final reconstructedMedia = importedMedia.map((mediaJson) {
          return MediaItem(
            id: mediaJson['id'],
            type: MediaType.values.firstWhere((e) => e.name == mediaJson['type']),
            uri: mediaJson['uri'],
            createdAt: DateTime.parse(mediaJson['createdAt']),
            analysisData: Map<String, dynamic>.from(mediaJson['analysisData'] ?? {}),
          );
        }).toList();

        // Verify consistency
        expect(reconstructedMedia.length, originalEntry.media.length);
        expect(reconstructedMedia.first.id, originalEntry.media.first.id);
        expect(reconstructedMedia.first.type, originalEntry.media.first.type);
        expect(reconstructedMedia.first.uri, originalEntry.media.first.uri);
        expect(reconstructedMedia.first.analysisData, originalEntry.media.first.analysisData);
      });

      test('handles mixed media types correctly', () {
        final originalEntry = JournalEntry(
          id: 'test-entry',
          title: 'Test Entry',
          content: 'This is a test with [PHOTO:photo_123] and [AUDIO:audio_456]',
          createdAt: DateTime.now(),
          emotion: 'neutral',
          tags: ['test'],
          mood: 'neutral',
          media: [
            MediaItem(
              id: 'photo_123',
              type: MediaType.image,
              uri: 'ph://real-photo-id',
              createdAt: DateTime.now(),
            ),
            MediaItem(
              id: 'audio_456',
              type: MediaType.audio,
              uri: 'file://audio.mp3',
              createdAt: DateTime.now(),
            ),
          ],
        );

        // Export
        final exportedMetadata = {
          'media': originalEntry.media.map((media) => {
            'id': media.id,
            'type': media.type.name,
            'uri': media.uri,
            'createdAt': media.createdAt.toIso8601String(),
          }).toList(),
        };

        // Import
        final importedMedia = exportedMetadata['media'] as List;
        final reconstructedMedia = importedMedia.map((mediaJson) {
          return MediaItem(
            id: mediaJson['id'],
            type: MediaType.values.firstWhere((e) => e.name == mediaJson['type']),
            uri: mediaJson['uri'],
            createdAt: DateTime.parse(mediaJson['createdAt']),
          );
        }).toList();

        // Verify both media types are preserved
        expect(reconstructedMedia.length, 2);
        expect(reconstructedMedia.any((m) => m.type == MediaType.image), true);
        expect(reconstructedMedia.any((m) => m.type == MediaType.audio), true);
      });
    });

    group('Content Extraction Fallback', () {
      test('extracts content from narrative when available', () {
        final nodeData = {
          'content': {
            'narrative': 'This is the main content',
          },
        };

        final content = _extractContentWithFallback(nodeData);
        expect(content, 'This is the main content');
      });

      test('falls back to text when narrative not available', () {
        final nodeData = {
          'content': {
            'text': 'This is fallback content',
          },
        };

        final content = _extractContentWithFallback(nodeData);
        expect(content, 'This is fallback content');
      });

      test('falls back to metadata.content when others not available', () {
        final nodeData = {
          'metadata': {
            'content': 'This is metadata content',
          },
        };

        final content = _extractContentWithFallback(nodeData);
        expect(content, 'This is metadata content');
      });

      test('returns null when no content found', () {
        final nodeData = {};

        final content = _extractContentWithFallback(nodeData);
        expect(content, null);
      });
    });

    group('Error Recovery', () {
      test('handles corrupted media data gracefully', () {
        final corruptedMetadata = {
          'media': [
            {'id': 'valid_media', 'type': 'image', 'uri': 'ph://valid-id'},
            {'invalid': 'data'}, // Missing required fields
            null, // Null entry
            {'id': 'another_valid', 'type': 'image', 'uri': 'ph://another-valid'},
          ],
        };

        final extractedMedia = _extractMedia(corruptedMetadata);
        expect(extractedMedia.length, 2); // Only valid entries
        expect(extractedMedia.any((m) => m['id'] == 'valid_media'), true);
        expect(extractedMedia.any((m) => m['id'] == 'another_valid'), true);
      });

      test('handles missing metadata gracefully', () {
        final extractedMedia = _extractMedia(null);
        expect(extractedMedia, []);
      });
    });
  });
}

// Helper functions for testing (copies of actual implementation)
String? _extractContentWithFallback(Map<String, dynamic> node) {
  // Try content.narrative first
  final content = node['content'] as Map<String, dynamic>?;
  String? text = content?['narrative'] as String? ?? content?['text'] as String?;
  if (text == null || text.isEmpty) {
    final meta = node['metadata'] as Map<String, dynamic>?;
    final mcontent = meta?['content'] as String?;
    if (mcontent != null && mcontent.isNotEmpty) text = mcontent;
  }
  if (text == null) return null;
  final t = text.trim();
  return t.isEmpty ? null : t;
}

List<Map<String, dynamic>> _extractMedia(Map<String, dynamic>? meta) {
  if (meta == null) return [];
  final dynamic a = meta['media'] ?? meta['mediaItems'] ?? meta['attachments'];
  if (a is List) {
    return a.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
  }
  return const [];
}

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MCP Media Extraction', () {
    group('_extractMedia', () {
      test('extracts media from "media" key', () {
        final meta = {
          'media': [
            {'id': 'media1', 'type': 'image', 'uri': 'file://test1.jpg'},
            {'id': 'media2', 'type': 'image', 'uri': 'file://test2.jpg'},
          ],
        };
        
        final result = _extractMedia(meta);
        expect(result.length, 2);
        expect(result[0]['id'], 'media1');
        expect(result[1]['id'], 'media2');
      });

      test('extracts media from "mediaItems" key when "media" not present', () {
        final meta = {
          'mediaItems': [
            {'id': 'media1', 'type': 'image', 'uri': 'file://test1.jpg'},
          ],
        };
        
        final result = _extractMedia(meta);
        expect(result.length, 1);
        expect(result[0]['id'], 'media1');
      });

      test('extracts media from "attachments" key when others not present', () {
        final meta = {
          'attachments': [
            {'id': 'media1', 'type': 'image', 'uri': 'file://test1.jpg'},
          ],
        };
        
        final result = _extractMedia(meta);
        expect(result.length, 1);
        expect(result[0]['id'], 'media1');
      });

      test('returns empty list when no media keys present', () {
        final meta = {
          'other': 'data',
        };
        
        final result = _extractMedia(meta);
        expect(result, []);
      });

      test('returns empty list when media value is not a list', () {
        final meta = {
          'media': 'not a list',
        };
        
        final result = _extractMedia(meta);
        expect(result, []);
      });

      test('filters out non-map items from list', () {
        final meta = {
          'media': [
            {'id': 'media1', 'type': 'image'},
            'not a map',
            {'id': 'media2', 'type': 'image'},
            null,
          ],
        };
        
        final result = _extractMedia(meta);
        expect(result.length, 2);
        expect(result[0]['id'], 'media1');
        expect(result[1]['id'], 'media2');
      });

      test('converts dynamic maps to String-keyed maps', () {
        final meta = {
          'media': [
            {1: 'value', 'key': 2}, // Dynamic map
          ],
        };
        
        final result = _extractMedia(meta);
        expect(result.length, 1);
        expect(result[0], isA<Map<String, dynamic>>());
        expect(result[0]['1'], 'value');
        expect(result[0]['key'], 2);
      });

      test('handles empty metadata', () {
        final result = _extractMedia({});
        expect(result, []);
      });

      test('handles null metadata', () {
        final result = _extractMedia(null);
        expect(result, []);
      });
    });
  });
}

// Copy of the _extractMedia function for testing
List<Map<String, dynamic>> _extractMedia(Map<String, dynamic>? meta) {
  if (meta == null) return [];
  final dynamic a = meta['media'] ?? meta['mediaItems'] ?? meta['attachments'];
  if (a is List) {
    return a.whereType<Map>()
            .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
  }
  return const [];
}

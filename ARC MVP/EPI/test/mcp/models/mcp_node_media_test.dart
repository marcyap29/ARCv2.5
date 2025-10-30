// Test to verify McpNode.fromJson captures root-level media field
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/mcp/models/mcp_schemas.dart';

void main() {
  group('McpNode.fromJson media field capture', () {
    test('should capture root-level media field in metadata', () {
      // Test JSON with root-level media field (as exported by journal_entry_projector)
      final testJson = {
        'id': 'je_test123',
        'type': 'journal_entry',
        'timestamp': '2025-01-15T10:00:00Z',
        'media': [
          {
            'id': 'media_001',
            'uri': 'ph://ABC123/L0/001',
            'type': 'image',
            'created_at': '2025-01-15T10:00:00Z',
          },
          {
            'id': 'media_002',
            'uri': 'ph://DEF456/L0/001',
            'type': 'image',
            'created_at': '2025-01-15T10:05:00Z',
          }
        ],
        'provenance': {
          'source': 'test',
        },
      };

      // Parse the JSON
      final node = McpNode.fromJson(testJson);

      // Verify media is captured in metadata
      expect(node.metadata, isNotNull);
      expect(node.metadata!.containsKey('media'), isTrue);

      final media = node.metadata!['media'] as List;
      expect(media.length, equals(2));

      final firstMedia = media[0] as Map<String, dynamic>;
      expect(firstMedia['uri'], equals('ph://ABC123/L0/001'));
      expect(firstMedia['type'], equals('image'));

      final secondMedia = media[1] as Map<String, dynamic>;
      expect(secondMedia['uri'], equals('ph://DEF456/L0/001'));
    });

    test('should handle nodes without media field', () {
      final testJson = {
        'id': 'je_test456',
        'type': 'journal_entry',
        'timestamp': '2025-01-15T10:00:00Z',
        'provenance': {
          'source': 'test',
        },
      };

      final node = McpNode.fromJson(testJson);

      // Should not create metadata if there's no media
      expect(node.metadata, isNull);
    });

    test('should merge media with existing metadata', () {
      final testJson = {
        'id': 'je_test789',
        'type': 'journal_entry',
        'timestamp': '2025-01-15T10:00:00Z',
        'metadata': {
          'custom_field': 'custom_value',
        },
        'media': [
          {
            'id': 'media_001',
            'uri': 'ph://ABC123/L0/001',
            'type': 'image',
            'created_at': '2025-01-15T10:00:00Z',
          }
        ],
        'provenance': {
          'source': 'test',
        },
      };

      final node = McpNode.fromJson(testJson);

      // Should preserve existing metadata and add media
      expect(node.metadata, isNotNull);
      expect(node.metadata!.containsKey('custom_field'), isTrue);
      expect(node.metadata!['custom_field'], equals('custom_value'));
      expect(node.metadata!.containsKey('media'), isTrue);

      final media = node.metadata!['media'] as List;
      expect(media.length, equals(1));
    });
  });
}

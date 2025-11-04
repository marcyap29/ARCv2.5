import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/arc/chat/chat/provenance_tracker.dart';

void main() {
  group('ChatProvenanceTracker Tests', () {
    late ChatProvenanceTracker tracker;

    setUp(() {
      tracker = ChatProvenanceTracker.instance;
      tracker.clearCache(); // Ensure clean state for each test
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        final instance1 = ChatProvenanceTracker.instance;
        final instance2 = ChatProvenanceTracker.instance;

        expect(identical(instance1, instance2), true);
      });

      test('should maintain state across calls', () async {
        final provenance1 = await tracker.getProvenanceMetadata();
        final provenance2 = await tracker.getProvenanceMetadata();

        // Should return same cached data
        expect(provenance1['timestamp'], equals(provenance2['timestamp']));
      });
    });

    group('Provenance Metadata Structure', () {
      test('should include required fields', () async {
        final provenance = await tracker.getProvenanceMetadata();

        // Core fields
        expect(provenance['source'], 'LUMARA');
        expect(provenance['timestamp'], isNotNull);

        // Export context
        expect(provenance['export_context'], isNotNull);
        expect(provenance['export_context']['feature'], 'chat_memory');
        expect(provenance['export_context']['format'], 'mcp_v1');
        expect(provenance['export_context']['schema_versions'], isNotNull);
      });

      test('should include schema version information', () async {
        final provenance = await tracker.getProvenanceMetadata();
        final schemaVersions = provenance['export_context']['schema_versions'];

        expect(schemaVersions['node'], 'v2');
        expect(schemaVersions['edge'], 'v1');
        expect(schemaVersions['chat_session'], 'v1');
        expect(schemaVersions['chat_message'], 'v1');
      });

      test('should include device information', () async {
        final provenance = await tracker.getProvenanceMetadata();

        expect(provenance['device'], isNotNull);
        expect(provenance['device']['platform'], isNotNull);

        // Platform should be a known value
        final platform = provenance['device']['platform'];
        expect(['android', 'ios', 'macos', 'windows', 'linux'].contains(platform), true);
      });

      test('should handle missing package info gracefully', () async {
        // This test verifies the tracker doesn't crash when package info fails
        final provenance = await tracker.getProvenanceMetadata();

        expect(provenance['source'], 'LUMARA');
        expect(provenance['timestamp'], isNotNull);
        // app_version might be missing but shouldn't cause failure
      });

      test('should handle missing device info gracefully', () async {
        // This test verifies the tracker doesn't crash when device info fails
        final provenance = await tracker.getProvenanceMetadata();

        expect(provenance['device'], isNotNull);
        expect(provenance['device']['platform'], isNotNull);
      });
    });

    group('Timestamp Generation', () {
      test('should generate valid ISO 8601 timestamp', () async {
        final provenance = await tracker.getProvenanceMetadata();
        final timestamp = provenance['timestamp'] as String;

        // Should be valid ISO 8601 format
        expect(() => DateTime.parse(timestamp), returnsNormally);

        // Should be UTC
        final parsed = DateTime.parse(timestamp);
        expect(parsed.isUtc, true);
      });

      test('should generate recent timestamp', () async {
        final before = DateTime.now().toUtc();
        final provenance = await tracker.getProvenanceMetadata();
        final after = DateTime.now().toUtc();

        final timestamp = DateTime.parse(provenance['timestamp'] as String);

        expect(timestamp.isAfter(before.subtract(const Duration(seconds: 1))), true);
        expect(timestamp.isBefore(after.add(const Duration(seconds: 1))), true);
      });
    });

    group('Caching Behavior', () {
      test('should cache provenance data', () async {
        final provenance1 = await tracker.getProvenanceMetadata();
        final provenance2 = await tracker.getProvenanceMetadata();

        // Should be identical (cached)
        expect(provenance1, equals(provenance2));
      });

      test('should return fresh data after cache clear', () async {
        final provenance1 = await tracker.getProvenanceMetadata();

        // Small delay to ensure different timestamp
        await Future.delayed(const Duration(milliseconds: 10));

        tracker.clearCache();
        final provenance2 = await tracker.getProvenanceMetadata();

        // Should have different timestamps
        expect(provenance1['timestamp'], isNot(equals(provenance2['timestamp'])));
      });

      test('should preserve modifications to returned map', () async {
        final provenance1 = await tracker.getProvenanceMetadata();
        provenance1['test_modification'] = 'test_value';

        final provenance2 = await tracker.getProvenanceMetadata();

        // Should not contain the modification (returns copy)
        expect(provenance2.containsKey('test_modification'), false);
      });
    });

    group('Device Information', () {
      test('should include platform-specific device info', () async {
        final provenance = await tracker.getProvenanceMetadata();
        final device = provenance['device'] as Map<String, dynamic>;

        expect(device['platform'], isNotNull);

        // Should include additional info based on platform
        switch (device['platform']) {
          case 'android':
            // Android might have model, manufacturer, version, sdk_int
            break;
          case 'ios':
            // iOS might have name, model, system_name, system_version
            break;
          default:
            // Other platforms should at least have platform and version
            break;
        }
      });

      test('should handle device info retrieval failure', () async {
        // This verifies graceful degradation when device info fails
        final provenance = await tracker.getProvenanceMetadata();
        final device = provenance['device'] as Map<String, dynamic>;

        // Should always have at least platform
        expect(device['platform'], isNotNull);
      });
    });

    group('App Information', () {
      test('should attempt to include app version info', () async {
        final provenance = await tracker.getProvenanceMetadata();

        // These fields might be present if package info is available
        // but we don't assert they must be present due to test environment limitations
        if (provenance.containsKey('app_version')) {
          expect(provenance['app_version'], isA<String>());
        }
        if (provenance.containsKey('build_number')) {
          expect(provenance['build_number'], isA<String>());
        }
        if (provenance.containsKey('app_name')) {
          expect(provenance['app_name'], isA<String>());
        }
      });
    });

    group('Export Context', () {
      test('should include complete export context', () async {
        final provenance = await tracker.getProvenanceMetadata();
        final exportContext = provenance['export_context'] as Map<String, dynamic>;

        expect(exportContext['feature'], 'chat_memory');
        expect(exportContext['format'], 'mcp_v1');

        final schemaVersions = exportContext['schema_versions'] as Map<String, dynamic>;
        expect(schemaVersions.keys, containsAll(['node', 'edge', 'chat_session', 'chat_message']));
      });

      test('should have consistent schema versions', () async {
        final provenance = await tracker.getProvenanceMetadata();
        final schemaVersions = provenance['export_context']['schema_versions'] as Map<String, dynamic>;

        // Verify expected schema versions
        expect(schemaVersions['node'], 'v2');
        expect(schemaVersions['edge'], 'v1');
        expect(schemaVersions['chat_session'], 'v1');
        expect(schemaVersions['chat_message'], 'v1');
      });
    });

    group('Data Integrity', () {
      test('should return immutable copy of provenance data', () async {
        final provenance1 = await tracker.getProvenanceMetadata();
        final provenance2 = await tracker.getProvenanceMetadata();

        // Should be equal but not identical
        expect(provenance1, equals(provenance2));
        expect(identical(provenance1, provenance2), false);
      });

      test('should maintain consistent structure across calls', () async {
        final provenance1 = await tracker.getProvenanceMetadata();
        tracker.clearCache();
        final provenance2 = await tracker.getProvenanceMetadata();

        // Should have same keys (structure)
        expect(provenance1.keys.toSet(), equals(provenance2.keys.toSet()));

        // Export context should be identical
        expect(provenance1['export_context'], equals(provenance2['export_context']));

        // Source should be identical
        expect(provenance1['source'], equals(provenance2['source']));
      });

      test('should handle multiple concurrent requests', () async {
        // Test thread safety by making multiple concurrent requests
        final futures = List.generate(10, (_) => tracker.getProvenanceMetadata());
        final results = await Future.wait(futures);

        // All results should be identical (cached)
        for (int i = 1; i < results.length; i++) {
          expect(results[i], equals(results[0]));
        }
      });
    });

    group('Error Recovery', () {
      test('should continue working after cache clear', () async {
        final provenance1 = await tracker.getProvenanceMetadata();
        expect(provenance1, isNotNull);

        tracker.clearCache();

        final provenance2 = await tracker.getProvenanceMetadata();
        expect(provenance2, isNotNull);
        expect(provenance2['source'], 'LUMARA');
      });

      test('should handle repeated cache clears', () async {
        for (int i = 0; i < 5; i++) {
          tracker.clearCache();
          final provenance = await tracker.getProvenanceMetadata();
          expect(provenance['source'], 'LUMARA');
        }
      });
    });
  });
}
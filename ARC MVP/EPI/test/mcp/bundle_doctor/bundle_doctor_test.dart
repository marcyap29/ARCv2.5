// test/mcp/bundle_doctor/bundle_doctor_test.dart
// Comprehensive tests for MCP Bundle Doctor

import 'package:test/test.dart';
import 'package:my_app/mcp/bundle_doctor/bundle_doctor.dart';
import 'package:my_app/mcp/bundle_doctor/mcp_models.dart';

void main() {
  group('Bundle Doctor', () {
    test('repairs missing required fields and drops invalid edges', () {
      final broken = {
        'nodes': [
          {'type': 'entry'}
        ],
        'edges': [
          {'from': 'missing', 'to': 'also-missing', 'type': 'mentions'}
        ]
      };

      final fixed = BundleDoctor.repair(broken);

      // Required fields added
      expect(fixed.schemaVersion, equals('mcp-1.0'));
      expect(fixed.bundleId, startsWith('b-'));

      // Node repairs
      expect(fixed.nodes.length, equals(1));
      final node = fixed.nodes.first;
      expect(node.id, startsWith('n-'));
      expect(node.type, equals('entry'));
      expect(() => DateTime.parse(node.timestamp), returnsNormally);

      // Invalid edges removed
      expect(fixed.edges.length, equals(0));

      // Repair log populated
      expect(fixed.repairLog, isNotEmpty);
      expect(fixed.repairLog.any((log) => log.contains('schemaVersion')), isTrue);
      expect(fixed.repairLog.any((log) => log.contains('bundleId')), isTrue);
      expect(fixed.repairLog.any((log) => log.contains('node ID')), isTrue);
      expect(fixed.repairLog.any((log) => log.contains('timestamp')), isTrue);
      expect(fixed.repairLog.any((log) => log.contains('Dropped edge')), isTrue);
    });

    test('preserves valid data and node references', () {
      final good = {
        'schemaVersion': 'mcp-1.0',
        'bundleId': 'b-demo',
        'nodes': [
          {
            'id': 'n1',
            'type': 'entry',
            'timestamp': '2025-09-24T21:00:00Z',
            'content': {'text': 'Test entry'}
          },
          {
            'id': 'n2',
            'type': 'keyword',
            'timestamp': '2025-09-24T21:00:01Z',
            'label': 'test'
          }
        ],
        'edges': [
          {
            'from': 'n1',
            'to': 'n2',
            'type': 'mentions',
            'weight': 0.9
          }
        ]
      };

      final fixed = BundleDoctor.repair(good);

      // All data preserved
      expect(fixed.schemaVersion, equals('mcp-1.0'));
      expect(fixed.bundleId, equals('b-demo'));
      expect(fixed.nodes.length, equals(2));
      expect(fixed.edges.length, equals(1));

      // Node data preserved
      expect(fixed.nodes[0].id, equals('n1'));
      expect(fixed.nodes[0].type, equals('entry'));
      expect(fixed.nodes[0].metadata['content'], equals({'text': 'Test entry'}));

      // Edge data preserved
      expect(fixed.edges[0].from, equals('n1'));
      expect(fixed.edges[0].to, equals('n2'));
      expect(fixed.edges[0].metadata['weight'], equals(0.9));

      // No repairs needed
      expect(fixed.repairLog, isEmpty);
    });

    test('handles complex metadata preservation', () {
      final complex = {
        'schemaVersion': 'mcp-1.0',
        'bundleId': 'b-complex',
        'pointers': [
          {
            'id': 'p1',
            'kind': 'chat_session',
            'ref': 'chat://sessions/123',
            'customField': 'preserved'
          }
        ],
        'nodes': [
          {
            'id': 'n1',
            'type': 'entry',
            'timestamp': '2025-09-24T21:00:00Z',
            'emotions': ['focused', 'anxious'],
            'phaseHint': 'Transition',
            'nested': {'deep': {'value': 42}}
          }
        ],
        'edges': [
          {
            'from': 'n1',
            'to': 'n1', // Self-reference
            'type': 'reflects_on',
            'strength': 'high',
            'tags': ['self-reflection']
          }
        ]
      };

      final fixed = BundleDoctor.repair(complex);

      // Pointer metadata preserved
      expect(fixed.pointers.length, equals(1));
      expect(fixed.pointers[0].metadata['customField'], equals('preserved'));

      // Node metadata preserved
      expect(fixed.nodes[0].metadata['emotions'], equals(['focused', 'anxious']));
      expect(fixed.nodes[0].metadata['phaseHint'], equals('Transition'));
      expect(fixed.nodes[0].metadata['nested'], equals({'deep': {'value': 42}}));

      // Edge metadata preserved
      expect(fixed.edges[0].metadata['strength'], equals('high'));
      expect(fixed.edges[0].metadata['tags'], equals(['self-reflection']));
    });

    test('generates unique IDs for multiple missing items', () {
      final multiMissing = {
        'nodes': [
          {'type': 'entry'},
          {'type': 'keyword'},
          {'type': 'phase'}
        ]
      };

      final fixed = BundleDoctor.repair(multiMissing);

      // All nodes get unique IDs
      final nodeIds = fixed.nodes.map((n) => n.id).toSet();
      expect(nodeIds.length, equals(3)); // All unique

      // All IDs follow format
      for (final id in nodeIds) {
        expect(id, startsWith('n-'));
        expect(id.length, greaterThan(10)); // UUID format
      }
    });
  });

  group('Bundle Validation', () {
    test('validates correct bundle', () {
      final bundle = MCPBundle(
        schemaVersion: 'mcp-1.0',
        bundleId: 'b-test',
        pointers: [],
        nodes: [
          MCPNode(
            id: 'n-123',
            type: 'entry',
            timestamp: '2025-09-24T21:00:00Z',
          )
        ],
        edges: [],
      );

      final result = BundleDoctor.validate(bundle);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('detects invalid schema version', () {
      final bundle = MCPBundle(
        schemaVersion: 'invalid-version',
        bundleId: 'b-test',
        pointers: [],
        nodes: [],
        edges: [],
      );

      final result = BundleDoctor.validate(bundle);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('Invalid schemaVersion')), isTrue);
    });

    test('detects duplicate node IDs', () {
      final bundle = MCPBundle(
        schemaVersion: 'mcp-1.0',
        bundleId: 'b-test',
        pointers: [],
        nodes: [
          MCPNode(
            id: 'n-duplicate',
            type: 'entry',
            timestamp: '2025-09-24T21:00:00Z',
          ),
          MCPNode(
            id: 'n-duplicate',
            type: 'keyword',
            timestamp: '2025-09-24T21:00:01Z',
          )
        ],
        edges: [],
      );

      final result = BundleDoctor.validate(bundle);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('Duplicate node ID')), isTrue);
    });

    test('detects invalid timestamp format', () {
      final bundle = MCPBundle(
        schemaVersion: 'mcp-1.0',
        bundleId: 'b-test',
        pointers: [],
        nodes: [
          MCPNode(
            id: 'n-test',
            type: 'entry',
            timestamp: 'not-a-timestamp',
          )
        ],
        edges: [],
      );

      final result = BundleDoctor.validate(bundle);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('Invalid timestamp format')), isTrue);
    });

    test('detects invalid edge references', () {
      final bundle = MCPBundle(
        schemaVersion: 'mcp-1.0',
        bundleId: 'b-test',
        pointers: [],
        nodes: [
          MCPNode(
            id: 'n-exists',
            type: 'entry',
            timestamp: '2025-09-24T21:00:00Z',
          )
        ],
        edges: [
          MCPEdge(
            from: 'n-exists',
            to: 'n-missing',
            type: 'mentions',
          )
        ],
      );

      final result = BundleDoctor.validate(bundle);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('unknown target node')), isTrue);
    });

    test('generates warnings for ID format conventions', () {
      final bundle = MCPBundle(
        schemaVersion: 'mcp-1.0',
        bundleId: 'bad-bundle-id', // Should start with b-
        pointers: [],
        nodes: [
          MCPNode(
            id: 'bad-node-id', // Should start with n-
            type: 'entry',
            timestamp: '2025-09-24T21:00:00Z',
          )
        ],
        edges: [],
      );

      final result = BundleDoctor.validate(bundle);
      expect(result.isValid, isTrue); // Just warnings, not errors
      expect(result.warnings.any((w) => w.contains('Bundle ID should start')), isTrue);
      expect(result.warnings.any((w) => w.contains('Node ID should start')), isTrue);
    });
  });

  group('JSON Serialization', () {
    test('round-trip JSON conversion', () {
      final original = {
        'schemaVersion': 'mcp-1.0',
        'bundleId': 'b-test',
        'nodes': [
          {
            'id': 'n1',
            'type': 'entry',
            'timestamp': '2025-09-24T21:00:00Z',
            'content': {'text': 'Test entry'}
          }
        ],
        'edges': []
      };

      // Convert to bundle and back
      final bundle = BundleDoctor.repair(original);
      final json = BundleDoctor.toJson(bundle);
      final parsed = BundleDoctor.fromJson(json);

      expect(parsed.schemaVersion, equals(bundle.schemaVersion));
      expect(parsed.bundleId, equals(bundle.bundleId));
      expect(parsed.nodes.length, equals(bundle.nodes.length));
      expect(parsed.nodes[0].id, equals(bundle.nodes[0].id));
      expect(parsed.nodes[0].metadata['content'], equals({'text': 'Test entry'}));
    });
  });

  group('Edge Cases', () {
    test('handles completely empty input', () {
      final empty = <String, dynamic>{};
      final fixed = BundleDoctor.repair(empty);

      expect(fixed.schemaVersion, equals('mcp-1.0'));
      expect(fixed.bundleId, startsWith('b-'));
      expect(fixed.nodes, isEmpty);
      expect(fixed.edges, isEmpty);
      expect(fixed.pointers, isEmpty);
      expect(fixed.repairLog, isNotEmpty);
    });

    test('handles null values gracefully', () {
      final withNulls = {
        'schemaVersion': null,
        'bundleId': null,
        'nodes': [
          {
            'id': null,
            'type': null,
            'timestamp': null
          }
        ],
        'edges': null
      };

      final fixed = BundleDoctor.repair(withNulls);

      expect(fixed.schemaVersion, equals('mcp-1.0'));
      expect(fixed.bundleId, startsWith('b-'));
      expect(fixed.nodes.length, equals(1));
      expect(fixed.nodes[0].type, equals('unknown'));
      expect(fixed.edges, isEmpty);
    });

    test('preserves unknown fields in metadata', () {
      final withUnknownFields = {
        'schemaVersion': 'mcp-1.0',
        'bundleId': 'b-test',
        'customRootField': 'should-be-ignored',
        'nodes': [
          {
            'id': 'n1',
            'type': 'entry',
            'timestamp': '2025-09-24T21:00:00Z',
            'customNodeField': 'should-be-preserved',
            'anotherCustomField': {'nested': 'data'}
          }
        ],
        'edges': [
          {
            'from': 'n1',
            'to': 'n1',
            'type': 'self-ref',
            'customEdgeField': 'also-preserved'
          }
        ]
      };

      final fixed = BundleDoctor.repair(withUnknownFields);

      // Unknown node fields preserved in metadata
      expect(fixed.nodes[0].metadata['customNodeField'], equals('should-be-preserved'));
      expect(fixed.nodes[0].metadata['anotherCustomField'], equals({'nested': 'data'}));

      // Unknown edge fields preserved in metadata
      expect(fixed.edges[0].metadata['customEdgeField'], equals('also-preserved'));
    });
  });
}